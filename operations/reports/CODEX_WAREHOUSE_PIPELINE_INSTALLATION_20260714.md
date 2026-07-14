# CODEX_WAREHOUSE_PIPELINE_INSTALLATION_20260714

Status: PASS_CODEX_WAREHOUSE_PIPELINE_V1_INSTALLED_AND_VALIDATED

Installed producer/consumer warehouse protocol:

```text
School patch = 1000 candidates
Codex warehouse output = 10 micro-batches × 100
School consumes READY batches independently
School waits with heartbeat when it is ahead of Codex
```

Validation:

- status: PASS_CODEX_WAREHOUSE_PIPELINE_VALIDATION_V1
- patch_candidate_count: 1000
- micro_batch_size: 100
- micro_batch_count: 10
- ready_consumer_status: PASS_WAREHOUSE_CONSUMED_READY_BATCHES_NO_ABSORB_V1
- ready_consumed_count: 1
- ready_accepted_count: 100
- wait_consumer_status: PASS_WAREHOUSE_CONSUMER_WAIT_TIMEOUT_NO_READY_V1
- memory_changed: False

Rules:

```text
Codex may fill warehouse within one patch without waiting for School.
School consumes only READY marker + READY JSONL.
School never consumes WRITING.
School does not launch duplicate producer while heartbeat/producer state is unresolved.
Only ABSORBED counts as memory progress.
```

Boundary: validator used mock READY micro-batch and wait scenario. No real Codex and no absorption.
