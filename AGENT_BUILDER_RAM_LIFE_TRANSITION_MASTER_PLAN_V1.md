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
Step 5: Run AUDIT E Orientation Card/Drift Sensor.
Step 6: Run AUDIT F Continuous Runtime Lab Design.
Step 7: Build IMMUTABLE_LIFE_ORIENTATION_CARD_V1.
Step 8: Build ORIENTATION_DRIFT_SENSOR_V1.
Step 9: Build CONTINUOUS_AGENT_RUNTIME_V1_LAB.
Step 10: Run bounded lab and compare against process-per-cycle life.
Step 11: Decide whether canonical life migrates or remains dual-mode.
```

## 6. Gate before continuous runtime implementation

Continuous runtime implementation is blocked until all are true:

```text
AUDIT_A_PASS
AUDIT_B_PASS
AUDIT_C_PASS
AUDIT_D_PASS
AUDIT_E_PASS
AUDIT_F_PASS
IMMUTABLE_LIFE_ORIENTATION_CARD_V1_PROVEN_LAB
ORIENTATION_DRIFT_SENSOR_V1_PROVEN_LAB
```

## 7. RAM-life target model

```text
one long-running process
agent state lives in RAM during life
orientation card loaded once
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
