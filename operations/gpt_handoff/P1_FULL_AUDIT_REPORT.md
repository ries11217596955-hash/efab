# P1_FULL_AUDIT_REPORT

Status: AUDIT_COMPLETE_WITH_GAPS
Created: 2026-07-15T15:14:53+04:00
Scope: body map / self-model map / organ passports / School surface / validator proof boundary

## 1. Preflight Proof Boundary

```text
repo_root = H:/efab
branch = main
HEAD_at_start = 12c118b
origin_delta = 0 / 0
mutation_scope = report artifacts only
School launched = false
active memory touched = false
cleanup performed = false
```

Process scan found no target School / producer / digest process beyond the checking PowerShell process at preflight time.

## 2. Artifacts Produced

```text
operations/gpt_handoff/P1_AUDIT_MACHINE_SUMMARY.json
```

Machine summary SHA256:

```text
ee1b1f64eef7aa6783bebd18e14cdc5650a686bb2ef1eec69f8beac3615e71a5
```

## 3. Core Counts

```text
body_map.confirmed_component_count = 7
body_map.primary_evidence_candidate_count = 142
self_model.module_count = 203
self_model.validator_count = 174
self_model.required_components_present = True
self_model.missing_required_components.count = 0
organ_passport_files_under_self_model/organ_passports = 140
organ_passport_json_under_self_model/organ_passports = 140
organ_passport_md_under_self_model/organ_passports = 0
school.files = 142
school.ps1_files = 84
school.json_files = 38
school.md_files = 17
school.primary_ps1_heuristic = 59
```

## 4. Existing Validator Results

Canonical School validator:

```text
VALIDATION_STATUS = PASS_AGENT_SCHOOL_CANONICAL_POLICY_V2
OWNER_FACING_ENTRYPOINT_COUNT = 1
OWNER_ENTRYPOINT = operations/school/run_agent_school.ps1
OWNER_FIELDS = Count,Mode,Topics
MODE_VALUES = Test,Live
SCHOOL_LIVE_MODE_IS_MEMORY_DIGEST_MODE_NOT_AGENT_RUNTIME = true
RUNTIME_READY = false
```

Organ passport maturity validator:

```text
VALIDATION_PASS = PASS_ORGAN_PASSPORT_MATURITY_SUMMARY_V1
TOTAL_PASSPORTS = 159
VALIDATED_OR_PROVEN = 5
DRAFT_WITH_VALIDATORS = 86
REPORT_PATH = reports/self_development/ORGAN_PASSPORT_MATURITY_SUMMARY_V1.json
PROOF_PATH = tests/self_development/ORGAN_PASSPORT_MATURITY_SUMMARY_V1_PROOF.json
```

Validated/proven passports from maturity summary:

```text
operations_live_readiness = VALIDATED_LAB / PROVEN_LAB
operations_reasoning = VALIDATED_LAB / PROVEN_LAB
operations_memory = VALIDATED_LAB / PROVEN_LAB
operations_live_start = VALIDATED_LIVE_INITIAL / PROVEN_LIVE_INITIAL_STOPPED
operations_self_model = VALIDATED_LAB / PROVEN_LAB
```

Failed / blocked validator results:

```text
validate_organ_passport_contract_and_coverage_audit_v1.ps1 -> BLOCKED: LIVE_AIMO_COUNT_BAD:0
validate_organ_passport_static_count_regression_guard_v1.ps1 -> FAIL: INDEX_COUNT_NOT_SCAN_COUNT
```

Interpretation: current repo has passport material, but passport index / coverage is not clean enough to claim mature organ coverage. Some validators expect a live AIMO process that is not running; this audit must not fake live proof.

## 5. Cross-Map Coverage Findings

```text
body_school_refs = 2
self_school_refs = 65
body_passport_refs = 1
self_passport_refs = 61
primary_school_ps1_covered_by_passport = 0
primary_school_ps1_uncovered_by_passport = 59
```

