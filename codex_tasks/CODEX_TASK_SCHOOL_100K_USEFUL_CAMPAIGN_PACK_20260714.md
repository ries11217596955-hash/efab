# CODEX_TASK_SCHOOL_100K_USEFUL_CAMPAIGN_PACK_20260714

## Role boundary

You are Codex acting as a bounded campaign-material author for the Builder school.
You are not Builder brain, not active memory, not school runtime, and not absorption engine.

Goal: author a high-quality, evidence-grounded campaign pack that the existing local candidate factory can expand into 100,000 school candidates later.

Candidate generation and atom absorption are separate processes:

1. This task: Codex authors compact campaign material only.
2. Later operator step: local candidate factory expands campaign seeds to 100k candidates.
3. Later separate step: streaming/absorption/digest pipeline processes generated atoms.

Do not run a 100k absorption/digest. Do not mutate `.runtime/active_compact_semantic_memory_v1`.

## PREFLIGHT requirement

Before writing any file, inspect the listed context and return either:

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

Read these files:

```text
operations/reports/SCHOOL_100K_USEFUL_CAMPAIGN_TOPIC_PLAN_20260714.json
operations/gpt_handoff/GPT_OPERATOR_JOURNAL.md
operations/gpt_handoff/CODEX_TASK_EVIDENCE_GROUNDED_SCHOOL_GENERATOR_V1.md
operations/school/curriculum/candidate_factory/generate_codex_curriculum_candidate_factory_run_v1.ps1
operations/school/curriculum/candidate_factory/campaign_packs/builder_self_knowledge_deep_v1.jsonl
operations/school/curriculum/candidate_factory/campaign_packs/builder_self_knowledge_deep_v1.manifest.json
operations/school/curriculum/candidate_factory/memory/theme_cursor_ledger.json
operations/school/digestion/apply_compact_memory_weight_guard_v1.ps1
operations/school/digestion/absorb_atom_file_via_digest_pipeline_v1.ps1
operations/reports/MEMORY_WEIGHT_GUARD_INSTALLATION_20260714.json
operations/reports/ACTIVE_COMPACT_MEMORY_CONSERVATIVE_COMPACTION_REPLACEMENT_20260714.json
operations/reports/RUNTIME_CLEANUP_REPORT_20260714.json
```

If any required file is missing, BLOCKED_PREFLIGHT.

## Task after PREFLIGHT_PASS

Create a new campaign pack for a 100,000-candidate useful school generation.

Output files:

```text
operations/school/curriculum/candidate_factory/campaign_packs/builder_useful_100k_v1.jsonl
operations/school/curriculum/candidate_factory/campaign_packs/builder_useful_100k_v1.manifest.json
operations/school/curriculum/candidate_factory/reports/BUILDER_USEFUL_100K_CAMPAIGN_COVERAGE_AUDIT_V1.json
operations/school/curriculum/candidate_factory/reports/BUILDER_USEFUL_100K_CAMPAIGN_LEVEL_PLAN_V1.json
operations/school/curriculum/candidate_factory/reports/BUILDER_USEFUL_100K_CAMPAIGN_AUTHOR_REPORT_V1.json
```

Do not modify source code unless PREFLIGHT blocks on a validator gap; if blocked, report the exact missing validator instead of patching broadly.

## Campaign content requirements

Use the topic plan:

```text
operations/reports/SCHOOL_100K_USEFUL_CAMPAIGN_TOPIC_PLAN_20260714.json
```

The pack must cover the 12 proposed roots there, with total expansion_budget exactly 100000.

For each seed line, JSONL object fields required:

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

- campaign_id must be `builder_useful_100k_v1`.
- Every seed must have a tracked local `source_path`.
- No invented source truth.
- No generic lessons like “learn repo structure”.
- Every lesson must teach an operator behavior that protects future school/growth runs.
- Every negative_trap must name a real failure mode.
- Every proof_target must name an observable proof surface: report path, JSON field, validator status, hash, or runtime boundary.
- New topics start at level 1 unless evidence says otherwise.
- Old-update topics must use cursor/memory/journal evidence and continue from the appropriate level; never reset all roots blindly to level 1.
- Keep seed count compact: prefer 48-80 high-quality seeds, not thousands.
- Budget per root should follow the plan unless evidence says a small adjustment is needed; total must remain exactly 100000.

## Required validation after writing files

1. Validate JSONL parse and required fields.
2. Validate manifest:
   - schema=`codex_campaign_pack_manifest_v1`
   - status=`CODEX_DRAFT_CAMPAIGN_PACK`
   - campaign_id=`builder_useful_100k_v1`
   - seed_count equals JSONL line count
   - total_expansion_budget=100000
   - runtime_ready=false
   - boundary says this is campaign material only, not absorption.
3. Run a small factory smoke test, not 100k:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File operations/school/curriculum/candidate_factory/generate_codex_curriculum_candidate_factory_run_v1.ps1 -TargetAccepted 100 -RunKind Test -BatchSize 100 -RunId builder_useful_100k_pack_validation_100_20260714 -CampaignPack operations/school/curriculum/candidate_factory/campaign_packs/builder_useful_100k_v1.jsonl
```

4. Run contract/streaming validation for that 100-candidate factory output using the existing validator if compatible:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File operations/school/curriculum/candidate_factory/validate_codex_curriculum_candidate_factory_v1.ps1 -TargetAccepted 100 -BatchSize 100 -RunId builder_useful_100k_pack_validation_100_20260714 -CampaignPack operations/school/curriculum/candidate_factory/campaign_packs/builder_useful_100k_v1.jsonl
```

If the validator does not support `-CampaignPack`, run the directly relevant lower validators and record the limitation.

## Explicit non-goals

Do not:

- generate 100k candidates directly by hand;
- run absorption/digest;
- mutate active memory;
- clean runtime;
- launch live school;
- edit protected memory;
- push to GitHub;
- claim 100k is complete.

## Required final report

Final response must include:

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
active_memory_mutated=expected false
codex_cli_invoked=true
api_invoked=<true/false if visible>
Files changed before PREFLIGHT_PASS: YES/NO
expected: NO
```

Status labels:

- `PREFLIGHT_PASS`
- `BLOCKED_PREFLIGHT`
- `CODEX_DRAFT_CAMPAIGN_PACK`
- `PASS_100K_CAMPAIGN_PACK_SMOKE_VALIDATED`
- `NOT_READY_FOR_ABSORPTION` if any validation is missing.

Boundary: output is CODEX_DRAFT until GPT/operator validates independently.