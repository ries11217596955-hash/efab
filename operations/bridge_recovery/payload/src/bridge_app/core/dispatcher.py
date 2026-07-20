from __future__ import annotations

from collections.abc import Callable
from typing import Any

from bridge_app.core.errors import NotImplementedCapabilityError


class OperationDispatcher:
    """Small operation registry for future route-to-operation wiring."""

    def __init__(self) -> None:
        self._handlers: dict[str, Callable[..., Any]] = {}

    def register(self, name: str, handler: Callable[..., Any]) -> None:
        self._handlers[name] = handler

    def dispatch(self, name: str, **kwargs: Any) -> Any:
        handler = self._handlers.get(name)
        if handler is None:
            raise NotImplementedCapabilityError(
                capability=name,
                message=f"Operation '{name}' is not implemented in this build pass.",
            )
        return handler(**kwargs)
