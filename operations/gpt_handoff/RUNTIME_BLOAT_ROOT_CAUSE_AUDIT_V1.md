# RUNTIME_BLOAT_ROOT_CAUSE_AUDIT_V1

Status: ROOT_CAUSE_IDENTIFIED_NO_PATCH
Created UTC: 2026-07-15T12:53:58.498534+00:00
Branch: main
HEAD: f89a8a7
Origin delta: 0	0

## Human answer

Yes: if we leave the pipeline as-is, every Live School absorption can create new runtime bloat and we will keep cleaning manually.

The bloat is not mainly produced by the School launcher itself. It is produced by the absorption/digest route used when Live School runs with `-Absorb`.

## Root cause

```text
absorb_atom_file_via_digest_pipeline_v1.ps1 creates a per-run candidate copy of active compact memory:
.runtime/file_atom_absorption/<run>/memory_candidate

It digests new atoms into that candidate.
It publishes the candidate into .runtime/active_compact_semantic_memory_v1.
But after successful publish it leaves memory_candidate behind.
```

## Call chain

```text
run_agent_school.ps1 Live
  -> invoke_exact_count_warehouse_cycle_v1.ps1 -Absorb
  -> consume_codex_warehouse_micro_batches_v1.ps1 -Absorb
  -> absorb_atom_file_via_digest_pipeline_v1.ps1
  -> .runtime/file_atom_absorption/<run>/memory_candidate
  -> publish to .runtime/active_compact_semantic_memory_v1
  -> old candidate remains on disk
```

## Evidence

```text
run_agent_school.ps1 line 026: Live exact cycle args add -Absorb
invoke_exact_count_warehouse_cycle_v1.ps1 line 132: passes -Absorb to warehouse consumer
consume_codex_warehouse_micro_batches_v1.ps1 line 060: calls absorb_atom_file_via_digest_pipeline_v1.ps1
absorb_atom_file_via_digest_pipeline_v1.ps1 line 073: runRoot=.runtime/file_atom_absorption/$runId
absorb_atom_file_via_digest_pipeline_v1.ps1 line 087: candidateMemoryRoot=$runRoot/memory_candidate
absorb_atom_file_via_digest_pipeline_v1.ps1 line 094: copies active memory into candidateMemoryRoot
absorb_atom_file_via_digest_pipeline_v1.ps1 line 200: publishes candidateMemoryRoot to active memory
missing: no Remove-Item candidateMemoryRoot after successful publish
```

## Important distinction

```text
active memory is not the trash.
active memory is the protected target.

trash candidate = old successful .runtime/file_atom_absorption/<run>/memory_candidate
protected memory = .runtime/active_compact_semantic_memory_v1
```

## What this means for future School runs

```text
Test mode without Absorb should not create these memory_candidate copies through the exact-count route.
Live mode with Absorb can create one candidate memory copy per consumed micro-batch.
So manual cleanup will repeat unless we patch retention into the pipeline.
```

## Correct fix

Not manual cleanup after every School.

Correct fix:

```text
Patch absorb_atom_file_via_digest_pipeline_v1.ps1:
  after successful publish + proof write,
  delete only its own per-run memory_candidate/staging,
  record removed bytes/hash/proof,
  never touch .runtime/active_compact_semantic_memory_v1,
  never delete reports/proofs,
  keep failed runs for debugging.
```

## Validator needed

```text
After a successful absorption:
  no stale successful memory_candidate remains for that run
  active memory exists and hashes are recorded
  proof/report remains
  failed runs are not erased automatically
```

## Status boundary

```text
ROOT_CAUSE = IDENTIFIED
PATCH = NOT_IMPLEMENTED
ACTIVE_MEMORY = NOT_TOUCHED
REPORTS_PROOFS = NOT_TOUCHED
MANUAL_CLEANUP_REPEAT_RISK = YES_UNTIL_PATCHED
```
