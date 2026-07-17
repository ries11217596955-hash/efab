# AGENT_BUILDER_INNATE_REFLEX_KERNEL_V1_PLAN

Status: ROOT_PLAN / CORRECTED_EXECUTABLE_REFLEX_MODEL
Codex task status: NEEDS_REWRITE / OLD_TASK_BLOCKED
Supersedes as current root growth plan: `AGENT_BUILDER_NEXT_15_STEPS_LOCK_V2_R2.md`
Old root plan status: ARCHIVE_REFERENCE / DO_NOT_DELETE_WITHOUT_OWNER_DECISION

## 0. Owner correction

The previous version mixed two different layers:

```text
wrong layer: behavioral sensitivity / logic laws
right layer: innate callable reflexes / built-in executable capabilities
```

Owner correction:

```text
A reflex is not merely ÃƒÂ¢Ã¢â€šÂ¬Ã…â€œthe agent should notice XÃƒÂ¢Ã¢â€šÂ¬Ã‚Â.
A reflex is a built-in callable mechanism, script, tool, or bounded procedure that the agent has from birth and can invoke under a contract.
```

Therefore `INNATE_REFLEX_KERNEL_V1` must be a registry/router for callable built-in reflexes, not a list of abstract good behaviors.

## 1. Core model

The agent is treated like a newborn organism:

```text
young / mostly untrained / little learned memory
but not empty
born with organs, primitive reflexes, safety boundaries, and basic callable procedures
```

The agent should not learn from scratch how to check its body, check repo reality, run validators, ask Codex, or seek external sources.
Those are built-in primitive reflexes.

## 2. Definitions

### 2.1 Organ

An organ is a larger capability/circuit.

Example:

```text
BODY_SELF_INSPECTION_CIRCUIT_V1
```

It can inspect the body/repo/maps/passports/signals and produce body self-inspection outputs.

### 2.2 Innate reflex

An innate reflex is a callable built-in ability that may use one organ, one script, one tool, or a bounded procedure.

Each reflex must have:

