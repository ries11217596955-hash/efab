# CODEX_TASK_CALLABLE_INNATE_REFLEX_KERNEL_V1

Status: READY_FOR_CODEX / NOT_RUN
Task type: bounded implementation slice
Target system: canonical AIMO life
Root plan: AGENT_BUILDER_INNATE_REFLEX_KERNEL_V1_PLAN.md
Correct model: callable innate reflexes, not behavioral laws

## 0. Role and boundary

You are Codex, an implementation tool.
You are not the Builder brain.
Do not invent architecture outside the root plan.
Do not replace canonical launch.
Do not implement all reflexes.
Do not invoke body self-inspection.

Implement `INNATE_REFLEX_KERNEL_V1` as a birth-layer registry for callable built-in reflexes.
The first real reflex is:

```text
body_audit_reflex
organ = BODY_SELF_INSPECTION_CIRCUIT_V1
status = AVAILABLE_NOT_WIRED
```

All other reflexes are reserved slots unless explicitly already implemented by existing repo proof.
For this task, treat them as `RESERVED_NOT_BUILT`.

## 1. Hard PREFLIGHT rule

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
cwd/repo root
branch
HEAD
git status --short --untracked-files=all
origin delta
canonical launcher exists
canonical launcher has only DurationMinutes as Owner-facing parameter
AIMO runner exists
callable innate reflex root plan exists
body self-inspection organ knowledge card exists
body integration plan exists
legacy launch quarantine exists
single-launch wiring audit PASS
old blocked Codex task is marked CONCEPTUALLY_BLOCKED / DO_NOT_RUN
```

If repo is dirty before your intended changes, return `BLOCKED_PREFLIGHT` unless the dirt is only this task file/validator/proof from the operator and you explicitly list it.

## 2. Read first

Read these files before changing anything:

```text
AGENT_BUILDER_INNATE_REFLEX_KERNEL_V1_PLAN.md
operations/autonomous_inner_motor/CODEX_TASK_INNATE_REFLEX_KERNEL_V1.md
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
validators/validate_callable_innate_reflex_kernel_v1.ps1
tests/self_development/CALLABLE_INNATE_REFLEX_KERNEL_V1_PROOF.json
```

Allowed modifications:

```text
operations/autonomous_inner_motor/run_autonomous_inner_motor.ps1
AGENT_BUILDER_SELF_NOTEBOOK.md
```

Allowed runtime outputs during validation/smoke only:

```text
.runtime/autonomous_inner_motor/<run>/innate_reflex_kernel.json
```

Do not modify any other file unless you stop and explain why in the final report.

## 4. Forbidden files / surfaces

Do not edit or mutate:

```text
operations/autonomous_inner_motor/start_agent_life_v1.ps1
operations/autonomous_inner_motor/select_agent_next_action_candidate_v1.ps1
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
invoke body self-inspection circuit
launch long live run
launch Codex recursively
browse web
execute repair drafts
write active memory directly
claim body_audit_reflex is callable from canonical life yet
claim all reflexes are implemented
add new Owner-facing launch parameters
use legacy launch surfaces
```

## 5. Required reflex matrix

Create a kernel manifest with these 25 reflex slots:

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

Each reflex slot must include:

```text
reflex_id
built_in
callable
status
entrypoint or planned_entrypoint
input_contract
output_contract
allowed_surfaces
forbidden_surfaces
validator
proof_expectation
boundary
maturity
```

## 6. First real reflex contract

`body_audit_reflex` must include:

```text
reflex_id = body_audit_reflex
built_in = true
callable = false
status = AVAILABLE_NOT_WIRED
organ_id = BODY_SELF_INSPECTION_CIRCUIT_V1
organ_status = KNOWN_ORGAN_AVAILABLE_NOT_WIRED
entrypoint = operations/body_self_inspection/invoke_body_self_inspection_circuit_v1.ps1
can_hear_body = true
body_inspection_invoked = false
invoked_this_cycle = false
```

Allowed future use:

```text
observe-only body audit when canonical observe hook is installed
```

Forbidden now:

```text
repair execution
map mutation
passport mutation
contract mutation
live action
direct active memory write
running every cycle
legacy launch usage
```

## 7. Reserved reflex contract

All other reflexes must be:

```text
built_in = true
callable = false
status = RESERVED_NOT_BUILT
maturity = RESERVED_SLOT
```

They must not point to fake working entrypoints.
They may use `planned_entrypoint` or `future_entrypoint`.

## 8. Builder script

Create:

```text
operations/autonomous_inner_motor/build_innate_reflex_kernel_v1.ps1
```

It must:

```text
read operations/autonomous_inner_motor/innate_reflex_kernel_v1.json
read operations/autonomous_inner_motor/organ_knowledge/BODY_SELF_INSPECTION_CIRCUIT_V1_KNOWLEDGE.json
produce a runtime-safe kernel object
prove body_audit_reflex references BODY_SELF_INSPECTION_CIRCUIT_V1
set body_audit_reflex.can_hear_body = true
set body_audit_reflex.callable = false
set body_audit_reflex.invoked_this_cycle = false by default
set body_audit_reflex.body_inspection_invoked = false
include counts: reflex_count, available_not_wired_count, reserved_count
include boundary flags
write output only when OutputPath is provided
```

Boundary flags must include:

```text
body_inspection_invoked = false
active_memory_mutated = false
live_process_touched = false
repair_executed = false
legacy_launch_used = false
```

## 9. Runner integration

Modify:

```text
operations/autonomous_inner_motor/run_autonomous_inner_motor.ps1
```

Required behavior:

```text
each AIMO cycle builds/writes .runtime/autonomous_inner_motor/<run>/innate_reflex_kernel.json
SANDBOX_EXPLORATION_PROOF.json includes innate_reflex_kernel object
sandbox_proof_pack_manifest.json requires innate_reflex_kernel.json
body self-inspection is NOT invoked
active memory is NOT directly written by this kernel
canonical launcher interface is untouched
```

This is knowledge/registry integration only, not observe hook.

## 10. Validator

Create:

```text
validators/validate_callable_innate_reflex_kernel_v1.ps1
```

It must validate:

```text
manifest parses
builder script parses
runner parses
25 reflex slots exist
all required reflex IDs exist
body_audit_reflex exists
body_audit_reflex.built_in == true
body_audit_reflex.callable == false
body_audit_reflex.status == AVAILABLE_NOT_WIRED
body_audit_reflex.organ_id == BODY_SELF_INSPECTION_CIRCUIT_V1
body_audit_reflex.can_hear_body == true
body_audit_reflex.body_inspection_invoked == false
body_audit_reflex.invoked_this_cycle == false
all non-body reflexes are RESERVED_NOT_BUILT and callable == false
builder can write a temp kernel output
runner contains innate_reflex_kernel.json
runner proof includes innate_reflex_kernel
proof pack manifest requires innate_reflex_kernel.json
canonical launcher still has only DurationMinutes
legacy launch quarantine exists
old blocked Codex task is not executable task anymore
```

Validator must write:

```text
tests/self_development/CALLABLE_INNATE_REFLEX_KERNEL_V1_PROOF.json
```

Expected status:

```text
PASS_CALLABLE_INNATE_REFLEX_KERNEL_V1
```

## 11. Required validation commands

Run at minimum:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File validators/validate_callable_innate_reflex_kernel_v1.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File validators/validate_body_self_inspection_organ_knowledge_v1.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File validators/validate_agent_life_quarantine_and_body_integration_v1.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File validators/validate_agent_life_launcher_v1.ps1
```

Do not run 10-minute life trial in this task.
Do not invoke body inspection.

## 12. Final report required fields

Final report must include exactly:

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
All 25 reflexes implemented: YES/NO
Known risks / next slice
```

Expected final truth:

```text
Files changed before PREFLIGHT_PASS: NO
Canonical launcher changed: NO
Body inspection invoked: NO
Active memory mutated: NO
Legacy launch used: NO
All 25 reflexes implemented: NO
```
