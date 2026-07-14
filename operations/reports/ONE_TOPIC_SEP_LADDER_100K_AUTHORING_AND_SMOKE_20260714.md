# ONE_TOPIC_SEP_LADDER_100K_AUTHORING_AND_SMOKE_20260714

Status: PASS_ONE_TOPIC_SEP_LADDER_PACK_SMOKE_VALIDATED

Boundary: Codex authoring + 100-candidate smoke only. No 100k generation, no streaming, no digest/absorption, no active memory mutation.

- campaign_id: builder_sep_ladder_100k_v1
- topic: school_generation_absorption_separation
- origin_unit_count: 180
- seed_count: 1200
- total_expansion_budget: 100000
- max_expansion_budget_per_seed: 84
- scenario_family_count: 180
- independent_validation_status: PASS_ONE_TOPIC_SEP_LADDER_CODEX_DRAFT_VALIDATED_AFTER_REPAIR

Contract repair:
- status: PASS_ALLOWED_MODES_NORMALIZED_FOR_CONTRACT
- allowed_modes normalized to directed_curriculum / experience_curriculum; semantic modes preserved in operational_mode_family.

100-candidate smoke:
- status: PASS_CAMPAIGN_PACK_CANDIDATE_FACTORY_V1
- candidates_created: 100
- seed_backed_percent: 100
- fallback_percent: 0
- contract_accepted: 100
- contract_rejected: 0
- active_memory_mutated: False

Next action: run 100k Test generation, streaming/staging, and quality gate. No digest/absorption.