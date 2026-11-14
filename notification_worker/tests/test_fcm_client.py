"""Tests for FcmClient and FCM HTTP v1 dispatch."""

from unittest.mock import MagicMock, patch
from notification_worker.config import WorkerConfig
from notification_worker.fcm_client import FcmClient, FcmSendResult


def test_dry_run_send_succeeds_without_firebase():
    config = WorkerConfig(dry_run=True)
    client = FcmClient(config)

    result = client.send_notification(
        tokens=["token_abc", "token_xyz"],
        title="Test Bill",
        body="Bill is due tomorrow",
        data_payload={"recordId": "rec_1", "amount": 100},
        channel_id="financial_urgent",
        delivery_key="user_1_rec_1_0d",
    )

    assert result.is_delivered is True
    assert result.success_count == 2
    assert result.failure_count == 0


def test_empty_tokens_returns_safe_failure():
    config = WorkerConfig(dry_run=True)
    client = FcmClient(config)

    result = client.send_notification(
        tokens=[],
        title="Test",
        body="Test",
        data_payload={},
    )
    assert result.is_delivered is False
    assert result.success_count == 0


def test_invalid_token_classification():
    assert FcmClient._is_invalid_token_error(Exception("The registration token is unregistered")) is True
    assert FcmClient._is_invalid_token_error(Exception("Requested entity was not_found")) is True
    assert FcmClient._is_invalid_token_error(Exception("Network timeout error")) is False


@patch("notification_worker.fcm_client.messaging.send_each")
def test_send_notification_detects_invalid_tokens_and_prunes(mock_send_each):
    config = WorkerConfig(dry_run=False, project_id="test", service_account='{"project_id": "test"}')

    with patch.object(FcmClient, "_init_firebase"):
        client = FcmClient(config)

        # Mock responses: 1 success, 1 unregistered failure
        resp_success = MagicMock(success=True, exception=None)
        resp_unregistered = MagicMock(
            success=False,
            exception=Exception("registration-token-not-registered: Token is invalid"),
        )
        mock_send_each.return_value = MagicMock(responses=[resp_success, resp_unregistered])

        result = client.send_notification(
            tokens=["valid_token", "stale_token"],
            title="School Fee Due",
            body="Installment #2 due today",
            data_payload={"recordId": "inst_2"},
        )

        assert result.success_count == 1
        assert result.failure_count == 1
        assert "stale_token" in result.invalid_tokens
        assert result.is_delivered is True
