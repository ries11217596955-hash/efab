param(
  [string]$RepoRoot = "",
  [Parameter(Mandatory = $true)]
  [string]$CurriculumPackPath,
  [string]$SchoolRunId = ""
)

$ErrorActionPreference = "Stop"
$Phase161AIngestSavedRepoRoot = $RepoRoot
$Phase161AIngestSavedCurriculumPackPath = $CurriculumPackPath
$Phase161AIngestSavedSchoolRunId = $SchoolRunId
. (Join-Path $PSScriptRoot "validate_builder_curriculum_pack_schema_001.ps1")
$RepoRoot = $Phase161AIngestSavedRepoRoot
$CurriculumPackPath = $Phase161AIngestSavedCurriculumPackPath
$SchoolRunId = $Phase161AIngestSavedSchoolRunId
. (Join-Path $PSScriptRoot "normalize_builder_lesson_batch_001.ps1")
$RepoRoot = $Phase161AIngestSavedRepoRoot
$CurriculumPackPath = $Phase161AIngestSavedCurriculumPackPath
$SchoolRunId = $Phase161AIngestSavedSchoolRunId
. (Join-Path $PSScriptRoot "inspect_builder_school_entry_state_001.ps1")
$RepoRoot = $Phase161AIngestSavedRepoRoot
$CurriculumPackPath = $Phase161AIngestSavedCurriculumPackPath
$SchoolRunId = $Phase161AIngestSavedSchoolRunId
Remove-Variable -Name Phase161AIngestSavedRepoRoot,Phase161AIngestSavedCurriculumPackPath,Phase161AIngestSavedSchoolRunId -ErrorAction SilentlyContinue

