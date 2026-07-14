# SCHOOL_100K_USEFUL_STAGING_RUN_20260714

Status: PASS_100K_USEFUL_SCHOOL_STAGING_COMPLETE

Boundary: LAB/Test staging only. No digest, no absorption, no active memory mutation.

Campaign:
- seed_count: 48
- expansion_budget: 100000
- roots: 12
- independent validation: PASS_CODEX_100K_CAMPAIGN_PACK_INDEPENDENT_VALIDATION

Generation:
- status: PASS_CODEX_CANDIDATE_FACTORY_GENERATION_V1
- run_kind: Test
- Real attempt: BLOCKED_REAL_RUN_REQUIRES_LIVE_AUTHORITY_PASSPORT
- candidates_created: 100000
- batches_created: 1000
- seed_backed: 100000
- fallback: 0
- elapsed_seconds: 308.536

Generation checkpoint limitation:
- Factory stdout reported PASS and process exited 0, but checkpoint.json remained RUNNING.

Streaming/staging:
- status: PASS_STREAMING_SCHOOL_TO_ABSORPTION_PIPELINE_V1
- processed_total: 100000
- contract_accepted_total: 100000
- contract_rejected_total: 0
- ready_atoms_total: 100000
- stream_quarantined_total: 0
- active_memory_mutated: False
- streaming_memory_mode: bounded_counters_and_jsonl_writers_v2
- elapsed_seconds: 647.754

Next action:
- usefulness/quality gate before any digest or absorption.