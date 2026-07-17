# AGENT_BUILDER_INNATE_REFLEX_KERNEL_V1_PLAN

Status: ROOT_PLAN / READY_FOR_CODEX_TASK
Supersedes as current root growth plan: `AGENT_BUILDER_NEXT_15_STEPS_LOCK_V2_R2.md`
Supersession type: ACTIVE_ROOT_PLAN_REPLACEMENT
Old plan status: ARCHIVE_REFERENCE / DO_NOT_DELETE_WITHOUT_OWNER_DECISION

## 1. Problem

We almost built `BODY_AWARENESS_REFLEX_V1` as a one-off private patch.
That would be wrong.

Owner reminded the core model: the agent is like a newborn organism.
A newborn is young and mostly untrained, but it is not empty.
It has built-in organs and reflexes before learning.

Therefore the Builder must not grow one isolated body-reflex hack.
It must grow an innate reflex layer.

## 2. Goal

Build `INNATE_REFLEX_KERNEL_V1` as a canonical-life layer.

The kernel must make innate reflexes visible in each canonical AIMO life cycle:

```text
agent_life_cycle
→ innate_reflex_kernel
→ reflex matrix
→ active trigger scan
→ allowed response / forbidden response
→ proof boundary
→ optional observe-only hook when a trigger requires it
```

First real reflex:

```text
BODY_AWARENESS_REFLEX_V1
```

Other reflexes must exist as reserved slots, not as fake implementations.

## 3. Core distinction

```text
organ ≠ reflex ≠ learned skill ≠ memory atom
```

- Organ: capability/circuit exists.
- Innate reflex: built-in response pattern available from birth.
- Learned skill: acquired capability from memory/training/use.
- Memory atom: learned compact knowledge, not the source of innate reflex authority.

`BODY_SELF_INSPECTION_CIRCUIT_V1` is an organ.
`BODY_AWARENESS_REFLEX_V1` is the innate reflex that knows the organ can hear the body.

## 4. Required first reflex matrix

The first kernel version must include at least these reflex IDs:

```text
body_awareness_reflex
proof_pain_reflex
confusion_reflex
owner_call_reflex
danger_stop_reflex
repetition_boredom_reflex
memory_hunger_reflex
source_hunger_reflex
sleep_digest_reflex
runtime_pressure_reflex
body_damage_reflex
unknown_gap_reflex
return_to_parent_reflex
quarantine_reflex
self_map_reflex
food_request_reflex
boundary_respect_reflex
validator_need_reflex
```

Only `body_awareness_reflex` is allowed to be implemented as `AVAILABLE_NOT_INVOKED` in this slice.
All other reflexes must be `RESERVED_NOT_BUILT` or equivalent.

## 5. BODY_AWARENESS_REFLEX_V1 contract

Reflex identity:

```text
reflex_id = body_awareness_reflex
innate = true
organ = BODY_SELF_INSPECTION_CIRCUIT_V1
organ_status = KNOWN_ORGAN_AVAILABLE_NOT_WIRED
mode = observe_only
can_hear_body = true
```

Allowed triggers:

```text
selected_frontier == body_self_inspection_signal
self_map_gap detected
body_state_unknown
organ_wiring_audit requests body signal
```

Allowed response:

```text
observe body state
emit body-awareness need/signal
prepare observe-only hook request
queue memory material through governed QueueOnly path only
```

Forbidden response:

```text
repair execution
map mutation
passport mutation
contract mutation
live action
direct active memory write
running body inspection every cycle
using legacy launch surfaces
```

## 6. Canonical life integration requirement

The innate reflex kernel must be visible in canonical AIMO life outputs.

Required canonical proof fields:

```text
innate_reflex_kernel.status
innate_reflex_kernel.reflex_count
innate_reflex_kernel.available_reflexes
innate_reflex_kernel.reserved_reflexes
innate_reflex_kernel.body_awareness_reflex.can_hear_body
innate_reflex_kernel.body_awareness_reflex.organ_id
innate_reflex_kernel.body_awareness_reflex.invoked_this_cycle
innate_reflex_kernel.boundary
```

The first implementation must not invoke body inspection by default.
It must prove that the agent knows the reflex exists in each cycle.

## 7. Relationship to existing artifacts

Must read/use:

```text
operations/autonomous_inner_motor/start_agent_life_v1.ps1
operations/autonomous_inner_motor/run_autonomous_inner_motor.ps1
operations/autonomous_inner_motor/select_agent_next_action_candidate_v1.ps1
operations/autonomous_inner_motor/organ_knowledge/BODY_SELF_INSPECTION_CIRCUIT_V1_KNOWLEDGE.json
operations/autonomous_inner_motor/BODY_SELF_INSPECTION_CANONICAL_INTEGRATION_PLAN_V1.md
operations/autonomous_inner_motor/AGENT_LIFE_LEGACY_LAUNCH_QUARANTINE_V1.json
operations/autonomous_inner_motor/reports/AGENT_LIFE_SINGLE_LAUNCH_WIRING_AUDIT_V1.json
validators/validate_body_self_inspection_organ_knowledge_v1.ps1
validators/validate_agent_life_quarantine_and_body_integration_v1.ps1
validators/validate_agent_life_launcher_v1.ps1
```

Must not replace the canonical launcher.
Owner-facing launch remains:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File operations/autonomous_inner_motor/start_agent_life_v1.ps1 -DurationMinutes <minutes>
```

## 8. Implementation expectation

The implementation should add a kernel/loader and wire it into the runner proof pack.

Expected files may include:

```text
operations/autonomous_inner_motor/innate_reflex_kernel_v1.json
operations/autonomous_inner_motor/build_innate_reflex_kernel_v1.ps1
validators/validate_innate_reflex_kernel_v1.ps1
tests/self_development/INNATE_REFLEX_KERNEL_V1_PROOF.json
```

Optional runtime output:

```text
.runtime/autonomous_inner_motor/<run>/innate_reflex_kernel.json
```

## 9. Acceptance criteria

PASS requires:

```text
kernel exists
18+ reflex slots exist
body_awareness_reflex is innate and available
body_awareness_reflex references BODY_SELF_INSPECTION_CIRCUIT_V1
reserved reflexes are not falsely implemented
canonical runner emits innate_reflex_kernel.json
SANDBOX_EXPLORATION_PROOF includes innate_reflex_kernel
proof pack manifest requires innate_reflex_kernel.json
canonical launcher remains single DurationMinutes interface
legacy launch quarantine remains respected
body inspection is not invoked by default
no live action
no repair execution
no direct active memory write
```

## 10. Non-goals

```text
Do not implement all 18 reflexes.
Do not wire body inspection observe hook yet unless explicitly scoped later.
Do not mutate active memory directly.
Do not execute body repairs.
Do not create child agents.
Do not broaden Owner-facing launch options.
Do not delete the old root plan in this slice.
```

## 11. Next slice after kernel

After `INNATE_REFLEX_KERNEL_V1` is proven, the next slice may be:

```text
BODY_AWARENESS_REFLEX_OBSERVE_HOOK_V1
```

That later slice may invoke body self-inspection observe-only when the reflex trigger is active.
