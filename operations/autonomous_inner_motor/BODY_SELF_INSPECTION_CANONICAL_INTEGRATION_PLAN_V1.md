# BODY_SELF_INSPECTION_CANONICAL_INTEGRATION_PLAN_V1

Status: INSTALL_READY_PLAN / NOT_WIRED

## Purpose

`BODY_SELF_INSPECTION_CIRCUIT_V1` is proven separately, but current canonical agent life does not invoke it.
This plan defines the safe integration contract before wiring.

## Current canonical launch

Owner-facing launch remains:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File operations/autonomous_inner_motor/start_agent_life_v1.ps1 -DurationMinutes <minutes>
```

No other launch path is Owner-facing.

## Current evidence

- Single-launch wiring audit: `PASS_AGENT_LIFE_SINGLE_LAUNCH_WIRING_AUDIT_V1`.
- Current mental organs are wired into canonical life.
- `BODY_SELF_INSPECTION_CIRCUIT_V1` is `FRONTIER_REFERENCED_NOT_INVOKED`.

## Integration trigger

Canonical AIMO life may invoke body self-inspection only when all are true:

```text
mental_frontier_router.status == PASS_MENTAL_FRONTIER_ROUTER_V1
mental_frontier_router.selected_frontier == body_self_inspection_signal
action_execution_allowed == false
memory_ingestion_mode == QueueOnly
repo dirty state is clean before invocation
no active live/school/aimo conflict process
```

## Integration mode

The invocation must be observe-only:

```text
invoke_body_self_inspection_circuit_v1.ps1
repair_executed = false
parent_action_executed = false
nervous_system_connected = false
live_process_touched = false
active_memory_mutated = false by body inspection itself
```

The canonical AIMO runner may read the body-inspection parent packet/signal and turn it into a queued memory/knowledge packet through the existing governed QueueOnly path.

## Required output contract

When invoked from canonical life, body inspection must produce or expose:

```text
body_self_inspection_signal.json
body_self_inspection_parent_packet.json
BODY_SELF_INSPECTION_CIRCUIT_PROOF.json
```

Canonical life must record:

```text
body_self_inspection_integration_ref
selected_frontier = body_self_inspection_signal
body_inspection_invoked = true
body_inspection_status
body_inspection_signal_ref
body_inspection_parent_packet_ref
boundary flags all false for action/live/repair
```

## Forbidden shortcuts

```text
Do not run body self-inspection on every cycle.
Do not invoke it when selected_frontier is not body_self_inspection_signal.
Do not execute repair drafts from body inspection.
Do not mutate maps/passports/contracts from this integration.
Do not use old legacy launch surfaces to run body inspection as agent life.
```

## Next implementation slice

`BODY_SELF_INSPECTION_CANONICAL_OBSERVE_HOOK_V1`:

```text
router selected body_self_inspection_signal
→ canonical runner invokes body self-inspection circuit observe-only
→ captures signal/parent packet refs
→ queues one compact memory packet about the discovered body/self-map gap
→ does not execute repairs
```
