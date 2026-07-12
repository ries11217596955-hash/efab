# PRIORITY POLICY CONTRACT V1

STATUS: CENTRAL_SELECTION_POLICY / LAB_ONLY / NON_EXECUTING / NOT_FULL_BRAIN

## Purpose

Priority Policy Contract V1 defines how Builder ranks possible next directions.

It exists because the Builder must not be pushed by a forced pipeline and must not rely on hidden/manual intuition scores.

Priority Policy recommends; it does not command.
Priority Policy ranks options; it does not execute.
Priority Policy may inform Brain; it is not full Brain.

## Core law

NO_FORCED_NEXT_STEP.

A next technical layer is not automatically the correct next direction.
Every option must compete against alternatives under a visible policy.

## Score formula

Each option receives components in the range 0.0..1.0.

Positive components:
- owner_goal_fit
- strategic_value
- proof_readiness
- safety_score
- reuse_value
- blocker_relief
- learning_value

Penalty components:
- risk_penalty
- authority_cost
- prematurity_penalty
- forced_pipeline_penalty
- live_runtime_penalty
- child_agent_prematurity_penalty

Formula:

```
positive_score =
  0.22 * owner_goal_fit +
  0.18 * strategic_value +
  0.12 * proof_readiness +
  0.15 * safety_score +
  0.08 * reuse_value +
  0.10 * blocker_relief +
  0.15 * learning_value

penalty_score =
  0.18 * risk_penalty +
  0.14 * authority_cost +
  0.20 * prematurity_penalty +
  0.22 * forced_pipeline_penalty +
  0.16 * live_runtime_penalty +
  0.10 * child_agent_prematurity_penalty

final_score = clamp01(positive_score - (0.72 * penalty_score) + 0.28)
```

The +0.28 baseline prevents all non-executing, safe options from collapsing to zero while still allowing penalties to dominate premature directions.

## Selection constraints

The selected option must satisfy:
- execution_allowed=false
- mutation_authorized=false
- runtime_ready=false
- live_ready=false
- autonomous_runtime=false
- passport_active_allowed=false
- owner_goal_fit >= 0.70
- forced_pipeline_penalty <= 0.35
- prematurity_penalty <= 0.45
- safety_score >= 0.70

If no option satisfies these constraints, select `stop_no_action` if present.

## Mandatory option set

The policy must score at least these options:
- continue_non_executing_brain_build
- strengthen_memory_layer
- mature_passport_pool
- build_action_planner_later
- activation_or_live_gate_later
- child_agent_production_later
- stop_no_action

## Mandatory explanations

Each scored option must include:
- score_components
- positive_score
- penalty_score
- final_score
- policy_decision
- why_selected_or_not
- risk
- proof_gap
- authority_required
- expected_value
- forbidden_actions

## Hard guards

- Action Planner cannot win when forced_pipeline_penalty is high.
- Live/activation cannot win without explicit live authority.
- Child-agent production cannot win before parent Brain/immune system is mature.
- STOP/NO_ACTION must remain a valid option.
- Manual final_score without components is invalid.
- Missing component is invalid.
- Component outside 0..1 is invalid.
- Priority result is recommendation, not command.

## Acceptance

Validator must prove:
- formula weights are present;
- all mandatory components are present;
- all options use the same formula;
- selected option is computed, not manually assigned;
- negative fixture with missing components fails;
- negative fixture with Action Planner forced high fails;
- negative fixture with live route selected without authority fails;
- output remains non-executing and non-mutating;
- Priority Policy Contract can be reused by future Brain/Selector without becoming Brain.
