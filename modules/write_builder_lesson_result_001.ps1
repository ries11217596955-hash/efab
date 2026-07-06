param(
  [string]$SchoolRunRoot = "",
  [string]$LessonId = "",
  [int]$LessonIndex = 0,
  [ValidateSet("PASS", "FAIL", "QUARANTINED")]
  [string]$Status = "PASS",
  [string]$FailureReason = "NONE",
  [string]$QuarantineReason = "NONE",
  [string[]]$ArtifactsCreated = @(),
  [bool]$ContinuedAfterFailure = $false
)

$ErrorActionPreference = "Stop"

function Write-Phase161ALessonResultJsonFile {
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

function Write-Phase161ALessonResult {
  param(
    [Parameter(Mandatory = $true)]
    [string]$SchoolRunRoot,
    [Parameter(Mandatory = $true)]
    [string]$LessonId,
    [int]$LessonIndex = 0,
    [Parameter(Mandatory = $true)]
    [ValidateSet("PASS", "FAIL", "QUARANTINED")]
    [string]$Status,
    [string]$FailureReason = "NONE",
    [string]$QuarantineReason = "NONE",
    [string[]]$ArtifactsCreated = @(),
    [bool]$ContinuedAfterFailure = $false
  )
  $schoolRunRootFull = [System.IO.Path]::GetFullPath($SchoolRunRoot)
  $resultsRoot = Join-Path $schoolRunRootFull "lesson_results"
  if (-not (Test-Path -LiteralPath $resultsRoot)) {
    New-Item -ItemType Directory -Force -Path $resultsRoot | Out-Null
  }
  $safeLessonId = ($LessonId -replace "[^A-Za-z0-9_.-]", "_")
  $fileName = "{0:d3}_{1}_result.json" -f $LessonIndex, $safeLessonId
  $resultPath = Join-Path $resultsRoot $fileName
  $result = [ordered]@{
    result_id = "$LessonId`_RESULT"
    lesson_id = $LessonId
    lesson_index = $LessonIndex
    status = $Status
    failure_reason = $FailureReason
    quarantine_reason = $QuarantineReason
    continued_after_failure = $ContinuedAfterFailure
    artifacts_created = @($ArtifactsCreated)
    accepted_repo_mutated = $false
    protected_state_mutated = $false
    commit_performed = $false
    push_performed = $false
    branch_switch_performed = $false
    written_at = (Get-Date).ToUniversalTime().ToString("o")
  }
  Write-Phase161ALessonResultJsonFile -Path $resultPath -Object $result
  return [pscustomobject][ordered]@{
    status = "PASS"
    lesson_result_written = $true
    lesson_id = $LessonId
    lesson_status = $Status
    result_path = $resultPath
  }
}

if (-not [string]::IsNullOrWhiteSpace($SchoolRunRoot) -and -not [string]::IsNullOrWhiteSpace($LessonId)) {
  Write-Phase161ALessonResult -SchoolRunRoot $SchoolRunRoot -LessonId $LessonId -LessonIndex $LessonIndex -Status $Status -FailureReason $FailureReason -QuarantineReason $QuarantineReason -ArtifactsCreated $ArtifactsCreated -ContinuedAfterFailure $ContinuedAfterFailure | ConvertTo-Json -Depth 30
}
