param(
  [int]$MinObservationSeconds = 60,
  [int]$HeartbeatSeconds = 10,
  [int]$SchoolCount = 10000,
  [int]$MinAimoCycles = 2,
  [int]$MaxWaitSeconds = 240,
  [string]$ProofPath = 'tests/live_like/SCHOOL_AIMO_LIVE_LIKE_OBSERVATION_GATE_V1_PROOF.json'
)
$ErrorActionPreference='Stop'
$RepoRoot=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
Set-Location $RepoRoot
function GitStatusShort(){ @(git status --short --untracked-files=all) }
function WriteJson($Path,$Obj){ New-Item -ItemType Directory -Force -Path (Split-Path $Path -Parent) | Out-Null; $Obj | ConvertTo-Json -Depth 30 | Set-Content -Path $Path -Encoding UTF8 }
function ReadJsonSafe($Path){ if(Test-Path $Path){ try { return (Get-Content $Path -Raw | ConvertFrom-Json) } catch { return $null } }; return $null }
function GetRelevantProcesses(){
  @(Get-CimInstance Win32_Process -ErrorAction SilentlyContinue | Where-Object {
    -not [string]::IsNullOrWhiteSpace([string]$_.CommandLine) -and (
      [string]$_.CommandLine -like '*run_school_aimo_parallel_lab_v1.ps1*' -or
      [string]$_.CommandLine -like '*run_agent_school.ps1*' -or
      [string]$_.CommandLine -like '*run_autonomous_inner_motor.ps1*'
    )
  })
}
$startedAt=Get-Date
$branch=(git branch --show-current).Trim()
$head=(git rev-parse HEAD).Trim()
$origin=(git remote get-url origin).Trim()
$dirtyBefore=GitStatusShort
if(($RepoRoot -replace '\\','/') -ne 'H:/efab'){ throw "REPO_ROOT_MISMATCH:$RepoRoot" }
if($branch -ne 'main'){ throw "BRANCH_MISMATCH:$branch" }
if($origin -ne 'https://github.com/ries11217596955-hash/efab.git'){ throw "ORIGIN_MISMATCH:$origin" }
if($dirtyBefore.Count -gt 0){ throw "DIRTY_BEFORE_LIVE_LIKE_GATE:$($dirtyBefore -join ';')" }
$conflicts=GetRelevantProcesses
if($conflicts.Count -gt 0){ throw "ACTIVE_PROCESS_CONFLICT:$($conflicts.Count)" }
$RunId='school_aimo_live_like_observation_gate_v1_' + (Get-Date).ToUniversalTime().ToString('yyyyMMddTHHmmssZ')
$RunRoot=Join-Path '.runtime/live_like' $RunId
New-Item -ItemType Directory -Force -Path $RunRoot | Out-Null
$childOut=Join-Path $RunRoot 'parallel_harness.stdout.txt'
$childErr=Join-Path $RunRoot 'parallel_harness.stderr.txt'
$parallelProof=Join-Path $RunRoot 'parallel_harness_proof.json'
$childArgs=@('-NoProfile','-ExecutionPolicy','Bypass','-File','operations/parallel_life/run_school_aimo_parallel_lab_v1.ps1','-SchoolCount',[string]$SchoolCount,'-MinAimoCycles',[string]$MinAimoCycles,'-MaxWaitSeconds',[string]$MaxWaitSeconds,'-ProofPath',$parallelProof)
$child=Start-Process -FilePath 'powershell' -ArgumentList $childArgs -RedirectStandardOutput $childOut -RedirectStandardError $childErr -PassThru -WindowStyle Hidden
Write-Host "LIVE_LIKE_CHILD_STARTED_PID=$($child.Id) RUN_ID=$RunId"
$heartbeats=@()
$watchdogViolations=@()
$lastBeat=Get-Date
$childExitedAt=$null
while($true){
  Start-Sleep -Seconds $HeartbeatSeconds
  $now=Get-Date
  try { $child.Refresh() } catch {}
  $processes=GetRelevantProcesses
  $parallelProofObj=ReadJsonSafe $parallelProof
  $aimoCycles=$null
  $packetStatus=$null
  $intakeStatus=$null
  $mergeStatus=$null
  if($parallelProofObj){
    $aimoCycles=$parallelProofObj.aimo.cycles
    $packetStatus=$parallelProofObj.intake_merge.agentlife_packet.status
    $intakeStatus=$parallelProofObj.intake_merge.agentlife_packet.intake_status
    $mergeStatus=$parallelProofObj.intake_merge.merge_after_school.status
  }
  $beat=[ordered]@{
    at=$now.ToString('o')
    elapsed_seconds=[Math]::Round(($now-$startedAt).TotalSeconds,3)
    child_alive=(-not $child.HasExited)
    relevant_process_count=$processes.Count
    proof_seen=($null -ne $parallelProofObj)
    aimo_cycles=$aimoCycles
    packet_status=$packetStatus
    intake_status=$intakeStatus
    merge_after_school_status=$mergeStatus
  }
  $heartbeats += $beat
  Write-Host ("HEARTBEAT elapsed={0} child_alive={1} process_count={2} proof_seen={3} cycles={4}" -f $beat.elapsed_seconds,$beat.child_alive,$beat.relevant_process_count,$beat.proof_seen,$beat.aimo_cycles)
  if((($now-$lastBeat).TotalSeconds) -gt ($HeartbeatSeconds + 5)){ $watchdogViolations += "HEARTBEAT_GAP_SECONDS_$([Math]::Round(($now-$lastBeat).TotalSeconds,3))" }
  $lastBeat=$now
  if($child.HasExited){ $childExitedAt=$now; break }
  if((($now-$startedAt).TotalSeconds) -gt ($MaxWaitSeconds + 120)){
    try { Stop-Process -Id $child.Id -Force -ErrorAction SilentlyContinue } catch {}
    $watchdogViolations += 'CHILD_TIMEOUT_FORCE_STOP'
    break
  }
}
$durationSeconds=[Math]::Round(((Get-Date)-$startedAt).TotalSeconds,3)
$childExit=0; try { if($null -ne $child.ExitCode){ $childExit=[int]$child.ExitCode } } catch { $childExit=1 }
$parallelProofObj=ReadJsonSafe $parallelProof
$parallelValidationStatus='NOT_ATTEMPTED'
$parallelValidationExit=$null
$parallelValidationOut=@()
if($parallelProofObj){
  $parallelValidationOut=@(& powershell -NoProfile -ExecutionPolicy Bypass -File operations/parallel_life/validate_school_aimo_parallel_lab_v1.ps1 -ProofPath $parallelProof *>&1 | ForEach-Object {[string]$_})
  $parallelValidationExit=$LASTEXITCODE
  $parallelValidationStatus=(($parallelValidationOut | Where-Object { $_ -match '^VALIDATION_PASS=' } | Select-Object -Last 1) -replace '^VALIDATION_PASS=','')
}
$dirtyAfter=GitStatusShort
$blockers=@()
if($childExit -ne 0){ $blockers += "CHILD_EXIT_$childExit" }
if($durationSeconds -lt $MinObservationSeconds){ $blockers += "OBSERVATION_TOO_SHORT:$durationSeconds<$MinObservationSeconds" }
if($heartbeats.Count -lt 2){ $blockers += "INSUFFICIENT_HEARTBEATS:$($heartbeats.Count)" }
if($watchdogViolations.Count -gt 0){ $blockers += "WATCHDOG_VIOLATIONS:$($watchdogViolations -join '|')" }
if(-not $parallelProofObj){ $blockers += 'PARALLEL_PROOF_MISSING' }
else {
  if($parallelProofObj.status -ne 'PASS_SCHOOL_AIMO_PARALLEL_LAB_V1'){ $blockers += "PARALLEL_STATUS_NOT_PASS:$($parallelProofObj.status)" }
  if($parallelProofObj.runtime_ready -ne $false){ $blockers += 'PARALLEL_RUNTIME_READY_BOUNDARY_MISMATCH' }
  if($parallelProofObj.intake_merge.agentlife_packet.intake_status -ne 'PASS_MULTI_SOURCE_COMPACT_MEMORY_INTAKE_SUBMIT_V1'){ $blockers += 'INTAKE_NOT_PASS' }
  if($parallelProofObj.intake_merge.merge_after_school.status -ne 'PASS_MULTI_SOURCE_COMPACT_MEMORY_MERGE_QUEUE_V1'){ $blockers += 'POST_SCHOOL_MERGE_NOT_PASS' }
}
if($parallelValidationExit -ne 0){ $blockers += "PARALLEL_VALIDATOR_EXIT_$parallelValidationExit" }
if($dirtyAfter.Count -gt 0){ $blockers += "DIRTY_AFTER_GATE:$($dirtyAfter -join ';')" }
$status='PASS_SCHOOL_AIMO_LIVE_LIKE_OBSERVATION_GATE_V1'
if($blockers.Count -gt 0){ $status='FAIL_SCHOOL_AIMO_LIVE_LIKE_OBSERVATION_GATE_V1' }
$result=[ordered]@{
  schema='school_aimo_live_like_observation_gate_v1'
  status=$status
  proof_label='PROVEN_LAB_LIVE_LIKE_OBSERVATION_NOT_LIVE_READY'
  run_id=$RunId
  repo=[ordered]@{ root=($RepoRoot -replace '\\','/'); branch=$branch; head=$head; origin=$origin; dirty_before=@($dirtyBefore); dirty_after=@($dirtyAfter) }
  observation=[ordered]@{ min_required_seconds=$MinObservationSeconds; duration_seconds=$durationSeconds; heartbeat_seconds=$HeartbeatSeconds; heartbeat_count=$heartbeats.Count; child_pid=$child.Id; child_exit=$childExit; child_exited_at=if($childExitedAt){$childExitedAt.ToString('o')}else{$null}; watchdog_violations=@($watchdogViolations); heartbeats=@($heartbeats) }
  parallel_harness=[ordered]@{ proof_path=$parallelProof; stdout_path=$childOut; stderr_path=$childErr; validation_status=$parallelValidationStatus; validation_exit=$parallelValidationExit; validation_output=@($parallelValidationOut); status=if($parallelProofObj){$parallelProofObj.status}else{$null}; aimo_cycles=if($parallelProofObj){$parallelProofObj.aimo.cycles}else{$null}; school_controlled_stop=if($parallelProofObj){$parallelProofObj.school.controlled_stop}else{$null}; packet_status=if($parallelProofObj){$parallelProofObj.intake_merge.agentlife_packet.status}else{$null}; intake_status=if($parallelProofObj){$parallelProofObj.intake_merge.agentlife_packet.intake_status}else{$null}; merge_after_school_status=if($parallelProofObj){$parallelProofObj.intake_merge.merge_after_school.status}else{$null}; runtime_ready=if($parallelProofObj){$parallelProofObj.runtime_ready}else{$null} }
  blockers=@($blockers)
  started_at=$startedAt.ToString('o')
  finished_at=(Get-Date).ToString('o')
  boundary='Live-like lab observation gate only: heartbeat/watchdog/duration around repeatable School+AIMO parallel harness. Not live readiness and not continuous autonomous runtime.'
  runtime_ready=$false
}
WriteJson $ProofPath $result
Write-Host "LIVE_LIKE_GATE_STATUS=$($result.status)"
Write-Host "LIVE_LIKE_GATE_PROOF=$ProofPath"
Write-Host "LIVE_LIKE_GATE_DURATION_SECONDS=$durationSeconds"
Write-Host "LIVE_LIKE_GATE_HEARTBEATS=$($heartbeats.Count)"
Write-Host "LIVE_LIKE_GATE_PARALLEL_STATUS=$($result.parallel_harness.status)"
Write-Host "LIVE_LIKE_GATE_PARALLEL_VALIDATION=$parallelValidationStatus"
Write-Host "LIVE_LIKE_GATE_BLOCKERS=$($blockers -join ',')"
Write-Host "RUNTIME_READY=false"
if($status -notlike 'PASS_*'){ exit 1 }