$ErrorActionPreference='Stop'
$repoRoot=(git rev-parse --show-toplevel).Trim(); Set-Location $repoRoot
function Write-Json([string]$Path,$Obj,[int]$Depth=100){$dir=Split-Path -Parent $Path;if($dir){New-Item -ItemType Directory -Force -Path $dir|Out-Null};$Obj|ConvertTo-Json -Depth $Depth|Set-Content $Path -Encoding UTF8}
function Assert($Cond,[string]$Msg){if(-not $Cond){throw $Msg}}
$organId='operations_active_behavior'
$passportPath="self_model/organ_passports/$organId/ORGAN_PASSPORT_V1.json"
$reportPath='reports/self_development/ACTIVE_BEHAVIOR_FRESH_1000_LIFECYCLE_PASS_V1.json'
$proofPath='tests/self_development/ACTIVE_BEHAVIOR_FRESH_1000_LIFECYCLE_PASS_V1_PROOF.json'
$validators=@('operations/active_behavior/validate_fresh_1000_candidate_behavior_absorption_v1.ps1','operations/active_behavior/validate_active_behavior_absorption_promotion_v1.ps1','operations/active_behavior/validate_active_behavior_task_decision_flow_v1.ps1')
foreach($v in $validators){powershell -ExecutionPolicy Bypass -File $v | Out-Host; Assert ($LASTEXITCODE -eq 0) "VALIDATOR_FAILED:$v"}
Assert (Test-Path $passportPath) 'PASSPORT_MISSING'
$p=Get-Content $passportPath -Raw|ConvertFrom-Json
$before=[ordered]@{maturity=$p.maturity;live_or_lab_status=$p.live_or_lab_status;validator_count=@($p.validators).Count;proof_count=@($p.proof_refs).Count}
$proofRefs=@('operations/reports/FRESH_1000_CANDIDATE_BEHAVIOR_ABSORPTION_V1.json','operations/reports/ACTIVE_BEHAVIOR_ABSORPTION_PROMOTION_V1.json','operations/reports/ACTIVE_BEHAVIOR_TASK_DECISION_FLOW_V1.json',$reportPath,$proofPath)
$p.status='PASSPORT_DRAFT_FROM_EVIDENCE'
$p.maturity='VALIDATED_LAB'
$p.live_or_lab_status='PROVEN_LAB'
$p.validators=@($validators)
$p.proof_refs=@($proofRefs|Sort-Object -Unique)
$p.gaps=@('PASSPORT_ACTIVE forbidden until separate activation authority','PROVEN_LIVE forbidden; active behavior absorption is lab/non-live proof','runtime_ready false','owner authority still required for live/active runtime')
$p | Add-Member -Force -NotePropertyName lifecycle_decision -NotePropertyValue ([ordered]@{decision='PROMOTE_TO_VALIDATED_LAB_KEEP_NON_ACTIVE';reason='Fresh 1000 source proof, active behavior absorption promotion, and task decision flow validators passed after new bounded cycle.';state_change='DRAFT_BLOCKED_TO_VALIDATED_LAB_PROVEN_LAB';created_at=(Get-Date).ToString('o')})
Write-Json $passportPath $p 100
$report=[ordered]@{schema='active_behavior_fresh_1000_lifecycle_pass_v1';status='PASS_ACTIVE_BEHAVIOR_FRESH_1000_LIFECYCLE_PASS_V1';organ_id=$organId;passport_path=$passportPath;before=$before;after=[ordered]@{maturity=$p.maturity;live_or_lab_status=$p.live_or_lab_status;validator_count=@($p.validators).Count;proof_count=@($p.proof_refs).Count};validators=$validators;proof_refs=$proofRefs;lifecycle_decision='PROMOTE_TO_VALIDATED_LAB_KEEP_NON_ACTIVE';state_change_verified=($before.live_or_lab_status -ne $p.live_or_lab_status -and $p.live_or_lab_status -eq 'PROVEN_LAB');boundary=[ordered]@{passport_active_created=$false;live_runtime_touched=$false;runtime_ready=$false;live_ready=$false;autonomous_runtime=$false};created_at=(Get-Date).ToString('o')}
$proof=[ordered]@{schema='active_behavior_fresh_1000_lifecycle_pass_v1_proof';status='PASS_ACTIVE_BEHAVIOR_FRESH_1000_LIFECYCLE_PASS_V1';organ_id=$organId;candidate_to_identity=$true;passport_draft_exists=$true;lifecycle_decision='PROMOTE_TO_VALIDATED_LAB_KEEP_NON_ACTIVE';fresh_source_proof_pass=$true;promotion_pass=$true;task_decision_flow_pass=$true;validator_count=@($validators).Count;proof_refs_attached=$true;state_change_verified=$report.state_change_verified;passport_index_update_pending=$true;no_passport_active_created=$true;no_live_runtime_touched=$true;runtime_ready=$false;live_ready_claim=$false;autonomous_runtime=$false;report_path=$reportPath;passport_path=$passportPath;created_at=(Get-Date).ToString('o')}
Write-Json $reportPath $report 100
Write-Json $proofPath $proof 100
Write-Host 'LIFECYCLE_PASS=PASS_ACTIVE_BEHAVIOR_FRESH_1000_LIFECYCLE_PASS_V1'
Write-Host 'MATURITY=VALIDATED_LAB'
Write-Host 'LIVE_OR_LAB_STATUS=PROVEN_LAB'
Write-Host 'RUNTIME_READY=false'
