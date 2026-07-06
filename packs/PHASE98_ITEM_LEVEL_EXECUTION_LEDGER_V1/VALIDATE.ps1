[CmdletBinding()]
param(
  [ValidateSet("Auto", "Seed", "Completed")]
  [string]$Stage = "Auto",
  [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
)

$ErrorActionPreference = "Stop"

$TaskId = "TASK_ITEM_LEVEL_EXECUTION_LEDGER_V1_001"
$PackId = "PHASE98_ITEM_LEVEL_EXECUTION_LEDGER_V1"
$EntryScript = "packs/PHASE98_ITEM_LEVEL_EXECUTION_LEDGER_V1/APPLY.ps1"
$NextAllowedStep = "PHASE99_CONTINUE_ON_FAILURE_RUNTIME_V1"
$SchemaPath = "contracts/self_development/item_level_execution_ledger_v1.schema.json"
$LedgerContractPath = "self_build_batch/ledger/ITEM_LEVEL_EXECUTION_LEDGER_V1.json"
$DryRunLedgerPath = "self_build_batch/ledger/BATCH_PLAN_EXAMPLE_V1_LEDGER_DRY_RUN.json"
$DeliveryConveyorContractPath = "contracts/operations/self_build_delivery_conveyor_v1.json"
$DeliveryConveyorDocPath = "docs/operations/SELF_BUILD_DELIVERY_CONVEYOR_V1.md"
$ReportPath = "reports/self_development/ITEM_LEVEL_EXECUTION_LEDGER_V1_REPORT.json"
$ProofPath = "proofs/self_development/ITEM_LEVEL_EXECUTION_LEDGER_V1.json"
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
  "modules/self_development/write_item_level_execution_ledger_v1.ps1",
  "packs/PHASE98_ITEM_LEVEL_EXECUTION_LEDGER_V1/PACK.json",
  "packs/PHASE98_ITEM_LEVEL_EXECUTION_LEDGER_V1/APPLY.ps1",
  "packs/PHASE98_ITEM_LEVEL_EXECUTION_LEDGER_V1/VALIDATE.ps1",
  "tasks/TASK_ITEM_LEVEL_EXECUTION_LEDGER_V1_001.json"
)) {
  Assert-FileExists $path
}

foreach ($path in @(
  "packs/PHASE98_ITEM_LEVEL_EXECUTION_LEDGER_V1/PACK.json",
  "tasks/TASK_ITEM_LEVEL_EXECUTION_LEDGER_V1_001.json",
  "TASK_QUEUE.json",
  "packs/registry.json",
  "CAPABILITY_ROADMAP.json",
  "GENESIS_STATE.json"
)) {
  Read-JsonFile $path | Out-Null
}

foreach ($script in @(
  "modules/self_development/write_item_level_execution_ledger_v1.ps1",
  "packs/PHASE98_ITEM_LEVEL_EXECUTION_LEDGER_V1/APPLY.ps1",
  "packs/PHASE98_ITEM_LEVEL_EXECUTION_LEDGER_V1/VALIDATE.ps1"
)) {
  Assert-ParserPass $script
}

$phase97Proof = Read-JsonFile "proofs/self_development/BATCH_ADMISSION_POLICY_V1.json"
if ($null -ne $phase97Proof) {
  if ("$(Get-PropertyValue -Object $phase97Proof -Name "status")" -ne "PASS") {
    Add-Failure "PHASE97_PROOF_STATUS_NOT_PASS"
  }
  if ("$(Get-PropertyValue -Object $phase97Proof -Name "next_allowed_step")" -ne "PHASE98_ITEM_LEVEL_EXECUTION_LEDGER_V1") {
    Add-Failure "PHASE97_PROOF_NEXT_STEP_MISMATCH"
  }
}

$admission = Read-JsonFile "self_build_batch/admission/BATCH_PLAN_EXAMPLE_V1_ADMISSION.json"
if ($null -ne $admission) {
  if ([bool](Get-PropertyValue -Object $admission -Name "execution_allowed")) {
    Add-Failure "SOURCE_ADMISSION_EXECUTION_ALLOWED_TRUE"
  }
}

$plan = Read-JsonFile "self_build_batch/plans/BATCH_PLAN_EXAMPLE_V1.json"
if ($null -ne $plan) {
  if ("$(Get-PropertyValue -Object $plan -Name "status")" -ne "PLANNED") {
    Add-Failure "SOURCE_PLAN_NOT_PLANNED"
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
    $LedgerContractPath,
    $DryRunLedgerPath,
    $DeliveryConveyorContractPath,
    $DeliveryConveyorDocPath,
    $ReportPath,
    $ProofPath,
    "packs/PHASE99_CONTINUE_ON_FAILURE_RUNTIME_V1",
    "tasks/TASK_CONTINUE_ON_FAILURE_RUNTIME_V1_001.json"
  )) {
    Assert-FileAbsent $path
  }
}

