# Codex Repair With Proof

## Purpose
Use Codex only for Builder repair/extension when scope spans files, architecture is unclear, or defect is systemic.

## Codex task must include
- context and current state;
- proven facts, not guesses;
- files in scope;
- files out of scope;
- exact requirements;
- expected validator output;
- expected proof/report paths;
- risks;
- cut list;
- no commit/push unless explicitly authorized.

## After Codex
1. Do not accept Codex summary as proof.
2. Run repo identity checks.
3. Inspect changed files.
4. Run validators.
5. Parse proof JSON.
6. Read generated report.
7. Check protected state.
8. Check git status.
9. Decide: keep, repair again, quarantine, rollback, or ask Owner.

## Forbidden
- Codex as normal builder for every organ.
- Codex direct accepted atom injection.
- Codex hidden mutation of protected state.
- Post-Codex “trust me” without terminal proof.

## Related heavy-process cards
- `heavy_process_reference.autonomous_long_run_recovery_and_resume.v1` — Autonomous Long Run Recovery And Resume
- `heavy_process_reference.phase162_acceptance_pipeline_reconciliation.v1` — Phase162 Acceptance Pipeline Reconciliation
- `heavy_process_reference.zero_surface_vs_partial_surface_failure.v1` — Zero Surface Vs Partial Surface Failure
- `heavy_process_reference.codex_boundary_repair_protocol.v1` — Codex Boundary Repair Protocol
- `heavy_process_reference.post_codex_terminal_proof_pack.v1` — Post Codex Terminal Proof Pack
- `heavy_process_reference.validator_proof_report_contract.v1` — Validator Proof Report Contract

## Operator Notes
This runbook is not a primitive concept explanation. It is a process reference. Read it when the task has risk, ambiguity, live state, protected surfaces, external material, or proof requirements.

## Atomization Note
This runbook is not accepted memory. A future atom may be proposed only after the runbook helps solve a real task gap and the result has proof/use.
