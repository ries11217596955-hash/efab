[CmdletBinding()]
param(
  [ValidateSet("Auto", "Seed", "Completed")]
  [string]$Stage = "Auto",
  [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
)

$ErrorActionPreference = "Stop"

$TaskId = "TASK_QUARANTINE_AND_BLOCKER_REGISTRY_V1_001"
$PackId = "PHASE100_QUARANTINE_AND_BLOCKER_REGISTRY_V1"
$EntryScript = "packs/PHASE100_QUARANTINE_AND_BLOCKER_REGISTRY_V1/APPLY.ps1"
$NextAllowedStep = "PHASE101_BATCH_PROOF_AGGREGATOR_V1"
$SchemaPath = "contracts/self_development/quarantine_and_blocker_registry_v1.schema.json"
$RegistryContractPath = "self_build_batch/quarantine/QUARANTINE_AND_BLOCKER_REGISTRY_V1.json"
$DryRunRegistryPath = "self_build_batch/quarantine/BATCH_PLAN_EXAMPLE_V1_QUARANTINE_BLOCKER_DRY_RUN.json"
$ReportPath = "reports/self_development/QUARANTINE_AND_BLOCKER_REGISTRY_V1_REPORT.json"
$ProofPath = "proofs/self_development/QUARANTINE_AND_BLOCKER_REGISTRY_V1.json"
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
  "modules/self_development/write_quarantine_and_blocker_registry_v1.ps1",
  "packs/PHASE100_QUARANTINE_AND_BLOCKER_REGISTRY_V1/PACK.json",
  "packs/PHASE100_QUARANTINE_AND_BLOCKER_REGISTRY_V1/APPLY.ps1",
  "packs/PHASE100_QUARANTINE_AND_BLOCKER_REGISTRY_V1/VALIDATE.ps1",
  "tasks/TASK_QUARANTINE_AND_BLOCKER_REGISTRY_V1_001.json"
)) {
  Assert-FileExists $path
}

foreach ($path in @(
  "packs/PHASE100_QUARANTINE_AND_BLOCKER_REGISTRY_V1/PACK.json",
  "tasks/TASK_QUARANTINE_AND_BLOCKER_REGISTRY_V1_001.json",
  "TASK_QUEUE.json",
  "packs/registry.json",
  "CAPABILITY_ROADMAP.json",
  "GENESIS_STATE.json"
)) {
  Read-JsonFile $path | Out-Null
}

foreach ($script in @(
  "modules/self_development/write_quarantine_and_blocker_registry_v1.ps1",
  "packs/PHASE100_QUARANTINE_AND_BLOCKER_REGISTRY_V1/APPLY.ps1",
  "packs/PHASE100_QUARANTINE_AND_BLOCKER_REGISTRY_V1/VALIDATE.ps1"
)) {
  Assert-ParserPass $script
}

$phase99Proof = Read-JsonFile "proofs/self_development/CONTINUE_ON_FAILURE_RUNTIME_V1.json"
if ($null -ne $phase99Proof) {
  if ("$(Get-PropertyValue -Object $phase99Proof -Name "status")" -ne "PASS") {
    Add-Failure "PHASE99_PROOF_STATUS_NOT_PASS"
  }
  if ("$(Get-PropertyValue -Object $phase99Proof -Name "next_allowed_step")" -ne "PHASE100_QUARANTINE_AND_BLOCKER_REGISTRY_V1") {
    Add-Failure "PHASE99_PROOF_NEXT_STEP_MISMATCH"
  }
}

$simulation = Read-JsonFile "self_build_batch/runtime/CONTINUE_ON_FAILURE_SIMULATION_V1.json"
if ($null -ne $simulation) {
  if ("$(Get-PropertyValue -Object $simulation -Name "status")" -ne "SIMULATION_ONLY") {
    Add-Failure "SOURCE_SIMULATION_STATUS_NOT_SIMULATION_ONLY"
  }
  if ([bool](Get-PropertyValue -Object $simulation -Name "execution_performed")) {
    Add-Failure "SOURCE_SIMULATION_EXECUTION_PERFORMED_TRUE"
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
    $RegistryContractPath,
    $DryRunRegistryPath,
    $ReportPath,
    $ProofPath,
    "self_build_batch/proofs",
    "packs/PHASE101_BATCH_PROOF_AGGREGATOR_V1",
    "tasks/TASK_BATCH_PROOF_AGGREGATOR_V1_001.json"
  )) {
    Assert-FileAbsent $path
  }
}

