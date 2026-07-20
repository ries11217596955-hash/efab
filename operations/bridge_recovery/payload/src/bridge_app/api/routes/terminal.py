from __future__ import annotations

from fastapi import APIRouter, Depends, Request
from fastapi.responses import JSONResponse

from bridge_app.core.auth import AuthContext, require_auth
from bridge_app.core.context_check import blocked_command_payload, check_route_context
from bridge_app.core.models import ContextCheckRequest
from bridge_app.core.models import TerminalRunEnvelope, TerminalRunRequest
from bridge_app.operations.terminal import terminal_run

router = APIRouter(prefix="/terminal", tags=["terminal"])


@router.post("/run", response_model=TerminalRunEnvelope)
def run_terminal_command(
    request_body: TerminalRunRequest,
    request: Request,
    auth_context: AuthContext = Depends(require_auth),
) -> TerminalRunEnvelope:
    if request_body.expected_root:
        context_result = check_route_context(
            ContextCheckRequest(expected_root=request_body.expected_root, cwd=request_body.cwd),
            request.app.state.settings,
        )
        if context_result.context_status != "READY":
            return JSONResponse(
                status_code=409,
                content=blocked_command_payload(context_result),
            )
    result = terminal_run(
        request_body,
        supervisor=request.app.state.run_supervisor,
        auth_context=auth_context,
    )
    return TerminalRunEnvelope(result=result)
