# AGENTS.md Ã¢â‚¬â€ EF Agent Builder Codex Command File

Status: ACTIVE_CODEX_COMMAND_FILE_V3
Owner decision: AGENTS.md is a command file, not a history archive.
Purpose: guide Codex to work productively and safely without wasting context or acting as Builder brain.

If this file conflicts with chat history, old reports, old route notes, or stale generated maps, this file wins for Codex execution.

---

## 1. Current repo identity

Canonical active local root:

```text
H:\efab
```

Canonical active GitHub remote:

```text
https://github.com/ries11217596955-hash/efab.git
```

Required branch:

```text
main
```

Current clean-line boundary:

```text
ACTIVE_WORKING_REPO=H:\efab
ACTIVE_GITHUB_REPO=ries11217596955-hash/efab
OLD_REPO=C:\Users\Azerbaijan\Downloads\e-factory-agent-builder
OLD_REPO_ROLE=ARCHIVE_REFERENCE_ONLY
OLD_GIT_HISTORY_DEPENDENCY=NO
```

Required identity markers:

```text
CAPABILITY_ROADMAP.json
GENESIS_STATE.json
TASK_QUEUE.json
packs/registry.json
orchestrator/run.ps1
AGENTS.md
reports/self_development/SELF_MODEL_ACTIVE_MAP.json
```

Remote identity gate:

```text
Expected origin URL must be exactly or resolve to:
https://github.com/ries11217596955-hash/efab.git
```

Preflight rule:

```text
If cwd/root is not H:\efab, or branch is not main, or origin is not efab.git:
STATUS: BLOCKED_PREFLIGHT
STOP: REPO_CONTEXT_MISMATCH
```

Historical path rule:

```text
C:\Users\Azerbaijan\Downloads\e-factory-agent-builder is old archive/reference only.
Do not use it as current body.
Do not commit, push, validate readiness, or run Builder growth from the old path unless Owner explicitly requests archive recovery.
```


## 2. Current route snapshot

Active work line:

```text
AGENT_BUILDER_SELF_DEVELOPMENT
```

Immediate route:

```text
1. Keep Codex bounded and productive through this AGENTS.md.
2. Current route is EXISTING_SCHOOL_ABSORPTION_DIAGNOSTIC, not new school construction.
3. Do not build a new school from scratch; existing school/acceptance proofs already cover 100, 1000, 3000, 5000, and 30000 lab mechanics.
4. Next work must diagnose/wire the existing canonical route: useful school -> Phase162/Phase165 acceptance -> accepted atom retention/compact storage -> retrieval -> decision reuse -> behavior delta proof.
5. REAL_DELTA_SCHOOL_ORGAN_V1_STAGE1 and related dry-run/resource-guard work are LAB_ADAPTER_CANDIDATE / SIDE_PROBE unless Owner explicitly promotes them.
6. Do not continue REAL_DELTA_SCHOOL_SCALE_GATE_V1 as route; it is SUPERSEDED_WRONG_DIRECTION because N is a parameter, not architecture.
7. Canonical school owner interface is defined by operations/school/SCHOOL_CANONICAL_RUN_CONTRACT_V1.md: TargetAccepted + RunKind(Test|Real), with internal 5000/100 scheduler.
8. GPT operator continuity lives in operations/gpt_handoff/GPT_OPERATOR_JOURNAL.md; GPT must read it and the self-map before choosing route.
9. runtime_ready=false.
```

Current known state:

```text
EXISTING_SCHOOL_PROOFS: PASS for curriculum supervisor 3000, useful ladder 5000, school 30000, batch 100, runtime 1000, durable retrieval 100.
ACTIVE_ACCEPTED_SURFACES: THINNED_REQUIRES_STORAGE_ORGAN_BEFORE_RUNTIME_USE for accepted memory snapshot, self model active map, and packs registry.
SCHOOL_ROUTE_DEDUP_AUDIT_V1: CLASSIFICATION_ONLY_NO_DELETE; canonical=1, internal_support=99, broken_support=12, quarantine_side_probe=59, superseded=3.
MAIN_GAP: accepted atoms are proven in lab/retrieval paths but not yet wired as canonical active behavior absorption.
REAL_DELTA_SCHOOL_EXISTING_BODY_SCAN_V1: VALID as reference.
REAL_DELTA_SCHOOL_ORGAN_V1_PASSPORT_CONTRACT: design reference only, not canonical route.
REAL_DELTA_SCHOOL_CYCLE_V1 / REVIEW: LAB harness references, not live intelligence.
SELF_MAP_ROLLUP_POLICY: atom/subchunk map updates blocked; rollup/capability/module/organ updates allowed.
runtime_ready=false
```


