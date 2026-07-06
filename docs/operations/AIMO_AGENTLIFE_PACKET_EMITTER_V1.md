# AIMO AgentLife Packet Emitter V1

Status: ACTIVE_MINIMAL_RUNTIME

## Purpose

After SandboxTestLife completes at least one life cycle, AIMO emits one compact `AgentLife` knowledge packet into the multi-source compact memory intake path.

## Boundary

AIMO does not write active compact memory directly. It creates a packet under `.runtime`, submits it to intake, and merges only through `merge_compact_memory_intake_queue_v1.ps1` when the merge lock is free. If the lock is active, AIMO submits and backs off from merge.

## Runtime safety

AIMO uses a runtime copy of the intake policy with `runtime_report_root = .runtime/compact_memory_intake_v1/reports` so packet submission does not dirty git while school finalizer is running.

## School-active backoff

When AIMO detects active school, the emitter submits the AgentLife packet to intake but does not attempt merge. School owns the current merge priority; AgentLife packet remains queued for later merge. This prevents merge-lock contention between school finalizer and AIMO.