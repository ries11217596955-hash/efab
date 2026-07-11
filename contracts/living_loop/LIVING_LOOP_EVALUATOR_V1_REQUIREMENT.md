# LIVING LOOP EVALUATOR V1 REQUIREMENT

STATUS: REQUIREMENT_DERIVED_FROM_LIVING_LOOP_CONTRACT_V1 / LAB_ONLY / NON_MUTATING_ORGAN_CANDIDATE

## Purpose

Living Loop Evaluator V1 reads the proof-backed Living Loop Contract V1, passport index, and lifecycle proof set, then emits normalized lifecycle signals.

It is not Brain, not autonomous runtime, not scheduler, and not a mutation engine.

## Inputs

Required:
- `contracts/living_loop/LIVING_LOOP_CONTRACT_V1.json`
- `self_model/organ_passports/_index/ORGAN_PASSPORT_DRAFT_INDEX_V1.json`
- lifecycle proof refs listed in the contract proof base

Optional observation surfaces:
- `reports/self_development/SELF_MODEL_ACTIVE_MAP.json`
- `reports/self_development/agent_body_map.json`

## Outputs

Required:
- `reports/self_development/LIVING_LOOP_EVALUATOR_V1_SIGNALS.json`
- `reports/self_development/LIVING_LOOP_EVALUATOR_V1_REPORT.json`
- `tests/self_development/LIVING_LOOP_EVALUATOR_V1_PROOF.json`

## Signal contract

Each signal MUST include:
- `signal_id`
- `organ_id`
- `signal_type`
- `severity`
- `confidence`
- `lifecycle_decision`
- `body_state`
- `evidence_ref`
- `passport_ref`
- boundary flags:
  - `passport_active_created`
  - `live_runtime_touched`
  - `runtime_ready`
  - `live_ready_claim`
  - `autonomous_runtime`
- `recommended_outcome`
- `brain_input_allowed`
- `reason`

## Signal types

Required minimum signal types:
- `VALIDATED_LAB_NON_ACTIVE_SIGNAL`
- `BLOCKED_MISSING_SOURCE_PROOF_SIGNAL`
- `BOUNDARY_GUARD_SIGNAL`
- `RETURN_TO_PARENT_SIGNAL`

## Laws enforced

- No proof -> no signal.
- No signal -> no Brain input.
- No state-change verification -> action unfinished.
- Lab proof != live proof.
- Live-like observation != live readiness.
- PASS can mean correctly blocked, not promoted.
- Missing proof becomes Body State, not fake proof.
- Evaluator must not create PASSPORT_ACTIVE, touch live runtime, synthesize proof, or mutate passports.

## Acceptance

Validator must prove:
- contract exists and validates;
- every proof-base item emits at least one signal;
- blocker proof emits a blocked signal;
- promotion proofs emit validated lab non-active signals;
- live-like proof emits boundary guard signal;
- every signal has evidence_ref and passport_ref;
- no live/runtime/autonomous overclaim;
- output is lab-only and non-mutating;
- return-to-parent summary exists.
