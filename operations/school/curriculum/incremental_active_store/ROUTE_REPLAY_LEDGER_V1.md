# ROUTE_REPLAY_LEDGER_V1

Status: LAB_IMPLEMENTED
Runtime ready: false

## Purpose

The incremental active route must be rebuildable from committed repo artifacts. A route pointer may use `.runtime` as the physical store, but it must not depend on uncommitted `.runtime` deltas as the only source of truth.

## Contract

```text
legacy frozen checkpoint + committed replay ledger + committed ready lane sources
→ rebuild routed incremental store
→ recover routed active count
```

## Boundary

This is repo-body lab/proof routing. It does not replace live runtime and does not delete the legacy checkpoint.