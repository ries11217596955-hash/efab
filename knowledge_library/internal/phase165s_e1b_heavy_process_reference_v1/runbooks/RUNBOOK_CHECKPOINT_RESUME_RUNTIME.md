# Checkpoint / Resume Runtime

## Purpose
Use for any long autonomous loop.

## Required runtime state
- total candidates;
- processed_count;
- accepted_count;
- quarantine_count;
- denied_count;
- failed_count;
- recovered_failure_count;
- current shard/index;
- last candidate and atom id;
- status;
- heartbeat timestamp;
- stop_signal observation;
- validator decision.

## Resume design
1. Write checkpoint after bounded interval.
2. Never increment accepted_count before visibility proof.
3. Store failed candidate details separately.
4. On resume, skip already finalized candidates.
5. On recoverable zero-surface failure, quarantine/reject and continue.
6. On partial surface, stop and reconcile.
7. Emit final report only when queue empty or stopped resumably.

## Proof
Validator must be able to distinguish completed, incomplete resumable, blocked and hard error.

## Related heavy-process cards
- `heavy_process_reference.autonomous_long_run_recovery_and_resume.v1` — Autonomous Long Run Recovery And Resume
- `heavy_process_reference.phase162_acceptance_pipeline_reconciliation.v1` — Phase162 Acceptance Pipeline Reconciliation
- `heavy_process_reference.zero_surface_vs_partial_surface_failure.v1` — Zero Surface Vs Partial Surface Failure
- `heavy_process_reference.checkpoint_resume_runtime_design.v1` — Checkpoint Resume Runtime Design
- `heavy_process_reference.runtime_health_heartbeat_observation.v1` — Runtime Health Heartbeat Observation
- `heavy_process_reference.partial_checkpoint_commit_policy.v1` — Partial Checkpoint Commit Policy

## Operator Notes
This runbook is not a primitive concept explanation. It is a process reference. Read it when the task has risk, ambiguity, live state, protected surfaces, external material, or proof requirements.

## Atomization Note
This runbook is not accepted memory. A future atom may be proposed only after the runbook helps solve a real task gap and the result has proof/use.
