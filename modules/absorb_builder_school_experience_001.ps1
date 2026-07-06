param(
  [string]$RepoRoot = "",
  [string]$SchoolRunId = "",
  [string]$SchoolRunRoot = "",
  [string]$AbsorptionId = "",
  [switch]$EmitJson
)

$ErrorActionPreference = "Stop"

function Resolve-Phase161BAbsorbRepoRoot {
  param([string]$RepoRoot)
  if (-not [string]::IsNullOrWhiteSpace($RepoRoot)) {
    return [System.IO.Path]::GetFullPath($RepoRoot)
  }
  return [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
}

function Resolve-Phase161BAbsorbSchoolRunRoot {
  param([string]$RepoRoot, [string]$SchoolRunId, [string]$SchoolRunRoot)
  if (-not [string]::IsNullOrWhiteSpace($SchoolRunRoot)) {
    if ([System.IO.Path]::IsPathRooted($SchoolRunRoot)) {
      return [System.IO.Path]::GetFullPath($SchoolRunRoot)
    }
    return [System.IO.Path]::GetFullPath((Join-Path $RepoRoot $SchoolRunRoot))
  }
  if (-not [string]::IsNullOrWhiteSpace($SchoolRunId)) {
    return [System.IO.Path]::GetFullPath((Join-Path $RepoRoot "runtime_sessions/school_runs/$SchoolRunId"))
  }
  throw "PHASE161B_ABSORB_SCHOOL_RUN_REQUIRED"
}

function Read-Phase161BAbsorbJsonSafe {
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

function Write-Phase161BAbsorbJson {
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

function Invoke-Phase161BAbsorbJsonScript {
  param([string]$ScriptPath, [string[]]$Arguments)
  $output = @(powershell -NoProfile -ExecutionPolicy Bypass -File $ScriptPath @Arguments 2>&1 | ForEach-Object { [string]$_ })
  if ($LASTEXITCODE -ne 0) {
    throw "PHASE161B_ABSORB_CHILD_SCRIPT_FAILED=$ScriptPath output=$($output -join ' | ')"
  }
  return ($output -join "`n") | ConvertFrom-Json
}

function Invoke-Phase161BSchoolExperienceAbsorption {
  param(
    [string]$RepoRoot = "",
    [string]$SchoolRunId = "",
    [string]$SchoolRunRoot = "",
    [string]$AbsorptionId = ""
  )
  $resolvedRepoRoot = Resolve-Phase161BAbsorbRepoRoot -RepoRoot $RepoRoot
  $schoolRunRootFull = Resolve-Phase161BAbsorbSchoolRunRoot -RepoRoot $resolvedRepoRoot -SchoolRunId $SchoolRunId -SchoolRunRoot $SchoolRunRoot
  $manifest = Read-Phase161BAbsorbJsonSafe -Path (Join-Path $schoolRunRootFull "school_run_manifest.json")
  if ($null -eq $manifest) {
    throw "PHASE161B_ABSORB_SCHOOL_RUN_MANIFEST_MISSING"
  }
  if ([string]::IsNullOrWhiteSpace($AbsorptionId)) {
    $AbsorptionId = "PHASE161B_ABSORB_{0}_{1}" -f ([string]$manifest.school_run_id), ((Get-Date).ToUniversalTime().ToString("yyyyMMddHHmmss"))
  }
  if ($AbsorptionId -match "[\\/:\*\?`"<>|]") {
    throw "PHASE161B_ABSORPTION_ID_MUST_BE_LEAF=$AbsorptionId"
  }
  $absorptionRoot = Join-Path $resolvedRepoRoot "runtime_sessions/learning_absorption/$AbsorptionId"
  if (-not (Test-Path -LiteralPath $absorptionRoot)) {
    New-Item -ItemType Directory -Force -Path $absorptionRoot | Out-Null
  }
  $resultRoot = Join-Path $schoolRunRootFull "lesson_results"
  $resultFiles = @(Get-ChildItem -LiteralPath $resultRoot -File -Filter "*_result.json" -ErrorAction SilentlyContinue | Sort-Object Name)
  $results = @()
  foreach ($resultFile in $resultFiles) {
    $result = Read-Phase161BAbsorbJsonSafe -Path $resultFile.FullName
    if ($null -ne $result) {
      $results += $result
    }
  }
  $clusterScript = Join-Path $resolvedRepoRoot "modules/cluster_builder_lesson_failures_001.ps1"
  $clusterResult = Invoke-Phase161BAbsorbJsonScript -ScriptPath $clusterScript -Arguments @("-RepoRoot", $resolvedRepoRoot, "-SchoolRunRoot", $schoolRunRootFull, "-EmitJson")
  $clusters = @($clusterResult.clusters)
  $passLessons = @($results | Where-Object { [string]$_.status -eq "PASS" })
  $usefulPatterns = @($passLessons | ForEach-Object { "passed_lesson:$([string]$_.lesson_id)" })
  if ($usefulPatterns.Count -eq 0) {
    $usefulPatterns = @("no_pass_patterns_recorded")
  }
  $unsafePatterns = @($clusters | Where-Object { [string]$_.cluster_type -eq "safety_violation" } | ForEach-Object { [string]$_.next_action })
  $retryLessons = @($clusters | Where-Object { [bool]$_.retry_recommended } | ForEach-Object { @($_.lesson_ids) } | ForEach-Object { [string]$_ } | Select-Object -Unique)
  $recommendedNextGaps = @($clusters | ForEach-Object {
    switch ([string]$_.cluster_type) {
      "safety_violation" { "REVIEW_SAFE_CURRICULUM_BOUNDARIES" }
      "schema_error" { "REPAIR_CURRICULUM_SCHEMA_ALIGNMENT" }
      "missing_expected_output" { "REPAIR_LESSON_EXPECTATION_ALIGNMENT" }
      "validator_failed" { "RECHECK_VALIDATOR_EXPECTATION_PATH" }
      "timeout" { "REDUCE_LESSON_RUNTIME_SCOPE" }
      "repeated_fail_same_lesson_type" { "SPLIT_REPEATED_FAILURE_LESSON_TYPE" }
      default { "INSPECT_UNKNOWN_LESSON_FAILURE" }
    }
  } | Select-Object -Unique)
  if ($recommendedNextGaps.Count -eq 0) {
    $recommendedNextGaps = @("CONSOLIDATE_PASSING_SCHOOL_PATTERNS")
  }
  $curriculumUpdates = @($clusters | ForEach-Object { [ordered]@{ cluster_id = [string]$_.cluster_id; recommended_update = [string]$_.next_action } })
  $absorption = [ordered]@{
    status = "PASS"
    absorption_id = $AbsorptionId
    source_school_run_id = [string]$manifest.school_run_id
    source_curriculum_id = [string]$manifest.curriculum_id
    lesson_total_count = [int]$manifest.lesson_total_count
    lesson_pass_count = [int]$manifest.lesson_pass_count
    lesson_fail_count = [int]$manifest.lesson_fail_count
    lesson_quarantine_count = [int]$manifest.lesson_quarantine_count
    repeated_failure_clusters = @($clusters)
    useful_patterns = @($usefulPatterns)
    unsafe_patterns = @($unsafePatterns)
    recommended_next_gaps = @($recommendedNextGaps)
    recommended_retry_lessons = @($retryLessons)
    recommended_curriculum_updates = @($curriculumUpdates)
    self_mode_resume_recommendation = [string]$recommendedNextGaps[0]
    accepted_repo_mutated = $false
    protected_state_mutated = $false
    owner_review_required = $true
    created_at = (Get-Date).ToUniversalTime().ToString("o")
  }
  $absorptionPath = Join-Path $absorptionRoot "learning_absorption.json"
  Write-Phase161BAbsorbJson -Path $absorptionPath -Object $absorption
  $suggestions = [ordered]@{
    status = "PASS"
    absorption_id = $AbsorptionId
    source_school_run_id = [string]$manifest.school_run_id
    suggestions = @($recommendedNextGaps | ForEach-Object { [ordered]@{ suggested_gap = [string]$_; mutation_target = "recommendation_only"; protected_state_mutation_allowed = $false } })
    accepted_repo_mutated = $false
    protected_state_mutated = $false
    created_at = (Get-Date).ToUniversalTime().ToString("o")
  }
  Write-Phase161BAbsorbJson -Path (Join-Path $absorptionRoot "school_to_gap_backlog_suggestions.json") -Object $suggestions
  $nextStepScript = Join-Path $resolvedRepoRoot "modules/select_builder_next_self_learning_step_001.ps1"
  $nextRecommendationsPath = Join-Path $absorptionRoot "next_self_learning_recommendations.json"
  $nextStep = Invoke-Phase161BAbsorbJsonScript -ScriptPath $nextStepScript -Arguments @("-AbsorptionPath", $absorptionPath, "-OutputPath", $nextRecommendationsPath, "-EmitJson")
  $reportScript = Join-Path $resolvedRepoRoot "modules/write_builder_learning_absorption_report_001.ps1"
  $reportPath = Join-Path $absorptionRoot "learning_absorption_report.md"
  $reportResult = Invoke-Phase161BAbsorbJsonScript -ScriptPath $reportScript -Arguments @("-AbsorptionPath", $absorptionPath, "-ReportPath", $reportPath, "-EmitJson")
  return [pscustomobject][ordered]@{
    status = "PASS"
    absorption_written = $true
    absorption_id = $AbsorptionId
    absorption_root = ($absorptionRoot.Substring($resolvedRepoRoot.TrimEnd([System.IO.Path]::DirectorySeparatorChar).Length + 1) -replace "\\", "/")
    source_school_run_id = [string]$manifest.school_run_id
    source_curriculum_id = [string]$manifest.curriculum_id
    failure_clustering_upgraded = [bool]$clusterResult.failure_clustering_upgraded
    cluster_count = [int]$clusterResult.cluster_count
    next_self_learning_recommendation_created = (Test-Path -LiteralPath $nextRecommendationsPath)
    recommended_next_self_gap = [string]$nextStep.recommended_next_gap
    learning_absorption_report_created = [bool]$reportResult.report_written
    school_to_gap_backlog_suggestions_created = (Test-Path -LiteralPath (Join-Path $absorptionRoot "school_to_gap_backlog_suggestions.json"))
    accepted_repo_mutated = $false
    protected_state_mutated = $false
  }
}

if ($EmitJson) {
  Invoke-Phase161BSchoolExperienceAbsorption -RepoRoot $RepoRoot -SchoolRunId $SchoolRunId -SchoolRunRoot $SchoolRunRoot -AbsorptionId $AbsorptionId | ConvertTo-Json -Depth 80
}
