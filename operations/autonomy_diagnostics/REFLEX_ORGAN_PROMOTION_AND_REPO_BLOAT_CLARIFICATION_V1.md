# Reflex, organ promotion, and repo bloat clarification V1

Status: STRATEGY_SUPPORTED / NOT_IMPLEMENTED_AS_ENGINE

## Owner correction: reflex trigger is not only repeat count

A process can become a reflex candidate by two signals:

1. `OBSERVED_REPEAT`: it has worked repeatedly across tasks.
2. `PREDICTED_BREADTH`: after one use, reasoning shows many foreseeable task families would need the same process.

Example: if travel across city A, city B, and inside cities all require the same driving capability, learning to drive may become a reflex candidate before many actual repetitions.

## Reflex rule

The agent should not silently implement a reflex by itself.

It should emit:

```text
REFLEX_PROMOTION_REQUEST
```

The request must include:

- process_signature
- trigger type: `OBSERVED_REPEAT` or `PREDICTED_BREADTH`
- observed proof refs, if any
- predicted task families and count/range
- why case pattern is insufficient
- proposed reflex boundary
- forbidden uses
- validator needed
- owner decision required

## Organ correction

Organ/module promotion should not depend mainly on repeat count.

An organ is needed when task X cannot be done without a capability module, even if X appears once.

Organ candidate trigger:

```text
CAPABILITY_NECESSITY_FOR_TASK_X
```

Required organ request fields:

- task X
- missing capability
- why existing organs/reflexes are insufficient
- authority boundary
- input/output contract
- validator/proof requirement
- rollback/quarantine boundary
- owner decision required

## Atom vs case pattern

A successful lesson becomes atom candidate only if it is small, reusable, composable, and acceptance-testable.

Otherwise default is compact case pattern.

## Repo bloat diagnostic 2026-07-05

Measured repo working directory size:

```text
repo total: 1,866,768,003 bytes
operations/gpt_handoff: 1,671,122,703 bytes
GPT_OPERATOR_JOURNAL.md: 1,671,111,144 bytes
.git: 119,858,390 bytes
.runtime: 66,306,807 bytes
operations/autonomous_inner_motor: 258,652 bytes
operations/knowledge_acquisition_port: 38,056 bytes
```

Root cause: repo bloat is dominated by one huge operator journal file, not the new knowledge acquisition port.

`GPT_OPERATOR_JOURNAL.md` is now too large for normal full-file reads and caused an OutOfMemoryException in PowerShell. It needs journal rotation/compaction policy before adding more append-heavy behavior.