function Resolve-Phase161AIngestRepoRoot {
  param([string]$RepoRoot)
  if (-not [string]::IsNullOrWhiteSpace($RepoRoot)) {
    return [System.IO.Path]::GetFullPath($RepoRoot)
  }
  return [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
}

function Resolve-Phase161AIngestPath {
  param([string]$RepoRoot, [string]$Path)
  if ([System.IO.Path]::IsPathRooted($Path)) {
    return [System.IO.Path]::GetFullPath($Path)
  }
  return [System.IO.Path]::GetFullPath((Join-Path $RepoRoot $Path))
}

function ConvertTo-Phase161AIngestRelativePath {
  param([string]$RepoRoot, [string]$FullPath)
  $root = [System.IO.Path]::GetFullPath($RepoRoot).TrimEnd([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar)
  $path = [System.IO.Path]::GetFullPath($FullPath).TrimEnd([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar)
  if ($path -eq $root) {
    return "."
  }
  if (-not $path.StartsWith($root + [System.IO.Path]::DirectorySeparatorChar, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw "PHASE161A_INGEST_PATH_OUTSIDE_REPO=$FullPath"
  }
  return ($path.Substring($root.Length + 1) -replace "\\", "/")
}

function Write-Phase161AIngestJsonFile {
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

function Invoke-Phase161ACurriculumPackIngest {
  param(
    [string]$RepoRoot = "",
    [Parameter(Mandatory = $true)]
    [string]$CurriculumPackPath,
    [string]$SchoolRunId = ""
  )
  $resolvedRepoRoot = Resolve-Phase161AIngestRepoRoot -RepoRoot $RepoRoot
  $validation = Test-Phase161ACurriculumPack -RepoRoot $resolvedRepoRoot -CurriculumPackPath $CurriculumPackPath
  if ([string]$validation.status -ne "PASS") {
    throw "PHASE161A_CURRICULUM_INGEST_BLOCKED=$(@($validation.errors) -join ';')"
  }
  if ([string]::IsNullOrWhiteSpace($SchoolRunId)) {
    $SchoolRunId = "PHASE161A_SCHOOL_RUN_{0}" -f ((Get-Date).ToUniversalTime().ToString("yyyyMMddHHmmss"))
  }
  if ($SchoolRunId -match "[\\/:\*\?`"<>|]") {
    throw "PHASE161A_SCHOOL_RUN_ID_MUST_BE_LEAF=$SchoolRunId"
  }
  $schoolRunRoot = Join-Path $resolvedRepoRoot "runtime_sessions/school_runs/$SchoolRunId"
  foreach ($relative in @("", "lesson_results", "lesson_artifacts", "quarantine")) {
    $path = if ([string]::IsNullOrWhiteSpace($relative)) { $schoolRunRoot } else { Join-Path $schoolRunRoot $relative }
    if (-not (Test-Path -LiteralPath $path)) {
      New-Item -ItemType Directory -Force -Path $path | Out-Null
    }
  }
  $packPath = Resolve-Phase161AIngestPath -RepoRoot $resolvedRepoRoot -Path $CurriculumPackPath
  $pack = Get-Content -LiteralPath $packPath -Raw | ConvertFrom-Json
  Write-Phase161AIngestJsonFile -Path (Join-Path $schoolRunRoot "curriculum_pack.json") -Object $pack
  $normalizedPath = Join-Path $schoolRunRoot "normalized_lesson_batch.json"
  $normalized = ConvertTo-Phase161ANormalizedLessonBatch -RepoRoot $resolvedRepoRoot -CurriculumPackPath $packPath -OutputPath $normalizedPath
  $routeState = Get-Phase161ASchoolEntryState -RepoRoot $resolvedRepoRoot
  $head = "UNKNOWN"
  $branch = "UNKNOWN"
  try {
    $head = (git -C $resolvedRepoRoot rev-parse --short HEAD).Trim()
    $branch = (git -C $resolvedRepoRoot branch --show-current).Trim()
  } catch {
    $head = "UNKNOWN"
    $branch = "UNKNOWN"
  }
  $manifest = [ordered]@{
    status = "INGESTED"
    school_run_id = $SchoolRunId
    school_run_root = ConvertTo-Phase161AIngestRelativePath -RepoRoot $resolvedRepoRoot -FullPath $schoolRunRoot
    curriculum_id = [string]$pack.curriculum_id
    curriculum_version = [string]$pack.curriculum_version
    active_line = [string]$pack.active_line
    active_mode = [string]$pack.active_mode
    route_step_id = [string]$pack.route_step_id
    active_route_lock_stamp = [string]$routeState.active_route_lock_stamp
    active_route_lock_file = [string]$routeState.active_route_lock_file
    branch = $branch
    run_head = $head
    lesson_total_count = [int]$normalized.lesson_total_count
    lesson_pass_count = 0
    lesson_fail_count = 0
    lesson_quarantine_count = 0
    morning_review_written = $false
    run_continues_after_failed_lesson = $false
    quarantine_handled_separately = $false
    accepted_repo_mutation_allowed = $false
    protected_state_mutation_allowed = $false
    accepted_repo_mutated = $false
    protected_state_mutated = $false
    commit_performed = $false
    push_performed = $false
    branch_switch_performed = $false
    ingested_at = (Get-Date).ToUniversalTime().ToString("o")
  }
  Write-Phase161AIngestJsonFile -Path (Join-Path $schoolRunRoot "school_run_manifest.json") -Object $manifest
  return [pscustomobject][ordered]@{
    status = "PASS"
    curriculum_ingest_pass = $true
    school_run_id = $SchoolRunId
    school_run_root = ConvertTo-Phase161AIngestRelativePath -RepoRoot $resolvedRepoRoot -FullPath $schoolRunRoot
    manifest_path = "runtime_sessions/school_runs/$SchoolRunId/school_run_manifest.json"
    normalized_lesson_batch_path = "runtime_sessions/school_runs/$SchoolRunId/normalized_lesson_batch.json"
    lesson_total_count = [int]$normalized.lesson_total_count
    active_route_lock_stamp = [string]$routeState.active_route_lock_stamp
  }
}

if (-not [string]::IsNullOrWhiteSpace($CurriculumPackPath)) {
  Invoke-Phase161ACurriculumPackIngest -RepoRoot $RepoRoot -CurriculumPackPath $CurriculumPackPath -SchoolRunId $SchoolRunId | ConvertTo-Json -Depth 50
}
