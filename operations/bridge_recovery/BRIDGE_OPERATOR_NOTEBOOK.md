# Bridge Operator Notebook

First read after chat migration, bridge failure, or PC reboot.

## Current live topology

### Channel A — Primary production channel

Purpose: normal GPT control of this PC. This channel must be independently correct and must not depend on Channel B for ordinary operation.

Route:

`GPT Action -> ngrok public endpoint -> Recovery Gateway 127.0.0.1:18787 -> Primary Bridge 127.0.0.1:18788`

Lifecycle:
- `EFAB Bridge Boot SYSTEM`
- `EFAB Recovery Gateway SYSTEM`
- `EFAB Ngrok Primary SYSTEM`
- `EFAB Ngrok Watchdog SYSTEM`

Current proof:
- Primary local health: PROVEN_LIVE
- Recovery local health: PROVEN_LIVE
- Public ngrok health: PROVEN_LIVE
- ngrok forced-kill recovery: PROVEN_LIVE, restored in 7 seconds
- full Windows reboot recovery: PROVEN_LIVE, full topology restored in 19 seconds
- process ownership: one Primary, one Recovery Gateway, one ngrok process

Primary rule:

Channel A is the production body. Channel B must never be used as an excuse to leave Channel A unstable, duplicated, dev-only, or without boot/restart validation.

### Channel B — Independent rescue channel

Purpose: emergency control when Channel A is unavailable or cannot recover itself.

Route:

`Rescue GPT Action -> Tailscale Funnel -> Rescue Control Plane 127.0.0.1:18789`

Lifecycle:
- `EFAB Rescue Control SYSTEM`
- `EFAB Rescue Watchdog SYSTEM`

Current proof:
- Rescue local health: PROVEN_LIVE
- Rescue public Tailscale health: PROVEN_LIVE
- Bearer authentication on Rescue server: PROVEN_LIVE
- Rescue Action in this GPT toolset: NOT_CONNECTED

Boundary:

The Rescue server is live, but it is not yet available to this GPT as an independent callable Action. Until that is connected and tested, complete loss of Channel A still requires external access to invoke Rescue.

## Live paths

- Primary live body: `H:\bridge`
- Agent Builder repo: `H:\efab`
- Rescue root: `C:\ProgramData\EFAB-Rescue`
- ngrok lifecycle root: `C:\ProgramData\EFAB-Ngrok`
- Primary boot root: `C:\ProgramData\EFAB-Primary`
- reboot proof root: `C:\ProgramData\EFAB-Reboot-Proof`

## Canonical V2 scripts

- Install: `scripts/install_bridge_v2.ps1`
- Recover: `scripts/recover_bridge_v2.ps1`
- Validate: `scripts/validate_bridge_v2.ps1`

V1 scripts remain historical compatibility material and are not the canonical two-channel path.

## Current migration artifact

- Archive: `releases/EFAB_BRIDGE_MIGRATION_PACK_v2_20260726.zip`
- Proof: `proofs/migration_pack_v2_proof_20260726.json`
- Live validator proof: `proofs/migration_validation_v2_current_20260726.json`
- Stage-only proof: `proofs/stage_only_install_proof_20260726.json`

Status:
- current PC: PROVEN_LIVE
- reboot recovery: PROVEN_LIVE
- V2 preflight: PASS
- V2 stage-only install: PROVEN_LAB
- clean-PC full install: NOT_PROVEN

## Required order of work

1. Keep Channel A stable as the production channel.
2. Prove Channel A boot, restart, process uniqueness, public health, and sustained monitoring.
3. Connect Channel B as a truly independent GPT Action.
4. Prove Channel B can inspect and restart Channel A.
5. Prove Channel B can request controlled machine reboot and observe recovery.
6. Only after both channels are independently proven, call the dual-channel architecture mature.

## Immediate strengthening plan

Priority 1 — Channel A hardening:
- add continuous availability telemetry with compact daily summaries;
- measure outage count, recovery time, duplicate-process count, task failures, and public-health failures;
- keep a rolling 7-day proof instead of relying only on spot checks;
- alert/quarantine repeated restart loops instead of restarting forever;
- remove deprecated ngrok request-header injection and move authentication to a supported traffic-policy/config mechanism;
- add version pinning and controlled upgrade policy for ngrok and Python dependencies.

Priority 2 — Channel B completion:
- finish the Rescue GPT Action connection;
- verify Bearer authentication from GPT, not only locally;
- test `status`, Primary restart, and log retrieval;
- perform one explicit controlled reboot drill through Rescue;
- document the exact acceptance boundary and rollback.

## Safety

- Never expose token files in repo, logs, chat, screenshots, or migration archives.
- Never run duplicate Primary, Recovery, ngrok, or Rescue processes.
- Never treat local health as proof of public availability.
- Never treat a single smoke test as multi-day stability proof.
- Never update the migration pack from an unproven live state.

Chat context handoff: `chat_context/BRIDGE_BUILD_CHAT_HANDOFF_20260720.md`
## Primary channel continuous monitoring

Live task: EFAB Primary Channel Availability Monitor SYSTEM.

Paths:
- script: C:\ProgramData\EFAB-Bridge-Monitor\sample_primary_channel.ps1`n- raw samples: C:\ProgramData\EFAB-Bridge-Monitor\samples.jsonl`n- rolling summary: C:\ProgramData\EFAB-Bridge-Monitor\daily_summary_latest.json`n
Sampling interval: 1 minute. Window: rolling 7 days. Metrics: availability_percent, outage_count, max_recovery_seconds, duplicate_process_events, task_failure_samples, current_status, maturity. The monitor is observe-only and does not restart or mutate Bridge components.

