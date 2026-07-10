$ErrorActionPreference='Stop'
$RepoRoot=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
Set-Location $RepoRoot
function Assert($Cond,[string]$Msg){if(-not $Cond){throw $Msg}}
$reportPath='reports/self_development/OPERATIONS_LIVE_READINESS_LAB_VALIDATION_V1.json'
$proofPath='tests/self_development/OPERATIONS_LIVE_READINESS_LAB_VALIDATION_V1_PROOF.json'
$passportPath='self_model/organ_passports/operations_live_readiness/ORGAN_PASSPORT_V1.json'
foreach($p in @($reportPath,$proofPath,$passportPath)){Assert (Test-Path $p) "MISSING:$p"}
$r=Get-Content $reportPath -Raw|ConvertFrom-Json
$pf=Get-Content $proofPath -Raw|ConvertFrom-Json
$pass=Get-Content $passportPath -Raw|ConvertFrom-Json
Assert ($r.status -eq 'PASS_OPERATIONS_LIVE_READINESS_LAB_VALIDATION_V1') 'REPORT_STATUS_BAD'
Assert ($pf.status -eq 'PASS_OPERATIONS_LIVE_READINESS_LAB_VALIDATION_V1') 'PROOF_STATUS_BAD'
Assert ($pf.organ_id -eq 'operations_live_readiness') 'ORGAN_ID_BAD'
Assert ([int]$pf.validators_passed -eq 5) 'VALIDATORS_PASSED_BAD'
Assert ($pass.organ_id -eq 'operations_live_readiness') 'PASSPORT_ID_BAD'
Assert ($pass.status -eq 'PASSPORT_DRAFT_FROM_EVIDENCE') 'PASSPORT_STATUS_SHOULD_STAY_DRAFT_FROM_EVIDENCE'
Assert ($pass.maturity -eq 'VALIDATED_LAB') 'PASSPORT_MATURITY_NOT_VALIDATED_LAB'
Assert ($pass.live_or_lab_status -eq 'PROVEN_LAB') 'PASSPORT_LAB_STATUS_NOT_PROVEN_LAB'
Assert ($pf.technical_runtime_ready -eq $true) 'TECHNICAL_READY_NOT_TRUE'
Assert ($pf.live_ready -eq $false) 'LIVE_READY_NOT_FALSE'
Assert ($pf.owner_live_authorized -eq $false) 'OWNER_AUTH_NOT_FALSE'
Assert ($pf.live_blocker -eq 'OWNER_LIVE_AUTHORIZATION_MISSING') 'LIVE_BLOCKER_BAD'
Assert ($pf.no_active_passports_created -eq $true) 'ACTIVE_BOUNDARY_BAD'
Assert ($pf.no_proven_live_claim -eq $true) 'PROVEN_LIVE_BOUNDARY_BAD'
Assert ($pf.live_process_touched -eq $false) 'LIVE_PROCESS_TOUCHED_BAD'
Assert ($r.boundaries.lab_validation_only -eq $true) 'LAB_ONLY_BOUNDARY_BAD'
Assert ($r.boundaries.no_active_passports_created -eq $true) 'REPORT_ACTIVE_BOUNDARY_BAD'
Assert ($r.boundaries.no_proven_live_claim -eq $true) 'REPORT_PROVEN_LIVE_BOUNDARY_BAD'
Assert ($r.boundaries.live_ready -eq $false) 'REPORT_LIVE_READY_BAD'
Write-Host 'VALIDATION_PASS=PASS_OPERATIONS_LIVE_READINESS_LAB_VALIDATION_V1'
Write-Host 'PASSPORT_MATURITY=VALIDATED_LAB'
Write-Host 'LIVE_OR_LAB_STATUS=PROVEN_LAB'
Write-Host 'LIVE_READY=false'
Write-Host 'LIVE_BLOCKER=OWNER_LIVE_AUTHORIZATION_MISSING'
Write-Host "REPORT_PATH=$reportPath"
Write-Host "PROOF_PATH=$proofPath"
