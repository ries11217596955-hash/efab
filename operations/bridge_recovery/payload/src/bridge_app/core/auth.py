from __future__ import annotations

from dataclasses import dataclass
from hmac import compare_digest

from fastapi import Request

from bridge_app.core.errors import BridgeError


@dataclass(frozen=True)
class AuthContext:
    authenticated: bool
    auth_status: str
    auth_method: str


def require_auth(request: Request) -> AuthContext:
    settings = request.app.state.settings
    expected_token = settings.auth_token
    if not expected_token:
        raise BridgeError(
            code="AUTH_NOT_CONFIGURED",
            message="Bridge auth token is not configured.",
            status_code=503,
        )

    provided_token, auth_method = _extract_token(request)
    if not provided_token:
        raise BridgeError(
            code="AUTH_REQUIRED",
            message="A valid Bridge auth token is required.",
            status_code=401,
        )
    if not compare_digest(provided_token, expected_token):
        raise BridgeError(
            code="AUTH_INVALID",
            message="Bridge auth token is invalid.",
            status_code=403,
        )
    return AuthContext(
        authenticated=True,
        auth_status="authenticated",
        auth_method=auth_method,
    )


def _extract_token(request: Request) -> tuple[str | None, str]:
    bridge_token = request.headers.get("x-bridge-token")
    if bridge_token:
        return bridge_token, "x_bridge_token"

    authorization = request.headers.get("authorization")
    if not authorization:
        return None, "missing"
    scheme, _, token = authorization.partition(" ")
    if scheme.lower() == "bearer" and token:
        return token, "authorization_bearer"
    return None, "unsupported_authorization"
