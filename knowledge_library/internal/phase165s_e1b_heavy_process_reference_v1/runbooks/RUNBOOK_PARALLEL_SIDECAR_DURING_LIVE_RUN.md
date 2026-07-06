# Parallel Sidecar During Live Run

## Purpose
Use when a long-running process is active and Owner wants useful parallel work.

## Allowed
- observe heartbeat/resume_state;
- prepare staged reference material;
- create sidecar proof/report;
- create validators that only validate sidecar;
- draft route/strategy materials;
- create packages that do not touch protected state.

## Not allowed
- hot-patch running accepted surfaces;
- mutate protected state;
- claim the running process is completed;
- create accepted atoms from sidecar reading;
- start competing runtime over same output directory;
- commit mixed D2B and sidecar changes as one completed result.

## Safe sidecar surfaces
`knowledge_library/internal/...`, `materials/...` candidates, `source_registry/...` candidates, `validators/...`, `proofs/self_development/...`, `reports/self_development/...`.

## Proof
Sidecar proof must explicitly state:
- protected_state_mutation=false;
- accepted_atoms_created=0;
- school_curriculum_created=false;
- running_process_touched=false.

## Related heavy-process cards
- `heavy_process_reference.autonomous_long_run_recovery_and_resume.v1` — Autonomous Long Run Recovery And Resume
- `heavy_process_reference.phase162_acceptance_pipeline_reconciliation.v1` — Phase162 Acceptance Pipeline Reconciliation
- `heavy_process_reference.zero_surface_vs_partial_surface_failure.v1` — Zero Surface Vs Partial Surface Failure
- `heavy_process_reference.checkpoint_resume_runtime_design.v1` — Checkpoint Resume Runtime Design
- `heavy_process_reference.artifact_delivery_pack_process.v1` — Artifact Delivery Pack Process
- `heavy_process_reference.parallel_sidecar_work_during_live_run.v1` — Parallel Sidecar Work During Live Run

## Operator Notes
This runbook is not a primitive concept explanation. It is a process reference. Read it when the task has risk, ambiguity, live state, protected surfaces, external material, or proof requirements.

## Atomization Note
This runbook is not accepted memory. A future atom may be proposed only after the runbook helps solve a real task gap and the result has proof/use.
