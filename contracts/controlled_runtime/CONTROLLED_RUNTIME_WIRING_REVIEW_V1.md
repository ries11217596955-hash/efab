# Controlled Runtime Wiring Review V1

Status: CONTROLLED_RUNTIME_ENTRYPOINT_ACCEPTED_LOCAL

Promoted from: CONTROLLED_RUNTIME_CANDIDATE

Runtime ready: false

## Basis

- Promotion review: `contracts/controlled_runtime/PROMOTION_REVIEW_CONTROLLED_RUNTIME_V1.json`
- Controlled runtime entrypoint commit: `27c0d5f`
- Wiring trial proof: `tests/accepted_atom_retention/CONTROLLED_EPHEMERAL_RUNTIME_WIRING_TRIAL_V1.json`
- Wiring validator pass: `validators/validate_controlled_ephemeral_runtime_wiring_trial_v1.ps1`
- Runtime 1000 validator pass: `validators/validate_ephemeral_candidate_to_atom_runtime_1000_trial_v1.ps1`

## Entrypoint

`modules/run_ephemeral_candidate_controlled_runtime_v1.ps1`

## Invariants

- `MaxCycles` is required.
- `BatchSize` is capped at 100.
- `StopFile` is supported.
- Heartbeat output is supported.
- Summary output is supported.
- Candidates are fuel, not memory.
- Successful candidate material is pruned.
- Successful work/current traces are pruned.
- Failed or quarantine traces are preserved.
- Unbounded loops are not allowed.

## Non-Goals

- Do not set `runtime_ready=true`.
- Do not create continuous autonomy.
- Do not run unbounded loops.
- Do not copy old raw_shards.
- Do not use the old repo as a runtime source.

## Next Required

STOP_GOVERNED_CONTINUOUS_TRIAL_REVIEW
