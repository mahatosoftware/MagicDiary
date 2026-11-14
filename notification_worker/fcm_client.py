"""FCM Client for sending remote notifications using FCM HTTP v1 via Firebase Admin SDK.

Supports:
- High-priority Android channels & tags
- APNs alerts with badges & sound
- Error classification and invalid token identification for automatic cleanup
- Delivery distinguishing between FCM acceptance and errors
"""

from __future__ import annotations

import logging
from dataclasses import dataclass, field
from typing import Any, Dict, List, Optional

import firebase_admin
from firebase_admin import credentials, messaging
from notification_worker.config import WorkerConfig

logger = logging.getLogger(__name__)


@dataclass
class FcmSendResult:
    success_count: int = 0
    failure_count: int = 0
    invalid_tokens: List[str] = field(default_factory=list)
    errors: List[str] = field(default_factory=list)

    @property
    def is_delivered(self) -> bool:
        return self.success_count > 0


class FcmClient:
    def __init__(self, config: WorkerConfig) -> None:
        self.config = config
        self._app: Optional[firebase_admin.App] = None
        if not config.dry_run:
            self._init_firebase()

    def _init_firebase(self) -> None:
        """Initializes Firebase Admin SDK app idempotently."""
        try:
            self._app = firebase_admin.get_app()
        except ValueError:
            sa_dict = self.config.get_service_account_dict()
            if sa_dict:
                cred = credentials.Certificate(sa_dict)
                self._app = firebase_admin.initialize_app(
                    cred,
                    {"projectId": self.config.project_id},
                )
            else:
                logger.warning("No credentials found; attempting default app initialization.")
                self._app = firebase_admin.initialize_app()

    def send_notification(
        self,
        tokens: List[str],
        title: str,
        body: str,
        data_payload: Dict[str, Any],
        channel_id: str = "financial_reminders",
        delivery_key: Optional[str] = None,
    ) -> FcmSendResult:
        """Sends push notification to multiple device tokens using FCM HTTP v1."""
        if not tokens:
            return FcmSendResult(failure_count=0, errors=["No device tokens provided."])

        if self.config.dry_run:
            logger.info(
                "[DRY RUN] Would send FCM HTTP v1 push to %d tokens: '%s' - '%s'",
                len(tokens),
                title,
                body,
            )
            return FcmSendResult(success_count=len(tokens), failure_count=0)

        # Stringify all data payload values for FCM HTTP v1 specification
        stringified_data: Dict[str, str] = {
            str(k): str(v) if v is not None else ""
            for k, v in data_payload.items()
        }
        if delivery_key:
            stringified_data["deliveryKey"] = delivery_key

        messages: List[messaging.Message] = []
        for token in tokens:
            android_config = messaging.AndroidConfig(
                priority="high",
                notification=messaging.AndroidNotification(
                    channel_id=channel_id,
                    sound="default",
                    click_action="FLUTTER_NOTIFICATION_CLICK",
                    tag=delivery_key or None,
                ),
            )

            apns_config = messaging.APNSConfig(
                headers={"apns-priority": "10"},
                payload=messaging.APNSPayload(
                    aps=messaging.Aps(
                        alert=messaging.ApsAlert(title=title, body=body),
                        sound="default",
                        badge=1,
                    )
                ),
            )

            msg = messaging.Message(
                token=token,
                notification=messaging.Notification(title=title, body=body),
                data=stringified_data,
                android=android_config,
                apns=apns_config,
            )
            messages.append(msg)

        result = FcmSendResult()
        try:
            batch_response = messaging.send_each(messages)
            for idx, resp in enumerate(batch_response.responses):
                token = tokens[idx]
                if resp.success:
                    result.success_count += 1
                else:
                    result.failure_count += 1
                    err = resp.exception
                    err_msg = str(err) if err else "Unknown FCM error"
                    result.errors.append(f"Token {token[:10]}...: {err_msg}")

                    # Check for invalid / expired / unregistered token
                    if self._is_invalid_token_error(err):
                        logger.info("Detected invalid/unregistered token: %s...", token[:10])
                        result.invalid_tokens.append(token)
        except Exception as e:
            logger.error("Failed to execute FCM send_each: %s", e)
            result.failure_count += len(tokens)
            result.errors.append(str(e))

        return result

    @staticmethod
    def _is_invalid_token_error(exception: Optional[Exception]) -> bool:
        """Determines if the FCM exception indicates a stale or invalid device token."""
        if not exception:
            return False
        msg = str(exception).lower()
        return any(
            indicator in msg
            for indicator in (
                "unregistered",
                "not_found",
                "invalid_argument",
                "registration-token-not-registered",
                "not-registered",
                "invalid-registration-token",
            )
        )
