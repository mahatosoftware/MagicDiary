"""Tests for WorkerConfig."""

import json
import pytest
from notification_worker.config import WorkerConfig


def test_config_defaults():
    config = WorkerConfig(lookahead_minutes=45, dry_run=True)
    assert config.lookahead_minutes == 45
    assert config.dry_run is True
    assert config.batch_size == 100
    assert config.max_retries == 3


def test_config_service_account_json_parsing():
    sa_dict = {"project_id": "test-project", "private_key": "dummy"}
    config = WorkerConfig(service_account=json.dumps(sa_dict))
    parsed = config.get_service_account_dict()
    assert parsed == sa_dict


def test_config_validation_requires_creds_when_not_dry_run():
    config = WorkerConfig(project_id="", service_account="", dry_run=False)
    with pytest.raises(ValueError, match="FIREBASE_PROJECT_ID"):
        config.validate()

    config2 = WorkerConfig(project_id="my-proj", service_account="", dry_run=False)
    with pytest.raises(ValueError, match="FIREBASE_SERVICE_ACCOUNT"):
        config2.validate()


def test_config_validation_succeeds_in_dry_run_without_creds():
    config = WorkerConfig(project_id="", service_account="", dry_run=True)
    config.validate()  # Should not raise


def test_config_validation_detects_project_id_mismatch():
    sa_dict = {"project_id": "Kittycircle-firebase-prod", "private_key": "dummy"}
    config = WorkerConfig(
        project_id="magicdiary-firebase-prod",
        service_account=json.dumps(sa_dict),
        dry_run=False,
    )
    with pytest.raises(ValueError, match="Project ID mismatch"):
        config.validate()


def test_config_validation_infers_project_id_from_service_account():
    sa_dict = {"project_id": "magicdiary-firebase-prod", "private_key": "dummy"}
    config = WorkerConfig(
        project_id="",
        service_account=json.dumps(sa_dict),
        dry_run=False,
    )
    config.validate()
    assert config.project_id == "magicdiary-firebase-prod"

