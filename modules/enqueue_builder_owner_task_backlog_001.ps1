function ConvertTo-Phase160JBacklogSafeLeaf {
  param([string]$Value, [int]$MaxLength = 90)
  $leaf = if ([string]::IsNullOrWhiteSpace($Value)) { "UNKNOWN" } else { $Value }
  $leaf = $leaf -replace '[^A-Za-z0-9_.-]', '_'
  if ($leaf.Length -gt $MaxLength) {
    $leaf = $leaf.Substring(0, $MaxLength)
  }
  return $leaf
}

function Read-Phase160JBacklogJsonSafe {
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

function Write-Phase160JBacklogJsonFile {
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

function Add-Phase160JOwnerTaskBacklog {
  param(
    [string]$TaskBacklogDirectory,
    [object]$NormalizedTask,
    [object]$ExistingActiveTask = $null,
    [string]$ExistingActiveStatus = "ACTIVE",
    [string]$DutyId = "NONE",
    [string]$TeacherDigestPath = "NONE",
    [string]$ContentHash = ""
  )

  New-Item -ItemType Directory -Force -Path $TaskBacklogDirectory | Out-Null
  $normalizedTaskId = [string]$NormalizedTask.normalized_task_id
  $taskId = if ([string]$NormalizedTask.original_task_id -ne "NONE") { [string]$NormalizedTask.original_task_id } else { $normalizedTaskId }
  $safeTaskId = ConvertTo-Phase160JBacklogSafeLeaf -Value $normalizedTaskId
  $backlogPath = Join-Path $TaskBacklogDirectory ("{0}.json" -f $safeTaskId)
  $existing = Read-Phase160JBacklogJsonSafe -Path $backlogPath
  $attempts = if ($null -ne $existing -and $existing.PSObject.Properties.Name -contains "attempts") { [int]$existing.attempts + 1 } else { 1 }
  $createdAt = if ($null -ne $existing -and $existing.PSObject.Properties.Name -contains "created_at") { [string]$existing.created_at } else { (Get-Date).ToUniversalTime().ToString("o") }
  $blockedByTaskId = if ($null -ne $ExistingActiveTask -and $ExistingActiveTask.PSObject.Properties.Name -contains "task_id") { [string]$ExistingActiveTask.task_id } else { "NONE" }
  if ([string]::IsNullOrWhiteSpace($blockedByTaskId)) {
    $blockedByTaskId = "NONE"
  }
  $planItems = @($NormalizedTask.plan_items)
  $record = [ordered]@{
    status = "BACKLOG"
    task_id = $taskId
    normalized_task_id = $normalizedTaskId
    source = "owner"
    backlog_status = "BACKLOG_WAITING_ACTIVE_SLOT"
    blocked_by_active_task_id = $blockedByTaskId
    blocked_by_status = if ([string]::IsNullOrWhiteSpace($ExistingActiveStatus)) { "ACTIVE" } else { $ExistingActiveStatus }
    activation_conditions = @(
      "active_task_slot_empty",
      "owner_promotion_or_restart_gate_required"
    )
    created_at = $createdAt
    last_seen_at = (Get-Date).ToUniversalTime().ToString("o")
    attempts = $attempts
    next_action = "WAIT_FOR_ACTIVE_SLOT_AND_OWNER_PROMOTION_GATE"
    duty_id = $DutyId
    priority = [string]$NormalizedTask.priority
    owner_goal = [string]$NormalizedTask.owner_goal
    desired_next_gap = [string]$NormalizedTask.desired_next_gap
    teacher_digest_path = $TeacherDigestPath
    content_hash = if ([string]::IsNullOrWhiteSpace($ContentHash)) { [string]$NormalizedTask.content_hash } else { $ContentHash }
    plan_step_count = $planItems.Count
    plan_items = @($planItems)
    safety_profile = $NormalizedTask.safety_profile
    owner_task_lost = $false
  }
  Write-Phase160JBacklogJsonFile -Path $backlogPath -Object $record
  return [pscustomobject][ordered]@{
    status = "BACKLOG_WRITTEN"
    task_id = $taskId
    normalized_task_id = $normalizedTaskId
    backlog_status = "BACKLOG_WAITING_ACTIVE_SLOT"
    backlog_path = $backlogPath
    blocked_by_active_task_id = $blockedByTaskId
    blocked_by_status = $record.blocked_by_status
    owner_task_lost = $false
  }
}
