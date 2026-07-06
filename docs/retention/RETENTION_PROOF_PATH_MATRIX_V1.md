# Retention Proof Path Matrix V1

Status: `RETENTION_PROOF_PATH_MATRIX_VALID`

Runtime readiness remains `false`. This matrix classifies retention proof paths for the current durable compact atom storage contract. Historical scale and legacy receipt-only paths must not be used as acceptance proof for the durable semantic-memory lane.

## Canonical Lane

`small_scale_durable_compact_store_integration_proof` is the single `ACTIVE_CANONICAL` lane.

It proves: 4 cycles, 8 accepted atoms, one durable store, retrieval after cleanup, compact receipts, and bounded runtime.

It does not prove: 30k scale, 300k scale, runtime readiness, or active memory promotion.

## Matrix

| Proof path | Classification | Proves | Does not prove |
| --- | --- | --- | --- |
| `compact_atom_storage_bridge_micro_proof` | `ACTIVE_SUPPORTING` | compact semantic index; retrieval by `atom_id` | cleanup survival; scale; runtime readiness |
| `real_runner_one_batch_retention_gate_dry_trial` | `ACTIVE_SUPPORTING` | real-runner adapter path creates compact index/retrieval for one batch | multi-cycle durable survival; runtime readiness |
| `compact_atom_storage_survives_cleanup_micro_proof` | `ACTIVE_SUPPORTING` | durable compact store survives cleanup in micro cycles | useful curriculum learning; runtime readiness |
| `small_scale_durable_compact_store_integration_proof` | `ACTIVE_CANONICAL` | 4 cycles; 8 accepted atoms; one durable store; retrieval after cleanup; receipts compact; runtime bounded | 30k scale; 300k scale; runtime readiness; active memory promotion |
| `ephemeral_candidate_to_atom_runtime_1000_trial` | `LEGACY_BLOCKED_UNDER_DURABLE_CONTRACT` | legacy candidate-to-atom runtime path behavior | durable compact semantic store; retrieval from durable store; new retention acceptance; runtime readiness |
| `old_5k_sustained_retention_proofs` | `HISTORICAL_SCALE_PROOF` | historical scale/cleanup/receipt discipline | compact semantic durable store plus retrieval under current contract |
| `old_30k_sustained_retention_proofs` | `HISTORICAL_SCALE_PROOF` | historical 30k scale/cleanup/receipt discipline | compact semantic durable store plus retrieval under current contract |

## Guard

The validator requires:

- exactly one `ACTIVE_CANONICAL` entry
- canonical lane equals `small_scale_durable_compact_store_integration_proof`
- matrix `runtime_ready=false`
- `ephemeral_candidate_to_atom_runtime_1000_trial` is `LEGACY_BLOCKED_UNDER_DURABLE_CONTRACT`
- 5k and 30k historical entries are not canonical
- active stubs remain `THINNED_REQUIRES_STORAGE_ORGAN_BEFORE_RUNTIME_USE`
