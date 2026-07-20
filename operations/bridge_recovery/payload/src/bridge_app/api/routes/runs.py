from __future__ import annotations

from fastapi import APIRouter, Body, Depends, Query, Request
from fastapi.responses import JSONResponse

from bridge_app.core.auth import AuthContext, require_auth
from bridge_app.core.context_check import blocked_command_payload, check_route_context
from bridge_app.core.models import ContextCheckRequest, RunLogsEnvelope, RunWaitRequest, TerminalRunEnvelope, TerminalRunRequest

router = APIRouter(prefix="/runs", tags=["runs"])


@router.post("/start", response_model=TerminalRunEnvelope)
def start_run(
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
    result = request.app.state.run_supervisor.start(request_body, auth_context)
    return TerminalRunEnvelope(result=result)


@router.get("/{run_id}/status", response_model=TerminalRunEnvelope)
def run_status(
    run_id: str,
    request: Request,
    auth_context: AuthContext = Depends(require_auth),
) -> TerminalRunEnvelope:
    _ = auth_context
    result = request.app.state.run_supervisor.snapshot(run_id)
    return TerminalRunEnvelope(result=result)


@router.post("/{run_id}/wait", response_model=TerminalRunEnvelope)
def wait_run(
    run_id: str,
    request: Request,
    request_body: RunWaitRequest | None = Body(default=None),
    wait_seconds: int | None = Query(default=None, ge=0, le=300),
    wait_timeout_seconds: int | None = Query(default=None, ge=0, le=300),
    auth_context: AuthContext = Depends(require_auth),
) -> TerminalRunEnvelope:
    _ = auth_context
    resolved_wait_seconds = _resolve_wait_seconds(
        request_body=request_body,
        wait_seconds=wait_seconds,
        wait_timeout_seconds=wait_timeout_seconds,
    )
    result = request.app.state.run_supervisor.wait(run_id, resolved_wait_seconds)
    return TerminalRunEnvelope(result=result)


def _resolve_wait_seconds(
    request_body: RunWaitRequest | None,
    wait_seconds: int | None,
    wait_timeout_seconds: int | None,
) -> int:
    if wait_seconds is not None:
        return wait_seconds
    if wait_timeout_seconds is not None:
        return wait_timeout_seconds
    if request_body is not None:
        return request_body.resolved_wait_seconds()
    return 60


@router.get("/{run_id}/logs", response_model=RunLogsEnvelope)
def run_logs(
    run_id: str,
    request: Request,
    auth_context: AuthContext = Depends(require_auth),
) -> RunLogsEnvelope:
    _ = auth_context
    result, stdout_tail, stderr_tail = request.app.state.run_supervisor.logs(run_id)
    return RunLogsEnvelope(
        run_id=run_id,
        status=result.status,
        process_alive=result.process_alive,
        stdout_path=result.stdout_path,
        stderr_path=result.stderr_path,
        stdout_tail=stdout_tail,
        stderr_tail=stderr_tail,
    )


@router.post("/{run_id}/stop", response_model=TerminalRunEnvelope)
def stop_run(
    run_id: str,
    request: Request,
    auth_context: AuthContext = Depends(require_auth),
) -> TerminalRunEnvelope:
    _ = auth_context
    result = request.app.state.run_supervisor.stop(run_id)
    return TerminalRunEnvelope(result=result)


@router.post("/{run_id}/kill", response_model=TerminalRunEnvelope)
def kill_run(
    run_id: str,
    request: Request,
    auth_context: AuthContext = Depends(require_auth),
) -> TerminalRunEnvelope:
    _ = auth_context
    result = request.app.state.run_supervisor.kill(run_id)
    return TerminalRunEnvelope(result=result)
