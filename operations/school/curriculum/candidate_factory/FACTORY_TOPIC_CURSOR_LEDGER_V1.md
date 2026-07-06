# FACTORY_TOPIC_CURSOR_LEDGER_V1

Status: LAB_IMPLEMENTED
Runtime ready: false

## Purpose

The factory must not rely on full duplicate scans as the hot path. It must remember theme progress and generate from cursors:

```text
new theme → level 1
existing theme → last_level + 1
```

## Theme key

```text
theme_key = verb|root|source_mode
```

## Hot path invariants

```text
candidate.topic not in topic_hash_index
candidate.duplicate_key not in duplicate_key_hash_index
candidate.level == theme_cursor.next_level for first candidate on theme in run
candidate.level increments when same theme appears again inside the same run
```

## Cold path

A deep audit can still scan all active atoms, but not on every generation step.

## Boundary

Cursor ledger protects factory generation and hot-path duplicate detection. It does not prove live runtime learning and does not promote active memory.