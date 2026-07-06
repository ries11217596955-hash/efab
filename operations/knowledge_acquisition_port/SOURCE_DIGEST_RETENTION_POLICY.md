# Source Digest Retention Policy V1

Status: ACTIVE_RULE_CANDIDATE

## Rule

External answers are source drafts, not active memory.

Successful knowledge acquisition must end as compact structured proof plus digest/promotion decision.

Raw source text is not retained by default.

## Default retention

After successful `PASS_CODEX_DRAFT_RETURNED`:

- keep `KNOWLEDGE_ACQUISITION_PROOF.json`
- keep `SOURCE_DIGEST_AND_PROMOTION_DECISION.json`
- delete `codex_last_message.json.txt` unless explicit audit retention is enabled

## Promotion default

Default classification is:

```text
CASE_PATTERN_CANDIDATE
DELETE_RAW_CANDIDATE
```

Not atom. Not reflex. Not organ.

## Promotion escalation

- `ACTIVE_MEMORY_CANDIDATE`: only compact general reusable decision rule.
- `ATOM_CANDIDATE`: small, composable, acceptance-testable unit.
- `REFLEX_CANDIDATE`: observed repeat or predicted breadth plus boundary/validator request.
- `ORGAN_CANDIDATE`: capability necessity for task X plus contract/validator/authority request.
- `OWNER_DECISION_REQUIRED`: any silent self-growth beyond case pattern is forbidden.
