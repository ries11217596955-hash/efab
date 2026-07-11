# BODY STATE AGGREGATOR V1 REQUIREMENT

STATUS: REQUIREMENT_DERIVED_FROM_LIVING_LOOP_EVALUATOR_V1 / LAB_ONLY / NON_MUTATING

## Purpose

Body State Aggregator V1 reads normalized lifecycle signals from Living Loop Evaluator V1 and groups them into organism state categories.

It is not Brain.
It does not choose tasks.
It does not mutate passports, files, runtime, or maps.
It does not create PASSPORT_ACTIVE.

## Inputs

Required:
- `reports/self_development/LIVING_LOOP_EVALUATOR_V1_SIGNALS.json`
- `tests/self_development/LIVING_LOOP_EVALUATOR_V1_PROOF.json`
- `contracts/living_loop/LIVING_LOOP_CONTRACT_V1.json`
- `self_model/organ_passports/_index/ORGAN_PASSPORT_DRAFT_INDEX_V1.json`

## Outputs

Required:
- `reports/self_development/BODY_STATE_AGGREGATOR_V1_STATE.json`
- `reports/self_development/BODY_STATE_AGGREGATOR_V1_REPORT.json`
- `tests/self_development/BODY_STATE_AGGREGATOR_V1_PROOF.json`

## Required categories

The aggregator MUST produce these state buckets:

- `validated_lab_non_active`
- `blocked`
- `boundary_guarded`
- `return_to_parent`
- `owner_decision_required`
- `repair_required`
- `no_action_needed`

Empty buckets are allowed but must be explicit.

## Required summary fields

- total_signals
- validated_lab_non_active_count
- blocked_count
- boundary_guarded_count
- return_to_parent_count
- owner_decision_required_count
- repair_required_count
- no_action_needed_count
- highest_severity
- recommended_next_route
- brain_input_ready
- mutation_authorized=false
- runtime_ready=false
- live_ready=false
- autonomous_runtime=false

## Laws enforced

- No signal -> no Body State.
- No evidence_ref -> invalid signal.
- No passport_ref -> invalid signal.
- Blocked signal must remain blocked, not promoted.
- Boundary guard signal must not become live/readiness claim.
- Body State Aggregator must not mutate evidence/passport/map/runtime.
- Brain may consume Body State only if all signals pass negative guards.

## Acceptance

Validator must prove:
- evaluator output exists and validates;
- every input signal appears in exactly one or more expected state buckets;
- blocked signal appears in `blocked`;
- boundary guard signals appear in `boundary_guarded`;
- return signal appears in `return_to_parent`;
- validated lab non-active signals appear in `validated_lab_non_active`;
- no signal has live/runtime/autonomous/passport-active overclaim;
- output is lab-only and non-mutating;
- recommended next route is not execution authority.
