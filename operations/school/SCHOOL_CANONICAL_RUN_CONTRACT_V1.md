# School Canonical Run Contract V1

Status: ACTIVE_SINGLE_ENTRYPOINT_TWO_FIELD_LAUNCH

## Owner-facing launch

There is exactly one owner-facing school launch surface:

```text
operations/school/run_agent_school.ps1 -Count <N> -Mode <Test|Live>
```

Fields:

- `Count`: required positive integer, max 1,000,000.
- `Mode`: required enum: `Test` or `Live`.
- Internal canonical topics plan: `operations/school/curriculum/topics/builder_night_school_topics_v1.json`. This is not an Owner launch field.

No owner-facing resume fields are allowed. Resume/recovery state is internal.

## Canonical flow

```text
Count + Mode
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

The school uses the internal canonical topics plan to control what it studies and relative topic distribution. Cursor arithmetic controls level continuation inside selected themes. Owner does not pass `TopicsPlan` at launch.

## Boundary

The factory is local/cursor-guided and does not call Codex CLI/API directly. Codex/material generation is represented by candidate contracts and validators until a dedicated governed Codex-source lane is explicitly wired.

## Lifecycle finalizer law

After a canonical PASS proof is written, the school invokes `operations/school/finalize_agent_school_run_v1.ps1` under `operations/school/school_lifecycle_policy.json`.

The finalizer must keep the owner-facing launch contract unchanged: `Count`, `Mode` only.

Finalizer duties:

- write a compact runtime finalizer record;
- for policy-allowed PASS runs, write a tracked compact summary under `docs/operations`;
- auto-commit that tracked summary only when the repo was clean before finalization;
- never commit raw `.runtime` files;
- report `FINALIZER_STATUS` in stdout.

Finalizer failure must not convert a valid school PASS into a fake failure, but it must be visible in stdout and runtime finalizer record.

## Internal helper surfaces

Owner-facing launch surface remains exactly one: `operations/school/run_agent_school.ps1`. Owner-facing launch fields are exactly two: `Count` and `Mode`.

Internal school launch/helper surfaces are allowed when they are called by the canonical entrypoint/controller and are not presented as separate owner-facing schools. This includes source router ports, candidate factory, streaming absorption, ready lane, digest/memory helpers, finalizer, and the autonomous school cycle controller.

`Mode=Live` is school-live / memory-digestion mode. It may update compact semantic memory through the school digest/merge gates, but it is not agent runtime, not OS/live process authority, and not autonomous AgentLife.

No extra owner prompt/request is required when the canonical policy validator passes and the Owner has authorized school `Mode=Live` for the active school entrypoint.

## Long max run detached launch protocol

For `Count=1000000` / long `Mode=Live` runs, use the canonical entrypoint through a detached wrapper that records runtime control metadata. This does not create a second school surface; it is only process control around the canonical entrypoint.

Required preflight:

```text
cwd/root = H:\efab
git status clean or explicitly accepted
HEAD synced with origin/main
no existing school/finalizer/digest/queue-maintenance/merge process
active compact memory manifest exists
canonical validator PASS
```

Required detached runtime outputs:

```text
.runtime/school_long_runs/<run_id>/launch.json
.runtime/school_long_runs/<run_id>/stdout.txt
.runtime/school_long_runs/<run_id>/stderr.txt
```

Launch metadata must include:

```text
run_id
pid
count
mode
entrypoint
git head
stdout/stderr paths
boundary = school-live compact-memory digestion mode; not AgentLife runtime; not Codex
```

Correct max launch target:

```text
operations/school/run_agent_school.ps1 -Count 1000000 -Mode Live
```

Do not claim full completion until:

```text
process exited cleanly
canonical proof status is PASS_REAL_FACTORY_DIGEST_RECALL_USE_V1
ready/merged/behavior_delta fields are checked
finalizer status is checked separately
no school-related process remains
```

Do not clean active `.runtime` surfaces while the process is alive.


## 2026-07-14 two-field correction

Owner-facing school launch has exactly two fields:

```text
Count
Mode = Test | Live
```

`TopicsPlan` is internal canonical configuration:

```text
operations/school/curriculum/topics/builder_night_school_topics_v1.json
```

Do not present candidate factory, streaming, digest, source router, Codex source ports, autonomous cycle controller, or TopicsPlan as separate Owner launch routes. They are internal organs/helpers called under the canonical entrypoint.

School completion means compact memory update proof exists. If compact memory is not updated, the school run is not complete; it is blocked/failed/pending.
