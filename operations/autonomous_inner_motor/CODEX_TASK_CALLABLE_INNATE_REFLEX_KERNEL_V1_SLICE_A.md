# CODEX_TASK_CALLABLE_INNATE_REFLEX_KERNEL_V1_SLICE_A

Status: READY_FOR_CODEX / NOT_RUN
Task type: narrowed implementation slice
Scope: manifest + builder + validator only
Explicitly out of scope: canonical runner integration
Root plan: AGENT_BUILDER_INNATE_REFLEX_KERNEL_V1_PLAN.md
Previous broad task result: CODEX_HUNG_DRAFT_NOT_ACCEPTED

## 0. Role and boundary

You are Codex, an implementation tool.
You are not the Builder brain.
Do not continue the broad task.
Do not touch runner integration in this slice.
Do not invoke body self-inspection.

Implement only Slice A:

```text
innate_reflex_kernel_v1.json
build_innate_reflex_kernel_v1.ps1
validate_callable_innate_reflex_kernel_v1.ps1
CALLABLE_INNATE_REFLEX_KERNEL_V1_PROOF.json
```

No canonical life wiring in this slice.

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
root plan exists and says callable reflex model
previous hung report exists
partial Codex drafts exist in .runtime/codex_drafts/callable_innate_reflex_kernel_v1_hung_20260717_161706
body organ knowledge card exists
body integration plan exists
legacy launch quarantine exists
```

If repo is dirty before changes, return `BLOCKED_PREFLIGHT`.

## 2. Read first

Read:

```text
AGENT_BUILDER_INNATE_REFLEX_KERNEL_V1_PLAN.md
operations/autonomous_inner_motor/reports/CODEX_CALLABLE_INNATE_REFLEX_KERNEL_V1_HUNG_REPORT.json
.runtime/codex_drafts/callable_innate_reflex_kernel_v1_hung_20260717_161706/innate_reflex_kernel_v1.json
.runtime/codex_drafts/callable_innate_reflex_kernel_v1_hung_20260717_161706/build_innate_reflex_kernel_v1.ps1
operations/autonomous_inner_motor/organ_knowledge/BODY_SELF_INSPECTION_CIRCUIT_V1_KNOWLEDGE.json
operations/autonomous_inner_motor/BODY_SELF_INSPECTION_CANONICAL_INTEGRATION_PLAN_V1.md
operations/autonomous_inner_motor/AGENT_LIFE_LEGACY_LAUNCH_QUARANTINE_V1.json
operations/autonomous_inner_motor/CODEX_TASK_CALLABLE_INNATE_REFLEX_KERNEL_V1.md
```

You may reuse the previous draft if it passes this slice's contract.
You must not trust the draft blindly.

## 3. Allowed files

Allowed new/modified files:

```text
operations/autonomous_inner_motor/innate_reflex_kernel_v1.json
operations/autonomous_inner_motor/build_innate_reflex_kernel_v1.ps1
validators/validate_callable_innate_reflex_kernel_v1.ps1
tests/self_development/CALLABLE_INNATE_REFLEX_KERNEL_V1_PROOF.json
AGENT_BUILDER_SELF_NOTEBOOK.md
```

Allowed temporary output during validator:

```text
.runtime/self_development/innate_reflex_kernel_v1_test/innate_reflex_kernel.json
```

No other repo files may be modified.

## 4. Forbidden scope

Do not modify:

```text
operations/autonomous_inner_motor/run_autonomous_inner_motor.ps1
operations/autonomous_inner_motor/start_agent_life_v1.ps1
operations/autonomous_inner_motor/select_agent_next_action_candidate_v1.ps1
operations/body_self_inspection/*
operations/reasoning/*
.runtime/active_compact_semantic_memory_v1
legacy launch surfaces
maps/passports/contracts
```

Do not:

```text
invoke body self-inspection circuit
wire runner
launch life run
launch Codex recursively
browse web
execute repair drafts
write active memory directly
claim canonical life integration is done
claim body_audit_reflex is callable from canonical life
```

## 5. Required manifest contract

Create/complete:

```text
operations/autonomous_inner_motor/innate_reflex_kernel_v1.json
```

It must include exactly these 25 reflex IDs or a superset containing all of them:

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
input_contract
output_contract
allowed_surfaces
forbidden_surfaces
validator
proof_expectation
boundary
maturity
```

`body_audit_reflex` must include:

```text
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

All non-body reflexes must include:

```text
built_in = true
callable = false
status = RESERVED_NOT_BUILT
maturity = RESERVED_SLOT
```

## 6. Required builder contract

Create/complete:

```text
operations/autonomous_inner_motor/build_innate_reflex_kernel_v1.ps1
```

It must:

```text
parse manifest JSON
parse body organ knowledge card
validate body_audit_reflex references BODY_SELF_INSPECTION_CIRCUIT_V1
validate body_audit_reflex.can_hear_body = true
validate body_audit_reflex.callable = false
validate body_audit_reflex.body_inspection_invoked = false
validate all non-body reflexes are RESERVED_NOT_BUILT and callable = false
return a runtime-safe object
include reflex_count, available_not_wired_count, reserved_count
include boundary flags
write output only when -OutputPath is provided
```

Boundary flags must include:

```text
body_inspection_invoked = false
active_memory_mutated = false
live_process_touched = false
repair_executed = false
legacy_launch_used = false
runner_integrated = false
```

## 7. Required validator contract

Create:

```text
validators/validate_callable_innate_reflex_kernel_v1.ps1
```

It must validate:

```text
manifest exists and parses
builder script exists and parses
25 required reflex IDs exist
body_audit_reflex contract is correct
all non-body reflexes are RESERVED_NOT_BUILT and callable=false
builder writes temp runtime-safe output to .runtime/self_development/innate_reflex_kernel_v1_test/innate_reflex_kernel.json
output boundary flags are false
runner is NOT modified by this slice
canonical launcher is NOT modified by this slice
body inspection is NOT invoked
```

It must write:

```text
tests/self_development/CALLABLE_INNATE_REFLEX_KERNEL_V1_PROOF.json
```

Expected status:

```text
PASS_CALLABLE_INNATE_REFLEX_KERNEL_V1_SLICE_A
```

## 8. Required validation commands

Run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File validators/validate_callable_innate_reflex_kernel_v1.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File validators/validate_callable_innate_reflex_codex_task_slice_a_v1.ps1
```

Do not run life.
Do not touch runner.

## 9. Final report required fields

Final report must include:

```text
PREFLIGHT status
Files changed before PREFLIGHT_PASS: YES/NO
Files changed
Validators run
Proof files
Boundary status
Runner modified: YES/NO
Canonical launcher modified: YES/NO
Body inspection invoked: YES/NO
Active memory mutated: YES/NO
Legacy launch used: YES/NO
Known risks / next slice
```

Expected final truth:

```text
Runner modified: NO
Canonical launcher modified: NO
Body inspection invoked: NO
Active memory mutated: NO
Legacy launch used: NO
Next slice: runner integration
```
