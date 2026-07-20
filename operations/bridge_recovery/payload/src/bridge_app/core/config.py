from __future__ import annotations

import os
from functools import lru_cache
from pathlib import Path

from pydantic import BaseModel, ConfigDict

from bridge_app import __version__


class BridgeSettings(BaseModel):
    model_config = ConfigDict(arbitrary_types_allowed=True)

    service_name: str = "Local Bridge"
    version: str = __version__
    root_dir: Path = Path.cwd()
    reports_dir: Path | None = None
    runs_dir: Path | None = None
    schemas_dir: Path | None = None
    auth_token: str | None = None

    def model_post_init(self, __context: object) -> None:
        self.root_dir = Path(self.root_dir).resolve()
        self.reports_dir = Path(self.reports_dir or self.root_dir / "reports").resolve()
        self.runs_dir = Path(self.runs_dir or self.root_dir / "runs").resolve()
        self.schemas_dir = Path(self.schemas_dir or self.root_dir / "schemas").resolve()


def load_settings() -> BridgeSettings:
    root = Path(os.getenv("BRIDGE_ROOT", Path.cwd()))
    return BridgeSettings(
        service_name=os.getenv("BRIDGE_SERVICE_NAME", "Local Bridge"),
        root_dir=root,
        reports_dir=_optional_path_env("BRIDGE_REPORTS_DIR"),
        runs_dir=_optional_path_env("BRIDGE_RUNS_DIR"),
        schemas_dir=_optional_path_env("BRIDGE_SCHEMAS_DIR"),
        auth_token=os.getenv("BRIDGE_AUTH_TOKEN"),
    )


def _optional_path_env(name: str) -> Path | None:
    value = os.getenv(name)
    if not value:
        return None
    return Path(value)


@lru_cache(maxsize=1)
def get_settings() -> BridgeSettings:
    return load_settings()
