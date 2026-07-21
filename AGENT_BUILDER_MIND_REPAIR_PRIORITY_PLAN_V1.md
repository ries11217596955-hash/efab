# AGENT_BUILDER_MIND_REPAIR_PRIORITY_PLAN_V1

Status: ROOT_REPAIR_PRIORITY_PLAN

## 1. Decision

First repair priority:

```text
LOGIC FIRST
```

Not because short-term memory is unimportant, but because the current mind fails before memory can help.

Evidence:

```text
AUDIT_M1_CURRENT_MIND_TOPOLOGY_V1
M1_F2 = DECISION_CHAIN_ENDS_AT_QUEUE_PACKET = HIGH
M1_F6 = FRONTIER_TO_BUILD_TASK_MISSING = HIGH
M1_F4 = SHORT_TERM_MEMORY_IS_WAKE_CONTEXT_NOT_MIND_STATE = MEDIUM
```

Conclusion:

```text
If we build short-term memory first, the agent will persist bad/unfinished decisions.
If we build RAM first, the agent will loop faster.
If we build compact retrieval first without a decision spine, retrieved memory has no reliable place to affect action.
```

## 2. First repair target

```text
NEXT_BUILD_TASK_DECISION_SPINE_V1
```

Purpose:

```text
Every canonical life cycle must end with either:
1. a concrete next build task candidate, or
2. a precise BLOCKED reason with missing input/proof.
```

It must not end merely as:

```text
queue packet written
frontier selected
summary written
learning artifact created
```

## 3. Minimum decision spine contract

Required fields:

```text
current_parent_goal
current_cycle_goal
selected_frontier
relevant_memory_refs
observed_gap
candidate_build_task
candidate_files_in
candidate_files_out
validator_target
proof_target
risk_boundary
blocked_reason
parent_goal_delta
utility_score
next_action_type
```

Allowed next_action_type values:

```text
BUILD_TASK_CANDIDATE
AUDIT_TASK_CANDIDATE
REPAIR_TASK_CANDIDATE
BLOCKED_NEEDS_MEMORY_RETRIEVAL
BLOCKED_NEEDS_OWNER_DECISION
BLOCKED_NEEDS_PROOF
NO_OP_SAFE
```

Acceptance condition:

```text
latest canonical proof/summary contains decision_spine
and decision_spine.next_action_type is not hidden behind queue packet creation
and candidate_build_task or blocked_reason is non-empty
```

## 4. Repair sequence

### P1 — Logic spine

```text
NEXT_BUILD_TASK_DECISION_SPINE_V1
```

Reason:

```text
Create the socket where memory, short-term state, reflexes, and frontier choice can affect action.
```

### P2 — Compact memory read/use

```text
SELECTIVE_COMPACT_MEMORY_RETRIEVAL_V1
```

Reason:

```text
Fill relevant_memory_refs and prove retrieved atoms changed observed_gap or candidate_build_task.
```

### P3 — Short-term mind memory

```text
SHORT_TERM_MIND_STATE_V1
RECENT_DECISION_RING_V1
UNRESOLVED_BLOCKER_MEMORY_V1
PARENT_GOAL_STACK_V1
```

Reason:

```text
Persist current objective, recent decisions, blockers, failed attempts, and parent-goal return across cycles.
```

### P4 — Frontier to build task router

```text
FRONTIER_TO_BUILD_TASK_ROUTER_V1
```

Reason:

```text
Turn selected frontier into a task contract with files/validator/proof.
```

### P5 — Reflex matrix current-state audit

```text
AUDIT_RX1_REFLEX_MATRIX_CURRENT_STATE_V1
```

Reason:

```text
The 25-slot reflex matrix is tracked, but most reflex slots are not yet audited for callable/wired/proven status.
```

### P6 — RAM canonical migration

```text
AUDIT_R1_RAM_CANONICAL_MIGRATION_GAP_V1
```

Reason:

```text
RAM is a body/process migration; it should follow once mind decision path is less broken.
```

