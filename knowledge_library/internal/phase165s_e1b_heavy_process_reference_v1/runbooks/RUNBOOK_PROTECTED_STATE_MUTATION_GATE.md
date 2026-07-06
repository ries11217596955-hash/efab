# Protected State Mutation Gate

## Protected surfaces
`TASK_QUEUE.json`, `GENESIS_STATE.json`, `CAPABILITY_ROADMAP.json`, `packs/registry.json`, `orchestrator/run.ps1`.

## Purpose
Prevent incidental damage to Builder identity, route, queue, registry and orchestrator.

## Gate
A protected-state change is allowed only when it has:
1. explicit route step or Owner approval;
2. candidate description;
3. risk review;
4. compatibility check;
5. limited apply plan;
6. validator;
7. proof JSON;
8. report;
9. self-map refresh if required.

## Procedure
1. Precheck repo identity and branch.
2. Record protected file hashes before change.
3. Apply the smallest change.
4. Run validators and parse JSON proof.
5. Compare protected hashes after change.
6. If unexpected protected mutation happened, stop and quarantine.
7. If expected mutation succeeded, refresh derived maps only through approved mechanism.
8. Commit only after proof and Owner decision when needed.

## Sidecar exception
Sidecar libraries and staged materials may create files under `knowledge_library`, `materials`, `reports`, `proofs` and `validators` if they do not change protected files.

## Related heavy-process cards
- `heavy_process_reference.autonomous_long_run_recovery_and_resume.v1` — Autonomous Long Run Recovery And Resume
- `heavy_process_reference.phase162_acceptance_pipeline_reconciliation.v1` — Phase162 Acceptance Pipeline Reconciliation
- `heavy_process_reference.zero_surface_vs_partial_surface_failure.v1` — Zero Surface Vs Partial Surface Failure
- `heavy_process_reference.protected_state_mutation_gate.v1` — Protected State Mutation Gate
- `heavy_process_reference.repo_identity_dirty_state_triage.v1` — Repo Identity Dirty State Triage

## Operator Notes
This runbook is not a primitive concept explanation. It is a process reference. Read it when the task has risk, ambiguity, live state, protected surfaces, external material, or proof requirements.

## Atomization Note
This runbook is not accepted memory. A future atom may be proposed only after the runbook helps solve a real task gap and the result has proof/use.
