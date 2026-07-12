# PRIORITY / INTENT SELECTION MODEL V1 REQUIREMENT

STATUS: REQUIREMENT_DERIVED_FROM_OWNER_NO_FORCED_PIPELINE_CORRECTION / LAB_ONLY / NON_EXECUTING

## Purpose

Priority / Intent Selection Model V1 reads the current Living Loop state and ranks multiple possible directions.

It must not force the next pipeline step.
It must not automatically choose Action Planner.
It must not execute.
It must not mutate.
It must not become full Brain.

Its purpose is to prove that Builder can compare alternatives and select a priority based on value, risk, proof gap, authority, and Owner goal alignment.

## Inputs

Required:
- `reports/self_development/LIVING_LOOP_CURRENT_STATE_REFRESH_V1_BODY_STATE.json`
- `reports/self_development/LIVING_LOOP_CURRENT_STATE_REFRESH_V1_REASONER.json`
- `reports/self_development/LIVING_LOOP_CURRENT_STATE_REFRESH_V1_DECISION.json`
- `tests/self_development/LIVING_LOOP_CURRENT_STATE_REFRESH_V1_PROOF.json`
- `operations/gpt_handoff/GPT_OPERATOR_JOURNAL.md`

## Outputs

Required:
- `reports/self_development/PRIORITY_INTENT_SELECTION_MODEL_V1_OPTIONS.json`
- `reports/self_development/PRIORITY_INTENT_SELECTION_MODEL_V1_REPORT.json`
- `tests/self_development/PRIORITY_INTENT_SELECTION_MODEL_V1_PROOF.json`

## Required option fields

Each ranked option must include:
- `option_id`
- `intent_class`
- `priority_score`
- `why`
- `risk`
- `proof_gap`
- `authority_required`
- `allowed_now`
- `execution_allowed=false`
- `mutation_authorized=false`
- `owner_goal_alignment`
- `expected_value`
- `rejection_reason_if_not_selected`

## Minimum option set

At least 6 alternatives must be considered:
- continue_non_executing_brain_build
- build_action_planner_later
- strengthen_memory_layer
- mature_passport_pool
- activation_or_live_gate_later
- child_agent_production_later
- stop_no_action

## Laws enforced

- No forced next step.
- Priority selection is not execution.
- Action Planner is not automatic.
- Owner goal alignment must be visible.
- Low-risk non-executing improvement can outrank action planning.
- STOP/NO_ACTION must be a valid option.
- Live/activation/child-agent routes need separate authority and proof ladder.

## Acceptance

Validator must prove:
- current state refresh validates;
- at least 6 options exist;
- options are ranked;
- selected option is not Action Planner by default;
- Action Planner option is considered but not automatically selected;
- every option has why/risk/proof_gap/authority/expected_value;
- every option has execution_allowed=false and mutation_authorized=false;
- no live/runtime/autonomous/PASSPORT_ACTIVE overclaim;
- NO_FORCED_NEXT_STEP is recorded in proof.
