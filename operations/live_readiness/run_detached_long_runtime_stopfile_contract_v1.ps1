param(
  [int]$MinHeartbeatCount = 3,
  [int]$HeartbeatSeconds = 2,
  [int]$StopGraceSeconds = 20,
  [int]$MaxWaitSeconds = 120,
  [string]$ProofPath = 'tests/live_readiness/DETACHED_LONG_RUNTIME_STOPFILE_CONTRACT_V1_PROOF.json'
)
$ErrorActionPreference='Stop'
$RepoRoot=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
Set-Location $RepoRoot
function GitStatusShort(){ @(git status --short --untracked-files=all) }
function WriteJson($Path,$Obj){ New-Item -ItemType Directory -Force -Path (Split-Path $Path -Parent) | Out-Null; $Obj | ConvertTo-Json -Depth 30 | Set-Content -Path $Path -Encoding UTF8 }
function ReadJsonSafe($Path){ if(Test-Path $Path){ try { return (Get-Content $Path -Raw | ConvertFrom-Json) } catch { return $null } }; return $null }
function GetContractProcesses(){
  @(Get-CimInstance Win32_Process -ErrorAction SilentlyContinue | Where-Object {
    -not [string]::IsNullOrWhiteSpace([string]$_.CommandLine) -and
    [string]$_.CommandLine -like '*run_detached_stopfile_contract_worker_v1.ps1*'
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
if($dirtyBefore.Count -gt 0){ throw "DIRTY_BEFORE_DETACHED_STOPFILE_CONTRACT:$($dirtyBefore -join ';')" }
$existing=@(GetContractProcesses)
if($existing.Count -gt 0){ throw "ACTIVE_DETACHED_STOPFILE_WORKER_CONFLICT:$($existing.Count)" }
$runId='detached_long_runtime_stopfile_contract_v1_' + (Get-Date).ToUniversalTime().ToString('yyyyMMddTHHmmssZ')
$runRoot=Join-Path '.runtime/live_readiness' $runId
New-Item -ItemType Directory -Force -Path $runRoot | Out-Null
$stopFile=Join-Path $runRoot 'STOP_REQUESTED.txt'
$heartbeatPath=Join-Path $runRoot 'heartbeat.json'
$exitProofPath=Join-Path $runRoot 'worker_exit_proof.json'
$stdoutPath=Join-Path $runRoot 'worker.stdout.txt'
$stderrPath=Join-Path $runRoot 'worker.stderr.txt'
$workerArgs=@('-NoProfile','-ExecutionPolicy','Bypass','-File','operations/live_readiness/run_detached_stopfile_contract_worker_v1.ps1','-RunRoot',$runRoot,'-StopFile',$stopFile,'-HeartbeatPath',$heartbeatPath,'-ExitProofPath',$exitProofPath,'-HeartbeatSeconds',[string]$HeartbeatSeconds,'-MaxRunSeconds',[string]$MaxWaitSeconds)
$worker=Start-Process -FilePath 'powershell' -ArgumentList $workerArgs -RedirectStandardOutput $stdoutPath -RedirectStandardError $stderrPath -PassThru -WindowStyle Hidden
Write-Host "DETACHED_WORKER_STARTED_PID=$($worker.Id) RUN_ID=$runId"
$heartbeatEvents=@()
$heartbeatReachedAt=$null
$startWait=Get-Date
while(((Get-Date)-$startWait).TotalSeconds -lt $MaxWaitSeconds){
  Start-Sleep -Seconds 1
  $hb=ReadJsonSafe $heartbeatPath
  if($hb){
    $heartbeatEvents += [ordered]@{ at=(Get-Date).ToString('o'); count=[int]$hb.heartbeat_count; elapsed_seconds=$hb.elapsed_seconds; stopfile_seen=$hb.stopfile_seen }
    if([int]$hb.heartbeat_count -ge $MinHeartbeatCount){ $heartbeatReachedAt=Get-Date; break }
  }
  try { $worker.Refresh() } catch {}
  if($worker.HasExited){ break }
}
if(-not $heartbeatReachedAt){ throw 'MIN_HEARTBEATS_NOT_REACHED_BEFORE_STOPFILE' }
$stopRequestedAt=Get-Date
Set-Content -Path $stopFile -Value "stop requested by $runId at $($stopRequestedAt.ToString('o'))" -Encoding UTF8
Write-Host "STOPFILE_WRITTEN=$stopFile"
$stoppedCleanly=$false
$stopDeadline=(Get-Date).AddSeconds($StopGraceSeconds)
while((Get-Date) -lt $stopDeadline){
  Start-Sleep -Milliseconds 500
  try { $worker.Refresh() } catch {}
  if($worker.HasExited){ $stoppedCleanly=$true; break }
}
if(-not $stoppedCleanly){
  try { Stop-Process -Id $worker.Id -Force -ErrorAction SilentlyContinue } catch {}
}
$finished=Get-Date
$workerExitProof=ReadJsonSafe $exitProofPath
$finalHeartbeat=ReadJsonSafe $heartbeatPath
$workerAlive=$false
try { $worker.Refresh(); $workerAlive=(-not $worker.HasExited) } catch { $workerAlive=$false }
$childExit=$null
try { if($null -ne $worker.ExitCode){ $childExit=[int]$worker.ExitCode } } catch {}
$blockers=@()
if(-not $stoppedCleanly){ $blockers += 'WORKER_DID_NOT_EXIT_WITHIN_STOP_GRACE' }
if($childExit -ne 0){ $blockers += "WORKER_EXIT_NOT_ZERO:$childExit" }
if(-not $workerExitProof){ $blockers += 'WORKER_EXIT_PROOF_MISSING' }
else {
  if($workerExitProof.status -ne 'PASS_DETACHED_STOPFILE_WORKER_EXIT_V1'){ $blockers += "WORKER_EXIT_STATUS_NOT_PASS:$($workerExitProof.status)" }
  if($workerExitProof.stopfile_seen -ne $true){ $blockers += 'WORKER_DID_NOT_SEE_STOPFILE' }
  if([int]$workerExitProof.heartbeat_count -lt $MinHeartbeatCount){ $blockers += 'WORKER_HEARTBEATS_TOO_LOW' }
}
$activeAfter=@(GetContractProcesses | Where-Object { [int]$_.ProcessId -eq [int]$worker.Id })
if($activeAfter.Count -gt 0 -or $workerAlive){ $blockers += 'WORKER_STILL_ACTIVE_AFTER_STOP' }
$dirtyAfter=GitStatusShort
$status='PASS_DETACHED_LONG_RUNTIME_STOPFILE_CONTRACT_V1'
if($blockers.Count -gt 0){ $status='FAIL_DETACHED_LONG_RUNTIME_STOPFILE_CONTRACT_V1' }
$result=[ordered]@{
  schema='detached_long_runtime_stopfile_contract_v1'
  status=$status
  proof_label='PROVEN_LAB_DETACHED_LONG_RUNTIME_STOPFILE_CONTRACT_NOT_LIVE'
  run_id=$runId
  repo=[ordered]@{ root=($RepoRoot -replace '\\','/'); branch=$branch; head=$head; origin=$origin; ahead_behind=$aheadBehind; dirty_before=@($dirtyBefore); dirty_after_before_proof_write=@($dirtyAfter) }
  detached_process=[ordered]@{ worker_pid=$worker.Id; child_exit=$childExit; started_at=$started.ToString('o'); stop_requested_at=$stopRequestedAt.ToString('o'); finished_at=$finished.ToString('o'); duration_seconds=[Math]::Round(($finished-$started).TotalSeconds,3); stopped_within_grace=$stoppedCleanly; stop_grace_seconds=$StopGraceSeconds; worker_alive_after_stop=$workerAlive }
  contract=[ordered]@{ run_root=$runRoot; stopfile_path=$stopFile; heartbeat_path=$heartbeatPath; exit_proof_path=$exitProofPath; stdout_path=$stdoutPath; stderr_path=$stderrPath; min_heartbeat_count=$MinHeartbeatCount; heartbeat_seconds=$HeartbeatSeconds; heartbeat_reached_at=$heartbeatReachedAt.ToString('o'); heartbeat_events=@($heartbeatEvents); final_heartbeat=$finalHeartbeat; worker_exit_proof=$workerExitProof }
  blockers=@($blockers)
  boundary='Lab contract proof only: detached worker emits heartbeat, observes stopfile, exits cleanly within grace. Not live runtime execution.'
  runtime_ready=$false
}
WriteJson $ProofPath $result
Write-Host "DETACHED_STOPFILE_CONTRACT_STATUS=$status"
Write-Host "DETACHED_STOPFILE_CONTRACT_PROOF=$ProofPath"
Write-Host "WORKER_PID=$($worker.Id)"
Write-Host "HEARTBEATS=$($workerExitProof.heartbeat_count)"
Write-Host "STOPPED_WITHIN_GRACE=$stoppedCleanly"
Write-Host "WORKER_EXIT=$childExit"
Write-Host "BLOCKERS=$($blockers -join ',')"
Write-Host 'RUNTIME_READY=false'
if($status -notlike 'PASS_*'){ exit 1 }