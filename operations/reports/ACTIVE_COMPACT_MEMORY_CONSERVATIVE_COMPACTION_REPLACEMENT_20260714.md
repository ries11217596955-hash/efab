# ACTIVE_COMPACT_MEMORY_CONSERVATIVE_COMPACTION_REPLACEMENT_20260714

Status: PASS_ACTIVE_COMPACT_MEMORY_CONSERVATIVE_COMPACTION_REPLACED_AND_VALIDATED
Mode: conservative_relations_source_fingerprints_summarized_properties_preserved
Backup path: .runtime\active_compact_semantic_memory_v1_backups\before_conservative_compaction_20260714_163639
Candidate path: .runtime\active_compact_semantic_memory_v1_compaction_work_20260714\candidate_conservative

Before:
- cells.jsonl: 113342972 bytes
- index.json: 308130 bytes
- manifest.json: 972 bytes

After:
- cells.jsonl: 12637868 bytes
- index.json: 308130 bytes
- manifest.json: 1814 bytes

Bytes saved in cells.jsonl: 100705104
Validation: recall probe PASS + structural live compaction validation PASS.
What was compacted: relations and source_fingerprints summarized into count + sha256 + head/tail samples.
What was preserved: properties full list, index.json, cell_id set, observation_count sum, labels/summaries/uses.

Rollback:
To rollback: Remove .runtime/active_compact_semantic_memory_v1 and copy backup_path back to .runtime/active_compact_semantic_memory_v1.

Boundary: aggressive 0.49 MB candidate was not installed. Active memory was mutated only through conservative backup+validator path.