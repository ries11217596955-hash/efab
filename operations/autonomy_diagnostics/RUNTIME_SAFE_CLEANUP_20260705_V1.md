# Runtime safe cleanup 2026-07-05

Status: PROVEN_LOCAL_CLEANUP_AFTER_REPORT_RECOVERY

Deleted only untracked runtime proof/snapshot/prompt directories.

Preserved:

`	ext
.runtime/active_compact_semantic_memory_v1
`

Sizes:

`	ext
repo before: 216377505 bytes
repo after: 157342862 bytes
runtime before: 66306807 bytes
runtime after: 7272164 bytes
runtime removed: 59034643 bytes
active memory after: 7272164 bytes
`

Deleted directories:

- .runtime/school_runs = 47984298 bytes
- .runtime/memory_snapshots = 10688355 bytes
- .runtime/codex_task_prompts = 90687 bytes
- .runtime/night_run_proofs = 22065 bytes
- .runtime/real_failure_rollback_proofs = 48299 bytes
- .runtime/real_resume_execution_proofs = 41563 bytes
- .runtime/scale_gate_proofs = 151521 bytes
- .runtime/supply_gate_proofs = 4894 bytes
- .runtime/memory_rebuild_proofs = 2961 bytes

Boundary: .runtime is untracked; active compact semantic memory was preserved. Initial report generation failed after deletion due manifest field typing; this report recovered from preflight measurements and current state.
