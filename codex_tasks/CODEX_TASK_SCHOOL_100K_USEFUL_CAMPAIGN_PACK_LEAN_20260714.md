# CODEX_TASK_SCHOOL_100K_USEFUL_CAMPAIGN_PACK_LEAN_20260714

You are Codex as bounded school campaign-material author.
You are not Builder brain, not runtime, not active memory, not absorption engine.

Read only this compact context first:

```text
operations/reports/CODEX_100K_CAMPAIGN_COMPACT_CONTEXT_20260714.json
```

Then inspect only source paths named inside that JSON as needed.
Do not read the full GPT journal unless a specific field forces it; use compact context instead.

## PREFLIGHT

Before writing any file, return:

```text
PREFLIGHT_STATUS=PREFLIGHT_PASS
```

or:

```text
PREFLIGHT_STATUS=BLOCKED_PREFLIGHT
blockers=[...]
```

No file writes before PREFLIGHT_PASS.

## After PREFLIGHT_PASS

Create exactly these files:

```text
operations/school/curriculum/candidate_factory/campaign_packs/builder_useful_100k_v1.jsonl
operations/school/curriculum/candidate_factory/campaign_packs/builder_useful_100k_v1.manifest.json
operations/school/curriculum/candidate_factory/reports/BUILDER_USEFUL_100K_CAMPAIGN_COVERAGE_AUDIT_V1.json
operations/school/curriculum/candidate_factory/reports/BUILDER_USEFUL_100K_CAMPAIGN_LEVEL_PLAN_V1.json
operations/school/curriculum/candidate_factory/reports/BUILDER_USEFUL_100K_CAMPAIGN_AUTHOR_REPORT_V1.json
```

Use campaign_id `builder_useful_100k_v1`.
Use total_expansion_budget exactly `100000`.
Use 48-80 compact, high-quality seed lines.
Every seed must have the fields listed in compact context `seed_schema`.
Every seed must cite a tracked local source_path.
Every lesson must be specific and operational, not generic.
Every proof_target must name an observable proof surface.

## Validation

Run the 100-candidate smoke command and validator command from compact context.
If a command is incompatible, record the exact limitation in AUTHOR_REPORT.
Do not run 100k generation.
Do not run absorption/digest.
Do not mutate `.runtime/active_compact_semantic_memory_v1`.
Do not push.

## Final response

Include:

```text
PREFLIGHT_STATUS=
campaign_pack_path=
manifest_path=
seed_count=
total_expansion_budget=
coverage_status=
level_plan_status=
factory_smoke_status=
contract_validation_status=
active_memory_mutated=false
Files changed before PREFLIGHT_PASS: YES/NO
expected: NO
```

Boundary: your output remains CODEX_DRAFT until GPT/operator validates independently.