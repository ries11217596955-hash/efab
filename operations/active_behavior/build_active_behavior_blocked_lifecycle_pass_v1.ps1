$ErrorActionPreference='Stop'
$repoRoot=(git rev-parse --show-toplevel).Trim(); Set-Location $repoRoot
function Write-Json([string]$Path,$Obj,[int]$Depth=100){$dir=Split-Path -Parent $Path;if($dir){New-Item -ItemType Directory -Force -Path $dir|Out-Null};$Obj|ConvertTo-Json -Depth $Depth|Set-Content $Path -Encoding UTF8}
function Exists([string]$p){ return Test-Path $p }
$organId='operations_active_behavior'
$passportPath="self_model/organ_passports/$organId/ORGAN_PASSPORT_V1.json"
$reportPath='reports/self_development/ACTIVE_BEHAVIOR_BLOCKED_LIFECYCLE_PASS_V1.json'
$proofPath='tests/self_development/ACTIVE_BEHAVIOR_BLOCKED_LIFECYCLE_PASS_V1_PROOF.json'
$requiredSource='operations/reports/FRESH_1000_CANDIDATE_BEHAVIOR_ABSORPTION_V1.json'
$downstreamReports=@('operations/reports/ACTIVE_BEHAVIOR_ABSORPTION_PROMOTION_V1.json','operations/reports/ACTIVE_BEHAVIOR_TASK_DECISION_FLOW_V1.json')
if(-not(Test-Path $passportPath)){throw 'PASSPORT_MISSING'}
$p=Get-Content $passportPath -Raw|ConvertFrom-Json
$before=[ordered]@{maturity=$p.maturity;live_or_lab_status=$p.live_or_lab_status;validator_count=@($p.validators).Count;proof_count=@($p.proof_refs).Count;gaps=@($p.gaps)}
$sourceExists=Exists $requiredSource
$downstream=@($downstreamReports|ForEach-Object{[ordered]@{path=$_;exists=(Exists $_)}})
$allDownstreamExist=(@($downstream|Where-Object{-not $_.exists}).Count -eq 0)
$decision=if(-not $sourceExists){'BLOCKED_BY_MISSING_SOURCE_PROOF'}elseif(-not $allDownstreamExist){'BLOCKED_BY_MISSING_DOWNSTREAM_REPORTS'}else{'READY_FOR_SEPARATE_PROMOTION_ATTEMPT'}
# Do not promote. Attach blocker proof and make gaps explicit.
$p.status='PASSPORT_DRAFT_FROM_EVIDENCE'
$p.maturity='DRAFT'
$p.live_or_lab_status='BLOCKED'
$p.proof_refs=@(@($p.proof_refs) + $reportPath + $proofPath | Sort-Object -Unique)
$p.gaps=@('BLOCKED_BY_MISSING_SOURCE_PROOF: operations/reports/FRESH_1000_CANDIDATE_BEHAVIOR_ABSORPTION_V1.json missing','promotion forbidden until source proof exists','do not synthesize or backfill proof','runtime_ready false','PASSPORT_ACTIVE forbidden','PROVEN_LIVE forbidden')
$p | Add-Member -Force -NotePropertyName lifecycle_decision -NotePropertyValue ([ordered]@{decision=$decision;reason='active behavior promotion requires source proof and downstream reports; current state lacks source proof, so lifecycle must stop as BLOCKED instead of promoting';state_change='DRAFT_NOT_PROVEN_TO_DRAFT_BLOCKED';created_at=(Get-Date).ToString('o')})
Write-Json $passportPath $p 100
$report=[ordered]@{schema='active_behavior_blocked_lifecycle_pass_v1';status='PASS_ACTIVE_BEHAVIOR_BLOCKED_LIFECYCLE_PASS_V1';organ_id=$organId;candidate=$organId;identity=$organId;passport_path=$passportPath;lifecycle_decision=$decision;before=$before;after=[ordered]@{maturity=$p.maturity;live_or_lab_status=$p.live_or_lab_status;validator_count=@($p.validators).Count;proof_count=@($p.proof_refs).Count};required_source_proof=[ordered]@{path=$requiredSource;exists=$sourceExists};downstream_reports=$downstream;state_change_verified=($before.live_or_lab_status -ne $p.live_or_lab_status -and $p.live_or_lab_status -eq 'BLOCKED');boundaries=[ordered]@{promotion_attempted=$false;files_mutated_by_promotion=$false;passport_active_created=$false;live_runtime_touched=$false;runtime_ready=$false;proof_synthesized=$false};created_at=(Get-Date).ToString('o')}
$proof=[ordered]@{schema='active_behavior_blocked_lifecycle_pass_v1_proof';status='PASS_ACTIVE_BEHAVIOR_BLOCKED_LIFECYCLE_PASS_V1';organ_id=$organId;candidate_to_identity=$true;passport_draft_exists=$true;lifecycle_decision=$decision;blocked_reason='MISSING_SOURCE_PROOF';missing_source_proof=$requiredSource;source_proof_exists=$sourceExists;state_change_verified=$report.state_change_verified;passport_index_update_pending=$true;promotion_attempted=$false;no_proof_synthesized=$true;no_passport_active_created=$true;no_live_runtime_touched=$true;runtime_ready=$false;report_path=$reportPath;passport_path=$passportPath;created_at=(Get-Date).ToString('o')}
Write-Json $reportPath $report 100
Write-Json $proofPath $proof 100
Write-Host 'LIFECYCLE_PASS=PASS_ACTIVE_BEHAVIOR_BLOCKED_LIFECYCLE_PASS_V1'
Write-Host "DECISION=$decision"
Write-Host "SOURCE_PROOF_EXISTS=$sourceExists"
Write-Host "REPORT_PATH=$reportPath"
Write-Host "PROOF_PATH=$proofPath"
