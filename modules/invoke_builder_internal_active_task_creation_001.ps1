param(
  [string]$SessionRoot = "",
  [string]$RunId = "",
  [string]$DutyId = "NONE",
  [int]$TickNumber = 0
)

$ErrorActionPreference = "Stop"

function Normalize-Phase160FInternalTaskFullPath {
  param([string]$Path)
  return [System.IO.Path]::GetFullPath($Path).TrimEnd([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar)
}

function Resolve-Phase160FInternalTaskRepoRoot {
  $scriptRootCandidate = $PSScriptRoot
  if ([string]::IsNullOrWhiteSpace($scriptRootCandidate) -and -not [string]::IsNullOrWhiteSpace($PSCommandPath)) {
    $scriptRootCandidate = Split-Path -Path $PSCommandPath -Parent
  }
  if ([string]::IsNullOrWhiteSpace($scriptRootCandidate) -and -not [string]::IsNullOrWhiteSpace($MyInvocation.MyCommand.Path)) {
    $scriptRootCandidate = Split-Path -Path $MyInvocation.MyCommand.Path -Parent
  }
  if ([string]::IsNullOrWhiteSpace($scriptRootCandidate)) {
    throw "PHASE160F_INTERNAL_TASK_SCRIPT_ROOT_UNAVAILABLE"
  }
  return Normalize-Phase160FInternalTaskFullPath -Path (Join-Path $scriptRootCandidate "..")
}

function Resolve-Phase160FInternalTaskPath {
  param([string]$RepoRoot, [string]$Path)
  if ([System.IO.Path]::IsPathRooted($Path)) {
    return [System.IO.Path]::GetFullPath($Path)
  }
  return [System.IO.Path]::GetFullPath((Join-Path $RepoRoot $Path))
}

function ConvertTo-Phase160FInternalTaskRelativePath {
  param([string]$RepoRoot, [string]$FullPath)
  $root = Normalize-Phase160FInternalTaskFullPath -Path $RepoRoot
  $full = Normalize-Phase160FInternalTaskFullPath -Path $FullPath
  if ($full -eq $root) {
    return "."
  }
  if (-not $full.StartsWith($root + [System.IO.Path]::DirectorySeparatorChar, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw "PHASE160F_INTERNAL_TASK_PATH_OUTSIDE_REPO=$FullPath"
  }
  return ($full.Substring($root.Length + 1) -replace "\\", "/")
}

function Write-Phase160FInternalTaskJsonFile {
  param([string]$Path, [object]$Object, [int]$Depth = 100)
  $directory = Split-Path -Path $Path -Parent
  if ($directory -and -not (Test-Path -LiteralPath $directory)) {
    New-Item -ItemType Directory -Force -Path $directory | Out-Null
  }
  $json = ($Object | ConvertTo-Json -Depth $Depth) -replace "`r`n", "`n"
  if (-not $json.EndsWith("`n")) {
    $json += "`n"
  }
  [System.IO.File]::WriteAllText($Path, $json, [System.Text.UTF8Encoding]::new($false))
}

function Add-Phase160FInternalTaskJsonLine {
  param([string]$Path, [object]$Object)
  $directory = Split-Path -Path $Path -Parent
  if ($directory -and -not (Test-Path -LiteralPath $directory)) {
    New-Item -ItemType Directory -Force -Path $directory | Out-Null
  }
  $line = $Object | ConvertTo-Json -Depth 100 -Compress
  [System.IO.File]::AppendAllText($Path, "$line`n", [System.Text.UTF8Encoding]::new($false))
}

function Read-Phase160FInternalTaskJsonSafe {
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

function Assert-Phase160FInternalTaskRunIdSafe {
  param([string]$RunId)
  if ([string]::IsNullOrWhiteSpace($RunId)) {
    return
  }
  if ($RunId.IndexOfAny([char[]]@("/", "\")) -ge 0) {
    throw "PHASE160F_INTERNAL_TASK_RUN_ID_MUST_BE_LEAF=$RunId"
  }
}

$RepoRoot = Resolve-Phase160FInternalTaskRepoRoot
$Pushed = $false

try {
  Push-Location $RepoRoot
  $Pushed = $true

  foreach ($identityFile in @("CAPABILITY_ROADMAP.json", "GENESIS_STATE.json", "TASK_QUEUE.json", "packs/registry.json", "orchestrator/run.ps1")) {
    if (-not (Test-Path -LiteralPath (Resolve-Phase160FInternalTaskPath -RepoRoot $RepoRoot -Path $identityFile))) {
      throw "STOP=WRONG_AGENT_BUILDER_REPO missing=$identityFile"
    }
  }

  Assert-Phase160FInternalTaskRunIdSafe -RunId $RunId
  if (-not [string]::IsNullOrWhiteSpace($RunId) -and [string]::IsNullOrWhiteSpace($SessionRoot)) {
    $SessionRoot = "runtime_sessions/live_growth/$RunId"
  }
  if ([string]::IsNullOrWhiteSpace($SessionRoot)) {
    throw "PHASE160F_INTERNAL_TASK_SESSION_ROOT_REQUIRED"
  }

  $SessionRootFull = Resolve-Phase160FInternalTaskPath -RepoRoot $RepoRoot -Path $SessionRoot
  $SessionRootRelative = ConvertTo-Phase160FInternalTaskRelativePath -RepoRoot $RepoRoot -FullPath $SessionRootFull
  $SelectionRoot = Join-Path $SessionRootFull "self_initiated_goal_selection"
  $SelectedGoal = Read-Phase160FInternalTaskJsonSafe -Path (Join-Path $SelectionRoot "selected_useful_goal.json")
  if ($null -eq $SelectedGoal) {
    throw "PHASE160F_INTERNAL_TASK_SELECTED_GOAL_MISSING=$SessionRootRelative/self_initiated_goal_selection/selected_useful_goal.json"
  }

  $ActiveTaskDir = Join-Path $SessionRootFull "active_task"
  $TaskLifecycleRoot = Join-Path $SessionRootFull "task_lifecycle"
  $CandidateWorkspace = Join-Path $SessionRootFull "candidate_workspace"
  New-Item -ItemType Directory -Force -Path $ActiveTaskDir, $TaskLifecycleRoot, $CandidateWorkspace | Out-Null
  $TaskId = "PHASE160F_INTERNAL_SELF_SELECTED_{0}" -f ([string]$SelectedGoal.selected_goal_id)
  if ($TaskId.Length -gt 115) {
    $TaskId = $TaskId.Substring(0, 115)
  }
  $CreatedAt = (Get-Date).ToUniversalTime().ToString("o")
  $InternalTask = [ordered]@{
    status = "ACTIVE"
    event_type = "internal_self_selected_goal_task"
    task_id = $TaskId
    source = "internal_self_selected_goal"
    priority = "high"
    owner_goal = "Build a session-local candidate for $($SelectedGoal.selected_goal_name)."
    desired_next_gap = "SELF_SELECTED_USEFUL_CANDIDATE_PRODUCTION"
    internal_goal_id = [string]$SelectedGoal.selected_goal_id
    internal_goal_name = [string]$SelectedGoal.selected_goal_name
    selected_goal_reason = [string]$SelectedGoal.reason
    expected_new_capability = [string]$SelectedGoal.expected_new_capability
    expected_candidate_capabilities = @(
      "SELF_INITIATED_USEFUL_GOAL_SELECTION",
      "self_gap_inventory",
      "usefulness_scoring",
      "internal_active_task_creation",
      "no_teacher_inbox_required",
      "candidate_bundle_creation",
      "promotion_bundle_update",
      "runtime_guard_required"
    )
    expected_candidate_files = @($SelectedGoal.expected_candidate_files)
    expected_validator_files = @($SelectedGoal.expected_validator_files)
    owner_approval_required = $true
    safety_rules = [ordered]@{
      accepted_state_mutation_allowed = $false
      accepted_memory_mutation_allowed = $false
      accepted_self_model_mutation_allowed = $false
      repo_commit_allowed = $false
      runtime_session_only = $true
    }
    code_execution_requested = $false
    accepted_state_mutation_allowed = $false
    accepted_memory_mutation_allowed = $false
    accepted_self_model_mutation_allowed = $false
    repo_commit_allowed = $false
    runtime_session_only = $true
    selected_without_teacher_inbox = $true
    selected_at = $CreatedAt
  }

  $InternalTaskPath = Join-Path $ActiveTaskDir "internal_self_selected_active_task.json"
  $ActiveTaskPath = Join-Path $ActiveTaskDir "active_task.json"
  Write-Phase160FInternalTaskJsonFile -Path $InternalTaskPath -Object $InternalTask
  Write-Phase160FInternalTaskJsonFile -Path $ActiveTaskPath -Object $InternalTask
  Write-Phase160FInternalTaskJsonFile -Path (Join-Path $SelectionRoot "internal_active_task.json") -Object $InternalTask
  Write-Phase160FInternalTaskJsonFile -Path (Join-Path $TaskLifecycleRoot "active_task_state.json") -Object ([ordered]@{
    status = "ACTIVE"
    source = "internal_self_selected_goal"
    active_task_id = $TaskId
    active_plan_item_id = "NONE"
    selected_goal_id = [string]$SelectedGoal.selected_goal_id
    desired_next_gap = "SELF_SELECTED_USEFUL_CANDIDATE_PRODUCTION"
    owner_approval_required = $true
    run_id = if ([string]::IsNullOrWhiteSpace($RunId)) { "NONE" } else { $RunId }
    updated_at = $CreatedAt
  })

  Add-Phase160FInternalTaskJsonLine -Path (Join-Path $CandidateWorkspace "change_ledger.jsonl") -Object ([ordered]@{
    event_type = "internal_active_task_created"
    source = "internal_self_selected_goal"
    task_id = $TaskId
    selected_goal_id = [string]$SelectedGoal.selected_goal_id
    no_teacher_inbox_required = $true
    occurred_at = $CreatedAt
  })
  Add-Phase160FInternalTaskJsonLine -Path (Join-Path $SessionRootFull "event_log.jsonl") -Object ([ordered]@{
    event_type = "internal_active_task_created"
    source = "self_initiated_goal_selector"
    task_id = $TaskId
    selected_goal_id = [string]$SelectedGoal.selected_goal_id
    occurred_at = $CreatedAt
  })

  [pscustomobject][ordered]@{
    status = "PASS"
    run_id = if ([string]::IsNullOrWhiteSpace($RunId)) { "NONE" } else { $RunId }
    session_root = $SessionRootRelative
    internal_active_task_created = $true
    internal_active_task_path = ConvertTo-Phase160FInternalTaskRelativePath -RepoRoot $RepoRoot -FullPath $InternalTaskPath
    active_task_id = $TaskId
    selected_goal_id = [string]$SelectedGoal.selected_goal_id
    source = "internal_self_selected_goal"
  } | ConvertTo-Json -Depth 20
} finally {
  if ($Pushed) {
    Pop-Location
  }
}
