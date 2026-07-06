# D2B / Long-Run Failure Recovery and Resume

## Purpose
Use this when a large autonomous run is not finished and has a recoverable failure. The goal is not to celebrate partial progress. The goal is to keep accepted surfaces safe, identify whether the failure is zero-surface or partial-surface, repair the runtime path if needed, and resume from checkpoint.

## When to use
- `queue_empty=false`.
- `status=HARD_ERROR`, `STOPPED_RESUMABLE`, `RUNNING_READY_TO_RESUME`, or similar.
- `processed_count` is far below total material.
- A failed candidate exists, but accepted memory may already contain previous successful candidates.
- Owner is asking what to do while another autonomous run is alive.

## Core rule
Never restart a long run from zero while resumable state exists unless fresh proof shows the checkpoint is corrupt and recovery is impossible. Never rollback accepted surfaces blindly.

## Procedure
1. Freeze interpretation. Do not call the run complete.
2. Read `resume_state.json` and the main proof JSON.
3. Identify failed candidate id, atom id, error, visibility counts, and last checkpoint.
4. Classify the failed surface:
   - `zero surface`: memory=0, self_map=0, registry=0. The candidate did not become accepted. It can be quarantined/rejected and the run can continue.
   - `partial surface`: one or more surfaces changed. Stop and reconcile. Do not resume.
5. Check counts: `accepted_count` must represent visible accepted atoms, not attempted accepts.
6. Preserve audit trail: record the failed candidate, reason, visibility counts and repair action.
7. Run validator. Expected state after recoverable repair is incomplete/resumable, not completed.
8. Resume with `-Resume`, never by deleting output and starting over.
9. Observe heartbeat and checkpoints without mutating accepted surfaces.
10. Finalize only when `queue_empty=true`, `failed_count=0` or blocked failures are explicitly reconciled, and validator says completed.

## Proof needed
- fresh terminal repo identity;
- proof JSON summary;
- validator output;
- resume_state summary;
- git status;
- report path.

## Stop conditions
- partial surface detected;
- protected state mutation outside expected surface;
- checkpoint corruption;
- accepted_count mismatch;
- missing proof/report/validator.

## Owner output
Report result as `resumable`, `blocked`, or `completed`. Do not say `done` until final proof exists.

## Related heavy-process cards
- `heavy_process_reference.autonomous_long_run_recovery_and_resume.v1` — Autonomous Long Run Recovery And Resume
- `heavy_process_reference.phase162_acceptance_pipeline_reconciliation.v1` — Phase162 Acceptance Pipeline Reconciliation
- `heavy_process_reference.zero_surface_vs_partial_surface_failure.v1` — Zero Surface Vs Partial Surface Failure
- `heavy_process_reference.checkpoint_resume_runtime_design.v1` — Checkpoint Resume Runtime Design
- `heavy_process_reference.parallel_sidecar_work_during_live_run.v1` — Parallel Sidecar Work During Live Run
- `heavy_process_reference.failure_taxonomy_and_triage.v1` — Failure Taxonomy And Triage

## Operator Notes
This runbook is not a primitive concept explanation. It is a process reference. Read it when the task has risk, ambiguity, live state, protected surfaces, external material, or proof requirements.

## Atomization Note
This runbook is not accepted memory. A future atom may be proposed only after the runbook helps solve a real task gap and the result has proof/use.
