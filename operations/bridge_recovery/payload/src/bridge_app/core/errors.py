from __future__ import annotations

from typing import Any

from fastapi import Request
from fastapi.responses import JSONResponse

from bridge_app.core.models import ErrorDetail, ErrorEnvelope


class BridgeError(Exception):
    def __init__(
        self,
        code: str,
        message: str,
        status_code: int = 400,
        details: dict[str, Any] | None = None,
    ) -> None:
        super().__init__(message)
        self.code = code
        self.message = message
        self.status_code = status_code
        self.details = details or {}


class NotImplementedCapabilityError(BridgeError):
    def __init__(self, capability: str, message: str | None = None) -> None:
        super().__init__(
            code="NOT_IMPLEMENTED",
            message=message or f"Capability '{capability}' is not implemented.",
            status_code=501,
            details={"capability": capability},
        )


async def bridge_error_handler(request: Request, exc: BridgeError) -> JSONResponse:
    error = ErrorEnvelope(
        error=ErrorDetail(
            code=exc.code,
            message=exc.message,
            details=exc.details,
        )
    )
    return JSONResponse(
        status_code=exc.status_code,
        content=error.model_dump(mode="json"),
    )
