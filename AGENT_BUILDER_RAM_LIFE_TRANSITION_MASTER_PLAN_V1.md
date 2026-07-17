# AGENT_BUILDER_RAM_LIFE_TRANSITION_MASTER_PLAN_V1

Status: MASTER_PLAN_CREATED / EXECUTION_GATED
Owner decision: before moving to continuous RAM-life, perform deep audits and define a gated transition path.

## 1. Goal

Move Agent Builder from process-per-cycle life with JSON/file bridges toward a continuous runtime body where active life state lives primarily in RAM and disk is used only for compact proof, checkpoints, crash recovery, accepted memory, and reports.

This transition must not turn into another file-factory. The target is not “more JSON”. The target is a safer organism runtime.

## 2. Current truth

Current life model:

```text
canonical launcher = operations/autonomous_inner_motor/start_agent_life_v1.ps1
cycle runner = operations/autonomous_inner_motor/run_autonomous_inner_motor.ps1
life = launcher loop + separate runner process per cycle
RAM state = lost when each runner exits
bridge = life_working_memory_context.json / proof files / runtime folders
```

Current proven improvements:

```text
DEFAULT_WAKE_REFLEXES_V2 = PROVEN_LAB
BODY_WAKE_RAW_RETENTION_V1 = PROVEN_LAB
LIFE_WORKING_MEMORY_V1 = PROVEN_LAB
```

Meaning:

```text
wake sensing exists
body wake raw retention is controlled
wake context can be reused across runner cycles
but life is still not a continuous in-RAM agent body
```

## 3. Non-goals

Do not immediately replace canonical launcher.
Do not launch an unbounded continuous process.
Do not give continuous runtime repair/git/codex/web authority.
Do not write active memory directly.
Do not keep raw cycle transcripts in RAM checkpoints.
Do not create file-per-breath under a new name.

## 4. Required audits before RAM-life

### AUDIT A — Current Runtime Topology

Question:

```text
How exactly does life currently start, loop, spawn runners, write files, and stop?
```

Must inspect:

```text
start_agent_life_v1.ps1
run_autonomous_inner_motor.ps1
process scan rules
trial summary generation
cycle proof generation
runtime folder layout
```

Output:

```text
operations/autonomous_inner_motor/reports/RAM_LIFE_AUDIT_A_RUNTIME_TOPOLOGY_V1.json
```

Acceptance:

```text
current process model described
cycle boundary described
file bridge surfaces listed
which state dies with runner process is named
which state survives on disk is named
```

### AUDIT B — State / Memory Layer Separation

Question:

```text
Which data belongs in orientation card, compact memory, RAM state, cycle scratch, proof, checkpoint, or archive?
```

Must classify:

```text
orientation / wake baseline
active compact memory
life working memory
cycle scratch
proof packs
runtime raw/debug
reports
accepted atoms
```

Output:

```text
operations/autonomous_inner_motor/reports/RAM_LIFE_AUDIT_B_STATE_MEMORY_LAYERS_V1.json
```

Acceptance:

```text
no memory layer is allowed to become a diary
life orientation is read-only during life
compact memory grows only through validators/gates
cycle scratch dies after cycle
RAM state has budget and checkpoint policy
```

### AUDIT C — File Growth / Retention / Proof Economy

Question:

```text
What files are still created per cycle and which are still unnecessary sidecars?
```

Must inspect:

```text
mutation_audit.files_written
proofPackRequiredFiles
runtime top offenders
compact memory intake queue growth
body wake raw retention
cycle sidecars
```

Output:

```text
operations/autonomous_inner_motor/reports/RAM_LIFE_AUDIT_C_FILE_PROOF_ECONOMY_V1.json
```

Acceptance:

```text
per-cycle file surfaces counted
raw/debug retention risk measured
compact proof target defined
sidecars that can move to RAM are listed
sidecars that must remain proof are listed
```

### AUDIT D — Continuous Runtime Safety / Immune System

Question:

```text
What protections must exist before a long-running process is allowed?
```

