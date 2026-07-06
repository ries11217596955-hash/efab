# CODEX_CURRICULUM_CANARY_TASK_V1

## Context

You are Codex acting as bounded curriculum candidate producer, not Builder brain.

Read:

- operations/school/curriculum/codex_contract/CODEX_CURRICULUM_CONTRACT_V1.md
- operations/school/curriculum/validate_curriculum_school_v1.ps1
- operations/reports/CURRICULUM_SCHOOL_V1_VALIDATION.json

## PREFLIGHT

Before writing any candidate file, inspect the contract and return either:

```text
PREFLIGHT_STATUS=PREFLIGHT_PASS
```

or:

```text
PREFLIGHT_STATUS=BLOCKED_PREFLIGHT
blockers=[...]
```

No file writes before PREFLIGHT_PASS.

## Task after PREFLIGHT_PASS

Create one JSONL file with exactly 20 curriculum lesson candidates that satisfy CODEX_CURRICULUM_CONTRACT_V1.

Output path:

```text
.runtime/codex_curriculum_batches/codex_curriculum_canary_batch_v1.jsonl
```

## Required validation

Run:

```powershell
operations/school/curriculum/codex_contract/validate_codex_curriculum_batch_v1.ps1 -BatchPath .runtime/codex_curriculum_batches/codex_curriculum_canary_batch_v1.jsonl
```

## Final report

Include:

```text
PREFLIGHT_STATUS=
candidate_count=
accepted_count=
rejected_count=
validation_status=
Files changed before PREFLIGHT_PASS: YES/NO
expected: NO
```