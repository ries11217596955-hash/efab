# Multi-source Compact Memory Intake V1

Status: ACTIVE_DESIGN_AND_MINIMAL_RUNTIME

## Purpose

Compact memory must not belong to only school or only autonomous agent life. Multiple sources may produce knowledge, but no source writes directly into active compact memory.

## Sources

Allowed first sources:

- School
- AgentLife
- Codex
- ExternalWorld
- InternalFactory

## Flow

```text
source
-> compact_memory_knowledge_packet_v1
-> validate_compact_memory_packet_v1.ps1
-> submit_compact_memory_packet_v1.ps1
-> runtime queue
-> ACTIVE_GROWTH_SIGNAL
-> path selector chooses path by normal priority/risk/task rules
-> autonomous life uses growth signal only as memory support for the selected path
-> locked/checkpointed compact memory merge remains separate
```

## Growth rule

More and better knowledge must affect autonomous life as execution support, not as route authority. A submitted packet emits a growth signal containing source, topics, declared atom count, maturity delta, focus boosts, and memory_support_policy. AIMO must not let the signal override path selection; it may use the signal after path selection when topics match the selected task/path.

## Boundary

This organ does not yet merge packets into active compact memory. It validates and queues packets, then emits a behavior signal. Active memory mutation remains a separate locked/checkpointed merge action with validator and rollback.