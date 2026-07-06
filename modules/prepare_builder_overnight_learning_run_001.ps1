param(
  [string]$RepoRoot = "",
  [string]$RunId = "",
  [string]$IntendedMode = "SELF_MODE",
  [string]$CurriculumId = "NONE",
  [int]$MaxLessons = 8,
  [int]$MaxRuntimeMinutes = 480,
  [string[]]$StopConditions = @("stop.flag_present", "owner_review_required", "runtime_budget_exhausted", "safety_violation_detected"),
  [switch]$EmitJson
)

$ErrorActionPreference = "Stop"

function Resolve-Phase161BOvernightRepoRoot {
  param([string]$RepoRoot)
  if (-not [string]::IsNullOrWhiteSpace($RepoRoot)) {
    return [System.IO.Path]::GetFullPath($RepoRoot)
  }
  return [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
}

function Write-Phase161BOvernightJson {
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

function New-Phase161BOvernightLearningRunPlan {
  param(
    [string]$RepoRoot = "",
    [string]$RunId = "",
    [string]$IntendedMode = "SELF_MODE",
    [string]$CurriculumId = "NONE",
    [int]$MaxLessons = 8,
    [int]$MaxRuntimeMinutes = 480,
    [string[]]$StopConditions = @("stop.flag_present", "owner_review_required", "runtime_budget_exhausted", "safety_violation_detected")
  )
  $resolvedRepoRoot = Resolve-Phase161BOvernightRepoRoot -RepoRoot $RepoRoot
  if ([string]::IsNullOrWhiteSpace($RunId)) {
    $RunId = "PHASE161B_OVERNIGHT_PREP_{0}" -f ((Get-Date).ToUniversalTime().ToString("yyyyMMddHHmmss"))
  }
  if ($RunId -match "[\\/:\*\?`"<>|]") {
    throw "PHASE161B_OVERNIGHT_RUN_ID_MUST_BE_LEAF=$RunId"
  }
  $runRoot = Join-Path $resolvedRepoRoot "runtime_sessions/learning_runs/$RunId"
  $plan = [ordered]@{
    status = "PREPARED_NOT_RUN"
    run_id = $RunId
    intended_mode = $IntendedMode
    curriculum_id = $CurriculumId
    max_lessons = $MaxLessons
    max_runtime_minutes = $MaxRuntimeMinutes
    stop_conditions = @($StopConditions)
    archive_required = $true
    morning_review_required = $true
    absorption_required = $true
    no_accepted_repo_mutation = $true
    no_commit_push_branch_switch = $true
    created_at = (Get-Date).ToUniversalTime().ToString("o")
  }
  $planPath = Join-Path $runRoot "overnight_learning_run_plan.json"
  Write-Phase161BOvernightJson -Path $planPath -Object $plan
  return [pscustomobject][ordered]@{
    status = "PASS"
    overnight_learning_run_plan_created = $true
    run_id = $RunId
    plan_path = $planPath
    no_accepted_repo_mutation = $true
    no_commit_push_branch_switch = $true
  }
}

if ($EmitJson) {
  New-Phase161BOvernightLearningRunPlan -RepoRoot $RepoRoot -RunId $RunId -IntendedMode $IntendedMode -CurriculumId $CurriculumId -MaxLessons $MaxLessons -MaxRuntimeMinutes $MaxRuntimeMinutes -StopConditions $StopConditions | ConvertTo-Json -Depth 40
}
