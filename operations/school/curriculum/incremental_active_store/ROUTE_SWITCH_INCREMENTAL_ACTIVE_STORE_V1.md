# ROUTE_SWITCH_INCREMENTAL_ACTIVE_STORE_V1

Status: LAB_IMPLEMENTED
Runtime ready: false

## Purpose

Future repo-body absorptions must stop using the legacy full checkpoint as the hot-path active store. The active route pointer must identify the incremental active store as the growth route while keeping the legacy checkpoint frozen as bootstrap/compatibility material.

## Route pointer

```text
operations/school/curriculum/incremental_active_store/ACTIVE_REPO_BODY_ROUTE_POINTER_V1.json
```

## Contract

```text
legacy checkpoint remains unchanged
incremental store is initialized/rebuildable from legacy checkpoint
future delta absorptions append to incremental store
rollback is inverse delta
compatibility projection reports active count without writing a full checkpoint
```

## Boundary

V1 does not delete the legacy checkpoint and does not prove live runtime use. It switches the repo-body growth route in lab/proof space and prepares old validators for compatibility projection.