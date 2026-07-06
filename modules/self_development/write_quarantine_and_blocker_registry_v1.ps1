[CmdletBinding()]
param(
  [string]$Phase99ProofPath = "proofs/self_development/CONTINUE_ON_FAILURE_RUNTIME_V1.json",
  [string]$Phase99ReportPath = "reports/self_development/CONTINUE_ON_FAILURE_RUNTIME_V1_REPORT.json",
  [string]$SourceRuntimePath = "self_build_batch/runtime/CONTINUE_ON_FAILURE_RUNTIME_V1.json",
  [string]$SourceSimulationPath = "self_build_batch/runtime/CONTINUE_ON_FAILURE_SIMULATION_V1.json",
  [string]$SourceLedgerContractPath = "self_build_batch/ledger/ITEM_LEVEL_EXECUTION_LEDGER_V1.json",
  [string]$SourceDryRunLedgerPath = "self_build_batch/ledger/BATCH_PLAN_EXAMPLE_V1_LEDGER_DRY_RUN.json",
  [string]$RouteLockPath = "AGENT_BUILDER_NEXT_15_STEPS_LOCK_V2_R2.md",
  [string]$SchemaPath = "contracts/self_development/quarantine_and_blocker_registry_v1.schema.json",
  [string]$RegistryContractPath = "self_build_batch/quarantine/QUARANTINE_AND_BLOCKER_REGISTRY_V1.json",
  [string]$DryRunRegistryPath = "self_build_batch/quarantine/BATCH_PLAN_EXAMPLE_V1_QUARANTINE_BLOCKER_DRY_RUN.json",
  [string]$ReportPath = "reports/self_development/QUARANTINE_AND_BLOCKER_REGISTRY_V1_REPORT.json",
  [string]$ProofPath = "proofs/self_development/QUARANTINE_AND_BLOCKER_REGISTRY_V1.json",
  [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
)

$ErrorActionPreference = "Stop"

$Phase = "PHASE100_QUARANTINE_AND_BLOCKER_REGISTRY_V1"
$TaskId = "TASK_QUARANTINE_AND_BLOCKER_REGISTRY_V1_001"
$RouteLockVersion = "V2_R2"
$BaselineCommit = "b592d35"
$NextAllowedStep = "PHASE101_BATCH_PROOF_AGGREGATOR_V1"

function Join-RepoPath {
  param([string]$Path)

  if ([System.IO.Path]::IsPathRooted($Path)) {
    return [System.IO.Path]::GetFullPath($Path)
  }
  return [System.IO.Path]::GetFullPath((Join-Path $RepoRoot $Path))
}

function Get-UtcStamp {
  return (Get-Date).ToUniversalTime().ToString("o")
}

function Read-JsonRequired {
  param([string]$Path)

  $fullPath = Join-RepoPath $Path
  if (-not (Test-Path -LiteralPath $fullPath)) {
    throw "MISSING_JSON=$Path"
  }
  return (Get-Content -LiteralPath $fullPath -Raw | ConvertFrom-Json)
}

function Write-JsonFile {
  param(
    [string]$Path,
    [object]$Object
  )

  $fullPath = Join-RepoPath $Path
  $directory = Split-Path -Parent $fullPath
  if (-not (Test-Path -LiteralPath $directory)) {
    New-Item -ItemType Directory -Path $directory -Force | Out-Null
  }
  $json = ($Object | ConvertTo-Json -Depth 100) -replace "`r`n", "`n"
  if (-not $json.EndsWith("`n")) {
    $json += "`n"
  }
  [System.IO.File]::WriteAllText($fullPath, $json, [System.Text.UTF8Encoding]::new($false))
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

function New-RegistryRecord {
  param(
    [object]$Scenario,
    [string]$RecordType,
    [string]$Status,
    [string]$Reason,
    [string]$NextAction,
    [bool]$OwnerDecisionRequired = $false,
    [bool]$CodexRepairRequired = $false,
    [bool]$MaterialRequired = $false,
    [bool]$RetryAllowed = $false,
    [string[]]$RetryConditions = @()
  )

  $itemId = "$(Get-PropertyValue -Object $Scenario -Name "item_id")"
  $assistanceRequired = @()
  if ($OwnerDecisionRequired) {
    $assistanceRequired += "NEEDS_OWNER_DECISION"
  }
  if ($CodexRepairRequired) {
    $assistanceRequired += "NEEDS_CODEX_REPAIR"
  }
  if ($MaterialRequired) {
    $assistanceRequired += "NEEDS_MATERIAL"
  }

  $record = [ordered]@{
    record_id = "RECORD_$($Status)_$itemId"
    item_id = $itemId
    source_gap = "$(Get-PropertyValue -Object $Scenario -Name "source_gap")"
    record_type = $RecordType
    status = $Status
    reason = $Reason
    evidence_paths = @($SourceSimulationPath)
    related_proof_or_report = $Phase99ProofPath
    assistance_required = $assistanceRequired
    owner_decision_required = $OwnerDecisionRequired
    codex_repair_required = $CodexRepairRequired
    material_required = $MaterialRequired
    retry_allowed = $RetryAllowed
    retry_conditions = $RetryConditions
    next_action = $NextAction
  }
  return [pscustomobject]$record
}

Write-Host "QUARANTINE_AND_BLOCKER_REGISTRY_V1_START"

$phase99Proof = Read-JsonRequired $Phase99ProofPath
$phase99Report = Read-JsonRequired $Phase99ReportPath
$runtime = Read-JsonRequired $SourceRuntimePath
$simulation = Read-JsonRequired $SourceSimulationPath
$ledgerContract = Read-JsonRequired $SourceLedgerContractPath
$dryRunLedger = Read-JsonRequired $SourceDryRunLedgerPath

if (-not (Test-Path -LiteralPath (Join-RepoPath $RouteLockPath))) {
  throw "MISSING_ROUTE_LOCK=$RouteLockPath"
}
if ("$(Get-PropertyValue -Object $phase99Proof -Name "status")" -ne "PASS") {
  throw "PHASE99_PROOF_STATUS_NOT_PASS"
}
if ("$(Get-PropertyValue -Object $phase99Proof -Name "next_allowed_step")" -ne "PHASE100_QUARANTINE_AND_BLOCKER_REGISTRY_V1") {
  throw "PHASE99_PROOF_NEXT_STEP_MISMATCH"
}
if (-not [bool](Get-PropertyValue -Object $phase99Proof -Name "quarantine_registry_required_next")) {
  throw "PHASE99_PROOF_QUARANTINE_REGISTRY_NOT_REQUIRED"
}
if ("$(Get-PropertyValue -Object $phase99Report -Name "status")" -ne "PASS") {
  throw "PHASE99_REPORT_STATUS_NOT_PASS"
}
if ("$(Get-PropertyValue -Object $runtime -Name "status")" -ne "ACTIVE_RUNTIME_CONTRACT") {
  throw "SOURCE_RUNTIME_STATUS_NOT_ACTIVE"
}
if ([bool](Get-PropertyValue -Object $runtime -Name "execution_allowed")) {
  throw "SOURCE_RUNTIME_EXECUTION_ALLOWED_TRUE"
}
if ("$(Get-PropertyValue -Object $simulation -Name "status")" -ne "SIMULATION_ONLY") {
  throw "SOURCE_SIMULATION_STATUS_NOT_SIMULATION_ONLY"
}
foreach ($falseField in @("execution_performed", "real_items_executed", "real_items_marked_pass")) {
  if ([bool](Get-PropertyValue -Object $simulation -Name $falseField)) {
    throw "SOURCE_SIMULATION_$($falseField.ToUpperInvariant())_TRUE"
  }
}
if ("$(Get-PropertyValue -Object $ledgerContract -Name "status")" -ne "ACTIVE_LEDGER_CONTRACT") {
  throw "LEDGER_CONTRACT_STATUS_NOT_ACTIVE"
}
if ([bool](Get-PropertyValue -Object $dryRunLedger -Name "execution_attempted")) {
  throw "DRY_RUN_LEDGER_EXECUTION_ATTEMPTED_TRUE"
}

$scenarioResults = As-Array (Get-PropertyValue -Object $simulation -Name "scenario_results")
$safeFailure = $scenarioResults | Where-Object { "$(Get-PropertyValue -Object $_ -Name "simulated_result")" -eq "WOULD_FAIL_SAFE_AND_CONTINUE" } | Select-Object -First 1
$quarantine = $scenarioResults | Where-Object { "$(Get-PropertyValue -Object $_ -Name "simulated_result")" -eq "WOULD_QUARANTINE_AND_CONTINUE" } | Select-Object -First 1
$blocked = $scenarioResults | Where-Object { "$(Get-PropertyValue -Object $_ -Name "simulated_result")" -eq "WOULD_BLOCK_AND_RECORD_REASON" } | Select-Object -First 1
$systemic = $scenarioResults | Where-Object { "$(Get-PropertyValue -Object $_ -Name "simulated_result")" -eq "WOULD_STOP_ON_SYSTEMIC_FAILURE" } | Select-Object -First 1

if ($null -eq $safeFailure) { throw "SIMULATION_SAFE_FAILURE_SCENARIO_MISSING" }
if ($null -eq $quarantine) { throw "SIMULATION_QUARANTINE_SCENARIO_MISSING" }
if ($null -eq $blocked) { throw "SIMULATION_BLOCKED_SCENARIO_MISSING" }
if ($null -eq $systemic) { throw "SIMULATION_SYSTEMIC_SCENARIO_MISSING" }

$recordStatusValues = @(
  "FAILED",
  "QUARANTINED",
  "BLOCKED",
  "NEEDS_OWNER_DECISION",
  "NEEDS_CODEX_REPAIR",
  "NEEDS_MATERIAL",
  "SKIPPED_BY_POLICY"
)

$records = @(
  (New-RegistryRecord -Scenario $safeFailure -RecordType "FAILED" -Status "FAILED" -Reason "Simulation shows this isolated item could fail safely and continue after the failure is recorded." -NextAction "RETRY_ONLY_AFTER_CODEX_REPAIR_OR_OWNER_APPROVAL" -CodexRepairRequired $true -RetryAllowed $true -RetryConditions @("failure_reason_recorded", "codex_repair_applied", "item_scope_remains_isolated")),
  (New-RegistryRecord -Scenario $quarantine -RecordType "QUARANTINED" -Status "QUARANTINED" -Reason "Simulation shows this item would be quarantined before continuing because validation failed." -NextAction "KEEP_QUARANTINED_UNTIL_PHASE100_REGISTRY_AND_OWNER_REVIEW"),
  (New-RegistryRecord -Scenario $blocked -RecordType "BLOCKED" -Status "BLOCKED" -Reason "Simulation shows this item would be blocked by a dependency and must record the blocker before continuing." -NextAction "WAIT_FOR_DEPENDENCY_CLEARANCE"),
  (New-RegistryRecord -Scenario $systemic -RecordType "NEEDS_OWNER_DECISION" -Status "NEEDS_OWNER_DECISION" -Reason "Simulation shows a systemic failure stop condition that requires owner decision before retry or continuation." -NextAction "STOP_BATCH_AND_REQUEST_OWNER_DECISION" -OwnerDecisionRequired $true)
)

$passRecords = @($records | Where-Object { "$(Get-PropertyValue -Object $_ -Name "status")" -eq "PASS" })
$recordsMissingReason = @($records | Where-Object { [string]::IsNullOrWhiteSpace("$(Get-PropertyValue -Object $_ -Name "reason")") })
$recordsMissingNextAction = @($records | Where-Object { [string]::IsNullOrWhiteSpace("$(Get-PropertyValue -Object $_ -Name "next_action")") })
$recordsMissingRecordType = @($records | Where-Object { [string]::IsNullOrWhiteSpace("$(Get-PropertyValue -Object $_ -Name "record_type")") })
if ($passRecords.Count -gt 0) {
  throw "DRY_RUN_REGISTRY_HAS_PASS_RECORD"
}
if ($recordsMissingReason.Count -gt 0) {
  throw "DRY_RUN_REGISTRY_RECORD_MISSING_REASON"
}
if ($recordsMissingNextAction.Count -gt 0) {
  throw "DRY_RUN_REGISTRY_RECORD_MISSING_NEXT_ACTION"
}
if ($recordsMissingRecordType.Count -gt 0) {
  throw "DRY_RUN_REGISTRY_RECORD_MISSING_RECORD_TYPE"
}

$generatedAt = Get-UtcStamp
$registryPolicy = [ordered]@{
  failed_item_must_have_reason = $true
  quarantined_item_must_have_reason = $true
  blocked_item_must_have_reason = $true
  assistance_required_must_be_explicit = $true
  no_blind_retry = $true
  retry_requires_conditions = $true
  owner_decision_required_must_be_explicit = $true
  codex_repair_required_must_be_explicit = $true
  material_required_must_be_explicit = $true
  registry_does_not_execute_items = $true
  registry_does_not_mark_pass = $true
  no_external_agent_production = $true
  no_external_install = $true
  no_external_fetch = $true
}

$schema = [ordered]@{
  '$schema' = "https://json-schema.org/draft/2020-12/schema"
  schema_id = "quarantine_and_blocker_registry_v1"
  title = "Quarantine And Blocker Registry V1"
  type = "object"
  required = @(
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
  )
  properties = [ordered]@{
    registry_id = [ordered]@{ type = "string" }
    version = [ordered]@{ const = "V1" }
    status = [ordered]@{ type = "string" }
    active_line = [ordered]@{ const = "AGENT_BUILDER / SELF_BUILD" }
    input_sources = [ordered]@{ type = "array" }
    registry_policy = [ordered]@{ type = "object" }
    record_status_values = [ordered]@{
      type = "array"
      items = [ordered]@{ enum = $recordStatusValues }
    }
    records = [ordered]@{
      type = "array"
      items = [ordered]@{
        type = "object"
        required = @(
          "record_id",
          "item_id",
          "source_gap",
          "record_type",
          "status",
          "reason",
          "evidence_paths",
          "related_proof_or_report",
          "assistance_required",
          "owner_decision_required",
          "codex_repair_required",
          "material_required",
          "retry_allowed",
          "retry_conditions",
          "next_action"
        )
      }
    }
    record_count = [ordered]@{ type = "integer"; minimum = 0 }
    execution_performed = [ordered]@{ const = $false }
    next_allowed_step = [ordered]@{ const = $NextAllowedStep }
  }
  additionalProperties = $true
}

$inputSources = @(
  "self_build_batch/runtime/CONTINUE_ON_FAILURE_RUNTIME_V1.json",
  "self_build_batch/runtime/CONTINUE_ON_FAILURE_SIMULATION_V1.json",
  "self_build_batch/ledger/ITEM_LEVEL_EXECUTION_LEDGER_V1.json",
  "self_build_batch/ledger/BATCH_PLAN_EXAMPLE_V1_LEDGER_DRY_RUN.json"
)

$registryContract = [ordered]@{
  registry_id = "QUARANTINE_AND_BLOCKER_REGISTRY_V1"
  version = "V1"
  status = "ACTIVE_REGISTRY_CONTRACT"
  phase = $Phase
  active_line = "AGENT_BUILDER / SELF_BUILD"
  generated_at = $generatedAt
  input_sources = $inputSources
  output_schema = $SchemaPath
  registry_policy = $registryPolicy
  record_status_values = $recordStatusValues
  records = @()
  record_count = 0
  execution_performed = $false
  next_allowed_step = $NextAllowedStep
}

$dryRunRegistry = [ordered]@{
  registry_id = "BATCH_PLAN_EXAMPLE_V1_QUARANTINE_BLOCKER_DRY_RUN"
  version = "V1"
  status = "DRY_RUN_INITIALIZED"
  active_line = "AGENT_BUILDER / SELF_BUILD"
  generated_at = $generatedAt
  source_simulation = $SourceSimulationPath
  execution_performed = $false
  real_items_executed = $false
  real_items_marked_pass = $false
  record_status_values = $recordStatusValues
  registry_policy = $registryPolicy
  records = $records
  record_count = $records.Count
  no_pass_records = $true
  no_blind_retry = $true
  next_allowed_step = $NextAllowedStep
}

$report = [ordered]@{
  status = "PASS"
  phase = $Phase
  active_line = "AGENT_BUILDER / SELF_BUILD"
  generated_at = $generatedAt
  baseline_commit = $BaselineCommit
  registry_contract_created = $RegistryContractPath
  schema_created = $SchemaPath
  dry_run_registry_created = $DryRunRegistryPath
  dry_run_registry_status = "DRY_RUN_INITIALIZED"
  execution_performed = $false
  real_items_executed = $false
  real_items_marked_pass = $false
  record_count = $records.Count
  no_pass_records = $true
  no_blind_retry = $true
  registry_does_not_execute_items = $true
  registry_does_not_mark_pass = $true
  batch_proof_aggregator_required_next = $true
  no_external_agent_production = $true
  no_external_install = $true
  no_external_fetch = $true
  phase101_not_executed = $true
  next_allowed_step = $NextAllowedStep
}

$proof = [ordered]@{
  status = "PASS"
  phase = $Phase
  task_id = $TaskId
  runtime_mode = "SELF_BUILD"
  generated_at = $generatedAt
  route_lock_version = $RouteLockVersion
  baseline_commit = $BaselineCommit
  registry_contract_created = $true
  schema_created = $true
  dry_run_registry_created = $true
  dry_run_registry_status = "DRY_RUN_INITIALIZED"
  execution_performed = $false
  real_items_executed = $false
  real_items_marked_pass = $false
  record_count = $records.Count
  no_pass_records = $true
  no_blind_retry = $true
  registry_does_not_execute_items = $true
  registry_does_not_mark_pass = $true
  batch_proof_aggregator_required_next = $true
  no_external_agent_production = $true
  no_external_install = $true
  no_external_fetch = $true
  phase101_not_executed = $true
  queue_returned_to_none = $true
  next_allowed_step = $NextAllowedStep
  evidence_files = @(
    $SchemaPath,
    $RegistryContractPath,
    $DryRunRegistryPath,
    $ReportPath
  )
}

Write-JsonFile -Path $SchemaPath -Object $schema
Write-JsonFile -Path $RegistryContractPath -Object $registryContract
Write-JsonFile -Path $DryRunRegistryPath -Object $dryRunRegistry
Write-JsonFile -Path $ReportPath -Object $report
Write-JsonFile -Path $ProofPath -Object $proof

Write-Host "QUARANTINE_AND_BLOCKER_REGISTRY_SCHEMA_CREATED=$SchemaPath"
Write-Host "QUARANTINE_AND_BLOCKER_REGISTRY_CONTRACT_CREATED=$RegistryContractPath"
Write-Host "QUARANTINE_BLOCKER_DRY_RUN_REGISTRY_CREATED=$DryRunRegistryPath"
Write-Host "DRY_RUN_REGISTRY_STATUS=DRY_RUN_INITIALIZED"
Write-Host "EXECUTION_PERFORMED=FALSE"
Write-Host "REAL_ITEMS_EXECUTED=FALSE"
Write-Host "REAL_ITEMS_MARKED_PASS=FALSE"
Write-Host "NO_PASS_RECORDS=TRUE"
Write-Host "NO_BLIND_RETRY=TRUE"
Write-Host "NO_EXTERNAL_AGENT_PRODUCTION=TRUE"
Write-Host "QUARANTINE_AND_BLOCKER_REGISTRY_REPORT_WRITTEN=$ReportPath"
Write-Host "QUARANTINE_AND_BLOCKER_REGISTRY_PROOF_WRITTEN=$ProofPath"
Write-Host "QUARANTINE_AND_BLOCKER_REGISTRY_V1_COMPLETE"

return [pscustomobject]$report
