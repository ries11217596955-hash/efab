# Knowledge Acquisition Port Contract

Status: ACTIVE_CONTRACT_CANDIDATE

Purpose: give AIMO a governed way to ask for missing knowledge when active memory and local sources do not contain executable knowledge for task X.

This port is not a brain, not an authority, and not a route decision-maker. It is a controlled source interface.

## Current source

`CODEX_READONLY_SOURCE` via `codex exec --sandbox read-only --ephemeral`.

Codex output status is always:

```text
CODEX_DRAFT
NOT_PROVEN_UNTIL_VALIDATED
```

## Input contract

- `CurrentTask`: the parent task X.
- `KnowledgeNeed`: the missing knowledge required for X.
- `AlreadyChecked`: compact list of sources already checked.
- `RunId`: proof run identifier.

## Output contract

One compact proof JSON under:

```text
operations/knowledge_acquisition_port/runs/<RunId>/KNOWLEDGE_ACQUISITION_PROOF.json
```

Required fields:

- source = `CODEX_READONLY_SOURCE`
- status
- current_task
- knowledge_need
- already_checked
- codex_answer_status = `CODEX_DRAFT`
- codex_answer_json_valid
- candidate_knowledge
- validation_needed
- return_to_task_hint
- mutation_audit

## Boundaries

- no repo mutation by Codex
- no shell/runtime execution by Codex
- no autonomous route decisions by Codex
- no active memory mutation
- no web/source claims accepted without validation
- agent remains decision-maker
- proof must record exit code and output file hash

## School correction

School is not a query source. If school is active, it owns priority. If school is inactive, it is not available as a knowledge lookup service.

## Acceptance for first layer

- Codex CLI exists.
- Bounded read-only query returns compact answer.
- Repo status remains clean except intended proof/port files before commit.
- Codex output is marked `CODEX_DRAFT`.
- No active memory mutation.
