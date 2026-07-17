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
A reflex is not merely â€œthe agent should notice Xâ€.
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
body_state_unknown â†’ consider body_audit_reflex
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
logic/trigger: â€œbody state is unknownâ€
reflex:       â€œcall observe-only body audit procedureâ€
organ:        â€œBODY_SELF_INSPECTION_CIRCUIT_V1â€
proof:        â€œbody audit signal/proof exists, no repair executedâ€
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

### Group A â€” body / self / repo awareness

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

### Group B â€” proof / safety / control

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

### Group C â€” memory / learning / continuity

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

### Group D â€” file / artifact / environment manipulation

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

### Group E â€” external help / external knowledge

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

## 11. Expected implementation files

Expected future files may include:

```text
operations/autonomous_inner_motor/innate_reflex_kernel_v1.json
operations/autonomous_inner_motor/build_innate_reflex_kernel_v1.ps1
validators/validate_callable_innate_reflex_kernel_v1.ps1
tests/self_development/CALLABLE_INNATE_REFLEX_KERNEL_V1_PROOF.json
```

Runtime output:

```text
.runtime/autonomous_inner_motor/<run>/innate_reflex_kernel.json
```

## 12. Acceptance criteria for future implementation

PASS requires:

```text
25 reflex slots exist or an explicit Owner-approved subset exists
body_audit_reflex exists
body_audit_reflex references BODY_SELF_INSPECTION_CIRCUIT_V1
body_audit_reflex status is AVAILABLE_NOT_WIRED
body_audit_reflex can_hear_body = true
all other reflexes are RESERVED_NOT_BUILT unless explicitly implemented
reserved reflexes are not falsely callable
kernel appears in canonical life proof pack
body inspection is not invoked by default
legacy launch is not used
canonical launcher remains DurationMinutes-only
no direct active memory write
no repair execution
```

## 13. Non-goals

```text
Do not implement all reflexes now.
Do not treat behavioral laws as callable reflexes.
Do not invoke body inspection yet.
Do not delete old plans.
Do not use legacy launch surfaces.
Do not create child agents.
Do not create a second life launcher.
```

## 14. Next action

Next correct step:

```text
rewrite Codex task under callable-reflex model
then run Codex as bounded implementation tool
```

Do not run the old Codex task.
