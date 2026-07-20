from __future__ import annotations

from typing import Any, Literal

from pydantic import BaseModel, Field


class ErrorDetail(BaseModel):
    code: str
    message: str
    details: dict[str, Any] = Field(default_factory=dict)


class ErrorEnvelope(BaseModel):
    ok: bool = False
    error: ErrorDetail


class CapabilityStatus(BaseModel):
    name: str
    status: Literal["available", "not_implemented", "reserved"]
    description: str


class HealthResponse(BaseModel):
    ok: bool = True
    service: str
    version: str
    status: Literal["ok"]
    timestamp: str
    capabilities: list[CapabilityStatus]


class RepoStatus(BaseModel):
    root: str
    checked_at: str
    is_git_repo: bool
    status: Literal["clean", "dirty", "not_a_git_repo", "git_unavailable", "error"]
    branch: str | None = None
    commit: str | None = None
    dirty: bool | None = None
    changed_files: list[str] = Field(default_factory=list)
    message: str


class RepoStatusEnvelope(BaseModel):
    ok: bool = True
    repo: RepoStatus


class ReportRecord(BaseModel):
    run_id: str
    report_type: str
    status: str
    created_at: str
    summary: str
    details: dict[str, Any] = Field(default_factory=dict)
    path: str | None = None


class ReportEnvelope(BaseModel):
    ok: bool = True
    report: ReportRecord


class ReportIndexFile(BaseModel):
    reports: list[ReportRecord] = Field(default_factory=list)


class TerminalRunRequest(BaseModel):
    command: str = Field(min_length=1)
    shell: Literal["powershell", "pwsh", "cmd"] = "powershell"
    cwd: str | None = None
    expected_root: str | None = None
    wait_timeout_seconds: int | None = Field(default=None, ge=0, le=300)
    timeout_seconds: int | None = Field(default=None, ge=1, le=300)
    runtime_limit_seconds: int | None = Field(default=None, ge=1, le=86400)
    request_id: str | None = None


class ContextCheckRequest(BaseModel):
    expected_root: str = Field(min_length=1)
    cwd: str | None = None


class ContextCheckResult(BaseModel):
    expected_root: str
    actual_cwd: str
    actual_root: str | None = None
    git_root: str | None = None
    branch: str | None = None
    head: str | None = None
    dirty: bool | None = None
    context_status: Literal["READY", "CONTEXT_MISMATCH", "UNKNOWN", "BLOCKED"]
    command_allowed: bool
    command_started: bool = False
    action_taken: Literal["checked_only"] = "checked_only"
    root_cause: str
    owner_action: str
    next_actions: list[str] = Field(default_factory=list)


class ContextCheckEnvelope(BaseModel):
    ok: bool = True
    result: ContextCheckResult


class RunWaitRequest(BaseModel):
    wait_timeout_seconds: int | None = Field(default=None, ge=0, le=300)
    wait_seconds: int | None = Field(default=None, ge=0, le=300)

    def resolved_wait_seconds(self, default: int = 60) -> int:
        if self.wait_seconds is not None:
            return self.wait_seconds
        if self.wait_timeout_seconds is not None:
            return self.wait_timeout_seconds
        return default


class RequestControlBundle(BaseModel):
    request_id: str
    received_at: str
    command_sha256: str
    validation_status: str
    auth_status: str
    authenticated: bool
    auth_method: str
    normalized_cwd: str
    shell: Literal["powershell", "pwsh", "cmd"]
    wait_timeout_seconds: int | None = None
    timeout_seconds: int | None = None
    runtime_limit_seconds: int | None = None


class TerminalRunResult(BaseModel):
    run_id: str
    request_id: str
    received_at: str
    command_sha256: str
    validation_status: str
    auth_status: str
    authenticated: bool
    request_control: RequestControlBundle
    status: str
    command: str
    cwd: str
    normalized_cwd: str
    shell: Literal["powershell", "pwsh", "cmd"]
    shell_executable: str
    pid: int | None = None
    process_alive: bool
    exit_code: int | None
    timed_out: bool = False
    started_at: str
    last_seen_at: str | None = None
    checked_at: str | None = None
    finished_at: str | None = None
    duration_ms: int | None = None
    elapsed_ms: int
    waited_ms: int | None = None
    wait_elapsed_ms: int | None = None
    artifact_dir: str
    stdout_path: str
    stderr_path: str
    result_path: str
    report_path: str
    stdout_preview: str = ""
    stderr_preview: str = ""
    stdout_tail: str = ""
    stderr_tail: str = ""
    choices: list[str] = Field(default_factory=list)


class TerminalRunEnvelope(BaseModel):
    ok: bool = True
    result: TerminalRunResult


class RunLogsEnvelope(BaseModel):
    ok: bool = True
    run_id: str
    status: str
    process_alive: bool
    stdout_path: str
    stderr_path: str
    stdout_tail: str = ""
    stderr_tail: str = ""


class CodexHandoffRequest(BaseModel):
    task_path: str
    instructions: str | None = None
