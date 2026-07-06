[CmdletBinding()]
param(
  [ValidateSet("Auto", "Seed", "Completed")]
  [string]$Stage = "Auto",
  [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
)

$ErrorActionPreference = "Stop"

$TaskId = "TASK_REPAIR_LOOP_GENERATOR_V1_001"
$PackId = "PHASE103_REPAIR_LOOP_GENERATOR_V1"
$EntryScript = "packs/PHASE103_REPAIR_LOOP_GENERATOR_V1/APPLY.ps1"
$NextAllowedStep = "PHASE104_CONTROLLED_MULTI_CYCLE_SELF_BUILD_RUN_V1"
$SchemaPath = "contracts/self_development/repair_loop_generator_v1.schema.json"
$RepairLoopGeneratorPath = "self_build_batch/repair_loop/REPAIR_LOOP_GENERATOR_V1.json"
$DryRunProgramBundlePath = "self_build_batch/repair_loop/BATCH_PLAN_EXAMPLE_V1_REPAIR_LOOP_PROGRAMS_DRY_RUN.json"
$ReportPath = "reports/self_development/REPAIR_LOOP_GENERATOR_V1_REPORT.json"
$ProofPath = "proofs/self_development/REPAIR_LOOP_GENERATOR_V1.json"
$script:Failures = @()

function Join-RepoPath {
  param([string]$Path)

  if ([System.IO.Path]::IsPathRooted($Path)) {
    return [System.IO.Path]::GetFullPath($Path)
  }
  return [System.IO.Path]::GetFullPath((Join-Path $RepoRoot $Path))
}

function Add-Failure {
  param([string]$Message)
  $script:Failures += $Message
}

function Read-JsonFile {
  param([string]$Path)

  $fullPath = Join-RepoPath $Path
  if (-not (Test-Path -LiteralPath $fullPath)) {
    Add-Failure "MISSING_JSON=$Path"
    return $null
  }
  try {
    return (Get-Content -LiteralPath $fullPath -Raw | ConvertFrom-Json)
  } catch {
    Add-Failure "INVALID_JSON=$Path :: $($_.Exception.Message)"
    return $null
  }
}

function Get-PropertyInfo {
  param(
    [object]$Object,
    [string]$Name
  )

  if ($null -eq $Object) {
    return $null
  }
  return $Object.PSObject.Properties | Where-Object { $_.Name -ieq $Name } | Select-Object -First 1
}

function Get-PropertyValue {
  param(
    [object]$Object,
    [string]$Name
  )

  $property = Get-PropertyInfo -Object $Object -Name $Name
  if ($null -eq $property) {
    return $null
  }
  return $property.Value
}

function As-Array {
  param([object]$Value)

  if ($null -eq $Value) {
    return @()
  }
  if ($Value -is [System.Array]) {
    return $Value
  }
  return @($Value)
}

function Get-SafeCount {
  param([object]$Value)

  return @($Value).Count
}

function Assert-FileExists {
  param([string]$Path)

  if (-not (Test-Path -LiteralPath (Join-RepoPath $Path))) {
    Add-Failure "MISSING_FILE=$Path"
  }
}

function Assert-FileAbsent {
  param([string]$Path)

  if (Test-Path -LiteralPath (Join-RepoPath $Path)) {
    Add-Failure "UNEXPECTED_FILE=$Path"
  }
}

function Assert-ParserPass {
  param([string]$Path)

  $fullPath = Join-RepoPath $Path
  if (-not (Test-Path -LiteralPath $fullPath)) {
    Add-Failure "MISSING_SCRIPT=$Path"
    return
  }
  $tokens = $null
  $errors = $null
  [System.Management.Automation.Language.Parser]::ParseFile($fullPath, [ref]$tokens, [ref]$errors) | Out-Null
  if ((Get-SafeCount -Value $errors) -gt 0) {
    Add-Failure "POWERSHELL_PARSE_FAIL=$Path"
  }
}

function Assert-CountAtLeast {
  param(
    [object]$Object,
    [string]$Name,
    [int]$Minimum
  )

  $value = Get-PropertyValue -Object $Object -Name $Name
  if ($null -eq $value) {
    Add-Failure "COUNT_FIELD_MISSING=$Name"
    return
  }
  try {
    $countValue = [int]$value
  } catch {
    Add-Failure "COUNT_FIELD_NOT_INTEGER=$Name"
    return
  }
  if ($countValue -lt $Minimum) {
    Add-Failure "$($Name.ToUpperInvariant())_LT_$Minimum"
  }
}

function Find-TaskEntry {
  param([object]$Queue)

  foreach ($task in As-Array (Get-PropertyValue -Object $Queue -Name "tasks")) {
    if ("$(Get-PropertyValue -Object $task -Name "task_id")" -eq $TaskId) {
      return $task
    }
  }
  return $null
}

function Get-MatchingRegistryPacks {
  param([object]$Registry)

  return @(
    As-Array (Get-PropertyValue -Object $Registry -Name "packs") |
      Where-Object { "$(Get-PropertyValue -Object $_ -Name "task_id")" -eq $TaskId }
  )
}

function Resolve-Stage {
  param([string]$RequestedStage)

  if ($RequestedStage -ne "Auto") {
    return $RequestedStage
  }
  $queue = Read-JsonFile "TASK_QUEUE.json"
  if ("$(Get-PropertyValue -Object $queue -Name "active_task_id")" -eq $TaskId) {
    return "Seed"
  }
  return "Completed"
}

$Stage = Resolve-Stage -RequestedStage $Stage
Write-Host "VALIDATION_STAGE=$Stage"

foreach ($marker in @("CAPABILITY_ROADMAP.json", "GENESIS_STATE.json", "TASK_QUEUE.json", "packs/registry.json", "orchestrator/run.ps1")) {
  Assert-FileExists $marker
}

foreach ($path in @(
  "modules/self_development/write_repair_loop_generator_v1.ps1",
  "packs/PHASE103_REPAIR_LOOP_GENERATOR_V1/PACK.json",
  "packs/PHASE103_REPAIR_LOOP_GENERATOR_V1/APPLY.ps1",
  "packs/PHASE103_REPAIR_LOOP_GENERATOR_V1/VALIDATE.ps1",
  "tasks/TASK_REPAIR_LOOP_GENERATOR_V1_001.json"
)) {
  Assert-FileExists $path
}

foreach ($path in @(
  "packs/PHASE103_REPAIR_LOOP_GENERATOR_V1/PACK.json",
  "tasks/TASK_REPAIR_LOOP_GENERATOR_V1_001.json",
  "TASK_QUEUE.json",
  "packs/registry.json",
  "CAPABILITY_ROADMAP.json",
  "GENESIS_STATE.json"
)) {
  Read-JsonFile $path | Out-Null
}

foreach ($script in @(
  "modules/self_development/write_repair_loop_generator_v1.ps1",
  "packs/PHASE103_REPAIR_LOOP_GENERATOR_V1/APPLY.ps1",
  "packs/PHASE103_REPAIR_LOOP_GENERATOR_V1/VALIDATE.ps1"
)) {
  Assert-ParserPass $script
}

$phase102Proof = Read-JsonFile "proofs/self_development/AUTO_NEXT_GAP_DECISION_V1.json"
if ($null -ne $phase102Proof) {
  if ("$(Get-PropertyValue -Object $phase102Proof -Name "status")" -ne "PASS") {
    Add-Failure "PHASE102_PROOF_STATUS_NOT_PASS"
  }
  if ("$(Get-PropertyValue -Object $phase102Proof -Name "next_allowed_step")" -ne "PHASE103_REPAIR_LOOP_GENERATOR_V1") {
    Add-Failure "PHASE102_PROOF_NEXT_STEP_MISMATCH"
  }
}

$phase102ActionPlan = Read-JsonFile "self_build_batch/next_actions/BATCH_PLAN_EXAMPLE_V1_NEXT_ACTION_PLAN_DRY_RUN.json"
if ($null -ne $phase102ActionPlan) {
  if (-not [bool](Get-PropertyValue -Object $phase102ActionPlan -Name "self_resolution_first")) {
    Add-Failure "PHASE102_ACTION_PLAN_SELF_RESOLUTION_FIRST_NOT_TRUE"
  }
  if (-not [bool](Get-PropertyValue -Object $phase102ActionPlan -Name "program_generation_required_next")) {
    Add-Failure "PHASE102_ACTION_PLAN_PROGRAM_GENERATION_REQUIRED_NEXT_NOT_TRUE"
  }
}

$queue = Read-JsonFile "TASK_QUEUE.json"
$registry = Read-JsonFile "packs/registry.json"
$task = Find-TaskEntry -Queue $queue
if ($null -eq $task) {
  Add-Failure "TASK_NOT_FOUND=$TaskId"
}
$selectedPacks = Get-MatchingRegistryPacks -Registry $registry
if ((Get-SafeCount -Value $selectedPacks) -ne 1) {
  Add-Failure "REGISTRY_SELECTED_PACK_COUNT=$(Get-SafeCount -Value $selectedPacks)"
} else {
  $selected = $selectedPacks[0]
  if ("$(Get-PropertyValue -Object $selected -Name "pack_id")" -ne $PackId) {
    Add-Failure "REGISTRY_SELECTED_PACK_ID_MISMATCH"
  }
  if ("$(Get-PropertyValue -Object $selected -Name "shell")" -ne "PowerShell") {
    Add-Failure "REGISTRY_SELECTED_SHELL_MISMATCH"
  }
  if ("$(Get-PropertyValue -Object $selected -Name "entry_script")" -ne $EntryScript) {
    Add-Failure "REGISTRY_SELECTED_ENTRY_SCRIPT_MISMATCH"
  }
}

if ($Stage -eq "Seed") {
  if ("$(Get-PropertyValue -Object $queue -Name "active_task_id")" -ne $TaskId) {
    $activeTaskId = Get-PropertyValue -Object $queue -Name "active_task_id"
    Add-Failure "SEED_ACTIVE_TASK_MISMATCH=$activeTaskId"
  }
  if ($null -ne $task -and "$(Get-PropertyValue -Object $task -Name "status")" -ne "READY") {
    Add-Failure "SEED_TASK_STATUS_NOT_READY"
  }
  foreach ($path in @(
    $SchemaPath,
    $RepairLoopGeneratorPath,
    $DryRunProgramBundlePath,
    $ReportPath,
    $ProofPath,
    "packs/PHASE104_CONTROLLED_MULTI_CYCLE_SELF_BUILD_RUN_V1",
    "tasks/TASK_CONTROLLED_MULTI_CYCLE_SELF_BUILD_RUN_V1_001.json",
    "proofs/self_development/CONTROLLED_MULTI_CYCLE_SELF_BUILD_RUN_V1.json",
    "reports/self_development/CONTROLLED_MULTI_CYCLE_SELF_BUILD_RUN_V1_REPORT.json"
  )) {
    Assert-FileAbsent $path
  }
}

if ($Stage -eq "Completed") {
  $schema = Read-JsonFile $SchemaPath
  $generator = Read-JsonFile $RepairLoopGeneratorPath
  $bundle = Read-JsonFile $DryRunProgramBundlePath
  $report = Read-JsonFile $ReportPath
  $proof = Read-JsonFile $ProofPath

  if ($null -ne $schema) {
    $required = As-Array (Get-PropertyValue -Object $schema -Name "required")
    foreach ($field in @(
      "repair_loop_generator_id",
      "version",
      "status",
      "active_line",
      "input_sources",
      "generator_policy",
      "program_bundle_contract",
      "program_types",
      "execution_allowed",
      "next_allowed_step"
    )) {
      if ($required -notcontains $field) {
        Add-Failure "SCHEMA_REQUIRED_FIELD_MISSING=$field"
      }
    }
  }

  if ($null -ne $generator) {
    if ("$(Get-PropertyValue -Object $generator -Name "status")" -ne "ACTIVE_REPAIR_LOOP_GENERATOR") {
      Add-Failure "GENERATOR_STATUS_NOT_ACTIVE"
    }
    if ([bool](Get-PropertyValue -Object $generator -Name "execution_allowed")) {
      Add-Failure "GENERATOR_EXECUTION_ALLOWED_TRUE"
    }
  }

  if ($null -ne $bundle) {
    if ("$(Get-PropertyValue -Object $bundle -Name "status")" -ne "DRY_RUN_PROGRAM_BUNDLE_READY") {
      Add-Failure "PROGRAM_BUNDLE_STATUS_NOT_READY"
    }
    foreach ($trueField in @("self_resolution_first", "assistance_is_fallback", "program_generation_performed", "admission_required_before_execution")) {
      if (-not [bool](Get-PropertyValue -Object $bundle -Name $trueField)) {
        Add-Failure "PROGRAM_BUNDLE_$($trueField.ToUpperInvariant())_NOT_TRUE"
      }
    }
    foreach ($falseField in @("execution_performed", "execution_allowed")) {
      if ([bool](Get-PropertyValue -Object $bundle -Name $falseField)) {
        Add-Failure "PROGRAM_BUNDLE_$($falseField.ToUpperInvariant())_TRUE"
      }
    }
    Assert-CountAtLeast -Object $bundle -Name "program_count" -Minimum 4
    Assert-CountAtLeast -Object $bundle -Name "self_build_program_count" -Minimum 1
    Assert-CountAtLeast -Object $bundle -Name "material_acquisition_program_count" -Minimum 1
    Assert-CountAtLeast -Object $bundle -Name "safe_patch_program_count" -Minimum 1
    Assert-CountAtLeast -Object $bundle -Name "resume_plan_count" -Minimum 1
    if ([string]::IsNullOrWhiteSpace("$(Get-PropertyValue -Object $bundle -Name "selected_program_for_next_cycle")")) {
      Add-Failure "SELECTED_PROGRAM_FOR_NEXT_CYCLE_MISSING"
    }
    $programs = @(As-Array (Get-PropertyValue -Object $bundle -Name "programs"))
    $programTypes = @($programs | ForEach-Object { "$(Get-PropertyValue -Object $_ -Name "program_type")" })
    foreach ($requiredType in @("SELF_BUILD_REQUIRED_MODULES_PROGRAM", "MATERIAL_ACQUISITION_UNDER_POLICY_PROGRAM", "SAFE_LOCAL_PATCH_PROGRAM", "RESUME_AFTER_SELF_REPAIR_PLAN")) {
      if ($programTypes -notcontains $requiredType) {
        Add-Failure "PROGRAM_TYPE_MISSING=$requiredType"
      }
    }
    foreach ($program in $programs) {
      $programId = "$(Get-PropertyValue -Object $program -Name "program_id")"
      if ([bool](Get-PropertyValue -Object $program -Name "execution_allowed_now")) {
        Add-Failure "PROGRAM_EXECUTION_ALLOWED_NOW_TRUE=$programId"
      }
      foreach ($arrayField in @("proof_requirements", "validation_requirements", "allowed_scope", "blocked_scope")) {
        if ((Get-SafeCount -Value @(As-Array (Get-PropertyValue -Object $program -Name $arrayField))) -lt 1) {
          Add-Failure "PROGRAM_$($arrayField.ToUpperInvariant())_MISSING=$programId"
        }
      }
      if ("$(Get-PropertyValue -Object $program -Name "program_type")" -eq "MATERIAL_ACQUISITION_UNDER_POLICY_PROGRAM") {
        $proofRequirementsText = ((As-Array (Get-PropertyValue -Object $program -Name "proof_requirements")) -join " ").ToLowerInvariant()
        foreach ($term in @("provenance", "license", "risk", "quarantine", "wrapper", "test", "proof")) {
          if (-not $proofRequirementsText.Contains($term)) {
            Add-Failure "MATERIAL_PROGRAM_REQUIREMENT_MISSING=$term"
          }
        }
      }
    }
  }

  if ($null -ne $report -and "$(Get-PropertyValue -Object $report -Name "status")" -ne "PASS") {
    Add-Failure "REPORT_STATUS_NOT_PASS"
  }

  if ($null -ne $proof) {
    if ("$(Get-PropertyValue -Object $proof -Name "status")" -ne "PASS") {
      Add-Failure "PROOF_STATUS_NOT_PASS"
    }
    if ("$(Get-PropertyValue -Object $proof -Name "phase")" -ne "PHASE103_REPAIR_LOOP_GENERATOR_V1") {
      Add-Failure "PROOF_PHASE_MISMATCH"
    }
    if ("$(Get-PropertyValue -Object $proof -Name "task_id")" -ne $TaskId) {
      Add-Failure "PROOF_TASK_ID_MISMATCH"
    }
    if ("$(Get-PropertyValue -Object $proof -Name "runtime_mode")" -ne "SELF_BUILD") {
      Add-Failure "PROOF_RUNTIME_MODE_MISMATCH"
    }
    foreach ($field in @(
      "repair_loop_generator_created",
      "schema_created",
      "dry_run_program_bundle_created",
      "self_resolution_first",
      "assistance_is_fallback",
      "program_generation_performed",
      "admission_required_before_execution",
      "phase104_required_next",
      "no_external_agent_production",
      "no_external_install",
      "no_external_fetch",
      "phase104_not_executed",
      "queue_returned_to_none"
    )) {
      if (-not [bool](Get-PropertyValue -Object $proof -Name $field)) {
        Add-Failure "PROOF_$($field.ToUpperInvariant())_NOT_TRUE"
      }
    }
    foreach ($falseField in @("execution_performed", "execution_allowed")) {
      if ([bool](Get-PropertyValue -Object $proof -Name $falseField)) {
        Add-Failure "PROOF_$($falseField.ToUpperInvariant())_TRUE"
      }
    }
    if ("$(Get-PropertyValue -Object $proof -Name "next_allowed_step")" -ne $NextAllowedStep) {
      Add-Failure "PROOF_NEXT_ALLOWED_STEP_MISMATCH"
    }
  }

  if ("$(Get-PropertyValue -Object $queue -Name "active_task_id")" -ne "NONE") {
    Add-Failure "COMPLETED_QUEUE_NOT_NONE"
  }
  if ($null -ne $task -and "$(Get-PropertyValue -Object $task -Name "status")" -ne "COMPLETED") {
    Add-Failure "COMPLETED_TASK_STATUS_NOT_COMPLETED"
  }
}

if ((Get-SafeCount -Value $script:Failures) -gt 0) {
  foreach ($failure in $script:Failures) {
    Write-Host "FAIL=$failure"
  }
  Write-Host "VALIDATION_RESULT=FAIL"
  throw "PHASE103_VALIDATION_FAILED"
}

if ($Stage -eq "Seed") {
  Write-Host "VALIDATION_RESULT=PASS_SEED"
} else {
  Write-Host "VALIDATION_RESULT=PASS"
}
