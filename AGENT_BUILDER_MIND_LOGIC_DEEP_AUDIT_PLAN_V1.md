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
## 7. Three parallel memory/life tracks

Status: ACTIVE_TRACKING_RULE

Owner correction:

```text
Work must proceed sequentially, but not forget three directions:
1. Compact Memory
2. Short-Term Memory
3. RAM / life process
```

### 7.1 Track A — Compact Memory

Current status:

```text
PARTIAL
write/queue path works
active memory root exists and is protected
selective read/use path is not mature
```

Known gap:

```text
Agent can create queue packets, but does not yet prove that it retrieves relevant active compact memory cells and uses them to change a decision.
```

Needed audit:

```text
AUDIT_M3_COMPACT_MEMORY_READ_PATH_V1
```

Candidate organ:

```text
SELECTIVE_COMPACT_MEMORY_RETRIEVAL_V1
```

Acceptance condition:

```text
proof shows retrieved memory atoms, relevance reasons, and decision effect
```

### 7.2 Track B — Short-Term Memory

Current status:

```text
PARTIAL / NOT_FULL_ORGAN
LIFE_WORKING_MEMORY_V1 exists and passed lab validation
but it is not yet a complete short-term mind memory organ
```

What exists:

```text
A life working memory context can be created once and reused across canonical process-per-cycle life runs.
It reduces repeated wake files and stores compact wake context for a run.
```

Known gap:

```text
It does not yet act like active short-term reasoning memory: current objective, recent decisions, unresolved blockers, hypotheses, last failed attempt, next intended step, and parent-goal return state.
```

Needed audit:

```text
AUDIT_S1_SHORT_TERM_MEMORY_CURRENT_STATE_V1
```

Candidate organs:

```text
SHORT_TERM_MIND_STATE_V1
RECENT_DECISION_RING_V1
UNRESOLVED_BLOCKER_MEMORY_V1
PARENT_GOAL_STACK_V1
```

Acceptance condition:

```text
proof shows short-term state survives across cycles and changes next decision without becoming a raw diary or long-term memory dump
```

### 7.3 Track C — RAM / life process

Current status:

```text
PROVEN_LAB_NOT_CANONICAL
CONTINUOUS_AGENT_RUNTIME_V1_LAB passed 5-minute proof
canonical life still uses start_agent_life_v1.ps1 + run_autonomous_inner_motor.ps1
```

Known debt:

```text
RAM lab has not been migrated into canonical life.
Transition plan remains open.
```

Needed future audit/design:

```text
AUDIT_R1_RAM_CANONICAL_MIGRATION_GAP_V1
```

Candidate organs/slices:

```text
CANONICAL_RAM_LIFE_MIGRATION_PLAN_V1
DUAL_MODE_LIFE_LAUNCHER_V1
RAM_RUNTIME_WATCHDOG_V1
RAM_TO_CANONICAL_PROOF_COMPARISON_V1
```

Acceptance condition:

```text
explicit owner decision + validator proof that RAM mode can replace or coexist with canonical life without losing safety, memory gates, proofs, stop control, and operator visibility
```

### 7.4 Sequencing rule

Do not jump between tracks randomly.

Default order:

```text
1. Audit mind topology.
2. Audit compact memory read path.
3. Audit short-term memory current state.
4. Audit frontier-to-build-task gap.
5. Only then decide whether RAM migration is needed immediately or later.
```

Reason:

```text
RAM gives a different body. Compact memory and short-term memory give the mind usable context. A better body without a better mind only loops faster.
```
## 8. Reflection / reflexion debt source

Status: ACTIVE_DEBT / DO_NOT_FORGET

Owner reminder:

```text
We discussed reflection/reflexion before RAM work accelerated. The debt must not be lost.
```

Important distinction:

```text
Reflexes = callable built-in sensing/action capabilities.
Reflection = the mind's ability to inspect its own thinking, detect loops/stalls/errors, score utility, and return to parent goal with a stronger next step.
```

### 8.1 Where reflexes are already written

Source:

```text
AGENT_BUILDER_INNATE_REFLEX_KERNEL_V1_PLAN.md
```

Implemented/proven parts include:

```text
INNATE_REFLEX_KERNEL_V1
INNATE_REFLEX_BOOTLOAD_V1
DEFAULT_WAKE_REFLEXES_V2
body_audit_reflex
repo_reality_reflex
process_scan_reflex
runtime_pressure_reflex
active_memory_read_reflex
```

Status:

```text
REFLEX_TRACK_PARTIAL_PROVEN
```

Do not confuse this with reflection.

### 8.2 Where reflection is currently scattered

Reflection-like concepts are currently spread across:

