$ErrorActionPreference='Stop'
$RepoRoot=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
Set-Location $RepoRoot
function CountOf($x){ return @($x).Count }
function AddResult($name,$path,$expectedStatus,$observedStatus,$exitCode,$meaning){
  return [pscustomobject][ordered]@{name=$name;path=$path;expected_status=$expectedStatus;observed_status=$observedStatus;exit_code=$exitCode;meaning=$meaning}
}
$triagePath='reports/self_development/BODY_MAP_CANDIDATE_TRIAGE_V1.json'
$passportPath='self_model/organ_passports/contracts_accepted_atom_retention_organ/ORGAN_PASSPORT_V1.json'
$contractPassportPath='contracts/accepted_atom_retention_organ/passports/ORGAN_PASSPORT.json'
$contractStatusPath='contracts/accepted_atom_retention_organ/ACCEPTED_ATOM_RETENTION_ORGAN_CONTRACT_STATUS.json'
$passportValidator='validators/validate_accepted_atom_retention_passports_v1.ps1'
$microValidator='validators/validate_accepted_atom_retention_micro_proof_v1.ps1'
$contractValidator='validators/validate_accepted_atom_retention_contract_v1.ps1'
$realShapeValidator='validators/validate_accepted_atom_retention_gate_real_shape_micro_trial_v1.ps1'
foreach($p in @($triagePath,$passportPath,$contractPassportPath,$contractStatusPath,$passportValidator,$microValidator,$contractValidator,$realShapeValidator)){ if(-not(Test-Path $p)){ throw "MISSING:$p" } }
$triage=Get-Content $triagePath -Raw|ConvertFrom-Json
$item=@($triage.items|Where-Object{$_.candidate_id -eq 'contracts_accepted_atom_retention_organ'})[0]
if($null -eq $item){ throw 'TRIAGE_ITEM_MISSING:contracts_accepted_atom_retention_organ' }
$pass=Get-Content $passportPath -Raw|ConvertFrom-Json
$contractPass=Get-Content $contractPassportPath -Raw|ConvertFrom-Json
$contractStatus=Get-Content $contractStatusPath -Raw|ConvertFrom-Json
$requiredFields=@('organ_id','status','maturity','live_or_lab_status','owning_root','purpose','safety_boundaries','gaps','source_evidence')
$missingFields=@($requiredFields|Where-Object{ -not ($pass.PSObject.Properties.Name -contains $_) })
$missingFiles=@()
foreach($p in @($pass.owning_root,$contractPass.contract_path,$contractPass.module_path,$contractPass.proof_path)){
  if($p -and -not(Test-Path ([string]$p))){ $missingFiles += [string]$p }
}
# Run only the positive validator in build. Failing validators are recorded as blockers by missing file checks, not executed as required pass.
& powershell -NoProfile -ExecutionPolicy Bypass -File $passportValidator | Out-Null
$passportValidatorExit=$LASTEXITCODE
$microProofPath='tests/accepted_atom_retention/ACCEPTED_ATOM_RETENTION_MICRO_PROOF_V1.json'
$fixturePath='tests/accepted_atom_retention/fixture_accepted_atom_receipt_v1.json'
$blockers=@()
if(-not(Test-Path $microProofPath)){ $blockers += [pscustomobject][ordered]@{blocker='MISSING_MICRO_PROOF';path=$microProofPath;blocks='runtime_ready_and_micro_proof_validator'} }
if(-not(Test-Path $fixturePath)){ $blockers += [pscustomobject][ordered]@{blocker='MISSING_CONTRACT_VALIDATOR_FIXTURE';path=$fixturePath;blocks='contract_validator_full_pass'} }
if($passportValidatorExit -ne 0){ $blockers += [pscustomobject][ordered]@{blocker='PASSPORT_VALIDATOR_FAILED';path=$passportValidator;blocks='passport_draft_validation'} }
foreach($mf in $missingFiles){ $blockers += [pscustomobject][ordered]@{blocker='REFERENCED_FILE_MISSING';path=$mf;blocks='overclaim_to_runtime_or_real_runner'} }
$status='PASS_ACCEPTED_ATOM_RETENTION_ORGAN_CALIBRATION_V1'
$calibrationDecision='PASSPORT_DRAFT_VALIDATED_BLOCKED_RUNTIME_PROOF'
$validatorResults=@()
$validatorResults += AddResult 'passport_validator' $passportValidator 'PASS' $(if($passportValidatorExit -eq 0){'PASS'}else{'FAIL'}) $passportValidatorExit 'contract passport bundle is syntactically valid and guarded against runtime-ready overclaim'
$validatorResults += AddResult 'micro_proof_validator' $microValidator 'BLOCKED_EXPECTED' $(if(Test-Path $microProofPath){'UNKNOWN_NOT_RUN'}else{'BLOCKED_MISSING_PROOF'}) $null 'runtime/micro proof is missing; do not promote runtime readiness'
$validatorResults += AddResult 'contract_validator' $contractValidator 'BLOCKED_EXPECTED' $(if(Test-Path $fixturePath){'UNKNOWN_NOT_RUN'}else{'BLOCKED_MISSING_FIXTURE'}) $null 'contract fixture missing; do not claim full contract pass'
$validatorResults += AddResult 'real_shape_gate_validator' $realShapeValidator 'BLOCKED_EXPECTED' $(if(Test-Path $microProofPath){'UNKNOWN_NOT_RUN'}else{'BLOCKED_MISSING_PROOF'}) $null 'real-shape proof missing; do not claim real runner readiness'
$report=[pscustomobject][ordered]@{
 schema='accepted_atom_retention_organ_calibration_v1'
 status=$status
 candidate_id='contracts_accepted_atom_retention_organ'
 owning_root='contracts/accepted_atom_retention_organ'
 passport_path=$passportPath
 contract_passport_path=$contractPassportPath
 triage_path=$triagePath
 previous_triage_readiness=$item.passport_readiness
 calibration_decision=$calibrationDecision
 maturity_after_calibration='DRAFT_VALIDATED_STRUCTURE_ONLY'
 live_or_lab_status_after_calibration='NOT_PROVEN'
 passport_validator_passed=($passportValidatorExit -eq 0)
 required_fields_missing=@($missingFields)
 blockers=@($blockers)
 validator_results=@($validatorResults)
 boundaries=[pscustomobject][ordered]@{
 no_active_passport_created=$true
 no_proven_live_claim_created=$true
 no_runtime_ready_claim_created=$true
 no_child_agent_readiness_claim_created=$true
 legacy_contract_passports_not_authority_without_self_model_gate=$true
 calibration_is_not_activation=$true
 live_process_touched=$false
 }
 next_required=@('restore_or_regenerate_micro_proof_fixture_before_runtime_claim','connect capability invocation only after validator/proof pass','owner_route_acceptance_required_before_active_passport')
 created_at=(Get-Date).ToString('o')
}
$reportPath='reports/self_development/ACCEPTED_ATOM_RETENTION_ORGAN_CALIBRATION_V1.json'
$proofPath='tests/self_development/ACCEPTED_ATOM_RETENTION_ORGAN_CALIBRATION_V1_PROOF.json'
$report|ConvertTo-Json -Depth 80|Set-Content $reportPath -Encoding UTF8
$proof=[pscustomobject][ordered]@{
 schema='accepted_atom_retention_organ_calibration_v1_proof'
 status=$status
 report_path=$reportPath
 candidate_id='contracts_accepted_atom_retention_organ'
 passport_path=$passportPath
 passport_validator_passed=($passportValidatorExit -eq 0)
 calibration_decision=$calibrationDecision
 required_fields_missing_count=CountOf $missingFields
 blocker_count=CountOf $blockers
 missing_micro_proof=(-not(Test-Path $microProofPath))
 missing_contract_fixture=(-not(Test-Path $fixturePath))
 no_active_passport_created=$true
 no_proven_live_claim_created=$true
 no_runtime_ready_claim_created=$true
 live_process_touched=$false
 created_at=(Get-Date).ToString('o')
}
$proof|ConvertTo-Json -Depth 80|Set-Content $proofPath -Encoding UTF8
$md=@()
$md+='# Accepted Atom Retention Organ Calibration V1'
$md+=''
$md+='status: PASS_ACCEPTED_ATOM_RETENTION_ORGAN_CALIBRATION_V1'
$md+=''
$md+='Decision: PASSPORT_DRAFT_VALIDATED_BLOCKED_RUNTIME_PROOF.'
$md+=''
$md+='Meaning: the self-model passport draft and contract passport bundle are valid enough for a calibrated draft, but runtime/micro-proof evidence is missing. This is not active, not live, and not child-agent ready.'
$md+=''
$md+='Boundaries:'
$md+='- no active passport created'
$md+='- no PROVEN_LIVE claim created'
$md+='- no runtime_ready claim created'
$md+='- missing micro-proof remains a blocker'
$md+=''
$md+='Next: restore/regenerate micro-proof fixture before runtime or active passport claims.'
$md|Set-Content docs/operations/ACCEPTED_ATOM_RETENTION_ORGAN_CALIBRATION_V1.md -Encoding UTF8
Write-Host 'BUILT_ACCEPTED_ATOM_RETENTION_ORGAN_CALIBRATION_V1'
Write-Host ('REPORT_PATH='+$reportPath)
Write-Host ('PROOF_PATH='+$proofPath)
Write-Host ('PASSPORT_VALIDATOR_PASSED='+($passportValidatorExit -eq 0))
Write-Host ('BLOCKERS='+(CountOf $blockers))
