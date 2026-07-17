# AGENT_BUILDER_MIND_LOGIC_DEEP_AUDIT_PLAN_V1

Status: ROOT_PLAN_DRAFTED

## 1. Purpose

Audit the agent mind, not the runtime shell.

Goal:

```text
Find why the agent loops, stalls, repeats old themes, fails to turn frontiers into build tasks, and does not yet use compact memory as working intelligence.
```

## 2. Current truth

```text
Canonical life still uses start_agent_life_v1.ps1.
RAM lab is PROVEN_LAB but not canonical replacement.
Compact memory write/queue path works.
Selective active compact memory retrieval is not mature.
Last canonical 5-minute run created queue packets but produced weak utility.
```

## 3. Main problem hypothesis

The agent has pieces of mind, but not a complete decision circuit.

Observed weak chain:

```text
wake context -> memory state check -> frontier selection -> queue packet
```

Missing stronger chain:

```text
wake context -> current goal -> retrieve relevant compact memory -> diagnose gap -> select build task -> execute/queue validated next action -> proof -> return-to-parent
```

## 4. Audit slices

### AUDIT_M1_CURRENT_MIND_TOPOLOGY_V1

Map actual decision pipeline:

```text
launcher
runner
wake context
memory checks
mind_logic_frame
action_decision_packet
frontier gates
queue packet creation
proof summary
```

Output:

```text
operations/autonomous_inner_motor/reports/MIND_AUDIT_M1_CURRENT_MIND_TOPOLOGY_V1.json
```

### AUDIT_M2_LOOP_AND_STALL_PATTERNS_V1

Study recent live trials and queue packets.

Questions:

```text
What topics repeat?
Where does decision not advance?
What selected_action_ids recur?
Does frontier choice become a build task?
Which steps produce appearance of progress but no useful action?
```

### AUDIT_M3_COMPACT_MEMORY_READ_PATH_V1

Separate write path from read/use path.

Questions:

```text
Does agent retrieve active compact memory cells?
Does it rank them by current goal?
Does retrieved memory affect decision?
Does proof show memory used, not only memory protected?
```

### AUDIT_M4_FRONTIER_TO_BUILD_TASK_GAP_V1

Audit why selected frontier does not become concrete construction work.

Questions:

```text
What is selected frontier?
What action is generated from it?
Is there a task contract?
Is there a validator target?
Is there proof expectation?
Does it return to parent goal?
```

### AUDIT_M5_DECISION_QUALITY_AND_UTILITY_V1

Measure useful output.

Signals:

```text
new validated organ
new validated reflex
new validator/proof
new concrete task
new memory atom that changes next decision
less repetition
clearer parent-return
```

### AUDIT_M6_MINIMUM_MIND_REPAIR_PLAN_V1

Create repair plan after audits.

Expected candidate organs:

```text
SELECTIVE_COMPACT_MEMORY_RETRIEVAL_V1
FRONTIER_TO_BUILD_TASK_ROUTER_V1
LOOP_STALL_DETECTOR_V1
DECISION_UTILITY_SCORE_V1
PARENT_GOAL_RETURN_GATE_V1
```

## 5. Forbidden shortcuts

```text
Do not run more life trials to hope for intelligence.
Do not call RAM lab a mind improvement.
Do not delete RAM transition evidence until canonical migration is accepted.
Do not claim compact memory is used unless proof shows retrieved atoms affecting decisions.
Do not let queue packet creation count as useful progress by itself.
```

## 6. First action

```text
AUDIT_M1_CURRENT_MIND_TOPOLOGY_V1
```

Boundary:

```text
audit_only = true
runtime_launched = false
active_memory_mutated = false
canonical_launcher_mutated = false
cycle_runner_mutated = false
```
