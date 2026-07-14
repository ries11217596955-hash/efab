# SCHOOL_CANONICAL_LAUNCH_POINTER_20260714

Status: ACTIVE_CANONICAL_SCHOOL_LAUNCH_ROUTE

## Only active route

1. Codex campaign authoring via repo task file:
   - `operations/gpt_handoff/CODEX_TASK_SCHOOL_100K_USEFUL_CAMPAIGN_GENERATOR_V1.md`
   - command pattern: `codex exec -C H:/efab -s workspace-write --json`
   - prompt: `Read and execute this repo task file: operations/gpt_handoff/CODEX_TASK_SCHOOL_100K_USEFUL_CAMPAIGN_GENERATOR_V1.md`

2. GPT/operator validates Codex output.

3. Local candidate generation:
   - `operations/school/curriculum/candidate_factory/generate_codex_curriculum_candidate_factory_run_v1.ps1`

4. Streaming/staging:
   - `operations/school/curriculum/streaming_absorption/process_codex_curriculum_streaming_absorption_v1.ps1`

5. Later separate absorption/digest:
   - `operations/school/digestion/absorb_atom_file_via_digest_pipeline_v1.ps1`
   - protected by `operations/school/digestion/apply_compact_memory_weight_guard_v1.ps1`

## Not active anymore

- embedded stdin prompt task route
- read-only no-shell context-by-path route
- lean prompt task route
- manual GPT-authored 100k campaign pack unless Owner explicitly changes route

Boundary: this pointer does not mean a 100k campaign pack exists. It only defines the one allowed launch route.
