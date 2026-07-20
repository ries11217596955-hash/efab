from __future__ import annotations

from bridge_app.core.auth import AuthContext
from bridge_app.core.models import TerminalRunRequest, TerminalRunResult
from bridge_app.core.supervisor import RunSupervisor


def terminal_run(
    request: TerminalRunRequest,
    supervisor: RunSupervisor,
    auth_context: AuthContext,
) -> TerminalRunResult:
    started = supervisor.start(request, auth_context)
    if not started.process_alive:
        return started
    return supervisor.wait(started.run_id, supervisor.resolve_wait_timeout(request))
