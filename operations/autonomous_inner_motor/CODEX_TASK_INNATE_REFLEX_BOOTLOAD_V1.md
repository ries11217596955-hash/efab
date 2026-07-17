# CODEX_TASK_INNATE_REFLEX_BOOTLOAD_V1

Status: READY_FOR_CODEX / NOT_RUN
Task type: narrow implementation slice
Target: canonical AIMO runner boot-loads permanent innate reflex kernel once per run
Root plan: AGENT_BUILDER_INNATE_REFLEX_KERNEL_V1_PLAN.md
Depends on: CALLABLE_INNATE_REFLEX_KERNEL_V1_SLICE_A

## 0. Role and boundary

You are Codex, an implementation tool.
You are not the Builder brain.

Implement only `INNATE_REFLEX_BOOTLOAD_V1`.

Correct model:

```text
permanent kernel is stored once:
  operations/autonomous_inner_motor/innate_reflex_kernel_v1.json

canonical life boot-loads it once per run:
  runtime innate_reflex_bootload.json

cycles may reference bootload:
  loaded=true + ref path
```

Wrong model:

```text
recreate reflexes every run
write full reflex matrix every cycle
make body_audit_reflex callable
invoke body self-inspection
```

## 1. PREFLIGHT rule

Before any file writes, output exactly one status:

```text
PREFLIGHT_PASS
BLOCKED_PREFLIGHT
```

No file writes before `PREFLIGHT_PASS`.

Final report must include:

```text
Files changed before PREFLIGHT_PASS: YES/NO
```

Expected: NO.

PREFLIGHT must check/report:

```text
repo root
branch
HEAD
git status --short --untracked-files=all
origin delta
root bootload plan validator exists and passes
Slice A kernel validator exists and passes
canonical runner exists
canonical launcher exists and is DurationMinutes-only
permanent kernel exists
builder script exists
legacy launch quarantine exists
no active life/codex process conflict
```

If repo is dirty before changes, return `BLOCKED_PREFLIGHT`.

## 2. Read first

Read:

```text
AGENT_BUILDER_INNATE_REFLEX_KERNEL_V1_PLAN.md
operations/autonomous_inner_motor/innate_reflex_kernel_v1.json
operations/autonomous_inner_motor/build_innate_reflex_kernel_v1.ps1
validators/validate_callable_innate_reflex_kernel_v1.ps1
operations/autonomous_inner_motor/run_autonomous_inner_motor.ps1
operations/autonomous_inner_motor/start_agent_life_v1.ps1
operations/autonomous_inner_motor/AGENT_LIFE_LEGACY_LAUNCH_QUARANTINE_V1.json
validators/validate_agent_life_launcher_v1.ps1
validators/validate_innate_reflex_bootload_plan_v1.ps1
```

## 3. Allowed files

Allowed modifications:

```text
operations/autonomous_inner_motor/run_autonomous_inner_motor.ps1
AGENT_BUILDER_SELF_NOTEBOOK.md
```

Allowed new files:

```text
validators/validate_innate_reflex_bootload_v1.ps1
tests/self_development/INNATE_REFLEX_BOOTLOAD_V1_PROOF.json
operations/autonomous_inner_motor/reports/INNATE_REFLEX_BOOTLOAD_V1_ACCEPTANCE.json
```

Allowed runtime output during validation/smoke:

```text
.runtime/**/innate_reflex_bootload.json
.runtime/**/SANDBOX_EXPLORATION_PROOF.json
.runtime/**/sandbox_proof_pack_manifest.json
```

No other repo files may be modified.

## 4. Forbidden scope

Do not modify:

```text
operations/autonomous_inner_motor/start_agent_life_v1.ps1
operations/autonomous_inner_motor/innate_reflex_kernel_v1.json
operations/autonomous_inner_motor/build_innate_reflex_kernel_v1.ps1
operations/body_self_inspection/*
.runtime/active_compact_semantic_memory_v1
legacy launch surfaces
maps/passports/contracts
```

Do not:

```text
invoke BODY_SELF_INSPECTION_CIRCUIT_V1
make body_audit_reflex callable
write full 25-reflex matrix every cycle
write active memory directly
launch long life run
browse web
launch Codex recursively
create a second life launcher
```

