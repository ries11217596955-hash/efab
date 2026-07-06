param(
  [string]$RepoRoot = "",
  [string]$CurriculumPackPath = "",
  [string]$OutputPath = ""
)

$ErrorActionPreference = "Stop"
$Phase161ANormalizeSavedRepoRoot = $RepoRoot
$Phase161ANormalizeSavedCurriculumPackPath = $CurriculumPackPath
$Phase161ANormalizeSavedOutputPath = $OutputPath
. (Join-Path $PSScriptRoot "validate_builder_curriculum_pack_schema_001.ps1")
$RepoRoot = $Phase161ANormalizeSavedRepoRoot
$CurriculumPackPath = $Phase161ANormalizeSavedCurriculumPackPath
$OutputPath = $Phase161ANormalizeSavedOutputPath
Remove-Variable -Name Phase161ANormalizeSavedRepoRoot,Phase161ANormalizeSavedCurriculumPackPath,Phase161ANormalizeSavedOutputPath -ErrorAction SilentlyContinue

function Resolve-Phase161ANormalizeRepoRoot {
  param([string]$RepoRoot)
  if (-not [string]::IsNullOrWhiteSpace($RepoRoot)) {
    return [System.IO.Path]::GetFullPath($RepoRoot)
  }
  return [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
}

function Resolve-Phase161ANormalizePath {
  param([string]$RepoRoot, [string]$Path)
  if ([System.IO.Path]::IsPathRooted($Path)) {
    return [System.IO.Path]::GetFullPath($Path)
  }
  return [System.IO.Path]::GetFullPath((Join-Path $RepoRoot $Path))
}

function Write-Phase161ANormalizeJsonFile {
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

function ConvertTo-Phase161ANormalizedLessonBatch {
  param(
    [string]$RepoRoot = "",
    [Parameter(Mandatory = $true)]
    [string]$CurriculumPackPath,
    [string]$OutputPath = ""
  )
  $resolvedRepoRoot = Resolve-Phase161ANormalizeRepoRoot -RepoRoot $RepoRoot
  $validation = Test-Phase161ACurriculumPack -RepoRoot $resolvedRepoRoot -CurriculumPackPath $CurriculumPackPath
  if ([string]$validation.status -ne "PASS") {
    throw "PHASE161A_CURRICULUM_PACK_INVALID=$(@($validation.errors) -join ';')"
  }
  $packPath = Resolve-Phase161ANormalizePath -RepoRoot $resolvedRepoRoot -Path $CurriculumPackPath
  $pack = Get-Content -LiteralPath $packPath -Raw | ConvertFrom-Json
  $lessons = @()
  $index = 0
  foreach ($lesson in @($pack.lessons)) {
    $index += 1
    $lessons += [ordered]@{
      lesson_index = $index
      lesson_id = [string]$lesson.lesson_id
      title = [string]$lesson.title
      objective = [string]$lesson.objective
      inputs = @($lesson.inputs | ForEach-Object { [string]$_ })
      expected_outputs = @($lesson.expected_outputs | ForEach-Object { [string]$_ })
      allowed_actions = @($lesson.allowed_actions | ForEach-Object { [string]$_ })
      failure_policy = $lesson.failure_policy
      validator_expectations = if ($lesson.PSObject.Properties.Name -contains "validator_expectations") { $lesson.validator_expectations } else { [ordered]@{} }
      normalized_status = "PENDING"
    }
  }
  $batch = [ordered]@{
    status = "PASS"
    batch_id = "$($pack.curriculum_id)_NORMALIZED_BATCH"
    curriculum_id = [string]$pack.curriculum_id
    curriculum_version = [string]$pack.curriculum_version
    pack_type = [string]$pack.pack_type
    active_line = [string]$pack.active_line
    active_mode = [string]$pack.active_mode
    route_lock_required = [bool]$pack.route_lock_required
    route_lock_stamp = if ($pack.PSObject.Properties.Name -contains "route_lock_stamp") { [string]$pack.route_lock_stamp } else { "NONE" }
    route_step_id = [string]$pack.route_step_id
    lesson_total_count = $lessons.Count
    lessons = @($lessons)
    normalized_at = (Get-Date).ToUniversalTime().ToString("o")
  }
  if (-not [string]::IsNullOrWhiteSpace($OutputPath)) {
    $outputFullPath = Resolve-Phase161ANormalizePath -RepoRoot $resolvedRepoRoot -Path $OutputPath
    Write-Phase161ANormalizeJsonFile -Path $outputFullPath -Object $batch
  }
  return [pscustomobject]$batch
}

if (-not [string]::IsNullOrWhiteSpace($CurriculumPackPath)) {
  ConvertTo-Phase161ANormalizedLessonBatch -RepoRoot $RepoRoot -CurriculumPackPath $CurriculumPackPath -OutputPath $OutputPath | ConvertTo-Json -Depth 50
}
