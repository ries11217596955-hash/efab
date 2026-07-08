$ErrorActionPreference='Stop'
$RepoRoot=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
Set-Location $RepoRoot
function Assert($Cond,[string]$Msg){if(-not $Cond){throw $Msg}}
$passportPath='self_model/organ_passports/operations_self_model/ORGAN_PASSPORT_V1.json'
$reportPath='reports/self_development/OPERATIONS_SELF_MODEL_ORGAN_LAB_VALIDATION_V1.json'
$proofPath='tests/self_development/OPERATIONS_SELF_MODEL_ORGAN_LAB_VALIDATION_V1_PROOF.json'
foreach($path in @($passportPath,$reportPath,$proofPath)){Assert (Test-Path $path) ("MISSING:{0}" -f $path)}
$contract=Get-Content self_model/ORGAN_PASSPORT_V1_CONTRACT.json -Raw|ConvertFrom-Json
$pass=Get-Content $passportPath -Raw|ConvertFrom-Json
$r=Get-Content $reportPath -Raw|ConvertFrom-Json
$p=Get-Content $proofPath -Raw|ConvertFrom-Json
Assert ($r.status -eq 'PASS_OPERATIONS_SELF_MODEL_ORGAN_LAB_VALIDATION_V1') 'REPORT_STATUS_BAD'
Assert ($p.status -eq 'PASS_OPERATIONS_SELF_MODEL_ORGAN_LAB_VALIDATION_V1') 'PROOF_STATUS_BAD'
Assert ($pass.organ_id -eq 'operations_self_model') 'PASSPORT_ID_BAD'
Assert ($pass.status -eq 'PASSPORT_DRAFT_FROM_EVIDENCE') 'PASSPORT_STATUS_BAD_OR_ACTIVE'
Assert ($pass.maturity -eq 'VALIDATED_LAB') 'PASSPORT_MATURITY_NOT_VALIDATED_LAB'
Assert ($pass.live_or_lab_status -eq 'PROVEN_LAB') 'PASSPORT_LAB_STATUS_NOT_PROVEN_LAB'
foreach($field in @($contract.required_fields)){Assert ($pass.PSObject.Properties.Name -contains $field) ("REQUIRED_FIELD_MISSING:{0}" -f $field)}
foreach($f in @($pass.owned_files)){Assert (Test-Path $f) ("OWNED_FILE_MISSING:{0}" -f $f)}
Assert (@($pass.validators|Where-Object{Test-Path $_}).Count -ge 10) 'EXISTING_VALIDATORS_TOO_LOW'
Assert (@($r.non_live_dedicated_runset|Where-Object{$_.exit_code -ne 0}).Count -eq 0) 'NON_LIVE_RUNSET_NOT_ALL_PASS'
Assert ($p.runset_all_pass -eq $true) 'PROOF_RUNSET_ALL_PASS_FALSE'
Assert (@($r.excluded_live_dependent_validators).Count -ge 2) 'LIVE_DEPENDENT_EXCLUSIONS_MISSING'
Assert ($r.boundaries.no_passport_active_created -eq $true) 'ACTIVE_BOUNDARY_BAD'
Assert ($r.boundaries.no_proven_live_claim -eq $true) 'LIVE_BOUNDARY_BAD'
Assert ($r.boundaries.live_dependent_validator_excluded -eq $true) 'LIVE_DEPENDENT_EXCLUSION_NOT_RECORDED'
Assert ($pass.status -ne 'PASSPORT_ACTIVE') 'ACTIVE_PASSPORT_FORBIDDEN'
Assert ($pass.live_or_lab_status -ne 'PROVEN_LIVE') 'PROVEN_LIVE_FORBIDDEN'
foreach($legacy in @('reports/self_development/CURRENT_BODY_CAPABILITY_SNAPSHOT_V1.json','self_knowledge/BUILDER_SELF_MODEL.json')){Assert (-not(Test-Path $legacy)) ("LEGACY_MAP_PRESENT:{0}" -f $legacy)}
Write-Host 'VALIDATION_PASS=PASS_OPERATIONS_SELF_MODEL_ORGAN_LAB_VALIDATION_V1'
Write-Host ('REPORT_PATH='+$reportPath)
Write-Host ('PROOF_PATH='+$proofPath)