Must cover:

```text
single process lock / pid file
watchdog
heartbeat
stop signal
duration cap
memory budget
CPU/disk pressure budget
crash recovery checkpoint
duplicate runtime prevention
safe shutdown
quarantine on fault
```

Output:

```text
operations/autonomous_inner_motor/reports/RAM_LIFE_AUDIT_D_CONTINUOUS_SAFETY_V1.json
```

Acceptance:

```text
continuous runtime cannot start without lock
continuous runtime cannot run without heartbeat
continuous runtime cannot mutate repo/active memory in lab
crash recovery boundary is defined
manual stop path exists
```

### AUDIT E — Orientation Card / Drift Sensor Readiness

Question:

```text
What immutable orientation card must the continuous process load, and how do we detect it is stale?
```

Must define:

```text
IMMUTABLE_LIFE_ORIENTATION_CARD_V1 fields
ORIENTATION_DRIFT_SENSOR_V1 compare sources
operator-only update rule
stale signal shape
proof refs only, no raw dumps
```

Output:

```text
operations/autonomous_inner_motor/reports/RAM_LIFE_AUDIT_E_ORIENTATION_DRIFT_V1.json
```

Acceptance:

```text
card is read-only during life
agent cannot auto-update card
drift sensor can detect mismatch between card and repo/proofs/kernel
stale signal is compact
operator update path is explicit
```

### AUDIT F — Continuous Runtime Lab Design

Question:

```text
What is the smallest safe lab experiment proving RAM-state persists across cycles?
```

Must define:

```text
CONTINUOUS_AGENT_RUNTIME_V1_LAB
single process
SandboxExploration only
QueueOnly memory
no git mutation
no codex
no web
no repair
2-5 minute cap
same PID across cycles
RAM state persists
compact start/end/error proof only
```

Output:

```text
operations/autonomous_inner_motor/reports/RAM_LIFE_AUDIT_F_LAB_DESIGN_V1.json
```

Acceptance:

```text
lab design has start/stop/heartbeat/checkpoint/proof
same process id across cycles is required
RAM state counter persists without JSON bridge per cycle
repo clean after run
active memory not directly mutated
```

## 5. Transition sequence

```text
Step 0: Create this master plan and current reality audit index.
Step 1: Run AUDIT A Runtime Topology.
Step 2: Run AUDIT B State/Memory Layer Separation.
Step 3: Run AUDIT C File/Proof Economy.
Step 4: Run AUDIT D Continuous Safety/Immune System.
Step 5: Run AUDIT F Continuous Runtime Lab Design for an operator-supervised RAM lab.
Step 6: Build CONTINUOUS_AGENT_RUNTIME_V1_LAB as bounded supervised lab only.
Step 7: Run bounded lab and compare against process-per-cycle life.
Step 8: Decide whether canonical life remains dual-mode.
Step 9: Keep AUDIT E Orientation Card/Drift Sensor for future unattended autonomy, not as a blocker for supervised lab.
```

## 6. Gate before continuous runtime implementation

Operator-supervised continuous RAM lab implementation is blocked until all are true:

```text
AUDIT_A_PASS
AUDIT_B_PASS
AUDIT_C_PASS
AUDIT_D_PASS
AUDIT_F_PASS
MINIMAL_SUPERVISED_LIFE_CONTEXT_AVAILABLE
```

Unattended or longer autonomy runtime is blocked until all are true:

```text
AUDIT_E_PASS
IMMUTABLE_LIFE_ORIENTATION_CARD_V1_PROVEN_LAB
ORIENTATION_DRIFT_SENSOR_V1_PROVEN_LAB
```

## 7. RAM-life target model

```text
one long-running process
agent state lives in RAM during life
minimal supervised life context loaded once
wake context loaded once
cycle scratch stays local to RAM
compact memory retrieval is selective
validated atoms still go through compact memory gates
proof/checkpoint written only on boundary
raw/debug off by default
```

## 8. Forbidden shortcuts

