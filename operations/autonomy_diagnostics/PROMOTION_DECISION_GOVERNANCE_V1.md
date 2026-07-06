# Promotion decision governance V1

Status: STRATEGY_SUPPORTED / NOT_IMPLEMENTED_AS_ENGINE

## Owner correction

Raw archive is not memory. Archive without retrieval and cleanup is forgotten garbage.

The source/material lifecycle must not be:

```text
use once -> keep raw forever -> maybe archive -> repo grows
```

It must be:

```text
use -> prove -> classify -> choose one: reuse pattern / promote candidate / delete raw / owner decision report
```

## Core rule

A successful process does not automatically become memory, atom, reflex, or organ.

It first becomes a promotion candidate with counters, evidence, and a recommendation.

## Candidate types

- `CASE_PATTERN_CANDIDATE`: reusable scheme for analogous tasks.
- `ACTIVE_MEMORY_CANDIDATE`: compact general rule for future decisions.
- `ATOM_CANDIDATE`: smallest reusable growth unit with acceptance boundary.
- `REFLEX_CANDIDATE`: repeated bounded process likely worth turning into a built-in reflex.
- `ORGAN_CANDIDATE`: repeated capability gap requiring its own contract/validator/authority boundary.
- `DELETE_RAW_CANDIDATE`: raw material already digested and not needed for audit.
- `OWNER_DECISION_REQUIRED`: promotion has architectural consequences.

## Reflex promotion rule

If the agent repeatedly solves X/Y/Z through the same process path, it should not silently hard-code itself.

It should emit a report:

```text
REFLEX_PROMOTION_REQUEST
```

Required fields:

- process_signature
- triggering task family
- repeat_count
- successful_proof_refs
- failed_or_negative_refs
- boundary and forbidden uses
- proposed reflex name
- expected validator
- rollback/quarantine rule
- why this should be reflex instead of case pattern
- owner decision: approve / reject / keep observing

## Organ promotion rule

If repeated work shows a missing capability, the agent should emit:

```text
ORGAN_PROMOTION_REQUEST
```

Required fields:

- capability gap
- tasks blocked or slowed
- why existing organs/reflexes are insufficient
- authority passport needed
- validator needed
- rollback/quarantine boundary
- expected proof path
- owner decision required

## Atom vs case pattern rule

Default after a validated external-source use is `CASE_PATTERN_CANDIDATE`, not atom.

Promote to atom only when the knowledge is:

- small
- reusable
- composable
- acceptance-testable
- useful beyond the single case

Otherwise keep it as a compact case pattern or delete raw after digest.

## No silent growth

The agent may recommend promotion, but should not silently create a reflex, organ, or active atom from one successful task.

Promotion needs report + criteria + proof + owner/validator decision depending on level.

## Anti-bloat rule

Every retained source/proof artifact needs one of:

- active reuse path
- compact case digest
- promotion request
- audit/legal proof need
- delete candidate

No unclassified retention.
