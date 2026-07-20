from __future__ import annotations

from bridge_app.core.auth import AuthContext
from bridge_app.core.config import BridgeSettings
from bridge_app.core.models import TerminalRunRequest, TerminalRunResult
from bridge_app.core.supervisor import RunSupervisor
from bridge_app.storage.reports import ReportStore


class TerminalAdapter:
    """Compatibility adapter backed by the managed run supervisor."""

    def run(
        self,
        request: TerminalRunRequest,
        settings: BridgeSettings,
        report_store: ReportStore,
        auth_context: AuthContext,
    ) -> TerminalRunResult:
        supervisor = RunSupervisor(settings, report_store)
        started = supervisor.start(request, auth_context)
        if not started.process_alive:
            return started
        return supervisor.wait(started.run_id, supervisor.resolve_wait_timeout(request))
