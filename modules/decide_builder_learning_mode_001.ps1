param(
  [string]$RepoRoot = "",
  [string]$SessionRoot = "",
  [string]$PreviousLearningMode = "",
  [string]$CurriculumRoot = "",
  [string]$CurriculumPackPath = "",
  [string]$CurriculumSource = "",
  [string]$SchoolRunId = "",
  [string]$DecisionId = "",
  [string]$SafetyMode = "SAFE",
  [switch]$OwnerReviewRequired,
  [switch]$IgnoreLatestSchoolRun,
  [switch]$EmitJson
)

$ErrorActionPreference = "Stop"

function Resolve-Phase161BModeRepoRoot {
  param([string]$RepoRoot)
  if (-not [string]::IsNullOrWhiteSpace($RepoRoot)) {
    return [System.IO.Path]::GetFullPath($RepoRoot)
  }
  return [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
}

function Resolve-Phase161BModePath {
  param([string]$RepoRoot, [string]$Path)
  if ([string]::IsNullOrWhiteSpace($Path)) {
    return ""
  }
  if ([System.IO.Path]::IsPathRooted($Path)) {
    return [System.IO.Path]::GetFullPath($Path)
  }
  return [System.IO.Path]::GetFullPath((Join-Path $RepoRoot $Path))
}

function ConvertTo-Phase161BModeRelativePath {
  param([string]$RepoRoot, [string]$FullPath)
  if ([string]::IsNullOrWhiteSpace($FullPath)) {
    return "NONE"
  }
  $root = [System.IO.Path]::GetFullPath($RepoRoot).TrimEnd([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar)
  $path = [System.IO.Path]::GetFullPath($FullPath).TrimEnd([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar)
  if ($path -eq $root) {
    return "."
  }
  if (-not $path.StartsWith($root + [System.IO.Path]::DirectorySeparatorChar, [System.StringComparison]::OrdinalIgnoreCase)) {
    return $FullPath
  }
  return ($path.Substring($root.Length + 1) -replace "\\", "/")
}

function Read-Phase161BModeJsonSafe {
  param([string]$Path)
  try {
    if ([string]::IsNullOrWhiteSpace($Path) -or -not (Test-Path -LiteralPath $Path)) {
      return $null
    }
    return Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json
  } catch {
    return $null
  }
}

function Write-Phase161BModeJson {
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

function Get-Phase161BModeProp {
  param([object]$Object, [string]$Name, [object]$DefaultValue = $null)
  if ($null -ne $Object -and $Object.PSObject.Properties.Name -contains $Name) {
    return $Object.$Name
  }
  return $DefaultValue
}

function Get-Phase161BRouteState {
  param([string]$RepoRoot)
  $activeRoute = Read-Phase161BModeJsonSafe -Path (Join-Path $RepoRoot "route_locks/ACTIVE_ROUTE_LOCK.json")
  if ($null -eq $activeRoute) {
    return [ordered]@{
      active_route_lock_file = "NONE"
      active_route_lock_status = "MISSING"
      current_route_step_id = "PHASE161B_UNIFIED_LEARNING_MODE_LOOP_V1"
    }
  }
  return [ordered]@{
    active_route_lock_file = [string](Get-Phase161BModeProp -Object $activeRoute -Name "active_route_lock_file" -DefaultValue "NONE")
    active_route_lock_status = [string](Get-Phase161BModeProp -Object $activeRoute -Name "active_route_lock_status" -DefaultValue "UNKNOWN")
    current_route_step_id = "PHASE161B_UNIFIED_LEARNING_MODE_LOOP_V1"
  }
}

function Get-Phase161BCurriculumSourceFromPath {
  param([string]$Path, [string]$Fallback = "generated")
  $normalized = ($Path -replace "\\", "/").ToLowerInvariant()
  if ($normalized -match "/owner/") { return "owner" }
  if ($normalized -match "/internal/") { return "internal" }
  if ($normalized -match "/generated/") { return "generated" }
  return $Fallback
}

function Test-Phase161BCurriculumSafety {
  param([object]$Pack)
  $unsafeReasons = @()
  $safety = Get-Phase161BModeProp -Object $Pack -Name "safety_rules" -DefaultValue $null
  if ($null -eq $safety) {
    $unsafeReasons += "missing_safety_rules"
  } else {
    foreach ($flag in @("accepted_repo_mutation_allowed", "protected_state_mutation_allowed", "repo_commit_allowed", "repo_push_allowed", "branch_switch_allowed")) {
      if ((Get-Phase161BModeProp -Object $safety -Name $flag -DefaultValue $false) -eq $true) {
        $unsafeReasons += "unsafe_$flag"
      }
    }
  }
  foreach ($lesson in @((Get-Phase161BModeProp -Object $Pack -Name "lessons" -DefaultValue @()))) {
    foreach ($action in @((Get-Phase161BModeProp -Object $lesson -Name "allowed_actions" -DefaultValue @()) | ForEach-Object { [string]$_ })) {
      if (@("commit", "push", "branch_switch", "accepted_repo_mutation", "protected_state_mutation") -contains $action) {
        $unsafeReasons += "lesson_$([string](Get-Phase161BModeProp -Object $lesson -Name "lesson_id" -DefaultValue "UNKNOWN"))`_unsafe_action_$action"
      }
    }
  }
  return [pscustomobject][ordered]@{
    safe = ($unsafeReasons.Count -eq 0)
    unsafe_reasons = @($unsafeReasons)
  }
}

function Get-Phase161BCurriculumCandidates {
  param(
    [string]$RepoRoot,
    [string]$CurriculumRoot,
    [string]$CurriculumPackPath,
    [string]$CurriculumSource
  )
  $candidateFiles = @()
  if (-not [string]::IsNullOrWhiteSpace($CurriculumPackPath)) {
    $candidateFiles += Resolve-Phase161BModePath -RepoRoot $RepoRoot -Path $CurriculumPackPath
  }
  $roots = @()
  if (-not [string]::IsNullOrWhiteSpace($CurriculumRoot)) {
    $roots += Resolve-Phase161BModePath -RepoRoot $RepoRoot -Path $CurriculumRoot
  } else {
    $roots += (Join-Path $RepoRoot "runtime_sessions/learning_curricula")
    $roots += (Join-Path $RepoRoot "runtime_sessions/curricula")
    $roots += (Join-Path $RepoRoot "runtime_sessions/school_curricula")
  }
  foreach ($root in $roots) {
    if (Test-Path -LiteralPath $root -PathType Leaf) {
      $candidateFiles += $root
    } elseif (Test-Path -LiteralPath $root -PathType Container) {
      $candidateFiles += @(Get-ChildItem -LiteralPath $root -File -Filter "*.json" -Recurse -ErrorAction SilentlyContinue | ForEach-Object { $_.FullName })
    }
  }
  $candidates = @()
  foreach ($file in @($candidateFiles | Select-Object -Unique)) {
    $pack = Read-Phase161BModeJsonSafe -Path $file
    if ($null -eq $pack) {
      continue
    }
    $source = if (-not [string]::IsNullOrWhiteSpace($CurriculumSource)) {
      $CurriculumSource
    } elseif (-not [string]::IsNullOrWhiteSpace([string](Get-Phase161BModeProp -Object $pack -Name "curriculum_source" -DefaultValue ""))) {
      [string]$pack.curriculum_source
    } elseif (-not [string]::IsNullOrWhiteSpace([string](Get-Phase161BModeProp -Object $pack -Name "source" -DefaultValue ""))) {
      [string]$pack.source
    } else {
      Get-Phase161BCurriculumSourceFromPath -Path $file -Fallback "generated"
    }
    $requiredOk = ([string](Get-Phase161BModeProp -Object $pack -Name "pack_type" -DefaultValue "") -eq "BUILDER_SCHOOL_CURRICULUM_PACK" -and -not [string]::IsNullOrWhiteSpace([string](Get-Phase161BModeProp -Object $pack -Name "curriculum_id" -DefaultValue "")) -and @((Get-Phase161BModeProp -Object $pack -Name "lessons" -DefaultValue @())).Count -gt 0)
    $safety = Test-Phase161BCurriculumSafety -Pack $pack
    $candidates += [ordered]@{
      path = $file
      relative_path = ConvertTo-Phase161BModeRelativePath -RepoRoot $RepoRoot -FullPath $file
      curriculum_id = [string](Get-Phase161BModeProp -Object $pack -Name "curriculum_id" -DefaultValue "UNKNOWN")
      source = $source.ToLowerInvariant()
      required_ok = $requiredOk
      safe = [bool]$safety.safe
      unsafe_reasons = @($safety.unsafe_reasons)
    }
  }
  return @($candidates)
}

function Get-Phase161BLatestSchoolRunRoot {
  param([string]$RepoRoot, [string]$SessionRoot, [string]$SchoolRunId, [bool]$IgnoreLatestSchoolRun)
  $schoolRunsRoot = Join-Path $RepoRoot "runtime_sessions/school_runs"
  if (-not [string]::IsNullOrWhiteSpace($SchoolRunId)) {
    $candidate = Join-Path $schoolRunsRoot $SchoolRunId
    if (Test-Path -LiteralPath (Join-Path $candidate "school_run_manifest.json")) {
      return $candidate
    }
  }
  if (-not [string]::IsNullOrWhiteSpace($SessionRoot)) {
    $sessionRootFull = Resolve-Phase161BModePath -RepoRoot $RepoRoot -Path $SessionRoot
    $pointer = Read-Phase161BModeJsonSafe -Path (Join-Path $sessionRootFull "school_run_pointer.json")
    if ($null -ne $pointer -and -not [string]::IsNullOrWhiteSpace([string](Get-Phase161BModeProp -Object $pointer -Name "school_run_id" -DefaultValue ""))) {
      $candidate = Join-Path $schoolRunsRoot ([string]$pointer.school_run_id)
      if (Test-Path -LiteralPath (Join-Path $candidate "school_run_manifest.json")) {
        return $candidate
      }
    }
  }
  if ($IgnoreLatestSchoolRun -or -not (Test-Path -LiteralPath $schoolRunsRoot)) {
    return ""
  }
  $runs = @(Get-ChildItem -LiteralPath $schoolRunsRoot -Directory -ErrorAction SilentlyContinue | Where-Object { Test-Path -LiteralPath (Join-Path $_.FullName "school_run_manifest.json") } | Sort-Object LastWriteTimeUtc, Name)
  if ($runs.Count -lt 1) {
    return ""
  }
  return $runs[-1].FullName
}

function Get-Phase161BAbsorptionForSchoolRun {
  param([string]$RepoRoot, [string]$SchoolRunId)
  if ([string]::IsNullOrWhiteSpace($SchoolRunId)) {
    return $null
  }
  $root = Join-Path $RepoRoot "runtime_sessions/learning_absorption"
  if (-not (Test-Path -LiteralPath $root)) {
    return $null
  }
  $records = @()
  foreach ($file in @(Get-ChildItem -LiteralPath $root -File -Filter "learning_absorption.json" -Recurse -ErrorAction SilentlyContinue)) {
    $record = Read-Phase161BModeJsonSafe -Path $file.FullName
    if ($null -ne $record -and [string]$record.source_school_run_id -eq $SchoolRunId) {
      $records += $record
    }
  }
  if ($records.Count -lt 1) {
    return $null
  }
  return @($records | Sort-Object created_at)[-1]
}

function Get-Phase161BLatestDecisionMode {
  param([string]$RepoRoot)
  $root = Join-Path $RepoRoot "runtime_sessions/learning_mode_decisions"
  if (-not (Test-Path -LiteralPath $root)) {
    return "NONE"
  }
  $files = @(Get-ChildItem -LiteralPath $root -File -Filter "learning_mode_decision.json" -Recurse -ErrorAction SilentlyContinue | Sort-Object LastWriteTimeUtc, Name)
  if ($files.Count -lt 1) {
    return "NONE"
  }
  $decision = Read-Phase161BModeJsonSafe -Path $files[-1].FullName
  if ($null -eq $decision) {
    return "NONE"
  }
  return [string](Get-Phase161BModeProp -Object $decision -Name "learning_mode" -DefaultValue "NONE")
}

function Write-Phase161BUnsafeCurriculumReport {
  param([string]$RepoRoot, [string]$DecisionRoot, [object[]]$UnsafeCandidates)
  if (@($UnsafeCandidates).Count -lt 1) {
    return $null
  }
  $unsafePatterns = @($UnsafeCandidates | ForEach-Object {
    [ordered]@{
      curriculum_id = [string]$_.curriculum_id
      source = [string]$_.source
      path = [string]$_.relative_path
      cluster_type = "safety_violation"
      unsafe_reasons = @($_.unsafe_reasons)
      not_run = $true
    }
  })
  $report = [ordered]@{
    status = "PASS"
    report_id = (Split-Path -Path $DecisionRoot -Leaf) + "_UNSAFE_CURRICULUM_REPORT"
    unsafe_curriculum_not_run = $true
    unsafe_patterns = @($unsafePatterns)
    accepted_repo_mutated = $false
    protected_state_mutated = $false
    created_at = (Get-Date).ToUniversalTime().ToString("o")
  }
  $decisionReportPath = Join-Path $DecisionRoot "unsafe_curriculum_report.json"
  Write-Phase161BModeJson -Path $decisionReportPath -Object $report
  $quarantineRoot = Join-Path $RepoRoot ("runtime_sessions/learning_curriculum_quarantine/" + (Split-Path -Path $DecisionRoot -Leaf))
  Write-Phase161BModeJson -Path (Join-Path $quarantineRoot "unsafe_curriculum_report.json") -Object $report
  return $report
}

function Invoke-Phase161BLearningModeDecision {
  param(
    [string]$RepoRoot = "",
    [string]$SessionRoot = "",
    [string]$PreviousLearningMode = "",
    [string]$CurriculumRoot = "",
    [string]$CurriculumPackPath = "",
    [string]$CurriculumSource = "",
    [string]$SchoolRunId = "",
    [string]$DecisionId = "",
    [string]$SafetyMode = "SAFE",
    [bool]$OwnerReviewRequired = $false,
    [bool]$IgnoreLatestSchoolRun = $false
  )
  $resolvedRepoRoot = Resolve-Phase161BModeRepoRoot -RepoRoot $RepoRoot
  $route = Get-Phase161BRouteState -RepoRoot $resolvedRepoRoot
  if ([string]::IsNullOrWhiteSpace($DecisionId)) {
    $DecisionId = "PHASE161B_DECISION_{0}" -f ((Get-Date).ToUniversalTime().ToString("yyyyMMddHHmmssfff"))
  }
  $decisionRoot = Join-Path $resolvedRepoRoot "runtime_sessions/learning_mode_decisions/$DecisionId"
  $previousMode = if (-not [string]::IsNullOrWhiteSpace($PreviousLearningMode)) { $PreviousLearningMode } else { Get-Phase161BLatestDecisionMode -RepoRoot $resolvedRepoRoot }
  $candidates = Get-Phase161BCurriculumCandidates -RepoRoot $resolvedRepoRoot -CurriculumRoot $CurriculumRoot -CurriculumPackPath $CurriculumPackPath -CurriculumSource $CurriculumSource
  $validCandidates = @($candidates | Where-Object { [bool]$_.required_ok -and [bool]$_.safe })
  $unsafeCandidates = @($candidates | Where-Object { -not [bool]$_.safe })
  $ownerCandidates = @($validCandidates | Where-Object { [string]$_.source -eq "owner" })
  $internalCandidates = @($validCandidates | Where-Object { [string]$_.source -eq "internal" })
  $generatedCandidates = @($validCandidates | Where-Object { [string]$_.source -eq "generated" })
  $selected = $null
  $priorityReason = "NO_CURRICULUM_AVAILABLE"
  if ($ownerCandidates.Count -gt 0) {
    $selected = $ownerCandidates[0]
    $priorityReason = "OWNER_CURRICULUM_HAS_PRIORITY"
  } elseif ($internalCandidates.Count -gt 0) {
    $selected = $internalCandidates[0]
    $priorityReason = "INTERNAL_CURRICULUM_SELECTED_AFTER_OWNER_ABSENT"
  } elseif ($generatedCandidates.Count -gt 0) {
    $selected = $generatedCandidates[0]
    $priorityReason = "GENERATED_CURRICULUM_SELECTED_AFTER_OWNER_AND_INTERNAL_ABSENT"
  } elseif ($unsafeCandidates.Count -gt 0) {
    $priorityReason = "UNSAFE_CURRICULUM_QUARANTINED_NO_VALID_CURRICULUM"
  }
  $schoolRunRoot = Get-Phase161BLatestSchoolRunRoot -RepoRoot $resolvedRepoRoot -SessionRoot $SessionRoot -SchoolRunId $SchoolRunId -IgnoreLatestSchoolRun $IgnoreLatestSchoolRun
  $schoolManifest = if (-not [string]::IsNullOrWhiteSpace($schoolRunRoot)) { Read-Phase161BModeJsonSafe -Path (Join-Path $schoolRunRoot "school_run_manifest.json") } else { $null }
  $schoolRunExists = $null -ne $schoolManifest
  $schoolRunCompleted = $false
  if ($schoolRunExists) {
    $schoolRunCompleted = ([string]$schoolManifest.status -match "COMPLETED" -or [bool](Get-Phase161BModeProp -Object $schoolManifest -Name "morning_review_written" -DefaultValue $false))
  }
  $activeSchoolRunId = if ($schoolRunExists) { [string]$schoolManifest.school_run_id } else { "NONE" }
  $schoolRunCurriculumId = if ($schoolRunExists) { [string]$schoolManifest.curriculum_id } else { "NONE" }
  $absorption = Get-Phase161BAbsorptionForSchoolRun -RepoRoot $resolvedRepoRoot -SchoolRunId $activeSchoolRunId
  $absorptionDone = $null -ne $absorption
  $absorptionRequired = ($schoolRunExists -and $schoolRunCompleted -and -not $absorptionDone)
  $lastAbsorptionId = if ($absorptionDone) { [string]$absorption.absorption_id } else { "NONE" }
  $lastAbsorptionStatus = if ($absorptionDone) { [string]$absorption.status } else { "NONE" }
  $recommendedNextSelfGap = if ($absorptionDone -and $absorption.PSObject.Properties.Name -contains "self_mode_resume_recommendation") { [string]$absorption.self_mode_resume_recommendation } else { "NONE" }
  $sessionStopFlag = $false
  $activeTaskStatus = "NONE"
  $ownerTaskBacklogCount = 0
  $promotionBundleStatus = "NONE"
  if (-not [string]::IsNullOrWhiteSpace($SessionRoot)) {
    $sessionRootFull = Resolve-Phase161BModePath -RepoRoot $resolvedRepoRoot -Path $SessionRoot
    $sessionStopFlag = Test-Path -LiteralPath (Join-Path $sessionRootFull "stop.flag")
    $currentState = Read-Phase161BModeJsonSafe -Path (Join-Path $sessionRootFull "current_state.json")
    if ($null -ne $currentState) {
      $activeTaskStatus = [string](Get-Phase161BModeProp -Object $currentState -Name "active_task_status" -DefaultValue "NONE")
      $ownerTaskBacklogCount = [int](Get-Phase161BModeProp -Object $currentState -Name "owner_task_backlog_count" -DefaultValue 0)
      $promotionBundleStatus = [string](Get-Phase161BModeProp -Object $currentState -Name "promotion_bundle_status" -DefaultValue "NONE")
    }
  }
  $learningMode = "SELF_MODE"
  $decisionReason = "NO_CURRICULUM_AND_NO_PENDING_ABSORPTION"
  $ownerReviewBlocks = ($OwnerReviewRequired -or $promotionBundleStatus -eq "WAITING_OWNER_REVIEW" -or $activeTaskStatus -eq "WAITING_OWNER_PROMOTION")
  if ($sessionStopFlag -or [string]$SafetyMode -notin @("SAFE", "SESSION_LOCAL_SAFE")) {
    $learningMode = "SAFE_IDLE_ONLY"
    $decisionReason = "STOP_OR_SAFETY_CONDITION_PRESENT"
  } elseif ($ownerReviewBlocks) {
    $learningMode = "WAITING_OWNER_REVIEW"
    $decisionReason = "OWNER_REVIEW_OR_PROMOTION_BLOCKS_ACCEPTED_PROMOTION"
  } elseif ($schoolRunExists -and -not $schoolRunCompleted) {
    $learningMode = "SCHOOL_MODE"
    $decisionReason = "ACTIVE_SCHOOL_RUN_CONTINUES_UNTIL_FINISHED"
  } elseif ($absorptionRequired) {
    $learningMode = "ABSORB_EXPERIENCE"
    $decisionReason = "COMPLETED_SCHOOL_RUN_REQUIRES_ABSORPTION"
  } elseif ($schoolRunExists -and $schoolRunCompleted -and $absorptionDone -and ($null -eq $selected -or [string]$selected.curriculum_id -eq $schoolRunCurriculumId)) {
    $learningMode = "SELF_MODE"
    $decisionReason = "ABSORPTION_DONE_RETURN_SELF_MODE"
  } elseif ($null -ne $selected) {
    $learningMode = "SCHOOL_MODE"
    $decisionReason = "VALID_CURRICULUM_AVAILABLE_SELECT_SCHOOL_MODE"
  }
  $activeCurriculumId = if ($learningMode -eq "SCHOOL_MODE" -and $null -ne $selected) { [string]$selected.curriculum_id } elseif ($schoolRunCurriculumId -ne "NONE") { $schoolRunCurriculumId } else { "NONE" }
  $selectedSource = if ($null -ne $selected) { [string]$selected.source } else { "NONE" }
  $selectedCurriculumId = if ($null -ne $selected) { [string]$selected.curriculum_id } else { "NONE" }
  $schoolModeAllowed = ($learningMode -eq "SCHOOL_MODE")
  $selfModeAllowed = ($learningMode -eq "SELF_MODE")
  $safeIdleOnly = ($learningMode -eq "SAFE_IDLE_ONLY")
  $decision = [ordered]@{
    status = "PASS"
    decision_id = $DecisionId
    learning_mode = $learningMode
    previous_learning_mode = $previousMode
    decision_reason = $decisionReason
    active_curriculum_id = $activeCurriculumId
    active_school_run_id = $activeSchoolRunId
    active_route_lock_file = [string]$route.active_route_lock_file
    active_route_lock_status = [string]$route.active_route_lock_status
    current_route_step_id = [string]$route.current_route_step_id
    self_mode_allowed = $selfModeAllowed
    school_mode_allowed = $schoolModeAllowed
    absorption_required = $absorptionRequired
    owner_review_required = $ownerReviewBlocks
    accepted_repo_mutation_allowed = $false
    owner_curriculum_available = ($ownerCandidates.Count -gt 0)
    internal_curriculum_available = ($internalCandidates.Count -gt 0)
    generated_curriculum_available = ($generatedCandidates.Count -gt 0)
    selected_curriculum_source = $selectedSource
    selected_curriculum_id = $selectedCurriculumId
    priority_decision_reason = $priorityReason
    unsafe_curriculum_quarantined = ($unsafeCandidates.Count -gt 0)
    unsafe_curriculum_count = $unsafeCandidates.Count
    last_absorption_id = $lastAbsorptionId
    last_absorption_status = $lastAbsorptionStatus
    recommended_next_self_gap = $recommendedNextSelfGap
    safe_idle_only = $safeIdleOnly
    no_accepted_repo_mutation = $true
    no_protected_state_mutation = $true
    active_task_status = $activeTaskStatus
    owner_task_backlog_count = $ownerTaskBacklogCount
    created_at = (Get-Date).ToUniversalTime().ToString("o")
  }
  Write-Phase161BModeJson -Path (Join-Path $decisionRoot "learning_mode_decision.json") -Object $decision
  if ($unsafeCandidates.Count -gt 0) {
    [void](Write-Phase161BUnsafeCurriculumReport -RepoRoot $resolvedRepoRoot -DecisionRoot $decisionRoot -UnsafeCandidates $unsafeCandidates)
  }
  return [pscustomobject]$decision
}

if ($EmitJson) {
  Invoke-Phase161BLearningModeDecision -RepoRoot $RepoRoot -SessionRoot $SessionRoot -PreviousLearningMode $PreviousLearningMode -CurriculumRoot $CurriculumRoot -CurriculumPackPath $CurriculumPackPath -CurriculumSource $CurriculumSource -SchoolRunId $SchoolRunId -DecisionId $DecisionId -SafetyMode $SafetyMode -OwnerReviewRequired ([bool]$OwnerReviewRequired) -IgnoreLatestSchoolRun ([bool]$IgnoreLatestSchoolRun) | ConvertTo-Json -Depth 80
}
