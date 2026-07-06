# REPLAY_AUDIT_POLICY_V1

Status: LAB_IMPLEMENTED
Runtime ready: false

## Purpose

Full replay rebuild is proof, not the hot path. Route-aware absorption may append deltas and update projection quickly, while full replay rebuild is a cold audit.

## Hot path

```text
ready lane → route-aware absorption → incremental delta → inverse rollback → replay ledger append → compatibility projection
```

## Cold audit triggers

```text
force_full_replay=true
crash_recovery=true
incoming_count >= max_incoming_without_replay
deltas_since_last_full_replay >= max_deltas_since_full_replay
before accepted-core/live promotion
before very large batch
```

## Boundary

This policy does not remove replay rebuild. It controls when replay rebuild is required so normal small absorptions do not pay the full rebuild cost every time.