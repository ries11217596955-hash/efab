# COMPACT_MEMORY_WEIGHT_AUDIT_20260714

Status: PASS_AUDIT_ONLY_NO_MEMORY_MUTATION

Cells: 121
Manifest input_count: 5000
Manifest merged_count: 5000
Observation_count sum: 450012
cells.jsonl: 113342972 bytes / 108.09 MB
index.json: 308130 bytes / 0.29 MB

Top fields by total bytes:
- relations: 72541028 bytes / 69.181 MB; count=121; list_items=850001
- source_fingerprints: 28478159 bytes / 27.159 MB; count=121; list_items=425002
- properties: 12220825 bytes / 11.655 MB; count=121; list_items=425121
- summary: 27603 bytes / 0.026 MB; count=121; list_items=0
- uses: 25695 bytes / 0.025 MB; count=121; list_items=241
- concept_key: 11386 bytes / 0.011 MB; count=121; list_items=0
- label: 10946 bytes / 0.01 MB; count=121; list_items=0
- updated_at: 6050 bytes / 0.006 MB; count=121; list_items=0
- kind: 4588 bytes / 0.004 MB; count=121; list_items=0
- schema: 4477 bytes / 0.004 MB; count=121; list_items=0

Index verdict: INDEX_IS_SMALL_KEEP; not the storage problem

Compaction estimate:
- summarize large list fields ['relations', 'source_fingerprints', 'properties']: candidate cells size 0.279 MB, savings 99.74%
- summarize large list + dict fields []: candidate cells size 0.279 MB, savings 99.74%

Boundary: audit only. Active memory was not modified.