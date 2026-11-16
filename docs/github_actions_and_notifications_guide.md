# GitHub Actions & Notification Configuration Guide

This comprehensive guide covers how to configure **GitHub Actions** and set up **notifications** for the Magic Diary project.

It addresses both aspects of notifications in modern mobile/serverless workflows:
1. **In-App Push Notifications (FCM HTTP v1)**: Running our automated scheduled worker on GitHub Actions to dispatch reminders, shared family updates, and financial digests to user devices without requiring paid servers.
2. **Workflow Run Notifications (CI/CD Alerts)**: Sending build status alerts (success, failure, warnings) to developers via **Telegram, Discord, Slack, or Email**.

---

## Table of Contents

- [1. Architecture Overview](#1-architecture-overview)
- [2. Part 1: Configuring App Push Notifications via GitHub Actions](#2-part-1-configuring-app-push-notifications-via-github-actions)
  - [2.1 Workflow File Breakdown](#21-workflow-file-breakdown)
  - [2.2 Generating Google Cloud / Firebase Service Account](#22-generating-google-cloud--firebase-service-account)
  - [2.3 Configuring GitHub Secrets](#23-configuring-github-secrets)
  - [2.4 Manual Execution & Dry-Run Testing](#24-manual-execution--dry-run-testing)
- [3. Part 2: Sending Workflow Status Notifications (Slack, Discord, Telegram)](#3-part-2-sending-workflow-status-notifications-slack-discord-telegram)
  - [3.1 Telegram Notifications](#31-telegram-notifications-recommended-free--instant)
  - [3.2 Discord Webhook Notifications](#32-discord-webhook-notifications)
  - [3.3 Slack Webhook Notifications](#33-slack-webhook-notifications)
  - [3.4 GitHub Native Summary & Email Alerts](#34-github-native-summary--email-alerts)
- [4. Complete Production Workflow Example with Notification Integration](#4-complete-production-workflow-example-with-notification-integration)
- [5. Troubleshooting & Operational Best Practices](#5-troubleshooting--operational-best-practices)
- [6. Summary Checklist](#6-summary-checklist)

---

## 1. Architecture Overview

```
                      ┌─────────────────────────────────────────────────────┐
                      │             GitHub Actions Scheduler                │
                      │               (Cron: */15 * * * *)                  │
                      └──────────────────────────┬──────────────────────────┘
                                                 │
                                                 ▼
                      ┌─────────────────────────────────────────────────────┐
                      │              notification_worker.yml                │
                      └──────────────┬───────────────────────┬──────────────┘
                                     │                       │
                                     ▼                       ▼
                        [Step: Notification Worker]   [Step: CI/CD Alert]
                                     │                       │
                        ┌────────────┴────────────┐          │
                        ▼                         ▼          ▼
               Firebase Firestore         FCM HTTP v1     Developer Alert
               - Read schedules           - Send push to  (Telegram/Discord/
               - Atomically claim lease     devices         Slack/Email)
               - Prune stale tokens       - Deduplicate
```

---

## 2. Part 1: Configuring App Push Notifications via GitHub Actions

Magic Diary uses a serverless Python worker (`notification_worker/`) executed on GitHub Actions to query Firestore and send scheduled FCM notifications.

### 2.1 Workflow File Breakdown

The workflow file is located at [`.github/workflows/notification_worker.yml`](file:///Volumes/DebasishApple/DeveloperExt/Apps/MagicDiary/.github/workflows/notification_worker.yml).

Key configurations:
- **Triggers**:
  - `schedule`: Runs every 15 minutes (`*/15 * * * *`).
  - `workflow_dispatch`: Enables manual trigger from the GitHub web UI with customizable parameters (`dry_run`, `lookahead_minutes`).
- **Concurrency Control**:
  - `group: notification-worker-execution`: Ensures only one worker runs at a time, preventing race conditions.
- **Environment Variables & Secrets**:
  - `FIREBASE_PROJECT_ID`: Injected from GitHub Repository Secrets.
  - `FIREBASE_SERVICE_ACCOUNT`: Injected from GitHub Repository Secrets.

### 2.2 Generating Google Cloud / Firebase Service Account

To authorize GitHub Actions to read Firestore and send FCM notifications, configure a Google Cloud Service Account with **least-privilege access**:

1. Open the [Google Cloud Console](https://console.cloud.google.com/) and ensure you have selected project **`magicdiary-firebase-prod`** (do not select `Kittycircle-firebase-prod` or any other project).
2. Navigate to **IAM & Admin > Service Accounts**.
3. Click **Create Service Account**:
   - **Name**: `magic-diary-github-worker`
   - **Description**: `Dispatches scheduled notifications from GitHub Actions for Magic Diary`
4. Grant the following IAM roles:
   - **Firebase Cloud Messaging Admin** (`roles/firebasemessaging.admin`): Needed to send push messages via FCM HTTP v1.
   - **Cloud Datastore User** (`roles/datastore.user`): Needed to query and update schedule status in Firestore.
5. Click **Done**.
6. Click on the newly created service account > **Keys** tab > **Add Key** > **Create new key** > Select **JSON**.
7. Download the JSON key file. Open it and verify that `"project_id": "magicdiary-firebase-prod"`.

> [!WARNING]
> **Critical Project ID Check**:
> Ensure the service account JSON key contains `"project_id": "magicdiary-firebase-prod"`. If it says `"project_id": "Kittycircle-firebase-prod"` or another project, it was generated under the wrong GCP/Firebase project and will cause authentication failures (`403 PERMISSION_DENIED` or `Project ID mismatch`). Never commit this JSON key file to Git! Only store it inside GitHub Actions Secrets.

### 2.3 Configuring GitHub Secrets

1. Go to your GitHub repository on [github.com](https://github.com).
2. Click **Settings** (tab at the top).
3. In the left sidebar, expand **Secrets and variables** and click **Actions**.
4. Under **Repository secrets**, click **New repository secret** (or click the edit pencil icon to update existing secrets):

| Secret Name | Value | Description |
|---|---|---|
| `FIREBASE_PROJECT_ID` | `magicdiary-firebase-prod` | Must match the Firebase Project ID exactly |
| `FIREBASE_SERVICE_ACCOUNT` | Entire contents of `magicdiary-firebase-prod` service account JSON key | Paste the full raw JSON text |

> [!TIP]
> Make sure the JSON does not contain unescaped line breaks that break formatting. Pasting the raw file contents directly into GitHub Secrets works seamlessly.

### 2.4 Manual Execution & Dry-Run Testing

Before relying on scheduled cron runs, test the setup directly:

1. In your GitHub repository, navigate to the **Actions** tab.
2. In the left workflow list, select **MagicDiary Notification Worker**.
3. Click the **Run workflow** dropdown on the right.
4. Set options:
   - **Dry run**: Checked (`true`) to simulate without writing to Firestore or sending push.
   - **Lookahead minutes**: e.g., `60`
5. Click **Run workflow**.
6. Click on the initiated run to inspect real-time logs and verify:
   - Dependencies installation
   - Pytest unit tests execution
   - Worker schedule query & FCM dispatch

---

## 3. Part 2: Sending Workflow Status Notifications (Slack, Discord, Telegram)

When your GitHub Action fails or succeeds, you can notify your development or operations team automatically.

### 3.1 Telegram Notifications (Recommended: Free & Instant)

Telegram bots provide free, instant mobile notifications without rate limits for developer alerts.

#### Step 1: Create a Telegram Bot
1. Open Telegram and search for `@BotFather`.
2. Send `/newbot`, choose a name and username (e.g. `MagicDiaryCiBot`).
3. Copy the **HTTP API Bot Token** (e.g., `123456789:ABCdefGhIJKlmNoPQRsTUVwxyZ`).

#### Step 2: Get your Chat ID
1. Search for `@userinfobot` on Telegram and send `/start`.
2. Note your numeric **Id** (e.g., `987654321`), or add the bot to your developer group and retrieve the group ID.

#### Step 3: Add GitHub Secrets
- `TELEGRAM_BOT_TOKEN`: The bot token from BotFather.
- `TELEGRAM_CHAT_ID`: Your chat or group ID.

#### Step 4: Add Notification Step in `.github/workflows/notification_worker.yml`
```yaml
      - name: Send Telegram Notification on Failure
        if: failure()
        uses: appleboy/telegram-action@master
        with:
          to: ${{ secrets.TELEGRAM_CHAT_ID }}
          token: ${{ secrets.TELEGRAM_BOT_TOKEN }}
          message: |
            ⚠️ GitHub Action Failed!
            Workflow: ${{ github.workflow }}
            Repository: ${{ github.repository }}
            Run: https://github.com/${{ github.repository }}/actions/runs/${{ github.run_id }}
```

---

### 3.2 Discord Webhook Notifications

Discord is widely used for developer notifications via webhooks.

#### Step 1: Create a Discord Webhook
1. In your Discord server, right-click your alerts channel and go to **Edit Channel > Integrations > Webhooks**.
2. Click **New Webhook**, name it `GitHub Actions Bot`, and click **Copy Webhook URL**.

#### Step 2: Add GitHub Secret
- `DISCORD_WEBHOOK_URL`: Paste the copied webhook URL.

#### Step 3: Add Step in Workflow
```yaml
      - name: Notify Discord
        if: always()
        uses: Ilshidur/action-discord@master
        env:
          DISCORD_WEBHOOK: ${{ secrets.DISCORD_WEBHOOK_URL }}
        with:
          args: 'Workflow {{ EVENT_PAYLOAD.repository.full_name }} finished with status: ${{ job.status }}'
```

---

### 3.3 Slack Webhook Notifications

For team communication in Slack:

#### Step 1: Create Slack Incoming Webhook
1. Go to [api.slack.com/apps](https://api.slack.com/apps) > **Create New App** > **From scratch**.
2. Enable **Incoming Webhooks** and click **Add New Webhook to Workspace**.
3. Select the channel and copy the **Webhook URL**.

#### Step 2: Add GitHub Secret
- `SLACK_WEBHOOK_URL`: Paste the Slack webhook URL.

#### Step 3: Add Step in Workflow
```yaml
      - name: Notify Slack
        if: always()
        uses: 8398a7/action-slack@v3
        with:
          status: ${{ job.status }}
          fields: repo,message,commit,author,action,eventName,ref,workflow
        env:
          SLACK_WEBHOOK_URL: ${{ secrets.SLACK_WEBHOOK_URL }}
```

---

### 3.4 GitHub Native Summary & Email Alerts

Even without external webhooks, GitHub Actions provides built-in mechanisms:

1. **Job Step Summary (`$GITHUB_STEP_SUMMARY`)**:
   Already configured in our `notification_worker.yml`:
   ```bash
   echo "### 🚀 Notification Worker Run Complete" >> $GITHUB_STEP_SUMMARY
   echo "- **Trigger**: ${{ github.event_name }}" >> $GITHUB_STEP_SUMMARY
   ```
   This displays a formatted card directly on the GitHub Actions run summary page.

2. **Email Notifications on Run Failure**:
   GitHub automatically sends emails on workflow failure to the committer. To configure:
   - In GitHub, go to **Settings > Notifications**.
   - Under **Actions**, ensure **Send notifications for failed workflows only** (or all workflows) is checked.

---

## 4. Complete Production Workflow Example with Notification Integration

Here is an enhanced `.github/workflows/notification_worker.yml` combining both **scheduled push notification execution** and **developer alerting**:

```yaml
name: MagicDiary Notification Worker

on:
  schedule:
    # Run every 15 minutes (24/7)
    - cron: '*/15 * * * *'
  workflow_dispatch:
    inputs:
      dry_run:
        description: 'Simulate without sending push or updating Firestore'
        type: boolean
        required: false
        default: false
      lookahead_minutes:
        description: 'Minutes in advance to search for eligible schedules'
        type: number
        required: false
        default: 30

concurrency:
  group: notification-worker-execution
  cancel-in-progress: false

jobs:
  run-worker:
    name: Execute Notification Worker
    runs-on: ubuntu-latest
    timeout-minutes: 10

    steps:
      - name: Checkout Repository
        uses: actions/checkout@v4

      - name: Set up Python
        uses: actions/setup-python@v5
        with:
          python-version: '3.11'
          cache: 'pip'

      - name: Install Dependencies
        run: |
          python -m pip install --upgrade pip
          pip install -r notification_worker/requirements.txt

      - name: Run Worker Unit Tests
        run: |
          pytest notification_worker/tests -v --durations=10

      - name: Execute Notification Worker
        env:
          FIREBASE_PROJECT_ID: ${{ secrets.FIREBASE_PROJECT_ID != '' && secrets.FIREBASE_PROJECT_ID || 'magicdiary-firebase-prod' }}
          FIREBASE_SERVICE_ACCOUNT: ${{ secrets.FIREBASE_SERVICE_ACCOUNT }}
          DRY_RUN: ${{ github.event.inputs.dry_run || 'false' }}
          LOOKAHEAD_MINUTES: ${{ github.event.inputs.lookahead_minutes || 30 }}
          BATCH_SIZE: 150
          MAX_RETRIES: 3
          CLAIM_LEASE_SECONDS: 300
        run: |
          python -m notification_worker.main

      - name: Generate Job Summary
        if: always()
        run: |
          echo "### 🚀 Magic Diary Notification Worker Run Complete" >> $GITHUB_STEP_SUMMARY
          echo "- **Trigger**: ${{ github.event_name }}" >> $GITHUB_STEP_SUMMARY
          echo "- **Status**: ${{ job.status }}" >> $GITHUB_STEP_SUMMARY
          echo "- **Dry Run**: ${{ github.event.inputs.dry_run || 'false' }}" >> $GITHUB_STEP_SUMMARY
          echo "- **Lookahead**: ${{ github.event.inputs.lookahead_minutes || 30 }} minutes" >> $GITHUB_STEP_SUMMARY
          echo "- **Timestamp**: $(date -u '+%Y-%m-%d %H:%M:%S UTC')" >> $GITHUB_STEP_SUMMARY

      # Optional: Alert developers if scheduled worker encounters errors
      - name: Send Telegram Alert on Failure
        if: failure() && env.TELEGRAM_BOT_TOKEN != ''
        env:
          TELEGRAM_BOT_TOKEN: ${{ secrets.TELEGRAM_BOT_TOKEN }}
          TELEGRAM_CHAT_ID: ${{ secrets.TELEGRAM_CHAT_ID }}
        uses: appleboy/telegram-action@master
        with:
          to: ${{ secrets.TELEGRAM_CHAT_ID }}
          token: ${{ secrets.TELEGRAM_BOT_TOKEN }}
          message: |
            ❌ Magic Diary Notification Worker Failed!
            Workflow: ${{ github.workflow }}
            Run URL: https://github.com/${{ github.repository }}/actions/runs/${{ github.run_id }}
            Commit: ${{ github.sha }}
```

---

## 5. Troubleshooting & Operational Best Practices

### 1. GitHub Cron Inactivity Rule
> [!IMPORTANT]
> If a repository has had **no commits or activity for 60 days**, GitHub automatically pauses all scheduled cron workflows.
> - **Solution**: Commit periodically or set up an automated dummy commit/repository dispatch every 30 days, or simply trigger a `workflow_dispatch` manually to keep it active.

### 2. GitHub Actions Free Tier Quota
- GitHub Actions provides **2,000 free minutes per month** for private repositories (unlimited for public repositories).
- Running every 15 minutes = ~2,880 runs/month.
- With average execution time of ~20 seconds:
  $$\frac{20 \text{ sec}}{60} \times 2,880 \approx 960 \text{ minutes/month}$$
  This stays comfortably within the free 2,000 minutes quota.

### 3. Checking Worker Delivery History in Firestore
Worker executions record telemetry and delivery status:
- `/notification_schedules/{scheduleId}`
  - `status`: `'sent'`, `'claimed'`, or `'cancelled'`
  - `sentAt`: Timestamp when FCM responded OK
  - `deliveryHistory`: Detailed log of FCM message IDs and retry attempts

### 4. Handling Invalid Tokens
When a user uninstalls the app or token expires:
- FCM returns `UNREGISTERED` or `INVALID_ARGUMENT`.
- The worker automatically deletes the dead device token from `/users/{userId}/devices/{deviceId}` to maintain high FCM reputation and eliminate unnecessary API requests.

### 5. Fixing "Project ID Mismatch" (`Kittycircle-firebase-prod` vs `magicdiary-firebase-prod`)
If you see an error indicating:
`Project ID mismatch: FIREBASE_PROJECT_ID is 'magicdiary-firebase-prod', but the service account key belongs to 'Kittycircle-firebase-prod'` (or `403 PERMISSION_DENIED`):
- **Cause**: The service account JSON key saved in GitHub Secrets was created under a different project (`Kittycircle-firebase-prod` or another app) instead of `magicdiary-firebase-prod`.
- **How to Fix**:
  1. Go to Google Cloud Console: https://console.cloud.google.com/
  2. In the top project dropdown, switch to **`magicdiary-firebase-prod`**.
  3. Go to **IAM & Admin > Service Accounts**.
  4. Create or select a service account with roles:
     - `Firebase Cloud Messaging Admin`
     - `Cloud Datastore User`
  5. Go to the **Keys** tab > **Add Key** > **Create new key** > **JSON**.
  6. Open the newly downloaded `.json` file and verify line 4 shows:
     ```json
     "project_id": "magicdiary-firebase-prod"
     ```
  7. In your GitHub repository, go to **Settings > Secrets and variables > Actions**.
  8. Update `FIREBASE_PROJECT_ID` to: `magicdiary-firebase-prod`.
  9. Update `FIREBASE_SERVICE_ACCOUNT` with the entire contents of this new JSON key.

---

## 6. Summary Checklist

- [ ] Firebase Service Account created with `Firebase Cloud Messaging Admin` and `Cloud Datastore User` roles.
- [ ] Service Account JSON key saved into GitHub Repository Secrets as `FIREBASE_SERVICE_ACCOUNT`.
- [ ] `FIREBASE_PROJECT_ID` configured in GitHub Repository Secrets.
- [ ] (Optional) Alert webhook secrets configured (`TELEGRAM_BOT_TOKEN`, `DISCORD_WEBHOOK_URL`, etc.).
- [ ] Workflow manually tested via **Actions > Run workflow** with `dry_run = true`.
- [ ] Verified live run in GitHub Actions logs and Firestore records.