```text
AGENT_BUILDER_MIND_LOGIC_DEEP_AUDIT_PLAN_V1.md
AGENT_BUILDER_SELF_NOTEBOOK.md
operations/autonomous_inner_motor/run_autonomous_inner_motor.ps1 proof fields
recent SANDBOX_EXPLORATION_PROOF.json cycle proofs
```

Known scattered pieces:

```text
loop/stall pattern analysis
mind_logic_frame
action_decision_packet
return_to_parent lens
decision quality / utility scoring
frontier-to-build-task gap
parent-goal return gate
```

Status:

```text
REFLECTION_TRACK_NOT_FULL_ORGAN
```

### 8.3 Reflection organ debt

Needed audit:

```text
AUDIT_REF1_REFLECTION_CURRENT_STATE_V1
```

Questions:

```text
Does the agent inspect the last cycle before choosing the next one?
Does it detect repeated topics/actions?
Does it detect when queue packet creation is fake progress?
Does it explain why the last action did or did not advance the parent goal?
Does it produce a sharper next step instead of looping?
Does it distinguish body/runtime issue from mind/logic issue?
Does it know when to stop and ask for operator decision?
```

Candidate organs:

```text
SELF_REFLECTION_FRAME_V1
LOOP_STALL_DETECTOR_V1
DECISION_UTILITY_SCORE_V1
PARENT_GOAL_RETURN_GATE_V1
LAST_ACTION_POSTMORTEM_V1
FAKE_PROGRESS_DETECTOR_V1
NEXT_STEP_SHARPENER_V1
```

### 8.4 Acceptance condition for reflection

Reflection is accepted only when proof shows:

```text
last_cycle_observed = true
loop_or_stall_checked = true
utility_score_computed = true
parent_goal_delta_computed = true
fake_progress_checked = true
next_step_changed_by_reflection = true
reflection_output_used_by_action_decision = true
```

Not accepted:

```text
agent merely writes a summary
agent writes another queue packet without changed next action
agent repeats the same frontier
agent says it reflected but proof does not show decision effect
```

### 8.5 Updated sequencing with reflection

Default order now:

```text
1. AUDIT_M1_CURRENT_MIND_TOPOLOGY_V1
2. AUDIT_REF1_REFLECTION_CURRENT_STATE_V1
3. AUDIT_M3_COMPACT_MEMORY_READ_PATH_V1
4. AUDIT_S1_SHORT_TERM_MEMORY_CURRENT_STATE_V1
5. AUDIT_M4_FRONTIER_TO_BUILD_TASK_GAP_V1
6. AUDIT_M5_DECISION_QUALITY_AND_UTILITY_V1
7. AUDIT_R1_RAM_CANONICAL_MIGRATION_GAP_V1 when owner decides migration timing
```

Reason:

```text
Without reflection, compact memory and short-term memory can still feed a looping mind. Reflection is the circuit that notices the loop and changes the next decision.
```
## 9. Correction — reflex debt is the active Owner-confirmed branch

Status: ACTIVE_CORRECTION

Owner correction:

```text
The discussed topic was reflexes, not a separate reflection/reflexion organ set.
```

Correction:

```text
REFLECTION_DEBT_SOURCE_MAP_V1 is not an Owner-confirmed active branch.
It is superseded for current planning by REFLEX_DEBT_SOURCE_MAP_V1.
```

Active source:

```text
AGENT_BUILDER_INNATE_REFLEX_KERNEL_V1_PLAN.md
section: Reflex groups and proposed first matrix
```

Full matrix in that source contains 25 reserved reflex slots:

```text
body_audit_reflex
organ_audit_reflex
full_body_map_audit_reflex
repo_reality_reflex
process_scan_reflex
runtime_pressure_reflex
preflight_reflex
validator_run_reflex
proof_pack_reflex
rollback_reflex
quarantine_reflex
stop_or_freeze_reflex
memory_queue_reflex
active_memory_read_reflex
memory_digest_reflex
handoff_write_reflex
self_notebook_update_reflex
directory_create_reflex
file_normalize_reflex
archive_backup_reflex
artifact_convert_reflex
codex_consult_reflex
codex_task_authoring_reflex
web_source_search_reflex
source_ingestion_reflex
```

Current status:

```text
REFLEX_TRACK_PARTIAL_PROVEN
```

Known proven/wired subset:

```text
DEFAULT_WAKE_REFLEXES_V2 = wake-default context includes body_audit_reflex, repo_reality_reflex, process_scan_reflex, runtime_pressure_reflex, active_memory_read_reflex.
```

Remaining debt:

```text
Most reflex slots are reserved/not fully built/not fully wired.
Need audit to compare plan slots vs registry vs canonical wake/default usage.
```

Needed audit:

```text
AUDIT_RX1_REFLEX_MATRIX_CURRENT_STATE_V1
```
