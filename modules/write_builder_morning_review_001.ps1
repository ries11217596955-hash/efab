param(
  [string]$SchoolRunRoot = ""
)

$ErrorActionPreference = "Stop"
$Phase161BMorningReviewSavedSchoolRunRoot = $SchoolRunRoot
. (Join-Path $PSScriptRoot "cluster_builder_lesson_failures_001.ps1")
$SchoolRunRoot = $Phase161BMorningReviewSavedSchoolRunRoot
Remove-Variable -Name Phase161BMorningReviewSavedSchoolRunRoot -ErrorAction SilentlyContinue

function Read-Phase161AMorningReviewJsonSafe {
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

function Write-Phase161AMorningReviewJsonFile {
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

function Get-Phase161AClusterRecords {
  param(
    [object[]]$Results,
    [string]$Status,
    [string]$ReasonField,
    [string]$DefaultReason
  )
  $clusters = @()
  $groups = @($Results | Where-Object { [string]$_.status -eq $Status } | Group-Object -Property $ReasonField)
  foreach ($group in $groups) {
    $reason = if ([string]::IsNullOrWhiteSpace([string]$group.Name)) { $DefaultReason } else { [string]$group.Name }
    $clusters += [ordered]@{
      reason = $reason
      count = $group.Count
      lesson_ids = @($group.Group | ForEach-Object { [string]$_.lesson_id })
    }
  }
  return @($clusters)
}

function Write-Phase161AMorningReview {
  param(
    [Parameter(Mandatory = $true)]
    [string]$SchoolRunRoot
  )
  $schoolRunRootFull = [System.IO.Path]::GetFullPath($SchoolRunRoot)
  $manifest = Read-Phase161AMorningReviewJsonSafe -Path (Join-Path $schoolRunRootFull "school_run_manifest.json")
  if ($null -eq $manifest) {
    throw "PHASE161A_SCHOOL_RUN_MANIFEST_MISSING"
  }
  $resultsRoot = Join-Path $schoolRunRootFull "lesson_results"
  $resultFiles = @(Get-ChildItem -LiteralPath $resultsRoot -File -Filter "*_result.json" -ErrorAction SilentlyContinue | Sort-Object Name)
  $results = @()
  foreach ($resultFile in $resultFiles) {
    $result = Read-Phase161AMorningReviewJsonSafe -Path $resultFile.FullName
    if ($null -ne $result) {
      $results += $result
    }
  }
  $passCount = @($results | Where-Object { [string]$_.status -eq "PASS" }).Count
  $failCount = @($results | Where-Object { [string]$_.status -eq "FAIL" }).Count
  $quarantineCount = @($results | Where-Object { [string]$_.status -eq "QUARANTINED" }).Count
  $clusterResult = Get-Phase161BLessonFailureClusters -SchoolRunRoot $schoolRunRootFull
  $failureClusters = @($clusterResult.clusters | Where-Object { [string]$_.cluster_type -ne "safety_violation" })
  $quarantineClusters = @($clusterResult.clusters | Where-Object { [string]$_.cluster_type -eq "safety_violation" })
  if ($failureClusters.Count -lt 1) {
    $failureClusters = Get-Phase161AClusterRecords -Results $results -Status "FAIL" -ReasonField "failure_reason" -DefaultReason "unspecified_failure"
  }
  if ($quarantineClusters.Count -lt 1) {
    $quarantineClusters = Get-Phase161AClusterRecords -Results $results -Status "QUARANTINED" -ReasonField "quarantine_reason" -DefaultReason "unspecified_quarantine"
  }
  $recommendations = @()
  if ($failCount -gt 0) {
    $recommendations += "Review failed lesson outputs and repair the curriculum or runner expectation before promotion."
  }
  if ($quarantineCount -gt 0) {
    $recommendations += "Keep quarantined lessons separated from ordinary failures and require owner review before any unsafe action."
  }
  if ($recommendations.Count -eq 0) {
    $recommendations += "No morning review repair action required for this bounded school run."
  }
  $review = [ordered]@{
    review_id = "$($manifest.school_run_id)_MORNING_REVIEW"
    school_run_id = [string]$manifest.school_run_id
    curriculum_id = [string]$manifest.curriculum_id
    active_route_lock_stamp = [string]$manifest.active_route_lock_stamp
    route_step_id = [string]$manifest.route_step_id
    lesson_total_count = $results.Count
    lesson_pass_count = $passCount
    lesson_fail_count = $failCount
    lesson_quarantine_count = $quarantineCount
    failure_clusters = @($failureClusters)
    quarantine_clusters = @($quarantineClusters)
    recommendations = @($recommendations)
    accepted_repo_mutated = $false
    protected_state_mutated = $false
    failure_clustering_skeleton_created = $true
    failure_clustering_upgraded = [bool]$clusterResult.failure_clustering_upgraded
    created_at = (Get-Date).ToUniversalTime().ToString("o")
  }
  $reviewJsonPath = Join-Path $schoolRunRootFull "morning_review.json"
  Write-Phase161AMorningReviewJsonFile -Path $reviewJsonPath -Object $review
  $markdown = @(
    "# PHASE161A School Morning Review",
    "",
    "school_run_id: $($review.school_run_id)",
    "curriculum_id: $($review.curriculum_id)",
    "active_route_lock_stamp: $($review.active_route_lock_stamp)",
    "route_step_id: $($review.route_step_id)",
    "lesson_total_count: $($review.lesson_total_count)",
    "lesson_pass_count: $($review.lesson_pass_count)",
    "lesson_fail_count: $($review.lesson_fail_count)",
    "lesson_quarantine_count: $($review.lesson_quarantine_count)",
    "",
    "Failure clusters and quarantine clusters are intentionally separate."
  ) -join "`n"
  [System.IO.File]::WriteAllText((Join-Path $schoolRunRootFull "morning_review.md"), "$markdown`n", [System.Text.UTF8Encoding]::new($false))
  return [pscustomobject][ordered]@{
    status = "PASS"
    morning_review_created = $true
    failure_clustering_skeleton_created = $true
    morning_review_path = $reviewJsonPath
    lesson_pass_count = $passCount
    lesson_fail_count = $failCount
    lesson_quarantine_count = $quarantineCount
  }
}

if (-not [string]::IsNullOrWhiteSpace($SchoolRunRoot)) {
  Write-Phase161AMorningReview -SchoolRunRoot $SchoolRunRoot | ConvertTo-Json -Depth 50
}