```text
no direct replacement of canonical launcher
no infinite while loop without lock/heartbeat/stop
no auto-update orientation card
no active memory direct write
no git/codex/web authority in RAM lab
no per-cycle raw proof dump
no claim of PROVEN_LIVE from lab
```

## 9. First execution slice

Current slice:

```text
RAM_LIFE_TRANSITION_MASTER_PLAN_V1
RAM_LIFE_AUDIT_0_CURRENT_REALITY_V1
```

Next slice after this commit:

```text
AUDIT_A_RUNTIME_TOPOLOGY_V1
```
## 10. AUDIT_D_CONTINUOUS_SAFETY_V1 detailed design

Status: WRITTEN_IN_PLAN / IMPLEMENTATION_BLOCKED_UNTIL_VALIDATED

Purpose:

```text
Define the immune system required before any operator-supervised continuous RAM-life lab is allowed to exist.
```

Continuous runtime is more dangerous than process-per-cycle life because mistakes can persist across cycles inside RAM. The safety layer must exist before the first supervised continuous lab. A full immutable orientation card is useful later, but not required while Owner/GPT are watching every short run.

### 10.1 Required safety organs

```text
runtime_lock
pid_file
heartbeat
stop_signal
watchdog
bounded_duration
memory_budget
cpu_budget
disk_budget
checkpoint_writer
crash_recovery_reader
quarantine_on_fault
duplicate_runtime_prevention
safe_shutdown
final_proof_writer
```

### 10.2 Runtime lock

Required file:

```text
.runtime/continuous_agent_runtime_v1/runtime.lock.json
```

Must include:

```text
runtime_id
pid
started_at
mode
owner
repo_head
heartbeat_path
stop_signal_path
checkpoint_path
```

Rules:

```text
no lock -> runtime may start
valid live lock -> runtime must refuse to start
stale lock -> runtime may quarantine stale lock only after process proof
```

### 10.3 Heartbeat

Required file:

```text
.runtime/continuous_agent_runtime_v1/heartbeat.json
```

Must update periodically with:

```text
runtime_id
pid
cycle_count
last_cycle_started_at
last_cycle_finished_at
last_safe_checkpoint
memory_mb
status
```

Rules:

```text
heartbeat proves the runtime is alive
watchdog reads heartbeat
missing/stale heartbeat triggers quarantine/stop recommendation
```

### 10.4 Stop signal

Required file:

```text
.runtime/continuous_agent_runtime_v1/STOP.json
```

Rules:

```text
runtime checks stop signal between cycles
runtime must stop safely if present
stop signal does not kill process violently
final proof must say stop_requested=true
```

### 10.5 Watchdog

Watchdog is observe-only in first lab.

Responsibilities:

```text
read lock
read heartbeat
check process exists
check duration cap
check memory/disk/cpu pressure
emit watchdog report
```

Forbidden in first lab:

```text
kill process automatically
clean runtime automatically
mutate active memory
mutate repo
launch codex/web/school
```

### 10.6 Budgets

First lab budget proposal:

```text
duration <= 5 minutes
mode = SandboxExploration
memory = measured and capped by policy before live use
cpu = observed, not optimized
repo mutation = false
active memory direct mutation = false
codex/web/git/repair = false
checkpoint count <= latest 3
raw debug retained = false by default
```

### 10.7 Checkpoint policy

Checkpoint is not memory diary.

Allowed:

```text
runtime_id
pid
cycle_count
orientation_card_ref/hash
wake_context_ref/hash
ram_state_compact
last_decision_summary
last_error_summary
last_safe_boundary
```

Forbidden:

```text
full compact memory dump
raw reasoning transcript
raw proof bodies
large repo inventory
unbounded cycle history
```

### 10.8 Crash recovery

First lab crash recovery can be proof-only.

Required:

```text
if runtime exits unexpectedly, final/error proof must preserve last checkpoint ref
restart must not auto-resume without operator authority
stale lock must not be blindly deleted
```

### 10.9 Quarantine on fault

Faults:

