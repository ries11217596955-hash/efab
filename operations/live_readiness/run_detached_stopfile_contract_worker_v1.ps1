param(
  [Parameter(Mandatory=$true)][string]$RunRoot,
  [Parameter(Mandatory=$true)][string]$StopFile,
  [Parameter(Mandatory=$true)][string]$HeartbeatPath,
  [Parameter(Mandatory=$true)][string]$ExitProofPath,
  [int]$HeartbeatSeconds = 2,
  [int]$MaxRunSeconds = 120
)
$ErrorActionPreference='Stop'
function WriteJson($Path,$Obj){ New-Item -ItemType Directory -Force -Path (Split-Path $Path -Parent) | Out-Null; $Obj | ConvertTo-Json -Depth 20 | Set-Content -Path $Path -Encoding UTF8 }
$started=Get-Date
$heartbeatCount=0
$stopSeen=$false
$exitReason='UNKNOWN'
try {
  New-Item -ItemType Directory -Force -Path $RunRoot | Out-Null
  while($true){
    $now=Get-Date
    $heartbeatCount++
    $hb=[ordered]@{
      schema='detached_stopfile_worker_heartbeat_v1'
      pid=$PID
      heartbeat_count=$heartbeatCount
      at=$now.ToString('o')
      elapsed_seconds=[Math]::Round(($now-$started).TotalSeconds,3)
      stopfile_seen=(Test-Path $StopFile)
      active_memory_mutated=$false
    }
    WriteJson $HeartbeatPath $hb
    if(Test-Path $StopFile){
      $stopSeen=$true
      $exitReason='STOPFILE_OBSERVED'
      break
    }
    if((($now-$started).TotalSeconds) -ge $MaxRunSeconds){
      $exitReason='MAX_RUN_SECONDS_REACHED'
      break
    }
    Start-Sleep -Seconds $HeartbeatSeconds
  }
  $finished=Get-Date
  $proof=[ordered]@{
    schema='detached_stopfile_worker_exit_v1'
    status=if($stopSeen){'PASS_DETACHED_STOPFILE_WORKER_EXIT_V1'}else{'FAIL_DETACHED_STOPFILE_WORKER_EXIT_V1'}
    pid=$PID
    exit_reason=$exitReason
    stopfile_seen=$stopSeen
    stopfile_path=$StopFile
    heartbeat_path=$HeartbeatPath
    heartbeat_count=$heartbeatCount
    started_at=$started.ToString('o')
    finished_at=$finished.ToString('o')
    duration_seconds=[Math]::Round(($finished-$started).TotalSeconds,3)
    active_memory_mutated=$false
    runtime_ready=$false
  }
  WriteJson $ExitProofPath $proof
  if($stopSeen){ exit 0 } else { exit 1 }
} catch {
  $finished=Get-Date
  $proof=[ordered]@{
    schema='detached_stopfile_worker_exit_v1'
    status='FAIL_DETACHED_STOPFILE_WORKER_EXCEPTION_V1'
    pid=$PID
    error=$_.Exception.Message
    stopfile_seen=$stopSeen
    heartbeat_count=$heartbeatCount
    started_at=$started.ToString('o')
    finished_at=$finished.ToString('o')
    runtime_ready=$false
  }
  WriteJson $ExitProofPath $proof
  exit 1
}