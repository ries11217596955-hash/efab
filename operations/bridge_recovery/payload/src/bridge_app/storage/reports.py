from __future__ import annotations

import json
import re
from pathlib import Path
from uuid import uuid4

from bridge_app.core.config import BridgeSettings
from bridge_app.core.models import ReportIndexFile, ReportRecord
from bridge_app.core.time import utc_now_iso


class ReportStore:
    def __init__(self, reports_dir: Path) -> None:
        self.reports_dir = Path(reports_dir).resolve()
        self.index_path = self.reports_dir / "index.json"

    def ensure_startup_report(self, settings: BridgeSettings) -> ReportRecord:
        latest = self.latest()
        if latest is not None:
            return latest
        return self.write_report(
            report_type="bridge_startup",
            status="ok",
            summary="Local Bridge foundation API initialized.",
            details={
                "service": settings.service_name,
                "root_dir": str(settings.root_dir),
                "implemented": [
                    "health",
                    "repo_status",
                    "reports",
                    "openapi",
                    "terminal_run",
                    "managed_run_lifecycle",
                ],
                "not_implemented": [
                    "codex_handoff",
                    "progress_events",
                    "repo_mutation",
                    "tunnel_deployment",
                    "secrets_handling",
                ],
            },
        )

    def write_report(
        self,
        report_type: str,
        status: str,
        summary: str,
        details: dict | None = None,
        run_id: str | None = None,
    ) -> ReportRecord:
        self.reports_dir.mkdir(parents=True, exist_ok=True)
        created_at = utc_now_iso()
        resolved_run_id = run_id or self._make_run_id(report_type, created_at)
        path = self.reports_dir / f"{resolved_run_id}.json"
        record = ReportRecord(
            run_id=resolved_run_id,
            report_type=report_type,
            status=status,
            created_at=created_at,
            summary=summary,
            details=details or {},
            path=str(path),
        )
        self._write_json(path, record.model_dump(mode="json"))
        self._update_index(record)
        return record

    def latest(self) -> ReportRecord | None:
        index = self._read_index()
        if not index.reports:
            return None
        latest_record = sorted(index.reports, key=lambda item: item.created_at)[-1]
        return self.get(latest_record.run_id) or latest_record

    def get(self, run_id: str) -> ReportRecord | None:
        safe_run_id = self._safe_run_id(run_id)
        if safe_run_id != run_id:
            return None
        path = self.reports_dir / f"{safe_run_id}.json"
        if not path.exists():
            return None
        data = json.loads(path.read_text(encoding="utf-8"))
        return ReportRecord.model_validate(data)

    def _update_index(self, record: ReportRecord) -> None:
        index = self._read_index()
        records = [item for item in index.reports if item.run_id != record.run_id]
        records.append(record)
        records.sort(key=lambda item: item.created_at)
        self._write_json(
            self.index_path,
            ReportIndexFile(reports=records).model_dump(mode="json"),
        )

    def _read_index(self) -> ReportIndexFile:
        if not self.index_path.exists():
            return ReportIndexFile()
        data = json.loads(self.index_path.read_text(encoding="utf-8"))
        return ReportIndexFile.model_validate(data)

    def _write_json(self, path: Path, data: dict) -> None:
        path.parent.mkdir(parents=True, exist_ok=True)
        tmp_path = path.with_suffix(path.suffix + ".tmp")
        tmp_path.write_text(json.dumps(data, indent=2, sort_keys=True) + "\n", encoding="utf-8")
        tmp_path.replace(path)

    def _make_run_id(self, report_type: str, created_at: str) -> str:
        stamp = created_at.replace("-", "").replace(":", "").replace("Z", "")
        stamp = stamp.replace("T", "-")
        return f"{self._safe_run_id(report_type)}-{stamp}-{uuid4().hex[:8]}"

    def _safe_run_id(self, value: str) -> str:
        return re.sub(r"[^A-Za-z0-9_.-]", "-", value).strip(".-")[:120]
