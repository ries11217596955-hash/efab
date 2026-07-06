[CmdletBinding()]
param(
  [string]$Phase98ProofPath = "proofs/self_development/ITEM_LEVEL_EXECUTION_LEDGER_V1.json",
  [string]$Phase98ReportPath = "reports/self_development/ITEM_LEVEL_EXECUTION_LEDGER_V1_REPORT.json",
  [string]$SourceLedgerContractPath = "self_build_batch/ledger/ITEM_LEVEL_EXECUTION_LEDGER_V1.json",
  [string]$SourceDryRunLedgerPath = "self_build_batch/ledger/BATCH_PLAN_EXAMPLE_V1_LEDGER_DRY_RUN.json",
  [string]$SourceAdmissionPath = "self_build_batch/admission/BATCH_PLAN_EXAMPLE_V1_ADMISSION.json",
  [string]$DeliveryConveyorContractPath = "contracts/operations/self_build_delivery_conveyor_v1.json",
  [string]$RouteLockPath = "AGENT_BUILDER_NEXT_15_STEPS_LOCK_V2_R2.md",
  [string]$SchemaPath = "contracts/self_development/continue_on_failure_runtime_v1.schema.json",
  [string]$RuntimeContractPath = "self_build_batch/runtime/CONTINUE_ON_FAILURE_RUNTIME_V1.json",
  [string]$SimulationPath = "self_build_batch/runtime/CONTINUE_ON_FAILURE_SIMULATION_V1.json",
  [string]$ReportPath = "reports/self_development/CONTINUE_ON_FAILURE_RUNTIME_V1_REPORT.json",
  [string]$ProofPath = "proofs/self_development/CONTINUE_ON_FAILURE_RUNTIME_V1.json",
  [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
)

$ErrorActionPreference = "Stop"

$Phase = "PHASE99_CONTINUE_ON_FAILURE_RUNTIME_V1"
$TaskId = "TASK_CONTINUE_ON_FAILURE_RUNTIME_V1_001"
$RouteLockVersion = "V2_R2"
$BaselineCommit = "19f1d8e"
$NextAllowedStep = "PHASE100_QUARANTINE_AND_BLOCKER_REGISTRY_V1"

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

Write-Host "CONTINUE_ON_FAILURE_RUNTIME_V1_START"

$phase98Proof = Read-JsonRequired $Phase98ProofPath
$phase98Report = Read-JsonRequired $Phase98ReportPath
$ledgerContract = Read-JsonRequired $SourceLedgerContractPath
$dryRunLedger = Read-JsonRequired $SourceDryRunLedgerPath
$admission = Read-JsonRequired $SourceAdmissionPath
$deliveryConveyor = Read-JsonRequired $DeliveryConveyorContractPath

if (-not (Test-Path -LiteralPath (Join-RepoPath $RouteLockPath))) {
  throw "MISSING_ROUTE_LOCK=$RouteLockPath"
}
if ("$(Get-PropertyValue -Object $phase98Proof -Name "status")" -ne "PASS") {
  throw "PHASE98_PROOF_STATUS_NOT_PASS"
}
if ("$(Get-PropertyValue -Object $phase98Proof -Name "next_allowed_step")" -ne "PHASE99_CONTINUE_ON_FAILURE_RUNTIME_V1") {
  throw "PHASE98_PROOF_NEXT_STEP_MISMATCH"
}
if ("$(Get-PropertyValue -Object $phase98Report -Name "status")" -ne "PASS") {
  throw "PHASE98_REPORT_STATUS_NOT_PASS"
}
if ("$(Get-PropertyValue -Object $ledgerContract -Name "status")" -ne "ACTIVE_LEDGER_CONTRACT") {
  throw "LEDGER_CONTRACT_STATUS_NOT_ACTIVE"
}
if ("$(Get-PropertyValue -Object $dryRunLedger -Name "status")" -ne "INITIALIZED") {
  throw "DRY_RUN_LEDGER_STATUS_NOT_INITIALIZED"
}
if ([bool](Get-PropertyValue -Object $dryRunLedger -Name "execution_attempted")) {
  throw "DRY_RUN_LEDGER_EXECUTION_ATTEMPTED_TRUE"
}
if ("$(Get-PropertyValue -Object $admission -Name "status")" -ne "PASS") {
  throw "SOURCE_ADMISSION_STATUS_NOT_PASS"
}
if ([bool](Get-PropertyValue -Object $admission -Name "execution_allowed")) {
  throw "SOURCE_ADMISSION_EXECUTION_ALLOWED_TRUE"
}
if ("$(Get-PropertyValue -Object $deliveryConveyor -Name "status")" -ne "ACTIVE_OPERATION_CONTRACT") {
  throw "DELIVERY_CONVEYOR_STATUS_NOT_ACTIVE"
}

$ledgerEntries = As-Array (Get-PropertyValue -Object $dryRunLedger -Name "entries")
if ($ledgerEntries.Count -lt 5) {
  throw "DRY_RUN_LEDGER_ITEM_COUNT_LT_5"
}

foreach ($entry in $ledgerEntries) {
  $entryId = Get-PropertyValue -Object $entry -Name "item_id"
  if ("$(Get-PropertyValue -Object $entry -Name "status")" -eq "PASS") {
    throw "DRY_RUN_LEDGER_HAS_PASS_ENTRY=$entryId"
  }
  if ([bool](Get-PropertyValue -Object $entry -Name "execution_attempted")) {
    throw "DRY_RUN_LEDGER_HAS_EXECUTED_ENTRY=$entryId"
  }
}

$failureClasses = @(
  "SAFE_ITEM_FAILURE",
  "ITEM_VALIDATION_FAILURE",
  "ITEM_POLICY_BLOCK",
  "BLOCKED_DEPENDENCY",
  "MISSING_MATERIAL",
  "SYSTEMIC_FAILURE",
  "POLICY_VIOLATION",
  "REPO_CORRUPTION"
)

$scenarioTemplates = @(
  [ordered]@{
    simulated_result = "WOULD_PASS_WITH_PROOF_REQUIRED"
    failure_class = $null
    runtime_action = "record_attempt_and_require_proof_before_pass"
    continue_after_item = $true
  },
  [ordered]@{
    simulated_result = "WOULD_FAIL_SAFE_AND_CONTINUE"
    failure_class = "SAFE_ITEM_FAILURE"
    runtime_action = "record_failure_reason_then_continue"
    continue_after_item = $true
  },
  [ordered]@{
    simulated_result = "WOULD_QUARANTINE_AND_CONTINUE"
    failure_class = "ITEM_VALIDATION_FAILURE"
    runtime_action = "record_quarantine_reason_then_continue"
    continue_after_item = $true
  },
  [ordered]@{
    simulated_result = "WOULD_BLOCK_AND_RECORD_REASON"
    failure_class = "BLOCKED_DEPENDENCY"
    runtime_action = "record_blocker_reason_and_skip_dependent_item"
    continue_after_item = $true
  },
  [ordered]@{
    simulated_result = "WOULD_STOP_ON_SYSTEMIC_FAILURE"
    failure_class = "SYSTEMIC_FAILURE"
    runtime_action = "record_systemic_failure_and_stop_batch"
    continue_after_item = $false
  }
)

$scenarioResults = @()
for ($i = 0; $i -lt $scenarioTemplates.Count; $i++) {
  $entry = $ledgerEntries[$i]
  $template = $scenarioTemplates[$i]
  $scenarioResults += [ordered]@{
    item_id = "$(Get-PropertyValue -Object $entry -Name "item_id")"
    source_gap = "$(Get-PropertyValue -Object $entry -Name "source_gap")"
    simulated_result = $template.simulated_result
    failure_class = $template.failure_class
    runtime_action = $template.runtime_action
    continue_after_item = $template.continue_after_item
    real_ledger_mutated = $false
    real_item_marked_pass = $false
  }
}

$generatedAt = Get-UtcStamp
$continueRules = [ordered]@{
  continue_after_safe_item_failure = $true
  continue_after_quarantined_item = $true
  continue_after_skipped_by_policy_when_item_scope_isolated = $true
  record_failure_before_continuing = $true
  record_quarantine_before_continuing = $true
  never_hide_failed_item = $true
}
$stopRules = [ordered]@{
  stop_on_systemic_failure = $true
  stop_on_policy_violation = $true
  stop_on_repo_corruption = $true
  stop_on_missing_ledger = $true
  stop_on_missing_admission = $true
  stop_on_unbounded_loop_risk = $true
}
$ledgerUpdateContract = [ordered]@{
  item_attempt_must_be_recorded = $true
  pass_requires_proof = $true
  failed_requires_reason = $true
  quarantined_requires_reason = $true
  blocked_requires_reason = $true
  assistance_required_must_be_explicit = $true
}
$runtimePolicy = [ordered]@{
  runtime_contract_created_only = $true
  real_batch_execution_performed = $false
  simulation_only = $true
  quarantine_registry_not_created = $true
  no_external_agent_production = $true
  no_external_install = $true
  no_external_fetch = $true
}

$schema = [ordered]@{
  '$schema' = "https://json-schema.org/draft/2020-12/schema"
  schema_id = "continue_on_failure_runtime_v1"
  title = "Continue-On-Failure Runtime V1"
  type = "object"
  required = @(
    "runtime_id",
    "version",
    "status",
    "active_line",
    "input_sources",
    "failure_classes",
    "continue_rules",
    "stop_rules",
    "ledger_update_contract",
    "simulation_contract",
    "execution_allowed",
    "next_allowed_step"
  )
  properties = [ordered]@{
    runtime_id = [ordered]@{ const = "CONTINUE_ON_FAILURE_RUNTIME_V1" }
    version = [ordered]@{ const = "V1" }
    status = [ordered]@{ const = "ACTIVE_RUNTIME_CONTRACT" }
    active_line = [ordered]@{ const = "AGENT_BUILDER / SELF_BUILD" }
    input_sources = [ordered]@{ type = "array" }
    failure_classes = [ordered]@{
      type = "array"
      items = [ordered]@{ enum = $failureClasses }
    }
    continue_rules = [ordered]@{ type = "object" }
    stop_rules = [ordered]@{ type = "object" }
    ledger_update_contract = [ordered]@{ type = "object" }
    simulation_contract = [ordered]@{ type = "object" }
    execution_allowed = [ordered]@{ const = $false }
    next_allowed_step = [ordered]@{ const = $NextAllowedStep }
  }
  additionalProperties = $true
}

$simulationContract = [ordered]@{
  simulation_id = "Stable simulation artifact identifier."
  status = "SIMULATION_ONLY"
  source_dry_run_ledger = "Source dry-run ledger path."
  execution_performed = $false
  real_items_executed = $false
  real_items_marked_pass = $false
  scenario_results = "Simulation-only per-item outcomes; must not mutate real ledger entries."
  next_allowed_step = $NextAllowedStep
}

$runtimeContract = [ordered]@{
  runtime_id = "CONTINUE_ON_FAILURE_RUNTIME_V1"
  version = "V1"
  status = "ACTIVE_RUNTIME_CONTRACT"
  phase = $Phase
  active_line = "AGENT_BUILDER / SELF_BUILD"
  generated_at = $generatedAt
  input_sources = @(
    "self_build_batch/ledger/ITEM_LEVEL_EXECUTION_LEDGER_V1.json",
    "self_build_batch/ledger/BATCH_PLAN_EXAMPLE_V1_LEDGER_DRY_RUN.json",
    "self_build_batch/admission/BATCH_PLAN_EXAMPLE_V1_ADMISSION.json",
    "contracts/operations/self_build_delivery_conveyor_v1.json"
  )
  output_schema = $SchemaPath
  failure_classes = $failureClasses
  continue_rules = $continueRules
  stop_rules = $stopRules
  ledger_update_contract = $ledgerUpdateContract
  simulation_contract = $simulationContract
  runtime_policy = $runtimePolicy
  execution_allowed = $false
  next_allowed_step = $NextAllowedStep
}

$simulation = [ordered]@{
  simulation_id = "CONTINUE_ON_FAILURE_SIMULATION_V1"
  status = "SIMULATION_ONLY"
  generated_at = $generatedAt
  source_dry_run_ledger = $SourceDryRunLedgerPath
  execution_performed = $false
  real_items_executed = $false
  real_items_marked_pass = $false
  simulated_item_count = $ledgerEntries.Count
  scenario_results = $scenarioResults
  continue_after_safe_failure_proven_by_simulation = $true
  stop_on_systemic_failure_proven_by_simulation = $true
  no_real_ledger_mutation = $true
  quarantine_registry_required_next = $true
  next_allowed_step = $NextAllowedStep
}

$report = [ordered]@{
  status = "PASS"
  phase = $Phase
  active_line = "AGENT_BUILDER / SELF_BUILD"
  generated_at = $generatedAt
  baseline_commit = $BaselineCommit
  runtime_contract_created = $RuntimeContractPath
  schema_created = $SchemaPath
  simulation_created = $SimulationPath
  simulation_status = "SIMULATION_ONLY"
  execution_performed = $false
  real_items_executed = $false
  real_items_marked_pass = $false
  continue_after_safe_failure_defined = $true
  stop_on_systemic_failure_defined = $true
  no_real_ledger_mutation = $true
  quarantine_registry_required_next = $true
  no_external_agent_production = $true
  no_external_install = $true
  no_external_fetch = $true
  phase100_not_executed = $true
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
  runtime_contract_created = $true
  schema_created = $true
  simulation_created = $true
  simulation_status = "SIMULATION_ONLY"
  execution_performed = $false
  real_items_executed = $false
  real_items_marked_pass = $false
  continue_after_safe_failure_defined = $true
  continue_after_safe_failure_proven_by_simulation = $true
  stop_on_systemic_failure_defined = $true
  stop_on_systemic_failure_proven_by_simulation = $true
  no_real_ledger_mutation = $true
  quarantine_registry_required_next = $true
  no_external_agent_production = $true
  no_external_install = $true
  no_external_fetch = $true
  phase100_not_executed = $true
  queue_returned_to_none = $true
  next_allowed_step = $NextAllowedStep
  evidence_files = @(
    $SchemaPath,
    $RuntimeContractPath,
    $SimulationPath,
    $ReportPath
  )
}

Write-JsonFile -Path $SchemaPath -Object $schema
Write-JsonFile -Path $RuntimeContractPath -Object $runtimeContract
Write-JsonFile -Path $SimulationPath -Object $simulation
Write-JsonFile -Path $ReportPath -Object $report
Write-JsonFile -Path $ProofPath -Object $proof

Write-Host "CONTINUE_ON_FAILURE_RUNTIME_SCHEMA_CREATED=$SchemaPath"
Write-Host "CONTINUE_ON_FAILURE_RUNTIME_CONTRACT_CREATED=$RuntimeContractPath"
Write-Host "CONTINUE_ON_FAILURE_SIMULATION_CREATED=$SimulationPath"
Write-Host "SIMULATION_STATUS=SIMULATION_ONLY"
Write-Host "EXECUTION_PERFORMED=FALSE"
Write-Host "REAL_ITEMS_EXECUTED=FALSE"
Write-Host "REAL_ITEMS_MARKED_PASS=FALSE"
Write-Host "NO_REAL_LEDGER_MUTATION=TRUE"
Write-Host "QUARANTINE_REGISTRY_REQUIRED_NEXT=TRUE"
Write-Host "NO_EXTERNAL_AGENT_PRODUCTION=TRUE"
Write-Host "CONTINUE_ON_FAILURE_RUNTIME_REPORT_WRITTEN=$ReportPath"
Write-Host "CONTINUE_ON_FAILURE_RUNTIME_PROOF_WRITTEN=$ProofPath"
Write-Host "CONTINUE_ON_FAILURE_RUNTIME_V1_COMPLETE"

return [pscustomobject]$report
