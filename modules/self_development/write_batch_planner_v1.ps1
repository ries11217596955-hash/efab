[CmdletBinding()]
param(
  [string]$Phase95ProofPath = "proofs/self_development/SELF_BUILD_PROGRAM_GENERATOR_V2.json",
  [string]$Phase95ReportPath = "reports/self_development/SELF_BUILD_PROGRAM_GENERATOR_V2_REPORT.json",
  [string]$SourceProgramPath = "self_build_programs/generated/SELF_BUILD_PROGRAM_V2_EXAMPLE_001.json",
  [string]$SourceGapMapPath = "self_build_backlog/OWNER_ORDER_GAP_MAP_EXAMPLE_V1.json",
  [string]$CapabilityGapIndexPath = "self_build_backlog/CAPABILITY_GAP_INDEX_V1.json",
  [string]$BacklogContractPath = "self_build_backlog/SELF_BUILD_BACKLOG_CONTRACT_V1.json",
  [string]$RouteLockPath = "AGENT_BUILDER_NEXT_15_STEPS_LOCK_V2_R2.md",
  [string]$SchemaPath = "contracts/self_development/batch_plan_v1.schema.json",
  [string]$PlannerPath = "self_build_batch/planner/BATCH_PLANNER_V1.json",
  [string]$ExamplePlanPath = "self_build_batch/plans/BATCH_PLAN_EXAMPLE_V1.json",
  [string]$ReportPath = "reports/self_development/BATCH_PLANNER_V1_REPORT.json",
  [string]$ProofPath = "proofs/self_development/BATCH_PLANNER_V1.json",
  [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
)

$ErrorActionPreference = "Stop"

$Phase = "PHASE96_BATCH_PLANNER_V1"
$TaskId = "TASK_BATCH_PLANNER_V1_001"
$RouteLockVersion = "V2_R2"
$BaselineCommit = "00a7ee1"
$NextAllowedStep = "PHASE97_BATCH_ADMISSION_POLICY_V1"

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

Write-Host "BATCH_PLANNER_V1_START"

$phase95Proof = Read-JsonRequired $Phase95ProofPath
$phase95Report = Read-JsonRequired $Phase95ReportPath
$sourceProgram = Read-JsonRequired $SourceProgramPath
$sourceGapMap = Read-JsonRequired $SourceGapMapPath
Read-JsonRequired $CapabilityGapIndexPath | Out-Null
Read-JsonRequired $BacklogContractPath | Out-Null

if (-not (Test-Path -LiteralPath (Join-RepoPath $RouteLockPath))) {
  throw "MISSING_ROUTE_LOCK=$RouteLockPath"
}
if ("$(Get-PropertyValue -Object $phase95Proof -Name "status")" -ne "PASS") {
  throw "PHASE95_PROOF_STATUS_NOT_PASS"
}
if ("$(Get-PropertyValue -Object $phase95Proof -Name "next_allowed_step")" -ne "PHASE96_BATCH_PLANNER_V1") {
  throw "PHASE95_PROOF_NEXT_STEP_MISMATCH"
}
if ("$(Get-PropertyValue -Object $phase95Report -Name "status")" -ne "PASS") {
  throw "PHASE95_REPORT_STATUS_NOT_PASS"
}
if ("$(Get-PropertyValue -Object $sourceProgram -Name "status")" -ne "GENERATED_CANDIDATE") {
  throw "SOURCE_PROGRAM_NOT_GENERATED_CANDIDATE"
}
if ([bool](Get-PropertyValue -Object $sourceProgram -Name "execution_allowed")) {
  throw "SOURCE_PROGRAM_EXECUTION_ALLOWED_TRUE"
}
if ("$(Get-PropertyValue -Object $sourceProgram -Name "source_gap")" -ne "PHASE96_BATCH_PLANNER_V1") {
  throw "SOURCE_PROGRAM_GAP_MISMATCH"
}

$generatedAt = Get-UtcStamp
$requiredPlanFields = @(
  "plan_id",
  "version",
  "status",
  "source_order",
  "source_gap_map",
  "source_programs",
  "planner_policy",
  "batches",
  "batch_count",
  "item_count",
  "admission_required",
  "execution_allowed",
  "next_allowed_step"
)

$requiredBatchFields = @(
  "batch_id",
  "title",
  "status",
  "risk",
  "items",
  "dependencies",
  "allowed_files_scope",
  "blocked_files_scope",
  "admission_required",
  "owner_approval_required",
  "execution_allowed",
  "stop_conditions",
  "proof_requirements"
)

$requiredItemFields = @(
  "item_id",
  "source_gap",
  "title",
  "status",
  "risk",
  "dependencies",
  "assistance_required",
  "expected_outputs",
  "validation_required",
  "proof_required",
  "quarantine_on_failure"
)

$schema = [ordered]@{
  '$schema' = "https://json-schema.org/draft/2020-12/schema"
  schema_id = "batch_plan_v1"
  title = "Batch Plan V1"
  type = "object"
  required = $requiredPlanFields
  properties = [ordered]@{
    plan_id = [ordered]@{ type = "string" }
    version = [ordered]@{ const = "V1" }
    status = [ordered]@{ enum = @("PLANNED", "ADMITTED", "BLOCKED", "FAILED") }
    source_order = [ordered]@{ type = "object" }
    source_gap_map = [ordered]@{ type = "string" }
    source_programs = [ordered]@{ type = "array" }
    planner_policy = [ordered]@{ type = "object" }
    batches = [ordered]@{
      type = "array"
      items = [ordered]@{
        type = "object"
        required = $requiredBatchFields
        properties = [ordered]@{
          batch_id = [ordered]@{ type = "string" }
          title = [ordered]@{ type = "string" }
          status = [ordered]@{ enum = @("PLANNED", "BLOCKED", "SKIPPED_BY_POLICY") }
          risk = [ordered]@{ type = "object" }
          items = [ordered]@{
            type = "array"
            items = [ordered]@{
              type = "object"
              required = $requiredItemFields
            }
          }
          dependencies = [ordered]@{ type = "array" }
          allowed_files_scope = [ordered]@{ type = "array" }
          blocked_files_scope = [ordered]@{ type = "array" }
          admission_required = [ordered]@{ type = "boolean" }
          owner_approval_required = [ordered]@{ type = "boolean" }
          execution_allowed = [ordered]@{ type = "boolean" }
          stop_conditions = [ordered]@{ type = "array" }
          proof_requirements = [ordered]@{ type = "array" }
        }
      }
    }
    batch_count = [ordered]@{ type = "integer"; minimum = 0 }
    item_count = [ordered]@{ type = "integer"; minimum = 0 }
    admission_required = [ordered]@{ type = "boolean" }
    execution_allowed = [ordered]@{ type = "boolean" }
    next_allowed_step = [ordered]@{ type = "string" }
  }
  additionalProperties = $true
}

$plannerPolicy = [ordered]@{
  planner_does_not_execute_batches = $true
  planner_does_not_admit_batches = $true
  batch_admission_required = $true
  execution_allowed = $false
  group_only_safe_compatible_items = $true
  do_not_mix_destructive_with_safe = $true
  do_not_mix_external_fetch_with_local_only = $true
  preserve_dependency_order = $true
  item_level_status_required = $true
  proof_required_per_batch = $true
  no_external_agent_production = $true
  no_external_install = $true
  no_external_fetch = $true
}

$planner = [ordered]@{
  planner_id = "BATCH_PLANNER_V1"
  status = "ACTIVE_PLANNER_CONTRACT"
  phase = $Phase
  active_line = "AGENT_BUILDER / SELF_BUILD"
  generated_at = $generatedAt
  input_sources = @(
    "self_build_programs/generated/SELF_BUILD_PROGRAM_V2_EXAMPLE_001.json",
    "self_build_backlog/OWNER_ORDER_GAP_MAP_EXAMPLE_V1.json",
    "self_build_backlog/CAPABILITY_GAP_INDEX_V1.json",
    "self_build_backlog/SELF_BUILD_BACKLOG_CONTRACT_V1.json"
  )
  output_schema = $SchemaPath
  required_plan_fields = $requiredPlanFields
  required_batch_fields = $requiredBatchFields
  required_item_fields = $requiredItemFields
  planner_policy = $plannerPolicy
}

function New-PlannedItem {
  param(
    [string]$ItemId,
    [string]$SourceGap,
    [string]$Title,
    [string[]]$Dependencies
  )

  return [ordered]@{
    item_id = $ItemId
    source_gap = $SourceGap
    title = $Title
    status = "PLANNED"
    risk = [ordered]@{
      classification = "LOW"
      reason = "Contract or planning foundation only; no execution in PHASE96."
    }
    dependencies = @($Dependencies)
    assistance_required = @()
    expected_outputs = @(
      "Contract artifact",
      "Example artifact",
      "Report artifact",
      "Proof artifact"
    )
    validation_required = $true
    proof_required = $true
    quarantine_on_failure = $true
    execution_performed = $false
  }
}

$batch1Items = @(
  (New-PlannedItem -ItemId "ITEM_PHASE97_BATCH_ADMISSION_POLICY_V1" -SourceGap "PHASE97_BATCH_ADMISSION_POLICY_V1" -Title "Define Batch Admission Policy V1" -Dependencies @())
)

$batch2Items = @(
  (New-PlannedItem -ItemId "ITEM_PHASE98_ITEM_LEVEL_EXECUTION_LEDGER_V1" -SourceGap "PHASE98_ITEM_LEVEL_EXECUTION_LEDGER_V1" -Title "Define Item-Level Execution Ledger V1" -Dependencies @("ITEM_PHASE97_BATCH_ADMISSION_POLICY_V1")),
  (New-PlannedItem -ItemId "ITEM_PHASE99_CONTINUE_ON_FAILURE_RUNTIME_V1" -SourceGap "PHASE99_CONTINUE_ON_FAILURE_RUNTIME_V1" -Title "Define Continue-On-Failure Runtime V1" -Dependencies @("ITEM_PHASE97_BATCH_ADMISSION_POLICY_V1", "ITEM_PHASE98_ITEM_LEVEL_EXECUTION_LEDGER_V1")),
  (New-PlannedItem -ItemId "ITEM_PHASE100_QUARANTINE_AND_BLOCKER_REGISTRY_V1" -SourceGap "PHASE100_QUARANTINE_AND_BLOCKER_REGISTRY_V1" -Title "Define Quarantine And Blocker Registry V1" -Dependencies @("ITEM_PHASE97_BATCH_ADMISSION_POLICY_V1", "ITEM_PHASE98_ITEM_LEVEL_EXECUTION_LEDGER_V1")),
  (New-PlannedItem -ItemId "ITEM_PHASE101_BATCH_PROOF_AGGREGATOR_V1" -SourceGap "PHASE101_BATCH_PROOF_AGGREGATOR_V1" -Title "Define Batch Proof Aggregator V1" -Dependencies @("ITEM_PHASE97_BATCH_ADMISSION_POLICY_V1", "ITEM_PHASE98_ITEM_LEVEL_EXECUTION_LEDGER_V1"))
)

$commonAllowed = @(
  "contracts/self_development/",
  "self_build_batch/",
  "self_build_backlog/",
  "reports/self_development/",
  "proofs/self_development/",
  "TASK_QUEUE.json",
  "packs/registry.json",
  "CAPABILITY_ROADMAP.json",
  "GENESIS_STATE.json"
)

$commonBlocked = @(
  "generated_agents/",
  "applied_agents/",
  ".github/workflows/",
  "materials/",
  "operations/",
  "packs/PHASE78*",
  "packs/PHASE79*",
  "packs/PHASE80*",
  "packs/PHASE81*",
  "packs/PHASE82*",
  "packs/PHASE83*",
  "packs/PHASE84*",
  "packs/PHASE85*",
  "packs/PHASE86*",
  "packs/PHASE87*",
  "packs/PHASE88*",
  "packs/PHASE89*",
  "packs/PHASE90*",
  "packs/PHASE91*",
  "packs/PHASE92*",
  "packs/PHASE93*",
  "packs/PHASE94*",
  "packs/PHASE95*"
)

$batches = @(
  [ordered]@{
    batch_id = "BATCH_001_ADMISSION_POLICY_FOUNDATION"
    title = "Admission policy foundation before execution-related batch work"
    status = "PLANNED"
    risk = [ordered]@{ classification = "LOW"; reason = "Policy contract only." }
    items = $batch1Items
    dependencies = @()
    allowed_files_scope = $commonAllowed
    blocked_files_scope = $commonBlocked
    admission_required = $true
    owner_approval_required = $false
    execution_allowed = $false
    stop_conditions = @("Validation failure", "Owner policy conflict", "Unexpected external scope")
    proof_requirements = @("Batch plan remains PLANNED", "No item marked PASS", "No execution performed")
  },
  [ordered]@{
    batch_id = "BATCH_002_EXECUTION_EVIDENCE_FOUNDATIONS"
    title = "Execution evidence and failure-handling foundations after admission policy"
    status = "PLANNED"
    risk = [ordered]@{ classification = "LOW"; reason = "Contract and planning foundations only." }
    items = $batch2Items
    dependencies = @("BATCH_001_ADMISSION_POLICY_FOUNDATION")
    allowed_files_scope = $commonAllowed
    blocked_files_scope = $commonBlocked
    admission_required = $true
    owner_approval_required = $false
    execution_allowed = $false
    stop_conditions = @("Admission policy missing", "Validation failure", "Unexpected external scope")
    proof_requirements = @("Item-level evidence requirements defined", "No batch admitted", "No batch executed")
  }
)

$itemCount = $batch1Items.Count + $batch2Items.Count
$plan = [ordered]@{
  plan_id = "BATCH_PLAN_EXAMPLE_V1"
  version = "V1"
  status = "PLANNED"
  generated_at = $generatedAt
  source_order = [ordered]@{
    order_path = "owner_orders/examples/OWNER_ORDER_BATCH_SELF_BUILD_100_TASKS_EXAMPLE.json"
    source_request = "$(Get-PropertyValue -Object $sourceGapMap -Name "understood_request")"
  }
  source_gap_map = $SourceGapMapPath
  source_programs = @($SourceProgramPath)
  planner_policy = $plannerPolicy
  batches = $batches
  batch_count = $batches.Count
  item_count = $itemCount
  admission_required = $true
  execution_allowed = $false
  next_allowed_step = $NextAllowedStep
}

$report = [ordered]@{
  status = "PASS"
  phase = $Phase
  active_line = "AGENT_BUILDER / SELF_BUILD"
  generated_at = $generatedAt
  baseline_commit = $BaselineCommit
  planner_created = $PlannerPath
  schema_created = $SchemaPath
  example_plan_created = $ExamplePlanPath
  example_plan_status = "PLANNED"
  example_plan_admission_required = $true
  example_plan_execution_allowed = $false
  planner_does_not_execute_batches = $true
  planner_does_not_admit_batches = $true
  batch_count = $batches.Count
  item_count = $itemCount
  no_external_agent_production = $true
  no_external_install = $true
  no_external_fetch = $true
  phase97_not_executed = $true
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
  planner_created = $true
  schema_created = $true
  example_plan_created = $true
  example_plan_status = "PLANNED"
  example_plan_admission_required = $true
  example_plan_execution_allowed = $false
  planner_does_not_execute_batches = $true
  planner_does_not_admit_batches = $true
  batch_count = $batches.Count
  item_count = $itemCount
  no_external_agent_production = $true
  no_external_install = $true
  no_external_fetch = $true
  phase97_not_executed = $true
  queue_returned_to_none = $true
  next_allowed_step = $NextAllowedStep
  evidence_files = @(
    $SchemaPath,
    $PlannerPath,
    $ExamplePlanPath,
    $ReportPath
  )
}

Write-JsonFile -Path $SchemaPath -Object $schema
Write-JsonFile -Path $PlannerPath -Object $planner
Write-JsonFile -Path $ExamplePlanPath -Object $plan
Write-JsonFile -Path $ReportPath -Object $report
Write-JsonFile -Path $ProofPath -Object $proof

Write-Host "BATCH_PLAN_SCHEMA_CREATED=$SchemaPath"
Write-Host "BATCH_PLANNER_CREATED=$PlannerPath"
Write-Host "BATCH_PLAN_EXAMPLE_CREATED=$ExamplePlanPath"
Write-Host "BATCH_PLAN_STATUS=PLANNED"
Write-Host "BATCH_PLAN_ADMISSION_REQUIRED=TRUE"
Write-Host "BATCH_PLAN_EXECUTION_ALLOWED=FALSE"
Write-Host "BATCH_COUNT=$($batches.Count)"
Write-Host "ITEM_COUNT=$itemCount"
Write-Host "PLANNER_DOES_NOT_ADMIT_BATCHES=TRUE"
Write-Host "PLANNER_DOES_NOT_EXECUTE_BATCHES=TRUE"
Write-Host "NO_EXTERNAL_AGENT_PRODUCTION=TRUE"
Write-Host "BATCH_PLANNER_REPORT_WRITTEN=$ReportPath"
Write-Host "BATCH_PLANNER_PROOF_WRITTEN=$ProofPath"
Write-Host "BATCH_PLANNER_V1_COMPLETE"

return [pscustomobject]$report
