# CODEX_TASK_SCHOOL_100K_USEFUL_CAMPAIGN_GENERATOR_V1

## Role boundary

You are Codex acting as a bounded repo task executor for Builder school campaign material.
You are not Builder brain, not active memory, not school runtime, and not absorption engine.

The correct historical route is repo-file task -> Codex edits tracked campaign/generator material -> GPT/operator validates -> local candidate_factory expands candidates -> streaming/absorption later.

## PREFLIGHT

Before file writes, inspect required context and report:

```text
PREFLIGHT_STATUS=PREFLIGHT_PASS
```

or:

```text
PREFLIGHT_STATUS=BLOCKED_PREFLIGHT
blockers=[...]
```

No file writes before PREFLIGHT_PASS.
Final report must include:

```text
Files changed before PREFLIGHT_PASS: YES/NO
expected: NO
```

## Required context

Read:

```text
operations/reports/SCHOOL_100K_USEFUL_CAMPAIGN_TOPIC_PLAN_20260714.json
operations/reports/CODEX_100K_CAMPAIGN_COMPACT_CONTEXT_20260714.json
operations/reports/SCHOOL_CODEX_LAUNCH_RUNBOOK_20260714.json
operations/gpt_handoff/CODEX_TASK_EVIDENCE_GROUNDED_SCHOOL_GENERATOR_V1.md
operations/school/curriculum/candidate_factory/generate_codex_curriculum_candidate_factory_run_v1.ps1
operations/school/curriculum/candidate_factory/validate_campaign_pack_candidate_factory_v1.ps1
operations/school/curriculum/candidate_factory/campaign_packs/builder_self_knowledge_deep_v1.jsonl
operations/school/curriculum/candidate_factory/campaign_packs/builder_self_knowledge_deep_v1.manifest.json
operations/school/curriculum/candidate_factory/memory/theme_cursor_ledger.json
```

If any required file is missing, BLOCKED_PREFLIGHT.

## Task

Create a new 100k-useful campaign pack consumed by the existing local candidate_factory.
Do not hand-write 100k candidates.
Do not run absorption/digest.
Do not mutate `.runtime/active_compact_semantic_memory_v1`.
Do not push.

Create/update exactly these files:

```text
operations/school/curriculum/candidate_factory/campaign_packs/builder_useful_100k_v1.jsonl
operations/school/curriculum/candidate_factory/campaign_packs/builder_useful_100k_v1.manifest.json
operations/school/curriculum/candidate_factory/reports/BUILDER_USEFUL_100K_CAMPAIGN_COVERAGE_AUDIT_V1.json
operations/school/curriculum/candidate_factory/reports/BUILDER_USEFUL_100K_CAMPAIGN_LEVEL_PLAN_V1.json
operations/school/curriculum/candidate_factory/reports/BUILDER_USEFUL_100K_CAMPAIGN_AUTHOR_REPORT_V1.json
```

Do not edit source code unless existing validator/generator cannot smoke-test this pack. If source change is needed, keep it minimal and explain.

## Campaign requirements

Use campaign_id:

```text
builder_useful_100k_v1
```

Use exactly the 12 roots and budgets from:

```text
operations/reports/SCHOOL_100K_USEFUL_CAMPAIGN_TOPIC_PLAN_20260714.json
```

Total expansion_budget must be exactly 100000.
Preferred seed_count: 48-80.

Each JSONL seed must include:

```text
seed_id
campaign_id
root
depth_level_band
start_level
source_kind
source_path
source_anchor_or_hint
source_summary
lesson
negative_trap
proof_target
behavior_delta
return_to_parent
allowed_verbs
allowed_modes
expansion_budget
```

Rules:

- Every seed must cite a tracked local source_path.
- Lessons must be operational and specific.
- Negative traps must name real failure modes from the repo/run history.
- Proof targets must name observable proof surfaces: report path, status field, validator result, hash, or runtime boundary.
- New roots start at level 1.
- Old-update roots must use theme cursor / journal evidence and must not blindly reset everything to level 1.
- No generic filler seeds.
- No invented source truth.

## Validation

Run only bounded validation/smoke. Do not run 100k generation.

Required:

1. JSONL parse PASS.
2. Manifest PASS:
   - schema=`codex_campaign_pack_manifest_v1`
   - status=`CODEX_DRAFT_CAMPAIGN_PACK`
   - campaign_id=`builder_useful_100k_v1`
   - seed_count equals JSONL lines
   - total_expansion_budget=100000
   - runtime_ready=false
   - boundary says campaign material only, not absorption.
3. Campaign/source checks:
   - source_path exists for every seed.
   - expansion_budget sum exactly 100000.
   - no duplicate seed_id.
   - roots exactly match topic plan.
4. Factory smoke only if compatible:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File operations/school/curriculum/candidate_factory/generate_codex_curriculum_candidate_factory_run_v1.ps1 -TargetAccepted 100 -RunKind Test -BatchSize 100 -RunId builder_useful_100k_pack_validation_100_20260714 -CampaignPack operations/school/curriculum/candidate_factory/campaign_packs/builder_useful_100k_v1.jsonl
```

5. Existing campaign validator if compatible:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File operations/school/curriculum/candidate_factory/validate_campaign_pack_candidate_factory_v1.ps1 -TargetAccepted 100 -BatchSize 100 -CampaignPack operations/school/curriculum/candidate_factory/campaign_packs/builder_useful_100k_v1.jsonl
```

If a command parameter differs, inspect script param block and use the correct supported invocation. Record exact command and result in AUTHOR_REPORT.

## Non-goals

Do not:

- generate 100k candidates;
- run absorption/digest;
- mutate active memory;
- clean runtime;
- launch live school;
- create duplicate generator organ;
- push to GitHub.

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
campaign_validator_status=
active_memory_mutated=false
Files changed before PREFLIGHT_PASS: YES/NO
expected: NO
```

Boundary: output is CODEX_DRAFT until GPT/operator independently validates.