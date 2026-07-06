# FACTORY_MEMORY_FROM_ACTIVE_ROUTE_V1

Status: LAB_IMPLEMENTED
Runtime ready: false

## Purpose

Candidate factory cursor/index memory must follow the active repo-body route. Once the growth source is `incremental_active_store_v1`, factory generation must not continue from the frozen legacy checkpoint.

## Rule

```text
active route pointer → routed incremental store → factory topic/key indexes + theme cursors
```

## Boundary

This sync updates factory generation memory. It does not absorb atoms and does not prove live runtime use.