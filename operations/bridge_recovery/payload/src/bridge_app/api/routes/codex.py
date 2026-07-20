from __future__ import annotations

from pathlib import Path
from uuid import uuid4

from fastapi import APIRouter, Depends, HTTPException, Request
from pydantic import BaseModel, Field

from bridge_app.core.auth import AuthContext, require_auth
from bridge_app.core.models import TerminalRunEnvelope, TerminalRunRequest
from bridge_app.operations.terminal import terminal_run


router = APIRouter(prefix="/codex", tags=["codex"])


class CodexRunnerV01Request(BaseModel):
    repo_root: str = Field(min_length=1)
    allowed_output: list[str] = Field(min_length=1)
    task_text: str | None = Field(default=None, min_length=1)
    task_file: str | None = Field(default=None, min_length=1)
    mode: str = Field(default="bypass", pattern="^(workspace-write|read-only|bypass)$")
    timeout_sec: int = Field(default=180, ge=1, le=86400)
    wait_timeout_seconds: int = Field(default=30, ge=0, le=300)
    runtime_limit_seconds: int | None = Field(default=None, ge=1, le=86400)
    require_clean_allowed_outputs: bool = False
    request_id: str | None = None


@router.post("/runner/v0_1", response_model=TerminalRunEnvelope)
def run_codex_runner_v0_1(
    request_body: CodexRunnerV01Request,
    request: Request,
    auth_context: AuthContext = Depends(require_auth),
) -> TerminalRunEnvelope:
    bridge_root = _bridge_root()
    runner_path = bridge_root / "codex_runner_v0_1.ps1"
    if not runner_path.exists():
        raise HTTPException(status_code=503, detail={"status": "CODEX_RUNNER_SCRIPT_MISSING", "path": str(runner_path)})

    task_file = _resolve_task_file(request_body, bridge_root)
    command = _build_runner_command(runner_path, request_body, task_file)
    run_request = TerminalRunRequest(
        command=command,
        shell="powershell",
        cwd=str(bridge_root),
        expected_root=str(bridge_root),
        wait_timeout_seconds=request_body.wait_timeout_seconds,
        runtime_limit_seconds=request_body.runtime_limit_seconds or (request_body.timeout_sec + 60),
        request_id=request_body.request_id,
    )
    result = terminal_run(run_request, supervisor=request.app.state.run_supervisor, auth_context=auth_context)
    return TerminalRunEnvelope(result=result)


def _bridge_root() -> Path:
    # <bridge-root>\src\bridge_app\api\routes\codex.py -> <bridge-root>
    return Path(__file__).resolve().parents[4]


def _resolve_task_file(request_body: CodexRunnerV01Request, bridge_root: Path) -> Path:
    if bool(request_body.task_text) == bool(request_body.task_file):
        raise HTTPException(status_code=400, detail="Provide exactly one of task_text or task_file.")
    if request_body.task_file:
        return Path(request_body.task_file).resolve()
    task_dir = bridge_root / "codex_runner_endpoint_tasks"
    task_dir.mkdir(parents=True, exist_ok=True)
    task_path = task_dir / f"codex_runner_task_{uuid4().hex}.md"
    task_path.write_text(request_body.task_text or "", encoding="utf-8")
    return task_path


def _build_runner_command(runner_path: Path, request_body: CodexRunnerV01Request, task_file: Path) -> str:
    allowed = "@(" + ",".join(_ps_quote(item) for item in request_body.allowed_output) + ")"
    parts = [
        "&",
        _ps_quote(str(runner_path)),
        "-RepoRoot",
        _ps_quote(request_body.repo_root),
        "-TaskFile",
        _ps_quote(str(task_file)),
        "-AllowedOutput",
        allowed,
        "-Mode",
        _ps_quote(request_body.mode),
        "-TimeoutSec",
        str(request_body.timeout_sec),
    ]
    if request_body.require_clean_allowed_outputs:
        parts.append("-RequireCleanAllowedOutputs")
    return " ".join(parts)


def _ps_quote(value: str) -> str:
    return "'" + value.replace("'", "''") + "'"

