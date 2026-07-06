param(
  [string]$CandidateDir = "",
  [string]$CandidateId = "",
  [string]$QualityStatus = "REVISION_REQUIRED",
  [string[]]$FailedChecks = @(),
  [string[]]$FailureReasons = @(),
  [string[]]$RequiredPayloadImprovements = @(),
  [int]$RetryNumber = 0,
  [int]$MaxRetryLimit = 2
)

$ErrorActionPreference = "Stop"

function Normalize-Phase160HRevisionFullPath {
  param([string]$Path)
  return [System.IO.Path]::GetFullPath($Path).TrimEnd([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar)
}

function Resolve-Phase160HRevisionRepoRoot {
  $scriptRootCandidate = $PSScriptRoot
  if ([string]::IsNullOrWhiteSpace($scriptRootCandidate) -and -not [string]::IsNullOrWhiteSpace($PSCommandPath)) {
    $scriptRootCandidate = Split-Path -Path $PSCommandPath -Parent
  }
  if ([string]::IsNullOrWhiteSpace($scriptRootCandidate) -and -not [string]::IsNullOrWhiteSpace($MyInvocation.MyCommand.Path)) {
    $scriptRootCandidate = Split-Path -Path $MyInvocation.MyCommand.Path -Parent
  }
  if ([string]::IsNullOrWhiteSpace($scriptRootCandidate)) {
    throw "PHASE160H_REVISION_SCRIPT_ROOT_UNAVAILABLE"
  }
  return Normalize-Phase160HRevisionFullPath -Path (Join-Path $scriptRootCandidate "..")
}

function Resolve-Phase160HRevisionPath {
  param([string]$RepoRoot, [string]$Path)
  if ([System.IO.Path]::IsPathRooted($Path)) {
    return [System.IO.Path]::GetFullPath($Path)
  }
  return [System.IO.Path]::GetFullPath((Join-Path $RepoRoot $Path))
}

function Assert-Phase160HRevisionPathInsideRepo {
  param([string]$RepoRoot, [string]$FullPath)
  $root = Normalize-Phase160HRevisionFullPath -Path $RepoRoot
  $full = Normalize-Phase160HRevisionFullPath -Path $FullPath
  if (-not ($full -eq $root -or $full.StartsWith($root + [System.IO.Path]::DirectorySeparatorChar, [System.StringComparison]::OrdinalIgnoreCase))) {
    throw "PHASE160H_REVISION_PATH_OUTSIDE_REPO=$FullPath"
  }
  return $full
}

function ConvertTo-Phase160HRevisionRelativePath {
  param([string]$RepoRoot, [string]$FullPath)
  $root = Normalize-Phase160HRevisionFullPath -Path $RepoRoot
  $full = Normalize-Phase160HRevisionFullPath -Path $FullPath
  if ($full -eq $root) {
    return "."
  }
  if (-not $full.StartsWith($root + [System.IO.Path]::DirectorySeparatorChar, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw "PHASE160H_REVISION_PATH_OUTSIDE_REPO=$FullPath"
  }
  return ($full.Substring($root.Length + 1) -replace "\\", "/")
}

function Write-Phase160HRevisionJsonFile {
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

function Write-Phase160HRevisionTextFile {
  param([string]$Path, [string]$Text)
  $directory = Split-Path -Path $Path -Parent
  if ($directory -and -not (Test-Path -LiteralPath $directory)) {
    New-Item -ItemType Directory -Force -Path $directory | Out-Null
  }
  if (-not $Text.EndsWith("`n")) {
    $Text += "`n"
  }
  [System.IO.File]::WriteAllText($Path, $Text, [System.Text.UTF8Encoding]::new($false))
}

function Read-Phase160HRevisionJsonSafe {
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

$RepoRoot = Resolve-Phase160HRevisionRepoRoot
$Pushed = $false

try {
  Push-Location $RepoRoot
  $Pushed = $true

  foreach ($identityFile in @("CAPABILITY_ROADMAP.json", "GENESIS_STATE.json", "TASK_QUEUE.json", "packs/registry.json", "orchestrator/run.ps1")) {
    if (-not (Test-Path -LiteralPath (Resolve-Phase160HRevisionPath -RepoRoot $RepoRoot -Path $identityFile))) {
      throw "STOP=WRONG_AGENT_BUILDER_REPO missing=$identityFile"
    }
  }

  if ([string]::IsNullOrWhiteSpace($CandidateDir)) {
    throw "PHASE160H_REVISION_CANDIDATE_DIR_REQUIRED"
  }
  $CandidateDirFull = Resolve-Phase160HRevisionPath -RepoRoot $RepoRoot -Path $CandidateDir
  $CandidateDirFull = Assert-Phase160HRevisionPathInsideRepo -RepoRoot $RepoRoot -FullPath $CandidateDirFull
  if (-not (Test-Path -LiteralPath $CandidateDirFull)) {
    throw "PHASE160H_REVISION_CANDIDATE_DIR_MISSING=$CandidateDir"
  }
  $CandidateDirRelative = ConvertTo-Phase160HRevisionRelativePath -RepoRoot $RepoRoot -FullPath $CandidateDirFull

  $manifest = Read-Phase160HRevisionJsonSafe -Path (Join-Path $CandidateDirFull "candidate_manifest.json")
  if ([string]::IsNullOrWhiteSpace($CandidateId)) {
    $CandidateId = if ($null -ne $manifest -and $manifest.PSObject.Properties.Name -contains "candidate_id") { [string]$manifest.candidate_id } else { Split-Path -Path $CandidateDirFull -Leaf }
  }
  if ($RetryNumber -lt 0) {
    $RetryNumber = 0
  }
  if ($MaxRetryLimit -lt 0) {
    $MaxRetryLimit = 0
  }

  $failedChecksSafe = @($FailedChecks | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) } | ForEach-Object { [string]$_ } | Select-Object -Unique)
  $failureReasonsSafe = @($FailureReasons | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) } | ForEach-Object { [string]$_ } | Select-Object -Unique)
  $improvementsSafe = @($RequiredPayloadImprovements | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) } | ForEach-Object { [string]$_ } | Select-Object -Unique)
  if ($failedChecksSafe.Count -lt 1) {
    $failedChecksSafe = @("candidate_quality_gate_failed")
  }
  if ($failureReasonsSafe.Count -lt 1) {
    $failureReasonsSafe = @("Candidate did not satisfy the real payload quality gate.")
  }
  if ($improvementsSafe.Count -lt 1) {
    $improvementsSafe = @(
      "Provide a real proposed module payload file under proposed_patch_or_file_payloads.",
      "Provide a real proposed validator payload file under proposed_patch_or_file_payloads.",
      "Ensure proposed payload files parse as PowerShell after materialization.",
      "Do not request commit, push, branch switch, or protected state mutation."
    )
  }

  $revisionRequestPath = Join-Path $CandidateDirFull "revision_request.json"
  $revisionRequestMdPath = Join-Path $CandidateDirFull "revision_request.md"
  $retryLimitReached = $RetryNumber -ge $MaxRetryLimit
  $request = [ordered]@{
    status = "REVISION_REQUIRED"
    quality_status = $QualityStatus
    candidate_id = $CandidateId
    candidate_dir = $CandidateDirRelative
    what_failed = @($failedChecksSafe)
    why_it_failed = @($failureReasonsSafe)
    payloads_or_files_must_be_improved = @($improvementsSafe)
    retry_number = $RetryNumber
    max_retry_limit = $MaxRetryLimit
    retry_limit_reached = $retryLimitReached
    return_to_candidate_generation = $true
    owner_promotion_allowed = $false
    accepted_code_written = $false
    repo_mutation_performed = $false
    commit_performed = $false
    push_performed = $false
    branch_switch_performed = $false
    protected_state_mutated = $false
    created_at = (Get-Date).ToUniversalTime().ToString("o")
  }
  Write-Phase160HRevisionJsonFile -Path $revisionRequestPath -Object $request

  $mdLines = @(
    "# Candidate Revision Request",
    "",
    "candidate_id: $CandidateId",
    "quality_status: $QualityStatus",
    "retry_number: $RetryNumber",
    "max_retry_limit: $MaxRetryLimit",
    "owner_promotion_allowed: false",
    "return_to_candidate_generation: true",
    "",
    "## What Failed"
  )
  foreach ($check in $failedChecksSafe) {
    $mdLines += "- $check"
  }
  $mdLines += @("", "## Why It Failed")
  foreach ($reason in $failureReasonsSafe) {
    $mdLines += "- $reason"
  }
  $mdLines += @("", "## Required Improvements")
  foreach ($improvement in $improvementsSafe) {
    $mdLines += "- $improvement"
  }
  Write-Phase160HRevisionTextFile -Path $revisionRequestMdPath -Text ($mdLines -join "`n")

  [pscustomobject][ordered]@{
    status = "REVISION_REQUIRED"
    quality_status = $QualityStatus
    candidate_id = $CandidateId
    candidate_dir = $CandidateDirRelative
    revision_request_path = ConvertTo-Phase160HRevisionRelativePath -RepoRoot $RepoRoot -FullPath $revisionRequestPath
    revision_request_md_path = ConvertTo-Phase160HRevisionRelativePath -RepoRoot $RepoRoot -FullPath $revisionRequestMdPath
    retry_number = $RetryNumber
    max_retry_limit = $MaxRetryLimit
    retry_limit_reached = $retryLimitReached
    return_to_candidate_generation = $true
    owner_promotion_allowed = $false
  } | ConvertTo-Json -Depth 100
} finally {
  if ($Pushed) {
    Pop-Location
  }
}
