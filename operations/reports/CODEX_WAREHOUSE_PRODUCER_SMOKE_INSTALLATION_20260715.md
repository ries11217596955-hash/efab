# CODEX_WAREHOUSE_PRODUCER_SMOKE_INSTALLATION_20260715

Status: PASS_CODEX_WAREHOUSE_PRODUCER_SMOKE_CONNECTED_WITH_RECOVERY_NO_ABSORB_V1

Real Codex producer was connected to the dynamic warehouse request in smoke mode.

Result:

`	ext
Codex produced micro_001 READY payload = 100 JSONL lines
Codex failed before marker/heartbeat completion due sandbox rename/timeout behavior
School recovered READY marker after validating payload
School consumed 100 candidates without absorption
memory_changed = false
`

Protocol repair:

`	ext
READY marker remains authoritative.
If sandbox denies rename, producer may copy/write READY.jsonl directly and then write marker.
School recovery can validate unmarked READY payload and create recovered READY marker.
`

Boundary: no absorption was run.

