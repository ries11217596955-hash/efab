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
