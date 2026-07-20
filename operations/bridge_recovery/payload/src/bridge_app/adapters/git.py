from __future__ import annotations

import shutil
import subprocess
from pathlib import Path

from bridge_app.core.models import RepoStatus
from bridge_app.core.time import utc_now_iso


class GitAdapter:
    """Read-only git adapter used by the foundation repo status endpoint."""

    def status(self, root_dir: Path) -> RepoStatus:
        root = Path(root_dir).resolve()
        checked_at = utc_now_iso()

        if shutil.which("git") is None:
            return RepoStatus(
                root=str(root),
                checked_at=checked_at,
                is_git_repo=False,
                status="git_unavailable",
                message="Git executable was not found on PATH.",
            )

        inside = self._git(root, "rev-parse", "--is-inside-work-tree")
        if inside.returncode != 0 or inside.stdout.strip().lower() != "true":
            return RepoStatus(
                root=str(root),
                checked_at=checked_at,
                is_git_repo=False,
                status="not_a_git_repo",
                message="Root is not inside a Git work tree.",
            )

        top_level = self._git(root, "rev-parse", "--show-toplevel").stdout.strip() or str(root)
        branch = self._git(root, "branch", "--show-current").stdout.strip() or None
        commit = self._git(root, "rev-parse", "--short", "HEAD").stdout.strip() or None
        status = self._git(root, "status", "--short")
        changed_files = [line for line in status.stdout.splitlines() if line.strip()]
        dirty = bool(changed_files)

        return RepoStatus(
            root=top_level,
            checked_at=checked_at,
            is_git_repo=True,
            status="dirty" if dirty else "clean",
            branch=branch,
            commit=commit,
            dirty=dirty,
            changed_files=changed_files,
            message="Git work tree has changes." if dirty else "Git work tree is clean.",
        )

    def _git(self, root: Path, *args: str) -> subprocess.CompletedProcess[str]:
        return subprocess.run(
            ["git", "-C", str(root), *args],
            capture_output=True,
            text=True,
            timeout=10,
            check=False,
        )
