param(
  [string]$SessionRoot = "",
  [string]$RunId = ""
)

$ErrorActionPreference = "Stop"

function Normalize-Phase160FScoreFullPath {
  param([string]$Path)
  return [System.IO.Path]::GetFullPath($Path).TrimEnd([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar)
}

function Resolve-Phase160FScoreRepoRoot {
  $scriptRootCandidate = $PSScriptRoot
  if ([string]::IsNullOrWhiteSpace($scriptRootCandidate) -and -not [string]::IsNullOrWhiteSpace($PSCommandPath)) {
    $scriptRootCandidate = Split-Path -Path $PSCommandPath -Parent
  }
  if ([string]::IsNullOrWhiteSpace($scriptRootCandidate) -and -not [string]::IsNullOrWhiteSpace($MyInvocation.MyCommand.Path)) {
    $scriptRootCandidate = Split-Path -Path $MyInvocation.MyCommand.Path -Parent
  }
  if ([string]::IsNullOrWhiteSpace($scriptRootCandidate)) {
    throw "PHASE160F_SCORE_SCRIPT_ROOT_UNAVAILABLE"
  }
  return Normalize-Phase160FScoreFullPath -Path (Join-Path $scriptRootCandidate "..")
}

function Resolve-Phase160FScorePath {
  param([string]$RepoRoot, [string]$Path)
  if ([System.IO.Path]::IsPathRooted($Path)) {
    return [System.IO.Path]::GetFullPath($Path)
  }
  return [System.IO.Path]::GetFullPath((Join-Path $RepoRoot $Path))
}

function ConvertTo-Phase160FScoreRelativePath {
  param([string]$RepoRoot, [string]$FullPath)
  $root = Normalize-Phase160FScoreFullPath -Path $RepoRoot
  $full = Normalize-Phase160FScoreFullPath -Path $FullPath
  if ($full -eq $root) {
    return "."
  }
  if (-not $full.StartsWith($root + [System.IO.Path]::DirectorySeparatorChar, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw "PHASE160F_SCORE_PATH_OUTSIDE_REPO=$FullPath"
  }
  return ($full.Substring($root.Length + 1) -replace "\\", "/")
}

function Write-Phase160FScoreJsonFile {
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

function Read-Phase160FScoreJsonSafe {
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

function New-Phase160FGoalScore {
  param(
    [string]$GoalId,
    [string]$GoalName,
    [string]$ExpectedCapability,
    [string[]]$CandidateFiles,
    [string[]]$ValidatorFiles,
    [int]$Autonomy,
    [int]$Safety,
    [int]$OwnerValue,
    [int]$ValidatorFeasibility,
    [int]$ImplementationRisk,
    [int]$DependencyComplexity,
    [int]$ProofSimplicity
  )
  $total = $Autonomy + $Safety + $OwnerValue + $ValidatorFeasibility + $ProofSimplicity - $ImplementationRisk - $DependencyComplexity
  return [ordered]@{
    goal_id = $GoalId
    goal_name = $GoalName
    expected_new_capability = $ExpectedCapability
    expected_candidate_files = $CandidateFiles
    expected_validator_files = $ValidatorFiles
    autonomy_gain_score = $Autonomy
    safety_gain_score = $Safety
    owner_value_score = $OwnerValue
    validator_feasibility_score = $ValidatorFeasibility
    implementation_risk_score = $ImplementationRisk
    dependency_complexity_score = $DependencyComplexity
    proof_simplicity_score = $ProofSimplicity
    total_usefulness_score = $total
    safety_boundary = "runtime_session_only_no_accepted_state_mutation"
  }
}

function Assert-Phase160FScoreRunIdSafe {
  param([string]$RunId)
  if ([string]::IsNullOrWhiteSpace($RunId)) {
    return
  }
  if ($RunId.IndexOfAny([char[]]@("/", "\")) -ge 0) {
    throw "PHASE160F_SCORE_RUN_ID_MUST_BE_LEAF=$RunId"
  }
}

$RepoRoot = Resolve-Phase160FScoreRepoRoot
$Pushed = $false

try {
  Push-Location $RepoRoot
  $Pushed = $true

  foreach ($identityFile in @("CAPABILITY_ROADMAP.json", "GENESIS_STATE.json", "TASK_QUEUE.json", "packs/registry.json", "orchestrator/run.ps1")) {
    if (-not (Test-Path -LiteralPath (Resolve-Phase160FScorePath -RepoRoot $RepoRoot -Path $identityFile))) {
      throw "STOP=WRONG_AGENT_BUILDER_REPO missing=$identityFile"
    }
  }

  Assert-Phase160FScoreRunIdSafe -RunId $RunId
  if (-not [string]::IsNullOrWhiteSpace($RunId) -and [string]::IsNullOrWhiteSpace($SessionRoot)) {
    $SessionRoot = "runtime_sessions/live_growth/$RunId"
  }
  if ([string]::IsNullOrWhiteSpace($SessionRoot)) {
    throw "PHASE160F_SCORE_SESSION_ROOT_REQUIRED"
  }

  $SessionRootFull = Resolve-Phase160FScorePath -RepoRoot $RepoRoot -Path $SessionRoot
  $SessionRootRelative = ConvertTo-Phase160FScoreRelativePath -RepoRoot $RepoRoot -FullPath $SessionRootFull
  $SelectionRoot = Join-Path $SessionRootFull "self_initiated_goal_selection"
  New-Item -ItemType Directory -Force -Path $SelectionRoot | Out-Null
  $GapInventory = Read-Phase160FScoreJsonSafe -Path (Join-Path $SelectionRoot "capability_gap_inventory.json")
  if ($null -eq $GapInventory) {
    throw "PHASE160F_SCORE_CAPABILITY_GAP_INVENTORY_MISSING=$SessionRootRelative/self_initiated_goal_selection/capability_gap_inventory.json"
  }

  $Goals = @(
    (New-Phase160FGoalScore -GoalId "SELF_INITIATED_USEFUL_GOAL_SELECTOR_HARDENING" -GoalName "Self-initiated useful goal selector hardening" -ExpectedCapability "self_gap_inventory plus usefulness_scoring can create internal_active_task without teacher_inbox" -CandidateFiles @("modules/select_builder_self_initiated_useful_goal_001.ps1", "modules/score_builder_self_growth_goal_001.ps1") -ValidatorFiles @("validators/validate_phase160f_full_self_initiated_goal_selection_live_candidate_production_v1.ps1") -Autonomy 10 -Safety 8 -OwnerValue 9 -ValidatorFeasibility 9 -ImplementationRisk 3 -DependencyComplexity 2 -ProofSimplicity 9),
    (New-Phase160FGoalScore -GoalId "PROMOTION_BUNDLE_HEALTH_INSPECTOR" -GoalName "Promotion bundle health inspector" -ExpectedCapability "verify promotion_bundle_update evidence before owner review" -CandidateFiles @("modules/inspect_builder_promotion_bundle_health_candidate.ps1") -ValidatorFiles @("validators/validate_promotion_bundle_health_candidate.ps1") -Autonomy 7 -Safety 9 -OwnerValue 8 -ValidatorFeasibility 8 -ImplementationRisk 2 -DependencyComplexity 2 -ProofSimplicity 8),
    (New-Phase160FGoalScore -GoalId "RUNTIME_GUARD_REGRESSION_VALIDATOR" -GoalName "Runtime guard regression validator" -ExpectedCapability "runtime_guard_required checks before candidate_bundle_creation" -CandidateFiles @("validators/validate_runtime_guard_regression_candidate.ps1") -ValidatorFiles @("validators/validate_runtime_guard_regression_candidate.ps1") -Autonomy 7 -Safety 10 -OwnerValue 8 -ValidatorFeasibility 8 -ImplementationRisk 3 -DependencyComplexity 2 -ProofSimplicity 8),
    (New-Phase160FGoalScore -GoalId "CANDIDATE_BUNDLE_COMPLETENESS_INSPECTOR" -GoalName "Candidate bundle completeness inspector" -ExpectedCapability "inspect candidate bundle files and payload completeness" -CandidateFiles @("modules/inspect_builder_candidate_bundle_completeness_candidate.ps1") -ValidatorFiles @("validators/validate_candidate_bundle_completeness_candidate.ps1") -Autonomy 6 -Safety 8 -OwnerValue 8 -ValidatorFeasibility 9 -ImplementationRisk 2 -DependencyComplexity 1 -ProofSimplicity 8),
    (New-Phase160FGoalScore -GoalId "BACKLOG_PLAN_ADVANCEMENT_VALIDATOR" -GoalName "Backlog and plan advancement validator" -ExpectedCapability "validate plan/backlog transitions into WAITING_OWNER_PROMOTION" -CandidateFiles @("validators/validate_backlog_plan_advancement_candidate.ps1") -ValidatorFiles @("validators/validate_backlog_plan_advancement_candidate.ps1") -Autonomy 6 -Safety 7 -OwnerValue 7 -ValidatorFeasibility 8 -ImplementationRisk 2 -DependencyComplexity 2 -ProofSimplicity 8),
    (New-Phase160FGoalScore -GoalId "FINAL_HANDOFF_SUMMARY_INSPECTOR" -GoalName "Final handoff summary inspector" -ExpectedCapability "check restart rule and owner handoff contents" -CandidateFiles @("modules/inspect_final_handoff_summary_candidate.ps1") -ValidatorFiles @("validators/validate_final_handoff_summary_candidate.ps1") -Autonomy 5 -Safety 7 -OwnerValue 8 -ValidatorFeasibility 8 -ImplementationRisk 2 -DependencyComplexity 1 -ProofSimplicity 9),
    (New-Phase160FGoalScore -GoalId "RECOVERY_REPORT_GENERATOR" -GoalName "Recovery report generator" -ExpectedCapability "create recovery report after blocked live sessions" -CandidateFiles @("modules/write_builder_recovery_report_candidate.ps1") -ValidatorFiles @("validators/validate_recovery_report_candidate.ps1") -Autonomy 6 -Safety 8 -OwnerValue 7 -ValidatorFeasibility 7 -ImplementationRisk 3 -DependencyComplexity 2 -ProofSimplicity 7),
    (New-Phase160FGoalScore -GoalId "LIVE_CONSOLE_FIELD_INTEGRITY_INSPECTOR" -GoalName "Live console field integrity inspector" -ExpectedCapability "ensure console shows live candidate and guard fields" -CandidateFiles @("modules/inspect_live_console_field_integrity_candidate.ps1") -ValidatorFiles @("validators/validate_live_console_field_integrity_candidate.ps1") -Autonomy 5 -Safety 7 -OwnerValue 8 -ValidatorFeasibility 8 -ImplementationRisk 2 -DependencyComplexity 1 -ProofSimplicity 8)
  )

  $Candidates = [ordered]@{
    status = "PASS"
    run_id = if ([string]::IsNullOrWhiteSpace($RunId)) { "NONE" } else { $RunId }
    candidate_goal_count = $Goals.Count
    goals = $Goals
    no_teacher_inbox_required = [bool]$GapInventory.no_teacher_inbox_required
    created_at = (Get-Date).ToUniversalTime().ToString("o")
  }
  $Scores = [ordered]@{
    status = "PASS"
    run_id = $Candidates.run_id
    scoring_model = "autonomy+safety+owner_value+validator_feasibility+proof_simplicity-risk-dependency"
    scoring_fields = @(
      "autonomy_gain_score",
      "safety_gain_score",
      "owner_value_score",
      "validator_feasibility_score",
      "implementation_risk_score",
      "dependency_complexity_score",
      "proof_simplicity_score",
      "total_usefulness_score"
    )
    scored_goals = @($Goals | Sort-Object @{ Expression = { -[int]$_.total_usefulness_score } }, @{ Expression = { [string]$_.goal_id } })
    created_at = (Get-Date).ToUniversalTime().ToString("o")
  }

  Write-Phase160FScoreJsonFile -Path (Join-Path $SelectionRoot "useful_goal_candidates.json") -Object $Candidates
  Write-Phase160FScoreJsonFile -Path (Join-Path $SelectionRoot "useful_goal_scores.json") -Object $Scores

  [pscustomobject][ordered]@{
    status = "PASS"
    run_id = $Candidates.run_id
    session_root = $SessionRootRelative
    selection_root = ConvertTo-Phase160FScoreRelativePath -RepoRoot $RepoRoot -FullPath $SelectionRoot
    useful_goal_candidates_written = $true
    useful_goal_scores_written = $true
    useful_goal_candidate_count = $Goals.Count
    top_goal_id = [string]$Scores.scored_goals[0].goal_id
    top_goal_score = [int]$Scores.scored_goals[0].total_usefulness_score
  } | ConvertTo-Json -Depth 20
} finally {
  if ($Pushed) {
    Pop-Location
  }
}
