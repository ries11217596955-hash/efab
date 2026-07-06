# Sandbox Study Life Mode Contract

Status: ACTIVE_RULE_CANDIDATE

## Purpose

`SandboxStudyLife` is intellectual life only. It is not practical action life.

The agent may study Builder-relevant questions, compare memory/docs/source drafts, create compact learning digests, and classify outputs as case patterns, atom candidates, open gaps, or future action-lane items.

## Two categories

### A. Intellectual learning lane

Allowed now:

- ask universal Builder questions
- inspect active memory and allowed repo docs
- ask bounded Codex source as `CODEX_DRAFT`
- use up to 3 progressive source attempts per learning episode
- create compact digest/case pattern candidate
- create atom candidate only if the configured acceptance rules are met
- park unresolved learning gaps and continue life

### B. Future action creation lane

Not enabled now:

- create files as task output
- write new scripts as autonomous action
- create new tools/actions/reflexes/organs by itself
- mutate live/runtime behavior

If a task belongs to this lane, the agent parks it and continues with another intellectual task.

## Non-death rule

Failure to understand or complete X does not stop life.

Flow:

```text
X unresolved
â†’ OPEN_LEARNING_GAP or FUTURE_ACTION_CREATION_LANE
â†’ compact parking record
â†’ continue with Y/Z
â†’ later knowledge may make X easier
```

## Source attempt ladder

Max 3 per episode:

1. `broad_map`: explain X and its parts.
2. `targeted_clarification`: I understood A/B, but D remains unclear.
3. `simple_child_explanation`: explain with minimal primitives, examples, and validation.

## Promotion default

Source draft does not become brain automatically.

Default:

```text
CASE_PATTERN_CANDIDATE
```

Atom candidate requires validation and acceptance rules.
