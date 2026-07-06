# PHASE162 Acceptance Pipeline Reconciliation

## Purpose
Use this when an atom candidate allegedly became accepted but visibility is unclear.

## Pipeline
candidate -> guard -> PHASE162 executor -> accepted memory -> self-map/body-map -> registry -> startup/reuse visibility proof.

## Procedure
1. Locate candidate id and atom id.
2. Find executor result and acceptance proof.
3. Check all visibility surfaces separately:
   - accepted change memory snapshot;
   - self model active map;
   - packs registry;
   - any runtime/startup awareness pointer.
4. Compare with expected count deltas.
5. Classify:
   - full visibility: accepted candidate can count.
   - zero visibility: not accepted; quarantine/reject candidate.
   - partial visibility: dangerous; block and reconcile.
6. For partial visibility, identify which surface changed first and whether it can be safely rolled back from proof.
7. Re-run validator. Validator must prove the final status, not merely the patch.
8. Only after full visibility can Builder absorb learning into next cycle.

## Do not
- Manually inject accepted atom into memory just to satisfy count.
- Mark failed candidate accepted without visibility/reuse proof.
- Use Codex output as proof without terminal validation.
- Update self-map manually unless the route explicitly allows it and validator confirms.

## Proof needed
- all three surface counts;
- atom id exact string;
- before/after diff where any surface changed;
- validator decision.

## Related heavy-process cards
- `heavy_process_reference.autonomous_long_run_recovery_and_resume.v1` — Autonomous Long Run Recovery And Resume
- `heavy_process_reference.phase162_acceptance_pipeline_reconciliation.v1` — Phase162 Acceptance Pipeline Reconciliation
- `heavy_process_reference.zero_surface_vs_partial_surface_failure.v1` — Zero Surface Vs Partial Surface Failure
- `heavy_process_reference.child_agent_production_acceptance_contract.v1` — Child Agent Production Acceptance Contract

## Operator Notes
This runbook is not a primitive concept explanation. It is a process reference. Read it when the task has risk, ambiguity, live state, protected surfaces, external material, or proof requirements.

## Atomization Note
This runbook is not accepted memory. A future atom may be proposed only after the runbook helps solve a real task gap and the result has proof/use.
