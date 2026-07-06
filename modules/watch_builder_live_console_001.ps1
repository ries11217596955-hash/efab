param(
  [string]$SessionRoot = "",
  [string]$RunId = "",
  [int]$DurationSeconds = 90,
  [int]$PollIntervalSeconds = 5,
  [int]$ShowTailEvents = 3,
  [int]$ShowTailObserver = 3,
  [string]$ConsoleRunId = "PHASE160_LIVE_OBSERVER_CONSOLE_REPAIR_001",
  [string]$ConsoleRuntimeRoot = ""
)

$ErrorActionPreference = "Stop"

function Normalize-Phase160ConsoleFullPath {
  param([string]$Path)
  return [System.IO.Path]::GetFullPath($Path).TrimEnd([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar)
}

function Resolve-Phase160ConsoleRepoRoot {
  $scriptRootCandidate = $PSScriptRoot
  if ([string]::IsNullOrWhiteSpace($scriptRootCandidate) -and -not [string]::IsNullOrWhiteSpace($PSCommandPath)) {
    $scriptRootCandidate = Split-Path -Path $PSCommandPath -Parent
  }
  if ([string]::IsNullOrWhiteSpace($scriptRootCandidate) -and -not [string]::IsNullOrWhiteSpace($MyInvocation.MyCommand.Path)) {
    $scriptRootCandidate = Split-Path -Path $MyInvocation.MyCommand.Path -Parent
  }
  if ([string]::IsNullOrWhiteSpace($scriptRootCandidate)) {
    throw "PHASE160_LIVE_CONSOLE_SCRIPT_ROOT_UNAVAILABLE"
  }
  return Normalize-Phase160ConsoleFullPath -Path (Join-Path $scriptRootCandidate "..")
}

function Resolve-Phase160ConsolePath {
  param([string]$RepoRoot, [string]$Path)
  if ([System.IO.Path]::IsPathRooted($Path)) {
    return [System.IO.Path]::GetFullPath($Path)
  }
  return [System.IO.Path]::GetFullPath((Join-Path $RepoRoot $Path))
}

function ConvertTo-Phase160ConsoleRelativePath {
  param([string]$RepoRoot, [string]$FullPath)
  $normalizedRoot = Normalize-Phase160ConsoleFullPath -Path $RepoRoot
  $normalizedPath = Normalize-Phase160ConsoleFullPath -Path $FullPath
  if ($normalizedPath -eq $normalizedRoot) {
    return "."
  }
  if (-not $normalizedPath.StartsWith($normalizedRoot + [System.IO.Path]::DirectorySeparatorChar, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw "PHASE160_LIVE_CONSOLE_PATH_OUTSIDE_REPO=$FullPath"
  }
  return ($normalizedPath.Substring($normalizedRoot.Length + 1) -replace "\\", "/")
}

function Write-Phase160ConsoleJsonFile {
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

function Read-Phase160ConsoleJsonSafe {
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

function Read-Phase160ConsoleJsonLineSafe {
  param([string]$Line)
  try {
    if ([string]::IsNullOrWhiteSpace($Line)) {
      return $null
    }
    return $Line | ConvertFrom-Json
  } catch {
    return $null
  }
}

function Get-Phase160ConsoleJsonLineCount {
  param([string]$Path)
  if (-not (Test-Path -LiteralPath $Path)) {
    return 0
  }
  return @((Get-Content -LiteralPath $Path -ErrorAction SilentlyContinue) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }).Count
}

function Get-Phase160ConsoleMacroStageCount {
  param([string]$SessionRootFull)
  $summaryPath = Join-Path $SessionRootFull "self_growth/macro_cycle_summary.json"
  $summary = Read-Phase160ConsoleJsonSafe -Path $summaryPath
  if ($null -ne $summary -and $summary.PSObject.Properties.Name -contains "duty_count_completed") {
    return [int]$summary.duty_count_completed
  }
  $selfGrowthRoot = Join-Path $SessionRootFull "self_growth"
  if (-not (Test-Path -LiteralPath $selfGrowthRoot)) {
    return 0
  }
  return @(Get-ChildItem -LiteralPath $selfGrowthRoot -Directory -ErrorAction SilentlyContinue | Where-Object {
    Test-Path -LiteralPath (Join-Path $_.FullName "macro_cycle_artifact.json")
  }).Count
}

function Get-Phase160ConsoleTailLines {
  param([string]$Path, [int]$Count)
  if ($Count -lt 1 -or -not (Test-Path -LiteralPath $Path)) {
    return @()
  }
  return @(Get-Content -LiteralPath $Path -Tail $Count -ErrorAction SilentlyContinue | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
}

function Get-Phase160ConsoleJsonFileSummary {
  param([string]$Directory, [string]$Pattern = "*.json")
  if (-not (Test-Path -LiteralPath $Directory)) {
    return [pscustomobject][ordered]@{
      count = 0
      latest_name = "NONE"
    }
  }
  $files = @(Get-ChildItem -LiteralPath $Directory -File -Filter $Pattern -ErrorAction SilentlyContinue | Where-Object { $_.Name -ne "README.json" } | Sort-Object LastWriteTimeUtc, Name)
  $latest = "NONE"
  if ($files.Count -gt 0) {
    $latest = $files[-1].Name
  }
  return [pscustomobject][ordered]@{
    count = $files.Count
    latest_name = $latest
  }
}

function Format-Phase160ConsoleValue {
  param([object]$Value)
  if ($null -eq $Value -or [string]::IsNullOrWhiteSpace([string]$Value)) {
    return "NONE"
  }
  return ([string]$Value).Trim() -replace "\s+", "_"
}

function Get-Phase160ConsoleTailSummary {
  param([string]$Line)
  $json = Read-Phase160ConsoleJsonLineSafe -Line $Line
  if ($null -eq $json) {
    $clean = Format-Phase160ConsoleValue -Value $Line
    if ($clean.Length -gt 140) {
      return $clean.Substring(0, 140)
    }
    return $clean
  }

  $eventType = Format-Phase160ConsoleValue -Value $json.event_type
  $tickId = Format-Phase160ConsoleValue -Value $json.tick_id
  $poll = Format-Phase160ConsoleValue -Value $json.poll_number
  $heartbeat = Format-Phase160ConsoleValue -Value $json.heartbeat_count
  $stale = Format-Phase160ConsoleValue -Value $json.stale_heartbeat
  if ($tickId -ne "NONE") {
    return "event=$eventType tick=$tickId heartbeat=$heartbeat stale=$stale"
  }
  if ($poll -ne "NONE") {
    return "event=$eventType poll=$poll heartbeat=$heartbeat stale=$stale"
  }
  return "event=$eventType heartbeat=$heartbeat stale=$stale"
}

function Get-Phase160ConsoleLatestEventName {
  param([string]$EventLogPath)
  $tail = @(Get-Phase160ConsoleTailLines -Path $EventLogPath -Count 1)
  if ($tail.Count -lt 1) {
    return "NONE"
  }
  $json = Read-Phase160ConsoleJsonLineSafe -Line ([string]$tail[-1])
  if ($null -eq $json) {
    return "UNREADABLE"
  }
  $tick = Format-Phase160ConsoleValue -Value $json.tick_id
  if ($tick -ne "NONE") {
    return $tick
  }
  return Format-Phase160ConsoleValue -Value $json.event_type
}

function Assert-Phase160ConsoleEquals {
  param([object]$Actual, [object]$Expected, [string]$Name)
  if ($Actual -ne $Expected) {
    throw "PHASE160_LIVE_CONSOLE_VALUE_UNEXPECTED=$Name actual=$Actual expected=$Expected"
  }
}

function Assert-Phase160ConsoleRunIdSafe {
  param([string]$RunId)
  if ([string]::IsNullOrWhiteSpace($RunId)) {
    return
  }
  if ($RunId.IndexOfAny([char[]]@("/", "\")) -ge 0) {
    throw "PHASE160_LIVE_CONSOLE_RUN_ID_MUST_BE_LEAF=$RunId"
  }
}

function Get-Phase160ConsoleRemoteHead {
  param([string]$ExpectedBranch)
  $remoteHead = (git rev-parse --short "origin/$ExpectedBranch" 2>$null)
  if ([string]::IsNullOrWhiteSpace($remoteHead)) {
    throw "PHASE160_LIVE_CONSOLE_REMOTE_HEAD_UNAVAILABLE"
  }
  return $remoteHead.Trim()
}

function Write-Phase160ConsoleVisibleLine {
  param([string]$Line, [string]$SamplePath)
  Write-Host $Line
  [System.IO.File]::AppendAllText($SamplePath, "$Line`n", [System.Text.UTF8Encoding]::new($false))
}

$RepoRoot = Resolve-Phase160ConsoleRepoRoot
$ExpectedBranch = "phase110-idempotent-autonomy-trial-runtime"
$RepairId = "PHASE160_LIVE_OBSERVER_CONSOLE_REPAIR_V1"
if ([string]::IsNullOrWhiteSpace($ConsoleRuntimeRoot)) {
  $ConsoleRuntimeRoot = "runtime_sessions/live_growth_console/$ConsoleRunId"
}
$Pushed = $false

try {
  Push-Location $RepoRoot
  $Pushed = $true

  foreach ($identityFile in @("CAPABILITY_ROADMAP.json", "GENESIS_STATE.json", "TASK_QUEUE.json", "packs/registry.json", "orchestrator/run.ps1")) {
    if (-not (Test-Path -LiteralPath (Resolve-Phase160ConsolePath -RepoRoot $RepoRoot -Path $identityFile))) {
      throw "STOP=WRONG_AGENT_BUILDER_REPO missing=$identityFile"
    }
  }

  $Branch = (git branch --show-current).Trim()
  Assert-Phase160ConsoleEquals -Actual $Branch -Expected $ExpectedBranch -Name "current_branch"
  $Head = (git rev-parse --short HEAD).Trim()
  $RemoteHead = Get-Phase160ConsoleRemoteHead -ExpectedBranch $ExpectedBranch
  Assert-Phase160ConsoleEquals -Actual $Head -Expected $RemoteHead -Name "current_synced_repo_head"
  $ExpectedHeadSource = "CURRENT_SYNCED_REPO_HEAD"

  $SessionRootExplicit = ($PSBoundParameters.ContainsKey("SessionRoot") -and -not [string]::IsNullOrWhiteSpace($SessionRoot))
  Assert-Phase160ConsoleRunIdSafe -RunId $RunId
  if (-not [string]::IsNullOrWhiteSpace($RunId) -and -not $SessionRootExplicit) {
    $SessionRoot = "runtime_sessions/live_growth/$RunId"
  }
  if ([string]::IsNullOrWhiteSpace($SessionRoot)) {
    $SessionRoot = "runtime_sessions/live_growth/PHASE160C_OWNER_SUPERVISED_LIVE_MACRO_RUN_001"
  }

  if ($DurationSeconds -lt 1) {
    throw "PHASE160_LIVE_CONSOLE_INVALID_DURATION=$DurationSeconds"
  }
  if ($PollIntervalSeconds -lt 1) {
    throw "PHASE160_LIVE_CONSOLE_INVALID_POLL_INTERVAL=$PollIntervalSeconds"
  }
  if ($ShowTailEvents -lt 0) {
    throw "PHASE160_LIVE_CONSOLE_INVALID_SHOW_TAIL_EVENTS=$ShowTailEvents"
  }
  if ($ShowTailObserver -lt 0) {
    throw "PHASE160_LIVE_CONSOLE_INVALID_SHOW_TAIL_OBSERVER=$ShowTailObserver"
  }

  $SessionRootFull = Resolve-Phase160ConsolePath -RepoRoot $RepoRoot -Path $SessionRoot
  $SessionRootRelative = ConvertTo-Phase160ConsoleRelativePath -RepoRoot $RepoRoot -FullPath $SessionRootFull
  if (-not (Test-Path -LiteralPath $SessionRootFull)) {
    throw "PHASE160_LIVE_CONSOLE_SESSION_ROOT_MISSING=$SessionRootRelative"
  }

  $ConsoleRuntimeRootFull = Resolve-Phase160ConsolePath -RepoRoot $RepoRoot -Path $ConsoleRuntimeRoot
  $ConsoleRuntimeRootRelative = ConvertTo-Phase160ConsoleRelativePath -RepoRoot $RepoRoot -FullPath $ConsoleRuntimeRootFull
  New-Item -ItemType Directory -Force -Path $ConsoleRuntimeRootFull | Out-Null
  $SamplePath = Join-Path $ConsoleRuntimeRootFull "console_output_sample.txt"
  $ResultPath = Join-Path $ConsoleRuntimeRootFull "console_run_result.json"
  [System.IO.File]::WriteAllText($SamplePath, "", [System.Text.UTF8Encoding]::new($false))

  $HeartbeatPath = Join-Path $SessionRootFull "heartbeat.json"
  $CurrentStatePath = Join-Path $SessionRootFull "current_state.json"
  $FinalStatePath = Join-Path $SessionRootFull "final_state.json"
  $EventLogPath = Join-Path $SessionRootFull "event_log.jsonl"
  $ObserverLogPath = Join-Path $SessionRootFull "observer_log.jsonl"
  $BlockerQueuePath = Join-Path $SessionRootFull "blocker_queue"
  $TeacherInboxPath = Join-Path $SessionRootFull "teacher_inbox"
  $TeacherDigestPath = Join-Path $SessionRootFull "teacher_digest"
  $TeacherConsumedPath = Join-Path $SessionRootFull "teacher_consumed"
  $TeacherQuarantinePath = Join-Path $SessionRootFull "teacher_quarantine"
  $TaskBacklogPath = Join-Path $SessionRootFull "task_backlog"
  $ActiveTaskRecordPath = Join-Path $SessionRootFull "active_task/active_task.json"
  $ActivePlanItemPath = Join-Path $SessionRootFull "active_task/active_plan_item.json"
  $TeacherOutboxPath = Join-Path $SessionRootFull "teacher_outbox"
  $StopFlagPath = Join-Path $SessionRootFull "stop.flag"
  $ExperienceLedgerPath = Join-Path $SessionRootFull "self_growth/experience_ledger.jsonl"
  $NextGoalPath = Join-Path $SessionRootFull "self_growth/next_goal.json"
  $RunManifestPath = Join-Path $SessionRootFull "run_manifest.json"
  $RuntimeIdentityPath = Join-Path $SessionRootFull "runtime_identity.json"
  $RuntimeGuardPath = Join-Path $SessionRootFull "runtime_guard.json"
  $CandidateBundleRoot = Join-Path $SessionRootFull "candidate_workspace/candidate_bundles"
  $PromotionManifestPath = Join-Path $SessionRootFull "promotion_bundle/promotion_manifest.json"
  $ActiveTaskStatePath = Join-Path $SessionRootFull "task_lifecycle/active_task_state.json"
  $ChangeLedgerPath = Join-Path $SessionRootFull "candidate_workspace/change_ledger.jsonl"
  $SelectedUsefulGoalPath = Join-Path $SessionRootFull "self_initiated_goal_selection/selected_useful_goal.json"
  $InternalActiveTaskPath = Join-Path $SessionRootFull "self_initiated_goal_selection/internal_active_task.json"

  $StartTime = Get-Date
  $EndTime = $StartTime.AddSeconds($DurationSeconds)
  $PollCount = 0
  $LiveLineCount = 0
  $StaleHeartbeatDetected = $false
  $HeartbeatRead = $false
  $CurrentStateRead = $false
  $EventLogRead = $false
  $ObserverLogRead = $false
  $BlockerQueueRead = $false
  $TeacherInboxRead = $false
  $TeacherOutboxRead = $false
  $StopFlagRead = $false
  $SelfGrowthFieldsPrinted = $false
  $MacroFieldsPrinted = $false
  $TaskIntakeFieldsPrinted = $false
  $Phase160EFieldsPrinted = $false
  $Phase160HQualityFieldsPrinted = $false
  $Phase160JOwnerTaskFieldsPrinted = $false
  $Phase161ASchoolFieldsPrinted = $false
  $Phase161BLearningModeFieldsPrinted = $false
  $Phase161B1OwnerInboxRouterFieldsPrinted = $false
  $StaleAfterSeconds = [Math]::Max(25, $PollIntervalSeconds * 5)

  while ((Get-Date) -lt $EndTime) {
    $PollCount += 1
    $Now = Get-Date
    $Heartbeat = Read-Phase160ConsoleJsonSafe -Path $HeartbeatPath
    $CurrentState = Read-Phase160ConsoleJsonSafe -Path $CurrentStatePath
    $HeartbeatRead = $HeartbeatRead -or ($null -ne $Heartbeat)
    $CurrentStateRead = $CurrentStateRead -or ($null -ne $CurrentState)

    $HeartbeatStatus = "MISSING"
    $HeartbeatCount = "NONE"
    $HeartbeatAgeSeconds = "NONE"
    $StaleThisPoll = $true
    if ($null -ne $Heartbeat) {
      $HeartbeatStatus = Format-Phase160ConsoleValue -Value $Heartbeat.status
      $HeartbeatCount = Format-Phase160ConsoleValue -Value $Heartbeat.heartbeat_count
      if (-not [string]::IsNullOrWhiteSpace([string]$Heartbeat.updated_at)) {
        $LastSeen = [datetime]$Heartbeat.updated_at
        $HeartbeatAgeSecondsValue = [Math]::Floor(($Now.ToUniversalTime() - $LastSeen.ToUniversalTime()).TotalSeconds)
        $HeartbeatAgeSeconds = [string]$HeartbeatAgeSecondsValue
        $StaleThisPoll = $HeartbeatAgeSecondsValue -gt $StaleAfterSeconds
      }
    }
    if ($StaleThisPoll) {
      $StaleHeartbeatDetected = $true
    }

    $CurrentTick = "NONE"
    if ($null -ne $CurrentState) {
      $CurrentTick = Format-Phase160ConsoleValue -Value $CurrentState.current_tick
    }
    if ($CurrentTick -eq "NONE") {
      $CurrentTick = $HeartbeatCount
    }

    $SelfGrowthEnabled = "False"
    $SelfGrowthDutyCount = "0"
    $LastSelfGrowthDuty = "NONE"
    $LastSelfGrowthGap = "NONE"
    $LastSelfGrowthStatus = "NONE"
    $NextSelfGrowthGap = "NONE"
    $MacroCycleEnabled = "False"
    $MacroCycleId = "NONE"
    $LastMacroCycleStage = "NONE"
    $LastMacroDecision = "NONE"
    if ($null -ne $Heartbeat -and $Heartbeat.PSObject.Properties.Name -contains "self_growth_enabled") {
      $SelfGrowthEnabled = Format-Phase160ConsoleValue -Value $Heartbeat.self_growth_enabled
    }
    if ($null -ne $Heartbeat -and $Heartbeat.PSObject.Properties.Name -contains "self_growth_duty_count") {
      $SelfGrowthDutyCount = Format-Phase160ConsoleValue -Value $Heartbeat.self_growth_duty_count
    }
    if ($null -ne $Heartbeat -and $Heartbeat.PSObject.Properties.Name -contains "macro_cycle_enabled") {
      $MacroCycleEnabled = Format-Phase160ConsoleValue -Value $Heartbeat.macro_cycle_enabled
    }
    if ($null -ne $Heartbeat -and $Heartbeat.PSObject.Properties.Name -contains "macro_cycle_id") {
      $MacroCycleId = Format-Phase160ConsoleValue -Value $Heartbeat.macro_cycle_id
    }
    if ($null -ne $Heartbeat -and $Heartbeat.PSObject.Properties.Name -contains "last_macro_cycle_stage") {
      $LastMacroCycleStage = Format-Phase160ConsoleValue -Value $Heartbeat.last_macro_cycle_stage
    }
    if ($null -ne $Heartbeat -and $Heartbeat.PSObject.Properties.Name -contains "last_macro_decision") {
      $LastMacroDecision = Format-Phase160ConsoleValue -Value $Heartbeat.last_macro_decision
    }
    if ($null -ne $CurrentState) {
      if ($CurrentState.PSObject.Properties.Name -contains "self_growth_enabled") {
        $SelfGrowthEnabled = Format-Phase160ConsoleValue -Value $CurrentState.self_growth_enabled
      }
      if ($CurrentState.PSObject.Properties.Name -contains "self_growth_duty_count") {
        $SelfGrowthDutyCount = Format-Phase160ConsoleValue -Value $CurrentState.self_growth_duty_count
      }
      if ($CurrentState.PSObject.Properties.Name -contains "last_self_growth_duty_id") {
        $LastSelfGrowthDuty = Format-Phase160ConsoleValue -Value $CurrentState.last_self_growth_duty_id
      }
      if ($CurrentState.PSObject.Properties.Name -contains "last_self_growth_gap") {
        $LastSelfGrowthGap = Format-Phase160ConsoleValue -Value $CurrentState.last_self_growth_gap
      }
      if ($CurrentState.PSObject.Properties.Name -contains "last_self_growth_status") {
        $LastSelfGrowthStatus = Format-Phase160ConsoleValue -Value $CurrentState.last_self_growth_status
      }
      if ($CurrentState.PSObject.Properties.Name -contains "next_self_growth_gap") {
        $NextSelfGrowthGap = Format-Phase160ConsoleValue -Value $CurrentState.next_self_growth_gap
      }
      if ($CurrentState.PSObject.Properties.Name -contains "macro_cycle_enabled") {
        $MacroCycleEnabled = Format-Phase160ConsoleValue -Value $CurrentState.macro_cycle_enabled
      }
      if ($CurrentState.PSObject.Properties.Name -contains "macro_cycle_id") {
        $MacroCycleId = Format-Phase160ConsoleValue -Value $CurrentState.macro_cycle_id
      }
      if ($CurrentState.PSObject.Properties.Name -contains "last_macro_cycle_stage") {
        $LastMacroCycleStage = Format-Phase160ConsoleValue -Value $CurrentState.last_macro_cycle_stage
      }
      if ($CurrentState.PSObject.Properties.Name -contains "last_macro_decision") {
        $LastMacroDecision = Format-Phase160ConsoleValue -Value $CurrentState.last_macro_decision
      }
    }
    $FinalState = Read-Phase160ConsoleJsonSafe -Path $FinalStatePath
    if ($null -ne $FinalState) {
      if ($FinalState.PSObject.Properties.Name -contains "macro_cycle_enabled") {
        $MacroCycleEnabled = Format-Phase160ConsoleValue -Value $FinalState.macro_cycle_enabled
      }
      if ($FinalState.PSObject.Properties.Name -contains "macro_cycle_id") {
        $MacroCycleId = Format-Phase160ConsoleValue -Value $FinalState.macro_cycle_id
      }
      if ($FinalState.PSObject.Properties.Name -contains "last_macro_cycle_stage") {
        $LastMacroCycleStage = Format-Phase160ConsoleValue -Value $FinalState.last_macro_cycle_stage
      }
      if ($FinalState.PSObject.Properties.Name -contains "last_macro_decision") {
        $LastMacroDecision = Format-Phase160ConsoleValue -Value $FinalState.last_macro_decision
      }
    }
    $RunManifest = Read-Phase160ConsoleJsonSafe -Path $RunManifestPath
    $RuntimeIdentity = Read-Phase160ConsoleJsonSafe -Path $RuntimeIdentityPath
    $RuntimeGuard = Read-Phase160ConsoleJsonSafe -Path $RuntimeGuardPath
    $PromotionManifest = Read-Phase160ConsoleJsonSafe -Path $PromotionManifestPath
    $ActiveTaskState = Read-Phase160ConsoleJsonSafe -Path $ActiveTaskStatePath
    $SelectedUsefulGoalRecord = Read-Phase160ConsoleJsonSafe -Path $SelectedUsefulGoalPath
    $InternalActiveTaskRecord = Read-Phase160ConsoleJsonSafe -Path $InternalActiveTaskPath
    $RunHead = if ($null -ne $RunManifest -and $RunManifest.PSObject.Properties.Name -contains "run_head") { Format-Phase160ConsoleValue -Value $RunManifest.run_head } elseif ($null -ne $CurrentState -and $CurrentState.PSObject.Properties.Name -contains "run_head") { Format-Phase160ConsoleValue -Value $CurrentState.run_head } else { "NONE" }
    $CurrentHead = if ($null -ne $RuntimeIdentity -and $RuntimeIdentity.PSObject.Properties.Name -contains "current_head") { Format-Phase160ConsoleValue -Value $RuntimeIdentity.current_head } elseif ($null -ne $CurrentState -and $CurrentState.PSObject.Properties.Name -contains "current_head") { Format-Phase160ConsoleValue -Value $CurrentState.current_head } else { "NONE" }
    $HeadMatch = if ($null -ne $RuntimeIdentity -and $RuntimeIdentity.PSObject.Properties.Name -contains "head_match") { Format-Phase160ConsoleValue -Value $RuntimeIdentity.head_match } elseif ($null -ne $CurrentState -and $CurrentState.PSObject.Properties.Name -contains "head_match") { Format-Phase160ConsoleValue -Value $CurrentState.head_match } else { "False" }
    $LiveRepoGuard = if ($null -ne $RuntimeGuard -and $RuntimeGuard.PSObject.Properties.Name -contains "status") { Format-Phase160ConsoleValue -Value $RuntimeGuard.status } elseif ($null -ne $CurrentState -and $CurrentState.PSObject.Properties.Name -contains "live_repo_guard") { Format-Phase160ConsoleValue -Value $CurrentState.live_repo_guard } else { "UNKNOWN" }
    $RuntimeGuardStatus = $LiveRepoGuard
    $GuardBlockReason = if ($null -ne $RuntimeGuard -and $RuntimeGuard.PSObject.Properties.Name -contains "blocked_reasons") { Format-Phase160ConsoleValue -Value ((@($RuntimeGuard.blocked_reasons | ForEach-Object { [string]$_ }) -join ",")) } else { "NONE" }
    if ([string]::IsNullOrWhiteSpace($GuardBlockReason)) {
      $GuardBlockReason = "NONE"
    }
    $AllowedRuntimeOutputCount = if ($null -ne $RuntimeGuard -and $RuntimeGuard.PSObject.Properties.Name -contains "allowed_runtime_output_count") { Format-Phase160ConsoleValue -Value $RuntimeGuard.allowed_runtime_output_count } else { "0" }
    $AllowedTrackedRuntimeSampleChange = if ($null -ne $RuntimeGuard -and $RuntimeGuard.PSObject.Properties.Name -contains "allowed_tracked_runtime_sample_change") { Format-Phase160ConsoleValue -Value $RuntimeGuard.allowed_tracked_runtime_sample_change } else { "False" }
    $UnsafeTrackedMutationCount = if ($null -ne $RuntimeGuard -and $RuntimeGuard.PSObject.Properties.Name -contains "unsafe_tracked_code_mutation_count") { Format-Phase160ConsoleValue -Value $RuntimeGuard.unsafe_tracked_code_mutation_count } else { "0" }
    $ProtectedStateMutationCount = if ($null -ne $RuntimeGuard -and $RuntimeGuard.PSObject.Properties.Name -contains "protected_state_mutation_count") { Format-Phase160ConsoleValue -Value $RuntimeGuard.protected_state_mutation_count } else { "0" }
    $CandidateProductionEnabled = if ($null -ne $RuntimeGuard -and $RuntimeGuard.PSObject.Properties.Name -contains "candidate_production_enabled") { Format-Phase160ConsoleValue -Value $RuntimeGuard.candidate_production_enabled } elseif ($null -ne $CurrentState -and $CurrentState.PSObject.Properties.Name -contains "candidate_production_enabled") { Format-Phase160ConsoleValue -Value $CurrentState.candidate_production_enabled } else { "False" }
    $CandidateWorkspacePromotionEnabled = if ($null -ne $CurrentState -and $CurrentState.PSObject.Properties.Name -contains "candidate_workspace_promotion_enabled") { Format-Phase160ConsoleValue -Value $CurrentState.candidate_workspace_promotion_enabled } else { "False" }
    $CandidateWorkspaceStatus = if ($null -ne $CurrentState -and $CurrentState.PSObject.Properties.Name -contains "candidate_workspace_status") { Format-Phase160ConsoleValue -Value $CurrentState.candidate_workspace_status } elseif ($CandidateWorkspacePromotionEnabled -eq "True" -and $LiveRepoGuard -eq "PASS") { "ENABLED" } elseif ($CandidateWorkspacePromotionEnabled -eq "True") { "BLOCKED" } else { "DISABLED" }
    $CandidateCount = 0
    $ReadyCandidateCount = 0
    $QualityGateEnabled = "True"
    $QualityReadyCount = 0
    $QualityResultFileCount = 0
    $QualityDecisionCount = 0
    $QualityArtifactConsistency = "UNKNOWN"
    $MissingQualityResultCount = 0
    $RevisionRequiredCount = 0
    $DraftCandidateCount = 0
    $QuarantinedCandidateCount = 0
    $BlockedCandidateCount = 0
    $LastQualityDecision = "NONE"
    $LastRevisionRequest = "NONE"
    $OwnerPromotionAllowed = "False"
    $LastCandidateId = "NONE"
    if (Test-Path -LiteralPath $CandidateBundleRoot) {
      $candidateBundleDirs = @(Get-ChildItem -LiteralPath $CandidateBundleRoot -Directory -ErrorAction SilentlyContinue | Sort-Object LastWriteTimeUtc, Name)
      foreach ($candidateBundleDir in $candidateBundleDirs) {
        $candidateManifest = Read-Phase160ConsoleJsonSafe -Path (Join-Path $candidateBundleDir.FullName "candidate_manifest.json")
        $candidateStatus = Read-Phase160ConsoleJsonSafe -Path (Join-Path $candidateBundleDir.FullName "candidate_status.json")
        $qualityRecord = Read-Phase160ConsoleJsonSafe -Path (Join-Path $candidateBundleDir.FullName "candidate_quality/quality_result.json")
        if ($null -ne $qualityRecord) {
          $QualityResultFileCount += 1
        } else {
          $qualityRecord = Read-Phase160ConsoleJsonSafe -Path (Join-Path $candidateBundleDir.FullName "quality_gate/quality_gate_result.json")
        }
        if ($null -eq $candidateManifest) {
          continue
        }
        $CandidateCount += 1
        $QualityDecisionCount += 1
        $decision = if ($null -ne $qualityRecord -and $qualityRecord.PSObject.Properties.Name -contains "quality_status") { [string]$qualityRecord.quality_status } elseif ($null -ne $candidateStatus -and $candidateStatus.PSObject.Properties.Name -contains "quality_status") { [string]$candidateStatus.quality_status } elseif ($null -ne $candidateStatus -and $candidateStatus.PSObject.Properties.Name -contains "status") { [string]$candidateStatus.status } elseif ($candidateManifest.PSObject.Properties.Name -contains "quality_status") { [string]$candidateManifest.quality_status } elseif ($candidateManifest.PSObject.Properties.Name -contains "decision") { [string]$candidateManifest.decision } else { "UNKNOWN" }
        $candidateOwnerPromotionAllowed = if ($null -ne $qualityRecord -and $qualityRecord.PSObject.Properties.Name -contains "owner_promotion_allowed") { [bool]$qualityRecord.owner_promotion_allowed } elseif ($null -ne $candidateStatus -and $candidateStatus.PSObject.Properties.Name -contains "owner_promotion_allowed") { [bool]$candidateStatus.owner_promotion_allowed } elseif ($candidateManifest.PSObject.Properties.Name -contains "owner_promotion_allowed") { [bool]$candidateManifest.owner_promotion_allowed } else { $decision -eq "CANDIDATE_READY" }
        if ($decision -eq "CANDIDATE_READY" -and $candidateOwnerPromotionAllowed) {
          $ReadyCandidateCount += 1
          $QualityReadyCount += 1
        }
        if ($decision -eq "REVISION_REQUIRED") {
          $RevisionRequiredCount += 1
        }
        if ($decision -eq "CANDIDATE_DRAFT") {
          $DraftCandidateCount += 1
        }
        if ($decision -match "QUARANTINE|QUARANTINED") {
          $QuarantinedCandidateCount += 1
        }
        if ($decision -match "BLOCKED") {
          $BlockedCandidateCount += 1
        }
        $LastCandidateId = if ($candidateManifest.PSObject.Properties.Name -contains "candidate_id") { Format-Phase160ConsoleValue -Value $candidateManifest.candidate_id } else { Format-Phase160ConsoleValue -Value $candidateBundleDir.Name }
        $LastQualityDecision = Format-Phase160ConsoleValue -Value $decision
        $LastRevisionRequest = if ($null -ne $qualityRecord -and $qualityRecord.PSObject.Properties.Name -contains "revision_request_path") { Format-Phase160ConsoleValue -Value $qualityRecord.revision_request_path } elseif ($null -ne $candidateStatus -and $candidateStatus.PSObject.Properties.Name -contains "revision_request_path") { Format-Phase160ConsoleValue -Value $candidateStatus.revision_request_path } elseif ($candidateManifest.PSObject.Properties.Name -contains "revision_request_path") { Format-Phase160ConsoleValue -Value $candidateManifest.revision_request_path } else { "NONE" }
        if ($candidateOwnerPromotionAllowed) {
          $OwnerPromotionAllowed = "True"
        }
      }
    }
    if ($null -ne $PromotionManifest) {
      if ($PromotionManifest.PSObject.Properties.Name -contains "quality_gate_enabled") { $QualityGateEnabled = Format-Phase160ConsoleValue -Value $PromotionManifest.quality_gate_enabled }
      if ($PromotionManifest.PSObject.Properties.Name -contains "quality_ready_count") { $QualityReadyCount = [int]$PromotionManifest.quality_ready_count }
      if ($PromotionManifest.PSObject.Properties.Name -contains "quality_result_file_count") { $QualityResultFileCount = [int]$PromotionManifest.quality_result_file_count }
      if ($PromotionManifest.PSObject.Properties.Name -contains "quality_decision_count") { $QualityDecisionCount = [int]$PromotionManifest.quality_decision_count }
      if ($PromotionManifest.PSObject.Properties.Name -contains "quality_artifact_consistency_status") { $QualityArtifactConsistency = Format-Phase160ConsoleValue -Value $PromotionManifest.quality_artifact_consistency_status }
      if ($PromotionManifest.PSObject.Properties.Name -contains "missing_quality_result_count") { $MissingQualityResultCount = [int]$PromotionManifest.missing_quality_result_count }
      if ($PromotionManifest.PSObject.Properties.Name -contains "revision_required_count") { $RevisionRequiredCount = [int]$PromotionManifest.revision_required_count }
      if ($PromotionManifest.PSObject.Properties.Name -contains "draft_candidate_count") { $DraftCandidateCount = [int]$PromotionManifest.draft_candidate_count }
      if ($PromotionManifest.PSObject.Properties.Name -contains "quarantined_candidate_count") { $QuarantinedCandidateCount = [int]$PromotionManifest.quarantined_candidate_count }
      if ($PromotionManifest.PSObject.Properties.Name -contains "blocked_candidate_count") { $BlockedCandidateCount = [int]$PromotionManifest.blocked_candidate_count }
      if ($PromotionManifest.PSObject.Properties.Name -contains "last_quality_decision") { $LastQualityDecision = Format-Phase160ConsoleValue -Value $PromotionManifest.last_quality_decision }
      if ($PromotionManifest.PSObject.Properties.Name -contains "last_revision_request") { $LastRevisionRequest = Format-Phase160ConsoleValue -Value $PromotionManifest.last_revision_request }
      if ($PromotionManifest.PSObject.Properties.Name -contains "owner_promotion_allowed") { $OwnerPromotionAllowed = Format-Phase160ConsoleValue -Value $PromotionManifest.owner_promotion_allowed }
    } elseif ($null -ne $CurrentState) {
      if ($CurrentState.PSObject.Properties.Name -contains "quality_gate_enabled") { $QualityGateEnabled = Format-Phase160ConsoleValue -Value $CurrentState.quality_gate_enabled }
      if ($CurrentState.PSObject.Properties.Name -contains "quality_ready_count") { $QualityReadyCount = [int]$CurrentState.quality_ready_count }
      if ($CurrentState.PSObject.Properties.Name -contains "quality_result_file_count") { $QualityResultFileCount = [int]$CurrentState.quality_result_file_count }
      if ($CurrentState.PSObject.Properties.Name -contains "quality_decision_count") { $QualityDecisionCount = [int]$CurrentState.quality_decision_count }
      if ($CurrentState.PSObject.Properties.Name -contains "quality_artifact_consistency_status") { $QualityArtifactConsistency = Format-Phase160ConsoleValue -Value $CurrentState.quality_artifact_consistency_status }
      if ($CurrentState.PSObject.Properties.Name -contains "missing_quality_result_count") { $MissingQualityResultCount = [int]$CurrentState.missing_quality_result_count }
      if ($CurrentState.PSObject.Properties.Name -contains "revision_required_count") { $RevisionRequiredCount = [int]$CurrentState.revision_required_count }
      if ($CurrentState.PSObject.Properties.Name -contains "draft_candidate_count") { $DraftCandidateCount = [int]$CurrentState.draft_candidate_count }
      if ($CurrentState.PSObject.Properties.Name -contains "blocked_candidate_count") { $BlockedCandidateCount = [int]$CurrentState.blocked_candidate_count }
      if ($CurrentState.PSObject.Properties.Name -contains "last_quality_decision") { $LastQualityDecision = Format-Phase160ConsoleValue -Value $CurrentState.last_quality_decision }
      if ($CurrentState.PSObject.Properties.Name -contains "last_revision_request") { $LastRevisionRequest = Format-Phase160ConsoleValue -Value $CurrentState.last_revision_request }
      if ($CurrentState.PSObject.Properties.Name -contains "owner_promotion_allowed") { $OwnerPromotionAllowed = Format-Phase160ConsoleValue -Value $CurrentState.owner_promotion_allowed }
    }
    $PromotionBundleStatus = if ($null -ne $PromotionManifest -and $PromotionManifest.PSObject.Properties.Name -contains "promotion_status") { Format-Phase160ConsoleValue -Value $PromotionManifest.promotion_status } elseif ($null -ne $CurrentState -and $CurrentState.PSObject.Properties.Name -contains "promotion_bundle_status") { Format-Phase160ConsoleValue -Value $CurrentState.promotion_bundle_status } else { "NONE" }
    $ActiveTaskStatus = if ($null -ne $ActiveTaskState -and $ActiveTaskState.PSObject.Properties.Name -contains "status") { Format-Phase160ConsoleValue -Value $ActiveTaskState.status } elseif ($null -ne $CurrentState -and $CurrentState.PSObject.Properties.Name -contains "active_task_status") { Format-Phase160ConsoleValue -Value $CurrentState.active_task_status } else { "NONE" }
    $PlanPendingCount = if ($null -ne $CurrentState -and $CurrentState.PSObject.Properties.Name -contains "plan_pending_count") { [int]$CurrentState.plan_pending_count } else { 0 }
    $PlanActiveCount = if ($null -ne $CurrentState -and $CurrentState.PSObject.Properties.Name -contains "plan_active_count") { [int]$CurrentState.plan_active_count } else { 0 }
    $PlanWaitingPromotionCount = if ($null -ne $CurrentState -and $CurrentState.PSObject.Properties.Name -contains "plan_waiting_promotion_count") { [int]$CurrentState.plan_waiting_promotion_count } else { 0 }
    $RestartRequiredAfterPromotion = if ($null -ne $PromotionManifest -and $PromotionManifest.PSObject.Properties.Name -contains "restart_required_after_promotion") { Format-Phase160ConsoleValue -Value $PromotionManifest.restart_required_after_promotion } elseif ($null -ne $CurrentState -and $CurrentState.PSObject.Properties.Name -contains "restart_required_after_promotion") { Format-Phase160ConsoleValue -Value $CurrentState.restart_required_after_promotion } else { "False" }
    $SelfInitiatedGoalSelected = if ($null -ne $SelectedUsefulGoalRecord) { "True" } elseif ($null -ne $CurrentState -and $CurrentState.PSObject.Properties.Name -contains "self_initiated_goal_selected") { Format-Phase160ConsoleValue -Value $CurrentState.self_initiated_goal_selected } else { "False" }
    $SelectedUsefulGoal = if ($null -ne $SelectedUsefulGoalRecord -and $SelectedUsefulGoalRecord.PSObject.Properties.Name -contains "selected_goal_id") { Format-Phase160ConsoleValue -Value $SelectedUsefulGoalRecord.selected_goal_id } elseif ($null -ne $CurrentState -and $CurrentState.PSObject.Properties.Name -contains "selected_useful_goal") { Format-Phase160ConsoleValue -Value $CurrentState.selected_useful_goal } else { "NONE" }
    $InternalActiveTaskCreated = if ($null -ne $InternalActiveTaskRecord) { "True" } elseif ($null -ne $CurrentState -and $CurrentState.PSObject.Properties.Name -contains "internal_active_task_created") { Format-Phase160ConsoleValue -Value $CurrentState.internal_active_task_created } else { "False" }
    $LastPromotionEvent = "NONE"
    if (Test-Path -LiteralPath $ChangeLedgerPath) {
      $ledgerTail = @(Get-Content -LiteralPath $ChangeLedgerPath -Tail 25 -ErrorAction SilentlyContinue | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
      foreach ($ledgerLine in $ledgerTail) {
        $ledgerEntry = Read-Phase160ConsoleJsonLineSafe -Line $ledgerLine
        if ($null -ne $ledgerEntry -and $ledgerEntry.PSObject.Properties.Name -contains "event_type" -and [string]$ledgerEntry.event_type -match "promotion") {
          $LastPromotionEvent = Format-Phase160ConsoleValue -Value $ledgerEntry.event_type
        }
      }
    }

    $EventLineCount = Get-Phase160ConsoleJsonLineCount -Path $EventLogPath
    $ObserverLineCount = Get-Phase160ConsoleJsonLineCount -Path $ObserverLogPath
    $MacroCycleStageCount = Get-Phase160ConsoleMacroStageCount -SessionRootFull $SessionRootFull
    $ExperienceLedgerCount = Get-Phase160ConsoleJsonLineCount -Path $ExperienceLedgerPath
    $NextGoal = Read-Phase160ConsoleJsonSafe -Path $NextGoalPath
    $NextGoalSelectedWithReason = $false
    if ($null -ne $NextGoal -and $NextGoal.PSObject.Properties.Name -contains "selected_with_reason") {
      $NextGoalSelectedWithReason = [bool]$NextGoal.selected_with_reason
    }
    $EventLogRead = $EventLogRead -or ($EventLineCount -gt 0)
    $ObserverLogRead = $ObserverLogRead -or ($ObserverLineCount -gt 0)
    $BlockerSummary = Get-Phase160ConsoleJsonFileSummary -Directory $BlockerQueuePath
    $TeacherInboxSummary = Get-Phase160ConsoleJsonFileSummary -Directory $TeacherInboxPath
    $TeacherDigestSummary = Get-Phase160ConsoleJsonFileSummary -Directory $TeacherDigestPath
    $TeacherConsumedSummary = Get-Phase160ConsoleJsonFileSummary -Directory $TeacherConsumedPath -Pattern "receipt_*.json"
    $TeacherQuarantineSummary = Get-Phase160ConsoleJsonFileSummary -Directory $TeacherQuarantinePath -Pattern "quarantine_*.json"
    $TaskBacklogSummary = Get-Phase160ConsoleJsonFileSummary -Directory $TaskBacklogPath
    $TeacherOutboxSummary = Get-Phase160ConsoleJsonFileSummary -Directory $TeacherOutboxPath
    $ActiveTaskRecord = Read-Phase160ConsoleJsonSafe -Path $ActiveTaskRecordPath
    $ActivePlanItem = Read-Phase160ConsoleJsonSafe -Path $ActivePlanItemPath
    $LatestConsumedRecord = if ($TeacherConsumedSummary.latest_name -ne "NONE") { Read-Phase160ConsoleJsonSafe -Path (Join-Path $TeacherConsumedPath $TeacherConsumedSummary.latest_name) } else { $null }
    $ActiveTaskId = if ($null -ne $ActiveTaskRecord -and $ActiveTaskRecord.PSObject.Properties.Name -contains "task_id") { Format-Phase160ConsoleValue -Value $ActiveTaskRecord.task_id } elseif ($null -ne $CurrentState -and $CurrentState.PSObject.Properties.Name -contains "active_task_id") { Format-Phase160ConsoleValue -Value $CurrentState.active_task_id } else { "NONE" }
    $ActivePlanItemId = if ($null -ne $ActivePlanItem -and $ActivePlanItem.PSObject.Properties.Name -contains "item_id") { Format-Phase160ConsoleValue -Value $ActivePlanItem.item_id } elseif ($null -ne $CurrentState -and $CurrentState.PSObject.Properties.Name -contains "active_plan_item_id") { Format-Phase160ConsoleValue -Value $CurrentState.active_plan_item_id } else { "NONE" }
    $LastConsumedTask = if ($null -ne $LatestConsumedRecord -and $LatestConsumedRecord.PSObject.Properties.Name -contains "task_id") { Format-Phase160ConsoleValue -Value $LatestConsumedRecord.task_id } elseif ($null -ne $CurrentState -and $CurrentState.PSObject.Properties.Name -contains "last_consumed_task") { Format-Phase160ConsoleValue -Value $CurrentState.last_consumed_task } else { "NONE" }
    $LastTaskInfluencedGap = "False"
    if ($null -ne $CurrentState -and $CurrentState.PSObject.Properties.Name -contains "last_task_influenced_gap_selection") {
      $LastTaskInfluencedGap = Format-Phase160ConsoleValue -Value $CurrentState.last_task_influenced_gap_selection
    } elseif ($null -ne $FinalState -and $FinalState.PSObject.Properties.Name -contains "last_task_influenced_gap_selection") {
      $LastTaskInfluencedGap = Format-Phase160ConsoleValue -Value $FinalState.last_task_influenced_gap_selection
    }
    $OwnerTaskIntake = if ($null -ne $CurrentState -and $CurrentState.PSObject.Properties.Name -contains "owner_task_intake_enabled") { Format-Phase160ConsoleValue -Value $CurrentState.owner_task_intake_enabled } elseif ($null -ne $FinalState -and $FinalState.PSObject.Properties.Name -contains "owner_task_intake_enabled") { Format-Phase160ConsoleValue -Value $FinalState.owner_task_intake_enabled } else { "False" }
    $LastIntakeDecision = if ($null -ne $CurrentState -and $CurrentState.PSObject.Properties.Name -contains "last_owner_task_intake_decision") { Format-Phase160ConsoleValue -Value $CurrentState.last_owner_task_intake_decision } elseif ($null -ne $FinalState -and $FinalState.PSObject.Properties.Name -contains "last_owner_task_intake_decision") { Format-Phase160ConsoleValue -Value $FinalState.last_owner_task_intake_decision } else { "NONE" }
    $OwnerBacklogCount = if ($null -ne $CurrentState -and $CurrentState.PSObject.Properties.Name -contains "owner_task_backlog_count") { [int]$CurrentState.owner_task_backlog_count } elseif ($null -ne $FinalState -and $FinalState.PSObject.Properties.Name -contains "owner_task_backlog_count") { [int]$FinalState.owner_task_backlog_count } else { [int]$TaskBacklogSummary.count }
    $LatestOwnerBacklogTask = if ($null -ne $CurrentState -and $CurrentState.PSObject.Properties.Name -contains "latest_owner_backlog_task_id") { Format-Phase160ConsoleValue -Value $CurrentState.latest_owner_backlog_task_id } elseif ($null -ne $FinalState -and $FinalState.PSObject.Properties.Name -contains "latest_owner_backlog_task_id") { Format-Phase160ConsoleValue -Value $FinalState.latest_owner_backlog_task_id } else { "NONE" }
    $ActiveTaskBlocksOwnerTask = if ($null -ne $CurrentState -and $CurrentState.PSObject.Properties.Name -contains "active_task_blocks_owner_task") { Format-Phase160ConsoleValue -Value $CurrentState.active_task_blocks_owner_task } elseif ($null -ne $FinalState -and $FinalState.PSObject.Properties.Name -contains "active_task_blocks_owner_task") { Format-Phase160ConsoleValue -Value $FinalState.active_task_blocks_owner_task } else { "False" }
    $LastQuarantineReason = if ($null -ne $CurrentState -and $CurrentState.PSObject.Properties.Name -contains "last_owner_task_quarantine_reason") { Format-Phase160ConsoleValue -Value $CurrentState.last_owner_task_quarantine_reason } elseif ($null -ne $FinalState -and $FinalState.PSObject.Properties.Name -contains "last_owner_task_quarantine_reason") { Format-Phase160ConsoleValue -Value $FinalState.last_owner_task_quarantine_reason } else { "NONE" }
    $OwnerTaskLost = if ($null -ne $CurrentState -and $CurrentState.PSObject.Properties.Name -contains "owner_task_lost") { Format-Phase160ConsoleValue -Value $CurrentState.owner_task_lost } elseif ($null -ne $FinalState -and $FinalState.PSObject.Properties.Name -contains "owner_task_lost") { Format-Phase160ConsoleValue -Value $FinalState.owner_task_lost } else { "False" }
    $OwnerInboxRouter = if ($null -ne $CurrentState -and $CurrentState.PSObject.Properties.Name -contains "owner_inbox_router_enabled") { Format-Phase160ConsoleValue -Value $CurrentState.owner_inbox_router_enabled } elseif ($null -ne $FinalState -and $FinalState.PSObject.Properties.Name -contains "owner_inbox_router_enabled") { Format-Phase160ConsoleValue -Value $FinalState.owner_inbox_router_enabled } else { "False" }
    $LastOwnerInboxMessageType = if ($null -ne $CurrentState -and $CurrentState.PSObject.Properties.Name -contains "last_owner_inbox_message_type") { Format-Phase160ConsoleValue -Value $CurrentState.last_owner_inbox_message_type } elseif ($null -ne $FinalState -and $FinalState.PSObject.Properties.Name -contains "last_owner_inbox_message_type") { Format-Phase160ConsoleValue -Value $FinalState.last_owner_inbox_message_type } else { "NONE" }
    $LastOwnerInboxRouteDecision = if ($null -ne $CurrentState -and $CurrentState.PSObject.Properties.Name -contains "last_owner_inbox_route_decision") { Format-Phase160ConsoleValue -Value $CurrentState.last_owner_inbox_route_decision } elseif ($null -ne $FinalState -and $FinalState.PSObject.Properties.Name -contains "last_owner_inbox_route_decision") { Format-Phase160ConsoleValue -Value $FinalState.last_owner_inbox_route_decision } else { "NONE" }
    $CurriculumRoutedCount = if ($null -ne $CurrentState -and $CurrentState.PSObject.Properties.Name -contains "curriculum_pack_routed_count") { [int]$CurrentState.curriculum_pack_routed_count } elseif ($null -ne $FinalState -and $FinalState.PSObject.Properties.Name -contains "curriculum_pack_routed_count") { [int]$FinalState.curriculum_pack_routed_count } else { 0 }
    $OwnerTaskRoutedCount = if ($null -ne $CurrentState -and $CurrentState.PSObject.Properties.Name -contains "owner_task_routed_count") { [int]$CurrentState.owner_task_routed_count } elseif ($null -ne $FinalState -and $FinalState.PSObject.Properties.Name -contains "owner_task_routed_count") { [int]$FinalState.owner_task_routed_count } else { 0 }
    $InstructionRoutedCount = if ($null -ne $CurrentState -and $CurrentState.PSObject.Properties.Name -contains "instruction_routed_count") { [int]$CurrentState.instruction_routed_count } elseif ($null -ne $FinalState -and $FinalState.PSObject.Properties.Name -contains "instruction_routed_count") { [int]$FinalState.instruction_routed_count } else { 0 }
    $UnknownQuarantineCount = if ($null -ne $CurrentState -and $CurrentState.PSObject.Properties.Name -contains "unknown_message_quarantine_count") { [int]$CurrentState.unknown_message_quarantine_count } elseif ($null -ne $FinalState -and $FinalState.PSObject.Properties.Name -contains "unknown_message_quarantine_count") { [int]$FinalState.unknown_message_quarantine_count } else { 0 }
    $SchoolEntry = if ($null -ne $CurrentState -and $CurrentState.PSObject.Properties.Name -contains "school_entry_enabled") { Format-Phase160ConsoleValue -Value $CurrentState.school_entry_enabled } elseif ($null -ne $FinalState -and $FinalState.PSObject.Properties.Name -contains "school_entry_enabled") { Format-Phase160ConsoleValue -Value $FinalState.school_entry_enabled } else { "False" }
    $ActiveSchoolRun = if ($null -ne $CurrentState -and $CurrentState.PSObject.Properties.Name -contains "active_school_run_id") { Format-Phase160ConsoleValue -Value $CurrentState.active_school_run_id } elseif ($null -ne $FinalState -and $FinalState.PSObject.Properties.Name -contains "active_school_run_id") { Format-Phase160ConsoleValue -Value $FinalState.active_school_run_id } else { "NONE" }
    $ActiveCurriculumId = if ($null -ne $CurrentState -and $CurrentState.PSObject.Properties.Name -contains "active_curriculum_id") { Format-Phase160ConsoleValue -Value $CurrentState.active_curriculum_id } elseif ($null -ne $FinalState -and $FinalState.PSObject.Properties.Name -contains "active_curriculum_id") { Format-Phase160ConsoleValue -Value $FinalState.active_curriculum_id } else { "NONE" }
    $SchoolLessonTotal = if ($null -ne $CurrentState -and $CurrentState.PSObject.Properties.Name -contains "school_lesson_total_count") { [int]$CurrentState.school_lesson_total_count } elseif ($null -ne $FinalState -and $FinalState.PSObject.Properties.Name -contains "school_lesson_total_count") { [int]$FinalState.school_lesson_total_count } else { 0 }
    $SchoolLessonPass = if ($null -ne $CurrentState -and $CurrentState.PSObject.Properties.Name -contains "school_lesson_pass_count") { [int]$CurrentState.school_lesson_pass_count } elseif ($null -ne $FinalState -and $FinalState.PSObject.Properties.Name -contains "school_lesson_pass_count") { [int]$FinalState.school_lesson_pass_count } else { 0 }
    $SchoolLessonFail = if ($null -ne $CurrentState -and $CurrentState.PSObject.Properties.Name -contains "school_lesson_fail_count") { [int]$CurrentState.school_lesson_fail_count } elseif ($null -ne $FinalState -and $FinalState.PSObject.Properties.Name -contains "school_lesson_fail_count") { [int]$FinalState.school_lesson_fail_count } else { 0 }
    $SchoolLessonQuarantine = if ($null -ne $CurrentState -and $CurrentState.PSObject.Properties.Name -contains "school_lesson_quarantine_count") { [int]$CurrentState.school_lesson_quarantine_count } elseif ($null -ne $FinalState -and $FinalState.PSObject.Properties.Name -contains "school_lesson_quarantine_count") { [int]$FinalState.school_lesson_quarantine_count } else { 0 }
    $SchoolMorningReview = if ($null -ne $CurrentState -and $CurrentState.PSObject.Properties.Name -contains "school_morning_review_written") { Format-Phase160ConsoleValue -Value $CurrentState.school_morning_review_written } elseif ($null -ne $FinalState -and $FinalState.PSObject.Properties.Name -contains "school_morning_review_written") { Format-Phase160ConsoleValue -Value $FinalState.school_morning_review_written } else { "False" }
    $SchoolRouteDrift = if ($null -ne $CurrentState -and $CurrentState.PSObject.Properties.Name -contains "school_route_drift_detected") { Format-Phase160ConsoleValue -Value $CurrentState.school_route_drift_detected } elseif ($null -ne $FinalState -and $FinalState.PSObject.Properties.Name -contains "school_route_drift_detected") { Format-Phase160ConsoleValue -Value $FinalState.school_route_drift_detected } else { "False" }
    $SchoolOwnerReview = if ($null -ne $CurrentState -and $CurrentState.PSObject.Properties.Name -contains "school_owner_review_required") { Format-Phase160ConsoleValue -Value $CurrentState.school_owner_review_required } elseif ($null -ne $FinalState -and $FinalState.PSObject.Properties.Name -contains "school_owner_review_required") { Format-Phase160ConsoleValue -Value $FinalState.school_owner_review_required } else { "False" }
    $ActiveRouteLock = if ($null -ne $CurrentState -and $CurrentState.PSObject.Properties.Name -contains "active_route_lock_stamp") { Format-Phase160ConsoleValue -Value $CurrentState.active_route_lock_stamp } elseif ($null -ne $FinalState -and $FinalState.PSObject.Properties.Name -contains "active_route_lock_stamp") { Format-Phase160ConsoleValue -Value $FinalState.active_route_lock_stamp } else { "NONE" }
    $RouteStep = if ($null -ne $CurrentState -and $CurrentState.PSObject.Properties.Name -contains "current_route_step_id") { Format-Phase160ConsoleValue -Value $CurrentState.current_route_step_id } elseif ($null -ne $FinalState -and $FinalState.PSObject.Properties.Name -contains "current_route_step_id") { Format-Phase160ConsoleValue -Value $FinalState.current_route_step_id } else { "NONE" }
    $LearningMode = if ($null -ne $CurrentState -and $CurrentState.PSObject.Properties.Name -contains "learning_mode") { Format-Phase160ConsoleValue -Value $CurrentState.learning_mode } elseif ($null -ne $FinalState -and $FinalState.PSObject.Properties.Name -contains "learning_mode") { Format-Phase160ConsoleValue -Value $FinalState.learning_mode } else { "SELF_MODE" }
    $LearningActiveCurriculum = if ($null -ne $CurrentState -and $CurrentState.PSObject.Properties.Name -contains "active_curriculum_id") { Format-Phase160ConsoleValue -Value $CurrentState.active_curriculum_id } elseif ($null -ne $FinalState -and $FinalState.PSObject.Properties.Name -contains "active_curriculum_id") { Format-Phase160ConsoleValue -Value $FinalState.active_curriculum_id } else { $ActiveCurriculumId }
    $LearningActiveSchoolRun = if ($null -ne $CurrentState -and $CurrentState.PSObject.Properties.Name -contains "active_school_run_id") { Format-Phase160ConsoleValue -Value $CurrentState.active_school_run_id } elseif ($null -ne $FinalState -and $FinalState.PSObject.Properties.Name -contains "active_school_run_id") { Format-Phase160ConsoleValue -Value $FinalState.active_school_run_id } else { $ActiveSchoolRun }
    $AbsorptionRequired = if ($null -ne $CurrentState -and $CurrentState.PSObject.Properties.Name -contains "absorption_required") { Format-Phase160ConsoleValue -Value $CurrentState.absorption_required } elseif ($null -ne $FinalState -and $FinalState.PSObject.Properties.Name -contains "absorption_required") { Format-Phase160ConsoleValue -Value $FinalState.absorption_required } else { "False" }
    $LastAbsorption = if ($null -ne $CurrentState -and $CurrentState.PSObject.Properties.Name -contains "last_absorption_id") { Format-Phase160ConsoleValue -Value $CurrentState.last_absorption_id } elseif ($null -ne $FinalState -and $FinalState.PSObject.Properties.Name -contains "last_absorption_id") { Format-Phase160ConsoleValue -Value $FinalState.last_absorption_id } else { "NONE" }
    $NextSelfGap = if ($null -ne $CurrentState -and $CurrentState.PSObject.Properties.Name -contains "recommended_next_self_gap") { Format-Phase160ConsoleValue -Value $CurrentState.recommended_next_self_gap } elseif ($null -ne $FinalState -and $FinalState.PSObject.Properties.Name -contains "recommended_next_self_gap") { Format-Phase160ConsoleValue -Value $FinalState.recommended_next_self_gap } else { "NONE" }
    $SelectedCurriculumSource = if ($null -ne $CurrentState -and $CurrentState.PSObject.Properties.Name -contains "selected_curriculum_source") { Format-Phase160ConsoleValue -Value $CurrentState.selected_curriculum_source } elseif ($null -ne $FinalState -and $FinalState.PSObject.Properties.Name -contains "selected_curriculum_source") { Format-Phase160ConsoleValue -Value $FinalState.selected_curriculum_source } else { "NONE" }
    $BlockerQueueRead = $true
    $TeacherInboxRead = $true
    $TeacherOutboxRead = $true
    $StopFlagPresent = Test-Path -LiteralPath $StopFlagPath
    $StopFlagRead = $true
    $FinalStateWritten = Test-Path -LiteralPath $FinalStatePath
    $LastEvent = Get-Phase160ConsoleLatestEventName -EventLogPath $EventLogPath

    $Line = "LIVE_CONSOLE POLL=$PollCount HEARTBEAT_STATUS=$HeartbeatStatus TICK=$CurrentTick HEARTBEAT_COUNT=$HeartbeatCount SELF_GROWTH_ENABLED=$SelfGrowthEnabled DUTY_COUNT=$SelfGrowthDutyCount LAST_DUTY=$LastSelfGrowthDuty LAST_GAP=$LastSelfGrowthGap LAST_DUTY_STATUS=$LastSelfGrowthStatus NEXT_GAP=$NextSelfGrowthGap MACRO_CYCLE=$MacroCycleId LAST_STAGE=$LastMacroCycleStage LAST_DECISION=$LastMacroDecision RUN_HEAD=$RunHead CURRENT_HEAD=$CurrentHead HEAD_MATCH=$HeadMatch OWNER_INBOX_ROUTER=$OwnerInboxRouter LAST_MESSAGE_TYPE=$LastOwnerInboxMessageType LAST_ROUTE_DECISION=$LastOwnerInboxRouteDecision CURRICULUM_ROUTED=$CurriculumRoutedCount OWNER_TASK_ROUTED=$OwnerTaskRoutedCount INSTRUCTION_ROUTED=$InstructionRoutedCount UNKNOWN_QUARANTINE=$UnknownQuarantineCount LEARNING_MODE=$LearningMode ACTIVE_CURRICULUM=$LearningActiveCurriculum ACTIVE_SCHOOL_RUN=$LearningActiveSchoolRun ABSORPTION_REQUIRED=$AbsorptionRequired LAST_ABSORPTION=$LastAbsorption NEXT_SELF_GAP=$NextSelfGap SELECTED_CURRICULUM_SOURCE=$SelectedCurriculumSource SCHOOL_ENTRY=$SchoolEntry CURRICULUM_ID=$ActiveCurriculumId LESSON_TOTAL=$SchoolLessonTotal LESSON_PASS=$SchoolLessonPass LESSON_FAIL=$SchoolLessonFail LESSON_QUARANTINE=$SchoolLessonQuarantine MORNING_REVIEW=$SchoolMorningReview SCHOOL_ROUTE_DRIFT=$SchoolRouteDrift SCHOOL_OWNER_REVIEW=$SchoolOwnerReview ACTIVE_ROUTE_LOCK=$ActiveRouteLock ROUTE_STEP=$RouteStep LIVE_REPO_GUARD=$LiveRepoGuard RUNTIME_GUARD_STATUS=$RuntimeGuardStatus GUARD_BLOCK_REASON=$GuardBlockReason ALLOWED_RUNTIME_OUTPUT_COUNT=$AllowedRuntimeOutputCount ALLOWED_TRACKED_RUNTIME_SAMPLE_CHANGE=$AllowedTrackedRuntimeSampleChange UNSAFE_TRACKED_MUTATION_COUNT=$UnsafeTrackedMutationCount PROTECTED_STATE_MUTATION_COUNT=$ProtectedStateMutationCount CANDIDATE_PRODUCTION_ENABLED=$CandidateProductionEnabled CANDIDATE_WORKSPACE_PROMOTION_ENABLED=$CandidateWorkspacePromotionEnabled CANDIDATE_WORKSPACE_STATUS=$CandidateWorkspaceStatus CANDIDATE_COUNT=$CandidateCount READY_CANDIDATE_COUNT=$ReadyCandidateCount QUALITY_GATE_ENABLED=$QualityGateEnabled QUALITY_READY_COUNT=$QualityReadyCount QUALITY_RESULT_FILE_COUNT=$QualityResultFileCount QUALITY_DECISION_COUNT=$QualityDecisionCount QUALITY_ARTIFACT_CONSISTENCY=$QualityArtifactConsistency MISSING_QUALITY_RESULT_COUNT=$MissingQualityResultCount REVISION_REQUIRED_COUNT=$RevisionRequiredCount DRAFT_CANDIDATE_COUNT=$DraftCandidateCount QUARANTINED_CANDIDATE_COUNT=$QuarantinedCandidateCount BLOCKED_CANDIDATE_COUNT=$BlockedCandidateCount LAST_QUALITY_DECISION=$LastQualityDecision LAST_REVISION_REQUEST=$LastRevisionRequest OWNER_PROMOTION_ALLOWED=$OwnerPromotionAllowed PROMOTION_BUNDLE_STATUS=$PromotionBundleStatus ACTIVE_TASK_STATUS=$ActiveTaskStatus ACTIVE_TASK=$ActiveTaskId ACTIVE_PLAN_ITEM=$ActivePlanItemId BACKLOG_COUNT=$($TaskBacklogSummary.count) PLAN_PENDING_COUNT=$PlanPendingCount PLAN_ACTIVE_COUNT=$PlanActiveCount PLAN_WAITING_PROMOTION_COUNT=$PlanWaitingPromotionCount OWNER_TASK_INTAKE=$OwnerTaskIntake LAST_INTAKE_DECISION=$LastIntakeDecision OWNER_BACKLOG_COUNT=$OwnerBacklogCount LATEST_OWNER_BACKLOG_TASK=$LatestOwnerBacklogTask ACTIVE_TASK_BLOCKS_OWNER_TASK=$ActiveTaskBlocksOwnerTask LAST_QUARANTINE_REASON=$LastQuarantineReason OWNER_TASK_LOST=$OwnerTaskLost SELF_INITIATED_GOAL_SELECTED=$SelfInitiatedGoalSelected SELECTED_USEFUL_GOAL=$SelectedUsefulGoal INTERNAL_ACTIVE_TASK_CREATED=$InternalActiveTaskCreated LAST_CANDIDATE_ID=$LastCandidateId LAST_PROMOTION_EVENT=$LastPromotionEvent RESTART_REQUIRED_AFTER_PROMOTION=$RestartRequiredAfterPromotion TEACHER_INBOX_COUNT=$($TeacherInboxSummary.count) TEACHER_DIGEST_COUNT=$($TeacherDigestSummary.count) TEACHER_CONSUMED_COUNT=$($TeacherConsumedSummary.count) TEACHER_QUARANTINE_COUNT=$($TeacherQuarantineSummary.count) TASK_BACKLOG_COUNT=$($TaskBacklogSummary.count) LAST_CONSUMED_TASK=$LastConsumedTask LAST_TASK_INFLUENCED_GAP=$LastTaskInfluencedGap macro_cycle_enabled=$MacroCycleEnabled macro_cycle_id=$MacroCycleId last_macro_cycle_stage=$LastMacroCycleStage last_macro_decision=$LastMacroDecision macro_cycle_stage_count=$MacroCycleStageCount experience_ledger_count=$ExperienceLedgerCount next_goal_selected_with_reason=$NextGoalSelectedWithReason final_state_written=$FinalStateWritten EVENT_LINES=$EventLineCount OBSERVER_LINES=$ObserverLineCount BLOCKERS=$($BlockerSummary.count) LATEST_BLOCKER=$($BlockerSummary.latest_name) TEACHER_INBOX=$($TeacherInboxSummary.count) LATEST_SUGGESTION=$($TeacherInboxSummary.latest_name) TEACHER_OUTBOX=$($TeacherOutboxSummary.count) STALE=$StaleThisPoll HEARTBEAT_AGE_SECONDS=$HeartbeatAgeSeconds STOP_FLAG=$StopFlagPresent LAST_EVENT=$LastEvent"
    Write-Phase160ConsoleVisibleLine -Line $Line -SamplePath $SamplePath
    $LiveLineCount += 1
    $SelfGrowthFieldsPrinted = $true
    $MacroFieldsPrinted = $true
    $TaskIntakeFieldsPrinted = $true
    $Phase160EFieldsPrinted = $true
    $Phase160HQualityFieldsPrinted = $true
    $Phase160JOwnerTaskFieldsPrinted = $true
    $Phase161ASchoolFieldsPrinted = $true
    $Phase161BLearningModeFieldsPrinted = $true
    $Phase161B1OwnerInboxRouterFieldsPrinted = $true

    $EventTail = Get-Phase160ConsoleTailLines -Path $EventLogPath -Count $ShowTailEvents
    for ($i = 0; $i -lt $EventTail.Count; $i += 1) {
      $TailSummary = Get-Phase160ConsoleTailSummary -Line $EventTail[$i]
      Write-Phase160ConsoleVisibleLine -Line "LIVE_CONSOLE EVENT_TAIL[$($i + 1)] $TailSummary" -SamplePath $SamplePath
    }

    $ObserverTail = Get-Phase160ConsoleTailLines -Path $ObserverLogPath -Count $ShowTailObserver
    for ($i = 0; $i -lt $ObserverTail.Count; $i += 1) {
      $TailSummary = Get-Phase160ConsoleTailSummary -Line $ObserverTail[$i]
      Write-Phase160ConsoleVisibleLine -Line "LIVE_CONSOLE OBSERVER_TAIL[$($i + 1)] $TailSummary" -SamplePath $SamplePath
    }

    $RemainingSeconds = [Math]::Floor(($EndTime - (Get-Date)).TotalSeconds)
    if ($RemainingSeconds -le 0) {
      break
    }
    Start-Sleep -Seconds ([Math]::Max(1, [Math]::Min($PollIntervalSeconds, $RemainingSeconds)))
  }

  $Result = [ordered]@{
    status = "PASS"
    repair_id = $RepairId
    run_id = $ConsoleRunId
    bound_run_id = if ([string]::IsNullOrWhiteSpace($RunId)) { "NONE" } else { $RunId }
    resolved_repo_root = $RepoRoot
    branch = $Branch
    local_head = $Head
    remote_head = $RemoteHead
    expected_head_source = $ExpectedHeadSource
    session_root = $SessionRootRelative
    console_runtime_root = $ConsoleRuntimeRootRelative
    console_output_sample_path = "$ConsoleRuntimeRoot/console_output_sample.txt"
    poll_count = $PollCount
    live_console_lines_count = $LiveLineCount
    console_prints_live_lines = $LiveLineCount -ge 2
    console_reads_heartbeat = $HeartbeatRead
    console_reads_current_state = $CurrentStateRead
    console_reads_event_log = $EventLogRead
    console_reads_observer_log = $ObserverLogRead
    console_reads_blocker_queue = $BlockerQueueRead
    console_reads_teacher_inbox = $TeacherInboxRead
    console_reads_teacher_outbox = $TeacherOutboxRead
    console_reads_stop_flag = $StopFlagRead
    console_detects_stale_heartbeat = $StaleHeartbeatDetected
    console_supports_owner_screenshot_mode = $true
    live_console_shows_self_growth_fields = $SelfGrowthFieldsPrinted
    live_console_shows_macro_fields = $MacroFieldsPrinted
    live_console_shows_task_intake_fields = $TaskIntakeFieldsPrinted
    live_console_shows_phase160e_fields = $Phase160EFieldsPrinted
    live_console_shows_phase160h_quality_fields = $Phase160HQualityFieldsPrinted
    live_console_shows_phase160j_owner_task_fields = $Phase160JOwnerTaskFieldsPrinted
    live_console_shows_phase161a_school_fields = $Phase161ASchoolFieldsPrinted
    live_console_shows_phase161b_learning_mode_fields = $Phase161BLearningModeFieldsPrinted
    live_console_shows_phase161b1_owner_inbox_router_fields = $Phase161B1OwnerInboxRouterFieldsPrinted
    accepted_state_mutated = $false
    accepted_memory_mutated = $false
    accepted_self_model_mutated = $false
    queue_mutated = $false
    external_fetch_performed = $false
    dependency_install_performed = $false
    arbitrary_code_execution_used = $false
    completed_at = (Get-Date).ToUniversalTime().ToString("o")
  }
  Write-Phase160ConsoleJsonFile -Path $ResultPath -Object $Result
  Write-Phase160ConsoleVisibleLine -Line "LIVE_CONSOLE_DONE STATUS=PASS POLLS=$PollCount SAMPLE=$ConsoleRuntimeRoot/console_output_sample.txt RESULT=$ConsoleRuntimeRoot/console_run_result.json" -SamplePath $SamplePath
} finally {
  if ($Pushed) {
    Pop-Location
  }
}
