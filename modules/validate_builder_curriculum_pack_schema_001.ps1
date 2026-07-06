param(
  [string]$RepoRoot = "",
  [string]$CurriculumPackPath = ""
)

$ErrorActionPreference = "Stop"

function Resolve-Phase161AValidationRepoRoot {
  param([string]$RepoRoot)
  if (-not [string]::IsNullOrWhiteSpace($RepoRoot)) {
    return [System.IO.Path]::GetFullPath($RepoRoot)
  }
  return [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
}

function Resolve-Phase161AValidationPath {
  param([string]$RepoRoot, [string]$Path)
  if ([System.IO.Path]::IsPathRooted($Path)) {
    return [System.IO.Path]::GetFullPath($Path)
  }
  return [System.IO.Path]::GetFullPath((Join-Path $RepoRoot $Path))
}

function Test-Phase161AHasProperty {
  param([object]$Object, [string]$Name)
  return ($null -ne $Object -and $Object.PSObject.Properties.Name -contains $Name)
}

function Add-Phase161AValidationError {
  param(
    [System.Collections.ArrayList]$Errors,
    [string]$Message
  )
  [void]$Errors.Add($Message)
}

function Test-Phase161ACurriculumPack {
  param(
    [string]$RepoRoot = "",
    [Parameter(Mandatory = $true)]
    [string]$CurriculumPackPath
  )
  $resolvedRepoRoot = Resolve-Phase161AValidationRepoRoot -RepoRoot $RepoRoot
  $packPath = Resolve-Phase161AValidationPath -RepoRoot $resolvedRepoRoot -Path $CurriculumPackPath
  $errors = [System.Collections.ArrayList]::new()
  $schemaPath = Join-Path $resolvedRepoRoot "schemas/builder_school_curriculum_pack.schema.json"
  $lessonSchemaPath = Join-Path $resolvedRepoRoot "schemas/builder_school_lesson.schema.json"
  if (-not (Test-Path -LiteralPath $schemaPath)) {
    Add-Phase161AValidationError -Errors $errors -Message "CURRICULUM_SCHEMA_MISSING"
  }
  if (-not (Test-Path -LiteralPath $lessonSchemaPath)) {
    Add-Phase161AValidationError -Errors $errors -Message "LESSON_SCHEMA_MISSING"
  }
  if (-not (Test-Path -LiteralPath $packPath)) {
    Add-Phase161AValidationError -Errors $errors -Message "CURRICULUM_PACK_MISSING=$CurriculumPackPath"
    return [pscustomobject][ordered]@{
      status = "FAIL"
      curriculum_pack_path = $CurriculumPackPath
      curriculum_ingest_pass = $false
      errors = @($errors)
    }
  }
  $pack = $null
  try {
    $pack = Get-Content -LiteralPath $packPath -Raw | ConvertFrom-Json
  } catch {
    Add-Phase161AValidationError -Errors $errors -Message "CURRICULUM_PACK_JSON_INVALID"
  }
  if ($null -ne $pack) {
    foreach ($required in @("curriculum_id", "curriculum_version", "pack_type", "active_line", "active_mode", "route_lock_required", "route_step_id", "safety_rules", "lessons")) {
      if (-not (Test-Phase161AHasProperty -Object $pack -Name $required)) {
        Add-Phase161AValidationError -Errors $errors -Message "CURRICULUM_REQUIRED_FIELD_MISSING=$required"
      }
    }
    if ((Test-Phase161AHasProperty -Object $pack -Name "pack_type") -and ([string]$pack.pack_type -ne "BUILDER_SCHOOL_CURRICULUM_PACK")) {
      Add-Phase161AValidationError -Errors $errors -Message "CURRICULUM_PACK_TYPE_UNSUPPORTED=$($pack.pack_type)"
    }
    if ((Test-Phase161AHasProperty -Object $pack -Name "active_line") -and ([string]$pack.active_line -notin @("AGENT_BUILDER_SELF_DEVELOPMENT", "AGENT_BUILDER_EXTERNAL_AGENT_PRODUCTION"))) {
      Add-Phase161AValidationError -Errors $errors -Message "CURRICULUM_ACTIVE_LINE_UNSUPPORTED=$($pack.active_line)"
    }
    if ((Test-Phase161AHasProperty -Object $pack -Name "active_mode") -and ([string]$pack.active_mode -notin @("SELF_BUILD", "BUILD_EXTERNAL_AGENT", "VERIFY"))) {
      Add-Phase161AValidationError -Errors $errors -Message "CURRICULUM_ACTIVE_MODE_UNSUPPORTED=$($pack.active_mode)"
    }
    $safety = if (Test-Phase161AHasProperty -Object $pack -Name "safety_rules") { $pack.safety_rules } else { $null }
    if ($null -eq $safety) {
      Add-Phase161AValidationError -Errors $errors -Message "CURRICULUM_SAFETY_RULES_MISSING"
    } else {
      $expectedSafety = [ordered]@{
        accepted_repo_mutation_allowed = $false
        protected_state_mutation_allowed = $false
        repo_commit_allowed = $false
        repo_push_allowed = $false
        branch_switch_allowed = $false
        runtime_session_only = $true
      }
      foreach ($key in $expectedSafety.Keys) {
        if (-not (Test-Phase161AHasProperty -Object $safety -Name $key)) {
          Add-Phase161AValidationError -Errors $errors -Message "CURRICULUM_SAFETY_FIELD_MISSING=$key"
        } elseif ([bool]$safety.$key -ne [bool]$expectedSafety[$key]) {
          Add-Phase161AValidationError -Errors $errors -Message "CURRICULUM_SAFETY_FIELD_UNSAFE=$key"
        }
      }
    }
    $lessons = @()
    if (Test-Phase161AHasProperty -Object $pack -Name "lessons") {
      $lessons = @($pack.lessons)
    }
    if ($lessons.Count -lt 1) {
      Add-Phase161AValidationError -Errors $errors -Message "CURRICULUM_LESSONS_EMPTY"
    }
    $lessonIds = @{}
    for ($i = 0; $i -lt $lessons.Count; $i += 1) {
      $lesson = $lessons[$i]
      foreach ($required in @("lesson_id", "title", "objective", "expected_outputs", "allowed_actions", "failure_policy")) {
        if (-not (Test-Phase161AHasProperty -Object $lesson -Name $required)) {
          Add-Phase161AValidationError -Errors $errors -Message "LESSON_$($i + 1)_FIELD_MISSING=$required"
        }
      }
      if (Test-Phase161AHasProperty -Object $lesson -Name "lesson_id") {
        $lessonId = [string]$lesson.lesson_id
        if ([string]::IsNullOrWhiteSpace($lessonId)) {
          Add-Phase161AValidationError -Errors $errors -Message "LESSON_$($i + 1)_ID_EMPTY"
        } elseif ($lessonIds.ContainsKey($lessonId)) {
          Add-Phase161AValidationError -Errors $errors -Message "LESSON_DUPLICATE_ID=$lessonId"
        } else {
          $lessonIds[$lessonId] = $true
        }
      }
      if ((Test-Phase161AHasProperty -Object $lesson -Name "expected_outputs") -and (@($lesson.expected_outputs).Count -lt 1)) {
        Add-Phase161AValidationError -Errors $errors -Message "LESSON_$($i + 1)_EXPECTED_OUTPUTS_EMPTY"
      }
      if (Test-Phase161AHasProperty -Object $lesson -Name "failure_policy") {
        $failurePolicy = $lesson.failure_policy
        if (-not (Test-Phase161AHasProperty -Object $failurePolicy -Name "continue_batch") -or -not [bool]$failurePolicy.continue_batch) {
          Add-Phase161AValidationError -Errors $errors -Message "LESSON_$($i + 1)_DOES_NOT_CONTINUE_BATCH"
        }
        if (-not (Test-Phase161AHasProperty -Object $failurePolicy -Name "quarantine_on_safety_violation") -or -not [bool]$failurePolicy.quarantine_on_safety_violation) {
          Add-Phase161AValidationError -Errors $errors -Message "LESSON_$($i + 1)_DOES_NOT_QUARANTINE_SAFETY"
        }
      }
    }
  }
  $status = if ($errors.Count -eq 0) { "PASS" } else { "FAIL" }
  return [pscustomobject][ordered]@{
    status = $status
    curriculum_pack_path = $CurriculumPackPath
    curriculum_ingest_pass = ($status -eq "PASS")
    curriculum_id = if ($null -ne $pack -and (Test-Phase161AHasProperty -Object $pack -Name "curriculum_id")) { [string]$pack.curriculum_id } else { "NONE" }
    route_step_id = if ($null -ne $pack -and (Test-Phase161AHasProperty -Object $pack -Name "route_step_id")) { [string]$pack.route_step_id } else { "NONE" }
    lesson_count = if ($null -ne $pack -and (Test-Phase161AHasProperty -Object $pack -Name "lessons")) { @($pack.lessons).Count } else { 0 }
    accepted_repo_mutation_allowed = if ($null -ne $pack -and (Test-Phase161AHasProperty -Object $pack -Name "safety_rules") -and (Test-Phase161AHasProperty -Object $pack.safety_rules -Name "accepted_repo_mutation_allowed")) { [bool]$pack.safety_rules.accepted_repo_mutation_allowed } else { $true }
    protected_state_mutation_allowed = if ($null -ne $pack -and (Test-Phase161AHasProperty -Object $pack -Name "safety_rules") -and (Test-Phase161AHasProperty -Object $pack.safety_rules -Name "protected_state_mutation_allowed")) { [bool]$pack.safety_rules.protected_state_mutation_allowed } else { $true }
    errors = @($errors)
    validated_at = (Get-Date).ToUniversalTime().ToString("o")
  }
}

if (-not [string]::IsNullOrWhiteSpace($CurriculumPackPath)) {
  Test-Phase161ACurriculumPack -RepoRoot $RepoRoot -CurriculumPackPath $CurriculumPackPath | ConvertTo-Json -Depth 30
}
