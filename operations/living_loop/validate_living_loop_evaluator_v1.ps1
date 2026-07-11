$ErrorActionPreference='Stop'
$repoRoot=(git rev-parse --show-toplevel).Trim(); Set-Location $repoRoot
function Assert($Cond,[string]$Msg){ if(-not $Cond){ throw $Msg } }
$requirement='contracts/living_loop/LIVING_LOOP_EVALUATOR_V1_REQUIREMENT.md'
$contract='contracts/living_loop/LIVING_LOOP_CONTRACT_V1.json'
$signalsPath='reports/self_development/LIVING_LOOP_EVALUATOR_V1_SIGNALS.json'
$reportPath='reports/self_development/LIVING_LOOP_EVALUATOR_V1_REPORT.json'
$proofPath='tests/self_development/LIVING_LOOP_EVALUATOR_V1_PROOF.json'
foreach($p in @($requirement,$contract,$signalsPath,$reportPath,$proofPath)){Assert (Test-Path $p) "MISSING:$p"}
# Ensure underlying contract still validates.
powershell -ExecutionPolicy Bypass -File operations/living_loop/validate_living_loop_contract_v1.ps1 | Out-Host
Assert ($LASTEXITCODE -eq 0) 'UNDERLYING_CONTRACT_VALIDATION_FAILED'
$sdoc=Get-Content $signalsPath -Raw|ConvertFrom-Json
$r=Get-Content $reportPath -Raw|ConvertFrom-Json
$p=Get-Content $proofPath -Raw|ConvertFrom-Json
Assert ($sdoc.status -eq 'PASS_LIVING_LOOP_EVALUATOR_V1_SIGNALS') 'SIGNALS_STATUS_BAD'
Assert ($r.status -eq 'PASS_LIVING_LOOP_EVALUATOR_V1') 'REPORT_STATUS_BAD'
Assert ($p.status -eq 'PASS_LIVING_LOOP_EVALUATOR_V1') 'PROOF_STATUS_BAD'
$signals=@($sdoc.signals)
Assert (@($signals).Count -ge 7) 'TOO_FEW_SIGNALS'
foreach($sig in $signals){
  foreach($field in @('signal_id','organ_id','signal_type','severity','confidence','lifecycle_decision','body_state','evidence_ref','passport_ref','recommended_outcome','brain_input_allowed','reason')){ Assert ($sig.PSObject.Properties.Name -contains $field) "SIGNAL_FIELD_MISSING:$field" }
  Assert (-not [string]::IsNullOrWhiteSpace([string]$sig.evidence_ref)) "EMPTY_EVIDENCE_REF:$($sig.signal_id)"
  Assert (-not [string]::IsNullOrWhiteSpace([string]$sig.passport_ref)) "EMPTY_PASSPORT_REF:$($sig.signal_id)"
  Assert ($sig.passport_active_created -eq $false) "PASSPORT_ACTIVE_OVERCLAIM:$($sig.signal_id)"
  Assert ($sig.live_runtime_touched -eq $false) "LIVE_TOUCHED_OVERCLAIM:$($sig.signal_id)"
  Assert ($sig.runtime_ready -eq $false) "RUNTIME_READY_OVERCLAIM:$($sig.signal_id)"
  Assert ($sig.live_ready_claim -eq $false) "LIVE_READY_OVERCLAIM:$($sig.signal_id)"
  Assert ($sig.autonomous_runtime -eq $false) "AUTONOMOUS_OVERCLAIM:$($sig.signal_id)"
}
Assert (@($signals|Where-Object{$_.signal_type -eq 'VALIDATED_LAB_NON_ACTIVE_SIGNAL'}).Count -eq 3) 'VALIDATED_SIGNAL_COUNT_BAD'
Assert (@($signals|Where-Object{$_.signal_type -eq 'BLOCKED_MISSING_SOURCE_PROOF_SIGNAL'}).Count -eq 1) 'BLOCKED_SIGNAL_COUNT_BAD'
Assert (@($signals|Where-Object{$_.signal_type -eq 'BOUNDARY_GUARD_SIGNAL'}).Count -ge 2) 'BOUNDARY_GUARD_SIGNAL_COUNT_BAD'
Assert (@($signals|Where-Object{$_.signal_type -eq 'RETURN_TO_PARENT_SIGNAL'}).Count -eq 1) 'RETURN_TO_PARENT_SIGNAL_COUNT_BAD'
Assert ($p.proof_base_count -eq 4) 'PROOF_BASE_COUNT_BAD'
Assert ($p.all_signals_have_evidence_refs -eq $true) 'EVIDENCE_REF_GUARD_BAD'
Assert ($p.all_signals_have_passport_refs -eq $true) 'PASSPORT_REF_GUARD_BAD'
Assert ($p.no_fake_proof -eq $true) 'NO_FAKE_PROOF_GUARD_BAD'
Assert ($p.no_passport_active_created -eq $true) 'PASSPORT_ACTIVE_GUARD_BAD'
Assert ($p.no_live_runtime_touched -eq $true) 'LIVE_RUNTIME_GUARD_BAD'
Assert ($p.runtime_ready_overclaim -eq $false) 'RUNTIME_READY_OVERCLAIM_GUARD_BAD'
Assert ($p.live_ready_overclaim -eq $false) 'LIVE_READY_OVERCLAIM_GUARD_BAD'
Assert ($p.autonomous_runtime_overclaim -eq $false) 'AUTONOMOUS_OVERCLAIM_GUARD_BAD'
Assert ($p.non_mutating_evaluator -eq $true) 'NON_MUTATING_GUARD_BAD'
Write-Host 'VALIDATION_PASS=PASS_LIVING_LOOP_EVALUATOR_V1'
Write-Host "SIGNALS=$(@($signals).Count)"
Write-Host 'VALIDATED_LAB_NON_ACTIVE_SIGNALS=3'
Write-Host 'BLOCKED_SIGNALS=1'
Write-Host 'BOUNDARY_GUARD_SIGNALS>=2'
Write-Host 'RETURN_TO_PARENT_SIGNALS=1'
Write-Host 'NON_MUTATING=true'
