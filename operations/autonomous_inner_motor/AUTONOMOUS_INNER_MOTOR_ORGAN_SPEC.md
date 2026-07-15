# AUTONOMOUS_INNER_MOTOR_ORGAN_SPEC

Status: ACTIVE_CONTRACT_DRAFT_VALIDATED_BY_STATIC_VALIDATOR
Layer: Agent thinking organ / inner motor / no-action phase

## Purpose

The Autonomous Inner Motor is the first serious thinking organ for the agent.

It is not the whole brain, not the executor, and not a new autonomous runner family.

Its job is to make the agent think better before the agent is allowed to act.

```text
observe -> restore context -> use compact memory -> ask known/unknown -> identify gaps -> choose source ladder -> form next_path -> stop at protective checkpoint
```

## No new autonomous runner

No new autonomous runner sprawl is allowed.

There is one runner:

```text
operations/autonomous_inner_motor/run_autonomous_inner_motor.ps1
```

All maturity levels live inside one organ. Maturity levels inside one organ are policy states, not new scripts.

## What the motor can do now

Current phase is thinking-only:

```text
Diagnostic
ReadOnly
SandboxExploration
SandboxTestLife
```

It may read:

```text
repo state
body inventory map
active compact memory manifest/index/cells hashes
living loop reports
School state as an observed learning/control surface
internal library / repo contracts
```

It may produce:

```text
self-question trace
decision trace
memory use trace
unknown/gap list
WEB_RESEARCH_PORT request objects
CODEX_QUESTION_PORT request objects
selected_next_path draft
proof JSON
```

It may not act:

```text
no active memory mutation
no git mutation
no School launch
no Codex launch
no web research execution
no background process
no repo patch
```

## Memory-first thinking

The motor must use compact memory before asking the outside world.

Order:

```text
1. ACTIVE_COMPACT_MEMORY_PORT
2. INTERNAL_LIBRARY_PORT
3. WEB_RESEARCH_PORT request if current/external facts are needed
4. CODEX_QUESTION_PORT request if implementation uncertainty remains
5. VALIDATOR_PORT for proof boundaries
6. ROLLBACK_PORT only as a planned safety route, not execution
```

Compact memory is treated as active semantic memory, not raw archive.

The motor reads memory state and small samples, but never mutates `.runtime/active_compact_semantic_memory_v1` in this phase.

## School teaches

School teaches. School is not the brain.

School may update compact memory through governed absorption runs. The inner motor may read memory after School has taught it. The motor does not launch School in thinking phase.

## External world ports

### WEB_RESEARCH_PORT

The web port is a question/output contract. In thinking phase the motor prepares a web research request object but does not browse by itself.

### CODEX_QUESTION_PORT

The Codex port is a bounded question/output contract. In thinking phase the motor prepares a Codex question pack but does not launch Codex.

Codex is not the brain. Codex is a bounded external reasoner / code analyst that may be asked a precise question when memory and repo context are insufficient.

## Protective checkpoint

Every SandboxExploration must stop with:

```text
PROTECTIVE_CHECKPOINT_THINKING_ONLY
```

No action beyond proof writing is allowed.

## Maturity levels inside one organ

```text
L0 Diagnostic: read static state only.
L1 ReadOnly: read maps/memory/reports, no reasoning loop.
L2 SandboxExploration: multi-cycle thinking proof, no external execution.
L3 SandboxTestLife: simulated life loop, no mutation.
L4 GovernedRepoAction: disabled for now.
L5 LiveAuthority: disabled for now.
```


## Self-directed thinking law

The motor must not wait for Owner questions to think.

Owner can give direction, correction, or authority, but the default thinking loop is self-seeded from:

```text
active compact memory
body inventory map
self-build backlog
living loop state
School proof state
agent catalog / future child-agent direction
```

The first development stage is not action. It is thinking growth:

```text
think better -> choose self-build gap -> prove reasoning -> stop
```

The second stage is governed self-build action. The third stage is child-agent creation.

Child-agent production is not current brain behavior. It is a future output of a Builder that can already self-observe, self-select gaps, validate, repair, and explain proof boundaries.
