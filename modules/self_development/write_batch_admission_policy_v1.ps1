[CmdletBinding()]
param(
  [string]$Phase96ProofPath = "proofs/self_development/BATCH_PLANNER_V1.json",
  [string]$Phase96ReportPath = "reports/self_development/BATCH_PLANNER_V1_REPORT.json",
  [string]$SourcePlanPath = "self_build_batch/plans/BATCH_PLAN_EXAMPLE_V1.json",
  [string]$PlannerPath = "self_build_batch/planner/BATCH_PLANNER_V1.json",
  [string]$BacklogContractPath = "self_build_backlog/SELF_BUILD_BACKLOG_CONTRACT_V1.json",
  [string]$SourceProgramPath = "self_build_programs/generated/SELF_BUILD_PROGRAM_V2_EXAMPLE_001.json",
  [string]$RouteLockPath = "AGENT_BUILDER_NEXT_15_STEPS_LOCK_V2_R2.md",
  [string]$SchemaPath = "contracts/self_development/batch_admission_policy_v1.schema.json",
  [string]$PolicyPath = "self_build_batch/admission/BATCH_ADMISSION_POLICY_V1.json",
  [string]$AdmissionPath = "self_build_batch/admission/BATCH_PLAN_EXAMPLE_V1_ADMISSION.json",
  [string]$ReportPath = "reports/self_development/BATCH_ADMISSION_POLICY_V1_REPORT.json",
  [string]$ProofPath = "proofs/self_development/BATCH_ADMISSION_POLICY_V1.json",
  [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
)

$ErrorActionPreference = "Stop"

$Phase = "PHASE97_BATCH_ADMISSION_POLICY_V1"
$TaskId = "TASK_BATCH_ADMISSION_POLICY_V1_001"
$RouteLockVersion = "V2_R2"
$BaselineCommit = "bdf0174"
$NextAllowedStep = "PHASE98_ITEM_LEVEL_EXECUTION_LEDGER_V1"
$Decision = "CONDITIONALLY_ADMISSIBLE"

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

Write-Host "BATCH_ADMISSION_POLICY_V1_START"

$phase96Proof = Read-JsonRequired $Phase96ProofPath
$phase96Report = Read-JsonRequired $Phase96ReportPath
$plan = Read-JsonRequired $SourcePlanPath
Read-JsonRequired $PlannerPath | Out-Null
Read-JsonRequired $BacklogContractPath | Out-Null
Read-JsonRequired $SourceProgramPath | Out-Null

if (-not (Test-Path -LiteralPath (Join-RepoPath $RouteLockPath))) {
  throw "MISSING_ROUTE_LOCK=$RouteLockPath"
}
if ("$(Get-PropertyValue -Object $phase96Proof -Name "status")" -ne "PASS") {
  throw "PHASE96_PROOF_STATUS_NOT_PASS"
}
if ("$(Get-PropertyValue -Object $phase96Proof -Name "next_allowed_step")" -ne "PHASE97_BATCH_ADMISSION_POLICY_V1") {
  throw "PHASE96_PROOF_NEXT_STEP_MISMATCH"
}
if ("$(Get-PropertyValue -Object $phase96Report -Name "status")" -ne "PASS") {
  throw "PHASE96_REPORT_STATUS_NOT_PASS"
}
if ("$(Get-PropertyValue -Object $plan -Name "status")" -ne "PLANNED") {
  throw "SOURCE_PLAN_NOT_PLANNED"
}
if (-not [bool](Get-PropertyValue -Object $plan -Name "admission_required")) {
  throw "SOURCE_PLAN_ADMISSION_REQUIRED_NOT_TRUE"
}
if ([bool](Get-PropertyValue -Object $plan -Name "execution_allowed")) {
  throw "SOURCE_PLAN_EXECUTION_ALLOWED_TRUE"
}

$batchCount = [int](Get-PropertyValue -Object $plan -Name "batch_count")
$itemCount = [int](Get-PropertyValue -Object $plan -Name "item_count")
if ($batchCount -le 0) {
  throw "SOURCE_PLAN_BATCH_COUNT_NOT_POSITIVE"
}
if ($itemCount -le 0) {
  throw "SOURCE_PLAN_ITEM_COUNT_NOT_POSITIVE"
}

$allItems = @()
$missingStatus = $false
$missingProof = $false
$missingQuarantine = $false
$passItems = @()
$executedItems = @()
foreach ($batch in As-Array (Get-PropertyValue -Object $plan -Name "batches")) {
  foreach ($item in As-Array (Get-PropertyValue -Object $batch -Name "items")) {
    $allItems += $item
    $itemId = "$(Get-PropertyValue -Object $item -Name "item_id")"
    if ([string]::IsNullOrWhiteSpace("$(Get-PropertyValue -Object $item -Name "status")")) {
      $missingStatus = $true
    }
    if (-not [bool](Get-PropertyValue -Object $item -Name "proof_required")) {
      $missingProof = $true
    }
    if ($null -eq (Get-PropertyInfo -Object $item -Name "quarantine_on_failure")) {
      $missingQuarantine = $true
    }
    if ("$(Get-PropertyValue -Object $item -Name "status")" -eq "PASS") {
      $passItems += $itemId
    }
    if ([bool](Get-PropertyValue -Object $item -Name "execution_performed")) {
      $executedItems += $itemId
    }
  }
}

if ($missingStatus) {
  throw "SOURCE_PLAN_MISSING_ITEM_LEVEL_STATUS"
}
if ($missingProof) {
  throw "SOURCE_PLAN_MISSING_ITEM_PROOF_REQUIREMENT"
}
if ($missingQuarantine) {
  throw "SOURCE_PLAN_MISSING_QUARANTINE_POLICY"
}
if ($passItems.Count -gt 0) {
  throw "SOURCE_PLAN_HAS_PASS_ITEMS=$($passItems -join ',')"
}
if ($executedItems.Count -gt 0) {
  throw "SOURCE_PLAN_HAS_EXECUTED_ITEMS=$($executedItems -join ',')"
}

$generatedAt = Get-UtcStamp
$decisionValues = @(
  "ADMIT_FOR_FUTURE_CONTROLLED_EXECUTION",
  "CONDITIONALLY_ADMISSIBLE",
  "BLOCKED",
  "NEEDS_OWNER_DECISION",
  "NEEDS_CODEX_REPAIR",
  "NEEDS_MATERIAL",
  "REJECTED_BY_POLICY"
)

$admissionChecks = @(
  "plan_status_must_be_planned",
  "admission_required_must_be_true",
  "execution_allowed_must_be_false_before_admission",
  "batch_count_must_be_positive",
  "item_count_must_be_positive",
  "items_must_have_item_level_status",
  "no_item_may_be_pass_before_execution",
  "no_item_may_be_executed_before_runtime",
  "dependencies_must_be_declared",
  "blocked_files_scope_must_be_declared",
  "allowed_files_scope_must_be_declared",
  "proof_requirements_must_be_declared",
  "quarantine_on_failure_must_be_declared"
)

$blockingConditions = @(
  "destructive_scope_without_owner_approval",
  "external_fetch_requested",
  "install_requested",
  "external_agent_production_requested",
  "missing_item_level_status",
  "missing_proof_requirements",
  "missing_quarantine_policy",
  "plan_already_executed"
)

$ownerApprovalConditions = @(
  "destructive_changes",
  "external_fetch",
  "install_dependencies",
  "policy_change",
  "large_scale_execution"
)

$assistanceConditions = @(
  "NEEDS_OWNER_DECISION",
  "NEEDS_CODEX_REPAIR",
  "NEEDS_MATERIAL"
)

$schema = [ordered]@{
  '$schema' = "https://json-schema.org/draft/2020-12/schema"
  schema_id = "batch_admission_policy_v1"
  title = "Batch Admission Policy V1"
  type = "object"
  required = @(
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
  )
  properties = [ordered]@{
    policy_id = [ordered]@{ const = "BATCH_ADMISSION_POLICY_V1" }
    version = [ordered]@{ const = "V1" }
    status = [ordered]@{ const = "ACTIVE_ADMISSION_POLICY" }
    active_line = [ordered]@{ const = "AGENT_BUILDER / SELF_BUILD" }
    input_sources = [ordered]@{ type = "array" }
    decision_values = [ordered]@{ type = "array"; items = [ordered]@{ enum = $decisionValues } }
    admission_checks = [ordered]@{ type = "array" }
    blocking_conditions = [ordered]@{ type = "array" }
    owner_approval_conditions = [ordered]@{ type = "array" }
    assistance_conditions = [ordered]@{ type = "array" }
    output_contract = [ordered]@{ type = "object" }
    execution_allowed = [ordered]@{ const = $false }
  }
  additionalProperties = $true
}

$policy = [ordered]@{
  policy_id = "BATCH_ADMISSION_POLICY_V1"
  version = "V1"
  status = "ACTIVE_ADMISSION_POLICY"
  phase = $Phase
  active_line = "AGENT_BUILDER / SELF_BUILD"
  generated_at = $generatedAt
  input_sources = @(
    "self_build_batch/plans/BATCH_PLAN_EXAMPLE_V1.json",
    "self_build_batch/planner/BATCH_PLANNER_V1.json",
    "self_build_backlog/SELF_BUILD_BACKLOG_CONTRACT_V1.json",
    "self_build_programs/generated/SELF_BUILD_PROGRAM_V2_EXAMPLE_001.json"
  )
  output_schema = $SchemaPath
  decision_values = $decisionValues
  admission_checks = $admissionChecks
  blocking_conditions = $blockingConditions
  owner_approval_conditions = $ownerApprovalConditions
  assistance_conditions = $assistanceConditions
  output_contract = [ordered]@{
    admission_id = "Stable admission artifact identifier."
    source_plan = "Source batch plan path."
    status = "PASS or FAIL for policy evaluation."
    decision = "One decision value from decision_values."
    execution_allowed = "Must remain false until future runtime exists."
    required_before_execution = "Required future runtime capabilities."
    checked_items = "Batch and item-level check summary."
    next_allowed_step = "Next safe self-build step."
  }
  execution_allowed = $false
  policy = [ordered]@{
    policy_does_not_execute_batches = $true
    policy_does_not_create_ledger = $true
    batch_execution_remains_blocked_until_runtime_exists = $true
    no_external_agent_production = $true
    no_external_install = $true
    no_external_fetch = $true
  }
}

$requiredBeforeExecution = @(
  "PHASE98_ITEM_LEVEL_EXECUTION_LEDGER_V1",
  "PHASE99_CONTINUE_ON_FAILURE_RUNTIME_V1",
  "PHASE100_QUARANTINE_AND_BLOCKER_REGISTRY_V1",
  "PHASE101_BATCH_PROOF_AGGREGATOR_V1"
)

$admission = [ordered]@{
  admission_id = "BATCH_PLAN_EXAMPLE_V1_ADMISSION"
  source_plan = $SourcePlanPath
  status = "PASS"
  decision = $Decision
  execution_allowed = $false
  reason = "Batch plan is structurally valid, but execution remains blocked until item-level ledger and continue-on-failure runtime are built."
  required_before_execution = $requiredBeforeExecution
  checked_items = [ordered]@{
    item_count = $itemCount
    batch_count = $batchCount
    no_pass_items = $passItems.Count -eq 0
    no_executed_items = $executedItems.Count -eq 0
    item_level_status_present = -not $missingStatus
    proof_requirements_present = -not $missingProof
    quarantine_policy_present = -not $missingQuarantine
  }
  no_external_agent_production = $true
  no_external_install = $true
  no_external_fetch = $true
  next_allowed_step = $NextAllowedStep
}

$report = [ordered]@{
  status = "PASS"
  phase = $Phase
  active_line = "AGENT_BUILDER / SELF_BUILD"
  generated_at = $generatedAt
  baseline_commit = $BaselineCommit
  policy_created = $PolicyPath
  schema_created = $SchemaPath
  example_admission_created = $AdmissionPath
  example_admission_status = "PASS"
  example_admission_decision = $Decision
  example_admission_execution_allowed = $false
  batch_execution_remains_blocked_until_runtime_exists = $true
  policy_does_not_execute_batches = $true
  policy_does_not_create_ledger = $true
  no_external_agent_production = $true
  no_external_install = $true
  no_external_fetch = $true
  phase98_not_executed = $true
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
  policy_created = $true
  schema_created = $true
  example_admission_created = $true
  example_admission_status = "PASS"
  example_admission_decision = $Decision
  example_admission_execution_allowed = $false
  batch_execution_remains_blocked_until_runtime_exists = $true
  policy_does_not_execute_batches = $true
  policy_does_not_create_ledger = $true
  no_external_agent_production = $true
  no_external_install = $true
  no_external_fetch = $true
  phase98_not_executed = $true
  queue_returned_to_none = $true
  next_allowed_step = $NextAllowedStep
  evidence_files = @(
    $SchemaPath,
    $PolicyPath,
    $AdmissionPath,
    $ReportPath
  )
}

Write-JsonFile -Path $SchemaPath -Object $schema
Write-JsonFile -Path $PolicyPath -Object $policy
Write-JsonFile -Path $AdmissionPath -Object $admission
Write-JsonFile -Path $ReportPath -Object $report
Write-JsonFile -Path $ProofPath -Object $proof

Write-Host "BATCH_ADMISSION_POLICY_SCHEMA_CREATED=$SchemaPath"
Write-Host "BATCH_ADMISSION_POLICY_CREATED=$PolicyPath"
Write-Host "BATCH_PLAN_ADMISSION_CREATED=$AdmissionPath"
Write-Host "BATCH_ADMISSION_DECISION=$Decision"
Write-Host "BATCH_ADMISSION_EXECUTION_ALLOWED=FALSE"
Write-Host "BATCH_EXECUTION_REMAINS_BLOCKED_UNTIL_RUNTIME_EXISTS=TRUE"
Write-Host "POLICY_DOES_NOT_EXECUTE_BATCHES=TRUE"
Write-Host "POLICY_DOES_NOT_CREATE_LEDGER=TRUE"
Write-Host "NO_EXTERNAL_AGENT_PRODUCTION=TRUE"
Write-Host "BATCH_ADMISSION_POLICY_REPORT_WRITTEN=$ReportPath"
Write-Host "BATCH_ADMISSION_POLICY_PROOF_WRITTEN=$ProofPath"
Write-Host "BATCH_ADMISSION_POLICY_V1_COMPLETE"

return [pscustomobject]$report
