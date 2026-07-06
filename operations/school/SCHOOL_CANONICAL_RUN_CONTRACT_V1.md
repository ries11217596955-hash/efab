# School Canonical Run Contract V1

Status: ACTIVE_SINGLE_ENTRYPOINT_THREE_FIELD_LAUNCH

## Owner-facing launch

There is exactly one owner-facing school launch surface:

```text
operations/school/run_agent_school.ps1 -Count <N> -Mode <Test|Live> -TopicsPlan <path-to-json>
```

Fields:

- `Count`: required positive integer, max 1,000,000.
- `Mode`: required enum: `Test` or `Live`.
- `TopicsPlan`: required JSON file that declares curriculum topics, relative weights, verbs, and source modes.

No owner-facing resume fields are allowed. Resume/recovery state is internal.

## Canonical flow

```text
Count + Mode + TopicsPlan
-> candidate factory
-> curriculum validators
-> streaming absorption validation
-> digest pipeline for Live
-> compact memory recall/use proof for Live
-> canonical proof
```

`Mode=Test` creates validated ready-lane curriculum candidates without active memory mutation.

`Mode=Live` consumes factory output through streaming, digest, and recall/use gates. It must not pass from candidate count alone.

## Scaling law

```text
N=30000  -> 6 chunks of 5000 -> 300 batches of 100
N=300000 -> 60 chunks of 5000 -> 3000 batches of 100
```

There must be no separate school for 100, 1000, 5000, 30000, 300000, or any other count.

## Topic plan law

The school must not rely on one hardcoded theme stream for night runs. `TopicsPlan` controls what the school studies and relative topic distribution. Cursor arithmetic controls level continuation inside selected themes.

## Boundary

The factory is local/cursor-guided and does not call Codex CLI/API directly. Codex/material generation is represented by candidate contracts and validators until a dedicated governed Codex-source lane is explicitly wired.

## Lifecycle finalizer law

After a canonical PASS proof is written, the school invokes `operations/school/finalize_agent_school_run_v1.ps1` under `operations/school/school_lifecycle_policy.json`.

The finalizer must keep the owner-facing launch contract unchanged: `Count`, `Mode`, `TopicsPlan` only.

Finalizer duties:

- write a compact runtime finalizer record;
- for policy-allowed PASS runs, write a tracked compact summary under `docs/operations`;
- auto-commit that tracked summary only when the repo was clean before finalization;
- never commit raw `.runtime` files;
- report `FINALIZER_STATUS` in stdout.

Finalizer failure must not convert a valid school PASS into a fake failure, but it must be visible in stdout and runtime finalizer record.
