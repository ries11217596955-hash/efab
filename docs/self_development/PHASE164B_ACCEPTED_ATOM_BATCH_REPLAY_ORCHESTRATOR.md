# PHASE164B Accepted Atom Batch Replay Orchestrator

Purpose:
Create a repeatable replay organ for already accepted, proof-backed atom batches.

This is not external candidate ingestion yet.

Flow:
1. Read active proof-backed atom sources.
2. Hash and replay them in dry-run mode.
3. Validate current accepted route evidence.
4. Produce replay manifest, validation, and report.
5. Do not mutate accepted core.
6. Do not mutate route lock.
7. Do not execute Codex.

Current source layer:
- PHASE163T visibility consume proof
- PHASE164A next locked route selection proof
- PHASE161K V2 PASS route evidence reconciliation proof

Next possible layer:
Owner/material candidate inbox through quarantine, sandbox, validation, proof, and promotion.
