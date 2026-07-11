# BRAIN INPUT CONSUMER V1 REQUIREMENT

STATUS: REQUIREMENT_DERIVED_FROM_DECISION_GATE_V1 / LAB_ONLY / NOT_BRAIN / NON_EXECUTING

## Purpose

Brain Input Consumer V1 reads the Decision Gate V1 decision packet and converts it into a Brain-safe input envelope.

It is not Brain.
It does not choose final action.
It does not execute.
It does not mutate.
It does not repair proof.
It does not start runtime.
It does not create PASSPORT_ACTIVE.

Its job is to prove that the route packet can be safely consumed by a future Brain/selector layer without losing boundaries, evidence refs, forbidden actions, or owner-decision requirements.

## Inputs

Required:
- `reports/self_development/DECISION_GATE_V1_DECISION_PACKET.json`
- `tests/self_development/DECISION_GATE_V1_PROOF.json`
- `contracts/living_loop/LIVING_LOOP_CONTRACT_V1.json`

## Outputs

Required:
- `reports/self_development/BRAIN_INPUT_CONSUMER_V1_ENVELOPE.json`
- `reports/self_development/BRAIN_INPUT_CONSUMER_V1_REPORT.json`
- `tests/self_development/BRAIN_INPUT_CONSUMER_V1_PROOF.json`

## Envelope required fields

- `input_class`
- `route_class`
- `target_organ_id`
- `dominant_root_cause`
- `owner_decision_required`
- `execution_allowed=false`
- `mutation_authorized=false`
- `brain_can_read=true`
- `brain_can_execute=false`
- `brain_can_mutate=false`
- `brain_must_preserve_forbidden_actions=true`
- `evidence_refs`
- `forbidden_actions`
- `required_owner_question`
- `safe_next_prompt_for_brain`
- `return_to_parent_summary`

## Accepted input classes

- `OWNER_DECISION_REQUIRED_REPAIR_OR_KEEP_BLOCKED`
- `NON_EXECUTING_ROUTE_PACKET`
- `STOP_PACKET`

## Laws enforced

- Brain-readable is not Brain-executable.
- Brain input must preserve evidence refs.
- Brain input must preserve forbidden actions.
- Owner decision requirement must not be dropped.
- Missing source proof cannot be bypassed.
- Consumer is not Brain.
- Consumer cannot authorize mutation.

## Acceptance

Validator must prove:
- Decision Gate validates;
- route class is preserved;
- target organ is preserved;
- owner_decision_required remains true for missing source proof route;
- execution_allowed=false;
- mutation_authorized=false;
- brain_can_read=true;
- brain_can_execute=false;
- brain_can_mutate=false;
- evidence refs and forbidden actions preserved;
- required Owner question exists;
- no live/runtime/autonomous/PASSPORT_ACTIVE overclaim.
