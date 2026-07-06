# GitHub Remote Proof

## Purpose
Use when remote state or CI matters.

## Procedure
1. Check local branch and remote branch.
2. Push only after local proof.
3. Inspect workflow runs when CI is expected.
4. Inspect artifacts if validator/report is generated remotely.
5. Treat workflow success as proof only for what the workflow actually checked.
6. Do not claim sync without `git status` and remote evidence.

## Output
- commit hash;
- pushed branch;
- workflow run id/status;
- artifact path if any;
- remaining risks.

## Related heavy-process cards
- `heavy_process_reference.autonomous_long_run_recovery_and_resume.v1` — Autonomous Long Run Recovery And Resume
- `heavy_process_reference.phase162_acceptance_pipeline_reconciliation.v1` — Phase162 Acceptance Pipeline Reconciliation
- `heavy_process_reference.zero_surface_vs_partial_surface_failure.v1` — Zero Surface Vs Partial Surface Failure
- `heavy_process_reference.post_codex_terminal_proof_pack.v1` — Post Codex Terminal Proof Pack
- `heavy_process_reference.validator_proof_report_contract.v1` — Validator Proof Report Contract
- `heavy_process_reference.github_actions_remote_proof_cycle.v1` — Github Actions Remote Proof Cycle

## Operator Notes
This runbook is not a primitive concept explanation. It is a process reference. Read it when the task has risk, ambiguity, live state, protected surfaces, external material, or proof requirements.

## Atomization Note
This runbook is not accepted memory. A future atom may be proposed only after the runbook helps solve a real task gap and the result has proof/use.
