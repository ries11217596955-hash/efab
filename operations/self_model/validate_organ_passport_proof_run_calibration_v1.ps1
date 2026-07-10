$ErrorActionPreference='Stop'
$RepoRoot=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
Set-Location $RepoRoot
function Assert($Cond,[string]$Msg){if(-not $Cond){throw $Msg}}
$reportPath='reports/self_development/ORGAN_PASSPORT_PROOF_RUN_CALIBRATION_V1.json'
$proofPath='tests/self_development/ORGAN_PASSPORT_PROOF_RUN_CALIBRATION_V1_PROOF.json'
foreach($p in @($reportPath,$proofPath)){Assert (Test-Path $p) "MISSING:$p"}
$r=Get-Content $reportPath -Raw|ConvertFrom-Json
$p=Get-Content $proofPath -Raw|ConvertFrom-Json
Assert ($r.status -eq 'PASS_ORGAN_PASSPORT_PROOF_RUN_CALIBRATION_V1') 'REPORT_STATUS_BAD'
Assert ($p.status -eq 'PASS_ORGAN_PASSPORT_PROOF_RUN_CALIBRATION_V1') 'PROOF_STATUS_BAD'
Assert ([int]$r.target_count -eq 9) 'TARGET_COUNT_BAD'
Assert ([int]$p.target_count -eq 9) 'PROOF_TARGET_COUNT_BAD'
Assert ([int]$p.ready_for_lab_validation_count -eq 3) 'READY_COUNT_BAD'
Assert ([int]$p.single_validator_candidate_count -eq 3) 'SINGLE_COUNT_BAD'
$ready=@($p.ready_for_lab_validation_ids)
foreach($id in @('operations_live_start','operations_memory','operations_reasoning')){Assert ($ready -contains $id) "READY_ID_MISSING:$id"}
$by=@{}; foreach($d in @($r.by_decision)){$by[[string]$d.decision]=[int]$d.count}
Assert ($by['READY_FOR_LAB_VALIDATION'] -eq 3) 'READY_BY_DECISION_BAD'
Assert ($by['SINGLE_VALIDATOR_PROOF_NEEDS_SECOND_SURFACE'] -eq 3) 'SINGLE_BY_DECISION_BAD'
Assert ($by['CONTRACT_REFERENCE_NEEDS_EXECUTABLE_VALIDATOR'] -eq 2) 'CONTRACT_BY_DECISION_BAD'
Assert ($by['BLOCKED_OR_TOO_GENERIC'] -eq 1) 'BLOCKED_BY_DECISION_BAD'
Assert ($r.boundaries.proof_run_calibration_only -eq $true) 'BOUNDARY_PROOF_RUN_ONLY_BAD'
Assert ($r.boundaries.no_validated_lab_claim_created -eq $true) 'BOUNDARY_VALIDATED_LAB_BAD'
Assert ($r.boundaries.no_active_passports_created -eq $true) 'BOUNDARY_ACTIVE_BAD'
Assert ($r.boundaries.no_proven_live_claim -eq $true) 'BOUNDARY_LIVE_CLAIM_BAD'
Assert ($r.boundaries.live_process_touched -eq $false) 'BOUNDARY_LIVE_TOUCHED_BAD'
foreach($id in @('operations_live_start','operations_memory','operations_reasoning')){
  $pp=Get-Content "self_model/organ_passports/$id/ORGAN_PASSPORT_V1.json" -Raw|ConvertFrom-Json
  Assert (@($pp.proof_refs).Count -ge 1) "PASSPORT_PROOF_REFS_NOT_ADDED:$id"
  Assert ($pp.live_or_lab_status -ne 'PROVEN_LIVE') "PROVEN_LIVE_FORBIDDEN:$id"
  Assert ($pp.maturity -ne 'VALIDATED_LAB') "VALIDATED_LAB_PREMATURE:$id"
}
Write-Host 'VALIDATION_PASS=PASS_ORGAN_PASSPORT_PROOF_RUN_CALIBRATION_V1'
Write-Host 'READY_FOR_LAB_VALIDATION=operations_live_start,operations_memory,operations_reasoning'
Write-Host "REPORT_PATH=$reportPath"
Write-Host "PROOF_PATH=$proofPath"
