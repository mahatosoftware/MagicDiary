"""Unit and integration tests for NotificationWorker."""

from datetime import datetime, timezone, timedelta
from unittest.mock import MagicMock, patch
import pytest

from notification_worker.config import WorkerConfig
from notification_worker.fcm_client import FcmClient, FcmSendResult
from notification_worker.worker import NotificationWorker, WorkerRunSummary


@pytest.fixture
def mock_config():
    return WorkerConfig(
        project_id="test-proj",
        service_account='{"project_id": "test-proj"}',
        dry_run=False,
        lookahead_minutes=30,
        max_retries=3,
    )


@pytest.fixture
def mock_fcm_client():
    client = MagicMock(spec=FcmClient)
    client.send_notification.return_value = FcmSendResult(
        success_count=1,
        failure_count=0,
        invalid_tokens=[],
    )
    return client


def test_skip_active_claimed_lease(mock_config, mock_fcm_client):
    """Concurrency test: Worker must skip schedules held by another active worker."""
    worker = NotificationWorker(mock_config, mock_fcm_client)
    now = datetime.now(timezone.utc)
    active_lease = now + timedelta(minutes=4)

    mock_doc = MagicMock()
    mock_doc.id = "sched_1"
    mock_doc.to_dict.return_value = {
        "userId": "user_1",
        "recordId": "rec_1",
        "status": "claimed",
        "claimLeaseExpiresAt": active_lease,
        "claimedByWorker": "other_worker_123",
    }

    summary = WorkerRunSummary(worker_id="worker_curr", started_at=now)
    worker._process_single_schedule(mock_doc, now, "worker_curr", summary)

    assert summary.skipped_count == 1
    assert summary.sent_count == 0
    mock_fcm_client.send_notification.assert_not_called()


def test_cancel_when_parent_record_paid_or_completed(mock_config, mock_fcm_client):
    """Payment completion test: Schedule is cancelled immediately if bill/reminder is paid."""
    worker = NotificationWorker(mock_config, mock_fcm_client)
    now = datetime.now(timezone.utc)

    mock_doc = MagicMock()
    mock_doc.id = "sched_bill_1"
    mock_doc_ref = MagicMock()
    mock_doc.reference = mock_doc_ref
    mock_doc.to_dict.return_value = {
        "userId": "user_1",
        "recordId": "reminder_bill_1",
        "moduleId": "bills",
        "status": "scheduled",
    }

    # Mock DB claim success and parent record check returning status 'paid'
    with patch.object(worker, "_claim_schedule", return_value=True), \
         patch.object(worker, "_verify_parent_record_active", return_value=(False, "Bill marked as 'paid'")), \
         patch.object(worker, "_cancel_schedule") as mock_cancel:

        summary = WorkerRunSummary(worker_id="worker_curr", started_at=now)
        worker._process_single_schedule(mock_doc, now, "worker_curr", summary)

        assert summary.cancelled_count == 1
        assert summary.sent_count == 0
        mock_cancel.assert_called_once()
        mock_fcm_client.send_notification.assert_not_called()


def test_cancel_when_parent_record_deleted(mock_config, mock_fcm_client):
    """Deletion test: Schedule is cancelled if parent reminder was deleted."""
    worker = NotificationWorker(mock_config, mock_fcm_client)
    now = datetime.now(timezone.utc)

    mock_doc = MagicMock()
    mock_doc.id = "sched_deleted"
    mock_doc.to_dict.return_value = {
        "userId": "user_1",
        "recordId": "reminder_deleted",
        "moduleId": "general",
        "status": "scheduled",
    }

    with patch.object(worker, "_claim_schedule", return_value=True), \
         patch.object(worker, "_verify_parent_record_active", return_value=(False, "Parent reminder record was deleted")), \
         patch.object(worker, "_cancel_schedule") as mock_cancel:

        summary = WorkerRunSummary(worker_id="worker_curr", started_at=now)
        worker._process_single_schedule(mock_doc, now, "worker_curr", summary)

        assert summary.cancelled_count == 1
        mock_cancel.assert_called_once()


def test_preserve_snooze_when_scheduled_in_future(mock_config, mock_fcm_client):
    """Snooze preservation test: Snoozed schedule with future trigger remains snoozed."""
    worker = NotificationWorker(mock_config, mock_fcm_client)
    now = datetime.now(timezone.utc)
    future_time = now + timedelta(hours=2)

    mock_doc = MagicMock()
    mock_doc.id = "sched_snooze"
    mock_doc.to_dict.return_value = {
        "userId": "user_1",
        "recordId": "rec_1",
        "status": "snoozed",
        "isSnoozed": True,
        "scheduledAt": future_time,
    }

    with patch.object(worker, "_claim_schedule", return_value=True), \
         patch.object(worker, "_verify_parent_record_active", return_value=(True, "Active")), \
         patch.object(worker, "_update_status") as mock_update_status:

        summary = WorkerRunSummary(worker_id="worker_curr", started_at=now)
        worker._process_single_schedule(mock_doc, now, "worker_curr", summary)

        assert summary.skipped_count == 1
        assert summary.sent_count == 0
        mock_update_status.assert_called_with(mock_doc.reference, "snoozed", now)
        mock_fcm_client.send_notification.assert_not_called()


