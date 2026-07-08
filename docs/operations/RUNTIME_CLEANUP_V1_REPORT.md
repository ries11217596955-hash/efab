# Runtime Cleanup V1 Report

status: PASS_RUNTIME_CLEANUP_V1
runtime_size_mb_before: 4572.46
runtime_size_mb_after: 48.51
freed_mb: 4523.95

## Deleted untracked transient paths
- .runtime/school_runs/school_factory_digest_use_real_1000000_20260707_140233/memory_checkpoints | deleted=True | mb_before=3545.42 | files=600 | tracked_count=0
- .runtime/compact_memory_intake_v1/checkpoints | deleted=True | mb_before=556.28 | files=204 | tracked_count=0
- .runtime/file_atom_absorption | deleted=True | mb_before=271.88 | files=32 | tracked_count=0
- .runtime/school_source_template_filter | deleted=True | mb_before=0.89 | files=285 | tracked_count=0
- .runtime/school_runs/school_factory_digest_use_real_1000000_20260707_110037/memory_checkpoints | deleted=True | mb_before=149.48 | files=123 | tracked_count=0

## Preserved
- active compact semantic memory
- compact memory growth signal
- canonical School 1M proof
- current live AIMO runtime proof

## Boundary
No git history rewrite. No live process touch. No active memory mutation. Cleanup removed only untracked runtime checkpoint/candidate/filter mass.
