param(
  [string]$AbsorptionPath = "",
  [string]$OutputPath = "",
  [switch]$EmitJson
)

$ErrorActionPreference = "Stop"

function Read-Phase161BNextStepJson {
  param([string]$Path)
  return Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json
}

function Write-Phase161BNextStepJson {
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

function Select-Phase161BNextSelfLearningStep {
  param(
    [Parameter(Mandatory = $true)]
    [object]$Absorption,
    [string]$OutputPath = ""
  )
  $clusters = @($Absorption.repeated_failure_clusters)
  $passPatterns = @($Absorption.useful_patterns)
  $nonSafetyCluster = @($clusters | Where-Object { [string]$_.cluster_type -ne "safety_violation" } | Select-Object -First 1)
  $safetyCluster = @($clusters | Where-Object { [string]$_.cluster_type -eq "safety_violation" } | Select-Object -First 1)
  $recommendedGap = "CONSOLIDATE_PASSING_SCHOOL_PATTERNS"
  $reason = "School run produced no blocking failure cluster; resume self mode by consolidating useful patterns."
  $safeNextAction = "resume_self_mode_with_session_local_recommendation_review"
  if ($safetyCluster.Count -gt 0) {
    $recommendedGap = "REVIEW_SAFE_CURRICULUM_BOUNDARIES"
    $reason = "A safety violation was quarantined; resume self mode only with owner-visible safety review."
    $safeNextAction = "review_quarantined_curriculum_before_any_retry"
  } elseif ($nonSafetyCluster.Count -gt 0) {
    $recommendedGap = switch ([string]$nonSafetyCluster[0].cluster_type) {
      "schema_error" { "REPAIR_CURRICULUM_SCHEMA_ALIGNMENT" }
      "missing_expected_output" { "REPAIR_LESSON_EXPECTATION_ALIGNMENT" }
      "validator_failed" { "RECHECK_VALIDATOR_EXPECTATION_PATH" }
      "timeout" { "REDUCE_LESSON_RUNTIME_SCOPE" }
      "repeated_fail_same_lesson_type" { "SPLIT_REPEATED_FAILURE_LESSON_TYPE" }
      default { "INSPECT_UNKNOWN_LESSON_FAILURE" }
    }
    $reason = "A school lesson cluster requires a bounded self-mode repair recommendation."
    $safeNextAction = "write_owner_visible_gap_recommendation_only"
  }
  $recommendation = [ordered]@{
    resume_mode = "SELF_MODE"
    recommended_next_gap = $recommendedGap
    recommended_reason = $reason
    source_school_run_id = [string]$Absorption.source_school_run_id
    source_absorption_id = [string]$Absorption.absorption_id
    source_failure_clusters = @($clusters | ForEach-Object { [string]$_.cluster_id })
    source_pass_patterns = @($passPatterns)
    avoid_repeating = @($clusters | Where-Object { [string]$_.cluster_type -in @("safety_violation", "repeated_fail_same_lesson_type") } | ForEach-Object { [string]$_.next_action })
    safe_next_action = $safeNextAction
    owner_review_required = [bool]$Absorption.owner_review_required
    accepted_repo_mutated = $false
    protected_state_mutated = $false
    created_at = (Get-Date).ToUniversalTime().ToString("o")
  }
  if (-not [string]::IsNullOrWhiteSpace($OutputPath)) {
    Write-Phase161BNextStepJson -Path $OutputPath -Object $recommendation
  }
  return [pscustomobject]$recommendation
}

if ($EmitJson) {
  if ([string]::IsNullOrWhiteSpace($AbsorptionPath)) {
    throw "PHASE161B_NEXT_STEP_ABSORPTION_PATH_REQUIRED"
  }
  $absorption = Read-Phase161BNextStepJson -Path $AbsorptionPath
  Select-Phase161BNextSelfLearningStep -Absorption $absorption -OutputPath $OutputPath | ConvertTo-Json -Depth 50
}
