"""Core scheduled notification worker for Magic Diary.

Connects to Firestore, claims eligible notification schedules using transactional leases
to prevent duplicate delivery, checks parent record status (cancelling if paid/completed/deleted),
evaluates snooze/defer/overdue state, checks quiet hours, sends push via FCM HTTP v1,
cleans up invalid device tokens, and writes delivery audit history.
"""

from __future__ import annotations

import logging
import uuid
from dataclasses import dataclass, field
from datetime import datetime, timezone
from typing import Any, Dict, List, Optional

import firebase_admin
from firebase_admin import firestore
from google.cloud.firestore_v1 import Transaction
from google.cloud.firestore_v1.base_query import FieldFilter
import pytz

from notification_worker.config import WorkerConfig
from notification_worker.fcm_client import FcmClient, FcmSendResult

logger = logging.getLogger(__name__)


@dataclass
class WorkerRunSummary:
    worker_id: str
    started_at: datetime
    completed_at: Optional[datetime] = None
    processed_count: int = 0
    sent_count: int = 0
    cancelled_count: int = 0
    skipped_count: int = 0
    failed_count: int = 0
    cleaned_tokens_count: int = 0
    errors: List[str] = field(default_factory=list)


class NotificationWorker:
    def __init__(self, config: Optional[WorkerConfig] = None, fcm_client: Optional[FcmClient] = None) -> None:
        self.config = config or WorkerConfig()
        self.fcm_client = fcm_client or FcmClient(self.config)
        self._db: Optional[firestore.Client] = None

    @property
    def db(self) -> firestore.Client:
        if self._db is None:
            self._db = firestore.client()
        return self._db

    def run(self) -> WorkerRunSummary:
        """Executes the notification worker cycle."""
        now = datetime.now(timezone.utc)
        worker_id = f"magicdiary_worker_{uuid.uuid4().hex[:8]}_{int(now.timestamp())}"
        summary = WorkerRunSummary(worker_id=worker_id, started_at=now)

        logger.info(
            "Starting MagicDiary Notification Worker %s (dry_run=%s, lookahead=%dm, batch_size=%d)",
            worker_id,
            self.config.dry_run,
            self.config.lookahead_minutes,
            self.config.batch_size,
        )

        try:
            eligible_docs = self._query_eligible_schedules(now)
            logger.info("Found %d candidate schedules within lookahead window.", len(eligible_docs))

            for doc in eligible_docs:
                summary.processed_count += 1
                try:
                    self._process_single_schedule(doc, now, worker_id, summary)
                except Exception as e:
                    logger.error("Error processing schedule %s: %s", doc.id, e, exc_info=True)
                    summary.failed_count += 1
                    summary.errors.append(f"Schedule {doc.id}: {e}")

        except Exception as e:
            logger.error("Fatal error during worker execution: %s", e, exc_info=True)
            summary.errors.append(f"Worker fatal error: {e}")

        summary.completed_at = datetime.now(timezone.utc)
        logger.info(
            "Worker %s completed: Processed=%d, Sent=%d, Cancelled=%d, Skipped=%d, Failed=%d, PrunedTokens=%d",
            summary.worker_id,
            summary.processed_count,
            summary.sent_count,
            summary.cancelled_count,
            summary.skipped_count,
            summary.failed_count,
            summary.cleaned_tokens_count,
        )
        return summary

    def _query_eligible_schedules(self, now: datetime) -> List[firestore.DocumentSnapshot]:
        """Queries schedules eligible for processing within the lookahead window."""
        window_end = datetime.fromtimestamp(
            now.timestamp() + (self.config.lookahead_minutes * 60),
            tz=timezone.utc,
        )

        if self.config.dry_run:
            logger.info("[DRY RUN] Querying collection_group 'notification_schedules'")

        # Query collection group 'notification_schedules'
        # Status can be 'scheduled', 'pending', or 'claimed' (for expired leases)
        try:
            query = (
                self.db.collection_group("notification_schedules")
                .where(filter=FieldFilter("status", "in", ["scheduled", "pending", "claimed"]))
                .where(filter=FieldFilter("scheduledAt", "<=", window_end))
                .limit(self.config.batch_size)
            )
            return list(query.stream())
        except Exception as e:
            logger.warning("Collection group query failed (index may be required), falling back to user scan: %s", e)
            return self._fallback_user_schedules_query(window_end)

    def _fallback_user_schedules_query(self, window_end: datetime) -> List[firestore.DocumentSnapshot]:
        """Fallback querying schedules user by user if composite collection group index is not yet built."""
        results: List[firestore.DocumentSnapshot] = []
        try:
            users = self.db.collection("users").limit(50).stream()
            for user in users:
                schedules = (
                    self.db.collection("users")
                    .doc(user.id)
                    .collection("notification_schedules")
                    .where(filter=FieldFilter("status", "in", ["scheduled", "pending", "claimed"]))
                    .where(filter=FieldFilter("scheduledAt", "<=", window_end))
                    .limit(20)
                    .stream()
                )
                for s in schedules:
                    results.append(s)
                    if len(results) >= self.config.batch_size:
                        return results
        except Exception as e:
            logger.error("Fallback scan error: %s", e)
        return results

    def _process_single_schedule(
        self,
        doc: firestore.DocumentSnapshot,
        now: datetime,
        worker_id: str,
        summary: WorkerRunSummary,
    ) -> None:
        """Processes a single schedule with transactional claiming and state verification."""
        data = doc.to_dict() or {}
        user_id = data.get("userId", "")
        record_id = data.get("recordId", "")
        schedule_id = doc.id
        status = data.get("status", "scheduled")
        delivery_key = data.get("deliveryKey") or f"{user_id}_{record_id}_{schedule_id}"

        # 1. Concurrency-Safe Claim Check
        if status == "claimed":
            lease_expires = data.get("claimLeaseExpiresAt")
            if lease_expires:
                if isinstance(lease_expires, datetime):
                    lease_dt = lease_expires if lease_expires.tzinfo else lease_expires.replace(tzinfo=timezone.utc)
                else:
                    lease_dt = datetime.fromtimestamp(lease_expires.timestamp(), tz=timezone.utc)
                if lease_dt > now:
                    logger.debug("Schedule %s has active lease until %s, skipping.", schedule_id, lease_dt)
                    summary.skipped_count += 1
                    return
            logger.info("Schedule %s has expired claim lease. Re-claiming.", schedule_id)

        # 2. Transactional Claim
        if not self.config.dry_run:
            claimed = self._claim_schedule(doc.reference, worker_id, now)
            if not claimed:
                logger.info("Failed to claim schedule %s (likely claimed by concurrent worker).", schedule_id)
                summary.skipped_count += 1
                return
        else:
            logger.info("[DRY RUN] Claimed schedule %s for worker %s", schedule_id, worker_id)

        # 3. Check Parent Record Status (Cancellation on complete / paid / deleted)
        is_active, cancel_reason = self._verify_parent_record_active(user_id, record_id, data.get("moduleId", ""))
        if not is_active:
            logger.info("Cancelling schedule %s because parent record is inactive: %s", schedule_id, cancel_reason)
            self._cancel_schedule(doc.reference, cancel_reason, now)
            summary.cancelled_count += 1
            return

        # 4. Check Snooze & Defer State
        is_snoozed = data.get("isSnoozed", False)
        is_deferred = data.get("isDeferred", False)
        scheduled_at = data.get("scheduledAt")
        if scheduled_at:
            sched_dt = scheduled_at if isinstance(scheduled_at, datetime) else datetime.fromtimestamp(scheduled_at.timestamp(), tz=timezone.utc)
            if sched_dt.tzinfo is None:
                sched_dt = sched_dt.replace(tzinfo=timezone.utc)
            if is_snoozed and sched_dt > now:
                logger.info("Schedule %s is snoozed until %s. Preserving snooze.", schedule_id, sched_dt)
                self._update_status(doc.reference, "snoozed", now)
                summary.skipped_count += 1
                return
            if is_deferred and sched_dt > now:
                logger.info("Schedule %s is deferred until %s. Preserving defer.", schedule_id, sched_dt)
                self._update_status(doc.reference, "deferred", now)
                summary.skipped_count += 1
                return

        # 5. Check User Preferences & Quiet Hours
        should_send, pref_reason = self._check_user_preferences_and_quiet_hours(user_id, data, now)
        if not should_send:
            logger.info("Skipping schedule %s due to preference / quiet hours: %s", schedule_id, pref_reason)
            self._update_status(doc.reference, "scheduled", now, error_msg=pref_reason)
            summary.skipped_count += 1
            return

        # 6. Retrieve User Device Tokens & Send FCM Push
        devices = self._get_user_devices(user_id)
        if not devices:
            logger.warning("No registered devices for user %s on schedule %s.", user_id, schedule_id)
            self._mark_failed(doc.reference, "No registered FCM devices found for user.", now, data)
            summary.failed_count += 1
            return

        tokens = [d["token"] for d in devices if d.get("token")]
        payload = data.get("payload") or {}
        title = payload.get("title") or data.get("eventType", "Reminder")
        body = payload.get("body") or data.get("reminderOffset", "")
        notification_type = data.get("notificationType", "reminder")

        # Determine Channel ID
        channel_id = "financial_reminders"
        if notification_type == "overdue":
            channel_id = "overdue_alerts"
        elif data.get("moduleId") == "vehicle":
            channel_id = "maintenance_service"
        elif is_snoozed or is_deferred:
            channel_id = "snooze_defer"

        fcm_data = {
            "scheduleId": schedule_id,
            "recordId": record_id,
            "moduleId": data.get("moduleId", "general"),
            "categoryId": data.get("categoryId", "general"),
            "type": "OVERDUE_ALERT" if notification_type == "overdue" else "REMINDER_ALERT",
            "actionRoute": payload.get("actionRoute", "/notifications"),
            "occurrenceId": data.get("occurrenceId", "occ_default"),
        }

        # Dispatch FCM HTTP v1 Notification
        send_result: FcmSendResult = self.fcm_client.send_notification(
            tokens=tokens,
            title=title,
            body=body,
            data_payload=fcm_data,
            channel_id=channel_id,
            delivery_key=delivery_key,
        )

        # 7. Prune Invalid Tokens Immediately
        if send_result.invalid_tokens and not self.config.dry_run:
            pruned = self._prune_invalid_tokens(user_id, devices, send_result.invalid_tokens)
            summary.cleaned_tokens_count += pruned

        # 8. Record Delivery State in Schedule & History
        if send_result.is_delivered:
            logger.info("Schedule %s sent successfully to %d devices.", schedule_id, send_result.success_count)
            self._mark_sent(doc.reference, user_id, schedule_id, data, title, body, delivery_key, now, send_result)
            summary.sent_count += 1
        else:
            err_msg = "; ".join(send_result.errors) or "FCM delivery failed to all tokens"
            attempt_count = int(data.get("attemptCount", 0)) + 1
            if attempt_count >= self.config.max_retries:
                logger.error("Schedule %s exceeded max retries (%d). Dead-lettering.", schedule_id, attempt_count)
                self._mark_failed(doc.reference, err_msg, now, data)
                summary.failed_count += 1
            else:
                logger.warning("Schedule %s failed (attempt %d/%d): %s. Re-scheduling.", schedule_id, attempt_count, self.config.max_retries, err_msg)
                self._update_status(doc.reference, "scheduled", now, error_msg=err_msg)
                summary.failed_count += 1

    def _claim_schedule(self, doc_ref: firestore.DocumentReference, worker_id: str, now: datetime) -> bool:
        """Atomically claims a schedule document using a lease duration."""
        lease_seconds = self.config.claim_lease_seconds
        lease_expires = datetime.fromtimestamp(now.timestamp() + lease_seconds, tz=timezone.utc)

        @firestore.transactional
        def claim_in_txn(txn: Transaction) -> bool:
            snapshot = doc_ref.get(transaction=txn)
            if not snapshot.exists:
                return False
            curr = snapshot.to_dict() or {}
            curr_status = curr.get("status", "")
            if curr_status not in ("scheduled", "pending", "claimed"):
                return False
            if curr_status == "claimed":
                curr_lease = curr.get("claimLeaseExpiresAt")
                if curr_lease:
                    c_dt = curr_lease if isinstance(curr_lease, datetime) else datetime.fromtimestamp(curr_lease.timestamp(), tz=timezone.utc)
                    if c_dt.tzinfo is None:
                        c_dt = c_dt.replace(tzinfo=timezone.utc)
                    if c_dt > now:
                        return False

            attempt_count = int(curr.get("attemptCount", 0)) + 1
            txn.update(
                doc_ref,
                {
                    "status": "claimed",
                    "claimedByWorker": worker_id,
                    "claimLeaseExpiresAt": lease_expires,
                    "lastAttemptAt": now,
                    "attemptCount": attempt_count,
                    "updatedAt": now,
                },
            )
            return True

        transaction = self.db.transaction()
        try:
            return claim_in_txn(transaction)
        except Exception as e:
            logger.debug("Transaction claim aborted: %s", e)
            return False

    def _verify_parent_record_active(self, user_id: str, record_id: str, module_id: str) -> tuple[bool, str]:
        """Checks whether the underlying commitment or reminder is still active and unpaid."""
        if not user_id or not record_id:
            return True, "No record to verify"

        # Check in reminders collection first
        reminder_ref = self.db.collection("users").doc(user_id).collection("reminders").doc(record_id)
        reminder_doc = reminder_ref.get()
        if reminder_doc.exists:
            rem_data = reminder_doc.to_dict() or {}
            st = rem_data.get("status", "").lower()
            if st in ("completed", "paid"):
                return False, f"Reminder status is '{st}'"
            return True, "Active reminder"

        # Check in bills collection if financial module
        if module_id in ("bills", "financial", "finance"):
            bill_ref = self.db.collection("users").doc(user_id).collection("bills").doc(record_id)
            bill_doc = bill_ref.get()
            if bill_doc.exists:
                b_data = bill_doc.to_dict() or {}
                if b_data.get("status", "").lower() == "paid":
                    return False, "Bill marked as 'paid'"
                return True, "Active bill"

        # Check in feeInstallments if school fees
        if module_id in ("school_fees", "schoolfees"):
            fee_ref = self.db.collection("users").doc(user_id).collection("feeInstallments").doc(record_id)
            fee_doc = fee_ref.get()
            if fee_doc.exists:
                f_data = fee_doc.to_dict() or {}
                if f_data.get("status", "").lower() == "paid":
                    return False, "Fee installment marked as 'paid'"
                return True, "Active installment"

        # If record ID starts with 'reminder_' and document does not exist, consider it deleted
        if record_id.startswith("reminder_") and not reminder_doc.exists:
            return False, "Parent reminder record was deleted"

        return True, "Record presumed active"

    def _check_user_preferences_and_quiet_hours(
        self, user_id: str, schedule_data: Dict[str, Any], now: datetime
    ) -> tuple[bool, str]:
        """Checks if user disabled notifications or if current time is inside quiet hours."""
        if not user_id:
            return True, "OK"

        try:
            pref_doc = (
                self.db.collection("users")
                .doc(user_id)
                .collection("notification_preferences")
                .doc("global")
                .get()
            )
            if not pref_doc.exists:
                return True, "No custom global preferences"

            prefs = pref_doc.to_dict() or {}
            if prefs.get("isEnabled") is False:
                return False, "User master toggle disabled"

            # Quiet Hours Check
            if prefs.get("quietHoursEnabled") is True:
                q_start = prefs.get("quietHoursStart") or {"hour": 22, "minute": 0}
                q_end = prefs.get("quietHoursEnd") or {"hour": 8, "minute": 0}
                tz_name = schedule_data.get("timezone") or self.config.timezone_default

                try:
                    user_tz = pytz.timezone(tz_name)
                    user_local = now.astimezone(user_tz)
                    cur_minute = user_local.hour * 60 + user_local.minute
                    s_minute = q_start.get("hour", 22) * 60 + q_start.get("minute", 0)
                    e_minute = q_end.get("hour", 8) * 60 + q_end.get("minute", 0)

                    in_quiet = False
                    if s_minute > e_minute:
                        in_quiet = cur_minute >= s_minute or cur_minute < e_minute
                    else:
                        in_quiet = s_minute <= cur_minute < e_minute

                    if in_quiet:
                        return False, f"Inside quiet hours in {tz_name} ({user_local.strftime('%H:%M')})"
                except Exception as tz_err:
                    logger.debug("Timezone resolution error for %s: %s", tz_name, tz_err)

        except Exception as e:
            logger.debug("Preference read exception: %s", e)

        return True, "Preferences allow delivery"

    def _get_user_devices(self, user_id: str) -> List[Dict[str, str]]:
        """Retrieves registered device FCM tokens for a user."""
        devices: List[Dict[str, str]] = []
        try:
            snap = self.db.collection("users").doc(user_id).collection("devices").stream()
            for doc in snap:
                d = doc.to_dict() or {}
                token = d.get("fcmToken", "")
                if token:
                    devices.append({"id": doc.id, "token": token})
        except Exception as e:
            logger.error("Error fetching devices for user %s: %s", user_id, e)
        return devices

    def _prune_invalid_tokens(
        self, user_id: str, devices: List[Dict[str, str]], invalid_tokens: List[str]
    ) -> int:
        """Deletes unregistered/invalid device tokens from Firestore."""
        pruned_count = 0
        invalid_set = set(invalid_tokens)
        for dev in devices:
            if dev["token"] in invalid_set:
                try:
                    self.db.collection("users").doc(user_id).collection("devices").doc(dev["id"]).delete()
                    logger.info("Pruned invalid FCM device token doc %s for user %s", dev["id"], user_id)
                    pruned_count += 1
                except Exception as e:
                    logger.warning("Failed to delete device %s: %s", dev["id"], e)
        return pruned_count

    def _mark_sent(
        self,
        doc_ref: firestore.DocumentReference,
        user_id: str,
        schedule_id: str,
        data: Dict[str, Any],
        title: str,
        body: str,
        delivery_key: str,
        now: datetime,
        send_result: FcmSendResult,
    ) -> None:
        """Updates schedule status to 'sent' and writes delivery audit history."""
        if not self.config.dry_run:
            doc_ref.update(
                {
                    "status": "sent",
                    "sentAt": now,
                    "updatedAt": now,
                    "errorMessage": None,
                }
            )

            # Write to user's notification_history
            history_id = f"hist_{schedule_id}_{int(now.timestamp())}"
            history_ref = (
                self.db.collection("users")
                .doc(user_id)
                .collection("notification_history")
                .doc(history_id)
            )
            history_data = {
                "id": history_id,
                "notificationId": schedule_id,
                "recordId": data.get("recordId", ""),
                "moduleId": data.get("moduleId", "general"),
                "eventType": data.get("eventType", "reminder"),
                "title": title,
                "body": body,
                "status": "sent",
                "scheduledAt": data.get("scheduledAt", now),
                "deliveredAt": now,
                "createdAt": now,
                "metadata": {
                    "deliveryKey": delivery_key,
                    "successCount": send_result.success_count,
                    "failureCount": send_result.failure_count,
                    "sentVia": "github_actions_worker",
                },
            }
            try:
                history_ref.set(history_data)
            except Exception as e:
                logger.warning("Failed to write notification history: %s", e)

            # Also log to global delivery history collection
            try:
                self.db.collection("notification_delivery_history").add(
                    {
                        "userId": user_id,
                        "scheduleId": schedule_id,
                        "deliveryKey": delivery_key,
                        "status": "sent",
                        "sentAt": now,
                    }
                )
            except Exception as e:
                logger.debug("Global delivery history log error: %s", e)

    def _mark_failed(
        self,
        doc_ref: firestore.DocumentReference,
        error_msg: str,
        now: datetime,
        data: Dict[str, Any],
    ) -> None:
        """Marks schedule as permanently failed (dead-letter queue)."""
        if not self.config.dry_run:
            doc_ref.update(
                {
                    "status": "failed",
                    "errorMessage": error_msg,
                    "updatedAt": now,
                }
            )

    def _cancel_schedule(
        self, doc_ref: firestore.DocumentReference, reason: str, now: datetime
    ) -> None:
        """Cancels schedule when parent record is completed or deleted."""
        if not self.config.dry_run:
            doc_ref.update(
                {
                    "status": "cancelled",
                    "errorMessage": reason,
                    "updatedAt": now,
                }
            )

    def _update_status(
        self,
        doc_ref: firestore.DocumentReference,
        status: str,
        now: datetime,
        error_msg: Optional[str] = None,
    ) -> None:
        if not self.config.dry_run:
            update_data: Dict[str, Any] = {
                "status": status,
                "updatedAt": now,
            }
            if error_msg:
                update_data["errorMessage"] = error_msg
            doc_ref.update(update_data)
