# Validator and Proof Design

## Purpose
Every important change needs machine-readable proof and human-readable report.

## Validator rules
- deterministic;
- narrow to the phase;
- checks file existence and JSON parse;
- checks counts and required fields;
- checks protected surfaces when relevant;
- emits JSON result;
- fails closed on ambiguity.

## Proof JSON
Include:
- schema_version;
- phase;
- status;
- timestamps;
- created/modified paths;
- count summaries;
- safety booleans;
- validator;
- next action.

## Report MD
Include:
- meaning;
- what changed;
- proof summary;
- risks;
- what was not done;
- next step.

## Anti-bureaucracy
Do not create reports that do not control action, prove result, reduce risk or support decision.

## Related heavy-process cards
- `heavy_process_reference.autonomous_long_run_recovery_and_resume.v1` — Autonomous Long Run Recovery And Resume
- `heavy_process_reference.phase162_acceptance_pipeline_reconciliation.v1` — Phase162 Acceptance Pipeline Reconciliation
- `heavy_process_reference.zero_surface_vs_partial_surface_failure.v1` — Zero Surface Vs Partial Surface Failure
- `heavy_process_reference.governed_external_search_material_candidate.v1` — Governed External Search Material Candidate
- `heavy_process_reference.post_codex_terminal_proof_pack.v1` — Post Codex Terminal Proof Pack
- `heavy_process_reference.validator_proof_report_contract.v1` — Validator Proof Report Contract

## Operator Notes
This runbook is not a primitive concept explanation. It is a process reference. Read it when the task has risk, ambiguity, live state, protected surfaces, external material, or proof requirements.

## Atomization Note
This runbook is not accepted memory. A future atom may be proposed only after the runbook helps solve a real task gap and the result has proof/use.