---
## 2A. Hard Codex context budget gate

When a task package gives an exact read list, that list is the context budget.

Codex must not read the whole repo to “understand context”.

Allowed discovery before PREFLIGHT_PASS:

```text
git status --short
git rev-parse --short HEAD
git rev-list --left-right --count HEAD...origin/main
git ls-files <explicit pathspecs from task only>
Select-String / grep only over explicit pathspecs from task
Get-ChildItem only for explicit shallow directories named in task
```

Forbidden unless the task explicitly grants `ALLOW_BROAD_REPO_SCAN=true`:

```text
git ls-files without pathspecs
Get-ChildItem -Recurse from repo root
reading all reports/**
reading all tests/**
reading all operations/**
reading all modules/**
reading all docs/**
opening legacy maps as authority
```

If Codex needs a file outside the task read list, it must stop with:

```text
STATUS: BLOCKED_PREFLIGHT
BLOCKER: READ_BUDGET_EXPANSION_REQUIRED
REQUESTED_FILES:
WHY_NEEDED:
FILES_CHANGED_BEFORE_PREFLIGHT_PASS: NO
```

For map/body/self-model work, old maps are never authority unless the task explicitly says so. They may only be used as bounded hints, hashes, or deletion targets.
Codex context budget cut-list:

```text
Do not ingest whole repo.
Do not read zz_MUSORKA_DO_NOT_READ_BY_CODEX unless explicitly asked.
Do not restore operations/quarantine blindly; quarantine is reference material only.
Do not inspect generated self-map state/report/logs unless the task is map validation.
Prefer exact file list from task + AGENTS.md + active validators/proofs only.
```

Do not claim any school, map, runtime, or live capability is fixed without fresh validator/runtime/proof evidence.

---
## 3. Codex role boundary

Codex is a bounded builder / repair / audit / launcher tool.

Codex is not:

```text
Builder brain
accepted truth source
live runtime supervisor
unbounded executor
child-agent factory
replacement for proof
```

Codex output is `CODEX_DRAFT` until validated by repo/test/runtime/proof evidence.

Codex may be active and productive.
Safety means planned, bounded, validated execution Ã¢â‚¬â€ not waiting for Owner after every step.

---

## 4. Mandatory one-pass workflow

Codex must not execute blindly.

For every task:

```text
1. Read AGENTS.md.
2. Read the task.
3. Restate the task goal.
4. Define in-scope work.
5. Define out-of-scope work.
6. List files expected to read.
7. List files expected to change.
8. Create a brief execution plan.
9. Create a validation plan.
10. Run bounded read-only preflight diagnosis.
11. If no blockers: declare PREFLIGHT_PASS and execute in the same run.
12. If blockers: declare BLOCKED_PREFLIGHT and do not modify files.
13. Validate.
14. Report.
```

Default rule:

```text
plan briefly, then execute
```

Codex does not wait for Owner approval after every plan.

Codex stops only when:

```text
repo/branch/head mismatch
dirty worktree blocks task
scope is unclear
validation is missing or impossible
task touches protected files/state not explicitly in scope
live/runtime/accepted-core/settings/route may be affected
AGENTS.md conflicts with task
task asks for broad "fix everything"
task requires long attached waiting
task would make Codex the brain/supervisor
```

---

## 5. Required preflight before mutation

Before modifying files, Codex must include:

```text
TASK UNDERSTANDING:
IN SCOPE:
OUT OF SCOPE:
FILES I EXPECT TO READ:
FILES I EXPECT TO CHANGE:
EXECUTION PLAN:
VALIDATION PLAN:
STOP IF:
PREFLIGHT_DECISION: PREFLIGHT_PASS or BLOCKED_PREFLIGHT
Files changed before PREFLIGHT_PASS: YES/NO
```

Expected:

```text
Files changed before PREFLIGHT_PASS: NO
```

Plan must be bounded, file-aware, validation-aware, and not a broad repo mutation.

---

## 6. If PREFLIGHT_PASS

Codex may execute without extra Owner approval when:

