param(
  [string]$OutputPath='reports/self_development/CANDIDATE_ACTION_SET_V1.json',
  [string]$EvidencePath='reports/self_development/SOURCE_EVIDENCE_INVENTORY_V1.json'
)
$ErrorActionPreference='Stop'
$RepoRoot=(git rev-parse --show-toplevel).Trim(); Set-Location $RepoRoot
if(-not(Test-Path $EvidencePath)){ & powershell -NoProfile -ExecutionPolicy Bypass -File operations/self_model/export_source_evidence_inventory_v1.ps1 -OutputPath $EvidencePath | Out-Host }
$identity=Get-Content 'self_model/BUILDER_IDENTITY_CONTRACT_V1.json' -Raw|ConvertFrom-Json
$gapMap=Get-Content 'reports/self_development/BUILDER_GAP_MAP_V1.json' -Raw|ConvertFrom-Json
$evidence=Get-Content $EvidencePath -Raw|ConvertFrom-Json
$gaps=@($gapMap.gaps)
$sources=@($evidence.sources)
function SourceHealth($Id){ $s=@($sources|Where-Object{$_.id -eq $Id}|Select-Object -First 1); if($s.Count -eq 0){return 'MISSING'}; return [string]$s[0].health }
$candidates=@()
function Add-Candidate($CandidateId,$Action,$GapId,$Mission,$Kind,$Reason,$ProofNeeded,$ValidatorNeeded,$SourcesUsed,$SourcesRejected,$Fallback,$WhyNotLatest,$DependsOnSchool){
  $row = New-Object PSObject
  $row | Add-Member -NotePropertyName id -NotePropertyValue $CandidateId
  $row | Add-Member -NotePropertyName selected_next_action -NotePropertyValue $Action
  $row | Add-Member -NotePropertyName candidate_kind -NotePropertyValue $Kind
  $row | Add-Member -NotePropertyName identity_alignment -NotePropertyValue 'primary_mission:build_repair_verify_and_improve_self'
  $row | Add-Member -NotePropertyName selected_gap -NotePropertyValue $GapId
  $row | Add-Member -NotePropertyName mission_relevance -NotePropertyValue $Mission
  $row | Add-Member -NotePropertyName reason -NotePropertyValue $Reason
  $row | Add-Member -NotePropertyName proof_needed -NotePropertyValue ([string[]]@($ProofNeeded))
  $row | Add-Member -NotePropertyName validator_needed -NotePropertyValue ([string[]]@($ValidatorNeeded))
  $row | Add-Member -NotePropertyName source_refs_used -NotePropertyValue ([string[]]@($SourcesUsed))
  $row | Add-Member -NotePropertyName source_refs_rejected -NotePropertyValue ([string[]]@($SourcesRejected))
  $row | Add-Member -NotePropertyName why_not_latest_signal -NotePropertyValue $WhyNotLatest
  $row | Add-Member -NotePropertyName fallback_if_source_missing -NotePropertyValue $Fallback
  $row | Add-Member -NotePropertyName depends_on_school -NotePropertyValue ([bool]$DependsOnSchool)
  $row | Add-Member -NotePropertyName status -NotePropertyValue 'CANDIDATE_READY_FOR_SCORING'
  $script:candidates = @($script:candidates) + $row
}
foreach($gap in $gaps){
  switch($gap.id){
    'source_agnostic_path_selector_missing' {
      Add-Candidate 'build_source_agnostic_path_selector_v1' 'build_source_agnostic_path_selector_v1' $gap.id $gap.mission_relevance 'self_build_selector' 'Critical gap blocks V4 identity-based selection; sources must enrich but not command.' @('lab source-agnostic selector proof','negative School missing/stale/failed proof','controlled live AIMO proof later') @('validate_source_agnostic_path_selector_v1','validate_single_source_dependency_negative_cases_v1') @('builder_identity_contract','current_body_capability_snapshot','builder_gap_map','source_evidence_inventory') @('latest_runtime_packets_as_authority','school_as_required_brain','agentlife_residue_as_direction') 'bounded_static_self_build_task_from_gap_map' 'Latest runtime packet is only freshness evidence; this candidate closes the critical Builder gap.' $false
    }
    'builder_mission_scoring_missing' {
      Add-Candidate 'build_builder_mission_scoring_v1' 'build_builder_mission_scoring_v1' $gap.id $gap.mission_relevance 'self_build_scoring' 'A scoring layer is needed before final selection can prefer mission value over freshness.' @('scoring proof JSON') @('validate_builder_mission_scoring_v1') @('builder_identity_contract','builder_gap_map') @('latest_signal_priority_without_scoring') 'choose_critical_gap_order_without_source_dependency' 'Latest signal is not enough until candidate scoring exists.' $false
    }
    'identity_contract_not_wired_into_aimo' {
      Add-Candidate 'wire_builder_identity_contract_into_aimo_lab_v1' 'wire_builder_identity_contract_into_aimo_lab_v1' $gap.id $gap.mission_relevance 'aimo_lab_wiring' 'Identity contract is proven as law but not consumed by AIMO yet.' @('AIMO lab integration proof') @('validate_aimo_identity_contract_integration_v1') @('builder_identity_contract','current_body_capability_snapshot') @('AIMO_current_task_without_identity_contract') 'do_not_hotswap_live_until_lab_pass' 'Latest source cannot wire identity into AIMO.' $false
    }
    'provenance_rejection_trace_missing' {
      Add-Candidate 'add_provenance_and_rejection_trace_v1' 'add_provenance_and_rejection_trace_v1' $gap.id $gap.mission_relevance 'trace' 'Trustworthy selection needs source_refs_used, source_refs_rejected, and why_not_latest_signal.' @('trace proof JSON') @('validate_rejection_trace_non_empty_v1') @('builder_identity_contract','source_evidence_inventory') @('opaque_selection_without_rejection_reasons') 'emit_minimal_identity_gap_reason_when_sources_missing' 'Latest signal may be rejected; rejection reason must be explicit.' $false
    }
    'latest_signal_overfit_negative_tests_missing' {
      Add-Candidate 'add_latest_signal_overfit_negative_tests_v1' 'add_latest_signal_overfit_negative_tests_v1' $gap.id $gap.mission_relevance 'validator' 'V4 requires proof that fresh but low-value source loses to higher Builder gap.' @('negative test proof') @('validate_latest_signal_overfit_rejection_v1') @('builder_gap_map','source_evidence_inventory') @('fresh_agentlife_residue_as_authority') 'use_builder_gap_map_when_latest_signal_low_value' 'Latest signal is intentionally not selected when mission relevance is lower.' $false
    }
    'single_source_dependency_negative_tests_missing' {
      Add-Candidate 'add_single_source_dependency_negative_tests_v1' 'add_single_source_dependency_negative_tests_v1' $gap.id $gap.mission_relevance 'validator' 'Selector must continue without School, AgentLife, or any single packet.' @('missing/stale/failed source proof') @('validate_single_source_dependency_negative_cases_v1') @('source_evidence_inventory','builder_gap_map') @('school_required_for_selection') 'fallback_to_identity_and_gap_map' 'Latest or single source is optional; missing source must not block.' $false
    }
    'child_agent_factory_not_ready_future_blocker' {
      Add-Candidate 'defer_child_agent_factory_until_self_build_selector_proven' 'defer_child_agent_factory_until_self_build_selector_proven' $gap.id $gap.mission_relevance 'defer_secondary' 'Child-agent factory is secondary and must wait for source-agnostic self-build selector proof.' @('future Owner review after V4 slice') @('child_agent_readiness_validator_later') @('builder_identity_contract','builder_gap_map') @('premature_child_agent_jump') 'continue_self_build_selector_slice' 'Latest signal cannot override primary mission maturity gate.' $false
    }
  }
}
if($candidates.Count -lt 1){
  Add-Candidate 'fallback_identity_gap_self_inspection_v1' 'fallback_identity_gap_self_inspection_v1' 'unknown_or_missing_gap_map' 'primary_self_build' 'bounded_fallback' 'No candidate sources were available; use identity and self-inspection fallback.' @('fallback proof JSON') @('validate_bounded_fallback_when_sources_missing_v1') @('builder_identity_contract') @('all_optional_sources_missing') 'bounded_self_inspection_task' 'Latest signal is missing; fallback uses Builder identity.' $false
}
$candidateSet=[ordered]@{
  schema='candidate_action_set_v1'
  status='CANDIDATE_ACTION_SET_EXPORTED'
  route_lock='route_locks/AGENT_BUILDER_NEXT_15_STEPS_LOCK_V4_IDENTITY_BASED_SELECTION.md'
  identity_contract_path='self_model/BUILDER_IDENTITY_CONTRACT_V1.json'
  gap_map_path='reports/self_development/BUILDER_GAP_MAP_V1.json'
  evidence_inventory_path=$EvidencePath
  generator_rule='generate_candidates_from_identity_plus_gap_map_plus_evidence; do_not_score_or_select_in_phase_f'
  candidates=@($candidates)
  candidate_count=@($candidates).Count
  scoring_not_performed=$true
  selection_not_performed=$true
  live_process_touched=$false
  active_memory_mutated=$false
  created_at=(Get-Date).ToString('o')
}
New-Item -ItemType Directory -Force -Path (Split-Path $OutputPath -Parent)|Out-Null
$candidateSet|ConvertTo-Json -Depth 100|Set-Content $OutputPath -Encoding UTF8
Write-Host 'EXPORT_STATUS=CANDIDATE_ACTION_SET_EXPORTED'
Write-Host ('OUTPUT_PATH='+$OutputPath)
Write-Host ('CANDIDATE_COUNT='+@($candidates).Count)
Write-Host 'LIVE_PROCESS_TOUCHED=false'


