# Route Lock Evolution

## Purpose
Use when a route has completed its locked steps or a new strategic direction emerges.

## Procedure
1. Identify active route lock and latest proof.
2. List completed locked steps with fresh evidence.
3. List unfinished, blocked or superseded steps.
4. For new idea, classify:
   - fits current locked step;
   - sidecar that does not disturb route;
   - route change request;
   - next route lock candidate.
5. Do not silently replace active route.
6. After 10-15 locked steps are completed, draft next route lock version.
7. Archive superseded rules with reason.

## Output
- `ROUTE_CHANGE_REQUEST` if changing now.
- `NEXT_ROUTE_LOCK_DRAFT` if preparing next version.
- `SIDECAR_APPROVED` if parallel safe.

## Related heavy-process cards
- `heavy_process_reference.autonomous_long_run_recovery_and_resume.v1` — Autonomous Long Run Recovery And Resume
- `heavy_process_reference.phase162_acceptance_pipeline_reconciliation.v1` — Phase162 Acceptance Pipeline Reconciliation
- `heavy_process_reference.zero_surface_vs_partial_surface_failure.v1` — Zero Surface Vs Partial Surface Failure
- `heavy_process_reference.route_lock_change_control.v1` — Route Lock Change Control

## Operator Notes
This runbook is not a primitive concept explanation. It is a process reference. Read it when the task has risk, ambiguity, live state, protected surfaces, external material, or proof requirements.

## Atomization Note
This runbook is not accepted memory. A future atom may be proposed only after the runbook helps solve a real task gap and the result has proof/use.