```text
task is bounded
scope is clear
target files are identified
validation is defined
protected state is not touched outside explicit scope
no hidden live/runtime risk
no AGENTS.md conflict
```

Then Codex should make the smallest sufficient change, run validation, and report evidence.

---

## 7. If BLOCKED_PREFLIGHT

Codex must not modify/create/delete/move/rename files.

Return blockers in batch, not one-by-one.

Required report:

```text
STATUS: BLOCKED_PREFLIGHT
TASK_UNDERSTANDING:
PREFLIGHT_SCOPE_CHECKED:
BLOCKERS:
RISKS_NOT_BLOCKING:
DUPLICATES_OR_CONFLICTS:
MISSING_INFORMATION:
PROPOSED_RESOLUTION_OPTIONS:
RECOMMENDED_NEXT_ACTION:
FILES_READ:
FILES_NOT_READ_AND_WHY:
Files changed before PREFLIGHT_PASS: NO
```

Do not invent blockers to avoid work.

---

## 8. Read budget and navigation

Codex must not burn context by reading everything.

Read order:

```text
1. AGENTS.md
2. user's task
3. exact files named in task
4. local AGENTS.md files only if present in target subtree
5. narrow modules/validators/tests/contracts relevant to task
6. targeted search only if exact file unknown
7. broader repo scan only if preflight proves narrow scan insufficient
```

Read first for current Builder work:

```text
AGENTS.md
README.md
AGENT_MISSION.md
CAPABILITY_ROADMAP.json
GENESIS_STATE.json
TASK_QUEUE.json
orchestrator/run.ps1
modules/run_ephemeral_candidate_controlled_runtime_v1.ps1
modules/invoke_accepted_atom_retention_compactor_v1.ps1
modules/invoke_accepted_atom_retention_gate_v1.ps1
modules/generate_structured_ephemeral_candidate_batch_v1.ps1
validators/
tests/accepted_atom_retention/
contracts/controlled_runtime/
```

Do not read by default:

```text
.runtime/**
reports/**
proofs/**
runtime_sessions/**
zz_MUSORKA_DO_NOT_READ_BY_CODEX/**
raw_shards/**
**/*.jsonl
runner stdout/stderr dumps
old logs
old frozen source repo paths
large historical report folders
```

Exception: exact task asks for a specific evidence path.

---

## 9. Protected areas

Do not touch unless task explicitly includes them:

```text
.git/**
.runtime/**
proofs/**
raw_shards/**
old reports/log dumps
accepted-core / D2B rules
settings/Knowledge law files
route locks / phase pointers
AGENTS.md itself
```

AGENTS.md may be edited only by explicit AGENTS.md update task.

---

## 10. Runtime and cleanup boundary

`.runtime/**` is ignored runtime evidence/temp material.

Rules:

```text
never commit .runtime/**
do not edit .runtime/**
do not delete .runtime/** unless task explicitly says controlled cleanup
before cleanup, check no matching runtime process is running
compact proof/evidence before deleting runtime evidence
```

Long runtime must be detached.

For long runs, Codex must launch detached and return:

```text
PID
runtime root
heartbeat path
summary path
stdout path
stderr path
stopfile path
git status count
next inspect command
runtime_ready=false
```

---


## 10A. Proof execution budget and no validation loop

Codex must not become runtime/proof supervisor.

Default: Codex patches. Owner terminal proves.

Codex may run only: static checks; syntax checks; small read-only diagnostics; one explicitly scoped quick smoke check.

Codex must not run: repair/validate/retry loops; attached multi-cycle runtime proofs; attached 8-cycle proof loops; attached 45-cycle proof; StructuredV1 30000; long polling of PowerShell validators; waiting for runtime/agent completion.

If a proof, validator, runtime, or helper process needs polling, repeated retries, or more than a short smoke window, Codex must stop attached waiting and return PID/root/heartbeat/summary/stdout/stderr/stopfile if detached, or return exact Owner PowerShell command to run outside Codex.

After a failed proof Codex must report the exact failure, report files changed, report validation attempted, and stop.

Codex must not silently patch and rerun proof again unless the task explicitly says: ALLOW_CODEX_VALIDATION_LOOP=true.

For Builder runtime work, 8-cycle, 45-cycle, and larger proofs are Owner-terminal or detached-proof responsibilities, not Codex waiting responsibilities.

## 11. Commit policy

Codex must not commit unless the task explicitly allows commit.

If commit is allowed:

