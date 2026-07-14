# ONE_TOPIC_SEP_LADDER_100K_QUALITY_GATE_20260714

Status: PASS_ONE_TOPIC_SEP_100K_QUALITY_GATE_COMPACT_DIGEST_READY

Boundary: quality gate only. No digest, no absorption, no active memory mutation.

Correction: v2 measures origin/scenario/level coverage from campaign pack and origin corpus because candidate_factory strips those metadata fields from generated candidates.

- candidate_count: 100000
- ready_count: 100000
- seed_count_observed: 1200
- fallback_template_count: 0
- source_missing_count: 0
- proof_missing_count: 0
- candidate_unique_exercise_ratio: 0.036
- candidate_unique_expected_behavior_ratio: 0.012

Pack/origin coverage:
- origin_unit_count: 180
- pack_seed_count: 1200
- pack_origin_reference_count: 180
- pack_scenario_family_count: 180
- pack_level_band_count: 10
- origin_scenario_family_count: 180
- total_expansion_budget: 100000
- max_expansion_budget_per_seed: 84
- missing_origin_refs_count: 0

Old 100k comparison:
- exercise_novelty_multiplier: 25.0
- expected_behavior_novelty_multiplier: 25.0

Decision: compact digest allowed; raw 100k promotion false.