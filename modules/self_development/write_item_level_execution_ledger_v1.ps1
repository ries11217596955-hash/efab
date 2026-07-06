[CmdletBinding()]
param(
  [string]$Phase97ProofPath = "proofs/self_development/BATCH_ADMISSION_POLICY_V1.json",
  [string]$Phase97ReportPath = "reports/self_development/BATCH_ADMISSION_POLICY_V1_REPORT.json",
  [string]$SourceAdmissionPath = "self_build_batch/admission/BATCH_PLAN_EXAMPLE_V1_ADMISSION.json",
  [string]$SourcePlanPath = "self_build_batch/plans/BATCH_PLAN_EXAMPLE_V1.json",
  [string]$BacklogContractPath = "self_build_backlog/SELF_BUILD_BACKLOG_CONTRACT_V1.json",
  [string]$RouteLockPath = "AGENT_BUILDER_NEXT_15_STEPS_LOCK_V2_R2.md",
  [string]$SchemaPath = "contracts/self_development/item_level_execution_ledger_v1.schema.json",
  [string]$LedgerContractPath = "self_build_batch/ledger/ITEM_LEVEL_EXECUTION_LEDGER_V1.json",
  [string]$DryRunLedgerPath = "self_build_batch/ledger/BATCH_PLAN_EXAMPLE_V1_LEDGER_DRY_RUN.json",
  [string]$DeliveryConveyorContractPath = "contracts/operations/self_build_delivery_conveyor_v1.json",
  [string]$DeliveryConveyorDocPath = "docs/operations/SELF_BUILD_DELIVERY_CONVEYOR_V1.md",
  [string]$ReportPath = "reports/self_development/ITEM_LEVEL_EXECUTION_LEDGER_V1_REPORT.json",
  [string]$ProofPath = "proofs/self_development/ITEM_LEVEL_EXECUTION_LEDGER_V1.json",
  [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
)

$ErrorActionPreference = "Stop"

$Phase = "PHASE98_ITEM_LEVEL_EXECUTION_LEDGER_V1"
$TaskId = "TASK_ITEM_LEVEL_EXECUTION_LEDGER_V1_001"
$RouteLockVersion = "V2_R2"
$BaselineCommit = "4b4e7c1"
$NextAllowedStep = "PHASE99_CONTINUE_ON_FAILURE_RUNTIME_V1"

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

function Write-TextFile {
  param(
    [string]$Path,
    [string]$Text
  )

  $fullPath = Join-RepoPath $Path
  $directory = Split-Path -Parent $fullPath
  if (-not (Test-Path -LiteralPath $directory)) {
    New-Item -ItemType Directory -Path $directory -Force | Out-Null
  }
  if (-not $Text.EndsWith("`n")) {
    $Text += "`n"
  }
  [System.IO.File]::WriteAllText($fullPath, $Text, [System.Text.UTF8Encoding]::new($false))
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

Write-Host "ITEM_LEVEL_EXECUTION_LEDGER_V1_START"

$phase97Proof = Read-JsonRequired $Phase97ProofPath
$phase97Report = Read-JsonRequired $Phase97ReportPath
$admission = Read-JsonRequired $SourceAdmissionPath
$plan = Read-JsonRequired $SourcePlanPath
Read-JsonRequired $BacklogContractPath | Out-Null

if (-not (Test-Path -LiteralPath (Join-RepoPath $RouteLockPath))) {
  throw "MISSING_ROUTE_LOCK=$RouteLockPath"
}
if ("$(Get-PropertyValue -Object $phase97Proof -Name "status")" -ne "PASS") {
  throw "PHASE97_PROOF_STATUS_NOT_PASS"
}
if ("$(Get-PropertyValue -Object $phase97Proof -Name "next_allowed_step")" -ne "PHASE98_ITEM_LEVEL_EXECUTION_LEDGER_V1") {
  throw "PHASE97_PROOF_NEXT_STEP_MISMATCH"
}
if ("$(Get-PropertyValue -Object $phase97Report -Name "status")" -ne "PASS") {
  throw "PHASE97_REPORT_STATUS_NOT_PASS"
}
if ("$(Get-PropertyValue -Object $admission -Name "status")" -ne "PASS") {
  throw "SOURCE_ADMISSION_STATUS_NOT_PASS"
}
if ("$(Get-PropertyValue -Object $admission -Name "decision")" -ne "CONDITIONALLY_ADMISSIBLE") {
  throw "SOURCE_ADMISSION_DECISION_MISMATCH"
}
if ([bool](Get-PropertyValue -Object $admission -Name "execution_allowed")) {
  throw "SOURCE_ADMISSION_EXECUTION_ALLOWED_TRUE"
}
if ("$(Get-PropertyValue -Object $plan -Name "status")" -ne "PLANNED") {
  throw "SOURCE_PLAN_NOT_PLANNED"
}
if ([bool](Get-PropertyValue -Object $plan -Name "execution_allowed")) {
  throw "SOURCE_PLAN_EXECUTION_ALLOWED_TRUE"
}

$itemStatusValues = @(
  "PLANNED",
  "RUNNING",
  "PASS",
  "FAILED",
  "QUARANTINED",
  "BLOCKED",
  "NEEDS_OWNER_DECISION",
  "NEEDS_CODEX_REPAIR",
  "NEEDS_MATERIAL",
  "SKIPPED_BY_POLICY"
)

$generatedAt = Get-UtcStamp
$entries = @()
$passEntries = @()
$executedEntries = @()

foreach ($batch in As-Array (Get-PropertyValue -Object $plan -Name "batches")) {
  foreach ($item in As-Array (Get-PropertyValue -Object $batch -Name "items")) {
    $itemId = "$(Get-PropertyValue -Object $item -Name "item_id")"
    $sourceGap = "$(Get-PropertyValue -Object $item -Name "source_gap")"
    $status = "$(Get-PropertyValue -Object $item -Name "status")"
    if ([string]::IsNullOrWhiteSpace($itemId)) {
      throw "SOURCE_PLAN_ITEM_ID_MISSING"
    }
    if ([string]::IsNullOrWhiteSpace($sourceGap)) {
      throw "SOURCE_PLAN_ITEM_SOURCE_GAP_MISSING=$itemId"
    }
    if ($status -eq "PASS") {
      $passEntries += $itemId
    }
    if ([bool](Get-PropertyValue -Object $item -Name "execution_performed")) {
      $executedEntries += $itemId
    }
    $entries += [ordered]@{
      ledger_entry_id = "LEDGER_$itemId"
      item_id = $itemId
      source_gap = $sourceGap
      title = "$(Get-PropertyValue -Object $item -Name "title")"
      status = "PLANNED"
      execution_attempted = $false
      attempt_count = 0
      evidence_paths = @()
      validation_output = [ordered]@{
        status = "NOT_RUN"
        output_path = $null
      }
      proof_or_report_path = $null
      failure_reason = $null
      quarantine_reason = $null
      blocker_reason = $null
      assistance_required = As-Array (Get-PropertyValue -Object $item -Name "assistance_required")
      next_action = "AWAIT_CONTROLLED_RUNTIME"
      updated_at_policy = "Runtime must update this entry after each attempted item; dry-run ledger records no attempts."
    }
  }
}

if ($entries.Count -lt 5) {
  throw "SOURCE_PLAN_ITEM_COUNT_LT_5"
}
if ($passEntries.Count -gt 0) {
  throw "SOURCE_PLAN_HAS_PASS_ITEMS=$($passEntries -join ',')"
}
if ($executedEntries.Count -gt 0) {
  throw "SOURCE_PLAN_HAS_EXECUTED_ITEMS=$($executedEntries -join ',')"
}

$schema = [ordered]@{
  '$schema' = "https://json-schema.org/draft/2020-12/schema"
  schema_id = "item_level_execution_ledger_v1"
  title = "Item-Level Execution Ledger V1"
  type = "object"
  required = @(
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
  )
  properties = [ordered]@{
    ledger_id = [ordered]@{ type = "string" }
    version = [ordered]@{ const = "V1" }
    status = [ordered]@{ type = "string" }
    active_line = [ordered]@{ const = "AGENT_BUILDER / SELF_BUILD" }
    source_plan = [ordered]@{ type = "string" }
    source_admission = [ordered]@{ type = "string" }
    item_status_values = [ordered]@{
      type = "array"
      items = [ordered]@{ enum = $itemStatusValues }
    }
    ledger_policy = [ordered]@{ type = "object" }
    entries = [ordered]@{
      type = "array"
      items = [ordered]@{
        type = "object"
        required = @(
          "ledger_entry_id",
          "item_id",
          "source_gap",
          "title",
          "status",
          "execution_attempted",
          "attempt_count",
          "evidence_paths",
          "validation_output",
          "proof_or_report_path",
          "failure_reason",
          "quarantine_reason",
          "blocker_reason",
          "assistance_required",
          "next_action",
          "updated_at_policy"
        )
      }
    }
    item_count = [ordered]@{ type = "integer"; minimum = 0 }
    execution_attempted = [ordered]@{ const = $false }
    next_allowed_step = [ordered]@{ const = $NextAllowedStep }
  }
  additionalProperties = $true
}

$ledgerPolicy = [ordered]@{
  ledger_records_item_attempts = $true
  ledger_does_not_execute_items = $true
  no_item_pass_without_proof = $true
  failed_item_must_have_reason = $true
  quarantined_item_must_have_reason = $true
  blocked_item_must_have_reason = $true
  assistance_required_must_be_explicit = $true
  batch_report_must_not_hide_failed_items = $true
  no_external_agent_production = $true
  no_external_install = $true
  no_external_fetch = $true
}

$ledgerContract = [ordered]@{
  ledger_id = "ITEM_LEVEL_EXECUTION_LEDGER_V1"
  version = "V1"
  status = "ACTIVE_LEDGER_CONTRACT"
  phase = $Phase
  active_line = "AGENT_BUILDER / SELF_BUILD"
  generated_at = $generatedAt
  input_sources = @(
    "self_build_batch/plans/BATCH_PLAN_EXAMPLE_V1.json",
    "self_build_batch/admission/BATCH_PLAN_EXAMPLE_V1_ADMISSION.json",
    "self_build_backlog/SELF_BUILD_BACKLOG_CONTRACT_V1.json"
  )
  output_schema = $SchemaPath
  item_status_values = $itemStatusValues
  ledger_policy = $ledgerPolicy
  entries = @()
  item_count = 0
  execution_attempted = $false
  next_allowed_step = $NextAllowedStep
}

$dryRunLedger = [ordered]@{
  ledger_id = "BATCH_PLAN_EXAMPLE_V1_LEDGER_DRY_RUN"
  version = "V1"
  status = "INITIALIZED"
  active_line = "AGENT_BUILDER / SELF_BUILD"
  generated_at = $generatedAt
  source_plan = $SourcePlanPath
  source_admission = $SourceAdmissionPath
  item_status_values = $itemStatusValues
  ledger_policy = $ledgerPolicy
  entries = $entries
  item_count = $entries.Count
  execution_attempted = $false
  no_item_pass = $true
  no_executed_entries = $true
  next_allowed_step = $NextAllowedStep
}

$deliveryConveyorContract = [ordered]@{
  contract_id = "SELF_BUILD_DELIVERY_CONVEYOR_V1"
  status = "ACTIVE_OPERATION_CONTRACT"
  created_in_phase = $Phase
  active_line = "AGENT_BUILDER / SELF_BUILD"
  generated_at = $generatedAt
  purpose = "reduce manual seed/runtime/proof loops without weakening proof discipline"
  process_policy = [ordered]@{
    codex_for_complex_seed = $true
    combined_terminal_pack_preferred_after_phase97 = $true
    seed_check_required = $true
    runtime_only_after_seed_pass = $true
    proof_validation_required = $true
    commit_only_after_runtime_pass = $true
    push_only_after_commit_pass = $true
    stop_on_any_fail = $true
    no_fake_pass = $true
    no_commit_on_fail = $true
    no_push_on_fail = $true
    owner_report_required_on_fail = $true
    no_unbounded_loop = $true
  }
  next_allowed_step = $NextAllowedStep
}

$doc = @"
# SELF_BUILD_DELIVERY_CONVEYOR_V1

This operational contract records the post-PHASE97 delivery rule for complex Builder self-development work.

- Codex prepares the bounded seed files and leaves Builder runtime unrun.
- A combined terminal pack performs seed validation, Builder runtime, proof/report validation, then commit and push.
- Runtime may start only after seed validation passes.
- Commit may happen only after runtime and proof validation pass.
- Any FAIL stops the conveyor before commit or push and requires an owner-facing failure report.
- Fake PASS is forbidden; failed evidence remains visible.

This reduces manual actions by joining the repetitive validation-runtime-proof-commit path into one guarded terminal packet while keeping proof discipline intact.
"@

$report = [ordered]@{
  status = "PASS"
  phase = $Phase
  active_line = "AGENT_BUILDER / SELF_BUILD"
  generated_at = $generatedAt
  baseline_commit = $BaselineCommit
  ledger_contract_created = $LedgerContractPath
  schema_created = $SchemaPath
  dry_run_ledger_created = $DryRunLedgerPath
  delivery_conveyor_contract_created = $DeliveryConveyorContractPath
  delivery_conveyor_doc_created = $DeliveryConveyorDocPath
  dry_run_ledger_status = "INITIALIZED"
  dry_run_execution_attempted = $false
  item_count = $entries.Count
  no_item_pass = $true
  ledger_does_not_execute_items = $true
  no_external_agent_production = $true
  no_external_install = $true
  no_external_fetch = $true
  phase99_not_executed = $true
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
  ledger_contract_created = $true
  schema_created = $true
  dry_run_ledger_created = $true
  delivery_conveyor_contract_created = $true
  delivery_conveyor_doc_created = $true
  dry_run_ledger_status = "INITIALIZED"
  dry_run_execution_attempted = $false
  item_count = $entries.Count
  no_item_pass = $true
  ledger_does_not_execute_items = $true
  combined_terminal_pack_policy_recorded = $true
  no_external_agent_production = $true
  no_external_install = $true
  no_external_fetch = $true
  phase99_not_executed = $true
  queue_returned_to_none = $true
  next_allowed_step = $NextAllowedStep
  evidence_files = @(
    $SchemaPath,
    $LedgerContractPath,
    $DryRunLedgerPath,
    $DeliveryConveyorContractPath,
    $DeliveryConveyorDocPath,
    $ReportPath
  )
}

Write-JsonFile -Path $SchemaPath -Object $schema
Write-JsonFile -Path $LedgerContractPath -Object $ledgerContract
Write-JsonFile -Path $DryRunLedgerPath -Object $dryRunLedger
Write-JsonFile -Path $DeliveryConveyorContractPath -Object $deliveryConveyorContract
Write-TextFile -Path $DeliveryConveyorDocPath -Text $doc
Write-JsonFile -Path $ReportPath -Object $report
Write-JsonFile -Path $ProofPath -Object $proof

Write-Host "ITEM_LEVEL_EXECUTION_LEDGER_SCHEMA_CREATED=$SchemaPath"
Write-Host "ITEM_LEVEL_EXECUTION_LEDGER_CONTRACT_CREATED=$LedgerContractPath"
Write-Host "ITEM_LEVEL_EXECUTION_LEDGER_DRY_RUN_CREATED=$DryRunLedgerPath"
Write-Host "SELF_BUILD_DELIVERY_CONVEYOR_CONTRACT_CREATED=$DeliveryConveyorContractPath"
Write-Host "SELF_BUILD_DELIVERY_CONVEYOR_DOC_CREATED=$DeliveryConveyorDocPath"
Write-Host "DRY_RUN_LEDGER_STATUS=INITIALIZED"
Write-Host "DRY_RUN_EXECUTION_ATTEMPTED=FALSE"
Write-Host "NO_ITEM_PASS=TRUE"
Write-Host "LEDGER_DOES_NOT_EXECUTE_ITEMS=TRUE"
Write-Host "NO_EXTERNAL_AGENT_PRODUCTION=TRUE"
Write-Host "ITEM_LEVEL_EXECUTION_LEDGER_REPORT_WRITTEN=$ReportPath"
Write-Host "ITEM_LEVEL_EXECUTION_LEDGER_PROOF_WRITTEN=$ProofPath"
Write-Host "ITEM_LEVEL_EXECUTION_LEDGER_V1_COMPLETE"

return [pscustomobject]$report
