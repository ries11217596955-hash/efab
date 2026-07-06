[CmdletBinding()]
param(
  [ValidateSet("Auto", "Seed", "Completed")]
  [string]$Stage = "Auto",
  [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
)

$ErrorActionPreference = "Stop"

$TaskId = "TASK_BATCH_ADMISSION_POLICY_V1_001"
$PackId = "PHASE97_BATCH_ADMISSION_POLICY_V1"
$EntryScript = "packs/PHASE97_BATCH_ADMISSION_POLICY_V1/APPLY.ps1"
$NextAllowedStep = "PHASE98_ITEM_LEVEL_EXECUTION_LEDGER_V1"
$SchemaPath = "contracts/self_development/batch_admission_policy_v1.schema.json"
$PolicyPath = "self_build_batch/admission/BATCH_ADMISSION_POLICY_V1.json"
$AdmissionPath = "self_build_batch/admission/BATCH_PLAN_EXAMPLE_V1_ADMISSION.json"
$ReportPath = "reports/self_development/BATCH_ADMISSION_POLICY_V1_REPORT.json"
$ProofPath = "proofs/self_development/BATCH_ADMISSION_POLICY_V1.json"
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
  if (@($errors).Count -gt 0) {
    Add-Failure "POWERSHELL_PARSE_FAIL=$Path"
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
  "modules/self_development/write_batch_admission_policy_v1.ps1",
  "packs/PHASE97_BATCH_ADMISSION_POLICY_V1/PACK.json",
  "packs/PHASE97_BATCH_ADMISSION_POLICY_V1/APPLY.ps1",
  "packs/PHASE97_BATCH_ADMISSION_POLICY_V1/VALIDATE.ps1",
  "tasks/TASK_BATCH_ADMISSION_POLICY_V1_001.json"
)) {
  Assert-FileExists $path
}

foreach ($path in @(
  "packs/PHASE97_BATCH_ADMISSION_POLICY_V1/PACK.json",
  "tasks/TASK_BATCH_ADMISSION_POLICY_V1_001.json",
  "TASK_QUEUE.json",
  "packs/registry.json",
  "CAPABILITY_ROADMAP.json",
  "GENESIS_STATE.json"
)) {
  Read-JsonFile $path | Out-Null
}

foreach ($script in @(
  "modules/self_development/write_batch_admission_policy_v1.ps1",
  "packs/PHASE97_BATCH_ADMISSION_POLICY_V1/APPLY.ps1",
  "packs/PHASE97_BATCH_ADMISSION_POLICY_V1/VALIDATE.ps1"
)) {
  Assert-ParserPass $script
}

$phase96Proof = Read-JsonFile "proofs/self_development/BATCH_PLANNER_V1.json"
if ($null -ne $phase96Proof) {
  if ("$(Get-PropertyValue -Object $phase96Proof -Name "status")" -ne "PASS") {
    Add-Failure "PHASE96_PROOF_STATUS_NOT_PASS"
  }
  if ("$(Get-PropertyValue -Object $phase96Proof -Name "next_allowed_step")" -ne "PHASE97_BATCH_ADMISSION_POLICY_V1") {
    Add-Failure "PHASE96_PROOF_NEXT_STEP_MISMATCH"
  }
}

$plan = Read-JsonFile "self_build_batch/plans/BATCH_PLAN_EXAMPLE_V1.json"
if ($null -ne $plan) {
  if ("$(Get-PropertyValue -Object $plan -Name "status")" -ne "PLANNED") {
    Add-Failure "SOURCE_PLAN_NOT_PLANNED"
  }
  if ([bool](Get-PropertyValue -Object $plan -Name "execution_allowed")) {
    Add-Failure "SOURCE_PLAN_EXECUTION_ALLOWED_TRUE"
  }
}

$queue = Read-JsonFile "TASK_QUEUE.json"
$registry = Read-JsonFile "packs/registry.json"
$task = Find-TaskEntry -Queue $queue
if ($null -eq $task) {
  Add-Failure "TASK_NOT_FOUND=$TaskId"
}
$selectedPacks = Get-MatchingRegistryPacks -Registry $registry
if (@($selectedPacks).Count -ne 1) {
  Add-Failure "REGISTRY_SELECTED_PACK_COUNT=$(@($selectedPacks).Count)"
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
    $PolicyPath,
    $AdmissionPath,
    $ReportPath,
    $ProofPath,
    "self_build_batch/ledger/ITEM_LEVEL_EXECUTION_LEDGER_V1.json",
    "packs/PHASE98_ITEM_LEVEL_EXECUTION_LEDGER_V1",
    "tasks/TASK_ITEM_LEVEL_EXECUTION_LEDGER_V1_001.json"
  )) {
    Assert-FileAbsent $path
  }
}

