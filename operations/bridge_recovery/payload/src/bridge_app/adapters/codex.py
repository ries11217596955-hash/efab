from __future__ import annotations

from typing import NoReturn

from bridge_app.core.errors import NotImplementedCapabilityError
from bridge_app.core.models import CodexHandoffRequest


class CodexAdapter:
    """Reserved adapter for future Codex CLI handoff."""

    def handoff(self, request: CodexHandoffRequest) -> NoReturn:
        raise NotImplementedCapabilityError(
            capability="codex_handoff",
            message="Codex handoff is not implemented in this foundation pass.",
        )
