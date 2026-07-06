param(
  [string]$AbsorptionPath = "",
  [string]$ReportPath = "",
  [switch]$EmitJson
)

$ErrorActionPreference = "Stop"

function Read-Phase161BAbsorptionReportJson {
  param([string]$Path)
  return Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json
}

function Write-Phase161BAbsorptionReport {
  param(
    [Parameter(Mandatory = $true)]
    [object]$Absorption,
    [Parameter(Mandatory = $true)]
    [string]$ReportPath
  )
  $directory = Split-Path -Path $ReportPath -Parent
  if ($directory -and -not (Test-Path -LiteralPath $directory)) {
    New-Item -ItemType Directory -Force -Path $directory | Out-Null
  }
  $clusterLines = @($Absorption.repeated_failure_clusters | ForEach-Object {
    "- $($_.cluster_id): $($_.cluster_type), count=$($_.count), next_action=$($_.next_action)"
  })
  if ($clusterLines.Count -eq 0) {
    $clusterLines = @("- NONE")
  }
  $gapLines = @($Absorption.recommended_next_gaps | ForEach-Object { "- $_" })
  if ($gapLines.Count -eq 0) {
    $gapLines = @("- CONSOLIDATE_PASSING_SCHOOL_PATTERNS")
  }
  $markdown = @(
    "# PHASE161B Learning Absorption Report",
    "",
    "absorption_id: $($Absorption.absorption_id)",
    "source_school_run_id: $($Absorption.source_school_run_id)",
    "source_curriculum_id: $($Absorption.source_curriculum_id)",
    "lesson_total_count: $($Absorption.lesson_total_count)",
    "lesson_pass_count: $($Absorption.lesson_pass_count)",
    "lesson_fail_count: $($Absorption.lesson_fail_count)",
    "lesson_quarantine_count: $($Absorption.lesson_quarantine_count)",
    "",
    "## Failure Clusters",
    ($clusterLines -join "`n"),
    "",
    "## Recommended Next Gaps",
    ($gapLines -join "`n"),
    "",
    "self_mode_resume_recommendation: $($Absorption.self_mode_resume_recommendation)",
    "accepted_repo_mutated: false",
    "protected_state_mutated: false"
  ) -join "`n"
  [System.IO.File]::WriteAllText($ReportPath, "$markdown`n", [System.Text.UTF8Encoding]::new($false))
  return [pscustomobject][ordered]@{
    status = "PASS"
    report_written = $true
    report_path = $ReportPath
    accepted_repo_mutated = $false
    protected_state_mutated = $false
  }
}

if ($EmitJson) {
  if ([string]::IsNullOrWhiteSpace($AbsorptionPath) -or [string]::IsNullOrWhiteSpace($ReportPath)) {
    throw "PHASE161B_ABSORPTION_REPORT_PATHS_REQUIRED"
  }
  $absorption = Read-Phase161BAbsorptionReportJson -Path $AbsorptionPath
  Write-Phase161BAbsorptionReport -Absorption $absorption -ReportPath $ReportPath | ConvertTo-Json -Depth 20
}
