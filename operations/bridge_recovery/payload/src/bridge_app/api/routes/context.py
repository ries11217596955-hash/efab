from __future__ import annotations

from fastapi import APIRouter, Depends, Request

from bridge_app.core.auth import AuthContext, require_auth
from bridge_app.core.context_check import check_route_context
from bridge_app.core.models import ContextCheckEnvelope, ContextCheckRequest

router = APIRouter(prefix="/context", tags=["context"])


@router.post("/check", response_model=ContextCheckEnvelope)
def context_check(
    request_body: ContextCheckRequest,
    request: Request,
    auth_context: AuthContext = Depends(require_auth),
) -> ContextCheckEnvelope:
    _ = auth_context
    result = check_route_context(request_body, request.app.state.settings)
    return ContextCheckEnvelope(result=result)
