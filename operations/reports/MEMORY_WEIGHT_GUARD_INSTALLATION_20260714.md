# MEMORY_WEIGHT_GUARD_INSTALLATION_20260714

Status: PASS_MEMORY_WEIGHT_GUARD_INSTALLED_AND_VALIDATED

What changed:
- Added `operations/school/digestion/apply_compact_memory_weight_guard_v1.ps1`.
- Wired it into `operations/school/digestion/absorb_atom_file_via_digest_pipeline_v1.ps1` after digest and before publish.

Policy:
- Mode: Conservative.
- Guarded fields: relations, source_fingerprints.
- Limit: max_list_items=1000 or max_field_bytes=262144.
- Action: summarize large proof-tail lists into count + sha256 + head/tail samples.
- Properties: preserved full.

Proof:
- Synthetic heavy test: PASS_COMPACT_MEMORY_WEIGHT_GUARD_V1, events=2, bytes_saved=25064, properties preserved.
- Absorption integration test: PASS_FILE_ATOM_ABSORPTION_PIPELINE_V1, guard_status=PASS_COMPACT_MEMORY_WEIGHT_GUARD_V1, guard_proof=.runtime/file_atom_absorption/file_atom_absorption_20260714_170259/MEMORY_WEIGHT_GUARD_V1.json.
- Recall probe on integration memory: PASS_COMPACT_MEMORY_RECALL_USE_PROBE_V1_VALID.

Active memory mutated by guard install: false.
Active cells/index unchanged since conservative compaction: True.

Boundary: This installs future merge protection. It does not prove unlimited 500k readiness; size reports must still be monitored after large runs.