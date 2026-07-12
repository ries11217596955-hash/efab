$ErrorActionPreference='Stop'
$repoRoot=(git rev-parse --show-toplevel).Trim(); Set-Location $repoRoot
function Assert($Cond,[string]$Msg){if(-not $Cond){throw $Msg}}
$passportPath='self_model/organ_passports/operations_active_behavior/ORGAN_PASSPORT_V1.json'
$reportPath='reports/self_development/ACTIVE_BEHAVIOR_FRESH_1000_LIFECYCLE_PASS_V1.json'
$proofPath='tests/self_development/ACTIVE_BEHAVIOR_FRESH_1000_LIFECYCLE_PASS_V1_PROOF.json'
foreach($p in @($passportPath,$reportPath,$proofPath)){Assert (Test-Path $p) "MISSING:$p"}
foreach($v in @('operations/active_behavior/validate_fresh_1000_candidate_behavior_absorption_v1.ps1','operations/active_behavior/validate_active_behavior_absorption_promotion_v1.ps1','operations/active_behavior/validate_active_behavior_task_decision_flow_v1.ps1')){powershell -ExecutionPolicy Bypass -File $v | Out-Host; Assert ($LASTEXITCODE -eq 0) "VALIDATOR_FAILED:$v"}
$pp=Get-Content $passportPath -Raw|ConvertFrom-Json
$r=Get-Content $reportPath -Raw|ConvertFrom-Json
$proof=Get-Content $proofPath -Raw|ConvertFrom-Json
Assert ($r.status -eq 'PASS_ACTIVE_BEHAVIOR_FRESH_1000_LIFECYCLE_PASS_V1') 'REPORT_STATUS_BAD'
Assert ($proof.status -eq 'PASS_ACTIVE_BEHAVIOR_FRESH_1000_LIFECYCLE_PASS_V1') 'PROOF_STATUS_BAD'
Assert ($pp.maturity -eq 'VALIDATED_LAB') 'PASSPORT_MATURITY_BAD'
Assert ($pp.live_or_lab_status -eq 'PROVEN_LAB') 'PASSPORT_LAB_STATUS_BAD'
Assert (@($pp.validators).Count -ge 3) 'VALIDATOR_COUNT_BAD'
Assert (@($pp.proof_refs).Count -ge 5) 'PROOF_REF_COUNT_BAD'
Assert ($proof.fresh_source_proof_pass -eq $true) 'SOURCE_PROOF_NOT_PASS'
Assert ($proof.promotion_pass -eq $true) 'PROMOTION_NOT_PASS'
Assert ($proof.task_decision_flow_pass -eq $true) 'TASK_FLOW_NOT_PASS'
Assert ($proof.state_change_verified -eq $true) 'STATE_CHANGE_NOT_VERIFIED'
Assert ($proof.no_passport_active_created -eq $true) 'PASSPORT_ACTIVE_OVERCLAIM'
Assert ($proof.no_live_runtime_touched -eq $true) 'LIVE_TOUCHED_OVERCLAIM'
Assert ($proof.runtime_ready -eq $false) 'RUNTIME_READY_OVERCLAIM'
Write-Host 'VALIDATION_PASS=PASS_ACTIVE_BEHAVIOR_FRESH_1000_LIFECYCLE_PASS_V1'
Write-Host 'MATURITY=VALIDATED_LAB'
Write-Host 'LIVE_OR_LAB_STATUS=PROVEN_LAB'
Write-Host 'RUNTIME_READY=false'