if ($Stage -eq "Completed") {
  $schema = Read-JsonFile $SchemaPath
  $registryContract = Read-JsonFile $RegistryContractPath
  $dryRunRegistry = Read-JsonFile $DryRunRegistryPath
  $report = Read-JsonFile $ReportPath
  $proof = Read-JsonFile $ProofPath

  if ($null -ne $schema) {
    $required = As-Array (Get-PropertyValue -Object $schema -Name "required")
    foreach ($field in @(
      "registry_id",
      "version",
      "status",
      "active_line",
      "input_sources",
      "registry_policy",
      "record_status_values",
      "records",
      "record_count",
      "execution_performed",
      "next_allowed_step"
    )) {
      if ($required -notcontains $field) {
        Add-Failure "SCHEMA_REQUIRED_FIELD_MISSING=$field"
      }
    }
  }

  if ($null -ne $registryContract) {
    if ("$(Get-PropertyValue -Object $registryContract -Name "status")" -ne "ACTIVE_REGISTRY_CONTRACT") {
      Add-Failure "REGISTRY_CONTRACT_STATUS_NOT_ACTIVE"
    }
    if ([bool](Get-PropertyValue -Object $registryContract -Name "execution_performed")) {
      Add-Failure "REGISTRY_CONTRACT_EXECUTION_PERFORMED_TRUE"
    }
  }

  if ($null -ne $dryRunRegistry) {
    if ("$(Get-PropertyValue -Object $dryRunRegistry -Name "status")" -ne "DRY_RUN_INITIALIZED") {
      Add-Failure "DRY_RUN_REGISTRY_STATUS_NOT_INITIALIZED"
    }
    foreach ($falseField in @("execution_performed", "real_items_executed", "real_items_marked_pass")) {
      if ([bool](Get-PropertyValue -Object $dryRunRegistry -Name $falseField)) {
        Add-Failure "DRY_RUN_REGISTRY_$($falseField.ToUpperInvariant())_TRUE"
      }
    }
    $recordCount = [int](Get-PropertyValue -Object $dryRunRegistry -Name "record_count")
    if ($recordCount -lt 4) {
      Add-Failure "DRY_RUN_REGISTRY_RECORD_COUNT_LT_4"
    }
    $records = As-Array (Get-PropertyValue -Object $dryRunRegistry -Name "records")
    $statuses = @($records | ForEach-Object { "$(Get-PropertyValue -Object $_ -Name "status")" })
    $recordTypes = @($records | ForEach-Object { "$(Get-PropertyValue -Object $_ -Name "record_type")" })
    foreach ($status in @("FAILED", "QUARANTINED", "BLOCKED")) {
      if ($statuses -notcontains $status) {
        Add-Failure "DRY_RUN_REGISTRY_STATUS_MISSING=$status"
      }
      if ($recordTypes -notcontains $status) {
        Add-Failure "DRY_RUN_REGISTRY_RECORD_TYPE_MISSING=$status"
      }
    }
    if (($statuses -notcontains "NEEDS_OWNER_DECISION") -and ($statuses -notcontains "NEEDS_CODEX_REPAIR") -and ($statuses -notcontains "NEEDS_MATERIAL")) {
      Add-Failure "DRY_RUN_REGISTRY_ASSISTANCE_STATUS_MISSING"
    }
    if (($recordTypes -notcontains "NEEDS_OWNER_DECISION") -and ($recordTypes -notcontains "NEEDS_CODEX_REPAIR") -and ($recordTypes -notcontains "NEEDS_MATERIAL")) {
      Add-Failure "DRY_RUN_REGISTRY_ASSISTANCE_RECORD_TYPE_MISSING"
    }
    if ($statuses -contains "PASS") {
      Add-Failure "DRY_RUN_REGISTRY_HAS_PASS_RECORD"
    }
    foreach ($record in $records) {
      $recordId = Get-PropertyValue -Object $record -Name "record_id"
      $status = "$(Get-PropertyValue -Object $record -Name "status")"
      $recordType = "$(Get-PropertyValue -Object $record -Name "record_type")"
      if ([string]::IsNullOrWhiteSpace($recordType)) {
        Add-Failure "DRY_RUN_REGISTRY_RECORD_MISSING_RECORD_TYPE=$recordId"
      }
      if ($status -eq "PASS") {
        Add-Failure "DRY_RUN_REGISTRY_RECORD_STATUS_PASS=$recordId"
      }
      if (($status -in @("FAILED", "QUARANTINED", "BLOCKED")) -and ($recordType -ne $status)) {
        Add-Failure "DRY_RUN_REGISTRY_RECORD_TYPE_MISMATCH=$recordId"
      }
      if ([string]::IsNullOrWhiteSpace("$(Get-PropertyValue -Object $record -Name "reason")")) {
        Add-Failure "DRY_RUN_REGISTRY_RECORD_MISSING_REASON=$recordId"
      }
      if ([string]::IsNullOrWhiteSpace("$(Get-PropertyValue -Object $record -Name "next_action")")) {
        Add-Failure "DRY_RUN_REGISTRY_RECORD_MISSING_NEXT_ACTION=$recordId"
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
    if ("$(Get-PropertyValue -Object $proof -Name "phase")" -ne "PHASE100_QUARANTINE_AND_BLOCKER_REGISTRY_V1") {
      Add-Failure "PROOF_PHASE_MISMATCH"
    }
    if ("$(Get-PropertyValue -Object $proof -Name "task_id")" -ne $TaskId) {
      Add-Failure "PROOF_TASK_ID_MISMATCH"
    }
    if ("$(Get-PropertyValue -Object $proof -Name "runtime_mode")" -ne "SELF_BUILD") {
      Add-Failure "PROOF_RUNTIME_MODE_MISMATCH"
    }
    foreach ($field in @(
      "registry_contract_created",
      "schema_created",
      "dry_run_registry_created",
      "no_pass_records",
      "no_blind_retry",
      "registry_does_not_execute_items",
      "registry_does_not_mark_pass",
      "batch_proof_aggregator_required_next",
      "no_external_agent_production",
      "no_external_install",
      "no_external_fetch",
      "phase101_not_executed",
      "queue_returned_to_none"
    )) {
      if (-not [bool](Get-PropertyValue -Object $proof -Name $field)) {
        Add-Failure "PROOF_$($field.ToUpperInvariant())_NOT_TRUE"
      }
    }
    foreach ($falseField in @("execution_performed", "real_items_executed", "real_items_marked_pass")) {
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

if (@($script:Failures).Count -gt 0) {
  foreach ($failure in $script:Failures) {
    Write-Host "FAIL=$failure"
  }
  Write-Host "VALIDATION_RESULT=FAIL"
  throw "PHASE100_VALIDATION_FAILED"
}

if ($Stage -eq "Seed") {
  Write-Host "VALIDATION_RESULT=PASS_SEED"
} else {
  Write-Host "VALIDATION_RESULT=PASS"
}
