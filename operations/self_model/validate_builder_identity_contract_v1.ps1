$ErrorActionPreference='Stop'
$RepoRoot=(git rev-parse --show-toplevel).Trim(); Set-Location $RepoRoot
function Assert($Cond,[string]$Msg){ if(-not $Cond){ throw $Msg } }
$path='self_model/BUILDER_IDENTITY_CONTRACT_V1.json'
Assert (Test-Path $path) 'IDENTITY_CONTRACT_MISSING'
$j=Get-Content $path -Raw|ConvertFrom-Json
Assert ($j.schema -eq 'builder_identity_contract_v1') 'SCHEMA_BAD'
Assert ($j.primary_mission -eq 'build_repair_verify_and_improve_self') 'PRIMARY_MISSION_BAD'
Assert ($j.secondary_mission -like 'learn_to_build_child_agents*') 'SECONDARY_MISSION_BAD'
$not=@($j.identity.not_a)
foreach($bad in @('chatbot','tool_wrapper','school_follower','agentlife_follower','latest_signal_follower','external_brain')){ Assert ($not -contains $bad) "MISSING_NOT_A:$bad" }
$order=@($j.selection_doctrine.authority_order)
Assert ($order[0] -eq 'builder_identity_and_mission') 'AUTHORITY_ORDER_NOT_IDENTITY_FIRST'
Assert ($order -contains 'known_gap_map') 'AUTHORITY_ORDER_GAP_MISSING'
Assert ($j.selection_doctrine.latest_signal_policy -eq 'freshness_is_modifier_not_authority') 'LATEST_SIGNAL_POLICY_BAD'
Assert ($j.selection_doctrine.school_policy -eq 'optional_material_source_not_required_brain') 'SCHOOL_POLICY_BAD'
foreach($f in @('selected_next_action','identity_alignment','selected_gap','proof_needed','validator_needed','source_refs_used','source_refs_rejected','why_not_latest_signal','fallback_if_source_missing')){ Assert (@($j.required_output_fields_for_next_step) -contains $f) "REQUIRED_OUTPUT_FIELD_MISSING:$f" }
foreach($p in @('do_not_require_school','do_not_follow_latest_packet_by_default','do_not_promote_agentlife_residue_to_direction')){ Assert (@($j.hard_prohibitions) -contains $p) "HARD_PROHIBITION_MISSING:$p" }
$proof=[ordered]@{schema='builder_identity_contract_validation_v1';status='PASS_BUILDER_IDENTITY_CONTRACT_V1';contract_path=$path;live_process_touched=$false;active_memory_mutated=$false;tests=@([ordered]@{name='identity_not_chatbot_or_source_follower';status='PASS'},[ordered]@{name='mission_self_build_first_child_agents_second';status='PASS'},[ordered]@{name='latest_signal_and_school_not_authority';status='PASS'},[ordered]@{name='next_step_output_contract_present';status='PASS'});created_at=(Get-Date).ToString('o')}
$proofPath='tests/self_model/BUILDER_IDENTITY_CONTRACT_V1_PROOF.json'
$proof|ConvertTo-Json -Depth 50|Set-Content $proofPath -Encoding UTF8
Write-Host 'VALIDATION_PASS=PASS_BUILDER_IDENTITY_CONTRACT_V1'
Write-Host ('PROOF_PATH='+$proofPath)
Write-Host 'LIVE_PROCESS_TOUCHED=false'
