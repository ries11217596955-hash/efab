# Source Gap to Reference Expansion

## Purpose
Use when Builder reaches a concrete missing knowledge area during a real task.

## Flow
task -> decompose -> missing Y -> accepted memory scan -> internal reference scan -> self-map/body map -> material catalogue -> governed external policy -> material candidate -> applied proof -> possible atom candidate.

## Procedure
1. Name the gap type: concept, procedure, requirement, organ, proof, source, safety or permission.
2. Explain why accepted atoms/organs did not solve it.
3. Look for internal reference card or runbook.
4. If absent, create `reference_expansion_candidate`.
5. If external material is needed, classify it as material candidate, not trusted core.
6. Capture provenance, license/terms, risk and validation path.
7. Apply knowledge to the task before proposing atom candidate.
8. Create atom candidate only after proof/use.

## Output shape
```json
{
  "gap_id": "...",
  "missing_knowledge_area": "...",
  "why_internal_sources_insufficient": "...",
  "proposed_internal_reference": "...",
  "proposed_external_material_candidates": [],
  "risk_level": "low|medium|high",
  "owner_approval_required": true,
  "expected_atom_types": []
}
```

## Related heavy-process cards
- `heavy_process_reference.autonomous_long_run_recovery_and_resume.v1` — Autonomous Long Run Recovery And Resume
- `heavy_process_reference.phase162_acceptance_pipeline_reconciliation.v1` — Phase162 Acceptance Pipeline Reconciliation
- `heavy_process_reference.zero_surface_vs_partial_surface_failure.v1` — Zero Surface Vs Partial Surface Failure
- `heavy_process_reference.protected_state_mutation_gate.v1` — Protected State Mutation Gate
- `heavy_process_reference.route_lock_change_control.v1` — Route Lock Change Control
- `heavy_process_reference.source_gap_to_reference_expansion.v1` — Source Gap To Reference Expansion

## Operator Notes
This runbook is not a primitive concept explanation. It is a process reference. Read it when the task has risk, ambiguity, live state, protected surfaces, external material, or proof requirements.

## Atomization Note
This runbook is not accepted memory. A future atom may be proposed only after the runbook helps solve a real task gap and the result has proof/use.
