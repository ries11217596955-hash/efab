# Source answer digest and absorption governance V1

Status: STRATEGY_SUPPORTED / NOT_IMPLEMENTED_AS_VALIDATOR

## Problem

External source answers from Codex/web/library can be useful, but they must not automatically become permanent memory, atoms, reflexes, or organs.

Otherwise the agent becomes heavy:

```text
question -> source answer -> stored forever -> repo/body bloat -> weak active memory
```

## Core rule

```text
SOURCE_ANSWER != ACTIVE_MEMORY
SOURCE_ANSWER != ATOM
SOURCE_ANSWER != REFLEX
SOURCE_ANSWER != ORGAN
```

A source answer is only material.

## Lifecycle

1. `SOURCE_DRAFT` / `CODEX_DRAFT`
2. task use attempt
3. validation/proof
4. classification
5. compact digest
6. optional promotion
7. pruning/archive/reference

## Classification after use

- `TRANSIENT_SOURCE_DRAFT`: useful only for current reasoning; do not keep raw.
- `PROOF_SUPPORT`: keep compact proof link/hash; raw optional if audit requires.
- `CASE_PATTERN`: keep a compact reusable story: task, gap, source, validation, return-to-parent.
- `ACTIVE_MEMORY_CANDIDATE`: general reusable rule, not too specific.
- `ATOM_CANDIDATE`: smallest reusable growth unit with acceptance boundary.
- `REFLEX_CANDIDATE`: repeated bounded behavior that can become deterministic/actionable.
- `ORGAN_MATERIAL`: only if requirement/contract/validator/rollback exist.
- `ARCHIVE_REFERENCE`: old/raw/heavy material kept outside active memory.
- `DELETE_CANDIDATE`: raw/outdated/duplicative material after compact digest exists.

## Default

The default promotion after a successful outside-source use is:

```text
CASE_PATTERN + compact source digest
```

Not atom. Not reflex. Not active memory.

## Promotion rules

### To active memory

Only if the lesson is compact, general, reusable across tasks, and directly helps future decisions.

### To atom

Only if it is a smallest reusable growth unit with acceptance criteria and future composition value.

### To reflex

Only if behavior was repeated, bounded, safe, deterministic enough, and validator/proof exists.

### To organ/module

Only after requirement, contract, authority boundary, validator, rollback/quarantine, and repeated proof.

## Repo/body bloat rule

Raw external answer should not be kept forever by default. Prefer:

```text
raw source -> compact digest -> proof hash/path -> prune or archive raw
```

The agent should carry maps and reusable rules, not books.

## Open implementation direction

Before deeper batch knowledge acquisition, add retention/digest policy for knowledge acquisition runs:

- keep one compact proof
- keep compact source digest
- optionally delete raw Codex last message after proof compaction
- promote only by explicit classification
