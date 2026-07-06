function Normalize-Phase160JInspectPath {
  param([string]$Path)
  return [System.IO.Path]::GetFullPath($Path).TrimEnd([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar)
}

function Resolve-Phase160JInspectPath {
  param([string]$Root, [string]$Path)
  if ([System.IO.Path]::IsPathRooted($Path)) {
    return [System.IO.Path]::GetFullPath($Path)
  }
  return [System.IO.Path]::GetFullPath((Join-Path $Root $Path))
}

function Read-Phase160JInspectJsonSafe {
  param([string]$Path)
  try {
    if (-not (Test-Path -LiteralPath $Path)) {
      return $null
    }
    return Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json
  } catch {
    return $null
  }
}

function Write-Phase160JInspectJsonFile {
  param([string]$Path, [object]$Object)
  $directory = Split-Path -Path $Path -Parent
  if ($directory -and -not (Test-Path -LiteralPath $directory)) {
    New-Item -ItemType Directory -Force -Path $directory | Out-Null
  }
  $json = ($Object | ConvertTo-Json -Depth 100) -replace "`r`n", "`n"
  if (-not $json.EndsWith("`n")) {
    $json += "`n"
  }
  [System.IO.File]::WriteAllText($Path, $json, [System.Text.UTF8Encoding]::new($false))
}

function Get-Phase160JLatestJsonFile {
  param([string]$Directory, [string]$Pattern = "*.json")
  if (-not (Test-Path -LiteralPath $Directory)) {
    return $null
  }
  $files = @(Get-ChildItem -LiteralPath $Directory -File -Filter $Pattern -ErrorAction SilentlyContinue | Where-Object { $_.Name -ne "README.json" } | Sort-Object LastWriteTimeUtc, Name)
  if ($files.Count -lt 1) {
    return $null
  }
  return $files[-1]
}

function Get-Phase160JOwnerTaskLifecycleState {
  param([string]$SessionRootFull)

  $activeTask = Read-Phase160JInspectJsonSafe -Path (Join-Path $SessionRootFull "active_task/active_task.json")
  $activeTaskState = Read-Phase160JInspectJsonSafe -Path (Join-Path $SessionRootFull "task_lifecycle/active_task_state.json")
  $lastIntake = Read-Phase160JInspectJsonSafe -Path (Join-Path $SessionRootFull "owner_task_lifecycle/last_owner_task_intake.json")
  $latestBacklogFile = Get-Phase160JLatestJsonFile -Directory (Join-Path $SessionRootFull "task_backlog")
  $latestBacklog = if ($null -ne $latestBacklogFile) { Read-Phase160JInspectJsonSafe -Path $latestBacklogFile.FullName } else { $null }
  $latestConsumedFile = Get-Phase160JLatestJsonFile -Directory (Join-Path $SessionRootFull "teacher_consumed") -Pattern "receipt_*.json"
  $latestConsumed = if ($null -ne $latestConsumedFile) { Read-Phase160JInspectJsonSafe -Path $latestConsumedFile.FullName } else { $null }
  $backlogFiles = @(Get-ChildItem -LiteralPath (Join-Path $SessionRootFull "task_backlog") -File -Filter "*.json" -ErrorAction SilentlyContinue | Where-Object { $_.Name -ne "README.json" } | Sort-Object LastWriteTimeUtc, Name)
  $ownerBacklogRecords = @()
  foreach ($file in $backlogFiles) {
    $record = Read-Phase160JInspectJsonSafe -Path $file.FullName
    if ($null -ne $record -and $record.PSObject.Properties.Name -contains "source" -and [string]$record.source -eq "owner") {
      $ownerBacklogRecords += $record
    }
  }
  $latestOwnerBacklog = if ($ownerBacklogRecords.Count -gt 0) { $ownerBacklogRecords[-1] } else { $null }
  $activeTaskId = if ($null -ne $activeTask -and $activeTask.PSObject.Properties.Name -contains "task_id") { [string]$activeTask.task_id } else { "NONE" }
  $activeStatus = if ($null -ne $activeTaskState -and $activeTaskState.PSObject.Properties.Name -contains "status") { [string]$activeTaskState.status } elseif ($activeTaskId -ne "NONE") { "ACTIVE" } else { "NONE" }
  $ownerBacklogCount = $ownerBacklogRecords.Count
  $lastIntakeTaskId = if ($null -ne $lastIntake -and $lastIntake.PSObject.Properties.Name -contains "task_id") { [string]$lastIntake.task_id } else { "NONE" }
  $latestConsumedTaskId = if ($null -ne $latestConsumed -and $latestConsumed.PSObject.Properties.Name -contains "task_id") { [string]$latestConsumed.task_id } else { "NONE" }
  $lastIntakeWasConsumed = ($lastIntakeTaskId -ne "NONE" -and $latestConsumedTaskId -eq $lastIntakeTaskId)
  $lastDecision = if ($null -ne $lastIntake -and $lastIntake.PSObject.Properties.Name -contains "decision") { [string]$lastIntake.decision } else { "NONE" }
  $lastQuarantineReason = if ($null -ne $lastIntake -and $lastIntake.PSObject.Properties.Name -contains "quarantine_reason") { [string]$lastIntake.quarantine_reason } else { "NONE" }
  $lastBacklogStatus = if ($null -ne $latestOwnerBacklog -and $latestOwnerBacklog.PSObject.Properties.Name -contains "backlog_status") { [string]$latestOwnerBacklog.backlog_status } elseif ($null -ne $lastIntake -and $lastIntake.PSObject.Properties.Name -contains "backlog_status") { [string]$lastIntake.backlog_status } else { "NONE" }
  $latestOwnerBacklogTaskId = if ($null -ne $latestOwnerBacklog -and $latestOwnerBacklog.PSObject.Properties.Name -contains "task_id") { [string]$latestOwnerBacklog.task_id } else { "NONE" }
  $activeBlocksOwnerTask = ($ownerBacklogCount -gt 0 -and $activeTaskId -ne "NONE")
  $backlogActivationReady = ($ownerBacklogCount -gt 0 -and $activeTaskId -eq "NONE")
  $ownerTaskLost = $false
  if ($lastDecision -eq "ACCEPT_SAFE_OWNER_TASK" -and $activeTaskId -eq "NONE" -and -not $lastIntakeWasConsumed) {
    $ownerTaskLost = $true
  }
  if ($lastDecision -eq "BACKLOG_SAFE_OWNER_TASK" -and $ownerBacklogCount -lt 1 -and -not $lastIntakeWasConsumed) {
    $ownerTaskLost = $true
  }

  return [pscustomobject][ordered]@{
    owner_task_intake_enabled = $true
    last_owner_task_id = $lastIntakeTaskId
    last_owner_task_intake_decision = $lastDecision
    last_owner_task_quarantine_reason = $lastQuarantineReason
    last_owner_task_backlog_status = $lastBacklogStatus
    owner_task_backlog_count = $ownerBacklogCount
    latest_owner_backlog_task_id = $latestOwnerBacklogTaskId
    latest_consumed_task_id = $latestConsumedTaskId
    latest_backlog_task_id = if ($null -ne $latestBacklog -and $latestBacklog.PSObject.Properties.Name -contains "task_id") { [string]$latestBacklog.task_id } else { "NONE" }
    latest_backlog_reason = if ($null -ne $latestBacklog -and $latestBacklog.PSObject.Properties.Name -contains "blocked_by_status") { [string]$latestBacklog.blocked_by_status } else { "NONE" }
    active_task_blocks_owner_task = $activeBlocksOwnerTask
    backlog_activation_ready = $backlogActivationReady
    owner_task_lost = $ownerTaskLost
    active_task_id = $activeTaskId
    active_task_status = $activeStatus
  }
}
