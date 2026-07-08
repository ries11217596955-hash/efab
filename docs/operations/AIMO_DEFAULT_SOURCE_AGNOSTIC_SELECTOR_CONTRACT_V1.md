# AIMO Default Source-Agnostic Selector Contract V1

status: ACTIVE_CONTRACT
route: AIMO_DEFAULT_SOURCE_AGNOSTIC_SELECTION_V1

## Contract

AIMO default task selection must use Builder identity, body/capability state, gap map, source evidence inventory, candidate actions, mission scoring, and provenance/rejection trace.

The source-agnostic selector must not require the explicit `UseSourceAgnosticPathSelectionLabGate` switch for normal operation after this route succeeds.

## Legacy selector boundary

The legacy School/latest/growth-signal path is not default authority. It may remain only as bounded fallback or diagnostic comparison during transition.

Forbidden as default authority:
- ACTIVE_MEMORY_DELTA_FROM_SCHOOL
- latest_runtime_packet_as_authority
- School_required_for_selection
- AgentLife_residue_as_direction
- child_agent_jump_before_self_build_selector_proven

## Required trace fields
- selected_next_action
- selected_candidate_id
- identity_alignment
- selected_gap
- selected_gap_severity
- proof_needed
- validator_needed
- source_refs_used
- source_refs_rejected
- why_not_latest_signal
- why_not_school_dependency
- fallback_if_source_missing
- selection_rule

## Not proven by this contract
- default_no_gate_lab_selection
- default_no_gate_live_selection
- legacy_selector_demoted_in_code
- explicit_gate_not_required
- child_agent_factory_readiness

## Boundary
This is contract-only. It does not modify AIMO runtime code and does not touch live.
