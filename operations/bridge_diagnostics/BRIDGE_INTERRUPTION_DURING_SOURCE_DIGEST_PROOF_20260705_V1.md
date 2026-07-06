# Bridge interruption during source digest proof 2026-07-05

Status: RECOVERED_AFTER_BRIDGE_ENDPOINT_OFFLINE

User-visible errors:

`	ext
ERR_NGROK_3004
ERR_NGROK_3200 endpoint offline
`

Interrupted user-visible operation:

`	ext
SOURCE_DIGEST_PROOF_RUN
operations/knowledge_acquisition_port/ask_codex_knowledge_source.ps1
RunId: source_digest_retention_docx_20260705_01
`

Recovery finding:

`	ext
local proof exists: true
local digest exists: true
raw source exists: false
proof status: PASS_CODEX_DRAFT_RETURNED
raw retention: DELETED_AFTER_COMPACT_DIGEST
digest status: COMPACT_DIGEST_CREATED
promotion default: CASE_PATTERN_CANDIDATE
`

Interpretation:

Transport failed between ChatGPT and local Bridge, but the local command completed. Do not treat bridge loss as local failure without artifact/process recovery.

Probable cause hypothesis:

`	ext
brief internet/ngrok tunnel interruption, IP/session change, endpoint restart, or similar transport break
`

Bridge hardening candidates:

- managed run heartbeat and resumable polling by run_id
- local run ledger independent of ngrok connection
- automatic recovery sequence: health -> context -> process scan -> last managed run report -> repo status
- record last command sha/run_id/cwd/head/dirty state before long runs
- on transport failure, inspect local artifacts before retrying or rollback
