# Study Episode Manager V1

Status: ACTIVE_RULE_CANDIDATE

## Purpose

Turn SandboxStudyLife from a loop into closed learning episodes.

Each episode starts with one focus X, runs the permitted learning process, extracts learning residue, classifies the result, closes the episode, and prevents immediate repetition of the same focus.

## Key rules

```text
one active episode at a time
one focus per episode
max 3 source attempts per run / per configured policy
X unresolved -> park once, not spam
failure without residue is waste
failure with learning residue is development
after source budget is exhausted, do no-source reflection instead of open-gap spam
when all configured focuses are already tried, idle without creating gaps
```

## Learning residue

Learning residue records partial understanding or boundary knowledge even when X is not solved.

Examples:

```text
X unresolved, but Y became partially understood
practical X is disabled now, so it belongs to future action lane
source budget is exhausted, so next learning should use existing residue or wait for new focus
```

## Boundary

This manager does not perform practical actions, does not mutate active memory, and does not claim accepted atoms.
