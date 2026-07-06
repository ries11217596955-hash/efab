# Accepted Atom Retention Organ Contract v1

Status: CONTRACT_CANDIDATE
Runtime: DISABLED_UNTIL_IMPLEMENTED
Goal: prevent repo bloat during autonomous atom absorption.

## Problem

Successful atom traces are currently kept as full JSON/report artifacts.
This makes the repo grow without adding live capability.

## Rule

A successful atom is fuel, not archive.

After acceptance:

1. Apply mutation to compact state.
2. Emit compact receipt.
3. Emit batch manifest.
4. Delete successful heavy traces.
5. Preserve full traces only for failed/quarantine/rollback cases.

## Retention Modes

- FullTrace: debug only, small trials only.
- CompactAccepted: default for learning.
- QuarantineTrace: keep full trace only for failed/quarantine.

## Compact Accepted Atom Receipt v1

Required fields:

- schema
- atom_id
- atom_hash
- batch_id
- accepted_utc
- effect_type
- target
- source_ref_hash
- retained_trace
- retained_reason

Full successful candidate payload is forbidden.

## Batch Manifest v1

Required fields:

- schema
- batch_id
- started_utc
- completed_utc
- accepted_count
- failed_count
- quarantined_count
- receipts_hash
- validator_status
- heavy_trace_pruned
- repo_growth_bytes

## Delete after successful batch

- work/current
- cand
- ctrl
- exec
- fin
- before_copies
- rollback_copies
- successful execution reports
- successful full fingerprints
- old checkpoints

## Keep

- compact receipts
- batch manifest
- failed/quarantine traces
- validator summary
- queue pointer
- current compact state

## Passports

### Organ Passport

Name: ACCEPTED_ATOM_RETENTION_ORGAN
Purpose: keep Builder learning bounded in disk and Git size.

### Capability Passport

Capability: compact successful accepted atom into receipt + manifest.

### Sanitizer Passport

Deletes only successful traces after post-validation pass.
Never deletes failed/quarantine/rollback traces.

### Lifecycle Passport

Candidate → validated → accepted → compacted → pruned → committed.

### Proof Passport

Micro-proof must show:

- accepted_count > 0
- failed_count = 0
- heavy_trace_pruned = true
- repo growth bounded
- validator pass
- worktree clean
