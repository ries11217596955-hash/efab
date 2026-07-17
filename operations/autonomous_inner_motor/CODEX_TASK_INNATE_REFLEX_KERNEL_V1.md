# CODEX_TASK_INNATE_REFLEX_KERNEL_V1

Status: READY_FOR_CODEX / NOT_RUN
Task type: bounded implementation slice
Target system: canonical AIMO life
Target organ layer: INNATE_REFLEX_KERNEL_V1
Primary root plan: AGENT_BUILDER_INNATE_REFLEX_KERNEL_V1_PLAN.md

## 0. Role and boundary

You are Codex, an implementation tool.
You are not the Builder brain.
Do not invent architecture outside the plan.
Do not replace canonical launch.
Do not implement all reflexes.

Implement `INNATE_REFLEX_KERNEL_V1` as a canonical-life layer.
The first real reflex is `BODY_AWARENESS_REFLEX_V1`.
All other reflexes are reserved placeholders, not fake built organs.

## 1. PREFLIGHT rule

Before any file writes, produce exactly one:

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
canonical launcher exists
AIMO runner exists
body self-inspection organ knowledge card exists
legacy launch quarantine exists
single-launch wiring audit PASS
body integration plan exists
```

If repo is dirty before changes, return `BLOCKED_PREFLIGHT` unless the dirt is explicitly expected and listed.

## 2. Read first

Read these files before changing anything:

```text
AGENT_BUILDER_INNATE_REFLEX_KERNEL_V1_PLAN.md
operations/autonomous_inner_motor/start_agent_life_v1.ps1
operations/autonomous_inner_motor/run_autonomous_inner_motor.ps1
operations/autonomous_inner_motor/select_agent_next_action_candidate_v1.ps1
operations/autonomous_inner_motor/organ_knowledge/BODY_SELF_INSPECTION_CIRCUIT_V1_KNOWLEDGE.json
operations/autonomous_inner_motor/BODY_SELF_INSPECTION_CANONICAL_INTEGRATION_PLAN_V1.md
operations/autonomous_inner_motor/AGENT_LIFE_LEGACY_LAUNCH_QUARANTINE_V1.json
operations/autonomous_inner_motor/reports/AGENT_LIFE_SINGLE_LAUNCH_WIRING_AUDIT_V1.json
validators/validate_body_self_inspection_organ_knowledge_v1.ps1
validators/validate_agent_life_quarantine_and_body_integration_v1.ps1
validators/validate_agent_life_launcher_v1.ps1
```

## 3. Allowed files

Allowed new files:

```text
operations/autonomous_inner_motor/innate_reflex_kernel_v1.json
operations/autonomous_inner_motor/build_innate_reflex_kernel_v1.ps1
validators/validate_innate_reflex_kernel_v1.ps1
tests/self_development/INNATE_REFLEX_KERNEL_V1_PROOF.json
```

Allowed modifications:

```text
operations/autonomous_inner_motor/run_autonomous_inner_motor.ps1
AGENT_BUILDER_SELF_NOTEBOOK.md
```

Allowed runtime outputs when validating:

```text
.runtime/autonomous_inner_motor/<run>/innate_reflex_kernel.json
```

Do not modify any other file unless you stop and explain why in the final report.

## 4. Forbidden scope

Do not edit or mutate:

```text
operations/autonomous_inner_motor/start_agent_life_v1.ps1
operations/body_self_inspection/*
operations/reasoning/*
.runtime/active_compact_semantic_memory_v1
legacy launch surfaces
maps/passports/contracts
credentials/secrets/env files
school runtime scripts
```

Do not:

```text
launch live long-run
launch Codex recursively
browse web
execute repair drafts
write active memory directly
Do not invoke body self-inspection circuit
claim body inspection is wired
claim all reflexes are implemented
add new Owner-facing launch parameters
```

## 5. Required implementation

### 5.1 Kernel manifest

Create `operations/autonomous_inner_motor/innate_reflex_kernel_v1.json`.

It must include at least 18 reflex slots:

```text
body_awareness_reflex
proof_pain_reflex
confusion_reflex
owner_call_reflex
danger_stop_reflex
repetition_boredom_reflex
memory_hunger_reflex
source_hunger_reflex
sleep_digest_reflex
runtime_pressure_reflex
body_damage_reflex
unknown_gap_reflex
return_to_parent_reflex
quarantine_reflex
self_map_reflex
food_request_reflex
boundary_respect_reflex
validator_need_reflex
```

Only `body_awareness_reflex` may be `AVAILABLE_NOT_INVOKED`.
All others must be `RESERVED_NOT_BUILT`.

### 5.2 Builder/loader script

Create `operations/autonomous_inner_motor/build_innate_reflex_kernel_v1.ps1`.

It must:

```text
read innate_reflex_kernel_v1.json
read BODY_SELF_INSPECTION_CIRCUIT_V1_KNOWLEDGE.json
produce a runtime-safe kernel object
prove body_awareness_reflex references BODY_SELF_INSPECTION_CIRCUIT_V1
set body_awareness_reflex.can_hear_body = true
set body_awareness_reflex.invoked_this_cycle = false by default
set body_awareness_reflex.body_inspection_invoked = false
include boundary flags
write output only when OutputPath is provided
```

### 5.3 Runner integration

Modify `operations/autonomous_inner_motor/run_autonomous_inner_motor.ps1` so each canonical AIMO cycle writes:

```text
innate_reflex_kernel.json
```

and includes in `SANDBOX_EXPLORATION_PROOF.json`:

```text
innate_reflex_kernel
```

and includes in proof pack manifest required files:

```text
innate_reflex_kernel.json
```

It must not invoke body self-inspection.
It must not mutate active memory directly.
It must not change canonical launcher parameters.

### 5.4 Validator

Create `validators/validate_innate_reflex_kernel_v1.ps1`.

It must validate:

```text
manifest parses
builder/loader parses
runner parses
18+ reflexes exist
body_awareness_reflex exists
body_awareness_reflex.innate == true
body_awareness_reflex.organ_id == BODY_SELF_INSPECTION_CIRCUIT_V1
body_awareness_reflex.can_hear_body == true
body_awareness_reflex.status == AVAILABLE_NOT_INVOKED
reserved reflexes are RESERVED_NOT_BUILT
body inspection invoked false
runner emits innate_reflex_kernel.json
runner proof includes innate_reflex_kernel
proof pack requires innate_reflex_kernel.json
canonical launcher still has only DurationMinutes
legacy launch quarantine exists
```

Validator must write:

```text
tests/self_development/INNATE_REFLEX_KERNEL_V1_PROOF.json
```

Expected status:

```text
PASS_INNATE_REFLEX_KERNEL_V1
```

## 6. Required proof boundary

All proof must show:

```text
body_inspection_invoked = false
action_execution_allowed = false
repair_executed = false
active_memory_mutated = false by this kernel
live_process_touched = false
codex_launched = false
web_launched = false
legacy_launch_used = false
canonical_launcher_modified = false
```

## 7. Acceptance command set

Run at minimum:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File validators/validate_innate_reflex_kernel_v1.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File validators/validate_body_self_inspection_organ_knowledge_v1.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File validators/validate_agent_life_quarantine_and_body_integration_v1.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File validators/validate_agent_life_launcher_v1.ps1
```

Do not run a 10-minute life trial in this Codex task.
A 1-minute canonical smoke may be done later by the operator after review.

## 8. Final report required fields

Report exactly:

```text
PREFLIGHT status
Files changed before PREFLIGHT_PASS: YES/NO
Files changed
Validators run
Proof files
Boundary status
Canonical launcher changed: YES/NO
Body inspection invoked: YES/NO
Active memory mutated: YES/NO
Legacy launch used: YES/NO
Known risks / next slice
```
