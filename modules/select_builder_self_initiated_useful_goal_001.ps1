param(
  [string]$SessionRoot = "",
  [string]$RunId = "",
  [string]$DutyId = "NONE",
  [int]$TickNumber = 0,
  [string]$MacroCycleStage = "NONE",
  [switch]$CandidateWorkspacePromotionEnabled
)

$ErrorActionPreference = "Stop"

function Normalize-Phase160FSelectFullPath {
  param([string]$Path)
  return [System.IO.Path]::GetFullPath($Path).TrimEnd([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar)
}

function Resolve-Phase160FSelectRepoRoot {
  $scriptRootCandidate = $PSScriptRoot
  if ([string]::IsNullOrWhiteSpace($scriptRootCandidate) -and -not [string]::IsNullOrWhiteSpace($PSCommandPath)) {
    $scriptRootCandidate = Split-Path -Path $PSCommandPath -Parent
  }
  if ([string]::IsNullOrWhiteSpace($scriptRootCandidate) -and -not [string]::IsNullOrWhiteSpace($MyInvocation.MyCommand.Path)) {
    $scriptRootCandidate = Split-Path -Path $MyInvocation.MyCommand.Path -Parent
  }
  if ([string]::IsNullOrWhiteSpace($scriptRootCandidate)) {
    throw "PHASE160F_SELECT_SCRIPT_ROOT_UNAVAILABLE"
  }
  return Normalize-Phase160FSelectFullPath -Path (Join-Path $scriptRootCandidate "..")
}

function Resolve-Phase160FSelectPath {
  param([string]$RepoRoot, [string]$Path)
  if ([System.IO.Path]::IsPathRooted($Path)) {
    return [System.IO.Path]::GetFullPath($Path)
  }
  return [System.IO.Path]::GetFullPath((Join-Path $RepoRoot $Path))
}

function ConvertTo-Phase160FSelectRelativePath {
  param([string]$RepoRoot, [string]$FullPath)
  $root = Normalize-Phase160FSelectFullPath -Path $RepoRoot
  $full = Normalize-Phase160FSelectFullPath -Path $FullPath
  if ($full -eq $root) {
    return "."
  }
  if (-not $full.StartsWith($root + [System.IO.Path]::DirectorySeparatorChar, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw "PHASE160F_SELECT_PATH_OUTSIDE_REPO=$FullPath"
  }
  return ($full.Substring($root.Length + 1) -replace "\\", "/")
}

function Write-Phase160FSelectJsonFile {
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

function Write-Phase160FSelectTextFile {
  param([string]$Path, [string]$Text)
  $directory = Split-Path -Path $Path -Parent
  if ($directory -and -not (Test-Path -LiteralPath $directory)) {
    New-Item -ItemType Directory -Force -Path $directory | Out-Null
  }
  if (-not $Text.EndsWith("`n")) {
    $Text += "`n"
  }
  [System.IO.File]::WriteAllText($Path, $Text, [System.Text.UTF8Encoding]::new($false))
}

function Add-Phase160FSelectJsonLine {
  param([string]$Path, [object]$Object)
  $directory = Split-Path -Path $Path -Parent
  if ($directory -and -not (Test-Path -LiteralPath $directory)) {
    New-Item -ItemType Directory -Force -Path $directory | Out-Null
  }
  $line = $Object | ConvertTo-Json -Depth 100 -Compress
  [System.IO.File]::AppendAllText($Path, "$line`n", [System.Text.UTF8Encoding]::new($false))
}

function Read-Phase160FSelectJsonSafe {
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

function Get-Phase160FSelectString {
  param([object]$Object, [string]$Name, [string]$Default = "NONE")
  if ($null -eq $Object -or -not ($Object.PSObject.Properties.Name -contains $Name)) {
    return $Default
  }
  $value = $Object.$Name
  if ($null -eq $value -or [string]::IsNullOrWhiteSpace([string]$value)) {
    return $Default
  }
  return [string]$value
}

function Get-Phase160FSelectFileCount {
  param([string]$Path, [string]$Pattern = "*.json")
  if (-not (Test-Path -LiteralPath $Path)) {
    return 0
  }
  return @(Get-ChildItem -LiteralPath $Path -File -Filter $Pattern -ErrorAction SilentlyContinue | Where-Object { $_.Name -ne "README.json" }).Count
}

function Assert-Phase160FSelectRunIdSafe {
  param([string]$RunId)
  if ([string]::IsNullOrWhiteSpace($RunId)) {
    return
  }
  if ($RunId.IndexOfAny([char[]]@("/", "\")) -ge 0) {
    throw "PHASE160F_SELECT_RUN_ID_MUST_BE_LEAF=$RunId"
  }
}

$RepoRoot = Resolve-Phase160FSelectRepoRoot
$Pushed = $false

try {
  Push-Location $RepoRoot
  $Pushed = $true

  foreach ($identityFile in @("CAPABILITY_ROADMAP.json", "GENESIS_STATE.json", "TASK_QUEUE.json", "packs/registry.json", "orchestrator/run.ps1")) {
    if (-not (Test-Path -LiteralPath (Resolve-Phase160FSelectPath -RepoRoot $RepoRoot -Path $identityFile))) {
      throw "STOP=WRONG_AGENT_BUILDER_REPO missing=$identityFile"
    }
  }

  Assert-Phase160FSelectRunIdSafe -RunId $RunId
  if (-not [string]::IsNullOrWhiteSpace($RunId) -and [string]::IsNullOrWhiteSpace($SessionRoot)) {
    $SessionRoot = "runtime_sessions/live_growth/$RunId"
  }
  if ([string]::IsNullOrWhiteSpace($SessionRoot)) {
    throw "PHASE160F_SELECT_SESSION_ROOT_REQUIRED"
  }

  $SessionRootFull = Resolve-Phase160FSelectPath -RepoRoot $RepoRoot -Path $SessionRoot
  $SessionRootRelative = ConvertTo-Phase160FSelectRelativePath -RepoRoot $RepoRoot -FullPath $SessionRootFull
  $SelectionRoot = Join-Path $SessionRootFull "self_initiated_goal_selection"
  $CandidateWorkspace = Join-Path $SessionRootFull "candidate_workspace"
  New-Item -ItemType Directory -Force -Path $SelectionRoot, $CandidateWorkspace | Out-Null

  $RuntimeGuard = Read-Phase160FSelectJsonSafe -Path (Join-Path $SessionRootFull "runtime_guard.json")
  $ActiveTask = Read-Phase160FSelectJsonSafe -Path (Join-Path $SessionRootFull "active_task/active_task.json")
  $ActivePlanItem = Read-Phase160FSelectJsonSafe -Path (Join-Path $SessionRootFull "active_task/active_plan_item.json")
  $ActiveTaskState = Read-Phase160FSelectJsonSafe -Path (Join-Path $SessionRootFull "task_lifecycle/active_task_state.json")
  $TeacherInboxCount = Get-Phase160FSelectFileCount -Path (Join-Path $SessionRootFull "teacher_inbox")
  $BacklogCount = Get-Phase160FSelectFileCount -Path (Join-Path $SessionRootFull "task_backlog")
  $RuntimeGuardStatus = Get-Phase160FSelectString -Object $RuntimeGuard -Name "status" -Default "UNKNOWN"
  $RuntimeGuardPass = ($null -ne $RuntimeGuard -and $RuntimeGuardStatus -eq "PASS")
  $MacroStageEligible = @("DAEMON_START", "EARLY_TICK", "SAFE_PRE_CANDIDATE", "GAP_RANK_AND_SELECT", "EXPERIENCE_ABSORB_AND_NEXT_GOAL", "NONE") -contains $MacroCycleStage
  $ActiveStatus = Get-Phase160FSelectString -Object $ActiveTaskState -Name "status" -Default "NONE"
  $ActivePlanStatus = Get-Phase160FSelectString -Object $ActivePlanItem -Name "status" -Default "NONE"
  $ActiveTaskRequiresWork = ($null -ne $ActiveTask -and $ActiveStatus -notin @("WAITING_OWNER_PROMOTION", "DONE_SESSION_LOCAL", "BLOCKED", "QUARANTINED"))
  $ActivePlanRequiresWork = ($null -ne $ActivePlanItem -and $ActivePlanStatus -in @("ACTIVE", "PENDING", "CANDIDATE_READY"))
  $AlreadySelected = Test-Path -LiteralPath (Join-Path $SelectionRoot "selected_useful_goal.json")
  $TriggerPass = (
    $CandidateWorkspacePromotionEnabled -and
    $RuntimeGuardPass -and
    $TeacherInboxCount -eq 0 -and
    $BacklogCount -eq 0 -and
    (-not $ActiveTaskRequiresWork) -and
    (-not $ActivePlanRequiresWork) -and
    $MacroStageEligible -and
    -not $AlreadySelected
  )

  if (-not $TriggerPass) {
    $Reason = [ordered]@{
      candidate_workspace_promotion_enabled = [bool]$CandidateWorkspacePromotionEnabled
      runtime_guard_pass = $RuntimeGuardPass
      teacher_inbox_count = $TeacherInboxCount
      backlog_count = $BacklogCount
      active_task_requires_work = $ActiveTaskRequiresWork
      active_plan_item_requires_work = $ActivePlanRequiresWork
      macro_stage_eligible = $MacroStageEligible
      already_selected = $AlreadySelected
    }
    Add-Phase160FSelectJsonLine -Path (Join-Path $CandidateWorkspace "change_ledger.jsonl") -Object ([ordered]@{
      event_type = "self_initiated_goal_selection_skipped"
      source = "self_initiated_goal_selector"
      duty_id = $DutyId
      macro_cycle_stage = $MacroCycleStage
      reason = $Reason
      occurred_at = (Get-Date).ToUniversalTime().ToString("o")
    })
    [pscustomobject][ordered]@{
      status = "SKIPPED"
      run_id = if ([string]::IsNullOrWhiteSpace($RunId)) { "NONE" } else { $RunId }
      session_root = $SessionRootRelative
      self_initiated_goal_selected = $false
      internal_active_task_created = $false
      reason = $Reason
    } | ConvertTo-Json -Depth 20
    return
  }

  $EvidenceScript = Resolve-Phase160FSelectPath -RepoRoot $RepoRoot -Path "modules/inspect_builder_self_growth_evidence_001.ps1"
  $ScoreScript = Resolve-Phase160FSelectPath -RepoRoot $RepoRoot -Path "modules/score_builder_self_growth_goal_001.ps1"
  $InternalTaskScript = Resolve-Phase160FSelectPath -RepoRoot $RepoRoot -Path "modules/invoke_builder_internal_active_task_creation_001.ps1"
  $EvidenceOutput = @(powershell -NoProfile -ExecutionPolicy Bypass -File $EvidenceScript -SessionRoot $SessionRootRelative -RunId $RunId -DutyId $DutyId -TickNumber $TickNumber 2>&1 | ForEach-Object { [string]$_ })
  if ($LASTEXITCODE -ne 0) {
    throw "PHASE160F_SELECT_EVIDENCE_SCAN_FAILED exit=$LASTEXITCODE output=$($EvidenceOutput -join ' | ')"
  }
  $ScoreOutput = @(powershell -NoProfile -ExecutionPolicy Bypass -File $ScoreScript -SessionRoot $SessionRootRelative -RunId $RunId 2>&1 | ForEach-Object { [string]$_ })
  if ($LASTEXITCODE -ne 0) {
    throw "PHASE160F_SELECT_GOAL_SCORE_FAILED exit=$LASTEXITCODE output=$($ScoreOutput -join ' | ')"
  }

  $Scores = Read-Phase160FSelectJsonSafe -Path (Join-Path $SelectionRoot "useful_goal_scores.json")
  if ($null -eq $Scores -or -not ($Scores.PSObject.Properties.Name -contains "scored_goals") -or @($Scores.scored_goals).Count -lt 1) {
    throw "PHASE160F_SELECT_GOAL_SCORES_MISSING"
  }
  $Top = @($Scores.scored_goals)[0]
  $OtherGoals = @($Scores.scored_goals | Where-Object { [string]$_.goal_id -ne [string]$Top.goal_id } | Select-Object -First 5)
  $SelectedGoal = [ordered]@{
    status = "PASS"
    selected_goal_id = [string]$Top.goal_id
    selected_goal_name = [string]$Top.goal_name
    reason = "Highest total_usefulness_score with strong autonomy, owner value, proof simplicity, and low dependency complexity."
    expected_new_capability = [string]$Top.expected_new_capability
    expected_candidate_files = @($Top.expected_candidate_files)
    expected_validator_files = @($Top.expected_validator_files)
    safety_boundary = [string]$Top.safety_boundary
    why_now = "teacher_inbox_count=0 and no active external work; Builder can use self_gap_inventory and usefulness_scoring to keep growing safely."
    why_not_other_goals = @($OtherGoals | ForEach-Object { "{0}: lower total_usefulness_score={1}" -f [string]$_.goal_id, [int]$_.total_usefulness_score })
    no_teacher_inbox_required = $true
    owner_approval_required = $true
    selected_at = (Get-Date).ToUniversalTime().ToString("o")
  }
  Write-Phase160FSelectJsonFile -Path (Join-Path $SelectionRoot "selected_useful_goal.json") -Object $SelectedGoal
  Write-Phase160FSelectTextFile -Path (Join-Path $SelectionRoot "self_selection_rationale.md") -Text (@(
    "# Self-Initiated Goal Selection Rationale",
    "",
    "selected_goal_id: $($SelectedGoal.selected_goal_id)",
    "selected_goal_name: $($SelectedGoal.selected_goal_name)",
    "",
    "The live runner had no teacher_inbox work and runtime_guard was PASS. It selected a useful internal goal using self_gap_inventory, usefulness_scoring, internal_active_task_creation, no_teacher_inbox_required, candidate_bundle_creation, promotion_bundle_update, and runtime_guard_required evidence.",
    "",
    "Candidate output remains session-local and requires owner promotion."
  ) -join "`n")

  $InternalTaskOutput = @(powershell -NoProfile -ExecutionPolicy Bypass -File $InternalTaskScript -SessionRoot $SessionRootRelative -RunId $RunId -DutyId $DutyId -TickNumber $TickNumber 2>&1 | ForEach-Object { [string]$_ })
  if ($LASTEXITCODE -ne 0) {
    throw "PHASE160F_SELECT_INTERNAL_ACTIVE_TASK_FAILED exit=$LASTEXITCODE output=$($InternalTaskOutput -join ' | ')"
  }
  $InternalTaskResult = ($InternalTaskOutput -join "`n") | ConvertFrom-Json
  Add-Phase160FSelectJsonLine -Path (Join-Path $CandidateWorkspace "change_ledger.jsonl") -Object ([ordered]@{
    event_type = "self_initiated_goal_selected"
    source = "self_initiated_goal_selector"
    selected_goal_id = [string]$SelectedGoal.selected_goal_id
    selected_goal_name = [string]$SelectedGoal.selected_goal_name
    internal_active_task_id = [string]$InternalTaskResult.active_task_id
    no_teacher_inbox_required = $true
    occurred_at = (Get-Date).ToUniversalTime().ToString("o")
  })
  Add-Phase160FSelectJsonLine -Path (Join-Path $SessionRootFull "event_log.jsonl") -Object ([ordered]@{
    event_type = "self_initiated_goal_selected"
    source = "self_initiated_goal_selector"
    selected_goal_id = [string]$SelectedGoal.selected_goal_id
    internal_active_task_id = [string]$InternalTaskResult.active_task_id
    occurred_at = (Get-Date).ToUniversalTime().ToString("o")
  })

  [pscustomobject][ordered]@{
    status = "PASS"
    run_id = if ([string]::IsNullOrWhiteSpace($RunId)) { "NONE" } else { $RunId }
    session_root = $SessionRootRelative
    self_initiated_goal_selected = $true
    selected_goal_id = [string]$SelectedGoal.selected_goal_id
    selected_goal_name = [string]$SelectedGoal.selected_goal_name
    internal_active_task_created = [bool]$InternalTaskResult.internal_active_task_created
    internal_active_task_id = [string]$InternalTaskResult.active_task_id
    no_teacher_inbox_required = $true
  } | ConvertTo-Json -Depth 20
} finally {
  if ($Pushed) {
    Pop-Location
  }
}