```text
reflex_id
built_in = true
callable = true/false
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

### 2.3 Trigger law

A trigger law decides when a reflex should be considered.

Example:

```text
body_state_unknown ÃƒÂ¢Ã¢â‚¬Â Ã¢â‚¬â„¢ consider body_audit_reflex
```

Trigger law is not the reflex itself.

### 2.4 Learned skill

A learned skill is acquired later through school/memory/use.
It is not the source of innate reflex authority.

### 2.5 Memory atom

A memory atom is learned compact knowledge.
It may help select a reflex, but it does not create the reflex.

## 3. Correct layer split

```text
logic/trigger: ÃƒÂ¢Ã¢â€šÂ¬Ã…â€œbody state is unknownÃƒÂ¢Ã¢â€šÂ¬Ã‚Â
reflex:       ÃƒÂ¢Ã¢â€šÂ¬Ã…â€œcall observe-only body audit procedureÃƒÂ¢Ã¢â€šÂ¬Ã‚Â
organ:        ÃƒÂ¢Ã¢â€šÂ¬Ã…â€œBODY_SELF_INSPECTION_CIRCUIT_V1ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â
proof:        ÃƒÂ¢Ã¢â€šÂ¬Ã…â€œbody audit signal/proof exists, no repair executedÃƒÂ¢Ã¢â€šÂ¬Ã‚Â
```

Explicit rule:

`	ext
organ != reflex != learned_skill != memory_atom
`	mp

The kernel must not confuse these layers.

## 4. Kernel purpose

`INNATE_REFLEX_KERNEL_V1` is the birth-layer registry of built-in callable reflexes.

It must answer in every canonical life cycle:

```text
what reflexes exist
which are callable now
which are reserved but not built
which organ/script each reflex uses
what each reflex is allowed to touch
what each reflex must never touch
what proof is expected if invoked
whether any reflex was invoked this cycle
```

## 5. Status vocabulary

Allowed reflex status values:

```text
AVAILABLE
AVAILABLE_NOT_WIRED
RESERVED_NOT_BUILT
BLOCKED_NEEDS_ORGAN
BLOCKED_NEEDS_SCRIPT
BLOCKED_NEEDS_VALIDATOR
BLOCKED_NEEDS_AUTHORITY
QUARANTINED
DEPRECATED
```

Meaning:

```text
AVAILABLE            callable through canonical life now
AVAILABLE_NOT_WIRED  organ/script exists but canonical hook is not installed
RESERVED_NOT_BUILT   planned slot only; no fake implementation
BLOCKED_*            known gap prevents use
QUARANTINED          explicitly unsafe/noncanonical until reviewed
DEPRECATED           old reflex replaced by newer one
```

## 6. Reflex groups and proposed first matrix

The first kernel should reserve about 25 reflex slots.
Not all are implemented now.

### Group A ÃƒÂ¢Ã¢â€šÂ¬Ã¢â‚¬Â body / self / repo awareness

#### 1. body_audit_reflex

```text
Purpose: hear the body.
Existing organ: BODY_SELF_INSPECTION_CIRCUIT_V1
Current status: AVAILABLE_NOT_WIRED
Callable goal: observe-only body audit.
Entry point: operations/body_self_inspection/invoke_body_self_inspection_circuit_v1.ps1
Output: body_self_inspection_signal, parent packet, proof.
Forbidden: repair execution, map mutation, passport mutation, live action.
```

This is the first real reflex candidate.
One organ for this reflex already exists.
The organ is not yet connected to canonical life.

#### 2. organ_audit_reflex

```text
Purpose: audit one selected organ.
Checks: passport, contract, validator, proof, wiring, maturity, boundary.
Current status: RESERVED_NOT_BUILT
Expected output: organ audit report + maturity status.
```

#### 3. full_body_map_audit_reflex

```text
Purpose: audit all known organs/maps/passports/contracts.
Current status: RESERVED_NOT_BUILT
Related existing material: body self-inspection circuit / body composition map.
Expected output: body map reality report.
```

#### 4. repo_reality_reflex

```text
Purpose: know current repo reality before action.
Checks: cwd, branch, HEAD, dirty state, remote delta.
Current status: RESERVED_NOT_BUILT
Expected output: repo reality snapshot.
```

#### 5. process_scan_reflex

```text
Purpose: detect duplicate or conflicting runtime.
Checks: agent/school/Codex/live processes.
Current status: RESERVED_NOT_BUILT
Expected output: process conflict report.
```

#### 6. runtime_pressure_reflex

```text
Purpose: detect environmental pressure.
Checks: disk/runtime/log growth/long-run risk/process pressure.
Current status: RESERVED_NOT_BUILT
Expected output: runtime pressure snapshot.
```

### Group B ÃƒÂ¢Ã¢â€šÂ¬Ã¢â‚¬Â proof / safety / control

#### 7. preflight_reflex

```text
Purpose: run safety preflight before any risky action.
Checks: repo clean, process clear, authority, protected surfaces, rollback path.
Current status: RESERVED_NOT_BUILT
Expected output: PREFLIGHT_PASS or BLOCKED_PREFLIGHT.
```

#### 8. validator_run_reflex

```text
Purpose: run the correct validator for a changed organ/surface.
Current status: RESERVED_NOT_BUILT
Expected output: validator proof JSON/status.
```

#### 9. proof_pack_reflex

```text
Purpose: assemble proof pack after a change or run.
Current status: RESERVED_NOT_BUILT
Expected output: proof pack manifest + required proof files.
```

#### 10. rollback_reflex

```text
Purpose: return to checkpoint safely after failed validation.
Current status: RESERVED_NOT_BUILT
Expected output: rollback report, git state proof.
Forbidden: blind cleanup, protected memory deletion.
```

#### 11. quarantine_reflex

```text
Purpose: isolate legacy/unsafe/noncanonical surfaces without deleting them.
Current status: RESERVED_NOT_BUILT
Related existing material: AGENT_LIFE_LEGACY_LAUNCH_QUARANTINE_V1.json
Expected output: quarantine manifest/update.
```

#### 12. stop_or_freeze_reflex

```text
Purpose: stop or refuse unsafe/duplicate runtime action.
Current status: RESERVED_NOT_BUILT
Expected output: freeze/stop decision with proof.
Forbidden: killing unknown processes without authority.
```

### Group C ÃƒÂ¢Ã¢â€šÂ¬Ã¢â‚¬Â memory / learning / continuity

#### 13. memory_queue_reflex

```text
Purpose: send learned material to governed QueueOnly intake.
Current status: RESERVED_NOT_BUILT
Expected output: compact memory knowledge packet.
Forbidden: direct active memory write.
```

#### 14. active_memory_read_reflex

```text
Purpose: read active memory state before claiming/learning.
Current status: RESERVED_NOT_BUILT
Expected output: memory availability/relevance snapshot.
Forbidden: mutation.
```

#### 15. memory_digest_reflex

```text
Purpose: compress raw run/log/chunk material into compact digest.
Current status: RESERVED_NOT_BUILT
Expected output: digest report and retention decision.
```

#### 16. handoff_write_reflex

```text
Purpose: write compact handoff/status for next cycle/chat/operator.
Current status: RESERVED_NOT_BUILT
Expected output: handoff artifact.
```

#### 17. self_notebook_update_reflex

```text
Purpose: update the root agent notebook after proven changes.
Current status: RESERVED_NOT_BUILT
Expected output: notebook checkpoint.
Forbidden: claiming proof without proof refs.
```

### Group D ÃƒÂ¢Ã¢â€šÂ¬Ã¢â‚¬Â file / artifact / environment manipulation

#### 18. directory_create_reflex

```text
Purpose: create required directory structure by contract.
Current status: RESERVED_NOT_BUILT
Expected output: directory creation proof.
Forbidden: creating broad/unscoped trees.
```

#### 19. file_normalize_reflex

```text
Purpose: normalize files after edits.
Examples: line endings, trailing whitespace, stable JSON formatting.
Current status: RESERVED_NOT_BUILT
Expected output: diff-check clean.
```

#### 20. archive_backup_reflex

```text
Purpose: create backup/archive before risky mutation or cleanup.
Current status: RESERVED_NOT_BUILT
Expected output: archive path, hash/size, source list.
```

#### 21. artifact_convert_reflex

```text
Purpose: convert artifacts through approved tools.
Examples: docx to pdf, md to pdf, report to artifact.
Current status: RESERVED_NOT_BUILT
Expected output: converted artifact + validator/proof.
Forbidden: using unapproved conversion path or leaking font files.
```

### Group E ÃƒÂ¢Ã¢â€šÂ¬Ã¢â‚¬Â external help / external knowledge

#### 22. codex_consult_reflex

```text
Purpose: ask Codex for bounded advice/review/options.
Current status: RESERVED_NOT_BUILT
Role: Codex is advisor/tool, not brain.
Expected output: CODEX_DRAFT advice, not accepted proof.
Forbidden: letting Codex mutate files or decide authority.
```

#### 23. codex_task_authoring_reflex

```text
Purpose: author a strict Codex task from current context.
Current status: RESERVED_NOT_BUILT
Required template: context, allowed files, forbidden files, preflight, validators, proof, risks, final report.
Expected output: install-ready Codex task.
```

#### 24. web_source_search_reflex

```text
Purpose: seek external truth/source material from the internet when local knowledge is insufficient or freshness matters.
Current status: RESERVED_NOT_BUILT
Expected output: cited source set/search report.
Forbidden: browsing without need, using web as brain, uncited claims from web.
```

#### 25. source_ingestion_reflex

```text
Purpose: turn external/local source material into governed knowledge.
Current status: RESERVED_NOT_BUILT
Expected output: extracted claims, source refs, validation result, QueueOnly packet candidate.
Forbidden: raw source dump into active memory.
```

## 7. First implementation target

The first implementation should not build all reflexes.

It should build the kernel/registry and make only one reflex real:

```text
body_audit_reflex
status = AVAILABLE_NOT_WIRED
organ = BODY_SELF_INSPECTION_CIRCUIT_V1
callable = false from canonical life until observe hook exists
can_hear_body = true
body_inspection_invoked = false by default
```

All other reflexes:

```text
status = RESERVED_NOT_BUILT
callable = false
```

## 8. Canonical life integration requirement

Each canonical AIMO life cycle should eventually expose:

```text
innate_reflex_kernel.status
innate_reflex_kernel.reflex_count
innate_reflex_kernel.available_reflexes
innate_reflex_kernel.available_not_wired_reflexes
innate_reflex_kernel.reserved_reflexes
innate_reflex_kernel.body_audit_reflex.organ_id
innate_reflex_kernel.body_audit_reflex.can_hear_body
innate_reflex_kernel.body_audit_reflex.callable
innate_reflex_kernel.body_audit_reflex.invoked_this_cycle
innate_reflex_kernel.boundary
```

The first implementation must prove:

```text
agent knows it has body_audit_reflex
body audit organ exists
body audit is not invoked by default
legacy launch is not used
canonical launcher remains the only Owner-facing life launch
```

## 9. Relationship to current artifacts

Must use/read:

```text
operations/autonomous_inner_motor/start_agent_life_v1.ps1
operations/autonomous_inner_motor/run_autonomous_inner_motor.ps1
operations/autonomous_inner_motor/organ_knowledge/BODY_SELF_INSPECTION_CIRCUIT_V1_KNOWLEDGE.json
operations/autonomous_inner_motor/BODY_SELF_INSPECTION_CANONICAL_INTEGRATION_PLAN_V1.md
operations/autonomous_inner_motor/AGENT_LIFE_LEGACY_LAUNCH_QUARANTINE_V1.json
operations/autonomous_inner_motor/reports/AGENT_LIFE_SINGLE_LAUNCH_WIRING_AUDIT_V1.json
validators/validate_body_self_inspection_organ_knowledge_v1.ps1
validators/validate_agent_life_quarantine_and_body_integration_v1.ps1
validators/validate_agent_life_launcher_v1.ps1
```

Existing first organ:

```text
BODY_SELF_INSPECTION_CIRCUIT_V1 = organ exists / PROVEN_LAB / not canonical-life wired
```

Existing first reflex slot:

```text
body_audit_reflex = should be born from that organ / AVAILABLE_NOT_WIRED
```

## 10. Correct Codex strategy

The old Codex task generated from the previous plan is conceptually blocked.

Before Codex implementation, create a new task:

```text
CODEX_TASK_CALLABLE_INNATE_REFLEX_KERNEL_V1.md
```

The new Codex task must implement callable reflex registry, not behavioral laws.

Required Codex preflight:

```text
PREFLIGHT_PASS or BLOCKED_PREFLIGHT
Files changed before PREFLIGHT_PASS: YES/NO
```

Codex must not invoke body self-inspection yet.
Codex must not implement all reflexes.
Codex must not alter canonical launcher.

## 11. Current implementation status

Slice A is already proven:

```text
CALLABLE_INNATE_REFLEX_KERNEL_V1_SLICE_A = PROVEN_LAB
```

Permanent kernel files now exist:

```text
operations/autonomous_inner_motor/innate_reflex_kernel_v1.json
operations/autonomous_inner_motor/build_innate_reflex_kernel_v1.ps1
validators/validate_callable_innate_reflex_kernel_v1.ps1
tests/self_development/CALLABLE_INNATE_REFLEX_KERNEL_V1_PROOF.json
```

Important boundary:

```text
The permanent reflex kernel exists once in repo.
It is not recreated on every agent launch.
```

## 12. Bootload correction

Owner correction:

```text
Do not write/recreate reflexes every run.
Reflexes are permanent built-in birth layer.
A launch must only load them and prove that they were loaded.
```

Correct model:

```text
permanent DNA:
  operations/autonomous_inner_motor/innate_reflex_kernel_v1.json

