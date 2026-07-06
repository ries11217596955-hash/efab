param(
  [string]$RepoRoot = "",
  [string]$SchoolRunId = "",
  [string]$SchoolRunRoot = "",
  [switch]$EmitJson
)

$ErrorActionPreference = "Stop"

function Resolve-Phase161BClusterRepoRoot {
  param([string]$RepoRoot)
  if (-not [string]::IsNullOrWhiteSpace($RepoRoot)) {
    return [System.IO.Path]::GetFullPath($RepoRoot)
  }
  return [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
}

function Resolve-Phase161BClusterSchoolRunRoot {
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
  throw "PHASE161B_CLUSTER_SCHOOL_RUN_REQUIRED"
}

function Read-Phase161BClusterJsonSafe {
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

function Get-Phase161BFailureClusterType {
  param([object]$Result)
  $status = [string]$Result.status
  $failureReason = if ($Result.PSObject.Properties.Name -contains "failure_reason") { [string]$Result.failure_reason } else { "" }
  $quarantineReason = if ($Result.PSObject.Properties.Name -contains "quarantine_reason") { [string]$Result.quarantine_reason } else { "" }
  $reasonText = "$failureReason $quarantineReason".ToLowerInvariant()
  if ($status -eq "QUARANTINED" -or $reasonText -match "unsafe|safety|commit|push|branch|protected|accepted_repo") {
    return "safety_violation"
  }
  if ($reasonText -match "schema|json") {
    return "schema_error"
  }
  if ($reasonText -match "missing_expected_output|missing expected|missing_output") {
    return "missing_expected_output"
  }
  if ($reasonText -match "validator|validation") {
    return "validator_failed"
  }
  if ($reasonText -match "timeout|timed out") {
    return "timeout"
  }
  if ([string]::IsNullOrWhiteSpace($reasonText) -or $reasonText.Trim() -eq "none") {
    return "unknown"
  }
  return "unknown"
}

function New-Phase161BClusterRecord {
  param(
    [string]$ClusterId,
    [string]$ClusterType,
    [object[]]$Results
  )
  $lessonIds = @($Results | ForEach-Object { [string]$_.lesson_id } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
  $reasons = @($Results | ForEach-Object {
    $reason = if ($_.PSObject.Properties.Name -contains "failure_reason" -and -not [string]::IsNullOrWhiteSpace([string]$_.failure_reason) -and [string]$_.failure_reason -ne "NONE") {
      [string]$_.failure_reason
    } elseif ($_.PSObject.Properties.Name -contains "quarantine_reason" -and -not [string]::IsNullOrWhiteSpace([string]$_.quarantine_reason) -and [string]$_.quarantine_reason -ne "NONE") {
      [string]$_.quarantine_reason
    } else {
      "unspecified"
    }
    $reason
  } | Select-Object -Unique)
  $retryRecommended = $ClusterType -notin @("safety_violation")
  $nextAction = switch ($ClusterType) {
    "schema_error" { "repair_schema_or_pack_shape_before_retry" }
    "safety_violation" { "quarantine_and_request_owner_review" }
    "missing_expected_output" { "repair_expected_output_or_lesson_artifact" }
    "validator_failed" { "inspect_validator_expectation_and_retry" }
    "timeout" { "reduce_lesson_scope_or_runtime_limit" }
    "repeated_fail_same_lesson_type" { "split_repeated_lesson_type_into_smaller_steps" }
    default { "inspect_failure_record_before_retry" }
  }
  return [ordered]@{
    cluster_id = $ClusterId
    cluster_type = $ClusterType
    lesson_ids = @($lessonIds)
    count = @($lessonIds).Count
    example_failure_reasons = @($reasons)
    retry_recommended = $retryRecommended
    repair_recommended = $true
    next_action = $nextAction
  }
}

function Get-Phase161BLessonFailureClusters {
  param(
    [string]$RepoRoot = "",
    [string]$SchoolRunId = "",
    [string]$SchoolRunRoot = ""
  )
  $resolvedRepoRoot = Resolve-Phase161BClusterRepoRoot -RepoRoot $RepoRoot
  $schoolRunRootFull = Resolve-Phase161BClusterSchoolRunRoot -RepoRoot $resolvedRepoRoot -SchoolRunId $SchoolRunId -SchoolRunRoot $SchoolRunRoot
  $manifest = Read-Phase161BClusterJsonSafe -Path (Join-Path $schoolRunRootFull "school_run_manifest.json")
  if ($null -eq $manifest) {
    throw "PHASE161B_CLUSTER_SCHOOL_RUN_MANIFEST_MISSING"
  }
  $resultRoot = Join-Path $schoolRunRootFull "lesson_results"
  $resultFiles = @()
  if (Test-Path -LiteralPath $resultRoot) {
    $resultFiles = @(Get-ChildItem -LiteralPath $resultRoot -File -Filter "*_result.json" -ErrorAction SilentlyContinue | Sort-Object Name)
  }
  $results = @()
  foreach ($resultFile in $resultFiles) {
    $result = Read-Phase161BClusterJsonSafe -Path $resultFile.FullName
    if ($null -ne $result -and [string]$result.status -ne "PASS") {
      $results += $result
    }
  }
  $clusters = @()
  $index = 0
  $typed = @{}
  foreach ($result in $results) {
    $type = Get-Phase161BFailureClusterType -Result $result
    if (-not $typed.ContainsKey($type)) {
      $typed[$type] = @()
    }
    $typed[$type] = @($typed[$type]) + $result
  }
  foreach ($type in @("schema_error", "safety_violation", "missing_expected_output", "validator_failed", "timeout", "unknown")) {
    if ($typed.ContainsKey($type) -and @($typed[$type]).Count -gt 0) {
      $index += 1
      $clusters += New-Phase161BClusterRecord -ClusterId ("CLUSTER_{0:d3}_{1}" -f $index, $type.ToUpperInvariant()) -ClusterType $type -Results @($typed[$type])
    }
  }
  $reasonGroups = @($results | Group-Object -Property failure_reason | Where-Object { $_.Count -gt 1 -and -not [string]::IsNullOrWhiteSpace([string]$_.Name) -and [string]$_.Name -ne "NONE" })
  foreach ($group in $reasonGroups) {
    $index += 1
    $clusters += New-Phase161BClusterRecord -ClusterId ("CLUSTER_{0:d3}_REPEATED_FAIL_SAME_LESSON_TYPE" -f $index) -ClusterType "repeated_fail_same_lesson_type" -Results @($group.Group)
  }
  return [pscustomobject][ordered]@{
    status = "PASS"
    clustering_id = "PHASE161B_FAILURE_CLUSTERING"
    school_run_id = [string]$manifest.school_run_id
    source_curriculum_id = [string]$manifest.curriculum_id
    failure_clustering_upgraded = $true
    cluster_count = @($clusters).Count
    clusters = @($clusters)
    accepted_repo_mutated = $false
    protected_state_mutated = $false
    created_at = (Get-Date).ToUniversalTime().ToString("o")
  }
}

if ($EmitJson) {
  Get-Phase161BLessonFailureClusters -RepoRoot $RepoRoot -SchoolRunId $SchoolRunId -SchoolRunRoot $SchoolRunRoot | ConvertTo-Json -Depth 50
}
