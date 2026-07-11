# LIVING LOOP CONTRACT V1

STATUS: CONTRACT_DRAFT_DERIVED_FROM_PROOF / NOT_ACTIVE_RUNTIME / NOT_AUTONOMOUS_LOOP

## 1. Purpose

Living Loop Contract V1 defines the minimum organism cycle for Agent Builder.
It is derived from proven passport lifecycle passes, not from abstract discussion.

The contract turns the organism idea into a bounded behavioral law:

```text
wake -> observe -> restore Body Model -> build Body State -> emit signals -> reason -> decide -> act/block -> verify state change -> memory/reuse -> return-to-parent
```

This contract is not a scheduler, event loop, task runner, or autonomous runtime.
It is a lifecycle law for how any future runtime/brain/wake organ must behave.

## 2. Proof base

This contract is grounded in these lifecycle proofs:

1. `tests/self_development/ORGAN_PROMOTION_LANES_LIFECYCLE_PASS_V1_PROOF.json`
   - `PROMOTE_TO_VALIDATED_LAB_KEEP_NON_ACTIVE`
   - Governance/signal lane pass.

2. `tests/self_development/PARALLEL_LIFE_LIFECYCLE_PASS_V1_PROOF.json`
   - `PROMOTE_TO_VALIDATED_LAB_KEEP_NON_ACTIVE`
   - Lab coordination pass.

3. `tests/self_development/LIVE_LIKE_LIFECYCLE_PASS_V1_PROOF.json`
   - `PROMOTE_TO_VALIDATED_LAB_KEEP_NON_ACTIVE`
   - Live-like observation pass with strict no-live/no-runtime-ready boundary.

4. `tests/self_development/ACTIVE_BEHAVIOR_BLOCKED_LIFECYCLE_PASS_V1_PROOF.json`
   - `BLOCKED_BY_MISSING_SOURCE_PROOF`
   - Blocker pass proving STOP/BLOCK is a valid lifecycle completion.

## 3. Required stages

Every Living Loop cycle MUST pass through these stages:

1. **Wake / stimulus received**
   - Owner command, repo/body change, validator result, runtime signal, stale proof, blocker, route lock, or scheduled self-check.
   - Wake does not imply action.

2. **Observe fresh reality**
   - Confirm repo/root/branch/head/dirty state when repo work is involved.
   - Confirm live/lab boundary.
   - Confirm fresh evidence refs.

3. **Restore Body Model**
   - Read organism anatomy: organs, passports, validators, proof refs, body maps, lifecycle roles.
   - Body Model answers: what exists?
   - Body Model does not decide.

4. **Build Body State**
   - Convert evidence into current state: validated, blocked, stale, missing proof, boundary risk, validator pass/fail.
   - Body State answers: what is happening now?

5. **Emit normalized signals**
   - Evidence must become signal before Brain/decision input.
   - No signal -> no Brain input.
   - Signals must retain evidence refs.

6. **Reason about cause**
   - Separate symptom from root cause.
   - Example: missing report is symptom; missing source proof is root blocker.

7. **Select lawful outcome**
   - Valid outcomes include:
     - `PROMOTE_TO_VALIDATED_LAB_KEEP_NON_ACTIVE`
     - `BLOCKED_BY_MISSING_SOURCE_PROOF`
     - `OWNER_DECISION_REQUIRED`
     - `NO_ACTION_NEEDED`
     - `QUARANTINE_REQUIRED`
     - `REPAIR_REQUIRED`
     - `CONTINUE_PARENT_TASK`
   - Promotion is not the only valid success.

8. **Act or block inside authority**
   - Mutation requires authority, proof boundary, and rollback/quarantine rule.
   - Blocker outcomes must avoid fake proof and avoid hidden mutation.

9. **Verify state change**
   - No action is complete without observed state change.
   - Required forms: validator output, proof JSON, passport/index/map update, runtime heartbeat/stop proof when live involved.

10. **Record memory/reuse**
   - Compact journal/proof references, not raw archive dumps.
   - Learning must be findable and reusable.

11. **Return-to-parent**
   - Update parent state/route with proof and next smallest action.
   - No return-to-parent -> unfinished growth.

## 4. Non-negotiable laws

- No proof -> no claim.
- No validator -> no maturity.
- No signal -> no Brain input.
- No lifecycle role -> not organ.
- No requirement -> no organ.
- No authority -> no mutation.
- No state-change verification -> action unfinished.
- No memory/use proof -> no learning.
- No return-to-parent -> unfinished growth.
- Lab proof != live proof.
- Live-like observation != live readiness.
- Runtime_ready=false must remain explicit.
- PASS can mean correctly blocked, not promoted.
- Missing proof must become Body State, not pressure to synthesize proof.

## 5. Boundary dimensions

A Living Loop decision must keep these dimensions separate:

- observation signal
- validation/maturity state
- proof status
- runtime_ready state
- live readiness state
- authority to mutate
- activation/PASSPORT_ACTIVE state
- autonomous runtime state
- blocker/quarantine state

The live-like lifecycle proof proves why this separation is mandatory:

```text
live-like observation signal != live readiness
lab coordination proof != runtime authority
validated lab != active/passport-active
```

## 6. Accepted lifecycle outcome patterns from proof

### 6.1 Governance signal promotion

From `operations_organ_promotion_lanes`:

```text
body candidates -> lane decisions -> signal contract -> VALIDATED_LAB non-active
```

Lesson:
- Brain must consume normalized lane signals, not raw repo inventory.
- Lane decisions do not accept organs by themselves.

### 6.2 Lab coordination promotion

From `operations_parallel_life`:

```text
lab parallel proof -> signal validator -> passport/index/map state change -> VALIDATED_LAB non-active
```

Lesson:
- Coordination can be proven in lab without claiming runtime/live readiness.

### 6.3 Live-boundary observation promotion

From `operations_live_like`:

```text
live-like observation -> strict non-live boundary -> VALIDATED_LAB non-active
```

Lesson:
- Useful observation signal may be explicitly non-live, non-runtime-ready, non-autonomous.

### 6.4 Blocker completion

From `operations_active_behavior`:

```text
missing source proof -> BLOCKED_BY_MISSING_SOURCE_PROOF -> DRAFT/BLOCKED -> return-to-parent
```

Lesson:
- Correct lifecycle completion may be BLOCKED.
- The organism must stop rather than invent proof.

## 7. Implementation boundary

This contract is not yet:

- active Brain implementation;
- wake/action runtime;
- autonomous loop;
- live process;
- child-agent production rule;
- PASSPORT_ACTIVE grant.

It is a validated behavioral contract derived from proof.

## 8. Next implementation direction

The next safe implementation should be a lab-only Living Loop evaluator that reads proof/passport/index state and emits normalized lifecycle signals, without mutating files unless a separate authority gate approves mutation.
