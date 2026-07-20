from __future__ import annotations

from typing import NoReturn

from bridge_app.adapters.codex import CodexAdapter
from bridge_app.core.models import CodexHandoffRequest


def codex_handoff(request: CodexHandoffRequest) -> NoReturn:
    return CodexAdapter().handoff(request)
