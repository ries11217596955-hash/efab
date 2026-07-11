$ErrorActionPreference='Stop'
$repoRoot=(git rev-parse --show-toplevel).Trim(); Set-Location $repoRoot
function Assert($Cond,[string]$Msg){ if(-not $Cond){ throw $Msg } }
function Write-Json([string]$Path,$Obj,[int]$Depth=100){$dir=Split-Path -Parent $Path;if($dir){New-Item -ItemType Directory -Force -Path $dir|Out-Null};$Obj|ConvertTo-Json -Depth $Depth|Set-Content $Path -Encoding UTF8}
$organId='operations_live_like'
$passportPath="self_model/organ_passports/$organId/ORGAN_PASSPORT_V1.json"
$reportPath='reports/self_development/LIVE_LIKE_LIFECYCLE_PASS_V1.json'
$proofPath='tests/self_development/LIVE_LIKE_LIFECYCLE_PASS_V1_PROOF.json'
$validators=@('operations/live_like/validate_school_aimo_live_like_observation_gate_v1.ps1','operations/live_like/validate_school_aimo_live_like_signal_contract_v1.ps1')
foreach($v in $validators){ Assert (Test-Path $v) "VALIDATOR_MISSING:$v"; powershell -ExecutionPolicy Bypass -File $v | Out-Host; Assert ($LASTEXITCODE -eq 0) "VALIDATOR_FAILED:$v" }
Assert (Test-Path $passportPath) 'PASSPORT_MISSING'
$p=Get-Content $passportPath -Raw|ConvertFrom-Json
$before=[ordered]@{maturity=$p.maturity;live_or_lab_status=$p.live_or_lab_status;validator_count=@($p.validators).Count;validators=@($p.validators);proof_count=@($p.proof_refs).Count}
$p.status='PASSPORT_DRAFT_FROM_EVIDENCE'
$p.maturity='VALIDATED_LAB'
$p.live_or_lab_status='PROVEN_LAB'
$p.validators=@($validators)
$p.proof_refs=@('tests/live_like/SCHOOL_AIMO_LIVE_LIKE_OBSERVATION_GATE_V1_PROOF.json',$reportPath,$proofPath|Sort-Object -Unique)
$p.gaps=@('PASSPORT_ACTIVE forbidden until active wiring and owner acceptance','PROVEN_LIVE forbidden; live-like lab observation is not live readiness','runtime_ready false; continuous autonomous runtime forbidden','live readiness remains owned by operations_live_readiness/live_start')
$p | Add-Member -Force -NotePropertyName lifecycle_decision -NotePropertyValue ([ordered]@{decision='PROMOTE_TO_VALIDATED_LAB_KEEP_NON_ACTIVE';reason='base observation gate and signal-contract validator pass; proof establishes live-like lab observation only, not live readiness';state_change='DRAFT_NOT_PROVEN_TO_VALIDATED_LAB_PROVEN_LAB';created_at=(Get-Date).ToString('o')})
Write-Json $passportPath $p 100
$report=[ordered]@{schema='live_like_lifecycle_pass_v1';status='PASS_LIVE_LIKE_LIFECYCLE_PASS_V1';organ_id=$organId;candidate=$organId;identity=$organId;passport_path=$passportPath;validators=$validators;proof_refs=$p.proof_refs;lifecycle_decision='PROMOTE_TO_VALIDATED_LAB_KEEP_NON_ACTIVE';before=$before;after=[ordered]@{maturity=$p.maturity;live_or_lab_status=$p.live_or_lab_status;validator_count=@($p.validators).Count;proof_count=@($p.proof_refs).Count};state_change_verified=($before.maturity -ne $p.maturity -and $p.maturity -eq 'VALIDATED_LAB' -and $p.live_or_lab_status -eq 'PROVEN_LAB');boundaries=[ordered]@{passport_active_created=$false;live_runtime_touched=$false;runtime_ready=$false;live_ready_claim=$false;continuous_autonomous_runtime=$false;lab_only=$true};created_at=(Get-Date).ToString('o')}
$proof=[ordered]@{schema='live_like_lifecycle_pass_v1_proof';status='PASS_LIVE_LIKE_LIFECYCLE_PASS_V1';organ_id=$organId;candidate_to_identity=$true;passport_draft_exists=$true;validator_count=2;validators_passed=$true;proof_refs_attached=$true;lifecycle_decision='PROMOTE_TO_VALIDATED_LAB_KEEP_NON_ACTIVE';state_change_verified=$report.state_change_verified;passport_index_update_pending=$true;no_passport_active_created=$true;no_live_runtime_touched=$true;runtime_ready=$false;live_ready_claim=$false;continuous_autonomous_runtime=$false;report_path=$reportPath;passport_path=$passportPath;created_at=(Get-Date).ToString('o')}
Write-Json $reportPath $report 100
Write-Json $proofPath $proof 100
Write-Host 'LIFECYCLE_PASS=PASS_LIVE_LIKE_LIFECYCLE_PASS_V1'
Write-Host "REPORT_PATH=$reportPath"
Write-Host "PROOF_PATH=$proofPath"
