# BRAIN SELECTOR STUB V1 REQUIREMENT

STATUS: REQUIREMENT_DERIVED_FROM_BRAIN_INPUT_CONSUMER_V1 / LAB_ONLY / NON_EXECUTING / NOT_FULL_BRAIN

## Purpose

Brain Selector Stub V1 reads the Brain Input Consumer envelope and selects a candidate intent.

It is not full Brain.
It does not execute.
It does not mutate.
It does not repair proof.
It does not start runtime.
It does not create PASSPORT_ACTIVE.

Its purpose is to prove the first safe Brain-facing behavior: reading a lawful input envelope and selecting a constrained candidate intent while preserving owner-decision and no-execution boundaries.

## Inputs

Required:
- `reports/self_development/BRAIN_INPUT_CONSUMER_V1_ENVELOPE.json`
- `tests/self_development/BRAIN_INPUT_CONSUMER_V1_PROOF.json`
- `contracts/living_loop/LIVING_LOOP_CONTRACT_V1.json`

## Outputs

Required:
- `reports/self_development/BRAIN_SELECTOR_STUB_V1_INTENT.json`
- `reports/self_development/BRAIN_SELECTOR_STUB_V1_REPORT.json`
- `tests/self_development/BRAIN_SELECTOR_STUB_V1_PROOF.json`

## Required intent fields

- `intent_class`
- `target_organ_id`
- `source_route_class`
- `owner_decision_required`
- `selected_by_brain_stub=true`
- `full_brain=false`
- `execution_allowed=false`
- `mutation_authorized=false`
- `brain_can_execute=false`
- `brain_can_mutate=false`
- `requires_preflight=true`
- `requires_owner_authority=true`
- `evidence_refs`
- `forbidden_actions`
- `allowed_next_step_description`
- `stop_conditions`
- `return_to_parent_summary`

## Allowed intent classes

- `REQUEST_OWNER_AUTHORIZED_PREFLIGHT_REPAIR_OR_KEEP_BLOCKED`
- `KEEP_BLOCKED_NO_ACTION`
- `ASK_OWNER_DECISION_ONLY`
- `STOP_NO_LAWFUL_INTENT`

## Laws enforced

- Candidate intent is not execution.
- Brain stub is not full Brain.
- Owner-decision requirement must be preserved.
- Missing source proof cannot be bypassed.
- Forbidden actions must be preserved.
- Evidence refs must be preserved.
- Prefight required before any repair mutation.

## Acceptance

Validator must prove:
- Brain Input Consumer validates;
- selected intent matches envelope route class;
- owner_decision_required remains true;
- requires_preflight=true;
- requires_owner_authority=true;
- execution_allowed=false;
- mutation_authorized=false;
- full_brain=false;
- evidence refs and forbidden actions preserved;
- no live/runtime/autonomous/PASSPORT_ACTIVE overclaim.