bootload mechanism:
  canonical life startup reads permanent DNA
  validates/loads runtime-safe object
  stores compact bootload proof for that run

runtime proof:
  reflex_kernel_loaded = true
  reflex_kernel_source = operations/autonomous_inner_motor/innate_reflex_kernel_v1.json
  reflex_count = 25
  body_audit_reflex.status = AVAILABLE_NOT_WIRED
  body_audit_reflex.can_hear_body = true
```

Wrong model:

```text
create reflexes every cycle
rewrite the full reflex matrix every cycle
claim body audit is callable before hook exists
```

## 13. INNATE_REFLEX_BOOTLOAD_V1

The next slice is:

```text
INNATE_REFLEX_BOOTLOAD_V1
```

Purpose:

```text
When canonical agent life starts, the runner loads the permanent innate reflex kernel once for that run and records a compact bootload proof.
```

It must not:

```text
recreate the kernel
modify the permanent kernel during life
invoke body inspection
make body_audit_reflex callable
write active memory directly
change Owner-facing launch command
```

Expected runtime output per run:

```text
.runtime/<current canonical run>/innate_reflex_bootload.json
```

Expected compact proof fields:

```text
innate_reflex_bootload.status = PASS_INNATE_REFLEX_BOOTLOAD_V1
innate_reflex_bootload.loaded = true
innate_reflex_bootload.source = operations/autonomous_inner_motor/innate_reflex_kernel_v1.json
innate_reflex_bootload.reflex_count = 25
innate_reflex_bootload.body_audit_reflex.status = AVAILABLE_NOT_WIRED
innate_reflex_bootload.body_audit_reflex.can_hear_body = true
innate_reflex_bootload.body_audit_reflex.callable = false
innate_reflex_bootload.body_inspection_invoked = false
```

The run proof may reference the bootload proof by path/ref.
It should not duplicate the full 25-reflex matrix into every cycle unless a validator explicitly requires a sample.

## 14. Canonical life integration requirement

The canonical runner should expose that reflexes were loaded, not created.

Minimum acceptable integration:

```text
at run/start:
  call build_innate_reflex_kernel_v1.ps1
  write innate_reflex_bootload.json once for the run

