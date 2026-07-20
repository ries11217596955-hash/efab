from __future__ import annotations

from fastapi import FastAPI

from bridge_app import __version__
from bridge_app.api.routes import codex, context, health, repo, reports, runs, terminal
from bridge_app.core.config import BridgeSettings, load_settings
from bridge_app.core.errors import BridgeError, bridge_error_handler
from bridge_app.core.supervisor import RunSupervisor
from bridge_app.storage.reports import ReportStore


def create_app(settings: BridgeSettings | None = None) -> FastAPI:
    resolved_settings = settings or load_settings()

    app = FastAPI(
        title="Local Bridge",
        version=__version__,
        description="Local execution and reporting bridge foundation API.",
    )
    app.state.settings = resolved_settings
    app.state.report_store = ReportStore(resolved_settings.reports_dir)
    app.state.run_supervisor = RunSupervisor(resolved_settings, app.state.report_store)
    startup_report = app.state.report_store.ensure_startup_report(resolved_settings)
    app.state.startup_report_run_id = startup_report.run_id

    app.add_exception_handler(BridgeError, bridge_error_handler)
    app.include_router(health.router)
    app.include_router(context.router)
    app.include_router(repo.router)
    app.include_router(reports.router)
    app.include_router(terminal.router)
    app.include_router(runs.router)
    app.include_router(codex.router)
    return app


app = create_app()

