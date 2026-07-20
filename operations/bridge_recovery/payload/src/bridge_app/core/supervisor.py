from __future__ import annotations

import hashlib
import json
import shutil
import subprocess
import time
from dataclasses import dataclass
from pathlib import Path
from threading import RLock
from typing import BinaryIO
from uuid import uuid4

from bridge_app.core.auth import AuthContext
from bridge_app.core.config import BridgeSettings
from bridge_app.core.errors import BridgeError
from bridge_app.core.models import RequestControlBundle, TerminalRunRequest, TerminalRunResult
from bridge_app.core.time import utc_now_iso
from bridge_app.storage.reports import ReportStore


@dataclass
class ManagedRun:
    run_id: str
    request: TerminalRunRequest
    request_control: RequestControlBundle
    process: subprocess.Popen[bytes]
    started_at: str
    start_perf: float
    cwd: Path
    shell_executable: str
    artifact_dir: Path
    stdout_path: Path
    stderr_path: Path
    result_path: Path
    report_path: Path
    stdout_file: BinaryIO
    stderr_file: BinaryIO
    status: str = "running"
    finished_at: str | None = None
    exit_code: int | None = None
    handles_closed: bool = False


class RunSupervisor:
    def __init__(self, settings: BridgeSettings, report_store: ReportStore) -> None:
        self.settings = settings
        self.report_store = report_store
        self._runs: dict[str, ManagedRun] = {}
        self._lock = RLock()

    def start(self, request: TerminalRunRequest, auth_context: AuthContext) -> TerminalRunResult:
        cwd = self._resolve_cwd(request.cwd)
        shell_executable = self._resolve_shell(request.shell)
        request_control = self._request_control(request, cwd, auth_context)
        run_id = self._make_run_id()
        artifact_dir = self.settings.runs_dir / run_id
        artifact_dir.mkdir(parents=True, exist_ok=True)
        stdout_path = artifact_dir / "stdout.txt"
        stderr_path = artifact_dir / "stderr.txt"
        result_path = artifact_dir / "result.json"
        report_path = self.report_store.reports_dir / f"{run_id}.json"
        stdout_file = stdout_path.open("wb")
        stderr_file = stderr_path.open("wb")
        started_at = utc_now_iso()

        try:
            process = subprocess.Popen(
                self._shell_args(request.shell, shell_executable, request.command),
                cwd=str(cwd),
                stdout=stdout_file,
                stderr=stderr_file,
                creationflags=self._creation_flags(),
            )
        except Exception:
            stdout_file.close()
            stderr_file.close()
            raise

        managed = ManagedRun(
            run_id=run_id,
            request=request,
            request_control=request_control,
            process=process,
            started_at=started_at,
            start_perf=time.perf_counter(),
            cwd=cwd,
            shell_executable=shell_executable,
            artifact_dir=artifact_dir,
            stdout_path=stdout_path,
            stderr_path=stderr_path,
            result_path=result_path,
            report_path=report_path,
            stdout_file=stdout_file,
            stderr_file=stderr_file,
        )
        with self._lock:
            self._runs[run_id] = managed
        return self.snapshot(run_id)

    def wait(self, run_id: str, wait_timeout_seconds: int) -> TerminalRunResult:
        managed = self._get(run_id)
        wait_started = time.perf_counter()
        try:
            managed.process.wait(timeout=wait_timeout_seconds)
        except subprocess.TimeoutExpired:
            pass
        wait_elapsed_ms = round((time.perf_counter() - wait_started) * 1000)
        return self.snapshot(run_id, wait_elapsed_ms=wait_elapsed_ms)

    def stop(self, run_id: str) -> TerminalRunResult:
        managed = self._get(run_id)
        if managed.process.poll() is None:
            managed.status = "stop_requested"
            self._taskkill(managed.process.pid, force=False)
            if self._verify_dead(managed, timeout_seconds=3):
                managed.status = "stopped_verified"
            else:
                managed.status = "stop_requested"
        return self.snapshot(run_id)

    def kill(self, run_id: str) -> TerminalRunResult:
        managed = self._get(run_id)
        if managed.process.poll() is None:
            managed.status = "kill_requested"
            self._taskkill(managed.process.pid, force=True)
            if self._verify_dead(managed, timeout_seconds=5):
                managed.status = "killed_verified"
            else:
                managed.status = "orphan_suspected"
        return self.snapshot(run_id)

    def logs(self, run_id: str) -> tuple[TerminalRunResult, str, str]:
        result = self.snapshot(run_id)
        return result, result.stdout_tail, result.stderr_tail

    def snapshot(self, run_id: str, wait_elapsed_ms: int | None = None) -> TerminalRunResult:
        managed = self._get(run_id)
        self._refresh_lifecycle(managed)
        process_alive = managed.process.poll() is None
        checked_at = utc_now_iso()
        elapsed_ms = round((time.perf_counter() - managed.start_perf) * 1000)
        duration_ms = elapsed_ms if managed.finished_at else None
        stdout_tail = self._tail(managed.stdout_path)
        stderr_tail = self._tail(managed.stderr_path)
        status = managed.status
        if wait_elapsed_ms is not None and process_alive:
            status = "wait_expired_still_running"

        result = TerminalRunResult(
            run_id=managed.run_id,
            request_id=managed.request_control.request_id,
            received_at=managed.request_control.received_at,
            command_sha256=managed.request_control.command_sha256,
            validation_status=managed.request_control.validation_status,
            auth_status=managed.request_control.auth_status,
            authenticated=managed.request_control.authenticated,
            request_control=managed.request_control,
            status=status,
            command=managed.request.command,
            cwd=str(managed.cwd),
            normalized_cwd=str(managed.cwd),
            shell=managed.request.shell,
            shell_executable=managed.shell_executable,
            pid=managed.process.pid,
            process_alive=process_alive,
            exit_code=managed.exit_code,
            timed_out=False,
            started_at=managed.started_at,
            last_seen_at=checked_at,
            checked_at=checked_at,
            finished_at=managed.finished_at,
            duration_ms=duration_ms,
            elapsed_ms=elapsed_ms,
            waited_ms=wait_elapsed_ms,
            wait_elapsed_ms=wait_elapsed_ms,
            artifact_dir=str(managed.artifact_dir),
            stdout_path=str(managed.stdout_path),
            stderr_path=str(managed.stderr_path),
            result_path=str(managed.result_path),
            report_path=str(managed.report_path),
            stdout_preview=stdout_tail,
            stderr_preview=stderr_tail,
            stdout_tail=stdout_tail,
            stderr_tail=stderr_tail,
            choices=self._choices(process_alive),
        )
        self._write_result_and_report(result)
        return result

    def _refresh_lifecycle(self, managed: ManagedRun) -> None:
        returncode = managed.process.poll()
        if returncode is None:
            if self._runtime_limit_exceeded(managed):
                managed.status = "runtime_limit_exceeded"
                self._taskkill(managed.process.pid, force=True)
                self._verify_dead(managed, timeout_seconds=5)
            returncode = managed.process.poll()

        if returncode is None:
            if managed.status not in {"stop_requested", "kill_requested", "orphan_suspected"}:
                managed.status = "running"
            return

        managed.exit_code = returncode
        if managed.finished_at is None:
            managed.finished_at = utc_now_iso()
        self._close_handles(managed)
        if managed.status in {"stopped_verified", "killed_verified", "runtime_limit_exceeded"}:
            return
        managed.status = "completed_success" if returncode == 0 else "completed_failed"

    def _runtime_limit_exceeded(self, managed: ManagedRun) -> bool:
        limit = managed.request.runtime_limit_seconds
        if limit is None:
            return False
        return (time.perf_counter() - managed.start_perf) >= limit

    def _verify_dead(self, managed: ManagedRun, timeout_seconds: int) -> bool:
        deadline = time.perf_counter() + timeout_seconds
        while time.perf_counter() < deadline:
            if managed.process.poll() is not None:
                managed.exit_code = managed.process.returncode
                if managed.finished_at is None:
                    managed.finished_at = utc_now_iso()
                self._close_handles(managed)
                return True
            time.sleep(0.05)
        return managed.process.poll() is not None

    def _taskkill(self, pid: int, force: bool) -> None:
        args = ["taskkill", "/PID", str(pid), "/T"]
        if force:
            args.append("/F")
        subprocess.run(args, capture_output=True, text=True, check=False, timeout=10)

    def _write_result_and_report(self, result: TerminalRunResult) -> None:
        self._write_json(Path(result.result_path), result.model_dump(mode="json"))
        self.report_store.write_report(
            report_type="terminal_run",
            status=result.status,
            summary=f"Managed run is {result.status}.",
            details={
                "terminal_run": result.model_dump(mode="json"),
                "managed_run": result.model_dump(mode="json"),
                "request_control": result.request_control.model_dump(mode="json"),
            },
            run_id=result.run_id,
        )

    def _get(self, run_id: str) -> ManagedRun:
        with self._lock:
            managed = self._runs.get(run_id)
        if managed is None:
            raise BridgeError(
                code="RUN_NOT_FOUND",
                message=f"Run '{run_id}' was not found in the active supervisor.",
                status_code=404,
                details={"run_id": run_id},
            )
        return managed

    def _request_control(
        self,
        request: TerminalRunRequest,
        cwd: Path,
        auth_context: AuthContext,
    ) -> RequestControlBundle:
        wait_timeout_seconds = self.resolve_wait_timeout(request)
        return RequestControlBundle(
            request_id=request.request_id or f"req-{uuid4().hex}",
            received_at=utc_now_iso(),
            command_sha256=hashlib.sha256(request.command.encode("utf-8")).hexdigest(),
            validation_status="validated",
            auth_status=auth_context.auth_status,
            authenticated=auth_context.authenticated,
            auth_method=auth_context.auth_method,
            normalized_cwd=str(cwd),
            shell=request.shell,
            wait_timeout_seconds=wait_timeout_seconds,
            timeout_seconds=wait_timeout_seconds,
            runtime_limit_seconds=request.runtime_limit_seconds,
        )

    def resolve_wait_timeout(self, request: TerminalRunRequest) -> int:
        if request.wait_timeout_seconds is not None:
            return request.wait_timeout_seconds
        if request.timeout_seconds is not None:
            return request.timeout_seconds
        return 60

    def _resolve_cwd(self, requested_cwd: str | None) -> Path:
        if requested_cwd:
            candidate = Path(requested_cwd)
            if not candidate.is_absolute():
                candidate = self.settings.root_dir / candidate
        else:
            candidate = self.settings.root_dir
        resolved = candidate.resolve()
        if not resolved.exists() or not resolved.is_dir():
            raise BridgeError(
                code="INVALID_CWD",
                message="Terminal run cwd must be an existing directory.",
                status_code=400,
                details={"cwd": str(resolved)},
            )
        return resolved

    def _resolve_shell(self, shell: str) -> str:
        candidates = {
            "powershell": ["powershell", "pwsh"],
            "pwsh": ["pwsh"],
            "cmd": ["cmd"],
        }[shell]
        for candidate in candidates:
            found = shutil.which(candidate)
            if found:
                return found
        raise BridgeError(
            code="SHELL_NOT_FOUND",
            message=f"Requested shell '{shell}' was not found on PATH.",
            status_code=400,
            details={"shell": shell, "candidates": candidates},
        )

    def _shell_args(self, shell: str, executable: str, command: str) -> list[str]:
        if shell in {"powershell", "pwsh"}:
            return [
                executable,
                "-NoProfile",
                "-NonInteractive",
                "-ExecutionPolicy",
                "Bypass",
                "-Command",
                self._powershell_command_wrapper(command),
            ]
        if shell == "cmd":
            return [executable, "/C", command]
        raise BridgeError(
            code="SHELL_NOT_SUPPORTED",
            message=f"Requested shell '{shell}' is not supported.",
            status_code=400,
            details={"shell": shell},
        )

    def _powershell_command_wrapper(self, command: str) -> str:
        return "\n".join(
            [
                "$global:LASTEXITCODE = $null",
                "& {",
                command,
                "}",
                "$bridgeCommandSucceeded = $?",
                "$bridgeLastExitCode = $global:LASTEXITCODE",
                "if ($null -ne $bridgeLastExitCode) { exit $bridgeLastExitCode }",
                "if ($bridgeCommandSucceeded) { exit 0 }",
                "exit 1",
            ]
        )

    def _tail(self, path: Path, limit: int = 4000) -> str:
        if not path.exists():
            return ""
        data = path.read_bytes()
        if len(data) > limit:
            data = data[-limit:]
        return data.decode("utf-8", errors="replace")

    def _choices(self, process_alive: bool) -> list[str]:
        if process_alive:
            return ["check_status", "wait", "stop", "kill"]
        return ["read_logs", "read_report"]

    def _make_run_id(self) -> str:
        stamp = utc_now_iso().replace("-", "").replace(":", "").replace("Z", "")
        stamp = stamp.replace("T", "-")
        return f"managed_run-{stamp}-{uuid4().hex[:8]}"

    def _creation_flags(self) -> int:
        return getattr(subprocess, "CREATE_NEW_PROCESS_GROUP", 0)

    def _close_handles(self, managed: ManagedRun) -> None:
        if managed.handles_closed:
            return
        managed.stdout_file.close()
        managed.stderr_file.close()
        managed.handles_closed = True

    def _write_json(self, path: Path, data: dict) -> None:
        path.write_text(json.dumps(data, indent=2, sort_keys=True) + "\n", encoding="utf-8")
