from __future__ import annotations

from fastapi import APIRouter, Request

from bridge_app.core.models import CapabilityStatus, HealthResponse
from bridge_app.core.time import utc_now_iso

router = APIRouter(tags=["health"])


@router.get("/health", response_model=HealthResponse)
def get_health(request: Request) -> HealthResponse:
    settings = request.app.state.settings
    return HealthResponse(
        service=settings.service_name,
        version=settings.version,
        status="ok",
        timestamp=utc_now_iso(),
        capabilities=[
            CapabilityStatus(
                name="health",
                status="available",
                description="API health endpoint is implemented.",
            ),
            CapabilityStatus(
                name="repo_status",
                status="available",
                description="Read-only repository status detection is implemented.",
            ),
            CapabilityStatus(
                name="reports",
                status="available",
                description="JSON report writing and retrieval are implemented.",
            ),
            CapabilityStatus(
                name="terminal_run",
                status="available",
                description="Terminal execution is implemented as a managed-run wrapper.",
            ),
            CapabilityStatus(
                name="managed_run_lifecycle",
                status="available",
                description="Managed run start, status, wait, logs, stop, and kill endpoints are implemented.",
            ),
            CapabilityStatus(
                name="codex_handoff",
                status="not_implemented",
                description="Codex handoff is reserved for a later pass.",
            ),
            CapabilityStatus(
                name="progress_events",
                status="not_implemented",
                description="Long-running progress or event streaming is not implemented.",
            ),
        ],
    )