def test_successful_fcm_dispatch_and_history_recording(mock_config, mock_fcm_client):
    """End-to-end dispatch: Claims schedule, fetches devices, dispatches push, marks sent."""
    worker = NotificationWorker(mock_config, mock_fcm_client)
    now = datetime.now(timezone.utc)

    mock_doc = MagicMock()
    mock_doc.id = "sched_ok"
    mock_doc.reference = MagicMock()
    mock_doc.to_dict.return_value = {
        "userId": "user_1",
        "recordId": "rec_1",
        "moduleId": "bills",
        "eventType": "electricity_bill",
        "status": "scheduled",
        "deliveryKey": "user_1_rec_1_0d",
        "payload": {"title": "Electricity Bill", "body": "Due today: ₹2,400"},
    }

    with patch.object(worker, "_claim_schedule", return_value=True), \
         patch.object(worker, "_verify_parent_record_active", return_value=(True, "Active")), \
         patch.object(worker, "_check_user_preferences_and_quiet_hours", return_value=(True, "OK")), \
         patch.object(worker, "_get_user_devices", return_value=[{"id": "dev_1", "token": "token_123"}]), \
         patch.object(worker, "_mark_sent") as mock_mark_sent:

        summary = WorkerRunSummary(worker_id="worker_curr", started_at=now)
        worker._process_single_schedule(mock_doc, now, "worker_curr", summary)

        assert summary.sent_count == 1
        assert summary.failed_count == 0
        mock_fcm_client.send_notification.assert_called_once_with(
            tokens=["token_123"],
            title="Electricity Bill",
            body="Due today: ₹2,400",
            data_payload={
                "scheduleId": "sched_ok",
                "recordId": "rec_1",
                "moduleId": "bills",
                "categoryId": "general",
                "type": "REMINDER_ALERT",
                "actionRoute": "/notifications",
                "occurrenceId": "occ_default",
            },
            channel_id="financial_reminders",
            delivery_key="user_1_rec_1_0d",
        )
        mock_mark_sent.assert_called_once()


def test_pruning_invalid_tokens_on_dispatch(mock_config):
    """Invalid token cleanup test: Unregistered token detected by FCM is deleted from Firestore."""
    fcm_client = MagicMock(spec=FcmClient)
    fcm_client.send_notification.return_value = FcmSendResult(
        success_count=1,
        failure_count=1,
        invalid_tokens=["bad_token_999"],
    )
    worker = NotificationWorker(mock_config, fcm_client)
    now = datetime.now(timezone.utc)

    mock_doc = MagicMock()
    mock_doc.id = "sched_prune"
    mock_doc.reference = MagicMock()
    mock_doc.to_dict.return_value = {
        "userId": "user_1",
        "recordId": "rec_1",
        "status": "scheduled",
    }

    devices = [
        {"id": "dev_good", "token": "good_token_111"},
        {"id": "dev_bad", "token": "bad_token_999"},
    ]

    with patch.object(worker, "_claim_schedule", return_value=True), \
         patch.object(worker, "_verify_parent_record_active", return_value=(True, "Active")), \
         patch.object(worker, "_check_user_preferences_and_quiet_hours", return_value=(True, "OK")), \
         patch.object(worker, "_get_user_devices", return_value=devices), \
         patch.object(worker, "_prune_invalid_tokens", return_value=1) as mock_prune, \
         patch.object(worker, "_mark_sent"):

        summary = WorkerRunSummary(worker_id="worker_curr", started_at=now)
        worker._process_single_schedule(mock_doc, now, "worker_curr", summary)

        mock_prune.assert_called_once_with("user_1", devices, ["bad_token_999"])
        assert summary.cleaned_tokens_count == 1
        assert summary.sent_count == 1


def test_max_retries_dead_lettering(mock_config):
    """Dead-letter test: When attemptCount exceeds max_retries, mark status as failed."""
    fcm_client = MagicMock(spec=FcmClient)
    fcm_client.send_notification.return_value = FcmSendResult(
        success_count=0,
        failure_count=1,
        errors=["503 Service Unavailable"],
    )
    worker = NotificationWorker(mock_config, fcm_client)
    now = datetime.now(timezone.utc)

    mock_doc = MagicMock()
    mock_doc.id = "sched_retry"
    mock_doc.reference = MagicMock()
    mock_doc.to_dict.return_value = {
        "userId": "user_1",
        "recordId": "rec_1",
        "status": "scheduled",
        "attemptCount": 3,  # Already at max_retries
    }

    with patch.object(worker, "_claim_schedule", return_value=True), \
         patch.object(worker, "_verify_parent_record_active", return_value=(True, "Active")), \
         patch.object(worker, "_check_user_preferences_and_quiet_hours", return_value=(True, "OK")), \
         patch.object(worker, "_get_user_devices", return_value=[{"id": "dev_1", "token": "tok_1"}]), \
         patch.object(worker, "_mark_failed") as mock_mark_failed:

        summary = WorkerRunSummary(worker_id="worker_curr", started_at=now)
        worker._process_single_schedule(mock_doc, now, "worker_curr", summary)

        assert summary.failed_count == 1
        assert summary.sent_count == 0
        mock_mark_failed.assert_called_once()