if ($Stage -eq "Completed") {
  $schema = Read-JsonFile $SchemaPath
  $ledgerContract = Read-JsonFile $LedgerContractPath
  $dryRunLedger = Read-JsonFile $DryRunLedgerPath
  $conveyorContract = Read-JsonFile $DeliveryConveyorContractPath
  $report = Read-JsonFile $ReportPath
  $proof = Read-JsonFile $ProofPath

  $docFullPath = Join-RepoPath $DeliveryConveyorDocPath
  if (-not (Test-Path -LiteralPath $docFullPath)) {
    Add-Failure "MISSING_DOC=$DeliveryConveyorDocPath"
  } else {
    $docText = Get-Content -LiteralPath $docFullPath -Raw
    if ($docText -notmatch "SELF_BUILD_DELIVERY_CONVEYOR_V1") {
      Add-Failure "DOC_MISSING_CONVEYOR_ID"
    }
  }

  if ($null -ne $schema) {
    $required = As-Array (Get-PropertyValue -Object $schema -Name "required")
    foreach ($field in @(
      "ledger_id",
      "version",
      "status",
      "active_line",
      "source_plan",
      "source_admission",
      "item_status_values",
      "ledger_policy",
      "entries",
      "item_count",
      "execution_attempted",
      "next_allowed_step"
    )) {
      if ($required -notcontains $field) {
        Add-Failure "SCHEMA_REQUIRED_FIELD_MISSING=$field"
      }
    }
  }

  if ($null -ne $ledgerContract) {
    if ("$(Get-PropertyValue -Object $ledgerContract -Name "status")" -ne "ACTIVE_LEDGER_CONTRACT") {
      Add-Failure "LEDGER_CONTRACT_STATUS_NOT_ACTIVE"
    }
  }

  if ($null -ne $dryRunLedger) {
    if ("$(Get-PropertyValue -Object $dryRunLedger -Name "status")" -ne "INITIALIZED") {
      Add-Failure "DRY_RUN_LEDGER_STATUS_NOT_INITIALIZED"
    }
    if ([bool](Get-PropertyValue -Object $dryRunLedger -Name "execution_attempted")) {
      Add-Failure "DRY_RUN_LEDGER_EXECUTION_ATTEMPTED_TRUE"
    }
    $itemCount = [int](Get-PropertyValue -Object $dryRunLedger -Name "item_count")
    if ($itemCount -lt 5) {
      Add-Failure "DRY_RUN_LEDGER_ITEM_COUNT_LT_5"
    }
    foreach ($entry in As-Array (Get-PropertyValue -Object $dryRunLedger -Name "entries")) {
      $entryId = Get-PropertyValue -Object $entry -Name "item_id"
      if ("$(Get-PropertyValue -Object $entry -Name "status")" -eq "PASS") {
        Add-Failure "DRY_RUN_LEDGER_HAS_PASS_ENTRY=$entryId"
      }
      if ([bool](Get-PropertyValue -Object $entry -Name "execution_attempted")) {
        Add-Failure "DRY_RUN_LEDGER_HAS_EXECUTED_ENTRY=$entryId"
      }
    }
  }

  if ($null -ne $conveyorContract) {
    if ("$(Get-PropertyValue -Object $conveyorContract -Name "status")" -ne "ACTIVE_OPERATION_CONTRACT") {
      Add-Failure "CONVEYOR_CONTRACT_STATUS_NOT_ACTIVE"
    }
    $processPolicy = Get-PropertyValue -Object $conveyorContract -Name "process_policy"
    foreach ($field in @("combined_terminal_pack_preferred_after_phase97", "stop_on_any_fail", "no_fake_pass")) {
      if (-not [bool](Get-PropertyValue -Object $processPolicy -Name $field)) {
        Add-Failure "CONVEYOR_POLICY_$($field.ToUpperInvariant())_NOT_TRUE"
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
    if ("$(Get-PropertyValue -Object $proof -Name "phase")" -ne "PHASE98_ITEM_LEVEL_EXECUTION_LEDGER_V1") {
      Add-Failure "PROOF_PHASE_MISMATCH"
    }
    if ("$(Get-PropertyValue -Object $proof -Name "task_id")" -ne $TaskId) {
      Add-Failure "PROOF_TASK_ID_MISMATCH"
    }
    if ("$(Get-PropertyValue -Object $proof -Name "runtime_mode")" -ne "SELF_BUILD") {
      Add-Failure "PROOF_RUNTIME_MODE_MISMATCH"
    }
    foreach ($field in @(
      "ledger_contract_created",
      "schema_created",
      "dry_run_ledger_created",
      "delivery_conveyor_contract_created",
      "delivery_conveyor_doc_created",
      "no_item_pass",
      "ledger_does_not_execute_items",
      "combined_terminal_pack_policy_recorded",
      "no_external_agent_production",
      "no_external_install",
      "no_external_fetch",
      "phase99_not_executed",
      "queue_returned_to_none"
    )) {
      if (-not [bool](Get-PropertyValue -Object $proof -Name $field)) {
        Add-Failure "PROOF_$($field.ToUpperInvariant())_NOT_TRUE"
      }
    }
    if ([bool](Get-PropertyValue -Object $proof -Name "dry_run_execution_attempted")) {
      Add-Failure "PROOF_DRY_RUN_EXECUTION_ATTEMPTED_TRUE"
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
  throw "PHASE98_VALIDATION_FAILED"
}

if ($Stage -eq "Seed") {
  Write-Host "VALIDATION_RESULT=PASS_SEED"
} else {
  Write-Host "VALIDATION_RESULT=PASS"
}
