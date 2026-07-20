from __future__ import annotations

from fastapi import APIRouter, Depends, Request

from bridge_app.core.auth import AuthContext, require_auth
from bridge_app.core.errors import BridgeError
from bridge_app.core.models import ReportEnvelope

router = APIRouter(prefix="/reports", tags=["reports"])


@router.get("/latest", response_model=ReportEnvelope)
def latest_report(
    request: Request,
    auth_context: AuthContext = Depends(require_auth),
) -> ReportEnvelope:
    _ = auth_context
    report_store = request.app.state.report_store
    report = report_store.latest()
    if report is None:
        raise BridgeError(
            code="NO_REPORTS",
            message="No reports have been written yet.",
            status_code=404,
        )
    return ReportEnvelope(report=report)


@router.get("/{run_id}", response_model=ReportEnvelope)
def report_by_run_id(
    run_id: str,
    request: Request,
    auth_context: AuthContext = Depends(require_auth),
) -> ReportEnvelope:
    _ = auth_context
    report_store = request.app.state.report_store
    report = report_store.get(run_id)
    if report is None:
        raise BridgeError(
            code="REPORT_NOT_FOUND",
            message=f"Report '{run_id}' was not found.",
            status_code=404,
            details={"run_id": run_id},
        )
    return ReportEnvelope(report=report)
