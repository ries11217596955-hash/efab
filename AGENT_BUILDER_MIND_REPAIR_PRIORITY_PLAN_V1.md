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
