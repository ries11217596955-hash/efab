$ErrorActionPreference='Stop'
$repoRoot=(git rev-parse --show-toplevel).Trim(); Set-Location $repoRoot
function Write-Json([string]$Path,$Obj,[int]$Depth=80){$dir=Split-Path -Parent $Path;if($dir){New-Item -ItemType Directory -Force -Path $dir|Out-Null};$Obj|ConvertTo-Json -Depth $Depth|Set-Content $Path -Encoding UTF8}
function Assert($Cond,[string]$Msg){ if(-not $Cond){ throw $Msg } }
$organId='operations_organ_promotion_lanes'
$passportPath="self_model/organ_passports/$organId/ORGAN_PASSPORT_V1.json"
$reportPath='reports/self_development/ORGAN_PROMOTION_LANES_LIFECYCLE_PASS_V1.json'
$proofPath='tests/self_development/ORGAN_PROMOTION_LANES_LIFECYCLE_PASS_V1_PROOF.json'
$validators=@('operations/organ_promotion_lanes/validate_organ_promotion_lanes_v1.ps1','operations/organ_promotion_lanes/validate_organ_promotion_lanes_signal_contract_v1.ps1')
foreach($v in $validators){ Assert (Test-Path $v) "VALIDATOR_MISSING:$v"; & powershell -ExecutionPolicy Bypass -File $v | Out-Host; Assert ($LASTEXITCODE -eq 0) "VALIDATOR_FAILED:$v" }
Assert (Test-Path $passportPath) 'PASSPORT_MISSING'
$p=Get-Content $passportPath -Raw|ConvertFrom-Json
$before=[ordered]@{maturity=$p.maturity;live_or_lab_status=$p.live_or_lab_status;proof_count=@($p.proof_refs).Count;validator_count=@($p.validators).Count}
# Attach lifecycle proof refs and second validator. Promote only to lab-validated, not active/live.
$p.status='PASSPORT_DRAFT_FROM_EVIDENCE'
$p.maturity='VALIDATED_LAB'
$p.live_or_lab_status='PROVEN_LAB'
$p.validators=@($validators)
$baseProofs=@('reports/self_development/ORGAN_PROMOTION_LANES_V1_REPORT.json','self_model/organ_promotion_lanes/ORGAN_PROMOTION_LANES_V1.json','tests/self_development/ORGAN_PROMOTION_LANES_V1_PROOF.json')
$p.proof_refs=@($baseProofs + $reportPath + $proofPath | Sort-Object -Unique)
$p.gaps=@('PASSPORT_ACTIVE forbidden until active wiring contract exists','PROVEN_LIVE forbidden','Living Loop Brain consumption of lane signals not implemented yet')
$p | Add-Member -Force -NotePropertyName lifecycle_decision -NotePropertyValue ([ordered]@{decision='PROMOTE_TO_VALIDATED_LAB_KEEP_NON_ACTIVE';reason='two independent validators pass; lane decisions are normalized signals, not organ acceptance';state_change='DRAFT_NOT_PROVEN_TO_VALIDATED_LAB_PROVEN_LAB';created_at=(Get-Date).ToString('o')})
Write-Json $passportPath $p 80
$report=[ordered]@{schema='organ_promotion_lanes_lifecycle_pass_v1';status='PASS_ORGAN_PROMOTION_LANES_LIFECYCLE_PASS_V1';organ_id=$organId;candidate=$organId;identity=$organId;passport_path=$passportPath;validators=$validators;proof_refs=$p.proof_refs;lifecycle_decision='PROMOTE_TO_VALIDATED_LAB_KEEP_NON_ACTIVE';before=$before;after=[ordered]@{maturity=$p.maturity;live_or_lab_status=$p.live_or_lab_status;proof_count=@($p.proof_refs).Count;validator_count=@($p.validators).Count};state_change_verified=($before.maturity -ne $p.maturity -and $p.maturity -eq 'VALIDATED_LAB' -and $p.live_or_lab_status -eq 'PROVEN_LAB');boundaries=[ordered]@{passport_active_created=$false;live_runtime_touched=$false;active_allowed=$false;brain_reads_raw_repo=$false;signals_only=$true};created_at=(Get-Date).ToString('o')}
$proof=[ordered]@{schema='organ_promotion_lanes_lifecycle_pass_v1_proof';status='PASS_ORGAN_PROMOTION_LANES_LIFECYCLE_PASS_V1';organ_id=$organId;candidate_to_identity=$true;passport_draft_exists=$true;validator_count=2;validators_passed=$true;proof_refs_attached=$true;lifecycle_decision='PROMOTE_TO_VALIDATED_LAB_KEEP_NON_ACTIVE';registry_or_index_update_pending=$true;state_change_verified=$report.state_change_verified;no_passport_active_created=$true;no_live_runtime_touched=$true;report_path=$reportPath;passport_path=$passportPath;created_at=(Get-Date).ToString('o')}
Write-Json $reportPath $report 80
Write-Json $proofPath $proof 80
Write-Host 'LIFECYCLE_PASS=PASS_ORGAN_PROMOTION_LANES_LIFECYCLE_PASS_V1'
Write-Host "REPORT_PATH=$reportPath"
Write-Host "PROOF_PATH=$proofPath"
