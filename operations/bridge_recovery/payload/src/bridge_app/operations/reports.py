from __future__ import annotations

from bridge_app.core.models import ReportRecord
from bridge_app.storage.reports import ReportStore


def get_latest_report(report_store: ReportStore) -> ReportRecord | None:
    return report_store.latest()


def get_report(report_store: ReportStore, run_id: str) -> ReportRecord | None:
    return report_store.get(run_id)
