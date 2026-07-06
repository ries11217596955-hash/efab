# PROMOTION REVIEW CONTROLLED RUNTIME V1

Status: CONTROLLED_RUNTIME_CANDIDATE

Promoted from: ACCEPTED_LOCAL

Runtime ready: false

## Basis

- Batch 100 proof: `tests/accepted_atom_retention/EPHEMERAL_CANDIDATE_TO_ATOM_BATCH_100_TRIAL_V1.json`
- Runtime 1000 proof: `tests/accepted_atom_retention/EPHEMERAL_CANDIDATE_TO_ATOM_RUNTIME_1000_TRIAL_V1.json`
- Current Codex map: `AGENTS.md`

## Runtime 1000 Summary

- total_cycles: 10
- total_candidates: 1000
- total_accepted: 1000
- total_receipts: 1000
- failed_cycles: 0
- material_pruned: true
- work_current_pruned: true
- unexpected_git_status_count: 0
- runtime_ready: false

## Invariants

- Candidates are fuel, not memory.
- Successful candidate material must be pruned.
- `work/current` must be pruned after success.
- Failed, quarantine, or hard-error traces must be preserved.
- Old raw_shards are not a runtime dependency.
- The old repo is not a runtime source.
- `.runtime` is disposable ignored runtime.

## Non-Goals

- Do not set `runtime_ready=true`.
- Do not run new large tests for this promotion review.
- Do not rewrite passports.
- Do not copy old material banks.

## Next Required

CONTROLLED_RUNTIME_WIRING_OR_STOP_GOVERNED_CONTINUOUS_TRIAL
