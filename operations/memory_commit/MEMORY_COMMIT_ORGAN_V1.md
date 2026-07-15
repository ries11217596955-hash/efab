# MEMORY_COMMIT_ORGAN_V1

One active compact-memory commit throat. School has priority for batch commits. AgentLife atoms are queued during School and drained after School or in safe micro-slices. Rejected packets are deleted immediately after a compact rejection metric is written. Accepted packets are removed from the queue after successful merge.

Boundary: this organ protects active memory integrity; it does not create multiple blind writers into `.runtime/active_compact_semantic_memory_v1`.
