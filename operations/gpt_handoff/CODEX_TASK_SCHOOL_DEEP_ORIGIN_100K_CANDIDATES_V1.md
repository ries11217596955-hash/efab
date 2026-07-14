# CODEX_TASK_SCHOOL_DEEP_ORIGIN_100K_CANDIDATES_V1

## Role boundary

You are Codex acting as a bounded repo task executor for Builder school curriculum material.
You are not Builder brain, not active memory, not absorption engine, and not live runtime.

Owner goal: create a NEW DEEP ORIGIN for the school and a NEW campaign pack capable of producing another 100,000 candidates with much higher novelty than `builder_useful_100k_v1`.

Do not generate 100k candidates by hand.
Do not run absorption/digest.
Do not mutate `.runtime/active_compact_semantic_memory_v1`.
Do not push.

The local candidate factory will later expand the campaign pack into 100k candidates.

## Why this task exists

The previous campaign `builder_useful_100k_v1` passed contract/source/staging but quality gate found low novelty:

```text
unique_exercise_ratio=0.00144
unique_expected_behavior_ratio=0.00048
exercise_duplicate_max_cluster=696
expected_behavior_duplicate_max_cluster=2088
```

Root cause: 48 seeds expanded into 100k drills. That is useful for repetition but too shallow as a new learning origin.

This task must create a deeper origin with many more independent cases/seeds.


## Command discipline for Codex

Do not use PowerShell pipelines for PREFLIGHT or validation.
The previous Codex attempts repeatedly failed with:

```text
ParserError: An empty pipe element is not allowed
```

Therefore:

- Use Python one-shot scripts for JSON/JSONL validation.
- Use simple `git ls-files <path>` commands if needed.
- Do not generate multi-line PowerShell arrays piped to `ConvertTo-Json`.
- Do not use `} | ConvertTo-Json` patterns.
- Do not block on formatting a PREFLIGHT JSON with shell; inspect files directly.
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
Final response must include:

```text
Files changed before PREFLIGHT_PASS: YES/NO
expected: NO
```

## Required context to read before PREFLIGHT

Read this compact context pack only:

```text
operations/reports/DEEP_ORIGIN_100K_CODEX_COMPACT_CONTEXT_20260714.json
```

You may inspect tracked source files listed inside `tracked_source_pool` if needed.
Do not read `operations/school/curriculum/candidate_factory/memory/theme_cursor_ledger.json` directly in this task; use `cursor_summary` from the compact context pack.
If the compact context pack is missing, BLOCKED_PREFLIGHT.
## Task after PREFLIGHT_PASS

Create a NEW deep origin and NEW campaign pack:

```text
operations/school/curriculum/candidate_factory/source_origins/builder_deep_origin_100k_v1.jsonl
operations/school/curriculum/candidate_factory/source_origins/builder_deep_origin_100k_v1.manifest.json
operations/school/curriculum/candidate_factory/campaign_packs/builder_deep_origin_100k_v1.jsonl
operations/school/curriculum/candidate_factory/campaign_packs/builder_deep_origin_100k_v1.manifest.json
operations/school/curriculum/candidate_factory/reports/BUILDER_DEEP_ORIGIN_100K_AUTHOR_REPORT_V1.json
operations/school/curriculum/candidate_factory/reports/BUILDER_DEEP_ORIGIN_100K_COVERAGE_AUDIT_V1.json
operations/school/curriculum/candidate_factory/reports/BUILDER_DEEP_ORIGIN_100K_LEVEL_PLAN_V1.json
operations/school/curriculum/candidate_factory/reports/BUILDER_DEEP_ORIGIN_100K_NOVELTY_PLAN_V1.json
```

Campaign id:

```text
builder_deep_origin_100k_v1
```

## Deep origin requirements

The source origin is not a small seed list. It must be a compact but deep curriculum corpus.

`source_origins/builder_deep_origin_100k_v1.jsonl` must contain 240-480 origin units.
Each origin unit must be JSON with:

```text
origin_id
root
subsystem
scenario_family
failure_mode
operator_decision
proof_surface
negative_case
positive_case
minimum_validator
rollback_or_return_path
source_paths
why_it_matters
```

Rules:

- Every source_paths item must point to a tracked local source file or report.
- No invented external truth.
- Each origin unit must describe a distinct operational situation, not wording variations.
- It must include positive and negative cases.
- It must include an observable proof surface.

## Campaign pack requirements

`campaign_packs/builder_deep_origin_100k_v1.jsonl` must contain 1000-2000 seed lines.
Recommended: 1200 seeds.

