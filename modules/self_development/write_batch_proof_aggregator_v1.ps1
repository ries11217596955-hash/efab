[CmdletBinding()]
param(
  [string]$Phase100ProofPath = "proofs/self_development/QUARANTINE_AND_BLOCKER_REGISTRY_V1.json",
  [string]$Phase100ReportPath = "reports/self_development/QUARANTINE_AND_BLOCKER_REGISTRY_V1_REPORT.json",
  [string]$SourceLedgerPath = "self_build_batch/ledger/BATCH_PLAN_EXAMPLE_V1_LEDGER_DRY_RUN.json",
  [string]$SourceRuntimeSimulationPath = "self_build_batch/runtime/CONTINUE_ON_FAILURE_SIMULATION_V1.json",
  [string]$SourceQuarantineRegistryPath = "self_build_batch/quarantine/BATCH_PLAN_EXAMPLE_V1_QUARANTINE_BLOCKER_DRY_RUN.json",
  [string]$ItemLedgerProofPath = "proofs/self_development/ITEM_LEVEL_EXECUTION_LEDGER_V1.json",
  [string]$RuntimeProofPath = "proofs/self_development/CONTINUE_ON_FAILURE_RUNTIME_V1.json",
  [string]$QuarantineProofPath = "proofs/self_development/QUARANTINE_AND_BLOCKER_REGISTRY_V1.json",
  [string]$RouteLockPath = "AGENT_BUILDER_NEXT_15_STEPS_LOCK_V2_R2.md",
  [string]$SchemaPath = "contracts/self_development/batch_proof_aggregator_v1.schema.json",
  [string]$AggregatorContractPath = "self_build_batch/proof_aggregation/BATCH_PROOF_AGGREGATOR_V1.json",
  [string]$DryRunSummaryPath = "self_build_batch/proof_aggregation/BATCH_PLAN_EXAMPLE_V1_PROOF_SUMMARY_DRY_RUN.json",
  [string]$ReportPath = "reports/self_development/BATCH_PROOF_AGGREGATOR_V1_REPORT.json",
  [string]$ProofPath = "proofs/self_development/BATCH_PROOF_AGGREGATOR_V1.json",
  [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
)

$ErrorActionPreference = "Stop"

$Phase = "PHASE101_BATCH_PROOF_AGGREGATOR_V1"
$TaskId = "TASK_BATCH_PROOF_AGGREGATOR_V1_001"
$RouteLockVersion = "V2_R2"
$BaselineCommit = "4b0635a"
$NextAllowedStep = "PHASE102_AUTO_NEXT_GAP_DECISION_V1"

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

function Get-SafeCount {
  param([object]$Value)

  return @($Value).Count
}

function Convert-UnresolvedRecord {
  param([object]$Record)

  return [pscustomobject][ordered]@{
    record_id = "$(Get-PropertyValue -Object $Record -Name "record_id")"
    item_id = "$(Get-PropertyValue -Object $Record -Name "item_id")"
    source_gap = "$(Get-PropertyValue -Object $Record -Name "source_gap")"
    record_type = "$(Get-PropertyValue -Object $Record -Name "record_type")"
    status = "$(Get-PropertyValue -Object $Record -Name "status")"
    reason = "$(Get-PropertyValue -Object $Record -Name "reason")"
    evidence_paths = As-Array (Get-PropertyValue -Object $Record -Name "evidence_paths")
    related_proof_or_report = "$(Get-PropertyValue -Object $Record -Name "related_proof_or_report")"
    assistance_required = As-Array (Get-PropertyValue -Object $Record -Name "assistance_required")
    next_action = "$(Get-PropertyValue -Object $Record -Name "next_action")"
  }
}

Write-Host "BATCH_PROOF_AGGREGATOR_V1_START"

$phase100Proof = Read-JsonRequired $Phase100ProofPath
$phase100Report = Read-JsonRequired $Phase100ReportPath
$ledger = Read-JsonRequired $SourceLedgerPath
$simulation = Read-JsonRequired $SourceRuntimeSimulationPath
$quarantineRegistry = Read-JsonRequired $SourceQuarantineRegistryPath
$itemLedgerProof = Read-JsonRequired $ItemLedgerProofPath
$runtimeProof = Read-JsonRequired $RuntimeProofPath
$quarantineProof = Read-JsonRequired $QuarantineProofPath

if (-not (Test-Path -LiteralPath (Join-RepoPath $RouteLockPath))) {
  throw "MISSING_ROUTE_LOCK=$RouteLockPath"
}
if ("$(Get-PropertyValue -Object $phase100Proof -Name "status")" -ne "PASS") {
  throw "PHASE100_PROOF_STATUS_NOT_PASS"
}
if ("$(Get-PropertyValue -Object $phase100Proof -Name "next_allowed_step")" -ne "PHASE101_BATCH_PROOF_AGGREGATOR_V1") {
  throw "PHASE100_PROOF_NEXT_STEP_MISMATCH"
}
if ("$(Get-PropertyValue -Object $phase100Report -Name "status")" -ne "PASS") {
  throw "PHASE100_REPORT_STATUS_NOT_PASS"
}
foreach ($proofInfo in @(
  [pscustomobject]@{ Name = "ITEM_LEVEL_EXECUTION_LEDGER_V1"; Proof = $itemLedgerProof },
  [pscustomobject]@{ Name = "CONTINUE_ON_FAILURE_RUNTIME_V1"; Proof = $runtimeProof },
  [pscustomobject]@{ Name = "QUARANTINE_AND_BLOCKER_REGISTRY_V1"; Proof = $quarantineProof }
)) {
  if ("$(Get-PropertyValue -Object $proofInfo.Proof -Name "status")" -ne "PASS") {
    throw "$($proofInfo.Name)_PROOF_STATUS_NOT_PASS"
  }
}

if ("$(Get-PropertyValue -Object $ledger -Name "status")" -ne "INITIALIZED") {
  throw "SOURCE_LEDGER_STATUS_NOT_INITIALIZED"
}
if ([bool](Get-PropertyValue -Object $ledger -Name "execution_attempted")) {
  throw "SOURCE_LEDGER_EXECUTION_ATTEMPTED_TRUE"
}
if ("$(Get-PropertyValue -Object $simulation -Name "status")" -ne "SIMULATION_ONLY") {
  throw "SOURCE_SIMULATION_STATUS_NOT_SIMULATION_ONLY"
}
foreach ($falseField in @("execution_performed", "real_items_executed", "real_items_marked_pass")) {
  if ([bool](Get-PropertyValue -Object $simulation -Name $falseField)) {
    throw "SOURCE_SIMULATION_$($falseField.ToUpperInvariant())_TRUE"
  }
}
if ("$(Get-PropertyValue -Object $quarantineRegistry -Name "status")" -ne "DRY_RUN_INITIALIZED") {
  throw "SOURCE_QUARANTINE_REGISTRY_STATUS_NOT_INITIALIZED"
}
foreach ($falseField in @("execution_performed", "real_items_executed", "real_items_marked_pass")) {
  if ([bool](Get-PropertyValue -Object $quarantineRegistry -Name $falseField)) {
    throw "SOURCE_QUARANTINE_REGISTRY_$($falseField.ToUpperInvariant())_TRUE"
  }
}

$ledgerEntries = @(As-Array (Get-PropertyValue -Object $ledger -Name "entries"))
$unresolvedRecordsRaw = @(As-Array (Get-PropertyValue -Object $quarantineRegistry -Name "records"))
$ledgerEntryCount = Get-SafeCount $ledgerEntries
$unresolvedRecordsRawCount = Get-SafeCount $unresolvedRecordsRaw
$totalItemCount = [int](Get-PropertyValue -Object $ledger -Name "item_count")
if ($totalItemCount -lt $ledgerEntryCount) {
  $totalItemCount = $ledgerEntryCount
}
if ($totalItemCount -lt 5) {
  throw "TOTAL_ITEM_COUNT_LT_5"
}

$plannedEntries = @($ledgerEntries | Where-Object { "$(Get-PropertyValue -Object $_ -Name "status")" -eq "PLANNED" })
$passEntries = @($ledgerEntries | Where-Object { "$(Get-PropertyValue -Object $_ -Name "status")" -eq "PASS" })
$executedEntries = @($ledgerEntries | Where-Object { [bool](Get-PropertyValue -Object $_ -Name "execution_attempted") })
$registryPassRecords = @($unresolvedRecordsRaw | Where-Object { "$(Get-PropertyValue -Object $_ -Name "status")" -eq "PASS" })
$plannedCount = Get-SafeCount $plannedEntries
$passCount = Get-SafeCount $passEntries
$executedEntryCount = Get-SafeCount $executedEntries
$registryPassRecordCount = Get-SafeCount $registryPassRecords
if ($passCount -ne 0) {
  throw "SOURCE_LEDGER_HAS_PASS_ENTRY"
}
if ($executedEntryCount -ne 0) {
  throw "SOURCE_LEDGER_HAS_EXECUTED_ENTRY"
}
if ($registryPassRecordCount -ne 0) {
  throw "SOURCE_QUARANTINE_REGISTRY_HAS_PASS_RECORD"
}

$failedRecords = @($unresolvedRecordsRaw | Where-Object { "$(Get-PropertyValue -Object $_ -Name "status")" -eq "FAILED" })
$quarantinedRecords = @($unresolvedRecordsRaw | Where-Object { "$(Get-PropertyValue -Object $_ -Name "status")" -eq "QUARANTINED" })
$blockedRecords = @($unresolvedRecordsRaw | Where-Object { "$(Get-PropertyValue -Object $_ -Name "status")" -eq "BLOCKED" })
$failedCount = Get-SafeCount $failedRecords
$quarantinedCount = Get-SafeCount $quarantinedRecords
$blockedCount = Get-SafeCount $blockedRecords
$assistanceStatuses = @("NEEDS_OWNER_DECISION", "NEEDS_CODEX_REPAIR", "NEEDS_MATERIAL")
$assistanceRequiredRecords = @(
  $unresolvedRecordsRaw | Where-Object {
    $status = "$(Get-PropertyValue -Object $_ -Name "status")"
    $assistance = @(As-Array (Get-PropertyValue -Object $_ -Name "assistance_required"))
    ($assistanceStatuses -contains $status) -or ((Get-SafeCount $assistance) -gt 0)
  }
)
$assistanceRequiredCount = Get-SafeCount $assistanceRequiredRecords
$unresolvedRecordCount = [int](Get-PropertyValue -Object $quarantineRegistry -Name "record_count")
if ($unresolvedRecordCount -lt $unresolvedRecordsRawCount) {
  $unresolvedRecordCount = $unresolvedRecordsRawCount
}

if ($failedCount -lt 1) { throw "FAILED_COUNT_LT_1" }
if ($quarantinedCount -lt 1) { throw "QUARANTINED_COUNT_LT_1" }
if ($blockedCount -lt 1) { throw "BLOCKED_COUNT_LT_1" }
if ($assistanceRequiredCount -lt 1) { throw "ASSISTANCE_REQUIRED_COUNT_LT_1" }
if ($unresolvedRecordCount -lt 4) { throw "UNRESOLVED_RECORD_COUNT_LT_4" }

$unresolvedRecords = @($unresolvedRecordsRaw | ForEach-Object { Convert-UnresolvedRecord -Record $_ })
$evidenceManifest = @(
  $ItemLedgerProofPath,
  $RuntimeProofPath,
  $QuarantineProofPath,
  $SourceLedgerPath,
  $SourceRuntimeSimulationPath,
  $SourceQuarantineRegistryPath
)
$statusCounts = [ordered]@{
  total_item_count = $totalItemCount
  planned_count = $plannedCount
  pass_count = 0
  failed_count = $failedCount
  quarantined_count = $quarantinedCount
  blocked_count = $blockedCount
  assistance_required_count = $assistanceRequiredCount
  unresolved_record_count = $unresolvedRecordCount
}

$generatedAt = Get-UtcStamp
$aggregationPolicy = [ordered]@{
  aggregate_batch_level_summary = $true
  no_fake_pass = $true
  no_hidden_failures = $true
  failed_items_must_be_counted = $true
  quarantined_items_must_be_counted = $true
  blocked_items_must_be_counted = $true
  unresolved_records_must_be_listed = $true
  evidence_manifest_required = $true
  aggregator_does_not_execute_items = $true
  aggregator_does_not_mark_pass = $true
  auto_next_gap_decision_required_next = $true
  no_external_agent_production = $true
  no_external_install = $true
  no_external_fetch = $true
}

$schema = [ordered]@{
  '$schema' = "https://json-schema.org/draft/2020-12/schema"
  schema_id = "batch_proof_aggregator_v1"
  title = "Batch Proof Aggregator V1"
  type = "object"
  required = @(
    "aggregator_id",
    "version",
    "status",
    "active_line",
    "input_sources",
    "aggregation_policy",
    "summary_contract",
    "status_counts",
    "evidence_manifest",
    "unresolved_records",
    "execution_performed",
    "next_allowed_step"
  )
  properties = [ordered]@{
    aggregator_id = [ordered]@{ type = "string" }
    version = [ordered]@{ const = "V1" }
    status = [ordered]@{ type = "string" }
    active_line = [ordered]@{ const = "AGENT_BUILDER / SELF_BUILD" }
    input_sources = [ordered]@{ type = "array" }
    aggregation_policy = [ordered]@{ type = "object" }
    summary_contract = [ordered]@{
      type = "object"
      required = @(
        "summary_id",
        "status",
        "source_ledger",
        "source_runtime_simulation",
        "source_quarantine_registry",
        "execution_performed",
        "real_items_executed",
        "real_items_marked_pass",
        "total_item_count",
        "planned_count",
        "pass_count",
        "failed_count",
        "quarantined_count",
        "blocked_count",
        "assistance_required_count",
        "unresolved_record_count",
        "no_fake_pass",
        "no_hidden_failures",
        "evidence_manifest",
        "unresolved_records",
        "next_allowed_step"
      )
    }
    status_counts = [ordered]@{ type = "object" }
    evidence_manifest = [ordered]@{ type = "array" }
    unresolved_records = [ordered]@{ type = "array" }
    execution_performed = [ordered]@{ const = $false }
    next_allowed_step = [ordered]@{ const = $NextAllowedStep }
  }
  additionalProperties = $true
}

$inputSources = @(
  "self_build_batch/ledger/BATCH_PLAN_EXAMPLE_V1_LEDGER_DRY_RUN.json",
  "self_build_batch/runtime/CONTINUE_ON_FAILURE_SIMULATION_V1.json",
  "self_build_batch/quarantine/BATCH_PLAN_EXAMPLE_V1_QUARANTINE_BLOCKER_DRY_RUN.json",
  "proofs/self_development/ITEM_LEVEL_EXECUTION_LEDGER_V1.json",
  "proofs/self_development/CONTINUE_ON_FAILURE_RUNTIME_V1.json",
  "proofs/self_development/QUARANTINE_AND_BLOCKER_REGISTRY_V1.json"
)

$summaryContract = [ordered]@{
  summary_id = "BATCH_PLAN_EXAMPLE_V1_PROOF_SUMMARY_DRY_RUN"
  status = "DRY_RUN_AGGREGATED"
  source_ledger = $SourceLedgerPath
  source_runtime_simulation = $SourceRuntimeSimulationPath
  source_quarantine_registry = $SourceQuarantineRegistryPath
  execution_performed = $false
  real_items_executed = $false
  real_items_marked_pass = $false
  total_item_count = $totalItemCount
  planned_count = $plannedCount
  pass_count = 0
  failed_count = $failedCount
  quarantined_count = $quarantinedCount
  blocked_count = $blockedCount
  assistance_required_count = $assistanceRequiredCount
  unresolved_record_count = $unresolvedRecordCount
  no_fake_pass = $true
  no_hidden_failures = $true
  evidence_manifest = $evidenceManifest
  unresolved_records = $unresolvedRecords
  next_allowed_step = $NextAllowedStep
}

$aggregatorContract = [ordered]@{
  aggregator_id = "BATCH_PROOF_AGGREGATOR_V1"
  version = "V1"
  status = "ACTIVE_AGGREGATOR_CONTRACT"
  phase = $Phase
  active_line = "AGENT_BUILDER / SELF_BUILD"
  generated_at = $generatedAt
  input_sources = $inputSources
  output_schema = $SchemaPath
  aggregation_policy = $aggregationPolicy
  summary_contract = $summaryContract
  status_counts = $statusCounts
  evidence_manifest = $evidenceManifest
  unresolved_records = $unresolvedRecords
  execution_performed = $false
  next_allowed_step = $NextAllowedStep
}

$dryRunSummary = [ordered]@{
  summary_id = "BATCH_PLAN_EXAMPLE_V1_PROOF_SUMMARY_DRY_RUN"
  version = "V1"
  status = "DRY_RUN_AGGREGATED"
  active_line = "AGENT_BUILDER / SELF_BUILD"
  generated_at = $generatedAt
  source_ledger = $SourceLedgerPath
  source_runtime_simulation = $SourceRuntimeSimulationPath
  source_quarantine_registry = $SourceQuarantineRegistryPath
  execution_performed = $false
  real_items_executed = $false
  real_items_marked_pass = $false
  total_item_count = $totalItemCount
  planned_count = $plannedCount
  pass_count = 0
  failed_count = $failedCount
  quarantined_count = $quarantinedCount
  blocked_count = $blockedCount
  assistance_required_count = $assistanceRequiredCount
  unresolved_record_count = $unresolvedRecordCount
  no_fake_pass = $true
  no_hidden_failures = $true
  evidence_manifest = $evidenceManifest
  unresolved_records = $unresolvedRecords
  next_allowed_step = $NextAllowedStep
}

$report = [ordered]@{
  status = "PASS"
  phase = $Phase
  active_line = "AGENT_BUILDER / SELF_BUILD"
  generated_at = $generatedAt
  baseline_commit = $BaselineCommit
  aggregator_contract_created = $AggregatorContractPath
  schema_created = $SchemaPath
  dry_run_summary_created = $DryRunSummaryPath
  dry_run_summary_status = "DRY_RUN_AGGREGATED"
  execution_performed = $false
  real_items_executed = $false
  real_items_marked_pass = $false
  total_item_count = $totalItemCount
  pass_count = 0
  failed_count = $failedCount
  quarantined_count = $quarantinedCount
  blocked_count = $blockedCount
  assistance_required_count = $assistanceRequiredCount
  unresolved_record_count = $unresolvedRecordCount
  no_fake_pass = $true
  no_hidden_failures = $true
  aggregator_does_not_execute_items = $true
  aggregator_does_not_mark_pass = $true
  auto_next_gap_decision_required_next = $true
  no_external_agent_production = $true
  no_external_install = $true
  no_external_fetch = $true
  phase102_not_executed = $true
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
  aggregator_contract_created = $true
  schema_created = $true
  dry_run_summary_created = $true
  dry_run_summary_status = "DRY_RUN_AGGREGATED"
  execution_performed = $false
  real_items_executed = $false
  real_items_marked_pass = $false
  total_item_count = $totalItemCount
  pass_count = 0
  failed_count = $failedCount
  quarantined_count = $quarantinedCount
  blocked_count = $blockedCount
  assistance_required_count = $assistanceRequiredCount
  unresolved_record_count = $unresolvedRecordCount
  no_fake_pass = $true
  no_hidden_failures = $true
  aggregator_does_not_execute_items = $true
  aggregator_does_not_mark_pass = $true
  auto_next_gap_decision_required_next = $true
  no_external_agent_production = $true
  no_external_install = $true
  no_external_fetch = $true
  phase102_not_executed = $true
  queue_returned_to_none = $true
  next_allowed_step = $NextAllowedStep
  evidence_files = @(
    $SchemaPath,
    $AggregatorContractPath,
    $DryRunSummaryPath,
    $ReportPath,
    $ItemLedgerProofPath,
    $RuntimeProofPath,
    $QuarantineProofPath
  )
}

Write-JsonFile -Path $SchemaPath -Object $schema
Write-JsonFile -Path $AggregatorContractPath -Object $aggregatorContract
Write-JsonFile -Path $DryRunSummaryPath -Object $dryRunSummary
Write-JsonFile -Path $ReportPath -Object $report
Write-JsonFile -Path $ProofPath -Object $proof

Write-Host "BATCH_PROOF_AGGREGATOR_SCHEMA_CREATED=$SchemaPath"
Write-Host "BATCH_PROOF_AGGREGATOR_CONTRACT_CREATED=$AggregatorContractPath"
Write-Host "BATCH_PROOF_SUMMARY_DRY_RUN_CREATED=$DryRunSummaryPath"
Write-Host "DRY_RUN_SUMMARY_STATUS=DRY_RUN_AGGREGATED"
Write-Host "EXECUTION_PERFORMED=FALSE"
Write-Host "REAL_ITEMS_EXECUTED=FALSE"
Write-Host "REAL_ITEMS_MARKED_PASS=FALSE"
Write-Host "PASS_COUNT=0"
Write-Host "NO_FAKE_PASS=TRUE"
Write-Host "NO_HIDDEN_FAILURES=TRUE"
Write-Host "NO_EXTERNAL_AGENT_PRODUCTION=TRUE"
Write-Host "BATCH_PROOF_AGGREGATOR_REPORT_WRITTEN=$ReportPath"
Write-Host "BATCH_PROOF_AGGREGATOR_PROOF_WRITTEN=$ProofPath"
Write-Host "BATCH_PROOF_AGGREGATOR_V1_COMPLETE"

return [pscustomobject]$report