## 5. Forbidden shortcuts

```text
Do not run more life trials hoping the mind improves by itself.
Do not build short-term memory before defining the decision spine.
Do not call queue packet creation progress unless it changes next action.
Do not migrate RAM into canonical life before logic has a useful action path.
Do not let Codex write a broad multi-file repair without sliced task and preflight.
```

## 6. First implementation slice

```text
NEXT_BUILD_TASK_DECISION_SPINE_V1_SLICE_A
```

Scope:

```text
Add a compact decision spine artifact/field to canonical cycle proof/summary without changing external actions.
```

Expected output:

```text
operations/autonomous_inner_motor/reports/NEXT_BUILD_TASK_DECISION_SPINE_V1_ACCEPTANCE.json
tests/self_development/NEXT_BUILD_TASK_DECISION_SPINE_V1_PROOF.json
validators/validate_next_build_task_decision_spine_v1.ps1
```

Boundary:

```text
runtime_launched_only_by_validator = maybe one bounded canonical smoke run if needed
active_memory_direct_mutated = false
codex_launched = false
web_launched = false
school_launched = false
ram_migration = false
```
## 7. Slice A acceptance

Status: PROVEN_LAB / ACCEPTED

```text
NEXT_BUILD_TASK_DECISION_SPINE_V1_SLICE_A = PASS
```

Proof:

```text
tests/self_development/NEXT_BUILD_TASK_DECISION_SPINE_V1_PROOF.json
operations/autonomous_inner_motor/reports/NEXT_BUILD_TASK_DECISION_SPINE_V1_ACCEPTANCE.json
```

Validated result:

```text
decision_spine.status = PASS_NEXT_BUILD_TASK_DECISION_SPINE_V1
decision_spine.next_action_type = BLOCKED_NEEDS_MEMORY_RETRIEVAL
decision_spine.blocked_reason = no selected_action_id available; selective compact memory retrieval and build-task routing must run before execution
manifest_has_spine = true
action_execution_allowed = false
active_memory_mutated = false
```

Interpretation:

```text
The first logic socket exists. The next missing organ is selective compact memory retrieval.
```

Next repair:

```text
SELECTIVE_COMPACT_MEMORY_RETRIEVAL_V1
```
## 8. Selective Compact Memory Retrieval Slice A acceptance

Status: PROVEN_LAB / ACCEPTED

```text
SELECTIVE_COMPACT_MEMORY_RETRIEVAL_V1_SLICE_A = PASS
```

Proof:

```text
tests/self_development/SELECTIVE_COMPACT_MEMORY_RETRIEVAL_V1_PROOF.json
operations/autonomous_inner_motor/reports/SELECTIVE_COMPACT_MEMORY_RETRIEVAL_V1_ACCEPTANCE.json
```

Validated result:

```text
selective_compact_memory_retrieval.status = PASS_SELECTIVE_COMPACT_MEMORY_RETRIEVAL_V1
selective_compact_memory_retrieval.scanned_cells = 134
selective_compact_memory_retrieval.selected_count = 7
decision_effect.previous_next_action_type = BLOCKED_NEEDS_MEMORY_RETRIEVAL
decision_effect.current_next_action_type = REPAIR_TASK_CANDIDATE
decision_effect.changed_by_retrieval = true
decision_spine.candidate_build_task = SHORT_TERM_MIND_STATE_V1_SLICE_A
active_memory_mutated = false
```

Interpretation:

```text
Compact memory now affects decision_spine. The next missing organ is short-term mind state.
```

Next repair:

```text
SHORT_TERM_MIND_STATE_V1_SLICE_A
```
## 9. Short-Term Mind State Slice A acceptance

Status: PROVEN_LAB / ACCEPTED

```text
SHORT_TERM_MIND_STATE_V1_SLICE_A_WITH_EXISTING_MULTI_SOURCE_INTAKE_ROUTE = PASS
```

Proof:

