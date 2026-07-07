$ErrorActionPreference='Stop'
$RepoRoot=(git rev-parse --show-toplevel).Trim(); Set-Location $RepoRoot
function Assert($Cond,[string]$Msg){ if(-not $Cond){ throw $Msg } }
$exportEvidence='operations/self_model/export_source_evidence_inventory_v1.ps1'
$exportCandidates='operations/self_model/export_candidate_action_set_v1.ps1'
& powershell -NoProfile -ExecutionPolicy Bypass -File $exportEvidence | Out-Host
& powershell -NoProfile -ExecutionPolicy Bypass -File $exportCandidates | Out-Host
$path='reports/self_development/CANDIDATE_ACTION_SET_V1.json'
Assert (Test-Path $path) 'CANDIDATE_SET_MISSING'
$j=Get-Content $path -Raw|ConvertFrom-Json
Assert ($j.schema -eq 'candidate_action_set_v1') 'SCHEMA_BAD'
Assert ($j.scoring_not_performed -eq $true -and $j.selection_not_performed -eq $true) 'PHASE_F_SCOPE_BAD'
$c=@($j.candidates)
Assert ($c.Count -ge 6) 'TOO_FEW_CANDIDATES'
foreach($id in @('build_source_agnostic_path_selector_v1','build_builder_mission_scoring_v1','wire_builder_identity_contract_into_aimo_lab_v1','add_provenance_and_rejection_trace_v1','add_latest_signal_overfit_negative_tests_v1','add_single_source_dependency_negative_tests_v1','defer_child_agent_factory_until_self_build_selector_proven')){ Assert (@($c|Where-Object{$_.id -eq $id}).Count -eq 1) "CANDIDATE_MISSING:$id" }
foreach($cand in $c){
  foreach($field in @('selected_next_action','identity_alignment','selected_gap','proof_needed','validator_needed','source_refs_used','source_refs_rejected','why_not_latest_signal','fallback_if_source_missing')){ Assert ($cand.PSObject.Properties[$field]) "FIELD_MISSING:$($cand.id):$field" }
  Assert (@($cand.proof_needed).Count -ge 1) "PROOF_NEEDED_EMPTY:$($cand.id)"
  Assert (@($cand.validator_needed).Count -ge 1) "VALIDATOR_NEEDED_EMPTY:$($cand.id)"
  Assert (-not [string]::IsNullOrWhiteSpace([string]$cand.why_not_latest_signal)) "WHY_NOT_LATEST_EMPTY:$($cand.id)"
  Assert ($cand.depends_on_school -eq $false) "CANDIDATE_DEPENDS_ON_SCHOOL:$($cand.id)"
}
$primary=$c|Where-Object{$_.id -eq 'build_source_agnostic_path_selector_v1'}|Select-Object -First 1
Assert ($primary.selected_gap -eq 'source_agnostic_path_selector_missing') 'PRIMARY_CANDIDATE_GAP_BAD'
Assert (@($primary.source_refs_rejected) -contains 'school_as_required_brain') 'PRIMARY_REJECTS_SCHOOL_AS_BRAIN_MISSING'
$missingEvidence='reports/self_development/SOURCE_EVIDENCE_INVENTORY_V1_MISSING_SOURCES_FOR_CANDIDATES_TEST.json'
$missingCandidates='reports/self_development/CANDIDATE_ACTION_SET_V1_MISSING_SOURCES_TEST.json'
& powershell -NoProfile -ExecutionPolicy Bypass -File $exportEvidence -OutputPath $missingEvidence -SimulateSchoolMissing -SimulateRuntimeSourcesMissing | Out-Host
& powershell -NoProfile -ExecutionPolicy Bypass -File $exportCandidates -EvidencePath $missingEvidence -OutputPath $missingCandidates | Out-Host
$m=Get-Content $missingCandidates -Raw|ConvertFrom-Json
$mc=@($m.candidates)
Assert ($mc.Count -ge 1) 'MISSING_SOURCE_CANDIDATES_EMPTY'
Assert (@($mc|Where-Object{$_.mission_relevance -eq 'primary_self_build'}).Count -ge 1) 'NO_PRIMARY_SELF_BUILD_CANDIDATE_WITH_SOURCES_MISSING'
Assert (@($mc|Where-Object{$_.depends_on_school -eq $true}).Count -eq 0) 'MISSING_SOURCE_CANDIDATE_DEPENDS_ON_SCHOOL'
Assert ($m.scoring_not_performed -eq $true -and $m.selection_not_performed -eq $true) 'MISSING_SOURCE_SCOPE_BAD'
Assert ($j.live_process_touched -eq $false -and $j.active_memory_mutated -eq $false) 'MUTATION_FLAGS_BAD'
$proof=[ordered]@{schema='candidate_action_set_validation_v1';status='PASS_CANDIDATE_ACTION_SET_V1';candidate_set_path=$path;missing_sources_candidate_set_path=$missingCandidates;live_process_touched=$false;active_memory_mutated=$false;tests=@([ordered]@{name='candidate_actions_generated_from_gap_map';status='PASS'},[ordered]@{name='required_output_fields_present';status='PASS'},[ordered]@{name='no_candidate_depends_on_school';status='PASS'},[ordered]@{name='missing_sources_still_generate_self_build_candidate';status='PASS'},[ordered]@{name='phase_f_does_not_score_or_select';status='PASS'});created_at=(Get-Date).ToString('o')}
$proofPath='tests/self_model/CANDIDATE_ACTION_SET_V1_PROOF.json'
$proof|ConvertTo-Json -Depth 80|Set-Content $proofPath -Encoding UTF8
Write-Host 'VALIDATION_PASS=PASS_CANDIDATE_ACTION_SET_V1'
Write-Host ('PROOF_PATH='+$proofPath)
Write-Host 'LIVE_PROCESS_TOUCHED=false'
