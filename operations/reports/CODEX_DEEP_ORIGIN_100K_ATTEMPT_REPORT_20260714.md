# CODEX_DEEP_ORIGIN_100K_ATTEMPT_REPORT_20260714

Status: CODEX_DEEP_ORIGIN_NOT_PRODUCED

Owner goal: Codex should create a new deep origin and new campaign pack capable of producing new 100k higher-novelty candidates.

Prepared:
- `AGENTS.md` updated to current school/Codex route.
- `operations/gpt_handoff/CODEX_TASK_SCHOOL_DEEP_ORIGIN_100K_CANDIDATES_V1.md` created.
- `operations/reports/DEEP_ORIGIN_100K_CODEX_COMPACT_CONTEXT_20260714.json` created.

Expected outputs were not produced:
- `operations/school/curriculum/candidate_factory/source_origins/builder_deep_origin_100k_v1.jsonl`
- `operations/school/curriculum/candidate_factory/source_origins/builder_deep_origin_100k_v1.manifest.json`
- `operations/school/curriculum/candidate_factory/campaign_packs/builder_deep_origin_100k_v1.jsonl`
- `operations/school/curriculum/candidate_factory/campaign_packs/builder_deep_origin_100k_v1.manifest.json`
- `operations/school/curriculum/candidate_factory/reports/BUILDER_DEEP_ORIGIN_100K_AUTHOR_REPORT_V1.json`
- `operations/school/curriculum/candidate_factory/reports/BUILDER_DEEP_ORIGIN_100K_COVERAGE_AUDIT_V1.json`
- `operations/school/curriculum/candidate_factory/reports/BUILDER_DEEP_ORIGIN_100K_LEVEL_PLAN_V1.json`
- `operations/school/curriculum/candidate_factory/reports/BUILDER_DEEP_ORIGIN_100K_NOVELTY_PLAN_V1.json`

Failures observed:
- PowerShell pipeline/parser failure in Codex commands.
- Stale AGENTS pointer to old task route; fixed.
- Missing non-repo uploaded knowledge files in required context; fixed.
- Theme cursor direct parsing BOM/quoting failures; replaced with compact context.
- Compact-context attempt still did not create expected deep-origin/pack files.

Boundary:
- generation_100k_started=false
- streaming_started=false
- digest_started=false
- absorption_started=false
- active_memory_mutated=false

Next route: split Codex into smaller per-root deep-origin tasks or explicitly switch to operator/GPT-authored deterministic origin generation. Do not retry the same broad task blindly.