```text
tests/self_development/SHORT_TERM_MIND_STATE_V1_PROOF.json
operations/autonomous_inner_motor/reports/SHORT_TERM_MIND_STATE_V1_ACCEPTANCE.json
```

Validated result:

```text
cycles = 2
continuity_proven = true
existing_warehouse_route_proven = true
run1 completed_candidate.route_status = RELEASED_TO_EXISTING_MULTI_SOURCE_WAREHOUSE
run2 continuity.previous_state_found = true
queue_before = 59
queue_after = 61
active_memory_mutated = false
direct_active_memory_write = false
no_new_store_created = true
```

Interpretation:

```text
The agent now has a short-term active-thought state. Completed candidates are released into the existing multi-source intake/warehouse instead of creating a duplicate store.
```

Next repair candidate:

```text
FRONTIER_TO_BUILD_TASK_ROUTER_V1
or
SHORT_TERM_STATE_TO_NEXT_TASK_ROUTER_V1
```
## 10. Short-Term State To Next Task Router acceptance

Status: PROVEN_LAB / ACCEPTED

```text
SHORT_TERM_STATE_TO_NEXT_TASK_ROUTER_V1 = PASS
```

Proof:

```text
tests/self_development/SHORT_TERM_STATE_TO_NEXT_TASK_ROUTER_V1_PROOF.json
operations/autonomous_inner_motor/reports/SHORT_TERM_STATE_TO_NEXT_TASK_ROUTER_V1_ACCEPTANCE.json
```

Validated result:

```text
cycles = 2
run2_previous_state_found = true
selected_next_task = FRONTIER_TO_BUILD_TASK_ROUTER_V1
selector_only = true
execution_allowed = false
queue_before = 61
queue_after = 63
active_memory_mutated = false
direct_active_memory_write = false
no_new_store_created = true
```

Interpretation:

```text
Short-term state now feeds next-task selection. The agent can choose the next repair direction, but cannot yet turn it into a full build task contract.
```

Next repair:

```text
FRONTIER_TO_BUILD_TASK_ROUTER_V1
```
## 11. Frontier To Build Task Router acceptance

Status: PROVEN_LAB / ACCEPTED

```text
FRONTIER_TO_BUILD_TASK_ROUTER_V1 = PASS
```

Proof:

```text
tests/self_development/FRONTIER_TO_BUILD_TASK_ROUTER_V1_PROOF.json
operations/autonomous_inner_motor/reports/FRONTIER_TO_BUILD_TASK_ROUTER_V1_ACCEPTANCE.json
```

Validated result:

```text
cycles = 2
run2_previous_state_found = true
selected_next_task = FRONTIER_TO_BUILD_TASK_ROUTER_V1
contract.task_type = BUILD_TASK_CONTRACT
contract.execution_allowed = false
validator = validators/validate_frontier_to_build_task_router_v1.ps1
proof = tests/self_development/FRONTIER_TO_BUILD_TASK_ROUTER_V1_PROOF.json
queue_before = 63
queue_after = 65
active_memory_mutated = false
direct_active_memory_write = false
no_new_store_created = true
```

Interpretation:

```text
The mind can now move from selected frontier to a bounded build task contract. The next missing piece is a guarded execution gate for contracts, not free auto-patching.
```

Next repair:

```text
BUILD_TASK_CONTRACT_EXECUTION_GATE_V1
```
## 12. Build Task Contract Execution Gate acceptance

Status: PROVEN_LAB / ACCEPTED

```text
BUILD_TASK_CONTRACT_EXECUTION_GATE_V1 = PASS
```

Proof:

```text
tests/self_development/BUILD_TASK_CONTRACT_EXECUTION_GATE_V1_PROOF.json
operations/autonomous_inner_motor/reports/BUILD_TASK_CONTRACT_EXECUTION_GATE_V1_ACCEPTANCE.json
```

Validated result:

```text
cycles = 2
run2_previous_state_found = true
gate_decision = BLOCKED_CONTRACT_EXECUTION_NOT_AUTHORIZED
effective_execution_allowed = false
auto_execution_performed = false
contract_task_id = FRONTIER_TO_BUILD_TASK_ROUTER_V1
queue_before = 67
queue_after = 69
active_memory_mutated = false
direct_active_memory_write = false
no_new_store_created = true
```

