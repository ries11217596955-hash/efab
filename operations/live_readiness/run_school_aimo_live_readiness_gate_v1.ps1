param(
  [bool]$OwnerLiveAuthorization = $false,
  [int]$MinLiveLikeDurationSeconds = 180,
  [int]$MinHeartbeats = 10,
  [string]$LiveLikeProofPath = 'tests/live_like/SCHOOL_AIMO_LIVE_LIKE_OBSERVATION_GATE_V1_PROOF.json',
  [string]$StopfileContractProofPath = 'tests/live_readiness/DETACHED_LONG_RUNTIME_STOPFILE_CONTRACT_V1_PROOF.json',
  [string]$RollbackContractProofPath = 'tests/live_readiness/LIVE_ROLLBACK_CONTRACT_V1_PROOF.json',
  [string]$ProofPath = 'tests/live_readiness/SCHOOL_AIMO_LIVE_READINESS_GATE_V1_PROOF.json'
)
$ErrorActionPreference='Stop'
$RepoRoot=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
Set-Location $RepoRoot
function GitStatusShort(){ @(git status --short --untracked-files=all) }
function WriteJson($Path,$Obj){ New-Item -ItemType Directory -Force -Path (Split-Path $Path -Parent) | Out-Null; $Obj | ConvertTo-Json -Depth 30 | Set-Content -Path $Path -Encoding UTF8 }
function ReadJson($Path){ if(-not(Test-Path $Path)){ return $null }; return (Get-Content $Path -Raw | ConvertFrom-Json) }
function RelevantRuntimeChildProcesses(){
  @(Get-CimInstance Win32_Process -ErrorAction SilentlyContinue | Where-Object {
    -not [string]::IsNullOrWhiteSpace([string]$_.CommandLine) -and (
      [string]$_.CommandLine -like '*run_agent_school.ps1*' -or
      [string]$_.CommandLine -like '*run_autonomous_inner_motor.ps1*'
    )
  })
}
$startedAt=Get-Date
$branch=(git branch --show-current).Trim()
$head=(git rev-parse HEAD).Trim()
$origin=(git remote get-url origin).Trim()
git fetch origin main --quiet
$aheadBehind=(git rev-list --left-right --count HEAD...origin/main).Trim()
$aheadBehindNorm=($aheadBehind -replace '\s+',' ')
$dirtyBefore=GitStatusShort
$processes=@(RelevantRuntimeChildProcesses)
$liveLike=ReadJson $LiveLikeProofPath
$stopfileContract=ReadJson $StopfileContractProofPath
$rollbackContract=ReadJson $RollbackContractProofPath
$rejectContract=ReadJson $RejectAndForgetProofPath
$mapOut=@(& powershell -NoProfile -ExecutionPolicy Bypass -File validators/validate_agent_body_composition_map_current_v1.ps1 *>&1 | ForEach-Object {[string]$_})
$mapExit=$LASTEXITCODE
$mapStatus=(($mapOut | Where-Object { $_ -match '^STATUS=' } | Select-Object -Last 1) -replace '^STATUS=','')
$liveLikeValidationOut=@(); $liveLikeValidationExit=$null; $liveLikeValidationStatus='NOT_ATTEMPTED'
if($liveLike){
  $liveLikeValidationOut=@(& powershell -NoProfile -ExecutionPolicy Bypass -File operations/live_like/validate_school_aimo_live_like_observation_gate_v1.ps1 -ProofPath $LiveLikeProofPath *>&1 | ForEach-Object {[string]$_})
  $liveLikeValidationExit=$LASTEXITCODE
  $liveLikeValidationStatus=(($liveLikeValidationOut | Where-Object { $_ -match '^VALIDATION_PASS=' } | Select-Object -Last 1) -replace '^VALIDATION_PASS=','')
}
$stopfileContractValidationOut=@(); $stopfileContractValidationExit=$null; $stopfileContractValidationStatus='NOT_ATTEMPTED'
if($stopfileContract){
  $stopfileContractValidationOut=@(& powershell -NoProfile -ExecutionPolicy Bypass -File operations/live_readiness/validate_detached_long_runtime_stopfile_contract_v1.ps1 -ProofPath $StopfileContractProofPath *>&1 | ForEach-Object {[string]$_})
  $stopfileContractValidationExit=$LASTEXITCODE
  $stopfileContractValidationStatus=(($stopfileContractValidationOut | Where-Object { $_ -match '^VALIDATION_PASS=' } | Select-Object -Last 1) -replace '^VALIDATION_PASS=','')
}
$rollbackContractValidationOut=@(); $rollbackContractValidationExit=$null; $rollbackContractValidationStatus='NOT_ATTEMPTED'
if($rollbackContract){
  $rollbackContractValidationOut=@(& powershell -NoProfile -ExecutionPolicy Bypass -File operations/live_readiness/validate_live_rollback_contract_v1.ps1 -ProofPath $RollbackContractProofPath *>&1 | ForEach-Object {[string]$_})
  $rollbackContractValidationExit=$LASTEXITCODE
  $rollbackContractValidationStatus=(($rollbackContractValidationOut | Where-Object { $_ -match '^VALIDATION_PASS=' } | Select-Object -Last 1) -replace '^VALIDATION_PASS=','')
}
$rejectContractValidationOut=@(); $rejectContractValidationExit=$null; $rejectContractValidationStatus='NOT_ATTEMPTED'
if($rejectContract){
  $rejectContractValidationOut=@(& powershell -NoProfile -ExecutionPolicy Bypass -File operations/live_readiness/validate_live_reject_and_forget_contract_v1.ps1 -ProofPath $RejectAndForgetProofPath *>&1 | ForEach-Object {[string]$_})
  $rejectContractValidationExit=$LASTEXITCODE
  $rejectContractValidationStatus=(($rejectContractValidationOut | Where-Object { $_ -match '^VALIDATION_PASS=' } | Select-Object -Last 1) -replace '^VALIDATION_PASS=','')
}
$proofChecks=[ordered]@{
  live_like_proof_present=($null -ne $liveLike)
  live_like_status=if($liveLike){$liveLike.status}else{$null}
  live_like_duration_seconds=if($liveLike){$liveLike.observation.duration_seconds}else{$null}
  live_like_heartbeats=if($liveLike){$liveLike.observation.heartbeat_count}else{$null}
  live_like_watchdog_violations=if($liveLike){@($liveLike.observation.watchdog_violations).Count}else{$null}
  live_like_runtime_ready=if($liveLike){$liveLike.runtime_ready}else{$null}
  packet_status=if($liveLike){$liveLike.parallel_harness.packet_status}else{$null}
  intake_status=if($liveLike){$liveLike.parallel_harness.intake_status}else{$null}
  merge_status=if($liveLike){$liveLike.parallel_harness.merge_after_school_status}else{$null}
  stopfile_contract_present=($null -ne $stopfileContract)
  stopfile_contract_status=if($stopfileContract){$stopfileContract.status}else{$null}
  stopfile_contract_child_exit=if($stopfileContract){$stopfileContract.detached_process.child_exit}else{$null}
  stopfile_contract_exit_reason=if($stopfileContract){$stopfileContract.contract.worker_exit_proof.exit_reason}else{$null}
  stopfile_contract_stopped_within_grace=if($stopfileContract){$stopfileContract.detached_process.stopped_within_grace}else{$null}
  rollback_contract_present=($null -ne $rollbackContract)
  rollback_contract_status=if($rollbackContract){$rollbackContract.status}else{$null}
  rollback_contract_mutation_changed_hash=if($rollbackContract){$rollbackContract.rollback.mutation_changed_hash}else{$null}
  rollback_contract_restored_to_checkpoint=if($rollbackContract){$rollbackContract.rollback.restored_to_checkpoint}else{$null}
  rollback_contract_final_state=if($rollbackContract){$rollbackContract.rollback.final_state}else{$null}
  rollback_contract_active_memory_mutated=if($rollbackContract){$rollbackContract.safety.active_memory_mutated}else{$null}
  rollback_contract_tracked_repo_mutated=if($rollbackContract){$rollbackContract.safety.tracked_repo_mutated}else{$null}
  reject_contract_present=($null -ne $rejectContract)
  reject_contract_status=if($rejectContract){$rejectContract.status}else{$null}
  reject_contract_mode=if($rejectContract){$rejectContract.reject.mode}else{$null}
  reject_contract_raw_packet_exists_after_disposal=if($rejectContract){$rejectContract.bad_input.raw_packet_exists_after_disposal}else{$null}
  reject_contract_manifest_contains_raw_payload=if($rejectContract){$rejectContract.reject.manifest_contains_raw_payload}else{$null}
  reject_contract_accepted=if($rejectContract){$rejectContract.reject.accepted}else{$null}
  reject_contract_merged=if($rejectContract){$rejectContract.reject.merged}else{$null}
  reject_contract_executed=if($rejectContract){$rejectContract.reject.executed}else{$null}
}
$passedPrereqs=@(); $missingPrereqs=@()
if(($RepoRoot -replace '\\','/') -eq 'H:/efab'){ $passedPrereqs += 'CANONICAL_ROOT_H_EFAB' } else { $missingPrereqs += 'CANONICAL_ROOT_H_EFAB' }
if($branch -eq 'main'){ $passedPrereqs += 'BRANCH_MAIN' } else { $missingPrereqs += 'BRANCH_MAIN' }
if($origin -eq 'https://github.com/ries11217596955-hash/efab.git'){ $passedPrereqs += 'ORIGIN_EFAB' } else { $missingPrereqs += 'ORIGIN_EFAB' }
if($aheadBehindNorm -eq '0 0'){ $passedPrereqs += 'REMOTE_SYNCED_0_0' } else { $missingPrereqs += "REMOTE_SYNCED_0_0_ACTUAL_$aheadBehind" }
if($dirtyBefore.Count -eq 0){ $passedPrereqs += 'WORKTREE_CLEAN' } else { $missingPrereqs += 'WORKTREE_CLEAN' }
if($processes.Count -eq 0){ $passedPrereqs += 'NO_ACTIVE_RUNTIME_CHILD_PROCESS' } else { $missingPrereqs += "NO_ACTIVE_RUNTIME_CHILD_PROCESS_ACTUAL_$($processes.Count)" }
if($mapStatus -eq 'PASS_AGENT_BODY_COMPOSITION_MAP_CURRENT_V1' -and $mapExit -eq 0){ $passedPrereqs += 'MAP_VALIDATOR_PASS' } else { $missingPrereqs += 'MAP_VALIDATOR_PASS' }
if($liveLikeValidationStatus -eq 'PASS_SCHOOL_AIMO_LIVE_LIKE_OBSERVATION_GATE_V1' -and $liveLikeValidationExit -eq 0){ $passedPrereqs += 'LIVE_LIKE_GATE_VALIDATOR_PASS' } else { $missingPrereqs += 'LIVE_LIKE_GATE_VALIDATOR_PASS' }
if($liveLike -and $liveLike.observation.duration_seconds -ge $MinLiveLikeDurationSeconds){ $passedPrereqs += 'LIVE_LIKE_MIN_DURATION_PASS' } else { $missingPrereqs += 'LIVE_LIKE_MIN_DURATION_PASS' }
if($liveLike -and $liveLike.observation.heartbeat_count -ge $MinHeartbeats){ $passedPrereqs += 'LIVE_LIKE_MIN_HEARTBEATS_PASS' } else { $missingPrereqs += 'LIVE_LIKE_MIN_HEARTBEATS_PASS' }
if($liveLike -and @($liveLike.observation.watchdog_violations).Count -eq 0){ $passedPrereqs += 'LIVE_LIKE_WATCHDOG_CLEAN' } else { $missingPrereqs += 'LIVE_LIKE_WATCHDOG_CLEAN' }
if($liveLike -and $liveLike.parallel_harness.packet_status -eq 'PASS_AGENTLIFE_PACKET_SUBMITTED_SCHOOL_ACTIVE_BACKOFF'){ $passedPrereqs += 'AGENTLIFE_PACKET_BACKOFF_PASS' } else { $missingPrereqs += 'AGENTLIFE_PACKET_BACKOFF_PASS' }
if($liveLike -and $liveLike.parallel_harness.intake_status -eq 'PASS_MULTI_SOURCE_COMPACT_MEMORY_INTAKE_SUBMIT_V1'){ $passedPrereqs += 'COMPACT_MEMORY_INTAKE_PASS' } else { $missingPrereqs += 'COMPACT_MEMORY_INTAKE_PASS' }
if($liveLike -and $liveLike.parallel_harness.merge_after_school_status -eq 'PASS_MULTI_SOURCE_COMPACT_MEMORY_MERGE_QUEUE_V1'){ $passedPrereqs += 'POST_SCHOOL_MERGE_PASS' } else { $missingPrereqs += 'POST_SCHOOL_MERGE_PASS' }
if($stopfileContractValidationStatus -eq 'PASS_DETACHED_LONG_RUNTIME_STOPFILE_CONTRACT_V1' -and $stopfileContractValidationExit -eq 0){ $passedPrereqs += 'DETACHED_LONG_RUNTIME_STOPFILE_CONTRACT_PASS' } else { $missingPrereqs += 'DETACHED_LONG_RUNTIME_STOPFILE_CONTRACT_PASS' }
if($rollbackContractValidationStatus -eq 'PASS_LIVE_ROLLBACK_CONTRACT_V1' -and $rollbackContractValidationExit -eq 0){ $passedPrereqs += 'LIVE_ROLLBACK_CONTRACT_PASS' } else { $missingPrereqs += 'LIVE_ROLLBACK_CONTRACT_PASS' }
if($rejectContractValidationStatus -eq 'PASS_LIVE_REJECT_AND_FORGET_CONTRACT_V1' -and $rejectContractValidationExit -eq 0){ $passedPrereqs += 'LIVE_REJECT_AND_FORGET_CONTRACT_PASS' } else { $missingPrereqs += 'LIVE_REJECT_AND_FORGET_CONTRACT_PASS' }
$goBlockers=@()
if(-not $OwnerLiveAuthorization){ $goBlockers += 'OWNER_LIVE_AUTHORIZATION_MISSING' }
if($liveLike -and $liveLike.runtime_ready -ne $true){ $goBlockers += 'PRIOR_PROOF_RUNTIME_READY_FALSE' }
if($rollbackContractValidationStatus -ne 'PASS_LIVE_ROLLBACK_CONTRACT_V1' -or $rollbackContractValidationExit -ne 0){ $goBlockers += 'LIVE_ROLLBACK_PLAN_NOT_PROVEN' }
if($rejectContractValidationStatus -ne 'PASS_LIVE_REJECT_AND_FORGET_CONTRACT_V1' -or $rejectContractValidationExit -ne 0){ $goBlockers += 'LIVE_QUARANTINE_PLAN_NOT_PROVEN' }
if($stopfileContractValidationStatus -ne 'PASS_DETACHED_LONG_RUNTIME_STOPFILE_CONTRACT_V1' -or $stopfileContractValidationExit -ne 0){ $goBlockers += 'DETACHED_LONG_RUNTIME_STOPFILE_CONTRACT_NOT_PROVEN' }
$goBlockers += 'LIVE_CONTINUOUS_RUNTIME_NOT_PROVEN'
$gateBlockers=@(); if($missingPrereqs.Count -gt 0){ $gateBlockers += @($missingPrereqs) }
$liveReady=($gateBlockers.Count -eq 0 -and $goBlockers.Count -eq 0)
$decision='NO_GO_LIVE_READINESS_BLOCKED'; $status='PASS_SCHOOL_AIMO_LIVE_READINESS_GATE_NO_GO_V1'
if($liveReady){ $decision='GO_LIVE_READY'; $status='PASS_SCHOOL_AIMO_LIVE_READINESS_GATE_GO_V1' }
if($gateBlockers.Count -gt 0){ $decision='GATE_INVALID_PREREQ_FAILED'; $status='FAIL_SCHOOL_AIMO_LIVE_READINESS_GATE_V1' }
$result=[ordered]@{
  schema='school_aimo_live_readiness_gate_v1'
  status=$status
  proof_label='PROVEN_LAB_LIVE_READINESS_GATE_DECISION_NOT_LIVE_EXECUTION'
  decision=$decision
  live_ready=$liveReady
  repo=[ordered]@{ root=($RepoRoot -replace '\\','/'); branch=$branch; head=$head; origin=$origin; ahead_behind=$aheadBehind; dirty_before=@($dirtyBefore); active_process_count=$processes.Count }
  checks=[ordered]@{ passed=@($passedPrereqs); missing=@($missingPrereqs); go_blockers=@($goBlockers); map_status=$mapStatus; map_exit=$mapExit; live_like_validation_status=$liveLikeValidationStatus; live_like_validation_exit=$liveLikeValidationExit; stopfile_contract_validation_status=$stopfileContractValidationStatus; stopfile_contract_validation_exit=$stopfileContractValidationExit; rollback_contract_validation_status=$rollbackContractValidationStatus; rollback_contract_validation_exit=$rollbackContractValidationExit; reject_contract_validation_status=$rejectContractValidationStatus; reject_contract_validation_exit=$rejectContractValidationExit; proof_checks=$proofChecks }
  required_next_to_be_live_ready=@('explicit Owner live authorization','continuous runtime proof with live boundary, not lab controlled-stop')
  boundary='Readiness decision only. This gate does not launch live runtime. NO-GO is a valid safe pass when prerequisites are proven but live blockers remain.'
  runtime_ready=$false
  started_at=$startedAt.ToString('o')
  finished_at=(Get-Date).ToString('o')
}
WriteJson $ProofPath $result
Write-Host "LIVE_READINESS_GATE_STATUS=$($result.status)"
Write-Host "LIVE_READINESS_DECISION=$($result.decision)"
Write-Host "LIVE_READY=$($result.live_ready)"
Write-Host "GATE_BLOCKERS=$($gateBlockers -join ',')"
Write-Host "GO_BLOCKERS=$($goBlockers -join ',')"
Write-Host "ROLLBACK_CONTRACT_VALIDATION=$rollbackContractValidationStatus"
Write-Host "PROOF=$ProofPath"
Write-Host 'RUNTIME_READY=false'
if($status -like 'FAIL_*'){ exit 1 }