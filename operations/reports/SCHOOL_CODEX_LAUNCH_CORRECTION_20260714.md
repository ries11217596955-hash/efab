# SCHOOL_CODEX_LAUNCH_CORRECTION_20260714

Status: OWNER_CORRECTION_ACCEPTED_REPO_TASK_FILE_ROUTE_RESTORED

Owner was right: old successful route was a repo task file route, not embedded stdin mega-prompt mode.

Historical evidence:
- Journal: launched Codex on `CODEX_TASK_EVIDENCE_GROUNDED_SCHOOL_GENERATOR_V1.md`.
- Journal: unsupported `-a never` failed.
- Journal: supported command was `codex exec -C H:/efab -s workspace-write --json`.
- Journal: Codex created campaign pack + validator under existing candidate_factory.
- Journal: TargetAccepted 25/100 PASS.

Restored task file:
- `operations/gpt_handoff/CODEX_TASK_SCHOOL_100K_USEFUL_CAMPAIGN_GENERATOR_V1.md`

Latest attempt:
- Used repo-task-file prompt with old supported command pattern.
- Codex read repo context/pointers but did not create `builder_useful_100k_v1` pack files.

Boundary:
- campaign_pack=NOT_PRODUCED
- 100k_generation=NOT_STARTED
- absorption=NOT_STARTED
- active_memory_mutated=false

Corrected next route:
- Use repo task file route.
- Split into proven two slices: coverage/level only, then campaign pack/validator.
- Do not use embedded JSON prompt mode.