Interpretation:

```text
The mind can now route a build-task contract through a static execution gate. It safely blocks execution when authority is absent. This is not an executor yet.
```

Next repair:

```text
BUILD_TASK_BOUNDED_EXECUTOR_V1
```
## 13. Build Task Bounded Executor acceptance

Status: PROVEN_LAB / ACCEPTED

```text
BUILD_TASK_BOUNDED_EXECUTOR_V1 = PASS
```

Proof:

```text
tests/self_development/BUILD_TASK_BOUNDED_EXECUTOR_V1_PROOF.json
operations/autonomous_inner_motor/reports/BUILD_TASK_BOUNDED_EXECUTOR_V1_ACCEPTANCE.json
```

Validated result:

```text
cycles = 2
run2_previous_state_found = true
execution_status = NOT_EXECUTED_GATE_BLOCKED
gate_decision = BLOCKED_CONTRACT_EXECUTION_NOT_AUTHORIZED
gate_effective_execution_allowed = false
executed_files_count = 0
validator_ran = false
rollback_needed = false
queue_before = 69
queue_after = 71
active_memory_mutated = false
direct_active_memory_write = false
no_new_store_created = true
```

Interpretation:

```text
The bounded executor shell exists and respects the execution gate. It does not execute when authority is absent. This is not yet authorized write execution.
```

Next repair:

```text
BUILD_TASK_BOUNDED_EXECUTOR_V2_ALLOWED_DRY_RUN
```
## 14. Build Task Bounded Executor V2 allowed dry-run acceptance

Status: PROVEN_LAB / ACCEPTED

```text
BUILD_TASK_BOUNDED_EXECUTOR_V2_ALLOWED_DRY_RUN = PASS
```

Proof:

```text
tests/self_development/BUILD_TASK_BOUNDED_EXECUTOR_V2_ALLOWED_DRY_RUN_PROOF.json
operations/autonomous_inner_motor/reports/BUILD_TASK_BOUNDED_EXECUTOR_V2_ALLOWED_DRY_RUN_ACCEPTANCE.json
```

Validated result:

```text
cycles = 2
run2_previous_state_found = true
gate_decision = READY_FOR_BOUNDED_EXECUTOR_DRY_RUN
effective_dry_run_allowed = true
effective_execution_allowed = false
execution_status = DRY_RUN_PLAN_READY_NO_WRITES
dry_run_plan_ready = true
planned_operations_count = 6
executed_files_count = 0
validator_ran = false
rollback_needed = false
queue_before = 73
queue_after = 75
active_memory_mutated = false
direct_active_memory_write = false
no_new_store_created = true
```

Interpretation:

```text
The executor can now produce an authorized dry-run plan over allowed files. It still does not write files or run validators.
```

Next repair:

```text
BUILD_TASK_BOUNDED_EXECUTOR_V3_MINIMAL_ALLOWED_WRITE_WITH_ROLLBACK
```
## 15. Repeat To Refocus Router acceptance

Status: PROVEN_LAB / ACCEPTED

```text
REPEAT_TO_REFOCUS_ROUTER_V1 = PASS
```

Proof:

```text
tests/self_development/REPEAT_TO_REFOCUS_ROUTER_V1_PROOF.json
operations/autonomous_inner_motor/reports/REPEAT_TO_REFOCUS_ROUTER_V1_ACCEPTANCE.json
```

Validated result:

```text
repeated_task = FRONTIER_TO_BUILD_TASK_ROUTER_V1
repeated_topic = aimo.deep_thinking.recursive_thought_frame.memory_learning
selected_next_task = REPEAT_TO_REFOCUS_ROUTER_V1
repeat_refocus_selected = true
queue_before = 86
queue_after = 87
active_memory_mutated = false
direct_active_memory_write = false
process_count = 0
```

