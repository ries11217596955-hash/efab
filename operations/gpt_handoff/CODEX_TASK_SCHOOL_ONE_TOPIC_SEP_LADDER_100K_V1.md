# CODEX_TASK_SCHOOL_ONE_TOPIC_SEP_LADDER_100K_V1

## Role boundary

You are Codex acting as a bounded repo task executor for one school topic.
You are not Builder brain, not active memory, not live runtime, and not absorption engine.

Owner goal: create a ONE-TOPIC deep ladder campaign for `school_generation_absorption_separation` that can later generate 100,000 candidates in a long/night school run.

This task is intentionally narrow. Do not expand to other topics.

## Command discipline

Do not use PowerShell pipelines for PREFLIGHT or validation.
Do not parse theme_cursor_ledger.json directly.
Do not run shell-heavy validation unless absolutely necessary.
Use the compact context file as source of truth.

## PREFLIGHT

Before file writes, read:

```text
operations/reports/ONE_TOPIC_SEP_LADDER_100K_CODEX_CONTEXT_20260714.json
```

Then report:

```text
PREFLIGHT_STATUS=PREFLIGHT_PASS
```

or:

```text
PREFLIGHT_STATUS=BLOCKED_PREFLIGHT
blockers=[...]
```

No file writes before PREFLIGHT_PASS.
Final response must include:

```text
Files changed before PREFLIGHT_PASS: YES/NO
expected: NO
```

## Task after PREFLIGHT_PASS

Create exactly these files:

```text
operations/school/curriculum/candidate_factory/source_origins/builder_sep_ladder_100k_v1.jsonl
operations/school/curriculum/candidate_factory/source_origins/builder_sep_ladder_100k_v1.manifest.json
operations/school/curriculum/candidate_factory/campaign_packs/builder_sep_ladder_100k_v1.jsonl
operations/school/curriculum/candidate_factory/campaign_packs/builder_sep_ladder_100k_v1.manifest.json
operations/school/curriculum/candidate_factory/reports/BUILDER_SEP_LADDER_100K_AUTHOR_REPORT_V1.json
operations/school/curriculum/candidate_factory/reports/BUILDER_SEP_LADDER_100K_COVERAGE_REPORT_V1.json
operations/school/curriculum/candidate_factory/reports/BUILDER_SEP_LADDER_100K_NOVELTY_PLAN_V1.json
```

Campaign id:

```text
builder_sep_ladder_100k_v1
```

## Origin requirements

Create 120-220 origin units.
Each origin unit must be JSONL with these fields:

```text
origin_id
campaign_id
topic
level_band
scenario_family
failure_mode
operator_decision
proof_surface
negative_case
positive_case
minimum_validator
return_to_parent
source_paths
why_it_matters
```

Rules:

- topic must be `school_generation_absorption_separation`.
- source_paths must only use files from compact context `source_pool`.
- scenario_family must come from or refine compact context `scenario_family_suggestions`.
- Each origin unit must be a distinct operational situation, not a wording variation.
- Include positive and negative case.
- Include observable proof surface.

## Campaign pack requirements

Create 1000-1500 seed lines. Recommended: 1200.
Total expansion_budget must equal exactly 100000.
No single seed expansion_budget may exceed 100.

Each seed JSONL object must include these fields:

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
origin_id
scenario_family
novelty_axis
validator_focus
```

Rules:

- campaign_id must be `builder_sep_ladder_100k_v1`.
- root must be `school_generation_absorption_separation` for every seed.
- Every seed must reference an origin_id from the origin file.
- source_path must exist and must be in compact context source_pool or the new origin JSONL path.
- At least 40 scenario_family values.
- Cover all 10 level bands from compact context.
- Do not copy old `builder_useful_100k_v1` seed wording.
- No generic advice.
- Every seed must force a concrete decision under a constraint.
- Every proof_target must name a concrete observable proof surface.
- Every negative_trap must be a realistic failure mode from this repo/school/runtime.
- Every behavior_delta must be a next-time behavior change.

## Quality target for later 100k run

Design the pack so the later generated 100k should improve over previous low-novelty run:

```text
seed_count >= 1000
scenario_families >= 40
max_expansion_budget_per_seed <= 100
fallback_expected = 0
source_missing_expected = 0
proof_missing_expected = 0
expected_unique_exercise_ratio_target >= 0.01
expected_expected_behavior_unique_ratio_target >= 0.01
```

Record this in `BUILDER_SEP_LADDER_100K_NOVELTY_PLAN_V1.json`.

## Validation inside this task

Perform only lightweight structural validation if you can do it safely. Prefer Python, not PowerShell.
Do not run 100k generation.
Do not run streaming/staging.
Do not run digest/absorption.
Do not mutate active memory.
Do not push.

Validation expectations:

- JSONL parse PASS.
- origin_unit_count 120-220.
- seed_count 1000-1500.
- total_expansion_budget exactly 100000.
- max expansion_budget <= 100.
- origin_id references valid.
- scenario_family_count >= 40.
- all source paths exist.

## Non-goals

Do not:

- generate 100k candidates;
- run streaming/staging;
- run digest/absorption;
- mutate active memory;
- edit generator source code;
- create another launch route;
- read theme_cursor_ledger directly;
- push to GitHub.

## Final response

Include:

```text
PREFLIGHT_STATUS=
origin_path=
origin_unit_count=
campaign_pack_path=
seed_count=
total_expansion_budget=
max_expansion_budget_per_seed=
scenario_family_count=
novelty_plan_status=
structural_validation_status=
generation_100k_started=false
streaming_started=false
absorption_started=false
active_memory_mutated=false
Files changed before PREFLIGHT_PASS: YES/NO
expected: NO
```

Boundary: output is CODEX_DRAFT until GPT/operator independently validates.
