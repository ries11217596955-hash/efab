# Bridge Build Chat Handoff - 2026-07-20

Purpose: restore the operational context of the Bridge work without relying on raw chat history.

## Current source of truth

- Agent repository: H:\efab
- Portable pack: operations/bridge_recovery
- Live Bridge body: H:\bridge
- Operator notebook: operations/bridge_recovery/BRIDGE_OPERATOR_NOTEBOOK.md
- Root notebook: AGENT_BUILDER_SELF_NOTEBOOK.md
- Operator journal: operations/gpt_handoff/GPT_OPERATOR_JOURNAL.md

## Current live architecture

- Local Bridge health: http://127.0.0.1:18787/health
- Public health: https://scabbed-corner-gap.ngrok-free.dev/health
- Supervisor: H:\bridge\efab_resilience_supervisor_v3.ps1
- Keeper: H:\bridge\efab_supervisor_keeper_v1.ps1
- Startup launches both after Windows autologon.
- Supervisor interval: 60 seconds.
- Keeper interval: 120 seconds.
- Failure threshold: two cycles.
- Logs record state changes, recovery actions, and errors only.

## Proven live resilience

- Forced Windows reboot recovery: PROVEN_LIVE.
- Bridge process crash recovery: PROVEN_LIVE.
- Bridge hung-process recovery: PROVEN_LIVE.
- ngrok crash recovery: PROVEN_LIVE.
- Wi-Fi reconnect recovery: PROVEN_LIVE.
- No unnecessary Bridge/ngrok restart during network loss: PROVEN_LIVE.
- Supervisor recovery by keeper: PROVEN_LIVE.
- Keeper recovery by supervisor: PROVEN_LIVE.
- Duplicate lock ownership safety: PROVEN_LIVE.

Representative measured recovery times:

- ngrok crash: about 42.6 seconds.
- Bridge crash: about 35.1 seconds.
- Hung Bridge: about 62.3 seconds.
- Supervisor recovery: about 10.2 seconds.
- Keeper recovery: about 5.1 seconds.
- Forced reboot to full route: about 90 seconds after supervisor start.

## Portability pack v1

Location: operations/bridge_recovery

Contains:

- portable Bridge payload;
- parameterized supervisor and keeper templates;
- install_bridge.ps1;
- recover_bridge.ps1;
- validate_bridge.ps1;
- active manifest;
- checksums;
- compact proofs;
- migration ZIP artifact.

Acceptance boundary on another PC:

- local=true;
- public=true;
- supervisor_alive=true;
- keeper_alive=true;
- validator status=PASS.

Current portability status:

- Pack build: PROVEN_LAB.
- Lab restore: PASS.
- Secret files in pack: 0.
- Embedded Bridge token value: 0.
- Live Bridge mutated by lab build: false.
- Restore on a second physical PC: NOT_PROVEN.

## Secret boundary

Never commit:

- Bridge action token;
- ngrok authtoken or ngrok.yml;
- Windows password or Microsoft account credentials;
- API keys;
- lock files;
- runtime directories;
- raw logs;
- raw ChatGPT export.

Secrets must be provisioned separately on the target PC.

## BIOS and power-loss boundary

The current computer is an HP Pavilion Power Laptop 15-cb0xx with Insyde BIOS F.13.
Automatic power-on after complete AC loss was not configured and remains NOT_PROVEN.
Do not claim physical power-loss recovery until BIOS/UPS behavior is tested.

## Migration procedure

1. Clone H:\efab equivalent repository on the new Windows PC.
2. Read operations/bridge_recovery/BRIDGE_OPERATOR_NOTEBOOK.md.
3. Provision Bridge and ngrok secrets outside Git.
4. Run operations/bridge_recovery/scripts/install_bridge.ps1.
5. Run operations/bridge_recovery/scripts/validate_bridge.ps1.
6. Accept restoration only when validator status is PASS.
7. Update root notebook and operator journal with the second-PC proof.

## Next unresolved work

- Restore and validate on a second Windows PC.
- Add independent external heartbeat/alerting.
- Optionally configure BIOS AC recovery and UPS later.
- Do not add more local watchdog layers unless a fresh failure proves a requirement.

## New-chat recovery instruction

Use this instruction:

Read AGENT_BUILDER_SELF_NOTEBOOK.md, then operations/bridge_recovery/BRIDGE_OPERATOR_NOTEBOOK.md, then operations/bridge_recovery/chat_context/BRIDGE_BUILD_CHAT_HANDOFF_20260720.md. Restore repo, live runtime, proof boundary, and continue from fresh evidence.

Raw chat history is only secondary reference. This handoff and fresh runtime proof are the operational source of truth.