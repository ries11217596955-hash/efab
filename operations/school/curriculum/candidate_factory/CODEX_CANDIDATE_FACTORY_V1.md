# CODEX_CANDIDATE_FACTORY_V1

Status: LAB_IMPLEMENTED
Runtime ready: false

## Purpose

Codex must not be the long-running writer for every curriculum candidate. Codex may help design or repair a factory, but the mass production of candidates must be local, deterministic, resumable, and validator-first.

## Contract

```text
Owner input:
  TargetAccepted=N
  RunKind=Test|Real

Factory behavior:
  Test → generate local candidate batches without Codex CLI/API calls
  Real → blocked until live authority passport exists
```

## Flow

```text
TargetAccepted=N
→ local factory generates JSONL candidates in batches of 100
→ contract validator validates each batch
→ aggregate/per-batch consistency validator checks same material
→ streaming absorption lane processes completed batches
→ ready lane / quarantine
```

## Boundary

This factory does not promote active memory. It produces school material only. Absorption and promotion remain separate gates.

## Why this exists

The 5839 Test attempt proved that using Codex as a batch writer burns limits and can hang while producing output. The correct role split is:

```text
Codex = factory/spec designer and repair helper
Local factory = mass candidate producer
School = validator
Agent = streaming absorber and promoter only after proof
```