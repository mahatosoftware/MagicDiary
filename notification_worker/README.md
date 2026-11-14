# Magic Diary – Scheduled Notification Worker (GitHub Actions + FCM HTTP v1)

## Overview

This is the serverless, free-tier scheduled notification worker for Magic Diary. It replaces costly continuous cloud instances and Firebase Cloud Functions by running on **GitHub Actions** on a scheduled cron (e.g., every 15 minutes) or on-demand via `workflow_dispatch`.

Personal reminders are always scheduled locally on the user's device via `flutter_local_notifications` for 100% offline reliability. This worker handles:
- **Shared Family Updates**: Alerts for shared household expenses, attendance, and tasks.
- **Remote Overdue Escalation**: Multi-stage alerts when commitments are past due.
- **Cross-Device State Synchronization**: `RECORD_PAID` / `RECORD_COMPLETED` pushes.
- **Daily Financial Summaries**: Morning and evening financial digests.
- **Invalid Token Pruning**: Automated removal of stale/unregistered device tokens.

---

## Architecture & Zero Duplicate Delivery

```
                       ┌──────────────────────────────────────────────┐
                       │          GitHub Actions Workflow             │
                       │           (cron: '*/15 * * * *')             │
                       └──────────────────────┬───────────────────────┘
                                              │
                                              ▼
                                 ┌────────────────────────┐
                                 │   NotificationWorker   │
                                 └────────────┬───────────┘
                                              │
                      ┌───────────────────────┴────────────────────────┐
                      ▼                                                ▼
         1. Query Eligible Schedules                    2. Transactional Lease Claim
      (scheduledAt <= now + lookahead)                (prevents duplicate delivery across
        status in [scheduled, claimed]                   concurrent worker executions)
                      │
                      ▼
        3. Parent Record Verification
    (if paid / completed / deleted -> cancel)
                      │
                      ▼
        4. Snooze & Defer State Check
    (if snoozed/deferred in future -> preserve)
                      │
                      ▼
        5. User Preference & Quiet Hours Check
    (respects user quiet hours in local timezone)
                      │
                      ▼
        6. Dispatch Push via FCM HTTP v1
                      │
            ┌─────────┴─────────┐
            ▼                   ▼
    Success (is_delivered)    Invalid Token Detected
    - status = 'sent'         - Prunes device from Firestore
    - logs delivery history   - Dead-letters if retries exceeded
```

---

## Concurrency Safety & Idempotency

1. **Transactional Leases (`claimLeaseExpiresAt`)**:
   - Each worker claims schedules atomically using a lease duration (`CLAIM_LEASE_SECONDS`, default 300s).
   - If a worker crashes, the lease automatically expires and is safely reclaimed by the next run.
2. **Deterministic Composite Delivery Key (`deliveryKey`)**:
   - Format: `${userId}_${recordId}_${occurrenceId}_${notificationType}_${reminderOffset}`
   - Passed in FCM message `tag` and `data.deliveryKey` to ensure device-level deduplication.
3. **Payment & Deletion Reconciliation**:
   - Before any push is sent, the worker queries `/users/{userId}/reminders/{recordId}` (and bills/fee installments).
   - If the user marked the bill paid on any device or deleted the record, the schedule is cancelled immediately with **zero duplicate/stale notifications sent**.

---

## GitHub Secrets Setup

To run this worker in GitHub Actions, configure two repository secrets in your GitHub repository (**Settings > Secrets and variables > Actions > Repository secrets**):

| Secret Name | Description | Example |
|---|---|---|
| `FIREBASE_PROJECT_ID` | Your Google Cloud / Firebase Project ID | `magic-diary-app` |
| `FIREBASE_SERVICE_ACCOUNT` | Full JSON content of your Google Cloud Service Account key | `{"type": "service_account", "project_id": ...}` |

### Least-Privilege Service Account Permissions
Create a dedicated Service Account in Google Cloud IAM with only the following roles:
- **Firebase Cloud Messaging Admin** (`roles/firebasemessaging.admin`) – Dispatches FCM HTTP v1 notifications.
- **Cloud Datastore User** (`roles/datastore.user`) – Reads and updates schedules, preferences, and devices in Firestore.

> ⚠️ **SECURITY WARNING**: Never commit service account credentials into Git! Use only GitHub Secrets.

---

## Local Development & Testing

### 1. Install Dependencies
```bash
python3 -m pip install -r notification_worker/requirements.txt
```

### 2. Configure Environment
Copy `.env.example` to `.env`:
```bash
cp notification_worker/.env.example notification_worker/.env
```
Edit `.env` with your Firebase project ID and local service account path.

### 3. Run Dry-Run Mode (Safe simulation)
```bash
python3 -m notification_worker.main --dry-run --lookahead-minutes 30
```

### 4. Run Test Suite
```bash
pytest notification_worker/tests -v
```

---

## Manual Execution in GitHub Actions

You can trigger the worker manually at any time via the GitHub Web UI:
1. Navigate to **Actions** tab in your repository.
2. Select **Scheduled Notification Worker**.
3. Click **Run workflow**.
4. Choose optional inputs:
   - `dry_run`: `true` or `false`
   - `lookahead_minutes`: e.g. `45`
5. Click **Run workflow**.
