$ErrorActionPreference='Stop'
$repoRoot=(git rev-parse --show-toplevel).Trim(); Set-Location $repoRoot
function Assert($Cond,[string]$Msg){ if(-not $Cond){ throw $Msg } }
function Write-Json([string]$Path,$Obj,[int]$Depth=100){$dir=Split-Path -Parent $Path;if($dir){New-Item -ItemType Directory -Force -Path $dir|Out-Null};$Obj|ConvertTo-Json -Depth $Depth|Set-Content $Path -Encoding UTF8}
function BoolVal($x){ if($null -eq $x){return $false}; return [bool]$x }
function SignalId([string]$organId,[string]$type){ return ($organId + '__' + $type).ToUpperInvariant() }
$contractPath='contracts/living_loop/LIVING_LOOP_CONTRACT_V1.json'
$indexPath='self_model/organ_passports/_index/ORGAN_PASSPORT_DRAFT_INDEX_V1.json'
$signalsPath='reports/self_development/LIVING_LOOP_EVALUATOR_V1_SIGNALS.json'
$reportPath='reports/self_development/LIVING_LOOP_EVALUATOR_V1_REPORT.json'
$proofPath='tests/self_development/LIVING_LOOP_EVALUATOR_V1_PROOF.json'
Assert (Test-Path $contractPath) 'CONTRACT_MISSING'
Assert (Test-Path $indexPath) 'PASSPORT_INDEX_MISSING'
$c=Get-Content $contractPath -Raw|ConvertFrom-Json
$idx=Get-Content $indexPath -Raw|ConvertFrom-Json
Assert ($c.status -eq 'CONTRACT_DRAFT_DERIVED_FROM_PROOF') 'CONTRACT_STATUS_BAD'
Assert ($c.not_active_runtime -eq $true) 'CONTRACT_ACTIVE_RUNTIME_OVERCLAIM'
$signals=@()
$cases=@()
foreach($pb in @($c.proof_base)){
  Assert (Test-Path $pb.proof) "PROOF_MISSING:$($pb.proof)"
  $p=Get-Content $pb.proof -Raw|ConvertFrom-Json
  $entry=@($idx.entries|Where-Object{$_.organ_id -eq $pb.organ_id}) | Select-Object -First 1
  Assert ($null -ne $entry) "PASSPORT_INDEX_ENTRY_MISSING:$($pb.organ_id)"
  Assert ($p.organ_id -eq $pb.organ_id) "PROOF_ORGAN_MISMATCH:$($pb.proof)"
  Assert ($p.lifecycle_decision -eq $pb.expected_decision) "PROOF_DECISION_MISMATCH:$($pb.proof)"
  Assert ($p.state_change_verified -eq $true) "STATE_CHANGE_NOT_VERIFIED:$($pb.proof)"
  $runtimeReady=BoolVal $p.runtime_ready
  $liveReady=BoolVal $p.live_ready_claim
  $autonomous=BoolVal $p.continuous_autonomous_runtime
  $passportActive= -not (BoolVal $p.no_passport_active_created)
  $liveTouched= -not (BoolVal $p.no_live_runtime_touched)
  $bodyState= if($p.lifecycle_decision -eq 'BLOCKED_BY_MISSING_SOURCE_PROOF'){'DRAFT_BLOCKED'}elseif($entry.maturity -eq 'VALIDATED_LAB' -and $entry.live_or_lab_status -eq 'PROVEN_LAB'){'VALIDATED_LAB_NON_ACTIVE'}else{'OBSERVED_NON_ACTIVE'}
  $signalType= if($p.lifecycle_decision -eq 'BLOCKED_BY_MISSING_SOURCE_PROOF'){'BLOCKED_MISSING_SOURCE_PROOF_SIGNAL'}else{'VALIDATED_LAB_NON_ACTIVE_SIGNAL'}
  $severity= if($signalType -eq 'BLOCKED_MISSING_SOURCE_PROOF_SIGNAL'){'high'}else{'info'}
  $recommended= if($signalType -eq 'BLOCKED_MISSING_SOURCE_PROOF_SIGNAL'){'BLOCK_AND_RETURN_TO_PARENT'}else{'ALLOW_AS_LAB_SIGNAL_NO_ACTIVE_AUTHORITY'}
  $reason= if($signalType -eq 'BLOCKED_MISSING_SOURCE_PROOF_SIGNAL'){'Missing source proof is a Body State blocker; promotion forbidden and fake proof forbidden.'}else{'Lifecycle proof validates lab/non-active state change with no live or active authority.'}
  $signals += [ordered]@{
    signal_id=SignalId $pb.organ_id $signalType
    organ_id=$pb.organ_id
    pattern=$pb.pattern
    signal_type=$signalType
    severity=$severity
    confidence=1.0
    lifecycle_decision=$p.lifecycle_decision
    body_state=$bodyState
    evidence_ref=$pb.proof
    passport_ref=$entry.passport_path
    passport_index_ref=$indexPath
    passport_active_created=$passportActive
    live_runtime_touched=$liveTouched
    runtime_ready=$runtimeReady
    live_ready_claim=$liveReady
    autonomous_runtime=$autonomous
    recommended_outcome=$recommended
    brain_input_allowed=$true
    reason=$reason
  }
  # Boundary guard for any live-like/runtime/lab-sensitive proof.
  if($pb.organ_id -in @('operations_parallel_life','operations_live_like')){
    $signals += [ordered]@{
      signal_id=SignalId $pb.organ_id 'BOUNDARY_GUARD_SIGNAL'
      organ_id=$pb.organ_id
      pattern=$pb.pattern
      signal_type='BOUNDARY_GUARD_SIGNAL'
      severity='high'
      confidence=1.0
      lifecycle_decision=$p.lifecycle_decision
      body_state='BOUNDARY_GUARDED_LAB_ONLY'
      evidence_ref=$pb.proof
      passport_ref=$entry.passport_path
      passport_index_ref=$indexPath
      passport_active_created=$passportActive
      live_runtime_touched=$liveTouched
      runtime_ready=$runtimeReady
      live_ready_claim=$liveReady
      autonomous_runtime=$autonomous
      recommended_outcome='PRESERVE_LAB_ONLY_BOUNDARY'
      brain_input_allowed=$true
      reason='Lab/live/runtime boundaries must remain explicit; observation or coordination signal is not live readiness.'
    }
  }
  $cases += [ordered]@{organ_id=$pb.organ_id;pattern=$pb.pattern;decision=$p.lifecycle_decision;signal_type=$signalType;body_state=$bodyState;evidence_ref=$pb.proof;passport_ref=$entry.passport_path}
}
$signals += [ordered]@{
  signal_id='LIVING_LOOP__RETURN_TO_PARENT_SIGNAL'
  organ_id='living_loop_evaluator_v1'
  pattern='return_to_parent'
  signal_type='RETURN_TO_PARENT_SIGNAL'
  severity='info'
  confidence=1.0
  lifecycle_decision='CONTINUE_PARENT_TASK'
  body_state='EVALUATOR_EMITTED_SIGNALS_FROM_PROOF_BASE'
  evidence_ref=$contractPath
  passport_ref='NOT_A_PASSPORTED_ORGAN_YET'
  passport_index_ref=$indexPath
  passport_active_created=$false
  live_runtime_touched=$false
  runtime_ready=$false
  live_ready_claim=$false
  autonomous_runtime=$false
  recommended_outcome='NEXT_LAB_ONLY_SIGNAL_CONSUMER_OR_BODY_STATE_AGGREGATOR'
  brain_input_allowed=$true
  reason='Evaluator completed proof-to-signal pass and returns normalized state to parent route.'
}
# Negative guard checks before writing proof.
Assert (@($signals|Where-Object{[string]::IsNullOrWhiteSpace([string]$_.evidence_ref)}).Count -eq 0) 'SIGNAL_WITHOUT_EVIDENCE_REF'
Assert (@($signals|Where-Object{$_.passport_active_created -eq $true}).Count -eq 0) 'PASSPORT_ACTIVE_OVERCLAIM_SIGNAL'
Assert (@($signals|Where-Object{$_.live_runtime_touched -eq $true}).Count -eq 0) 'LIVE_TOUCHED_SIGNAL'
Assert (@($signals|Where-Object{$_.runtime_ready -eq $true}).Count -eq 0) 'RUNTIME_READY_OVERCLAIM_SIGNAL'
Assert (@($signals|Where-Object{$_.live_ready_claim -eq $true}).Count -eq 0) 'LIVE_READY_OVERCLAIM_SIGNAL'
Assert (@($signals|Where-Object{$_.autonomous_runtime -eq $true}).Count -eq 0) 'AUTONOMOUS_RUNTIME_OVERCLAIM_SIGNAL'
$signalsDoc=[ordered]@{schema='living_loop_evaluator_v1_signals';status='PASS_LIVING_LOOP_EVALUATOR_V1_SIGNALS';contract_ref=$contractPath;passport_index_ref=$indexPath;signals=$signals;created_at=(Get-Date).ToString('o')}
$counts=[ordered]@{
  total_signals=@($signals).Count
  proof_base_cases=@($cases).Count
  validated_lab_non_active_signals=@($signals|Where-Object{$_.signal_type -eq 'VALIDATED_LAB_NON_ACTIVE_SIGNAL'}).Count
  blocked_missing_source_proof_signals=@($signals|Where-Object{$_.signal_type -eq 'BLOCKED_MISSING_SOURCE_PROOF_SIGNAL'}).Count
  boundary_guard_signals=@($signals|Where-Object{$_.signal_type -eq 'BOUNDARY_GUARD_SIGNAL'}).Count
  return_to_parent_signals=@($signals|Where-Object{$_.signal_type -eq 'RETURN_TO_PARENT_SIGNAL'}).Count
}
$report=[ordered]@{schema='living_loop_evaluator_v1_report';status='PASS_LIVING_LOOP_EVALUATOR_V1';requirement='contracts/living_loop/LIVING_LOOP_EVALUATOR_V1_REQUIREMENT.md';contract_ref=$contractPath;passport_index_ref=$indexPath;signals_ref=$signalsPath;cases=$cases;counts=$counts;negative_guards=[ordered]@{no_fake_proof=$true;no_passport_active_created=$true;no_live_runtime_touched=$true;runtime_ready_overclaim=$false;live_ready_overclaim=$false;autonomous_runtime_overclaim=$false;non_mutating=$true};boundary='LAB_ONLY_SIGNAL_EVALUATOR_NO_PASSPORT_MUTATION_NO_LIVE_RUNTIME';created_at=(Get-Date).ToString('o')}
$proof=[ordered]@{schema='living_loop_evaluator_v1_proof';status='PASS_LIVING_LOOP_EVALUATOR_V1';proof_base_count=@($c.proof_base).Count;signals_emitted=@($signals).Count;validated_lab_non_active_signals=$counts.validated_lab_non_active_signals;blocked_signals=$counts.blocked_missing_source_proof_signals;boundary_guard_signals=$counts.boundary_guard_signals;return_to_parent_signals=$counts.return_to_parent_signals;all_signals_have_evidence_refs=$true;all_signals_have_passport_refs=(@($signals|Where-Object{[string]::IsNullOrWhiteSpace([string]$_.passport_ref)}).Count -eq 0);no_fake_proof=$true;no_passport_active_created=$true;no_live_runtime_touched=$true;runtime_ready_overclaim=$false;live_ready_overclaim=$false;autonomous_runtime_overclaim=$false;non_mutating_evaluator=$true;signals_ref=$signalsPath;report_path=$reportPath;created_at=(Get-Date).ToString('o')}
Write-Json $signalsPath $signalsDoc 100
Write-Json $reportPath $report 100
Write-Json $proofPath $proof 100
Write-Host 'BUILD_PASS=PASS_LIVING_LOOP_EVALUATOR_V1'
Write-Host "SIGNALS=$($counts.total_signals)"
Write-Host "VALIDATED_SIGNALS=$($counts.validated_lab_non_active_signals)"
Write-Host "BLOCKED_SIGNALS=$($counts.blocked_missing_source_proof_signals)"
Write-Host "BOUNDARY_GUARDS=$($counts.boundary_guard_signals)"
Write-Host "REPORT_PATH=$reportPath"
Write-Host "PROOF_PATH=$proofPath"
