# REASONER V1 REQUIREMENT

STATUS: REQUIREMENT_DERIVED_FROM_BODY_STATE_AGGREGATOR_V1 / LAB_ONLY / NON_EXECUTING

## Purpose

Reasoner V1 reads Body State and explains causes.
It separates symptom from root cause and emits legal action classes.

Reasoner V1 is not Brain.
It does not choose the final task.
It does not execute.
It does not mutate.
It does not create PASSPORT_ACTIVE.
It does not touch live runtime.

## Inputs

Required:
- `reports/self_development/BODY_STATE_AGGREGATOR_V1_STATE.json`
- `tests/self_development/BODY_STATE_AGGREGATOR_V1_PROOF.json`
- `contracts/living_loop/LIVING_LOOP_CONTRACT_V1.json`

## Outputs

Required:
- `reports/self_development/REASONER_V1_CAUSAL_EXPLANATION.json`
- `reports/self_development/REASONER_V1_REPORT.json`
- `tests/self_development/REASONER_V1_PROOF.json`

## Required reasoning outputs

For each meaningful Body State bucket, Reasoner must emit:
- `finding_id`
- `source_bucket`
- `symptom`
- `root_cause`
- `confidence`
- `evidence_refs`
- `legal_action_class`
- `forbidden_actions`
- `recommended_next_question_or_action_class`
- boundary flags:
  - `mutation_authorized=false`
  - `runtime_ready=false`
  - `live_ready=false`
  - `autonomous_runtime=false`
  - `brain_decision=false`
  - `execution_performed=false`

## Required finding classes

At minimum, Reasoner must produce:
- `BLOCKED_SOURCE_PROOF_ROOT_CAUSE`
- `BOUNDARY_GUARD_ROOT_CAUSE`
- `VALIDATED_LAB_NON_ACTIVE_CAUSE`
- `RETURN_TO_PARENT_CAUSE`

## Laws enforced

- Body State first; no raw proof-only reasoning.
- Symptom must not be treated as root cause.
- Reasoning is not execution.
- Legal action class is not mutation authority.
- Blocked state remains blocked until source proof exists.
- Live-like boundary remains non-live.
- Brain may consume explanation; Reasoner must not become Brain.

## Acceptance

Validator must prove:
- Body State Aggregator validates;
- Reasoner produces all required finding classes;
- blocked finding root cause is missing source proof;
- boundary finding forbids live/runtime/autonomous overclaim;
- validated lab findings remain non-active;
- legal action classes exist;
- forbidden actions exist;
- no execution, mutation, live runtime, PASSPORT_ACTIVE, or Brain decision is claimed.
