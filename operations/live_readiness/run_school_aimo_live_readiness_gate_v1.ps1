param(
  [bool]$OwnerLiveAuthorization = $false,
  [string]$LiveLikeProofPath = 'tests/live_like/SCHOOL_AIMO_LIVE_LIKE_OBSERVATION_GATE_V1_PROOF.json',
  [string]$StopfileContractProofPath = 'tests/live_readiness/DETACHED_LONG_RUNTIME_STOPFILE_CONTRACT_V1_PROOF.json',
  [string]$RollbackContractProofPath = 'tests/live_readiness/LIVE_ROLLBACK_CONTRACT_V1_PROOF.json',
  [string]$RejectAndForgetProofPath = 'tests/live_readiness/LIVE_REJECT_AND_FORGET_CONTRACT_V1_PROOF.json',
  [string]$ContinuousRuntimeProofPath = 'tests/live_readiness/SCHOOL_AIMO_CONTINUOUS_RUNTIME_PROOF_V1_PROOF.json',
  [string]$ProofPath = 'tests/live_readiness/SCHOOL_AIMO_LIVE_READINESS_GATE_V1_PROOF.json'
)
$ErrorActionPreference='Stop'
$RepoRoot=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
Set-Location $RepoRoot
function GitStatusShort(){ @(git status --short --untracked-files=all) }
function WriteJson($Path,$Obj){ New-Item -ItemType Directory -Force -Path (Split-Path $Path -Parent) | Out-Null; $Obj | ConvertTo-Json -Depth 40 | Set-Content -Path $Path -Encoding UTF8 }
function ReadJson($Path){ if([string]::IsNullOrWhiteSpace([string]$Path)){ return $null }; if(-not(Test-Path $Path)){ return $null }; return (Get-Content $Path -Raw | ConvertFrom-Json) }
function RuntimeProcesses(){ @(Get-CimInstance Win32_Process -ErrorAction SilentlyContinue | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_.CommandLine) -and ([string]$_.CommandLine -like '*run_agent_school.ps1*' -or [string]$_.CommandLine -like '*run_autonomous_inner_motor.ps1*' -or [string]$_.CommandLine -like '*run_school_aimo_parallel_lab_v1.ps1*' -or [string]$_.CommandLine -like '*run_school_aimo_live_like_observation_gate_v1.ps1*') }) }
function RunValidation($Script,$ProofPath){
  $out=@(& powershell -NoProfile -ExecutionPolicy Bypass -File $Script -ProofPath $ProofPath *>&1 | ForEach-Object {[string]$_})
  $exit=$LASTEXITCODE
  $status=(($out | Where-Object { $_ -match '^VALIDATION_PASS=' } | Select-Object -Last 1) -replace '^VALIDATION_PASS=','')
  return [ordered]@{ status=$status; exit=$exit; output=@($out) }
}
$started=Get-Date
$branch=(git branch --show-current).Trim()
$head=(git rev-parse HEAD).Trim()
$origin=(git remote get-url origin).Trim()
git fetch origin main --quiet
$aheadBehind=(git rev-list --left-right --count HEAD...origin/main).Trim()
$aheadBehindNorm=($aheadBehind -replace '\s+',' ')
$dirtyBefore=GitStatusShort
$activeProcesses=@(RuntimeProcesses)
$liveLike=ReadJson $LiveLikeProofPath
$stopfile=ReadJson $StopfileContractProofPath
$rollback=ReadJson $RollbackContractProofPath
$reject=ReadJson $RejectAndForgetProofPath
$continuous=ReadJson $ContinuousRuntimeProofPath
$mapOut=@(& powershell -NoProfile -ExecutionPolicy Bypass -File validators/validate_agent_body_composition_map_current_v1.ps1 *>&1 | ForEach-Object {[string]$_})
$mapExit=$LASTEXITCODE
$mapStatus=(($mapOut | Where-Object { $_ -match '^STATUS=' } | Select-Object -Last 1) -replace '^STATUS=','')
$liveLikeVal=RunValidation 'operations/live_like/validate_school_aimo_live_like_observation_gate_v1.ps1' $LiveLikeProofPath
$stopfileVal=RunValidation 'operations/live_readiness/validate_detached_long_runtime_stopfile_contract_v1.ps1' $StopfileContractProofPath
$rollbackVal=RunValidation 'operations/live_readiness/validate_live_rollback_contract_v1.ps1' $RollbackContractProofPath
$rejectVal=RunValidation 'operations/live_readiness/validate_live_reject_and_forget_contract_v1.ps1' $RejectAndForgetProofPath
$continuousVal=RunValidation 'operations/live_readiness/validate_school_aimo_continuous_runtime_proof_v1.ps1' $ContinuousRuntimeProofPath
$proofChecks=[ordered]@{
  live_like_status=if($liveLike){$liveLike.status}else{$null}
  live_like_duration_seconds=if($liveLike){$liveLike.observation.duration_seconds}else{$null}
  live_like_heartbeats=if($liveLike){$liveLike.observation.heartbeat_count}else{$null}
  live_like_watchdog_violations=if($liveLike){@($liveLike.observation.watchdog_violations).Count}else{$null}
  packet_status=if($liveLike){$liveLike.parallel_harness.packet_status}else{$null}
  intake_status=if($liveLike){$liveLike.parallel_harness.intake_status}else{$null}
  merge_status=if($liveLike){$liveLike.parallel_harness.merge_after_school_status}else{$null}
  stopfile_status=if($stopfile){$stopfile.status}else{$null}
  stopfile_child_exit=if($stopfile){$stopfile.detached_process.child_exit}else{$null}
  rollback_status=if($rollback){$rollback.status}else{$null}
  rollback_restored_to_checkpoint=if($rollback){$rollback.rollback.restored_to_checkpoint}else{$null}
  rollback_final_state=if($rollback){$rollback.rollback.final_state}else{$null}
  reject_status=if($reject){$reject.status}else{$null}
  reject_mode=if($reject){$reject.reject.mode}else{$null}
  reject_accepted=if($reject){$reject.reject.accepted}else{$null}
  reject_merged=if($reject){$reject.reject.merged}else{$null}
  reject_executed=if($reject){$reject.reject.executed}else{$null}
  continuous_status=if($continuous){$continuous.status}else{$null}
  continuous_technical_runtime_ready=if($continuous){$continuous.technical_runtime_ready}else{$null}
  continuous_runtime_ready=if($continuous){$continuous.runtime_ready}else{$null}
  continuous_duration=if($continuous){$continuous.continuous_observation.duration_seconds}else{$null}
  continuous_heartbeats=if($continuous){$continuous.continuous_observation.heartbeat_count}else{$null}
  continuous_packet=if($continuous){$continuous.parallel_runtime.packet_status}else{$null}
  continuous_intake=if($continuous){$continuous.parallel_runtime.intake_status}else{$null}
  continuous_merge=if($continuous){$continuous.parallel_runtime.merge_after_school_status}else{$null}
}
$passed=@(); $missing=@()
if(($RepoRoot -replace '\\','/') -eq 'H:/efab'){ $passed+='CANONICAL_ROOT_H_EFAB' } else { $missing+='CANONICAL_ROOT_H_EFAB' }
if($branch -eq 'main'){ $passed+='BRANCH_MAIN' } else { $missing+='BRANCH_MAIN' }
if($origin -eq 'https://github.com/ries11217596955-hash/efab.git'){ $passed+='ORIGIN_EFAB' } else { $missing+='ORIGIN_EFAB' }
if($aheadBehindNorm -eq '0 0'){ $passed+='REMOTE_SYNCED_0_0' } else { $missing+="REMOTE_SYNCED_0_0_ACTUAL_$aheadBehind" }
if($dirtyBefore.Count -eq 0){ $passed+='WORKTREE_CLEAN' } else { $missing+='WORKTREE_CLEAN' }
if($activeProcesses.Count -eq 0){ $passed+='NO_ACTIVE_RUNTIME_PROCESS' } else { $missing+="NO_ACTIVE_RUNTIME_PROCESS_ACTUAL_$($activeProcesses.Count)" }
if($mapStatus -eq 'PASS_AGENT_BODY_COMPOSITION_MAP_CURRENT_V1' -and $mapExit -eq 0){ $passed+='MAP_VALIDATOR_PASS' } else { $missing+='MAP_VALIDATOR_PASS' }
if($liveLikeVal.status -eq 'PASS_SCHOOL_AIMO_LIVE_LIKE_OBSERVATION_GATE_V1' -and $liveLikeVal.exit -eq 0){ $passed+='LIVE_LIKE_GATE_PASS' } else { $missing+='LIVE_LIKE_GATE_PASS' }
if($stopfileVal.status -eq 'PASS_DETACHED_LONG_RUNTIME_STOPFILE_CONTRACT_V1' -and $stopfileVal.exit -eq 0){ $passed+='DETACHED_STOPFILE_CONTRACT_PASS' } else { $missing+='DETACHED_STOPFILE_CONTRACT_PASS' }
if($rollbackVal.status -eq 'PASS_LIVE_ROLLBACK_CONTRACT_V1' -and $rollbackVal.exit -eq 0){ $passed+='LIVE_ROLLBACK_CONTRACT_PASS' } else { $missing+='LIVE_ROLLBACK_CONTRACT_PASS' }
if($rejectVal.status -eq 'PASS_LIVE_REJECT_AND_FORGET_CONTRACT_V1' -and $rejectVal.exit -eq 0){ $passed+='LIVE_REJECT_AND_FORGET_CONTRACT_PASS' } else { $missing+='LIVE_REJECT_AND_FORGET_CONTRACT_PASS' }
if($continuousVal.status -eq 'PASS_SCHOOL_AIMO_CONTINUOUS_RUNTIME_PROOF_V1' -and $continuousVal.exit -eq 0 -and $continuous.runtime_ready -eq $true -and $continuous.technical_runtime_ready -eq $true){ $passed+='SCHOOL_AIMO_CONTINUOUS_RUNTIME_PROOF_PASS' } else { $missing+='SCHOOL_AIMO_CONTINUOUS_RUNTIME_PROOF_PASS' }
$technicalRuntimeReady=($missing.Count -eq 0 -and $continuousVal.status -eq 'PASS_SCHOOL_AIMO_CONTINUOUS_RUNTIME_PROOF_V1' -and $continuous.runtime_ready -eq $true)
$goBlockers=@()
if(-not $OwnerLiveAuthorization){ $goBlockers+='OWNER_LIVE_AUTHORIZATION_MISSING' }
if(-not $technicalRuntimeReady){
  $goBlockers+='PRIOR_PROOF_RUNTIME_READY_FALSE'
  $goBlockers+='LIVE_CONTINUOUS_RUNTIME_NOT_PROVEN'
}
$liveReady=($missing.Count -eq 0 -and $goBlockers.Count -eq 0)
$status='PASS_SCHOOL_AIMO_LIVE_READINESS_GATE_NO_GO_V1'
$decision='NO_GO_LIVE_AUTHORIZATION_REQUIRED'
if($liveReady){ $status='PASS_SCHOOL_AIMO_LIVE_READINESS_GATE_GO_V1'; $decision='GO_LIVE_READY' }
if($missing.Count -gt 0){ $status='FAIL_SCHOOL_AIMO_LIVE_READINESS_GATE_V1'; $decision='GATE_INVALID_PREREQ_FAILED' }
$result=[ordered]@{
  schema='school_aimo_live_readiness_gate_v1'
  status=$status
  proof_label='PROVEN_LAB_LIVE_READINESS_GATE_DECISION_NOT_LIVE_EXECUTION'
  decision=$decision
  live_ready=$liveReady
  technical_runtime_ready=$technicalRuntimeReady
  runtime_ready=$technicalRuntimeReady
  owner_live_authorized=$OwnerLiveAuthorization
  repo=[ordered]@{ root=($RepoRoot -replace '\\','/'); branch=$branch; head=$head; origin=$origin; ahead_behind=$aheadBehind; dirty_before=@($dirtyBefore); active_process_count=$activeProcesses.Count }
  checks=[ordered]@{ passed=@($passed); missing=@($missing); go_blockers=@($goBlockers); map_status=$mapStatus; map_exit=$mapExit; live_like_validation_status=$liveLikeVal.status; live_like_validation_exit=$liveLikeVal.exit; stopfile_contract_validation_status=$stopfileVal.status; stopfile_contract_validation_exit=$stopfileVal.exit; rollback_contract_validation_status=$rollbackVal.status; rollback_contract_validation_exit=$rollbackVal.exit; reject_contract_validation_status=$rejectVal.status; reject_contract_validation_exit=$rejectVal.exit; continuous_runtime_validation_status=$continuousVal.status; continuous_runtime_validation_exit=$continuousVal.exit; proof_checks=$proofChecks }
  required_next_to_be_live_ready=@('explicit Owner live authorization')
  boundary='Readiness decision only. Technical runtime readiness may be true, but live_ready requires explicit Owner live authorization. Not PROVEN_LIVE.'
  started_at=$started.ToString('o')
  finished_at=(Get-Date).ToString('o')
}
WriteJson $ProofPath $result
Write-Host "LIVE_READINESS_GATE_STATUS=$($result.status)"
Write-Host "LIVE_READINESS_DECISION=$($result.decision)"
Write-Host "TECHNICAL_RUNTIME_READY=$($result.technical_runtime_ready)"
Write-Host "RUNTIME_READY=$($result.runtime_ready)"
Write-Host "LIVE_READY=$($result.live_ready)"
Write-Host "GO_BLOCKERS=$($goBlockers -join ',')"
Write-Host "PROOF=$ProofPath"
if($status -like 'FAIL_*'){ exit 1 }