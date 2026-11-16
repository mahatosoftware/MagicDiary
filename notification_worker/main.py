"""Main entry point for Magic Diary GitHub Actions Notification Worker.

Can be run locally or within a GitHub Actions workflow:
    python -m notification_worker.main [--dry-run] [--lookahead-minutes 30] [--batch-size 100]
"""

from __future__ import annotations

import argparse
import json
import logging
import sys

from notification_worker.config import WorkerConfig
from notification_worker.worker import NotificationWorker


def setup_logging() -> None:
    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s [%(levelname)s] %(name)s - %(message)s",
        datefmt="%Y-%m-%d %H:%M:%S",
    )


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="MagicDiary Notification Worker for GitHub Actions"
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Simulate run without writing to Firestore or dispatching FCM messages.",
    )
    parser.add_argument(
        "--lookahead-minutes",
        type=int,
        default=None,
        help="Minutes in advance to search for eligible notifications (default: 30).",
    )
    parser.add_argument(
        "--batch-size",
        type=int,
        default=None,
        help="Maximum schedules to evaluate per run (default: 100).",
    )
    return parser.parse_args()


def main() -> int:
    setup_logging()
    logger = logging.getLogger("notification_worker.main")
    args = parse_args()

    config = WorkerConfig(
        dry_run=args.dry_run,
        lookahead_minutes=args.lookahead_minutes or 30,
        batch_size=args.batch_size or 100,
    )

    try:
        config.validate()
    except ValueError as e:
        logger.error("Configuration validation failed: %s", e)
        return 1

    try:
        worker = NotificationWorker(config)
        summary = worker.run()

        # Emit summary output
        summary_dict = {
            "worker_id": summary.worker_id,
            "processed": summary.processed_count,
            "sent": summary.sent_count,
            "cancelled": summary.cancelled_count,
            "skipped": summary.skipped_count,
            "failed": summary.failed_count,
            "cleaned_tokens": summary.cleaned_tokens_count,
            "error_count": len(summary.errors),
        }
        print("\n" + "=" * 60)
        print("MAGICDIARY NOTIFICATION WORKER EXECUTION SUMMARY")
        print("=" * 60)
        print(json.dumps(summary_dict, indent=2))
        print("=" * 60 + "\n")

        return 0
    except Exception as e:
        logger.critical("Fatal exception in notification worker: %s", e, exc_info=True)
        return 1


if __name__ == "__main__":
    sys.exit(main())
