# SCHOOL_100K_USEFULNESS_QUALITY_GATE_20260714

Status: PASS_CONTRACT_SOURCE_COVERAGE_BUT_LOW_NOVELTY_COMPACT_DIGEST_ONLY

Boundary: quality gate only. No digest, no absorption, no active memory mutation.

Correction: v3 treats root/seed budget mismatch as scheduler weighting drift, not hard quality failure, because coverage is 12/12 roots and 48/48 seeds with 100000 accepted candidates.

- candidates: 100000
- ready_atoms: 100000
- roots: 12/12
- seeds: 48/48
- fallback_template_count: 0
- source_missing_count: 0
- proof_missing_count: 0
- hard_failures: 0
- unique_exercise_ratio: 0.00144
- unique_expected_behavior_ratio: 0.00048
- exercise_duplicate_max_cluster: 696
- expected_behavior_duplicate_max_cluster: 2088

Decision: reject raw 100k promotion; allow compact seed/root digest only.

Root counts:
- active_memory_compaction_and_rollback: 8352
- autonomous_next_action_selection: 8328
- backup_retention_release_gate: 8328
- child_agent_production_boundary: 8328
- codex_campaign_pack_governance: 8328
- hundred_k_scale_ladder: 8328
- live_lab_boundary_for_big_runs: 8328
- memory_weight_guard: 8352
- runtime_retention_cleanup_after_proof: 8328
- school_generation_absorption_separation: 8344
- speed_baseline_and_bottleneck_routing: 8328
- theme_cursor_level_continuation: 8328