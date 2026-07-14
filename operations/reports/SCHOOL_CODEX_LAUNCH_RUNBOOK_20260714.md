# SCHOOL_CODEX_LAUNCH_RUNBOOK_20260714

Status: READY_CANONICAL_RECOVERY_RUNBOOK_FROM_JOURNAL

## Human protocol

1. Codex writes bounded campaign material only.
2. GPT/operator validates Codex output.
3. Local candidate factory expands to N candidates.
4. Streaming/staging validates candidates.
5. Digest/absorption is a separate later process.
6. Cleanup happens only after proof and retention decision.

## Recovered successful path from journal

- Slice 1: Codex coverage audit / level plan.
- Slice 2: Codex campaign pack + validator support.
- Operator validation: PowerShell parse, JSONL parse, source paths, duplicate keys, contract consistency.
- 25/100 candidate smoke PASS.
- Then Owner selected 15k as first validation run.

## Current 100k state

- Topic plan exists.
- Compact context exists.
- Two Codex attempts failed/no-output.
- No 100k campaign pack exists.
- 100k generation not started.
- Absorption/digest not started.
- Active memory not mutated.

## Next route

Retry Codex as seed-plan-only/no-shell slice. Codex may output only a seed-plan draft JSON. No shell, no factory, no validation, no source edits. GPT/operator validates and formats/continues after that.

Boundary: this runbook is recovery guidance, not proof that a new campaign pack exists.