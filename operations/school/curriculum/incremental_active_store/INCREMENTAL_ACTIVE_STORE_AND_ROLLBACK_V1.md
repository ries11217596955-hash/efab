# INCREMENTAL_ACTIVE_STORE_AND_ROLLBACK_V1

Status: LAB_IMPLEMENTED
Runtime ready: false

## Problem

The legacy active repo-body checkpoint stores every active atom in one large JSON file. Small absorptions rewrite and snapshot the whole body.

## Goal

Replace hot-path full-state mutation with append/delta storage:

```text
active checkpoint full rewrite → append-only atom chunks
rollback full snapshot → inverse delta
index rebuild → append topic/key index entries
cursor rebuild → update touched cursors only
```

## Boundary

V1 is a parallel lab store in `.runtime/incremental_active_store_v1`. It does not replace the canonical active checkpoint yet and does not prove live runtime use.

## Acceptance

```text
legacy active checkpoint hash unchanged
incoming ready atoms appended as delta
rollback stored as inverse delta, not full snapshot
manifest updated compactly
indexes updated only for incoming topics/keys
cursor updates only for touched themes
proof report records sizes
```