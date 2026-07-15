# CODEX_WAREHOUSE_PRODUCER_SMOKE_INSTALLATION_20260715

Status: PASS_CODEX_WAREHOUSE_PRODUCER_HAPPY_PATH_READY_MARKER_NO_ABSORB_V1

Real Codex producer happy-path is proven for one micro-batch.

`	ext
Codex wrote micro_001.READY.jsonl directly
Codex wrote micro_001.READY.marker.json
Codex wrote producer.heartbeat.json
School consumed 100 candidates
absorption_run = false
memory_changed = false
`

Runner repair:

`	ext
The smoke prompt forbids tmp/rename and requires direct READY write.
If Codex CLI stays alive after valid READY output, runner treats timeout-after-ready as success and kills only its own process tree.
`

Boundary: no absorption was run.
