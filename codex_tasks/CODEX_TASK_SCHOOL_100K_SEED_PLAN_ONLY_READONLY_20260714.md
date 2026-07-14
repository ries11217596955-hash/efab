# CODEX_TASK_SCHOOL_100K_SEED_PLAN_ONLY_READONLY_20260714

You are Codex as bounded campaign seed-plan author.

READ-ONLY TASK.
Do not write files.
Do not run PowerShell.
Do not run shell commands.
Do not run candidate factory.
Do not run validators.
Do not run absorption/digest.
Do not mutate active memory.

Use the compact context below as your source of truth:

```text
operations/reports/CODEX_100K_CAMPAIGN_COMPACT_CONTEXT_20260714.json
```

Your only output is your final answer. Return one JSON object and nothing else.

Required JSON schema:

```json
{
  "schema": "codex_seed_plan_draft_v1",
  "status": "CODEX_DRAFT_SEED_PLAN_ONLY",
  "campaign_id": "builder_useful_100k_v1",
  "total_expansion_budget": 100000,
  "seed_count": 0,
  "coverage_status": "...",
  "level_plan_status": "...",
  "active_memory_mutated": false,
  "generation_started": false,
  "absorption_started": false,
  "files_written": false,
  "seeds": [
    {
      "seed_id": "...",
      "campaign_id": "builder_useful_100k_v1",
      "root": "...",
      "depth_level_band": "...",
      "start_level": 1,
      "source_kind": "tracked_repo_file",
      "source_path": "...",
      "source_anchor_or_hint": "...",
      "source_summary": "...",
      "lesson": "...",
      "negative_trap": "...",
      "proof_target": "...",
      "behavior_delta": "...",
      "return_to_parent": "...",
      "allowed_verbs": ["observe", "validate"],
      "allowed_modes": ["lab"],
      "expansion_budget": 1000
    }
  ],
  "root_budget_summary": [
    {"root":"...", "budget": 1000, "seed_count": 1, "start_policy":"..."}
  ],
  "boundary": "Seed plan only. No files written, no generation, no absorption. CODEX_DRAFT until GPT/operator validation."
}
```

Requirements:

- Use exactly the 12 roots from compact context.
- Total expansion_budget across seeds must equal exactly 100000.
- Prefer 48 to 80 seeds.
- Each seed must cite a tracked local source_path named in compact context.
- Lessons must be operational and specific.
- Negative traps must be real failure modes.
- Proof targets must name observable repo/report/runtime surfaces.
- Old-update roots must not blindly reset to level 1; use start_policy in root_budget_summary.
- Keep output valid JSON. No markdown fences.