```text
duplicate runtime detected
heartbeat stale
memory budget exceeded
duration cap exceeded
checkpoint write failed
proof write failed
unexpected repo dirty state
active memory mutation detected
```

Response:

```text
stop after current cycle if safe
write fault proof
mark runtime QUARANTINED
no cleanup unless separate retention authority exists
```

### 10.10 Start gate for CONTINUOUS_AGENT_RUNTIME_V1_LAB

Lab cannot start unless all are true:

```text
repo clean
remote delta 0/0
process_count 0
active memory root exists
minimal supervised life context exists or is generated from current canonical launch context
runtime lock absent or proven stale
heartbeat path writable
checkpoint path writable
duration cap provided
SandboxExploration only
QueueOnly only
git/codex/web/repair disabled
proof path writable
```

### 10.11 Proof expectations

Lab proof must include:

```text
same_pid_across_cycles=true
cycle_count > 1
ram_state_counter_persisted=true
per_cycle_json_bridge_used_for_ram_state=false
lock_created=true
heartbeat_written=true
stop_signal_supported=true
checkpoint_written=true
final_proof_written=true
repo_mutated=false
active_memory_direct_mutated=false
codex_launched=false
web_launched=false
school_launched=false
```
## 11. Operator correction — orientation card is future autonomy, not supervised lab blocker

Status: ACTIVE_PLAN_CORRECTION

Owner correction:

```text
At the current stage, Owner/GPT inspect the agent every 5-10 minutes. The agent is not being launched unattended for days. Therefore a powerful immutable orientation card and drift sensor are useful future organs, but they should not block the first supervised RAM-life lab.
```

Corrected rule:

```text
short supervised RAM lab -> needs safety gates + minimal supervised life context
longer/unattended autonomy -> needs immutable orientation card + drift sensor
```

Reason:

```text
A full orientation card is a self-orientation/autonomy organ. It prevents an agent from drifting when it is less supervised. Right now the operator loop is still the primary orientation and correction system.
```

Current next step after AUDIT_D:

```text
AUDIT_F_CONTINUOUS_RUNTIME_LAB_DESIGN_V1
```

AUDIT_E remains in the plan as future autonomy preparation, not immediate blocker.
## 12. AUDIT_F_CONTINUOUS_RUNTIME_LAB_DESIGN_V1 detailed design

Status: WRITTEN_IN_PLAN / IMPLEMENTATION_NOT_STARTED

Purpose:

```text
Design the smallest operator-supervised RAM-life lab proving that an agent can keep live state inside one long-running process across multiple cycles.
```

This lab is not a new full agent life. It is a proof slice for one principle:

```text
same process + RAM state persistence + safety boundary
```

### 12.1 Lab name

```text
CONTINUOUS_AGENT_RUNTIME_V1_LAB
```

### 12.2 Scope

Allowed:

```text
single PowerShell process
2-5 minute duration cap
SandboxExploration only
QueueOnly only
minimal supervised life context
RAM state object
cycle loop inside same process
heartbeat
runtime lock
stop signal support
checkpoint latest only / bounded latest 3
compact final proof
```

Forbidden:

```text
replace canonical launcher
run unattended
mutate repo
write active memory directly
launch Codex
use web
run git mutation
repair body
cleanup runtime
load full compact memory
keep raw cycle transcript
create per-cycle JSON bridge for RAM state
```

### 12.3 Minimal supervised life context

Because Owner/GPT supervise short runs, the lab does not need full immutable orientation card.

Minimal context must include:

```text
runtime_id
mode
repo_root
repo_head
active_memory_root_exists
compact_memory_queue_exists
allowed_actions = none
memory_mode = QueueOnly
safety_mode = supervised_lab
current_goal = prove RAM state persists across cycles
forbidden = git/codex/web/repair/cleanup/active_memory_direct_write
```

### 12.4 RAM state object

The process must create one in-memory object, for example:

```text
$AgentState = @{
  runtime_id = ...
  pid = $PID
  started_at = ...
  cycle_count = 0
  ram_counter = 0
  recent_cycles = @()
  current_goal = 'prove_ram_state_persistence'
  last_checkpoint_ref = $null
}
```

