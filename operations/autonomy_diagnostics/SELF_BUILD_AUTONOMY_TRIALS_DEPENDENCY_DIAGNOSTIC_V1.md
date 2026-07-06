# SELF_BUILD_AUTONOMY_TRIALS_DEPENDENCY_DIAGNOSTIC_V1

Status: BLOCKED_FOR_DELETE_UNTIL_PHASE110_141_RETIREMENT

Target: self_build_batch/autonomy_trials
Tracked files: 144
Tracked bytes: 171958
External ref count: 113
External ref files: 47

External ref groups:
- validators: 27
- modules: 10
- self_build_programs: 4
- packs: 4
- self_control: 2

Conclusion: do not delete self_build_batch/autonomy_trials yet. It is historical proof/output bulk, but still referenced by old phase110-141 validators/modules/packs/self_control/generated programs. First retire or replace that family with canonical Autonomous Inner Motor Micro-Trial validator surface.

External ref files:
- modules/invoke_admitted_action_execution_engine.ps1
- modules/invoke_autonomous_material_decision_stress_lab_001.ps1
- modules/invoke_builder_self_learning_loop_metrics_001.ps1
- modules/invoke_builder_self_pack_author_conveyor_001.ps1
- modules/invoke_builder_self_pack_author_scale_trial_001.ps1
- modules/invoke_material_governance_series_001.ps1
- modules/invoke_material_quarantine_evaluation_runtime_001.ps1
- modules/invoke_review_autonomous_material_decision_stress_results_001.ps1
- modules/invoke_sandbox_branch_merge_decision_001.ps1
- modules/invoke_self_need_detection_engine.ps1
- packs/PHASE110_IDEMPOTENT_AUTONOMY_TRIAL_ONE_CYCLE_SMOKE_V1/APPLY.ps1
- packs/PHASE110_IDEMPOTENT_AUTONOMY_TRIAL_ONE_CYCLE_SMOKE_V1/VALIDATE.ps1
- packs/PHASE115_EXECUTE_BUILDER_QUEUED_ADMITTED_ACTION_V1/APPLY.ps1
- packs/PHASE115_EXECUTE_BUILDER_QUEUED_ADMITTED_ACTION_V1/VALIDATE.ps1
- self_build_programs/generated/PHASE139A_BUILDER_GENERATED_SELF_LEARNING_LOOP_SEED_V1.json
- self_build_programs/generated/PHASE140A_BUILDER_GENERATED_STATE_SYNC_CAPSULE_SEED_V1.json
- self_build_programs/generated/PHASE140B_BUILDER_GENERATED_SELF_LEARNING_METRIC_SEED_V1.json
- self_build_programs/generated/PHASE140C_BUILDER_GENERATED_NEXT_GAP_SELECTOR_SEED_V1.json
- self_control/BUILDER_SELF_PACK_AUTHOR_CONVEYOR_RESULT.json
- self_control/BUILDER_SELF_PACK_AUTHOR_SCALE_TRIAL_RESULT.json
- validators/validate_phase110_idempotent_autonomy_trial_design_v1.ps1
- validators/validate_phase111_self_need_detection_engine_v1.ps1
- validators/validate_phase112_decision_to_action_engine_v1.ps1
- validators/validate_phase113_decision_action_admission_bridge_v1.ps1
- validators/validate_phase114_admitted_action_execution_engine_v1.ps1
- validators/validate_phase117_proof_aware_self_need_engine_v1.ps1
- validators/validate_phase118_self_model_update_engine_v1.ps1
- validators/validate_phase119_self_model_aware_decision_loop_v1.ps1
- validators/validate_phase120_autonomous_loop_controller_v1.ps1
- validators/validate_phase122_controller_aware_self_model_update_v1.ps1
- validators/validate_phase124_self_model_first_runtime_entrypoint_v1.ps1
- validators/validate_phase126_trial_aware_self_model_advance_v1.ps1
- validators/validate_phase127_self_build_operation_contract_v1.ps1
- validators/validate_phase129_operation_contract_aware_self_model_advance_v1.ps1
- validators/validate_phase130_self_build_operation_readiness_gate_v1.ps1
- validators/validate_phase132_operation_trial_aware_self_model_advance_v1.ps1
- validators/validate_phase133_self_build_operation_capability_selector_v1.ps1
- validators/validate_phase134_material_acquisition_bootstrap_v1.ps1
- validators/validate_phase135_manual_material_scout_pass_001_v1.ps1
- validators/validate_phase136_material_governance_series_v1.ps1
- validators/validate_phase137_material_quarantine_evaluation_runtime_v1.ps1
- validators/validate_phase138a_autonomous_material_decision_stress_lab_v1.ps1
- validators/validate_phase138b_review_autonomous_material_decision_stress_results_v1.ps1
- validators/validate_phase138c_sandbox_branch_merge_decision_v1.ps1
- validators/validate_phase139_builder_self_pack_author_conveyor_v1.ps1
- validators/validate_phase140_builder_self_pack_author_scale_trial_v1.ps1
- validators/validate_phase141_builder_self_learning_loop_metrics_v1.ps1

Boundary: read-only diagnostic. No deletion in this pass.
