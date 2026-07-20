from __future__ import annotations

from bridge_app.adapters.git import GitAdapter
from bridge_app.core.config import BridgeSettings
from bridge_app.core.models import RepoStatus


def get_repo_status(settings: BridgeSettings) -> RepoStatus:
    return GitAdapter().status(settings.root_dir)
