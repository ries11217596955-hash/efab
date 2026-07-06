# STREAMING_SCHOOL_TO_ABSORPTION_PIPELINE_V1

Status: LAB_IMPLEMENTED
Runtime ready: false

## Purpose

Do not wait for the whole TargetAccepted=N run before absorption starts. Every completed school batch can be processed into an absorption lane immediately.

## Flow

```text
candidate batch ready
→ contract validation
→ stream digest
→ per-batch/cumulative quality gate
→ ready lane OR quarantine lane
→ checkpoint
```

## Boundary

This lane does not mutate active memory. It prepares quality-gated material for later active promotion. Active promotion remains separate and must require its own decision-use and scale proof.

## Why this exists

The 699-candidate partial run proved that contract acceptance and digestion are not enough. Some material can still fail scale quality due duplicate topics or generic/placeholder atoms. Streaming absorption must quarantine bad items early instead of blocking or polluting the full run.