# ABSORPTION_ROUTE_GUARD_V1

Status: LAB_IMPLEMENTED
Runtime ready: false

## Purpose

There must not be two working hot-path absorption routes. When `ACTIVE_REPO_BODY_ROUTE_POINTER_V1` says `active_source=incremental_active_store_v1`, the legacy full-checkpoint promotion path is blocked.

## Only active entrypoint

```text
absorb_ready_lane_via_active_route_v1.ps1
```

## Rule

```text
if active_source == incremental_active_store_v1:
  use incremental delta + inverse rollback + replay ledger + projection
  block legacy full-checkpoint promote script
```

## Boundary

The legacy script remains in repo only as quarantined historical/rollback material. It is not a hot-path route while incremental active source is active.