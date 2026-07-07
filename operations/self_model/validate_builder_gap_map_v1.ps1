$ErrorActionPreference='Stop'
$RepoRoot=(git rev-parse --show-toplevel).Trim(); Set-Location $RepoRoot
function Assert($Cond,[string]$Msg){ if(-not $Cond){ throw $Msg } }
& powershell -NoProfile -ExecutionPolicy Bypass -File operations/self_model/export_builder_gap_map_v1.ps1 | Out-Host
$path='reports/self_development/BUILDER_GAP_MAP_V1.json'
Assert (Test-Path $path) 'GAP_MAP_MISSING'
$j=Get-Content $path -Raw|ConvertFrom-Json
Assert ($j.schema -eq 'builder_gap_map_v1') 'SCHEMA_BAD'
$gaps=@($j.gaps)
Assert ($gaps.Count -ge 6) 'TOO_FEW_GAPS'
foreach($id in @('source_agnostic_path_selector_missing','builder_mission_scoring_missing','identity_contract_not_wired_into_aimo','provenance_rejection_trace_missing','latest_signal_overfit_negative_tests_missing','single_source_dependency_negative_tests_missing','child_agent_factory_not_ready_future_blocker')){ Assert (@($gaps|Where-Object{$_.id -eq $id}).Count -eq 1) "GAP_MISSING:$id" }
foreach($gap in $gaps){
  Assert (-not [string]::IsNullOrWhiteSpace([string]$gap.severity)) "GAP_SEVERITY_MISSING:$($gap.id)"
  Assert (-not [string]::IsNullOrWhiteSpace([string]$gap.mission_relevance)) "GAP_MISSION_MISSING:$($gap.id)"
  Assert (@($gap.proof_needed).Count -ge 1) "GAP_PROOF_NEEDED_MISSING:$($gap.id)"
  Assert (@($gap.validator_needed).Count -ge 1) "GAP_VALIDATOR_NEEDED_MISSING:$($gap.id)"
}
$crit=$gaps|Where-Object{$_.id -eq 'source_agnostic_path_selector_missing'}|Select-Object -First 1
Assert ($crit.severity -eq 'CRITICAL') 'SOURCE_AGNOSTIC_GAP_NOT_CRITICAL'
Assert ($crit.source_dependency_risk -eq $true) 'SOURCE_AGNOSTIC_DEPENDENCY_RISK_BAD'
$child=$gaps|Where-Object{$_.id -eq 'child_agent_factory_not_ready_future_blocker'}|Select-Object -First 1
Assert ($child.mission_relevance -eq 'secondary_child_agent_future') 'CHILD_AGENT_GAP_NOT_SECONDARY'
Assert ($j.next_recommended_phase -eq 'PHASE_E_SOURCE_EVIDENCE_INVENTORY_V1') 'NEXT_PHASE_BAD'
Assert ($j.live_process_touched -eq $false -and $j.active_memory_mutated -eq $false) 'MUTATION_FLAGS_BAD'
$proof=[ordered]@{schema='builder_gap_map_validation_v1';status='PASS_BUILDER_GAP_MAP_V1';gap_map_path=$path;live_process_touched=$false;active_memory_mutated=$false;tests=@([ordered]@{name='required_identity_selection_gaps_present';status='PASS'},[ordered]@{name='each_gap_has_severity_mission_proof_validator';status='PASS'},[ordered]@{name='source_agnostic_gap_is_critical';status='PASS'},[ordered]@{name='child_agent_factory_remains_secondary';status='PASS'});created_at=(Get-Date).ToString('o')}
$proofPath='tests/self_model/BUILDER_GAP_MAP_V1_PROOF.json'
$proof|ConvertTo-Json -Depth 50|Set-Content $proofPath -Encoding UTF8
Write-Host 'VALIDATION_PASS=PASS_BUILDER_GAP_MAP_V1'
Write-Host ('PROOF_PATH='+$proofPath)
Write-Host 'LIVE_PROCESS_TOUCHED=false'
