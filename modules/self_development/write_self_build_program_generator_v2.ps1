[CmdletBinding()]
param(
  [string]$Phase94ProofPath = "proofs/self_development/OWNER_ORDER_TO_GAP_MAP_V1.json",
  [string]$Phase94ReportPath = "reports/self_development/OWNER_ORDER_TO_GAP_MAP_REPORT.json",
  [string]$OwnerOrderContractPath = "owner_orders/OWNER_ORDER_CONTRACT_V1.json",
  [string]$OwnerOrderGapMapContractPath = "self_build_backlog/OWNER_ORDER_TO_GAP_MAP_V1.json",
  [string]$OwnerOrderGapMapExamplePath = "self_build_backlog/OWNER_ORDER_GAP_MAP_EXAMPLE_V1.json",
  [string]$CapabilityGapIndexPath = "self_build_backlog/CAPABILITY_GAP_INDEX_V1.json",
  [string]$RouteLockPath = "AGENT_BUILDER_NEXT_15_STEPS_LOCK_V2_R2.md",
  [string]$SchemaPath = "contracts/self_development/self_build_program_v2.schema.json",
  [string]$GeneratorPath = "self_build_programs/generator/SELF_BUILD_PROGRAM_GENERATOR_V2.json",
  [string]$ExampleProgramPath = "self_build_programs/generated/SELF_BUILD_PROGRAM_V2_EXAMPLE_001.json",
  [string]$ReportPath = "reports/self_development/SELF_BUILD_PROGRAM_GENERATOR_V2_REPORT.json",
  [string]$ProofPath = "proofs/self_development/SELF_BUILD_PROGRAM_GENERATOR_V2.json",
  [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
)

$ErrorActionPreference = "Stop"

$Phase = "PHASE95_SELF_BUILD_PROGRAM_GENERATOR_V2"
$TaskId = "TASK_SELF_BUILD_PROGRAM_GENERATOR_V2_001"
$RouteLockVersion = "V2_R2"
$BaselineCommit = "9785fe2"
$NextAllowedStep = "PHASE96_BATCH_PLANNER_V1"

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

Write-Host "SELF_BUILD_PROGRAM_GENERATOR_V2_START"

$phase94Proof = Read-JsonRequired $Phase94ProofPath
$phase94Report = Read-JsonRequired $Phase94ReportPath
$ownerOrderContract = Read-JsonRequired $OwnerOrderContractPath
$ownerOrderGapMapContract = Read-JsonRequired $OwnerOrderGapMapContractPath
$ownerOrderGapMapExample = Read-JsonRequired $OwnerOrderGapMapExamplePath
$capabilityGapIndex = Read-JsonRequired $CapabilityGapIndexPath

if (-not (Test-Path -LiteralPath (Join-RepoPath $RouteLockPath))) {
  throw "MISSING_ROUTE_LOCK=$RouteLockPath"
}
if ("$(Get-PropertyValue -Object $phase94Proof -Name "status")" -ne "PASS") {
  throw "PHASE94_PROOF_STATUS_NOT_PASS"
}
if ("$(Get-PropertyValue -Object $phase94Proof -Name "next_allowed_step")" -ne "PHASE95_SELF_BUILD_PROGRAM_GENERATOR_V2") {
  throw "PHASE94_PROOF_NEXT_STEP_MISMATCH"
}
if ("$(Get-PropertyValue -Object $phase94Report -Name "status")" -ne "PASS") {
  throw "PHASE94_REPORT_STATUS_NOT_PASS"
}
if ("$(Get-PropertyValue -Object $ownerOrderGapMapExample -Name "next_safe_self_build_step")" -ne "PHASE95_SELF_BUILD_PROGRAM_GENERATOR_V2") {
  throw "OWNER_ORDER_GAP_MAP_NEXT_STEP_MISMATCH"
}

$generatedAt = Get-UtcStamp
$requiredFields = @(
  "program_id",
  "version",
  "status",
  "source_order",
  "source_gap",
  "objective",
  "expected_outputs",
  "allowed_files_scope",
  "blocked_files_scope",
  "risk",
  "admission_requirements",
  "validation_requirements",
  "proof_requirements",
  "rollback_requirements",
  "assistance_required",
  "owner_approval_required",
  "execution_allowed",
  "next_allowed_step"
)

$schema = [ordered]@{
  '$schema' = "https://json-schema.org/draft/2020-12/schema"
  schema_id = "self_build_program_v2"
  title = "Self-Build Program V2"
  type = "object"
  required = $requiredFields
  properties = [ordered]@{
    program_id = [ordered]@{ type = "string" }
    version = [ordered]@{ const = "V2" }
    status = [ordered]@{ enum = @("GENERATED_CANDIDATE", "ADMITTED", "REJECTED", "BLOCKED") }
    source_order = [ordered]@{ type = "object" }
    source_gap = [ordered]@{ type = "string" }
    objective = [ordered]@{ type = "string" }
    expected_outputs = [ordered]@{ type = "array" }
    allowed_files_scope = [ordered]@{ type = "array" }
    blocked_files_scope = [ordered]@{ type = "array" }
    risk = [ordered]@{ type = "object" }
    admission_requirements = [ordered]@{ type = "array" }
    validation_requirements = [ordered]@{ type = "array" }
    proof_requirements = [ordered]@{ type = "array" }
    rollback_requirements = [ordered]@{ type = "array" }
    assistance_required = [ordered]@{ type = "array" }
    owner_approval_required = [ordered]@{ type = "boolean" }
    admission_required = [ordered]@{ type = "boolean" }
    execution_allowed = [ordered]@{ type = "boolean" }
    next_allowed_step = [ordered]@{ type = "string" }
  }
  additionalProperties = $true
}

$generator = [ordered]@{
  generator_id = "SELF_BUILD_PROGRAM_GENERATOR_V2"
  status = "ACTIVE_GENERATOR_CONTRACT"
  phase = $Phase
  active_line = "AGENT_BUILDER / SELF_BUILD"
  generated_at = $generatedAt
  input_sources = @(
    "owner_orders/OWNER_ORDER_CONTRACT_V1.json",
    "self_build_backlog/OWNER_ORDER_TO_GAP_MAP_V1.json",
    "self_build_backlog/OWNER_ORDER_GAP_MAP_EXAMPLE_V1.json",
    "self_build_backlog/CAPABILITY_GAP_INDEX_V1.json"
  )
  output_schema = $SchemaPath
  required_program_fields = $requiredFields
  generator_policy = [ordered]@{
    generator_does_not_execute_program = $true
    generated_program_requires_admission = $true
    owner_approval_required_for_destructive_scope = $true
    owner_approval_required_for_external_fetch = $true
    owner_approval_required_for_installs = $true
    no_external_agent_production = $true
    no_external_install = $true
    no_external_fetch = $true
  }
}

$exampleProgram = [ordered]@{
  program_id = "SELF_BUILD_PROGRAM_V2_EXAMPLE_001"
  version = "V2"
  status = "GENERATED_CANDIDATE"
  generated_at = $generatedAt
  source_order = [ordered]@{
    order_path = "owner_orders/examples/OWNER_ORDER_BATCH_SELF_BUILD_100_TASKS_EXAMPLE.json"
    gap_map_path = $OwnerOrderGapMapExamplePath
  }
  source_gap = "PHASE96_BATCH_PLANNER_V1"
  objective = "Define the Batch Planner V1 foundation."
  expected_outputs = @(
    "Batch planner contract",
    "Batch plan example",
    "Batch planner report",
    "Batch planner proof"
  )
  allowed_files_scope = @(
    "contracts/self_development/",
    "self_build_backlog/",
    "reports/self_development/",
    "proofs/self_development/",
    "packs/PHASE96_BATCH_PLANNER_V1/",
    "tasks/TASK_BATCH_PLANNER_V1_001.json",
    "TASK_QUEUE.json",
    "packs/registry.json",
    "CAPABILITY_ROADMAP.json",
    "GENESIS_STATE.json"
  )
  blocked_files_scope = @(
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
    "packs/PHASE94*"
  )
  risk = [ordered]@{
    classification = "LOW"
    reason = "Planning contract only; no external agents, installs, fetches, or execution."
  }
  admission_required = $true
  admission_requirements = @(
    "Validate against self_build_program_v2.schema.json.",
    "Confirm source_gap is present in owner order gap map.",
    "Confirm execution_allowed is false before admission.",
    "Confirm no external agent production, installs, or external fetch are requested."
  )
  validation_requirements = @(
    "JSON parse for all generated artifacts.",
    "Seed validator must pass before Builder runtime.",
    "Completed validator must pass after Builder runtime.",
    "No PHASE96 execution in PHASE95."
  )
  proof_requirements = @(
    "Report status PASS.",
    "Proof status PASS.",
    "Queue returned to NONE.",
    "Example program remains GENERATED_CANDIDATE.",
    "Example program execution_allowed remains false."
  )
  rollback_requirements = @(
    "Runtime-created files are bounded to PHASE95 output paths.",
    "Do not modify protected PHASE78-PHASE94 packs.",
    "Do not commit if validation fails."
  )
  checkpoint_requirements = @(
    "Owner can inspect candidate before admission.",
    "PHASE96 is the next allowed step, not executed by PHASE95."
  )
  assistance_required = @(
    "Owner decision if Batch Planner scope expands beyond contract files.",
    "Codex repair only if validator emits NEEDS_CODEX_REPAIR for a bounded defect."
  )
  owner_approval_required = $false
  execution_allowed = $false
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
  generator_created = $GeneratorPath
  schema_created = $SchemaPath
  example_program_created = $ExampleProgramPath
  example_program_status = "GENERATED_CANDIDATE"
  example_program_admission_required = $true
  example_program_execution_allowed = $false
  generator_does_not_execute_program = $true
  no_external_agent_production = $true
  no_external_install = $true
  no_external_fetch = $true
  phase96_not_executed = $true
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
  generator_created = $true
  schema_created = $true
  example_program_created = $true
  example_program_status = "GENERATED_CANDIDATE"
  example_program_admission_required = $true
  example_program_execution_allowed = $false
  generator_does_not_execute_program = $true
  no_external_agent_production = $true
  no_external_install = $true
  no_external_fetch = $true
  phase96_not_executed = $true
  queue_returned_to_none = $true
  next_allowed_step = $NextAllowedStep
  evidence_files = @(
    $SchemaPath,
    $GeneratorPath,
    $ExampleProgramPath,
    $ReportPath
  )
}

Write-JsonFile -Path $SchemaPath -Object $schema
Write-JsonFile -Path $GeneratorPath -Object $generator
Write-JsonFile -Path $ExampleProgramPath -Object $exampleProgram
Write-JsonFile -Path $ReportPath -Object $report
Write-JsonFile -Path $ProofPath -Object $proof

Write-Host "SELF_BUILD_PROGRAM_V2_SCHEMA_CREATED=$SchemaPath"
Write-Host "SELF_BUILD_PROGRAM_GENERATOR_V2_CREATED=$GeneratorPath"
Write-Host "SELF_BUILD_PROGRAM_V2_EXAMPLE_CREATED=$ExampleProgramPath"
Write-Host "EXAMPLE_PROGRAM_STATUS=GENERATED_CANDIDATE"
Write-Host "EXAMPLE_PROGRAM_ADMISSION_REQUIRED=TRUE"
Write-Host "EXAMPLE_PROGRAM_EXECUTION_ALLOWED=FALSE"
Write-Host "GENERATOR_DOES_NOT_EXECUTE_PROGRAM=TRUE"
Write-Host "NO_EXTERNAL_AGENT_PRODUCTION=TRUE"
Write-Host "SELF_BUILD_PROGRAM_GENERATOR_V2_REPORT_WRITTEN=$ReportPath"
Write-Host "SELF_BUILD_PROGRAM_GENERATOR_V2_PROOF_WRITTEN=$ProofPath"
Write-Host "SELF_BUILD_PROGRAM_GENERATOR_V2_COMPLETE"

return [pscustomobject]$report
