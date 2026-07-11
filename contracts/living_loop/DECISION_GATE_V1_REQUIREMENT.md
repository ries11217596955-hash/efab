# DECISION GATE / BRAIN INPUT GATE V1 REQUIREMENT

STATUS: REQUIREMENT_DERIVED_FROM_REASONER_V1 / LAB_ONLY / NON_EXECUTING / NOT_BRAIN

## Purpose

Decision Gate V1 reads Reasoner V1 output and selects a lawful route class for Brain-safe consumption.

It does not execute.
It does not mutate.
It does not start runtime.
It does not create PASSPORT_ACTIVE.
It is not Brain.
It is a gate that prevents Reasoner output from jumping directly into action.

## Inputs

Required:
- `reports/self_development/REASONER_V1_CAUSAL_EXPLANATION.json`
- `tests/self_development/REASONER_V1_PROOF.json`
- `contracts/living_loop/LIVING_LOOP_CONTRACT_V1.json`

## Outputs

Required:
- `reports/self_development/DECISION_GATE_V1_DECISION_PACKET.json`
- `reports/self_development/DECISION_GATE_V1_REPORT.json`
- `tests/self_development/DECISION_GATE_V1_PROOF.json`

## Decision packet required fields

- `route_class`
- `target_organ_id`
- `dominant_root_cause`
- `legal_action_class`
- `owner_decision_required`
- `execution_allowed=false`
- `mutation_authorized=false`
- `runtime_ready=false`
- `live_ready=false`
- `autonomous_runtime=false`
- `brain_decision=false`
- `evidence_refs`
- `forbidden_actions`
- `allowed_next_step_description`
- `return_to_parent_summary`

## Route classes

Allowed route classes:
- `REPAIR_SOURCE_PROOF_OR_KEEP_BLOCKED`
- `KEEP_BLOCKED_NO_ACTION`
- `ASK_OWNER_DECISION`
- `STOP_NO_LAWFUL_ACTION`
- `PRESERVE_BOUNDARY_AND_CONTINUE_NON_EXECUTING_LAYER`

## Laws enforced

- Legal route class is not execution authority.
- Owner may be required before repair if repair implies mutation or upstream generation.
- Blocked source proof cannot be bypassed.
- Boundary findings cannot become live readiness.
- Brain input must include forbidden actions.
- Brain input must include evidence refs.
- Decision Gate is not Brain.

## Acceptance

Validator must prove:
- Reasoner V1 validates;
- decision packet route class matches dominant root cause;
- missing source proof leads to `REPAIR_SOURCE_PROOF_OR_KEEP_BLOCKED`;
- execution_allowed=false;
- mutation_authorized=false;
- brain_decision=false;
- no live/runtime/autonomous overclaim;
- forbidden actions are present;
- evidence refs are present;
- return-to-parent summary exists.
