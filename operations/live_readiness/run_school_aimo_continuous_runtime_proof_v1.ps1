param(
  [int]$MinContinuousSeconds = 180,
  [int]$HeartbeatSeconds = 10,
  [int]$SchoolCount = 12000,
  [int]$MinAimoCycles = 2,
  [int]$MaxWaitSeconds = 360,
  [string]$ProofPath = 'tests/live_readiness/SCHOOL_AIMO_CONTINUOUS_RUNTIME_PROOF_V1_PROOF.json',
  [string]$ChildLiveLikeProofPath = 'tests/live_readiness/SCHOOL_AIMO_CONTINUOUS_RUNTIME_PROOF_V1_LIVE_LIKE_CHILD_PROOF.json'
)
$ErrorActionPreference='Stop'
$RepoRoot=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
Set-Location $RepoRoot
function GitStatusShort(){ @(git status --short --untracked-files=all) }
function WriteJson($Path,$Obj){ New-Item -ItemType Directory -Force -Path (Split-Path $Path -Parent) | Out-Null; $Obj | ConvertTo-Json -Depth 40 | Set-Content -Path $Path -Encoding UTF8 }
function ReadJson($Path){ if(-not(Test-Path $Path)){ return $null }; return (Get-Content $Path -Raw | ConvertFrom-Json) }
function RuntimeProcesses(){
  @(Get-CimInstance Win32_Process -ErrorAction SilentlyContinue | Where-Object {
    -not [string]::IsNullOrWhiteSpace([string]$_.CommandLine) -and (
      [string]$_.CommandLine -like '*run_agent_school.ps1*' -or
      [string]$_.CommandLine -like '*run_autonomous_inner_motor.ps1*' -or
      [string]$_.CommandLine -like '*run_school_aimo_parallel_lab_v1.ps1*' -or
      [string]$_.CommandLine -like '*run_school_aimo_live_like_observation_gate_v1.ps1*'
    )
  })
}
$started=Get-Date
$branch=(git branch --show-current).Trim()
$head=(git rev-parse HEAD).Trim()
$origin=(git remote get-url origin).Trim()
git fetch origin main --quiet
$aheadBehind=(git rev-list --left-right --count HEAD...origin/main).Trim()
$aheadBehindNorm=($aheadBehind -replace '\s+',' ')
$dirtyBefore=GitStatusShort
if(($RepoRoot -replace '\\','/') -ne 'H:/efab'){ throw "REPO_ROOT_MISMATCH:$RepoRoot" }
if($branch -ne 'main'){ throw "BRANCH_MISMATCH:$branch" }
if($origin -ne 'https://github.com/ries11217596955-hash/efab.git'){ throw "ORIGIN_MISMATCH:$origin" }
if($aheadBehindNorm -ne '0 0'){ throw "AHEAD_BEHIND_NOT_SYNCED:$aheadBehind" }
if($dirtyBefore.Count -gt 0){ throw "DIRTY_BEFORE_CONTINUOUS_RUNTIME_PROOF:$($dirtyBefore -join ';')" }
$activeBefore=@(RuntimeProcesses)
if($activeBefore.Count -gt 0){ throw "ACTIVE_RUNTIME_PROCESS_CONFLICT:$($activeBefore.Count)" }
$stopfileValidationOut=@(& powershell -NoProfile -ExecutionPolicy Bypass -File operations/live_readiness/validate_detached_long_runtime_stopfile_contract_v1.ps1 -ProofPath tests/live_readiness/DETACHED_LONG_RUNTIME_STOPFILE_CONTRACT_V1_PROOF.json *>&1 | ForEach-Object {[string]$_})
$stopfileValidationExit=$LASTEXITCODE
$stopfileValidationStatus=(($stopfileValidationOut | Where-Object { $_ -match '^VALIDATION_PASS=' } | Select-Object -Last 1) -replace '^VALIDATION_PASS=','')
$rollbackValidationOut=@(& powershell -NoProfile -ExecutionPolicy Bypass -File operations/live_readiness/validate_live_rollback_contract_v1.ps1 -ProofPath tests/live_readiness/LIVE_ROLLBACK_CONTRACT_V1_PROOF.json *>&1 | ForEach-Object {[string]$_})
$rollbackValidationExit=$LASTEXITCODE
$rollbackValidationStatus=(($rollbackValidationOut | Where-Object { $_ -match '^VALIDATION_PASS=' } | Select-Object -Last 1) -replace '^VALIDATION_PASS=','')
$rejectValidationOut=@(& powershell -NoProfile -ExecutionPolicy Bypass -File operations/live_readiness/validate_live_reject_and_forget_contract_v1.ps1 -ProofPath tests/live_readiness/LIVE_REJECT_AND_FORGET_CONTRACT_V1_PROOF.json *>&1 | ForEach-Object {[string]$_})
$rejectValidationExit=$LASTEXITCODE
$rejectValidationStatus=(($rejectValidationOut | Where-Object { $_ -match '^VALIDATION_PASS=' } | Select-Object -Last 1) -replace '^VALIDATION_PASS=','')
$liveLikeOut=@(& powershell -NoProfile -ExecutionPolicy Bypass -File operations/live_like/run_school_aimo_live_like_observation_gate_v1.ps1 -MinObservationSeconds $MinContinuousSeconds -HeartbeatSeconds $HeartbeatSeconds -SchoolCount $SchoolCount -MinAimoCycles $MinAimoCycles -MaxWaitSeconds $MaxWaitSeconds -ProofPath $ChildLiveLikeProofPath *>&1 | ForEach-Object {[string]$_})
$liveLikeExit=$LASTEXITCODE
$liveLikeObj=ReadJson $ChildLiveLikeProofPath
$liveLikeValidationOut=@(& powershell -NoProfile -ExecutionPolicy Bypass -File operations/live_like/validate_school_aimo_live_like_observation_gate_v1.ps1 -ProofPath $ChildLiveLikeProofPath *>&1 | ForEach-Object {[string]$_})
$liveLikeValidationExit=$LASTEXITCODE
$liveLikeValidationStatus=(($liveLikeValidationOut | Where-Object { $_ -match '^VALIDATION_PASS=' } | Select-Object -Last 1) -replace '^VALIDATION_PASS=','')
$activeAfter=@(RuntimeProcesses)
$dirtyAfter=GitStatusShort
$childWatchdogViolations=@()
if($liveLikeObj -and $liveLikeObj.observation -and $null -ne $liveLikeObj.observation.watchdog_violations){
  foreach($w in @($liveLikeObj.observation.watchdog_violations)){
    if($null -eq $w){ continue }
    $wj=($w | ConvertTo-Json -Compress)
    if([string]::IsNullOrWhiteSpace([string]$wj) -or $wj -eq '{}' -or $wj -eq 'null'){ continue }
    $childWatchdogViolations += $w
  }
}
$blockers=@()
if($stopfileValidationStatus -ne 'PASS_DETACHED_LONG_RUNTIME_STOPFILE_CONTRACT_V1' -or $stopfileValidationExit -ne 0){ $blockers += 'STOPFILE_CONTRACT_NOT_PASS' }
if($rollbackValidationStatus -ne 'PASS_LIVE_ROLLBACK_CONTRACT_V1' -or $rollbackValidationExit -ne 0){ $blockers += 'ROLLBACK_CONTRACT_NOT_PASS' }
if($rejectValidationStatus -ne 'PASS_LIVE_REJECT_AND_FORGET_CONTRACT_V1' -or $rejectValidationExit -ne 0){ $blockers += 'REJECT_AND_FORGET_CONTRACT_NOT_PASS' }
if($liveLikeExit -ne 0){ $blockers += "LIVE_LIKE_EXIT_$liveLikeExit" }
if(-not $liveLikeObj){ $blockers += 'LIVE_LIKE_CHILD_PROOF_MISSING' } else {
  if($liveLikeObj.status -ne 'PASS_SCHOOL_AIMO_LIVE_LIKE_OBSERVATION_GATE_V1'){ $blockers += "LIVE_LIKE_STATUS_NOT_PASS:$($liveLikeObj.status)" }
  if($liveLikeObj.observation.duration_seconds -lt $MinContinuousSeconds){ $blockers += "CONTINUOUS_DURATION_TOO_SHORT:$($liveLikeObj.observation.duration_seconds)<$MinContinuousSeconds" }
  if($liveLikeObj.observation.heartbeat_count -lt 2){ $blockers += 'INSUFFICIENT_CONTINUOUS_HEARTBEATS' }
  if($childWatchdogViolations.Count -gt 0){ $blockers += 'CONTINUOUS_WATCHDOG_VIOLATIONS' }
  if($liveLikeObj.parallel_harness.status -ne 'PASS_SCHOOL_AIMO_PARALLEL_LAB_V1'){ $blockers += 'PARALLEL_CHILD_NOT_PASS' }
  if($liveLikeObj.parallel_harness.packet_status -ne 'PASS_AGENTLIFE_PACKET_SUBMITTED_SCHOOL_ACTIVE_BACKOFF'){ $blockers += 'AGENTLIFE_PACKET_NOT_PASS' }
  if($liveLikeObj.parallel_harness.intake_status -ne 'PASS_MULTI_SOURCE_COMPACT_MEMORY_INTAKE_SUBMIT_V1'){ $blockers += 'INTAKE_NOT_PASS' }
  if($liveLikeObj.parallel_harness.merge_after_school_status -ne 'PASS_MULTI_SOURCE_COMPACT_MEMORY_MERGE_QUEUE_V1'){ $blockers += 'MERGE_AFTER_SCHOOL_NOT_PASS' }
}
if($liveLikeValidationStatus -ne 'PASS_SCHOOL_AIMO_LIVE_LIKE_OBSERVATION_GATE_V1' -or $liveLikeValidationExit -ne 0){ $blockers += 'LIVE_LIKE_VALIDATOR_NOT_PASS' }
if($activeAfter.Count -gt 0){ $blockers += "RUNTIME_PROCESS_LEFT_ACTIVE:$($activeAfter.Count)" }
$allowedDirty=@($ChildLiveLikeProofPath -replace '/','\')
$unexpectedDirty=@()
foreach($d in $dirtyAfter){
  $path=($d.Substring(3) -replace '/','\')
  if($allowedDirty -notcontains $path){ $unexpectedDirty += $d }
}
if($unexpectedDirty.Count -gt 0){ $blockers += "UNEXPECTED_DIRTY_AFTER_CHILD:$($unexpectedDirty -join ';')" }
$status='PASS_SCHOOL_AIMO_CONTINUOUS_RUNTIME_PROOF_V1'
$technicalRuntimeReady=$true
if($blockers.Count -gt 0){ $status='FAIL_SCHOOL_AIMO_CONTINUOUS_RUNTIME_PROOF_V1'; $technicalRuntimeReady=$false }
$result=[ordered]@{
  schema='school_aimo_continuous_runtime_proof_v1'
  status=$status
  proof_label='PROVEN_LAB_SUPERVISED_CONTINUOUS_RUNTIME_READY_CANDIDATE_NOT_OWNER_LIVE'
  run_id='school_aimo_continuous_runtime_proof_v1_' + (Get-Date).ToUniversalTime().ToString('yyyyMMddTHHmmssZ')
  repo=[ordered]@{ root=($RepoRoot -replace '\\','/'); branch=$branch; head=$head; origin=$origin; ahead_behind=$aheadBehind; dirty_before=@($dirtyBefore); dirty_after_before_proof_write=@($dirtyAfter); active_processes_before=$activeBefore.Count; active_processes_after=$activeAfter.Count }
  safety_contracts=[ordered]@{ stopfile_status=$stopfileValidationStatus; stopfile_exit=$stopfileValidationExit; rollback_status=$rollbackValidationStatus; rollback_exit=$rollbackValidationExit; reject_and_forget_status=$rejectValidationStatus; reject_and_forget_exit=$rejectValidationExit }
  continuous_observation=[ordered]@{ min_required_seconds=$MinContinuousSeconds; heartbeat_seconds=$HeartbeatSeconds; child_proof_path=$ChildLiveLikeProofPath; child_status=if($liveLikeObj){$liveLikeObj.status}else{$null}; duration_seconds=if($liveLikeObj){$liveLikeObj.observation.duration_seconds}else{$null}; heartbeat_count=if($liveLikeObj){$liveLikeObj.observation.heartbeat_count}else{$null}; watchdog_violations=@($childWatchdogViolations); child_exit=if($liveLikeObj){$liveLikeObj.observation.child_exit}else{$null}; live_like_validation_status=$liveLikeValidationStatus; live_like_validation_exit=$liveLikeValidationExit }
  parallel_runtime=[ordered]@{ school_plus_aimo_status=if($liveLikeObj){$liveLikeObj.parallel_harness.status}else{$null}; aimo_cycles=if($liveLikeObj){$liveLikeObj.parallel_harness.aimo_cycles}else{$null}; school_controlled_stop=if($liveLikeObj){$liveLikeObj.parallel_harness.school_controlled_stop}else{$null}; packet_status=if($liveLikeObj){$liveLikeObj.parallel_harness.packet_status}else{$null}; intake_status=if($liveLikeObj){$liveLikeObj.parallel_harness.intake_status}else{$null}; merge_after_school_status=if($liveLikeObj){$liveLikeObj.parallel_harness.merge_after_school_status}else{$null} }
  technical_runtime_ready=$technicalRuntimeReady
  owner_live_authorized=$false
  live_ready=$false
  blockers=@($blockers)
  boundary='Supervised bounded continuous runtime proof only. Technical runtime-ready candidate when PASS, but not owner-authorized live execution and not PROVEN_LIVE.'
  runtime_ready=$technicalRuntimeReady
  started_at=$started.ToString('o')
  finished_at=(Get-Date).ToString('o')
}
WriteJson $ProofPath $result
Write-Host "CONTINUOUS_RUNTIME_STATUS=$status"
Write-Host "CONTINUOUS_RUNTIME_PROOF=$ProofPath"
Write-Host "TECHNICAL_RUNTIME_READY=$technicalRuntimeReady"
Write-Host "LIVE_READY=false"
Write-Host "DURATION=$($result.continuous_observation.duration_seconds)"
Write-Host "HEARTBEATS=$($result.continuous_observation.heartbeat_count)"
Write-Host "AIMO_CYCLES=$($result.parallel_runtime.aimo_cycles)"
Write-Host "BLOCKERS=$($blockers -join ',')"
if($status -notlike 'PASS_*'){ exit 1 }