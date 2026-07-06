[CmdletBinding()]
param(
  [string]$Phase93ProofPath = "proofs/self_development/CAPABILITY_GAP_DETECTOR_V1.json",
  [string]$Phase93ReportPath = "reports/self_development/CAPABILITY_GAP_DETECTOR_REPORT.json",
  [string]$GapIndexPath = "self_build_backlog/CAPABILITY_GAP_INDEX_V1.json",
  [string]$RouteLockPath = "AGENT_BUILDER_NEXT_15_STEPS_LOCK_V2_R2.md",
  [string]$SchemaPath = "contracts/self_development/owner_order_to_gap_map_v1.schema.json",
  [string]$OwnerOrderContractPath = "owner_orders/OWNER_ORDER_CONTRACT_V1.json",
  [string]$ExampleOrderPath = "owner_orders/examples/OWNER_ORDER_BATCH_SELF_BUILD_100_TASKS_EXAMPLE.json",
  [string]$GapMapContractPath = "self_build_backlog/OWNER_ORDER_TO_GAP_MAP_V1.json",
  [string]$ExampleGapMapPath = "self_build_backlog/OWNER_ORDER_GAP_MAP_EXAMPLE_V1.json",
  [string]$ReportPath = "reports/self_development/OWNER_ORDER_TO_GAP_MAP_REPORT.json",
  [string]$ProofPath = "proofs/self_development/OWNER_ORDER_TO_GAP_MAP_V1.json",
  [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
)

$ErrorActionPreference = "Stop"

$Phase = "PHASE94_OWNER_ORDER_TO_GAP_MAP_V1"
$TaskId = "TASK_OWNER_ORDER_TO_GAP_MAP_V1_001"
$RouteLockVersion = "V2_R2"
$BaselineCommit = "0fae637"
$NextAllowedStep = "PHASE95_SELF_BUILD_PROGRAM_GENERATOR_V2"

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

Write-Host "OWNER_ORDER_TO_GAP_MAP_START"

$phase93Proof = Read-JsonRequired $Phase93ProofPath
$phase93Report = Read-JsonRequired $Phase93ReportPath
$gapIndex = Read-JsonRequired $GapIndexPath

if (-not (Test-Path -LiteralPath (Join-RepoPath $RouteLockPath))) {
  throw "MISSING_ROUTE_LOCK=$RouteLockPath"
}
if ("$(Get-PropertyValue -Object $phase93Proof -Name "status")" -ne "PASS") {
  throw "PHASE93_PROOF_STATUS_NOT_PASS"
}
if ("$(Get-PropertyValue -Object $phase93Proof -Name "next_allowed_step")" -ne "PHASE94_OWNER_ORDER_TO_GAP_MAP_V1") {
  throw "PHASE93_PROOF_NEXT_STEP_MISMATCH"
}
if ("$(Get-PropertyValue -Object $phase93Report -Name "status")" -ne "PASS") {
  throw "PHASE93_REPORT_STATUS_NOT_PASS"
}

$generatedAt = Get-UtcStamp
$mappedGaps = @(
  "PHASE95_SELF_BUILD_PROGRAM_GENERATOR_V2",
  "PHASE96_BATCH_PLANNER_V1",
  "PHASE97_BATCH_ADMISSION_POLICY_V1",
  "PHASE98_ITEM_LEVEL_EXECUTION_LEDGER_V1",
  "PHASE99_CONTINUE_ON_FAILURE_RUNTIME_V1",
  "PHASE100_QUARANTINE_AND_BLOCKER_REGISTRY_V1",
  "PHASE101_BATCH_PROOF_AGGREGATOR_V1",
  "PHASE102_AUTO_NEXT_GAP_DECISION_V1",
  "PHASE103_REPAIR_LOOP_GENERATOR_V1",
  "PHASE104_CONTROLLED_MULTI_CYCLE_SELF_BUILD_RUN_V1",
  "PHASE105_SCALE_TRIAL_10_TO_30_TO_100_TASKS_V1"
)

$schema = [ordered]@{
  '$schema' = "https://json-schema.org/draft/2020-12/schema"
  schema_id = "owner_order_to_gap_map_v1"
  title = "Owner Order To Gap Map V1"
  type = "object"
  required = @(
    "source_order_path",
    "understood_request",
    "mapped_gap_count",
    "available_foundation",
    "missing_capabilities",
    "blocked_items",
    "assistance_required",
    "next_safe_self_build_step",
    "no_external_agent_production",
    "execution_performed"
  )
  properties = [ordered]@{
    source_order_path = [ordered]@{ type = "string" }
    understood_request = [ordered]@{ type = "string" }
    mapped_gap_count = [ordered]@{ type = "integer"; minimum = 0 }
    available_foundation = [ordered]@{ type = "array" }
    missing_capabilities = [ordered]@{ type = "array" }
    blocked_items = [ordered]@{ type = "array" }
    assistance_required = [ordered]@{ type = "array" }
    next_safe_self_build_step = [ordered]@{ type = "string" }
    no_external_agent_production = [ordered]@{ const = $true }
    execution_performed = [ordered]@{ const = $false }
  }
  additionalProperties = $true
}

$ownerOrderContract = [ordered]@{
  contract_id = "OWNER_ORDER_CONTRACT_V1"
  status = "ACTIVE_CONTRACT"
  phase = $Phase
  generated_at = $generatedAt
  allowed_mode_values = @("PLAN_ONLY", "GAP_MAP_ONLY", "SELF_BUILD_PROPOSAL_ONLY")
  execution_mode_allowed = $false
  required_fields = @(
    "order_id",
    "mode",
    "request",
    "max_cycles",
    "max_items",
    "risk_level",
    "allow_external_agents",
    "allow_installs",
    "allow_external_fetch",
    "require_owner_approval",
    "expected_output",
    "constraints"
  )
  field_definitions = [ordered]@{
    order_id = "Stable owner order identifier."
    mode = "One of PLAN_ONLY, GAP_MAP_ONLY, SELF_BUILD_PROPOSAL_ONLY."
    request = "Natural-language owner request."
    max_cycles = "Maximum planning or mapping cycles allowed."
    max_items = "Maximum requested items to consider."
    risk_level = "Risk boundary for the order."
    allow_external_agents = "Must default false."
    allow_installs = "Must default false."
    allow_external_fetch = "Must default false."
    require_owner_approval = "Must default true."
    expected_output = "Requested output artifact or decision form."
    constraints = "Owner or policy constraints."
  }
  safety_defaults = [ordered]@{
    allow_external_agents = $false
    allow_installs = $false
    allow_external_fetch = $false
    require_owner_approval = $true
  }
  future_workflow_inputs = [ordered]@{
    order_path = "Path to an owner order JSON file."
    mode = "PLAN_ONLY, GAP_MAP_ONLY, or SELF_BUILD_PROPOSAL_ONLY."
    max_cycles = "Maximum cycles for the workflow-dispatched request."
    max_items = "Maximum item count for the workflow-dispatched request."
    risk_level = "Risk boundary such as SAFE_ONLY."
    require_owner_approval = "Boolean gate for owner approval."
  }
}

$exampleOrder = [ordered]@{
  order_id = "OWNER_ORDER_BATCH_SELF_BUILD_100_TASKS_EXAMPLE"
  mode = "GAP_MAP_ONLY"
  request = "Owner wants Builder to learn to process 100 self-build tasks in controlled batches."
  max_cycles = 1
  max_items = 100
  risk_level = "SAFE_ONLY"
  allow_external_agents = $false
  allow_installs = $false
  allow_external_fetch = $false
  require_owner_approval = $true
  expected_output = "Gap map for the capabilities needed to process 100 self-build tasks safely."
  constraints = @(
    "Self-build only.",
    "No external agents.",
    "No installs.",
    "No external fetch.",
    "No execution in PHASE94."
  )
}

$gapMapContract = [ordered]@{
  contract_id = "OWNER_ORDER_TO_GAP_MAP_V1"
  status = "ACTIVE_CONTRACT"
  phase = $Phase
  generated_at = $generatedAt
  schema_path = $SchemaPath
  source_contract_path = $OwnerOrderContractPath
  purpose = "Map simple owner orders into understood requests, missing capabilities, foundations, blockers, assistance needs, next safe self-build steps, and future workflow input fields."
  required_fields = @(
    "source_order_path",
    "understood_request",
    "mapped_gap_count",
    "available_foundation",
    "missing_capabilities",
    "blocked_items",
    "assistance_required",
    "next_safe_self_build_step",
    "no_external_agent_production",
    "execution_performed"
  )
  future_workflow_input_contract_defined = $true
  execution_performed = $false
}

$exampleGapMap = [ordered]@{
  gap_map_id = "OWNER_ORDER_GAP_MAP_EXAMPLE_V1"
  source_order_path = $ExampleOrderPath
  understood_request = "Builder should learn to process 100 self-build tasks through controlled batch planning, admission, item-level evidence, continue-on-failure handling, quarantine/blocker routing, proof aggregation, repair loops, and scale trials."
  mapped_gap_count = $mappedGaps.Count
  available_foundation = @(
    "AGENT_BUILDER_NEXT_15_STEPS_LOCK_V2_R2.md",
    "self_build_backlog/SELF_BUILD_BACKLOG_CONTRACT_V1.json",
    "self_build_backlog/CAPABILITY_GAP_DETECTOR_V1.json",
    "self_build_backlog/CAPABILITY_GAP_INDEX_V1.json",
    $Phase93ProofPath,
    $Phase93ReportPath
  )
  missing_capabilities = $mappedGaps
  blocked_items = @(
    [ordered]@{
      item = "External agent production"
      reason = "Forbidden by V2_R2 route lock for PHASE91-PHASE105."
    },
    [ordered]@{
      item = "Unbounded autonomous batch execution"
      reason = "Batch runtime and item-level policy are not proven yet."
    }
  )
  assistance_required = @(
    "Owner approval before moving from gap map to executable self-build proposal.",
    "Codex repair only when Builder emits NEEDS_CODEX_REPAIR for a bounded item.",
    "Owner decision for any item marked NEEDS_OWNER_DECISION."
  )
  next_safe_self_build_step = $NextAllowedStep
  future_workflow_inputs = [ordered]@{
    order_path = $ExampleOrderPath
    mode = "GAP_MAP_ONLY"
    max_cycles = 1
    max_items = 100
    risk_level = "SAFE_ONLY"
    require_owner_approval = $true
  }
  no_external_agent_production = $true
  execution_performed = $false
}

$report = [ordered]@{
  status = "PASS"
  phase = $Phase
  active_line = "AGENT_BUILDER / SELF_BUILD"
  generated_at = $generatedAt
  baseline_commit = $BaselineCommit
  owner_order_contract_created = $OwnerOrderContractPath
  example_order_created = $ExampleOrderPath
  gap_map_contract_created = $GapMapContractPath
  example_gap_map_created = $ExampleGapMapPath
  future_workflow_input_contract_defined = $true
  execution_performed = $false
  no_external_agent_production = $true
  no_external_install = $true
  no_external_fetch = $true
  source_gap_index_path = $GapIndexPath
  source_gap_index_status = "$(Get-PropertyValue -Object $gapIndex -Name "status")"
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
  owner_order_contract_created = $true
  example_owner_order_created = $true
  gap_map_contract_created = $true
  example_gap_map_created = $true
  future_workflow_input_contract_defined = $true
  execution_performed = $false
  no_external_agent_production = $true
  no_external_install = $true
  no_external_fetch = $true
  phase95_not_executed = $true
  queue_returned_to_none = $true
  next_allowed_step = $NextAllowedStep
  evidence_files = @(
    $SchemaPath,
    $OwnerOrderContractPath,
    $ExampleOrderPath,
    $GapMapContractPath,
    $ExampleGapMapPath,
    $ReportPath
  )
}

Write-JsonFile -Path $SchemaPath -Object $schema
Write-JsonFile -Path $OwnerOrderContractPath -Object $ownerOrderContract
Write-JsonFile -Path $ExampleOrderPath -Object $exampleOrder
Write-JsonFile -Path $GapMapContractPath -Object $gapMapContract
Write-JsonFile -Path $ExampleGapMapPath -Object $exampleGapMap
Write-JsonFile -Path $ReportPath -Object $report
Write-JsonFile -Path $ProofPath -Object $proof

Write-Host "OWNER_ORDER_CONTRACT_CREATED=$OwnerOrderContractPath"
Write-Host "OWNER_ORDER_EXAMPLE_CREATED=$ExampleOrderPath"
Write-Host "OWNER_ORDER_GAP_MAP_CONTRACT_CREATED=$GapMapContractPath"
Write-Host "OWNER_ORDER_GAP_MAP_EXAMPLE_CREATED=$ExampleGapMapPath"
Write-Host "FUTURE_WORKFLOW_INPUT_CONTRACT_DEFINED=TRUE"
Write-Host "EXECUTION_PERFORMED=FALSE"
Write-Host "NO_EXTERNAL_AGENT_PRODUCTION=TRUE"
Write-Host "OWNER_ORDER_TO_GAP_MAP_REPORT_WRITTEN=$ReportPath"
Write-Host "OWNER_ORDER_TO_GAP_MAP_PROOF_WRITTEN=$ProofPath"
Write-Host "OWNER_ORDER_TO_GAP_MAP_COMPLETE"

return [pscustomobject]$report
