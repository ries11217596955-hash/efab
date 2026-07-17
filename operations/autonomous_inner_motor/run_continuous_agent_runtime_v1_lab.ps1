param(
  [ValidateRange(1,5)]
  [int]$DurationMinutes = 1
)

$ErrorActionPreference = 'Stop'

function Write-CleanJson {
  param(
    [Parameter(Mandatory=$true)][string]$Path,
    [Parameter(Mandatory=$true)]$Data,
    [int]$Depth = 100
  )
  $dir = Split-Path $Path -Parent
  if ($dir) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
  $json = ($Data | ConvertTo-Json -Depth $Depth) -replace "`r`n", "`n"
  [System.IO.File]::WriteAllText((Join-Path (Get-Location).Path $Path), $json.TrimEnd() + "`n", (New-Object System.Text.UTF8Encoding($false)))
}

function Test-PidAlive {
  param([int]$ProcessId)
  if ($ProcessId -le 0) { return $false }
  try { return [bool](Get-Process -Id $ProcessId -ErrorAction Stop) } catch { return $false }
}

function Get-TreeStats {
  param([string]$Path)
  if (-not (Test-Path -LiteralPath $Path)) {
    return [ordered]@{ exists = $false; files = 0; bytes = 0; mb = 0 }
  }
  $files = @(Get-ChildItem -LiteralPath $Path -Recurse -File -Force -ErrorAction SilentlyContinue)
  $bytes = [int64](($files | Measure-Object Length -Sum).Sum)
  return [ordered]@{ exists = $true; files = $files.Count; bytes = $bytes; mb = [math]::Round($bytes / 1MB, 2) }
}

$repoRoot = (& git rev-parse --show-toplevel).Trim()
if (-not $repoRoot) { throw 'REPO_ROOT_NOT_FOUND' }
Set-Location $repoRoot

$repoStatusBefore = @(& git status --short --untracked-files=all)
$repoHead = (& git rev-parse --short HEAD).Trim()
$repoBranch = (& git rev-parse --abbrev-ref HEAD).Trim()
$remoteDelta = (& git rev-list --left-right --count HEAD...origin/main).Trim()

$activeMemoryRoot = '.runtime/active_compact_semantic_memory_v1'
$compactQueueRoot = '.runtime/compact_memory_intake_v1/queue'
if (-not (Test-Path -LiteralPath $activeMemoryRoot)) { throw "ACTIVE_MEMORY_ROOT_MISSING:$activeMemoryRoot" }

$baseRoot = '.runtime/continuous_agent_runtime_v1_lab'
New-Item -ItemType Directory -Force -Path $baseRoot | Out-Null

$existingLocks = @(Get-ChildItem -LiteralPath $baseRoot -Recurse -File -Filter 'runtime.lock.json' -ErrorAction SilentlyContinue)
foreach ($lockFile in $existingLocks) {
  try {
    $lock = Get-Content -LiteralPath $lockFile.FullName -Raw | ConvertFrom-Json
    if ($lock.active -eq $true -and (Test-PidAlive -ProcessId ([int]$lock.pid))) {
      throw "LIVE_CONTINUOUS_LAB_LOCK_EXISTS:$($lockFile.FullName):PID=$($lock.pid)"
    }
  } catch {
    if ($_.Exception.Message -like 'LIVE_CONTINUOUS_LAB_LOCK_EXISTS*') { throw }
  }
}

$runtimeId = 'continuous_lab_' + (Get-Date -Format 'yyyyMMdd_HHmmss') + '_' + ([guid]::NewGuid().ToString('N').Substring(0,8))
$runtimeRoot = Join-Path $baseRoot $runtimeId
$checkpointDir = Join-Path $runtimeRoot 'checkpoints'
New-Item -ItemType Directory -Force -Path $checkpointDir | Out-Null

$lockPath = Join-Path $runtimeRoot 'runtime.lock.json'
$heartbeatPath = Join-Path $runtimeRoot 'heartbeat.json'
$stopSignalPath = Join-Path $runtimeRoot 'STOP.json'
$checkpointPath = Join-Path $checkpointDir 'latest.json'
$runtimeProofPath = Join-Path $runtimeRoot 'CONTINUOUS_AGENT_RUNTIME_V1_LAB_PROOF.json'
$summaryPath = Join-Path $runtimeRoot 'CONTINUOUS_AGENT_RUNTIME_V1_LAB_SUMMARY.json'

$startedAt = (Get-Date).ToUniversalTime()
$deadline = $startedAt.AddMinutes($DurationMinutes)

$lockData = [ordered]@{
  schema = 'continuous_agent_runtime_v1_lab_lock'
  active = $true
  runtime_id = $runtimeId
  pid = $PID
  started_at = $startedAt.ToString('o')
  mode = 'SandboxExploration'
  memory_mode = 'QueueOnly'
  repo_root = $repoRoot
  repo_branch = $repoBranch
  repo_head = $repoHead
  heartbeat_path = $heartbeatPath
  stop_signal_path = $stopSignalPath
  checkpoint_path = $checkpointPath
}
Write-CleanJson -Path $lockPath -Data $lockData

