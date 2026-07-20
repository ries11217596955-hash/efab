# Local Bridge

Local Bridge is a local FastAPI service for structured local operations, reports, and GPT Action compatible OpenAPI access.

This foundation work creates the final project skeleton and proves the first working endpoints. Terminal run is implemented as a managed-run wrapper. Managed run start/status/wait/logs/stop/kill endpoints are available. Codex automation, VS Code/editor control, progress events, repo mutation, tunnel deployment, and secrets handling are not implemented yet.

## Install

From `<bridge-root>`:

```powershell
python -m pip install -e ".[dev]"
```

## Start

```powershell
python -m uvicorn bridge_app.main:app --app-dir src --host 127.0.0.1 --port 8765
```

## Read Checks

In another terminal:

```powershell
Invoke-RestMethod http://127.0.0.1:8765/health
Invoke-RestMethod http://127.0.0.1:8765/repo/status
Invoke-RestMethod http://127.0.0.1:8765/reports/latest
Invoke-RestMethod http://127.0.0.1:8765/openapi.json
```

The service writes JSON reports under `reports/` and keeps a small `reports/index.json`. Terminal runs also write per-run artifacts under `runs/<run_id>/`.

## Terminal Run

```powershell
$body = @{ command = "python --version"; shell = "powershell"; timeout_seconds = 10 } | ConvertTo-Json
Invoke-RestMethod -Method Post -Uri http://127.0.0.1:8765/terminal/run -ContentType "application/json" -Body $body
```

The command is passed exactly to the selected shell. The response includes `run_id`, lifecycle `status`, `process_alive`, `exit_code` when complete, timing, stdout/stderr previews, and artifact/report paths. If the caller wait expires while the process is still alive, the response says `wait_expired_still_running` rather than pretending the run finished.

## Implemented Now

- `GET /health`
- `GET /repo/status`
- `GET /reports/latest`
- `GET /reports/{run_id}`
- `POST /terminal/run`
- `POST /runs/start`
- `GET /runs/{run_id}/status`
- `POST /runs/{run_id}/wait`
- `GET /runs/{run_id}/logs`
- `POST /runs/{run_id}/stop`
- `POST /runs/{run_id}/kill`
- FastAPI OpenAPI schema at `/openapi.json`
- Report writer and report index
- Read-only git status detection when Git is available
- Managed terminal execution with stdout/stderr/report artifacts

## Reserved For Later Passes

The codebase includes module slots for Codex handoff and future repo operations. These slots raise clear `NOT_IMPLEMENTED` errors until a later construction pass implements them. VS Code/editor control and progress/event streaming are not implemented.

See [docs/OWNER_START_READ_WORKFLOW.md](docs/OWNER_START_READ_WORKFLOW.md) for the Owner start/read workflow.

