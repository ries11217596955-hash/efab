# AUTHORITY / PREFLIGHT GATE V1 REQUIREMENT

STATUS: REQUIREMENT_DERIVED_FROM_BRAIN_SELECTOR_STUB_V1 / LAB_ONLY / NON_MUTATING / BLOCKING_GATE

## Purpose

Authority / PREFLIGHT Gate V1 reads the Brain Selector Stub intent and determines whether the selected intent may proceed toward a repair preflight.

It is not a repair task.
It does not repair source proof.
It does not execute.
It does not mutate.
It does not grant runtime or live authority.
It does not create PASSPORT_ACTIVE.

Its purpose is to prove that selected Brain intent cannot move toward mutation unless authority, scope, validators, proof expectations, rollback boundary, and stop conditions are explicit.

## Inputs

Required:
- `reports/self_development/BRAIN_SELECTOR_STUB_V1_INTENT.json`
- `tests/self_development/BRAIN_SELECTOR_STUB_V1_PROOF.json`
- `contracts/living_loop/LIVING_LOOP_CONTRACT_V1.json`

Optional future authority input:
- owner repair authorization proof file, not present by default.

## Outputs

Required:
- `reports/self_development/AUTHORITY_PREFLIGHT_GATE_V1_DECISION.json`
- `reports/self_development/AUTHORITY_PREFLIGHT_GATE_V1_REPORT.json`
- `tests/self_development/AUTHORITY_PREFLIGHT_GATE_V1_PROOF.json`

## Required decision states

- `BLOCKED_PREFLIGHT`
- `PREFLIGHT_PASS`

Default expected state for current selected intent:
- `BLOCKED_PREFLIGHT`

## Required blockers when BLOCKED_PREFLIGHT

At minimum:
- `OWNER_REPAIR_AUTHORITY_MISSING`
- `REPAIR_SCOPE_NOT_FORMALIZED_AS_TASK`
- `REPAIR_VALIDATORS_NOT_DECLARED`
- `ROLLBACK_OR_QUARANTINE_BOUNDARY_NOT_DECLARED`
- `NO_FILE_WRITES_ALLOWED_BEFORE_PREFLIGHT_PASS`

## Laws enforced

- No authority -> no mutation.
- No PREFLIGHT_PASS -> no file writes.
- Selected intent is not execution authority.
- Owner decision required cannot be silently assumed.
- Missing source proof cannot be bypassed.
- Repair task must be separate from selector/gate.
- Gate must preserve forbidden actions and evidence refs.

## Acceptance

Validator must prove:
- Brain Selector Stub validates;
- selected intent requires preflight and owner authority;
- gate decision is BLOCKED_PREFLIGHT without owner repair authorization proof;
- blockers are present;
- no files were changed by a repair operation;
- execution_allowed=false;
- mutation_authorized=false;
- preflight_pass=false;
- no live/runtime/autonomous/PASSPORT_ACTIVE overclaim.