if ($Stage -eq "Completed") {
  $schema = Read-JsonFile $SchemaPath
  $policy = Read-JsonFile $PolicyPath
  $admission = Read-JsonFile $AdmissionPath
  $report = Read-JsonFile $ReportPath
  $proof = Read-JsonFile $ProofPath

  if ($null -ne $schema) {
    $required = As-Array (Get-PropertyValue -Object $schema -Name "required")
    foreach ($field in @(
      "policy_id",
      "version",
      "status",
      "active_line",
      "input_sources",
      "decision_values",
      "admission_checks",
      "blocking_conditions",
      "owner_approval_conditions",
      "assistance_conditions",
      "output_contract",
      "execution_allowed"
    )) {
      if ($required -notcontains $field) {
        Add-Failure "SCHEMA_REQUIRED_FIELD_MISSING=$field"
      }
    }
  }

  if ($null -ne $policy) {
    if ("$(Get-PropertyValue -Object $policy -Name "status")" -ne "ACTIVE_ADMISSION_POLICY") {
      Add-Failure "POLICY_STATUS_NOT_ACTIVE"
    }
  }

  if ($null -ne $admission) {
    if ("$(Get-PropertyValue -Object $admission -Name "status")" -ne "PASS") {
      Add-Failure "ADMISSION_STATUS_NOT_PASS"
    }
    if ("$(Get-PropertyValue -Object $admission -Name "decision")" -ne "CONDITIONALLY_ADMISSIBLE") {
      Add-Failure "ADMISSION_DECISION_MISMATCH"
    }
    if ([bool](Get-PropertyValue -Object $admission -Name "execution_allowed")) {
      Add-Failure "ADMISSION_EXECUTION_ALLOWED_TRUE"
    }
    $requiredBeforeExecution = As-Array (Get-PropertyValue -Object $admission -Name "required_before_execution")
    foreach ($phase in @(
      "PHASE98_ITEM_LEVEL_EXECUTION_LEDGER_V1",
      "PHASE99_CONTINUE_ON_FAILURE_RUNTIME_V1",
      "PHASE100_QUARANTINE_AND_BLOCKER_REGISTRY_V1",
      "PHASE101_BATCH_PROOF_AGGREGATOR_V1"
    )) {
      if ($requiredBeforeExecution -notcontains $phase) {
        Add-Failure "ADMISSION_REQUIRED_BEFORE_EXECUTION_MISSING=$phase"
      }
    }
    foreach ($field in @("no_external_agent_production", "no_external_install", "no_external_fetch")) {
      if (-not [bool](Get-PropertyValue -Object $admission -Name $field)) {
        Add-Failure "ADMISSION_$($field.ToUpperInvariant())_NOT_TRUE"
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
    if ("$(Get-PropertyValue -Object $proof -Name "phase")" -ne "PHASE97_BATCH_ADMISSION_POLICY_V1") {
      Add-Failure "PROOF_PHASE_MISMATCH"
    }
    if ("$(Get-PropertyValue -Object $proof -Name "task_id")" -ne $TaskId) {
      Add-Failure "PROOF_TASK_ID_MISMATCH"
    }
    if ("$(Get-PropertyValue -Object $proof -Name "runtime_mode")" -ne "SELF_BUILD") {
      Add-Failure "PROOF_RUNTIME_MODE_MISMATCH"
    }
    if ("$(Get-PropertyValue -Object $proof -Name "example_admission_decision")" -ne "CONDITIONALLY_ADMISSIBLE") {
      Add-Failure "PROOF_EXAMPLE_ADMISSION_DECISION_MISMATCH"
    }
    foreach ($field in @(
      "policy_created",
      "schema_created",
      "example_admission_created",
      "batch_execution_remains_blocked_until_runtime_exists",
      "policy_does_not_execute_batches",
      "policy_does_not_create_ledger",
      "no_external_agent_production",
      "no_external_install",
      "no_external_fetch",
      "phase98_not_executed",
      "queue_returned_to_none"
    )) {
      if (-not [bool](Get-PropertyValue -Object $proof -Name $field)) {
        Add-Failure "PROOF_$($field.ToUpperInvariant())_NOT_TRUE"
      }
    }
    if ([bool](Get-PropertyValue -Object $proof -Name "example_admission_execution_allowed")) {
      Add-Failure "PROOF_EXAMPLE_ADMISSION_EXECUTION_ALLOWED_TRUE"
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

if (@($script:Failures).Count -gt 0) {
  foreach ($failure in $script:Failures) {
    Write-Host "FAIL=$failure"
  }
  Write-Host "VALIDATION_RESULT=FAIL"
  throw "PHASE97_VALIDATION_FAILED"
}

if ($Stage -eq "Seed") {
  Write-Host "VALIDATION_RESULT=PASS_SEED"
} else {
  Write-Host "VALIDATION_RESULT=PASS"
}
