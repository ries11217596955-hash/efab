# ONE_TOPIC_SEP_LADDER_100K_COMPLETION_20260714

Status: PASS_ONE_TOPIC_SEP_LADDER_100K_COMPLETED_AND_ABSORBED

Boundary: raw 100k was not promoted. A compact 191-atom digest was absorbed through the digest pipeline and active compact memory was published.

## Stream

- status: PASS_STREAMING_SCHOOL_TO_ABSORPTION_PIPELINE_V1
- processed: 100000
- accepted: 100000
- rejected: 0
- quarantine: 0

## Quality gate

- status: PASS_ONE_TOPIC_SEP_100K_QUALITY_GATE_COMPACT_DIGEST_READY
- unique_exercise_ratio: 0.036
- unique_expected_behavior_ratio: 0.012
- seeds: 1200
- origins: 180
- scenario_families: 180

## Absorption

- status: PASS_FILE_ATOM_ABSORPTION_PIPELINE_V1
- input_atoms: 191
- normalized_digest_atoms: 191
- validation_tier: Stable
- digest_status: PASS_COMPACT_SEMANTIC_DIGESTION_ORGAN_V1
- memory_weight_guard_status: PASS_COMPACT_MEMORY_WEIGHT_GUARD_V1
- digested_cells: 122
- merged_count: 190
- total_memory_bytes: 12784150

## Active memory

- changed: True
- before cells sha256: E4C7302F75A2838D2CF5FD91FDCC67D1D3D2F8544FC42393B7E956C712E56E00
- after cells sha256: 199C9D9391ED5C79BBC774F8F81E884E4B439A291091C8F6F2A36A7792BA8BD1

Next: retention cleanup of transient runtime staging and obsolete failed-route files only; do not delete active compact memory.