Required proof:

```text
same pid across all cycles
ram_counter increases across cycles without reading per-cycle JSON bridge
recent_cycles lives in RAM during run
cycle_scratch is created and cleared in RAM
```

### 12.5 Cycle design

Each cycle:

```text
check stop signal
increment cycle_count
increment ram_counter
create cycle_scratch in RAM
perform minimal no-op/safe decision step
append compact cycle summary to AgentState.recent_cycles ring buffer
clear cycle_scratch
write heartbeat
optionally write bounded checkpoint
sleep small interval
```

Cycle must not call canonical runner in first lab, because calling the old runner would reintroduce process-per-cycle behavior.

### 12.6 Disk output policy

Allowed files:

```text
runtime.lock.json
heartbeat.json
checkpoints/latest.json
CONTINUOUS_AGENT_RUNTIME_V1_LAB_PROOF.json
CONTINUOUS_AGENT_RUNTIME_V1_LAB_SUMMARY.json
```

Not allowed:

```text
per-cycle mind_logic_frame.json
per-cycle action_decision_packet.json
per-cycle wake_body_audit
per-cycle default_wake_reflexes.json
per-cycle RAM bridge JSON
raw reasoning transcript
```

### 12.7 Start command proposal

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File operations/autonomous_inner_motor/run_continuous_agent_runtime_v1_lab.ps1 -DurationMinutes 2
```

Owner-facing parameters for lab:

```text
DurationMinutes only
```

Internal defaults:

```text
Mode = SandboxExploration
MemoryMode = QueueOnly
NoGit = true
NoCodex = true
NoWeb = true
NoRepair = true
NoCleanup = true
```

### 12.8 Validator expectations

Validator must prove:

```text
status = PASS_CONTINUOUS_AGENT_RUNTIME_V1_LAB
same_pid_across_cycles = true
cycle_count >= 2
ram_counter_final >= 2
ram_state_persisted = true
per_cycle_json_bridge_used_for_ram_state = false
lock_created = true
heartbeat_written = true
stop_signal_supported = true
checkpoint_written = true
final_proof_written = true
repo_mutated = false
active_memory_direct_mutated = false
codex_launched = false
web_launched = false
school_launched = false
raw_debug_retained = false
```

### 12.9 Acceptance boundary

This lab may claim only:

```text
PROVEN_LAB: one process can keep RAM state across multiple cycles under supervised safety gates
```

It may not claim:

```text
canonical life replaced
agent became autonomous
mind quality improved
compact memory integration solved
live/unattended runtime ready
```

### 12.10 Next implementation slice after this audit

If AUDIT_F validates, next slice is:

```text
CODEX_TASK_CONTINUOUS_AGENT_RUNTIME_V1_LAB_SLICE_A
```

But Codex task must be narrow:

```text
create lab script + validator + proof only
no canonical launcher mutation
no runner mutation
no compact memory mutation
no active memory mutation
no runtime cleanup
```
## 13. Transition plan status after 5-minute RAM lab

Status: PHASE_PROVEN_LAB_NOT_CANONICAL_REPLACEMENT

Current truth:

```text
CONTINUOUS_AGENT_RUNTIME_V1_LAB is PROVEN_LAB.
Canonical agent life is still start_agent_life_v1.ps1 + run_autonomous_inner_motor.ps1.
RAM lab has not replaced canonical life.
```

Proof:

```text
tests/self_development/CONTINUOUS_AGENT_RUNTIME_V1_LAB_PROOF.json
status = PASS_CONTINUOUS_AGENT_RUNTIME_V1_LAB
cycles = 125
same_pid_across_cycles = true
ram_state_persisted = true
```

Decision:

```text
Do not delete this transition plan yet.
Keep it as phase evidence until canonical launcher migration is explicitly designed, implemented, validated, and accepted.
```

Next focus:

```text
Agent mind / logic / decision audit, not more blind runtime launches.
```
