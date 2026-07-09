$ErrorActionPreference='Stop'
$RepoRoot=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
Set-Location $RepoRoot
function Assert($Cond,[string]$Msg){ if(-not $Cond){ throw $Msg } }
function CountOf($x){ return @($x).Count }
$reportPath='reports/self_development/ACCEPTED_ATOM_RETENTION_ORGAN_CALIBRATION_V1.json'
$proofPath='tests/self_development/ACCEPTED_ATOM_RETENTION_ORGAN_CALIBRATION_V1_PROOF.json'
$passportPath='self_model/organ_passports/contracts_accepted_atom_retention_organ/ORGAN_PASSPORT_V1.json'
foreach($p in @($reportPath,$proofPath,$passportPath)){ Assert (Test-Path $p) "MISSING:$p" }
$r=Get-Content $reportPath -Raw|ConvertFrom-Json
$p=Get-Content $proofPath -Raw|ConvertFrom-Json
$pass=Get-Content $passportPath -Raw|ConvertFrom-Json
Assert ($r.status -eq 'PASS_ACCEPTED_ATOM_RETENTION_ORGAN_CALIBRATION_V1') 'REPORT_STATUS_BAD'
Assert ($p.status -eq 'PASS_ACCEPTED_ATOM_RETENTION_ORGAN_CALIBRATION_V1') 'PROOF_STATUS_BAD'
Assert ($r.candidate_id -eq 'contracts_accepted_atom_retention_organ') 'CANDIDATE_BAD'
Assert ($r.calibration_decision -eq 'PASSPORT_DRAFT_VALIDATED_BLOCKED_RUNTIME_PROOF') 'DECISION_BAD'
Assert ($p.calibration_decision -eq 'PASSPORT_DRAFT_VALIDATED_BLOCKED_RUNTIME_PROOF') 'PROOF_DECISION_BAD'
Assert ($r.passport_validator_passed -eq $true) 'PASSPORT_VALIDATOR_NOT_PASSED'
Assert ($p.passport_validator_passed -eq $true) 'PROOF_PASSPORT_VALIDATOR_NOT_PASSED'
Assert ([int]$p.required_fields_missing_count -eq 0) 'REQUIRED_FIELDS_MISSING'
Assert ($p.missing_micro_proof -eq $true) 'MICRO_PROOF_BLOCKER_NOT_RECORDED'
Assert ($p.missing_contract_fixture -eq $true) 'CONTRACT_FIXTURE_BLOCKER_NOT_RECORDED'
Assert ([int]$p.blocker_count -ge 2) 'BLOCKER_COUNT_TOO_LOW'
Assert ($r.boundaries.no_active_passport_created -eq $true) 'ACTIVE_BOUNDARY_BAD'
Assert ($r.boundaries.no_proven_live_claim_created -eq $true) 'PROVEN_LIVE_BOUNDARY_BAD'
Assert ($r.boundaries.no_runtime_ready_claim_created -eq $true) 'RUNTIME_READY_BOUNDARY_BAD'
Assert ($r.boundaries.calibration_is_not_activation -eq $true) 'CALIBRATION_BOUNDARY_BAD'
Assert ($p.no_active_passport_created -eq $true) 'PROOF_ACTIVE_BOUNDARY_BAD'
Assert ($p.no_proven_live_claim_created -eq $true) 'PROOF_LIVE_BOUNDARY_BAD'
Assert ($p.no_runtime_ready_claim_created -eq $true) 'PROOF_RUNTIME_BOUNDARY_BAD'
Assert ($pass.status -eq 'PASSPORT_DRAFT_FROM_EVIDENCE') 'PASSPORT_STATUS_CHANGED_BAD'
Assert ($pass.live_or_lab_status -ne 'PROVEN_LIVE') 'PASSPORT_PROVEN_LIVE_BAD'
Assert ($pass.maturity -ne 'ACTIVE') 'PASSPORT_ACTIVE_BAD'
Write-Host 'VALIDATION_PASS=PASS_ACCEPTED_ATOM_RETENTION_ORGAN_CALIBRATION_V1'
Write-Host ('REPORT_PATH='+$reportPath)
Write-Host ('PROOF_PATH='+$proofPath)
