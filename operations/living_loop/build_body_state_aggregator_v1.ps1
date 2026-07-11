$ErrorActionPreference='Stop'
$repoRoot=(git rev-parse --show-toplevel).Trim(); Set-Location $repoRoot
function Assert($Cond,[string]$Msg){ if(-not $Cond){ throw $Msg } }
function Write-Json([string]$Path,$Obj,[int]$Depth=100){$dir=Split-Path -Parent $Path;if($dir){New-Item -ItemType Directory -Force -Path $dir|Out-Null};$Obj|ConvertTo-Json -Depth $Depth|Set-Content $Path -Encoding UTF8}
$signalsPath='reports/self_development/LIVING_LOOP_EVALUATOR_V1_SIGNALS.json'
$evaluatorProofPath='tests/self_development/LIVING_LOOP_EVALUATOR_V1_PROOF.json'
$contractPath='contracts/living_loop/LIVING_LOOP_CONTRACT_V1.json'
$indexPath='self_model/organ_passports/_index/ORGAN_PASSPORT_DRAFT_INDEX_V1.json'
$statePath='reports/self_development/BODY_STATE_AGGREGATOR_V1_STATE.json'
$reportPath='reports/self_development/BODY_STATE_AGGREGATOR_V1_REPORT.json'
$proofPath='tests/self_development/BODY_STATE_AGGREGATOR_V1_PROOF.json'
foreach($p in @($signalsPath,$evaluatorProofPath,$contractPath,$indexPath)){Assert (Test-Path $p) "INPUT_MISSING:$p"}
# Validate evaluator first.
powershell -ExecutionPolicy Bypass -File operations/living_loop/validate_living_loop_evaluator_v1.ps1 | Out-Host
Assert ($LASTEXITCODE -eq 0) 'EVALUATOR_VALIDATION_FAILED'
$sdoc=Get-Content $signalsPath -Raw|ConvertFrom-Json
$eproof=Get-Content $evaluatorProofPath -Raw|ConvertFrom-Json
$c=Get-Content $contractPath -Raw|ConvertFrom-Json
$idx=Get-Content $indexPath -Raw|ConvertFrom-Json
Assert ($sdoc.status -eq 'PASS_LIVING_LOOP_EVALUATOR_V1_SIGNALS') 'SIGNALS_STATUS_BAD'
Assert ($eproof.status -eq 'PASS_LIVING_LOOP_EVALUATOR_V1') 'EVALUATOR_PROOF_STATUS_BAD'
$signals=@($sdoc.signals)
Assert ($signals.Count -gt 0) 'NO_SIGNALS'
$buckets=[ordered]@{
  validated_lab_non_active=@()
  blocked=@()
  boundary_guarded=@()
  return_to_parent=@()
  owner_decision_required=@()
  repair_required=@()
  no_action_needed=@()
}
$invalid=@()
foreach($sig in $signals){
  if([string]::IsNullOrWhiteSpace([string]$sig.evidence_ref)){ $invalid += "MISSING_EVIDENCE:$($sig.signal_id)" }
  if([string]::IsNullOrWhiteSpace([string]$sig.passport_ref)){ $invalid += "MISSING_PASSPORT:$($sig.signal_id)" }
  if($sig.passport_active_created -eq $true){ $invalid += "PASSPORT_ACTIVE_OVERCLAIM:$($sig.signal_id)" }
  if($sig.live_runtime_touched -eq $true){ $invalid += "LIVE_TOUCHED_OVERCLAIM:$($sig.signal_id)" }
  if($sig.runtime_ready -eq $true){ $invalid += "RUNTIME_READY_OVERCLAIM:$($sig.signal_id)" }
  if($sig.live_ready_claim -eq $true){ $invalid += "LIVE_READY_OVERCLAIM:$($sig.signal_id)" }
  if($sig.autonomous_runtime -eq $true){ $invalid += "AUTONOMOUS_OVERCLAIM:$($sig.signal_id)" }
  $compact=[ordered]@{signal_id=$sig.signal_id;organ_id=$sig.organ_id;signal_type=$sig.signal_type;severity=$sig.severity;lifecycle_decision=$sig.lifecycle_decision;body_state=$sig.body_state;evidence_ref=$sig.evidence_ref;passport_ref=$sig.passport_ref;recommended_outcome=$sig.recommended_outcome;reason=$sig.reason}
  switch([string]$sig.signal_type){
    'VALIDATED_LAB_NON_ACTIVE_SIGNAL' { $buckets.validated_lab_non_active += $compact; $buckets.no_action_needed += $compact }
    'BLOCKED_MISSING_SOURCE_PROOF_SIGNAL' { $buckets.blocked += $compact; $buckets.repair_required += $compact }
    'BOUNDARY_GUARD_SIGNAL' { $buckets.boundary_guarded += $compact }
    'RETURN_TO_PARENT_SIGNAL' { $buckets.return_to_parent += $compact }
    default { $invalid += "UNKNOWN_SIGNAL_TYPE:$($sig.signal_id):$($sig.signal_type)" }
  }
}
Assert ($invalid.Count -eq 0) ('INVALID_SIGNALS:' + ($invalid -join ';'))
$severityRank=@{critical=4;high=3;medium=2;info=1;low=0}
$highest='info'
foreach($sig in $signals){$sev=[string]$sig.severity;if($severityRank.ContainsKey($sev) -and $severityRank[$sev] -gt $severityRank[$highest]){$highest=$sev}}
$blockedCount=@($buckets.blocked).Count
$boundaryCount=@($buckets.boundary_guarded).Count
$repairCount=@($buckets.repair_required).Count
$recommended= if($blockedCount -gt 0){'REPAIR_BLOCKED_SOURCE_PROOF_OR_KEEP_BLOCKED'}elseif($boundaryCount -gt 0){'PRESERVE_BOUNDARY_AND_OPTIONALLY_BUILD_REASONER'}else{'NO_ACTION_NEEDED_OR_BUILD_REASONER'}
$brainReady=($invalid.Count -eq 0 -and @($signals|Where-Object{$_.brain_input_allowed -ne $true}).Count -eq 0)
$state=[ordered]@{
  schema='body_state_aggregator_v1_state'
  status='PASS_BODY_STATE_AGGREGATOR_V1_STATE'
  source_signals_ref=$signalsPath
  evaluator_proof_ref=$evaluatorProofPath
  contract_ref=$contractPath
  passport_index_ref=$indexPath
  categories=$buckets
  summary=[ordered]@{
    total_signals=$signals.Count
    validated_lab_non_active_count=@($buckets.validated_lab_non_active).Count
    blocked_count=$blockedCount
    boundary_guarded_count=$boundaryCount
    return_to_parent_count=@($buckets.return_to_parent).Count
    owner_decision_required_count=@($buckets.owner_decision_required).Count
    repair_required_count=$repairCount
    no_action_needed_count=@($buckets.no_action_needed).Count
    highest_severity=$highest
    recommended_next_route=$recommended
    brain_input_ready=$brainReady
    mutation_authorized=$false
    runtime_ready=$false
    live_ready=$false
    autonomous_runtime=$false
  }
  created_at=(Get-Date).ToString('o')
}
$report=[ordered]@{
  schema='body_state_aggregator_v1_report'
  status='PASS_BODY_STATE_AGGREGATOR_V1'
  requirement='contracts/living_loop/BODY_STATE_AGGREGATOR_V1_REQUIREMENT.md'
  state_ref=$statePath
  source_signals_ref=$signalsPath
  summary=$state.summary
  laws_enforced=@('No signal -> no Body State','No evidence_ref -> invalid signal','No passport_ref -> invalid signal','Blocked signal remains blocked','Boundary guard signal does not become live readiness','Aggregator is lab-only and non-mutating')
  negative_guards=[ordered]@{no_passport_active_created=$true;no_live_runtime_touched=$true;runtime_ready_overclaim=$false;live_ready_overclaim=$false;autonomous_runtime_overclaim=$false;non_mutating=$true;not_brain=$true;not_execution_authority=$true}
  created_at=(Get-Date).ToString('o')
}
$proof=[ordered]@{
  schema='body_state_aggregator_v1_proof'
  status='PASS_BODY_STATE_AGGREGATOR_V1'
  total_signals=$signals.Count
  validated_lab_non_active_count=@($buckets.validated_lab_non_active).Count
  blocked_count=$blockedCount
  boundary_guarded_count=$boundaryCount
  return_to_parent_count=@($buckets.return_to_parent).Count
  repair_required_count=$repairCount
  no_action_needed_count=@($buckets.no_action_needed).Count
  all_signals_have_evidence_refs=$true
  all_signals_have_passport_refs=$true
  blocked_signal_preserved=($blockedCount -eq 1)
  boundary_guard_signals_preserved=($boundaryCount -ge 2)
  return_to_parent_signal_preserved=(@($buckets.return_to_parent).Count -eq 1)
  brain_input_ready=$brainReady
  mutation_authorized=$false
  no_passport_active_created=$true
  no_live_runtime_touched=$true
  runtime_ready=$false
  live_ready=$false
  autonomous_runtime=$false
  not_brain=$true
  not_execution_authority=$true
  state_ref=$statePath
  report_path=$reportPath
  created_at=(Get-Date).ToString('o')
}
Write-Json $statePath $state 100
Write-Json $reportPath $report 100
Write-Json $proofPath $proof 100
Write-Host 'BUILD_PASS=PASS_BODY_STATE_AGGREGATOR_V1'
Write-Host "TOTAL_SIGNALS=$($signals.Count)"
Write-Host "VALIDATED=$(@($buckets.validated_lab_non_active).Count)"
Write-Host "BLOCKED=$blockedCount"
Write-Host "BOUNDARY_GUARDED=$boundaryCount"
Write-Host "REPAIR_REQUIRED=$repairCount"
Write-Host "RECOMMENDED_NEXT_ROUTE=$recommended"
