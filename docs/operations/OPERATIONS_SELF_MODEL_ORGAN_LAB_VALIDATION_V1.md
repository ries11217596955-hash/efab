# Operations Self-Model Organ Lab Validation V1

status: PASS_OPERATIONS_SELF_MODEL_ORGAN_LAB_VALIDATION_V1

Non-live lab validation passed for `operations_self_model`. This does not create PASSPORT_ACTIVE and does not claim PROVEN_LIVE.

## Passed non-live runset
- operations/self_model/validate_body_map_primary_evidence_rebuild_v1.ps1 => PASS
- operations/self_model/validate_body_map_candidate_triage_v1.ps1 => PASS
- operations/self_model/validate_body_map_triage_promotion_plan_v1.ps1 => PASS
- operations/self_model/validate_legacy_duplicate_map_removal_v1.ps1 => PASS
- operations/self_model/validate_builder_identity_contract_v1.ps1 => PASS
- validators/validate_agent_body_composition_map_current_v1.ps1 => PASS

## Excluded live-dependent validators
- operations/self_model/validate_capability_invocation_map_v1_contract.ps1 => excluded because LIVE_AIMO_COUNT=0 after reboot
- operations/self_model/validate_aimo_default_source_agnostic_selector_contract_v1.ps1 => excluded because LIVE_AIMO_COUNT=0 after reboot
