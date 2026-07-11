$ErrorActionPreference='Stop'
$repoRoot=(git rev-parse --show-toplevel).Trim(); Set-Location $repoRoot
function Assert($Cond,[string]$Msg){ if(-not $Cond){ throw $Msg } }
$reportPath='reports/self_development/ACTIVE_BEHAVIOR_BLOCKED_LIFECYCLE_PASS_V1.json'
$proofPath='tests/self_development/ACTIVE_BEHAVIOR_BLOCKED_LIFECYCLE_PASS_V1_PROOF.json'
$passportPath='self_model/organ_passports/operations_active_behavior/ORGAN_PASSPORT_V1.json'
foreach($p in @($reportPath,$proofPath,$passportPath)){Assert (Test-Path $p) "MISSING:$p"}
$r=Get-Content $reportPath -Raw|ConvertFrom-Json
$proof=Get-Content $proofPath -Raw|ConvertFrom-Json
$p=Get-Content $passportPath -Raw|ConvertFrom-Json
Assert ($r.status -eq 'PASS_ACTIVE_BEHAVIOR_BLOCKED_LIFECYCLE_PASS_V1') 'REPORT_STATUS_BAD'
Assert ($proof.status -eq 'PASS_ACTIVE_BEHAVIOR_BLOCKED_LIFECYCLE_PASS_V1') 'PROOF_STATUS_BAD'
Assert ($proof.lifecycle_decision -eq 'BLOCKED_BY_MISSING_SOURCE_PROOF') 'DECISION_NOT_BLOCKED_BY_SOURCE_PROOF'
Assert ($proof.source_proof_exists -eq $false) 'SOURCE_PROOF_UNEXPECTEDLY_EXISTS'
Assert (-not(Test-Path $proof.missing_source_proof)) 'SOURCE_PROOF_PATH_NOW_EXISTS_RECHECK'
Assert ($p.maturity -eq 'DRAFT') 'PASSPORT_MATURITY_SHOULD_REMAIN_DRAFT'
Assert ($p.live_or_lab_status -eq 'BLOCKED') 'PASSPORT_STATUS_NOT_BLOCKED'
Assert ($proof.promotion_attempted -eq $false) 'PROMOTION_WAS_ATTEMPTED'
Assert ($proof.no_proof_synthesized -eq $true) 'PROOF_SYNTHESIZED_OVERCLAIM'
Assert ($proof.no_passport_active_created -eq $true) 'PASSPORT_ACTIVE_OVERCLAIM'
Assert ($proof.no_live_runtime_touched -eq $true) 'LIVE_TOUCHED_OVERCLAIM'
Assert ($proof.runtime_ready -eq $false) 'RUNTIME_READY_OVERCLAIM'
Assert ($proof.state_change_verified -eq $true) 'STATE_CHANGE_NOT_VERIFIED'
Assert (@($p.proof_refs|Where-Object{$_ -eq $proofPath}).Count -eq 1) 'BLOCKER_PROOF_NOT_ATTACHED'
Write-Host 'VALIDATION_PASS=PASS_ACTIVE_BEHAVIOR_BLOCKED_LIFECYCLE_PASS_V1'
Write-Host 'DECISION=BLOCKED_BY_MISSING_SOURCE_PROOF'
Write-Host 'MATURITY=DRAFT'
Write-Host 'LIVE_OR_LAB_STATUS=BLOCKED'
Write-Host 'PROMOTION_ATTEMPTED=false'
Write-Host 'LIVE_RUNTIME_TOUCHED=false'
