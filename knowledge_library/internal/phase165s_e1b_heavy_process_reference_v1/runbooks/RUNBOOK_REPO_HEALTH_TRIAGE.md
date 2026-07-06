# Repo Health Triage

## Purpose
Use before important terminal work and after any code-generation repair.

## Procedure
1. `Get-Location`.
2. Check repo signs: `CAPABILITY_ROADMAP.json`, `GENESIS_STATE.json`, `TASK_QUEUE.json`, `packs/registry.json`, `orchestrator/run.ps1`.
3. Check branch.
4. Check `HEAD` and `origin/<branch>` if remote truth matters.
5. Check `git status --short`.
6. Separate tracked modifications from untracked files.
7. Classify dirty state by phase.
8. Never call repo clean/synced without fresh output.

## Output
- repo identity;
- branch;
- head/origin;
- dirty state;
- phase-owned files;
- unknown files;
- safe next action.

## Related heavy-process cards
- `heavy_process_reference.autonomous_long_run_recovery_and_resume.v1` — Autonomous Long Run Recovery And Resume
- `heavy_process_reference.phase162_acceptance_pipeline_reconciliation.v1` — Phase162 Acceptance Pipeline Reconciliation
- `heavy_process_reference.zero_surface_vs_partial_surface_failure.v1` — Zero Surface Vs Partial Surface Failure
- `heavy_process_reference.repo_identity_dirty_state_triage.v1` — Repo Identity Dirty State Triage
- `heavy_process_reference.validator_proof_report_contract.v1` — Validator Proof Report Contract
- `heavy_process_reference.failure_taxonomy_and_triage.v1` — Failure Taxonomy And Triage

## Operator Notes
This runbook is not a primitive concept explanation. It is a process reference. Read it when the task has risk, ambiguity, live state, protected surfaces, external material, or proof requirements.

## Atomization Note
This runbook is not accepted memory. A future atom may be proposed only after the runbook helps solve a real task gap and the result has proof/use.