```text
run validation first
inspect changed files
include commit hash in report
include git status count after commit
```

If commit is not allowed:

```text
leave diff uncommitted
report changed files
report validation result
```

---

## 12. Validation and proof language

Do not claim:

```text
fixed
works
accepted
synced
clean
complete
runtime_ready=true
```

unless fresh proof supports it.

Use statuses:

```text
CODEX_DRAFT
PREFLIGHT_PASS
BLOCKED_PREFLIGHT
VALIDATOR_PASS
PROOF_PASS
VALIDATED_PENDING_ACCEPTANCE
ACCEPTED_LOCAL
OWNER_DECISION_REQUIRED
QUARANTINED
ROLLBACK_REQUIRED
```

`runtime_ready` remains false unless Owner explicitly authorizes a route that proves otherwise.

---

## 13. Shell and terminal discipline

Before commands, identify shell:

```text
PowerShell
Bash / Git Bash
CodeSpace Linux shell
```

Do not mix Bash syntax with PowerShell.

PowerShell owner-facing blocks should prefer soft STOP markers:

```powershell
$Continue = $true
if (-not (Test-Path "CAPABILITY_ROADMAP.json")) {
  Write-Host "STOP=WRONG_AGENT_BUILDER_REPO"
  $Continue = $false
}
```

Avoid `exit` in long owner-facing PowerShell blocks when soft STOP is safer.

---

## 14. Final report standard

Every Codex task ends with:

```text
CODEX_DELIVERY_REPORT
STATUS:
PREFLIGHT_DECISION:
Files changed before PREFLIGHT_PASS: YES/NO
TASK_UNDERSTANDING:
PLAN_USED:
FILES_READ:
FILES_CHANGED:
COMMANDS_RUN:
VALIDATION_RESULT:
DIFF_SUMMARY:
RISKS:
LIMITATIONS:
COMMIT:
RUNTIME_READY=false
NEXT_RECOMMENDED_STEP:
```

If not committed:

```text
COMMIT=NONE
WHY_NOT_COMMITTED:
```

---

## 15. Maintenance rule

This AGENTS.md is Codex-facing guidance, not source of truth.

If route/self-map/current runtime reality changes:

```text
AGENTS.md may become stale
Codex must not silently rely on stale map
update AGENTS.md only through explicit AGENTS.md update task
```

This file must stay compact.
Do not turn AGENTS.md into a ledger, report, or archive.




---

## 16. Current school-generator repair task

Current Owner route: school remains the learning accelerator. Codex is used before a new serious knowledge campaign to author/update the campaign content that the existing school generator consumes.



Coverage / level pointer before Codex spends tokens:

```text
operations/school/curriculum/candidate_factory/CAMPAIGN_COVERAGE_STATUS_POINTER_V1.md
```

Codex must read the pointer and produce coverage audit + level plan before writing a campaign pack. Do not blindly start all themes at level 1; reconcile cursor ledger with compact memory snapshot and journal/proofs.

Use this task package:

```text
operations/gpt_handoff/CODEX_TASK_EVIDENCE_GROUNDED_SCHOOL_GENERATOR_V1.md
```

Hard rules:

```text
update existing candidate_factory; do not create duplicate school/generator organ
Codex authors campaign content/pack; school runs it later
no file writes before PREFLIGHT_PASS
no Count=50000 or Count=1000000 run inside Codex task
no long Live school run
no direct active compact memory mutation
no report/runtime bloat
```

Runtime cleanup status:

```text
.runtime was intentionally removed before this Codex task
heavy streaming/runtime reports were intentionally removed
preserved evidence snapshot exists at operations/school/curriculum/candidate_factory/memory/active_compact_memory_snapshot_for_evidence_v1/
```

Candidate depth target:

```text
candidate = campaign seed + topic/root + real source + extracted lesson + negative trap + proof target + behavior delta
not root + verb + mode + generic template
```

Source law:

```text
No source -> no knowledge.
No source/proof anchor -> no memory candidate.
For external/domain campaigns, Owner/trusted sources must be provided before Codex authors knowledge content.
```

If evidence/source is missing, stop or use a clearly marked low-depth fallback. Do not manufacture knowledge.

First Live validation run after Codex:

```text
Count = 15000
Mode = Live
```

This is Owner-selected. Do not jump from Codex output directly to 50k or 1M. The 15k run validates the campaign-pack generator over 3 chunks of 5000 before larger scaling.