in SANDBOX_EXPLORATION_PROOF or run summary:
  include innate_reflex_bootload compact object or reference

in proof pack manifest:
  require innate_reflex_bootload.json
```

Cycle-level output may include only a compact reference:

```text
innate_reflex_bootload_loaded = true
innate_reflex_bootload_ref = <path>
```

Do not write the full kernel every cycle.

## 15. Acceptance criteria for INNATE_REFLEX_BOOTLOAD_V1

PASS requires:

```text
permanent kernel remains unchanged by launch
canonical launcher remains DurationMinutes-only
runner loads permanent kernel once per run
runtime bootload proof exists
run proof/summary references bootload proof
proof pack manifest requires bootload proof
body_audit_reflex remains AVAILABLE_NOT_WIRED
body_audit_reflex.callable = false
body inspection is not invoked
active memory is not directly written
legacy launch is not used
no full reflex matrix rewrite per cycle
```

## 16. Non-goals

```text
Do not implement body audit observe hook yet.
Do not make body_audit_reflex callable from canonical life yet.
Do not invoke BODY_SELF_INSPECTION_CIRCUIT_V1.
Do not implement all reserved reflexes.
Do not create a second life launcher.
Do not write active memory directly.
```

## 17. Next action

Create and run a narrow Codex task:

```text
CODEX_TASK_INNATE_REFLEX_BOOTLOAD_V1.md
```

Scope:

```text
runner bootload integration only
bootload validator/proof
no body inspection invocation
no observe hook
no permanent kernel mutation
```
## 18. DEFAULT_WAKE_REFLEXES_V1 correction

Owner correction:

```text
Some reflexes must run by default on wake.
They do not need extra trigger or Owner permission because they are observe-only body sensing.
```

Correct class split:

```text
wake-default reflexes = run automatically at agent wake/start
triggered reflexes = run when a signal/event appears
authorized reflexes = require authority because they can mutate body/memory/live surfaces
```

First wake-default reflex:

```text
body_audit_reflex
status = DEFAULT_WAKE_OBSERVE
callable = true
wake_default = true
requires_owner_permission = false
trigger_required = false
mode = observe_only
entrypoint = operations/body_self_inspection/invoke_body_self_inspection_circuit_v1.ps1
```

This means:

```text
Agent wakes.
Agent boot-loads innate reflex DNA.
Agent automatically observes its body using body_audit_reflex.
Agent writes default_wake_reflexes.json.
Agent does not repair/mutate/write active memory/live act.
```

Runtime proof must show:

```text
default_wake_reflexes.status = PASS_DEFAULT_WAKE_REFLEXES_V1
body_audit_reflex.status = PASS_BODY_AUDIT_WAKE_REFLEX_V1
body_audit_reflex.requires_owner_permission = false
body_audit_reflex.trigger_required = false
body_audit_reflex.observe_only = true
body_audit_reflex.body_inspection_invoked = true
boundary.body_repair_executed = false
boundary.active_memory_mutated = false
boundary.live_process_touched = false
```

Non-goals:

```text
Do not execute repair drafts.
Do not mutate maps/passports/contracts.
Do not write active memory directly.
Do not treat body sensing as Owner-authorized live action.
Do not run all reflexes by default.
```

## 19. DEFAULT_WAKE_REFLEXES_V2

Owner decision:

```text
Wake-default should include more read-only sensing reflexes, not only body sensing.
```

Default wake set V2:

```text
body_audit_reflex = observe body
repo_reality_reflex = observe repo root/branch/HEAD/dirty/remote delta
process_scan_reflex = observe duplicate life/codex/school processes
runtime_pressure_reflex = observe runtime/drive pressure light, no cleanup
active_memory_read_reflex = observe active memory root/manifest/index/cells availability
```

Allowed by wake-default:

```text
read
observe
sense
emit signal
write runtime proof
```

Forbidden by wake-default:

```text
repair
mutate repo
kill process
cleanup runtime
archive/compress/delete
write active memory
launch Codex
browse web
start child agent
```

Codex/Web remain triggered, not wake-default:

```text
codex_consult_reflex = triggered
web_source_search_reflex = triggered
```

Acceptance for V2:

```text
default_wake_reflexes.status = PASS_DEFAULT_WAKE_REFLEXES_V2
invoked includes body_audit_reflex, repo_reality_reflex, process_scan_reflex, runtime_pressure_reflex, active_memory_read_reflex
all V2 reflexes require_owner_permission=false and trigger_required=false
all V2 reflexes are observe-only/read-only
boundary has no repair/mutation/cleanup/process kill/git write/active memory write
```
