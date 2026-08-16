# Capability Invocation Map V1 Contract

status: ACTIVE_CONTRACT

## Purpose

This contract defines the future canonical map of what Builder can do and exactly how each capability is invoked and validated.

It is not the body/organ inventory map. The body map says what exists. This map says what can be done and how to run it safely.

## Required capability fields

- capability_id
- display_name
- owning_organ_id
- organ_inventory_ref
- what_it_does
- invocation_modes
- primary_invocation
- inputs
- outputs
- validator_refs
- proof_refs
- safety_boundary
- maturity
- live_or_lab_status
- source_task_refs
- source_script_refs
- source_report_refs
- gaps
- do_not_use_for

## Required invocation mode fields

- mode_id
- surface
- command_or_entrypoint
- cwd
- required_args
- optional_args
- preconditions
- expected_outputs
- stop_condition
- rollback_or_cleanup
- proof_after_run

## Maturity levels

- MATERIAL_ONLY
- DRAFT_NORMALIZED
- VALIDATED_LAB
- VALIDATED_LIVE
- DEPRECATED_REFERENCE
- BLOCKED

## Safety rules

- No capability may be marked PROVEN_LIVE without fresh live proof reference.
- No capability may be invokable without validator or explicit NOT_PROVEN/BLOCKED status.
- No child-agent production capability may be marked ready until child-agent readiness validator exists and passes.
- No live mutation command may be listed without cwd, stop condition, rollback/cleanup, and proof_after_run.
- Legacy maps may be source material only, not current authority.

## Next step

Generate a draft `CAPABILITY_INVOCATION_MAP_V1` from current tasks and validators. Missing fields must be recorded as gaps, not guessed.


## Retirement-accounted coverage revision (2026-08-16)

The original V1 contract observed 112 task sources. Three phase84-86 task files were later intentionally retired by governed cleanup commit `cc97c55f6b5754fa1491c2fdb26e6c0357ad5a53`, with proof `tests/self_development/PHASE84_86_OPERATION_RUNTIME_RETIREMENT_AND_DELETE_V1_PROOF.json`.

Coverage therefore preserves **112 as the historical baseline**, while current task coverage is computed from all present `tasks/*.json` files. Any deficit from the historical baseline is acceptable only when every missing historical task is explicitly named by an accepted retirement/decommission proof. Unexplained task loss is a hard blocker. Known current accounting is 109 current + 3 retired = 112 accounted. Retired tasks are legacy provenance only and must not be restored or represented as current tasks.

The contract validator is read-only: it validates this accounting and structural/safety rules but does not require a historical live runtime and does not rewrite tracked proof. Runtime state is not part of contract validity.
