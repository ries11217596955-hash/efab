# Compact Memory Queue Maintenance V1

Status: ACTIVE_MINIMAL_RUNTIME

## Purpose

Process queued knowledge packets after the merge lock is free, without a daemon and without direct active memory mutation.

Default source:

```text
AllowedSourceKinds = AgentLife
```

## Law

```text
School owns active merge priority while school is active.
AgentLife may submit packets during active school.
AgentLife does not merge while school is active.
After lock release, queue maintenance may merge queued AgentLife packets through merge queue.
```

## Boundary

This is synchronous and bounded. It is not an OS scheduler, not a background service, and not a new memory writer. It calls `merge_compact_memory_intake_queue_v1.ps1` for selected queued packets.
## Ordering

Maintenance processes matching packets newest-first. This prioritizes packets produced by the active parallel AgentLife run after school releases merge priority, instead of spending the whole bounded process limit on old backlog.