from __future__ import annotations

from enum import Enum

from bridge_app.core.errors import NotImplementedCapabilityError


class RunState(str, Enum):
    CREATED = "created"
    RUNNING = "running"
    SUCCEEDED = "succeeded"
    FAILED = "failed"
    CANCELLED = "cancelled"


class DetachedRunLifecycle:
    """Reserved lifecycle surface for future detached runs."""

    def start(self, command: str) -> None:
        raise NotImplementedCapabilityError(
            capability="detached_runs",
            message="Detached run lifecycle is not implemented in this foundation pass.",
        )

    def cancel(self, run_id: str) -> None:
        raise NotImplementedCapabilityError(
            capability="detached_runs",
            message="Detached run cancellation is not implemented in this foundation pass.",
        )
