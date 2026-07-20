from __future__ import annotations

from fastapi import APIRouter, Depends, Request

from bridge_app.core.auth import AuthContext, require_auth
from bridge_app.core.models import RepoStatusEnvelope
from bridge_app.operations.repo import get_repo_status

router = APIRouter(prefix="/repo", tags=["repo"])


@router.get("/status", response_model=RepoStatusEnvelope)
def repo_status(
    request: Request,
    auth_context: AuthContext = Depends(require_auth),
) -> RepoStatusEnvelope:
    _ = auth_context
    settings = request.app.state.settings
    status = get_repo_status(settings)
    return RepoStatusEnvelope(repo=status)