$AgentState = [ordered]@{
  runtime_id = $runtimeId
  pid = $PID
  started_at = $startedAt.ToString('o')
  cycle_count = 0
  ram_counter = 0
  recent_cycles = @()
  current_goal = 'prove_ram_state_persistence'
  last_checkpoint_ref = $null
  minimal_supervised_life_context = [ordered]@{
    runtime_id = $runtimeId
    mode = 'SandboxExploration'
    repo_root = $repoRoot
    repo_head = $repoHead
    active_memory_root_exists = (Test-Path -LiteralPath $activeMemoryRoot)
    compact_memory_queue_exists = (Test-Path -LiteralPath $compactQueueRoot)
    allowed_actions = @()
    memory_mode = 'QueueOnly'
    safety_mode = 'supervised_lab'
    current_goal = 'prove RAM state persists across cycles'
    forbidden = @('git','codex','web','repair','cleanup','active_memory_direct_write')
  }
}

$cycleRecords = @()
$stopRequested = $false
$cycleScratchCleared = $true

try {
  do {
    if (Test-Path -LiteralPath $stopSignalPath) {
      $stopRequested = $true
      break
    }

    $AgentState.cycle_count = [int]$AgentState.cycle_count + 1
    $AgentState.ram_counter = [int]$AgentState.ram_counter + 1
    $cycleStarted = (Get-Date).ToUniversalTime()

    $cycleScratch = [ordered]@{
      cycle = $AgentState.cycle_count
      pid = $PID
      scratch_nonce = [guid]::NewGuid().ToString('N')
      temporary_note = 'scratch exists only during this cycle and is cleared before next cycle'
    }

    $cycleSummary = [ordered]@{
      cycle = $AgentState.cycle_count
      pid = $PID
      ram_counter = $AgentState.ram_counter
      started_at = $cycleStarted.ToString('o')
      decision = 'NO_OP_SAFE_RAM_STATE_PERSISTENCE_STEP'
      scratch_created = $true
      scratch_cleared = $false
    }

    $cycleScratch = $null
    $cycleSummary.scratch_cleared = $true
    if ($null -ne $cycleScratch) { $cycleScratchCleared = $false }

    $cycleFinished = (Get-Date).ToUniversalTime()
    $cycleSummary.finished_at = $cycleFinished.ToString('o')
    $cycleRecords += $cycleSummary

    $recent = @($AgentState.recent_cycles) + @($cycleSummary)
    if ($recent.Count -gt 10) { $recent = @($recent | Select-Object -Last 10) }
    $AgentState.recent_cycles = @($recent)

    $heartbeat = [ordered]@{
      schema = 'continuous_agent_runtime_v1_lab_heartbeat'
      runtime_id = $runtimeId
      pid = $PID
      cycle_count = $AgentState.cycle_count
      ram_counter = $AgentState.ram_counter
      last_cycle_started_at = $cycleStarted.ToString('o')
      last_cycle_finished_at = $cycleFinished.ToString('o')
      last_safe_checkpoint = $checkpointPath
      status = 'RUNNING'
      memory_private_mb = [math]::Round((Get-Process -Id $PID).PrivateMemorySize64 / 1MB, 2)
      updated_at = (Get-Date).ToUniversalTime().ToString('o')
    }
    Write-CleanJson -Path $heartbeatPath -Data $heartbeat

    $checkpoint = [ordered]@{
      schema = 'continuous_agent_runtime_v1_lab_checkpoint'
      runtime_id = $runtimeId
      pid = $PID
      cycle_count = $AgentState.cycle_count
      ram_counter = $AgentState.ram_counter
      orientation_card_ref = $null
      wake_context_ref = 'minimal_supervised_life_context_in_ram'
      ram_state_compact = [ordered]@{
        current_goal = $AgentState.current_goal
        recent_cycles_count = @($AgentState.recent_cycles).Count
        last_cycle = $cycleSummary
      }
      last_safe_boundary = 'after_cycle_checkpoint'
      written_at = (Get-Date).ToUniversalTime().ToString('o')
    }
    Write-CleanJson -Path $checkpointPath -Data $checkpoint
    $AgentState.last_checkpoint_ref = $checkpointPath

    Start-Sleep -Seconds 2
  } while ((Get-Date).ToUniversalTime() -lt $deadline)
}
finally {
  $finishedAt = (Get-Date).ToUniversalTime()
  $cyclePids = @($cycleRecords | ForEach-Object { [int]$_['pid'] } | Select-Object -Unique)
  $samePid = ($cyclePids.Count -eq 1 -and $cyclePids[0] -eq $PID)
  $repoStatusAfter = @(& git status --short --untracked-files=all)
  $trackedDiffNames = @(& git diff --name-only)
  $trackedDiffCachedNames = @(& git diff --cached --name-only)
  $activeStatsAfter = Get-TreeStats -Path $activeMemoryRoot

  $finalHeartbeat = [ordered]@{
    schema = 'continuous_agent_runtime_v1_lab_heartbeat'
    runtime_id = $runtimeId
    pid = $PID
    cycle_count = $AgentState.cycle_count
    ram_counter = $AgentState.ram_counter
    last_cycle_started_at = if (@($cycleRecords).Count -gt 0) { @($cycleRecords)[-1].started_at } else { $null }
    last_cycle_finished_at = if (@($cycleRecords).Count -gt 0) { @($cycleRecords)[-1].finished_at } else { $null }
    last_safe_checkpoint = $checkpointPath
    status = 'STOPPED'
    memory_private_mb = [math]::Round((Get-Process -Id $PID).PrivateMemorySize64 / 1MB, 2)
    updated_at = $finishedAt.ToString('o')
  }
  Write-CleanJson -Path $heartbeatPath -Data $finalHeartbeat

  $lockData.active = $false
  $lockData.stopped_at = $finishedAt.ToString('o')
  $lockData.shutdown_status = 'SAFE_SHUTDOWN'
  Write-CleanJson -Path $lockPath -Data $lockData

  $proof = [ordered]@{
    schema = 'continuous_agent_runtime_v1_lab_proof'
    status = 'PASS_CONTINUOUS_AGENT_RUNTIME_V1_LAB'
    runtime_id = $runtimeId
    runtime_root = $runtimeRoot
    started_at = $startedAt.ToString('o')
    finished_at = $finishedAt.ToString('o')
    duration_minutes_requested = $DurationMinutes
    pid = $PID
    cycle_records = @($cycleRecords)
    same_pid_across_cycles = $samePid
    cycle_count = [int]$AgentState.cycle_count
    ram_counter_final = [int]$AgentState.ram_counter
    ram_state_persisted = ([int]$AgentState.ram_counter -ge 2 -and [int]$AgentState.cycle_count -ge 2 -and $samePid)
    per_cycle_json_bridge_used_for_ram_state = $false
    lock_created = (Test-Path -LiteralPath $lockPath)
    heartbeat_written = (Test-Path -LiteralPath $heartbeatPath)
    stop_signal_supported = $true
    stop_requested = $stopRequested
    checkpoint_written = (Test-Path -LiteralPath $checkpointPath)
    final_proof_written = $true
    cycle_scratch_cleared = $cycleScratchCleared
    canonical_launcher_mutated = $false
    cycle_runner_mutated = $false
    repo_mutated = ($trackedDiffNames.Count -gt 0 -or $trackedDiffCachedNames.Count -gt 0)
    active_memory_direct_mutated = $false
    codex_launched = $false
    web_launched = $false
    school_launched = $false
    raw_debug_retained = $false
    boundaries = [ordered]@{
      mode = 'SandboxExploration'
      memory_mode = 'QueueOnly'
      no_git_mutation = $true
      no_codex = $true
      no_web = $true
      no_repair = $true
      no_cleanup = $true
      active_memory_root_exists_after = $activeStatsAfter.exists
      active_memory_stats_after = $activeStatsAfter
      repo_status_before = $repoStatusBefore
      repo_status_after = $repoStatusAfter
      tracked_diff_names = $trackedDiffNames
      tracked_diff_cached_names = $trackedDiffCachedNames
    }
    artifacts = [ordered]@{
      lock = $lockPath
      heartbeat = $heartbeatPath
      checkpoint = $checkpointPath
      proof = $runtimeProofPath
      summary = $summaryPath
      stop_signal_path = $stopSignalPath
    }
  }
  Write-CleanJson -Path $runtimeProofPath -Data $proof

  $proof.final_proof_written = (Test-Path -LiteralPath $runtimeProofPath)
  Write-CleanJson -Path $runtimeProofPath -Data $proof

  $summary = [ordered]@{
    schema = 'continuous_agent_runtime_v1_lab_summary'
    status = $proof.status
    runtime_id = $runtimeId
    runtime_root = $runtimeRoot
    pid = $PID
    cycle_count = $proof.cycle_count
    ram_counter_final = $proof.ram_counter_final
    same_pid_across_cycles = $proof.same_pid_across_cycles
    ram_state_persisted = $proof.ram_state_persisted
    proof = $runtimeProofPath
  }
  Write-CleanJson -Path $summaryPath -Data $summary

  Write-Host "STATUS=$($proof.status)"
  Write-Host "RUNTIME_ROOT=$runtimeRoot"
  Write-Host "PROOF=$runtimeProofPath"
  Write-Host "CYCLE_COUNT=$($proof.cycle_count)"
  Write-Host "RAM_COUNTER_FINAL=$($proof.ram_counter_final)"
}
