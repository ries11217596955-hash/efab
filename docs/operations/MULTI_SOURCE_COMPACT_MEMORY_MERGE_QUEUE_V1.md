# Multi-source Compact Memory Merge Queue V1

Status: ACTIVE_MINIMAL_RUNTIME

## Purpose

Multiple sources may submit validated knowledge packets, but no source owns active compact memory. This organ serializes packet merging through a single lock, checkpoint, existing digest/absorption pipeline, and proof.

## Flow

```text
runtime intake queue / explicit packet paths
-> validate each compact_memory_knowledge_packet_v1
-> convert packet atoms to digest atoms
-> create active memory checkpoint
-> acquire MERGE_QUEUE.lock.json
-> run absorb_atom_file_via_digest_pipeline_v1.ps1
-> verify memory hash changed
-> move processed packets
-> write COMPACT_MEMORY_MERGE_QUEUE_RESULT_V1.json
-> remove lock
```

## Boundary

This wrapper does not invent a second memory writer. It uses the existing file atom absorption pipeline. On failure, it restores the checkpoint and reports rollback.

## Not yet solved

- long-running autonomous merge daemon
- concurrent source stress test
- semantic quality scoring beyond packet validation
- promotion of runtime_ready=true