$ErrorActionPreference='Stop'
$repoRoot=(git rev-parse --show-toplevel).Trim(); Set-Location $repoRoot
function Assert($Cond,[string]$Msg){ if(-not $Cond){ throw $Msg } }
$reportPath='reports/self_development/LIVE_LIKE_LIFECYCLE_PASS_V1.json'
$proofPath='tests/self_development/LIVE_LIKE_LIFECYCLE_PASS_V1_PROOF.json'
$passportPath='self_model/organ_passports/operations_live_like/ORGAN_PASSPORT_V1.json'
foreach($p in @($reportPath,$proofPath,$passportPath)){Assert (Test-Path $p) "MISSING:$p"}
$r=Get-Content $reportPath -Raw|ConvertFrom-Json
$proof=Get-Content $proofPath -Raw|ConvertFrom-Json
$p=Get-Content $passportPath -Raw|ConvertFrom-Json
Assert ($r.status -eq 'PASS_LIVE_LIKE_LIFECYCLE_PASS_V1') 'REPORT_STATUS_BAD'
Assert ($proof.status -eq 'PASS_LIVE_LIKE_LIFECYCLE_PASS_V1') 'PROOF_STATUS_BAD'
Assert ($p.maturity -eq 'VALIDATED_LAB') 'PASSPORT_MATURITY_NOT_VALIDATED_LAB'
Assert ($p.live_or_lab_status -eq 'PROVEN_LAB') 'PASSPORT_STATUS_NOT_PROVEN_LAB'
Assert (@($p.validators).Count -eq 2) 'VALIDATOR_COUNT_BAD'
foreach($v in @($p.validators)){ Assert (Test-Path $v) "PASSPORT_VALIDATOR_PATH_MISSING:$v" }
Assert (@($p.validators|Where-Object{$_ -match 'ps1operations'}).Count -eq 0) 'CONCATENATED_VALIDATOR_PATH_REMAINS'
Assert (@($p.proof_refs|Where-Object{$_ -eq $proofPath}).Count -eq 1) 'LIFECYCLE_PROOF_NOT_ATTACHED'
Assert ($proof.no_passport_active_created -eq $true) 'PASSPORT_ACTIVE_OVERCLAIM'
Assert ($proof.no_live_runtime_touched -eq $true) 'LIVE_TOUCHED_OVERCLAIM'
Assert ($proof.runtime_ready -eq $false) 'RUNTIME_READY_OVERCLAIM'
Assert ($proof.live_ready_claim -eq $false) 'LIVE_READY_OVERCLAIM'
Assert ($proof.continuous_autonomous_runtime -eq $false) 'AUTONOMOUS_RUNTIME_OVERCLAIM'
Assert ($proof.state_change_verified -eq $true) 'STATE_CHANGE_NOT_VERIFIED'
Write-Host 'VALIDATION_PASS=PASS_LIVE_LIKE_LIFECYCLE_PASS_V1'
Write-Host 'MATURITY=VALIDATED_LAB'
Write-Host 'LIVE_OR_LAB_STATUS=PROVEN_LAB'
Write-Host 'PASSPORT_ACTIVE_CREATED=false'
Write-Host 'LIVE_RUNTIME_TOUCHED=false'
Write-Host 'RUNTIME_READY=false'
Write-Host 'LIVE_READY=false'