Total expansion_budget must equal exactly 100000.
No single seed may have expansion_budget > 100.
Preferred per-seed budget: 50-100.

Each seed must include exactly these required fields:

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

- campaign_id must be `builder_deep_origin_100k_v1`.
- source_path must be the new origin JSONL path or one of the tracked repo source files cited by the origin.
- Every seed must reference an origin_id from `builder_deep_origin_100k_v1.jsonl`.
- Seeds must cover at least 12 roots and at least 80 scenario_family values.
- Do not copy old `builder_useful_100k_v1` seed wording.
- Do not produce generic operator advice.
- Every seed must force a concrete decision under a constraint.
- Every proof_target must name a concrete proof surface: report path, JSON field, validator status, hash, checkpoint, process count, or runtime boundary.
- Every negative_trap must be a failure that could realistically happen in this repo/school/runtime.
- Every behavior_delta must be something the Builder should do differently next time.
- `start_level` must be derived from theme cursor / old-update evidence where applicable; new scenario families may start at 1.

## Required roots / areas

Cover these at minimum, but you may add subroots if grounded:

```text
memory_weight_guard
active_memory_compaction_and_rollback
school_generation_absorption_separation
hundred_k_scale_ladder
codex_campaign_pack_governance
theme_cursor_level_continuation
speed_baseline_and_bottleneck_routing
runtime_retention_cleanup_after_proof
backup_retention_release_gate
child_agent_production_boundary
autonomous_next_action_selection
live_lab_boundary_for_big_runs
quality_gate_and_novelty_control
single_canonical_launch_route
codex_failure_recovery_and_retry_slicing
factory_checkpoint_integrity
```

## Quality targets for later 100k generation

The pack must be designed so that after local factory generation, expected quality can improve over the previous run:

```text
expected_seed_count >= 1000
expected_roots >= 12
expected_scenario_families >= 80
max_expansion_budget_per_seed <= 100
expected_unique_exercise_ratio_target >= 0.01
expected_expected_behavior_unique_ratio_target >= 0.01
fallback_expected = 0
source_missing_expected = 0
proof_missing_expected = 0
```

Record these in the novelty plan report.

## Validation after writing files

Run bounded validation only. Do not run 100k generation. Use Python for structural validation; run PowerShell only for the existing factory/validator commands exactly as shown, without wrapping them in generated pipeline code.

Required validation:

1. Parse all JSON/JSONL files.
2. Validate deep origin:
   - 240-480 origin units.
   - required fields present.
   - source_paths exist.
   - distinct origin_id.
   - at least 80 scenario_family values.
3. Validate campaign pack:
   - 1000-2000 seeds.
   - campaign_id correct.
   - total expansion_budget exactly 100000.
   - max expansion_budget per seed <= 100.
   - all required fields present.
   - every origin_id exists in origin file.
   - no duplicate seed_id.
   - at least 12 roots.
   - at least 80 scenario_family values.
   - every source_path exists.
4. Run a 100-candidate smoke generation if compatible:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File operations/school/curriculum/candidate_factory/generate_codex_curriculum_candidate_factory_run_v1.ps1 -TargetAccepted 100 -RunKind Test -BatchSize 100 -RunId builder_deep_origin_100k_pack_validation_100_20260714 -CampaignPack operations/school/curriculum/candidate_factory/campaign_packs/builder_deep_origin_100k_v1.jsonl
```

5. Run campaign validator if compatible:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File operations/school/curriculum/candidate_factory/validate_campaign_pack_candidate_factory_v1.ps1 -TargetAccepted 100 -BatchSize 100 -RunId builder_deep_origin_100k_pack_validation_100_20260714 -CampaignPack operations/school/curriculum/candidate_factory/campaign_packs/builder_deep_origin_100k_v1.jsonl
```

If validator does not understand extra fields such as origin_id, scenario_family, novelty_axis, validator_focus, keep the pack valid under existing required fields and record the validator limitation in AUTHOR_REPORT.

## Non-goals

Do not:

- generate 100k candidates directly;
- run streaming/staging on 100k;
- run digest/absorption;
- mutate active memory;
- delete old 100k staging;
- create another launch route;
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
root_count=
scenario_family_count=
coverage_status=
level_plan_status=
novelty_plan_status=
factory_smoke_status=
campaign_validator_status=
active_memory_mutated=false
generation_100k_started=false
absorption_started=false
Files changed before PREFLIGHT_PASS: YES/NO
expected: NO
```

Boundary: output is CODEX_DRAFT until GPT/operator independently validates.