## 5. Required implementation

Modify runner so canonical AIMO life boot-loads the permanent kernel once per run.

Use existing builder:

```powershell
operations/autonomous_inner_motor/build_innate_reflex_kernel_v1.ps1
```

At run/start, produce compact runtime bootload proof:

```text
innate_reflex_bootload.json
```

Required fields:

```text
schema = innate_reflex_bootload_v1
status = PASS_INNATE_REFLEX_BOOTLOAD_V1
loaded = true
source = operations/autonomous_inner_motor/innate_reflex_kernel_v1.json
builder = operations/autonomous_inner_motor/build_innate_reflex_kernel_v1.ps1
reflex_count = 25
available_not_wired_count = 1
reserved_count = 24
callable_count = 0
body_audit_reflex.reflex_id = body_audit_reflex
body_audit_reflex.status = AVAILABLE_NOT_WIRED
body_audit_reflex.organ_id = BODY_SELF_INSPECTION_CIRCUIT_V1
body_audit_reflex.can_hear_body = true
body_audit_reflex.callable = false
body_audit_reflex.invoked_this_cycle = false
body_audit_reflex.body_inspection_invoked = false
boundary.body_inspection_invoked = false
boundary.active_memory_mutated_by_bootload = false
boundary.live_process_touched = false
boundary.repair_executed = false
boundary.legacy_launch_used = false
boundary.permanent_kernel_mutated = false
```

Runner proof integration:

```text
SANDBOX_EXPLORATION_PROOF.json includes compact innate_reflex_bootload object or reference.
sandbox_proof_pack_manifest.json requires/includes innate_reflex_bootload.json.
```

Cycle behavior:

```text
Do not write full reflex matrix per cycle.
Do not write the full kernel every cycle.
If cycle-level proof needs anything, include only:
  innate_reflex_bootload_loaded = true
  innate_reflex_bootload_ref = <path>
```

## 6. Required validator

Create:

```text
validators/validate_innate_reflex_bootload_v1.ps1
```

It must validate without long life run:

```text
runner parses
launcher parses
permanent kernel parses
builder parses
Slice A validator passes
bootload plan validator passes
runner contains innate_reflex_bootload.json
runner calls/uses build_innate_reflex_kernel_v1.ps1
runner proof includes innate_reflex_bootload
proof pack manifest includes/requires innate_reflex_bootload.json
runner does not invoke BODY_SELF_INSPECTION_CIRCUIT_V1
runner does not modify innate_reflex_kernel_v1.json
launcher remains DurationMinutes-only
body_audit_reflex remains callable=false
```

Validator must also perform a small isolated runner/bootload proof check if feasible without long run. If not feasible, it must directly invoke builder to create a temp bootload-shaped object and validate shape.

Write proof:

```text
tests/self_development/INNATE_REFLEX_BOOTLOAD_V1_PROOF.json
```

Expected status:

```text
PASS_INNATE_REFLEX_BOOTLOAD_V1
```

## 7. Required validation commands

Run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File validators/validate_innate_reflex_bootload_v1.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File validators/validate_callable_innate_reflex_kernel_v1.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File validators/validate_agent_life_launcher_v1.ps1
```

Do not run a 10-minute life trial.
A tiny validator-controlled bootload check is allowed.

## 8. Final report required fields

Final report must include:

```text
PREFLIGHT status
Files changed before PREFLIGHT_PASS: YES/NO
Files changed
Validators run
Proof files
Bootload writes full matrix every cycle: YES/NO
Canonical launcher modified: YES/NO
Permanent kernel modified: YES/NO
Body inspection invoked: YES/NO
body_audit_reflex callable: YES/NO
Active memory mutated: YES/NO
Legacy launch used: YES/NO
Known risks / next slice
```

Expected final truth:

```text
Bootload writes full matrix every cycle: NO
Canonical launcher modified: NO
Permanent kernel modified: NO
Body inspection invoked: NO
body_audit_reflex callable: NO
Active memory mutated: NO
Legacy launch used: NO
Next slice: BODY_AUDIT_REFLEX_OBSERVE_HOOK_V1 only after Owner approval
```
