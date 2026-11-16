"""Configuration module for Magic Diary GitHub Actions Notification Worker.

Reads configuration from environment variables with sensible defaults.
Supports FIREBASE_SERVICE_ACCOUNT as either a raw JSON string or a file path.
"""

from __future__ import annotations

import json
import os
from typing import Any, Dict, Optional

try:
    from dotenv import load_dotenv
    load_dotenv()
except ImportError:
    pass


class WorkerConfig:
    def __init__(
        self,
        project_id: Optional[str] = None,
        service_account: Optional[str] = None,
        lookahead_minutes: int = 30,
        batch_size: int = 100,
        max_retries: int = 3,
        claim_lease_seconds: int = 300,
        dry_run: bool = False,
        timezone_default: str = "UTC",
    ) -> None:
        self.project_id = project_id or os.getenv("FIREBASE_PROJECT_ID", "")
        self.service_account_raw = service_account or os.getenv("FIREBASE_SERVICE_ACCOUNT", "")
        self.lookahead_minutes = int(os.getenv("LOOKAHEAD_MINUTES", str(lookahead_minutes)))
        self.batch_size = int(os.getenv("BATCH_SIZE", str(batch_size)))
        self.max_retries = int(os.getenv("MAX_RETRIES", str(max_retries)))
        self.claim_lease_seconds = int(os.getenv("CLAIM_LEASE_SECONDS", str(claim_lease_seconds)))
        self.dry_run = (
            dry_run
            or os.getenv("DRY_RUN", "false").lower() in ("true", "1", "yes")
        )
        self.timezone_default = os.getenv("DEFAULT_TIMEZONE", timezone_default)

    def get_service_account_dict(self) -> Optional[Dict[str, Any]]:
        """Parses service account credentials from either raw JSON or file path."""
        if not self.service_account_raw:
            return None

        # Try parsing as JSON string directly (GitHub Secrets standard)
        try:
            return json.loads(self.service_account_raw)
        except (json.JSONDecodeError, TypeError):
            pass

        # Try reading as a local file path
        if os.path.exists(self.service_account_raw):
            try:
                with open(self.service_account_raw, "r", encoding="utf-8") as f:
                    return json.load(f)
            except Exception as e:
                raise ValueError(f"Failed to read service account file: {e}") from e

        raise ValueError(
            "FIREBASE_SERVICE_ACCOUNT is neither valid JSON string nor existing file path."
        )

    def validate(self) -> None:
        """Validates critical worker configuration."""
        if not self.dry_run:
            sa_dict = None
            if self.service_account_raw:
                sa_dict = self.get_service_account_dict()

            sa_project_id = sa_dict.get("project_id") if isinstance(sa_dict, dict) else None
            if not self.project_id and sa_project_id:
                self.project_id = sa_project_id

            if not self.project_id:
                raise ValueError("FIREBASE_PROJECT_ID environment variable is required.")
            if not self.service_account_raw:
                raise ValueError("FIREBASE_SERVICE_ACCOUNT environment variable is required.")

            if sa_project_id and self.project_id and sa_project_id != self.project_id:
                raise ValueError(
                    f"Project ID mismatch: FIREBASE_PROJECT_ID is '{self.project_id}', "
                    f"but the service account key belongs to '{sa_project_id}'. "
                    f"Please generate the service account key from project '{self.project_id}'."
                )
