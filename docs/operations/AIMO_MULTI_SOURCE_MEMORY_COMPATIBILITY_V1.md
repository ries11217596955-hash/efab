# AIMO Multi-source Memory Compatibility V1

Status: ACTIVE_MINIMAL_COMPATIBILITY

## Purpose

AIMO must be able to continue safe read-only / sandbox life while autonomous school is active. Active school is no longer an absolute hard stop for safe modes.

## Law

```text
School active -> coordination signal, not default denial
AIMO safe mode -> may continue
AIMO memory write -> direct active compact memory write forbidden
AgentLife knowledge -> packet -> intake -> merge queue -> compact memory
Merge queue lock active -> AIMO must back off for memory admission
```

## Current implementation

`operations/autonomous_inner_motor/run_autonomous_inner_motor.ps1` now records `memory_coordination`:

```text
direct_active_memory_write_allowed = false
intake_required_for_agentlife_packets = true
merge_lock_active = <bool>
backoff_required = <bool>
```

When school is active, AIMO emits `school_coordination_hint` instead of `BLOCKED_BY_ACTIVE_SCHOOL` for safe modes.

## Boundary

This does not yet prove full long-running AgentLife parallel with a Live 50k school cycle. V1 proves compatibility semantics: safe modes are not denied merely because school is active, and memory writes remain constrained to intake/merge queue.
## Runtime proof root correction

SandboxTestLife writes live run proofs under `.runtime/autonomous_inner_motor/test_life_runs` so parallel school finalizer does not see repo dirty and block merge queue admission. Tracked compact proof files may be created after the run, outside the concurrent window.
## Knowledge acquisition runtime root correction

AIMO-owned knowledge acquisition source runs must also write under `.runtime/knowledge_acquisition_port/runs`. Otherwise Codex draft proof files can dirty the repo while school finalizer is trying to auto-merge, causing a correct but unwanted `SKIPPED_MERGE_QUEUE_REPO_DIRTY` blocker.
## Source port RunRootBase override

Knowledge source scripts now honor `RunRootBase` from input JSON. AIMO passes `.runtime/knowledge_acquisition_port/runs`, so source-port CODEX_DRAFT proofs do not dirty git while school finalizer is trying to merge. Default source-port root remains the historical operations path unless overridden.