Hard finding:

```text
School canonical launcher and canonical validator exist and validate, but body map does not reference them as canonical School surface.
```

Gaps detected by machine audit:

```text
SCHOOL_PRIMARY_PS1_NOT_PASSPORT_COVERED
CANONICAL_SCHOOL_LAUNCHER_NOT_REFERENCED_IN_BODY_MAP
CANONICAL_SCHOOL_VALIDATOR_NOT_REFERENCED_IN_BODY_MAP
EXPECTED_SCHOOL_SUBDIRS_ABSENT_AS_DIRECTORIES
```

Missing directory warning from heuristic:

```text
campaigns
generator
validators
reports
```

Boundary: missing `campaigns/generator/validators/reports` as direct subdirectories is a structure warning, not proof of broken School, because current School tree is organized through top-level files and subtrees like `curriculum`, `warehouse`, `proofs`, `memory`, `digestion`, `codex`, `request`.

## 6. Root Cause

The Builder has more material than governance wiring.

```text
School exists and has canonical entrypoint proof.
Self-model sees many school references.
Passport material exists.
But body map, passport index, and mature organ coverage are not aligned.
```

This is not a reason to create one passport per script. That would confuse script inventory with organ maturity.

Correct model:

```text
School organ passport / invocation contract / validator contract
  -> covers canonical launcher
  -> covers internal helper surfaces as implementation details
  -> maps major sub-capabilities: source router, candidate factory, warehouse/request, digestion/memory, proofs/finalize
  -> does not promote every script as its own organ
```

## 7. Current Status Labels

```text
School canonical owner-facing surface = VALIDATOR_PASS
School live runtime = NOT_RUNNING / NOT_PROVEN_LIVE
Body map School reference = STALE_OR_INCOMPLETE
Self-model School references = PRESENT_BUT_NOT_AUTHORITY_MAP
Organ passport maturity = PARTIAL_VALIDATED_LAB
Passport coverage/index = NOT_CLEAN / NEEDS_RECONCILIATION
School component passport coverage = NOT_PROVEN
Active memory = NOT_TOUCHED
Cleanup = NOT_PERFORMED
```

## 8. Unsafe Actions Cut

```text
Do not launch School from this audit.
Do not mutate .runtime active memory.
Do not delete old operator/source files.
Do not create passport per script.
Do not claim live readiness from maturity summary.
Do not treat SELF_MODEL_ACTIVE_MAP as active body inventory.
Do not treat body map as capability invocation map.
```

## 9. Next Strong Move

P1A should be a bounded repair/audit slice, not a broad rewrite:

```text
Task: reconcile School organ coverage without per-script passport explosion.
Inputs:
  - operations/school/run_agent_school.ps1
  - operations/school/validate_agent_school_canonical_entrypoint_v1.ps1
  - reports/self_development/agent_body_map.json
  - reports/self_development/SELF_MODEL_ACTIVE_MAP.json
  - self_model/organ_passports/_index/ORGAN_PASSPORT_DRAFT_INDEX_V1.json
  - reports/self_development/ORGAN_PASSPORT_MATURITY_SUMMARY_V1.json
Outputs:
  - School organ coverage audit/contract candidate
  - body-map sync request or patch candidate
  - passport index reconciliation report
Validators:
  - canonical School validator PASS
  - passport index count reconciliation PASS
  - no live runtime required unless explicitly in live route
  - no active memory mutation
Forbidden:
  - one passport per script
  - duplicate School launcher
  - cleanup/deletion
  - live proof claim
```

## 10. Acceptance Boundary

This P1 audit is complete as an audit report only. It does not repair the gaps.

Acceptance for next repair requires:

```text
fresh diff
validator PASS
passport index count reconciled
body map reference to canonical School surface updated or route_change_request created
School organ coverage contract present
no active memory mutation
no live runtime launch
commit + remote proof
```