Interpretation:

```text
The mind can now detect repeated recent topic/task and route to refocus instead of repeating the same technical frontier.
```

Open memory retrieval note:

```text
The count of 7 memory refs is currently a hard top-window/projection. A different topic changes which refs are selected, but not necessarily how many. Dynamic retrieval budget remains unbuilt.
```

Next repair:

```text
REFOCUS_TO_NEW_THOUGHT_SEED_V1
DYNAMIC_MEMORY_RETRIEVAL_BUDGET_V1
```
## 16. Refocus To New Thought Seed acceptance

Status: PROVEN_LAB / ACCEPTED

```text
REFOCUS_TO_NEW_THOUGHT_SEED_V1 = PASS
```

Proof:

```text
tests/self_development/REFOCUS_TO_NEW_THOUGHT_SEED_V1_PROOF.json
operations/autonomous_inner_motor/reports/REFOCUS_TO_NEW_THOUGHT_SEED_V1_ACCEPTANCE.json
```

Validated result:

```text
repeated_task = FRONTIER_TO_BUILD_TASK_ROUTER_V1
selected_next_task = REPEAT_TO_REFOCUS_ROUTER_V1
seed_status = PASS_REFOCUS_TO_NEW_THOUGHT_SEED_V1
seed_lens = unexamined_assumption
queue_before = 87
queue_after = 88
active_memory_mutated = false
direct_active_memory_write = false
process_count = 0
```

Interpretation:

```text
The mind can now transform repetition into a new thought seed. The next missing piece is consuming that seed as the next cycle's active thought.
```

Next repair:

```text
NEW_THOUGHT_SEED_TO_ACTIVE_GOAL_V1
DYNAMIC_MEMORY_RETRIEVAL_BUDGET_V1
```
## 17. New Thought Seed To Active Goal acceptance

Status: PROVEN_LAB / ACCEPTED

```text
NEW_THOUGHT_SEED_TO_ACTIVE_GOAL_V1 = PASS
```

Proof:

```text
tests/self_development/NEW_THOUGHT_SEED_TO_ACTIVE_GOAL_V1_PROOF.json
operations/autonomous_inner_motor/reports/NEW_THOUGHT_SEED_TO_ACTIVE_GOAL_V1_ACCEPTANCE.json
```

Validated result:

```text
seed_consumed = true
active_goal_source = REFOCUS_THOUGHT_SEED_ACTIVE_GOAL
active_goal = What assumption under the repeated topic has not been examined yet, and what different angle would make the next cycle stronger?
queue_before = 88
queue_after = 88
active_memory_mutated = false
direct_active_memory_write = false
process_count = 0
```

Interpretation:

```text
The next cycle can consume a refocus seed as its active internal goal when Owner did not provide an explicit question.
```

Next repair:

```text
DYNAMIC_MEMORY_RETRIEVAL_BUDGET_V1
```
## 18. Dynamic Memory Retrieval Budget acceptance

Status: PROVEN_LAB / ACCEPTED

```text
DYNAMIC_MEMORY_RETRIEVAL_BUDGET_V1 = PASS
```

Proof:

```text
tests/self_development/DYNAMIC_MEMORY_RETRIEVAL_BUDGET_V1_PROOF.json
operations/autonomous_inner_motor/reports/DYNAMIC_MEMORY_RETRIEVAL_BUDGET_V1_ACCEPTANCE.json
```

Validated result:

```text
seed_consumed = true
base_limit = 7
budget_target_count = 5
selected_count = 5
queue_before = 88
queue_after = 88
active_memory_mutated = false
direct_active_memory_write = false
process_count = 0
```

Interpretation:

```text
The retrieval count is no longer hard-wired to 7 on the refocus-seed path. Budget is selected before retrieval and uses active goal plus wake reflex context.
```

Next repair / observation:

```text
LIVE_OBSERVATION_5MIN_THOUGHT_AUDIT_V2_AFTER_REFOCUS_AND_DYNAMIC_BUDGET
```
