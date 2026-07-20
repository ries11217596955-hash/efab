from __future__ import annotations

import shutil
import subprocess
from pathlib import Path

from bridge_app.core.config import BridgeSettings
from bridge_app.core.models import ContextCheckRequest, ContextCheckResult


def check_route_context(request: ContextCheckRequest, settings: BridgeSettings) -> ContextCheckResult:
    expected_root = _resolve_expected_root(request.expected_root, settings.root_dir)
    actual_cwd = _resolve_cwd(request.cwd, settings.root_dir)
    if not actual_cwd.exists() or not actual_cwd.is_dir():
        return ContextCheckResult(
            expected_root=str(expected_root),
            actual_cwd=str(actual_cwd),
            actual_root=None,
            context_status="UNKNOWN",
            command_allowed=False,
            root_cause="Context could not be checked because actual_cwd does not exist or is not a directory.",
            owner_action="Verify the requested cwd manually, open the intended repo/root, and retry.",
            next_actions=[
                "Check that cwd exists.",
                f"Open VS Code/Codex/terminal in {expected_root}.",
                "Retry after confirming the route context.",
            ],
        )

    git_root = _git_text(actual_cwd, "rev-parse", "--show-toplevel")
    actual_root = Path(git_root).resolve() if git_root else actual_cwd.resolve()
    branch = _git_text(actual_cwd, "branch", "--show-current") if git_root else None
    head = _git_text(actual_cwd, "rev-parse", "--short", "HEAD") if git_root else None
    dirty = _git_dirty(actual_cwd) if git_root else None

    if _same_path(expected_root, actual_root):
        return ContextCheckResult(
            expected_root=str(expected_root),
            actual_cwd=str(actual_cwd),
            actual_root=str(actual_root),
            git_root=str(Path(git_root).resolve()) if git_root else None,
            branch=branch,
            head=head,
            dirty=dirty,
            context_status="READY",
            command_allowed=True,
            root_cause="Actual root matches expected_root.",
            owner_action="No owner action required; route context is ready.",
            next_actions=["Command execution may proceed."],
        )

    return ContextCheckResult(
        expected_root=str(expected_root),
        actual_cwd=str(actual_cwd),
        actual_root=str(actual_root),
        git_root=str(Path(git_root).resolve()) if git_root else None,
        branch=branch,
        head=head,
        dirty=dirty,
        context_status="CONTEXT_MISMATCH",
        command_allowed=False,
        root_cause="Actual root does not match expected_root.",
        owner_action=f"Open VS Code/Codex/terminal in {expected_root} and retry.",
        next_actions=[
            f"Expected root: {expected_root}",
            f"Actual root: {actual_root}",
            "Do not retry command execution until the route context is corrected.",
        ],
    )


def blocked_command_payload(result: ContextCheckResult) -> dict:
    return {
        "ok": False,
        "error": {
            "code": result.context_status,
            "message": "Command was not executed because route context is not ready.",
            "root_cause": result.root_cause,
            "expected_root": result.expected_root,
            "actual_root": result.actual_root,
            "actual_cwd": result.actual_cwd,
            "git_root": result.git_root,
            "owner_action": result.owner_action,
            "next_actions": result.next_actions,
        },
        "command_allowed": False,
        "command_started": False,
    }


def _resolve_expected_root(expected_root: str, root_dir: Path) -> Path:
    path = Path(expected_root)
    if not path.is_absolute():
        path = root_dir / path
    return path.resolve()


def _resolve_cwd(cwd: str | None, root_dir: Path) -> Path:
    path = Path(cwd) if cwd else root_dir
    if not path.is_absolute():
        path = root_dir / path
    return path.resolve()


def _same_path(left: Path, right: Path) -> bool:
    return str(left.resolve()).casefold() == str(right.resolve()).casefold()


def _git_text(cwd: Path, *args: str) -> str | None:
    if shutil.which("git") is None:
        return None
    completed = subprocess.run(
        ["git", "-C", str(cwd), *args],
        capture_output=True,
        text=True,
        timeout=10,
        check=False,
    )
    if completed.returncode != 0:
        return None
    value = completed.stdout.strip()
    return value or None


def _git_dirty(cwd: Path) -> bool | None:
    if shutil.which("git") is None:
        return None
    completed = subprocess.run(
        ["git", "-C", str(cwd), "status", "--short"],
        capture_output=True,
        text=True,
        timeout=10,
        check=False,
    )
    if completed.returncode != 0:
        return None
    return bool(completed.stdout.strip())
