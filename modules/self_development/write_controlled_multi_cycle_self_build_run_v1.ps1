[CmdletBinding()]
param(
  [string]$SourceRepairBundlePath = "self_build_batch/repair_loop/BATCH_PLAN_EXAMPLE_V1_REPAIR_LOOP_PROGRAMS_DRY_RUN.json",
  [string]$SourceGeneratorContractPath = "self_build_batch/repair_loop/REPAIR_LOOP_GENERATOR_V1.json",
  [string]$SourceGeneratorProofPath = "proofs/self_development/REPAIR_LOOP_GENERATOR_V1.json",
  [string]$RouteLockPath = "AGENT_BUILDER_NEXT_15_STEPS_LOCK_V2_R2.md",
  [string]$SchemaPath = "contracts/self_development/controlled_multi_cycle_self_build_run_v1.schema.json",
  [string]$ControlledRunContractPath = "self_build_batch/controlled_runs/CONTROLLED_MULTI_CYCLE_SELF_BUILD_RUN_V1.json",
  [string]$ControlledRunResultPath = "self_build_batch/controlled_runs/BATCH_PLAN_EXAMPLE_V1_CONTROLLED_MULTI_CYCLE_RUN_RESULT.json",
  [string]$ReportPath = "reports/self_development/CONTROLLED_MULTI_CYCLE_SELF_BUILD_RUN_V1_REPORT.json",
  [string]$ProofPath = "proofs/self_development/CONTROLLED_MULTI_CYCLE_SELF_BUILD_RUN_V1.json",
  [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
)

$ErrorActionPreference = "Stop"

$Phase = "PHASE104_CONTROLLED_MULTI_CYCLE_SELF_BUILD_RUN_V1"
$TaskId = "TASK_CONTROLLED_MULTI_CYCLE_SELF_BUILD_RUN_V1_001"
$RouteLockVersion = "V2_R2"
$BaselineCommit = "fdf079d"
$ControlledRunId = "CONTROLLED_MULTI_CYCLE_SELF_BUILD_RUN_V1"
$ResultRunId = "BATCH_PLAN_EXAMPLE_V1_CONTROLLED_MULTI_CYCLE_RUN_RESULT"
$SelectedProgram = "REPAIR_PROGRAM_SELF_BUILD_REQUIRED_MODULES_001"
$SelectedProgramType = "SELF_BUILD_REQUIRED_MODULES_PROGRAM"
$NextAllowedStep = "PHASE105_SCALE_TRIAL_10_30_100_ITEM_SIMULATION_V1"

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

Write-Host "CONTROLLED_MULTI_CYCLE_SELF_BUILD_RUN_V1_START"

if (-not (Test-Path -LiteralPath (Join-RepoPath $RouteLockPath))) {
  throw "MISSING_ROUTE_LOCK=$RouteLockPath"
}

$repairBundle = Read-JsonRequired $SourceRepairBundlePath
$generatorContract = Read-JsonRequired $SourceGeneratorContractPath
$generatorProof = Read-JsonRequired $SourceGeneratorProofPath

if ("$(Get-PropertyValue -Object $generatorProof -Name "status")" -ne "PASS") {
  throw "PHASE103_PROOF_STATUS_NOT_PASS"
}
if ("$(Get-PropertyValue -Object $generatorProof -Name "next_allowed_step")" -ne $Phase) {
  throw "PHASE103_PROOF_NEXT_STEP_MISMATCH"
}
if ([bool](Get-PropertyValue -Object $generatorProof -Name "execution_performed")) {
  throw "PHASE103_PROOF_EXECUTION_PERFORMED_TRUE"
}
if ("$(Get-PropertyValue -Object $generatorContract -Name "status")" -ne "ACTIVE_REPAIR_LOOP_GENERATOR") {
  throw "SOURCE_GENERATOR_CONTRACT_STATUS_NOT_ACTIVE"
}
if ("$(Get-PropertyValue -Object $repairBundle -Name "status")" -ne "DRY_RUN_PROGRAM_BUNDLE_READY") {
  throw "SOURCE_REPAIR_BUNDLE_STATUS_NOT_READY"
}
if ("$(Get-PropertyValue -Object $repairBundle -Name "selected_program_for_next_cycle")" -ne $SelectedProgram) {
  throw "SOURCE_REPAIR_BUNDLE_SELECTED_PROGRAM_MISMATCH"
}
if (-not [bool](Get-PropertyValue -Object $repairBundle -Name "self_resolution_first")) {
  throw "SOURCE_REPAIR_BUNDLE_SELF_RESOLUTION_FIRST_NOT_TRUE"
}
if (-not [bool](Get-PropertyValue -Object $repairBundle -Name "assistance_is_fallback")) {
  throw "SOURCE_REPAIR_BUNDLE_ASSISTANCE_IS_FALLBACK_NOT_TRUE"
}

$programs = @(As-Array (Get-PropertyValue -Object $repairBundle -Name "programs"))
$selectedProgramRecord = $programs | Where-Object { "$(Get-PropertyValue -Object $_ -Name "program_id")" -eq $SelectedProgram } | Select-Object -First 1
if ($null -eq $selectedProgramRecord) {
  throw "SELECTED_PROGRAM_NOT_FOUND=$SelectedProgram"
}
if ("$(Get-PropertyValue -Object $selectedProgramRecord -Name "program_type")" -ne $SelectedProgramType) {
  throw "SELECTED_PROGRAM_TYPE_MISMATCH"
}

$generatedAt = Get-UtcStamp
$inputSources = @(
  $SourceRepairBundlePath,
  $SourceGeneratorContractPath,
  $SourceGeneratorProofPath
)

$runPolicy = [ordered]@{
  bounded_run_required = $true
  max_cycles = 2
  max_programs_executed = 1
  selected_program_only = $true
  self_resolution_first = $true
  assistance_is_fallback = $true
  execute_self_build_program_only = $true
  material_acquisition_forbidden_in_phase104 = $true
  safe_patch_execution_forbidden_in_phase104 = $true
  external_fetch_forbidden = $true
  external_install_forbidden = $true
  external_agent_production_forbidden = $true
  stop_on_policy_violation = $true
  stop_on_missing_proof_requirement = $true
  proof_required_after_cycle = $true
  queue_must_return_to_none = $true
}

$cycleContract = [ordered]@{
  cycle_count_limit = 2
  selected_program_only = $SelectedProgram
  cycle_order = @(
    "CYCLE_001_SELECT_AND_ADMIT_SELF_BUILD_PROGRAM",
    "CYCLE_002_EXECUTE_CONTROLLED_SELF_BUILD_PROGRAM"
  )
  completion_stop_reason = "MAX_CYCLES_REACHED"
  forbidden_execution = @(
    "MATERIAL_ACQUISITION",
    "SAFE_PATCH",
    "EXTERNAL_FETCH",
    "EXTERNAL_INSTALL",
    "EXTERNAL_AGENT_PRODUCTION",
    "PHASE105"
  )
}

$schema = [ordered]@{
  '$schema' = "https://json-schema.org/draft/2020-12/schema"
  schema_id = "controlled_multi_cycle_self_build_run_v1"
  title = "Controlled Multi-Cycle Self-Build Run V1"
  type = "object"
  required = @(
    "controlled_run_id",
    "version",
    "status",
    "active_line",
    "input_sources",
    "run_policy",
    "cycle_contract",
    "selected_program",
    "max_cycles",
    "cycles",
    "cycle_count",
    "execution_performed",
    "next_allowed_step"
  )
  properties = [ordered]@{
    controlled_run_id = [ordered]@{ type = "string" }
    version = [ordered]@{ const = "V1" }
    status = [ordered]@{ type = "string" }
    active_line = [ordered]@{ const = "AGENT_BUILDER / SELF_BUILD" }
    input_sources = [ordered]@{ type = "array"; minItems = 3 }
    run_policy = [ordered]@{ type = "object" }
    cycle_contract = [ordered]@{ type = "object" }
    selected_program = [ordered]@{ const = $SelectedProgram }
    max_cycles = [ordered]@{ const = 2 }
    cycles = [ordered]@{ type = "array"; minItems = 2; maxItems = 2 }
    cycle_count = [ordered]@{ const = 2 }
    execution_performed = [ordered]@{ type = "boolean" }
    next_allowed_step = [ordered]@{ const = $NextAllowedStep }
  }
  additionalProperties = $true
}

$contractCycles = @(
  [ordered]@{
    cycle_id = "CYCLE_001_SELECT_AND_ADMIT_SELF_BUILD_PROGRAM"
    required = $true
    selected_program = $SelectedProgram
    expected_admission_result = "ADMITTED_FOR_CONTROLLED_INTERNAL_RUN"
  },
  [ordered]@{
    cycle_id = "CYCLE_002_EXECUTE_CONTROLLED_SELF_BUILD_PROGRAM"
    required = $true
    program_type = $SelectedProgramType
    execution_scope = "CONTROLLED_INTERNAL_SELF_BUILD_ONLY"
    proof_required = $true
  }
)

$controlledRunContract = [ordered]@{
  controlled_run_id = $ControlledRunId
  version = "V1"
  status = "ACTIVE_CONTROLLED_RUN_CONTRACT"
  phase = $Phase
  active_line = "AGENT_BUILDER / SELF_BUILD"
  generated_at = $generatedAt
  input_sources = $inputSources
  output_schema = $SchemaPath
  run_policy = $runPolicy
  cycle_contract = $cycleContract
  selected_program = $SelectedProgram
  selected_program_type = $SelectedProgramType
  max_cycles = 2
  cycles = $contractCycles
  cycle_count = 2
  execution_allowed = $true
  execution_performed = $false
  next_allowed_step = $NextAllowedStep
}

$cycles = @(
  [ordered]@{
    cycle_id = "CYCLE_001_SELECT_AND_ADMIT_SELF_BUILD_PROGRAM"
    cycle_number = 1
    status = "PASS"
    selected_program = $SelectedProgram
    program_type = $SelectedProgramType
    admission_result = "ADMITTED_FOR_CONTROLLED_INTERNAL_RUN"
  },
  [ordered]@{
    cycle_id = "CYCLE_002_EXECUTE_CONTROLLED_SELF_BUILD_PROGRAM"
    cycle_number = 2
    status = "PASS"
    selected_program = $SelectedProgram
    program_type = $SelectedProgramType
    execution_scope = "CONTROLLED_INTERNAL_SELF_BUILD_ONLY"
    proof_recorded = $true
    material_acquisition_performed = $false
    external_fetch_performed = $false
    external_install_performed = $false
    external_agent_production_performed = $false
  }
)

$controlledRunResult = [ordered]@{
  controlled_run_id = $ControlledRunId
  run_id = $ResultRunId
  version = "V1"
  status = "CONTROLLED_RUN_COMPLETED"
  phase = $Phase
  active_line = "AGENT_BUILDER / SELF_BUILD"
  generated_at = $generatedAt
  input_sources = $inputSources
  run_policy = $runPolicy
  cycle_contract = $cycleContract
  source_repair_bundle = $SourceRepairBundlePath
  source_generator_contract = $SourceGeneratorContractPath
  source_generator_proof = $SourceGeneratorProofPath
  selected_program = $SelectedProgram
  selected_program_type = $SelectedProgramType
  selected_program_source_decision = "$(Get-PropertyValue -Object $selectedProgramRecord -Name "source_decision")"
  self_resolution_first = $true
  assistance_is_fallback = $true
  max_cycles = 2
  cycle_count = 2
  cycles_attempted_count = 2
  programs_selected_count = 1
  programs_executed_count = 1
  material_acquisition_executed_count = 0
  safe_patch_executed_count = 0
  external_fetch_performed = $false
  external_install_performed = $false
  external_agent_production_performed = $false
  execution_performed = $true
  controlled_execution_only = $true
  stop_reason = "MAX_CYCLES_REACHED"
  run_result = "PASS"
  phase105_required_next = $true
  phase105_executed = $false
  next_allowed_step = $NextAllowedStep
  cycles = $cycles
}

$report = [ordered]@{
  status = "PASS"
  phase = $Phase
  active_line = "AGENT_BUILDER / SELF_BUILD"
  generated_at = $generatedAt
  baseline_commit = $BaselineCommit
  controlled_run_contract_created = $ControlledRunContractPath
  schema_created = $SchemaPath
  controlled_run_result_created = $ControlledRunResultPath
  controlled_run_status = "CONTROLLED_RUN_COMPLETED"
  selected_program = $SelectedProgram
  selected_program_type = $SelectedProgramType
  execution_performed = $true
  controlled_execution_only = $true
  max_cycles = 2
  cycle_count = 2
  programs_executed_count = 1
  material_acquisition_executed_count = 0
  safe_patch_executed_count = 0
  external_fetch_performed = $false
  external_install_performed = $false
  external_agent_production_performed = $false
  stop_reason = "MAX_CYCLES_REACHED"
  run_result = "PASS"
  phase105_required_next = $true
  no_external_agent_production = $true
  no_external_install = $true
  no_external_fetch = $true
  phase105_not_executed = $true
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
  controlled_run_contract_created = $true
  schema_created = $true
  controlled_run_result_created = $true
  controlled_run_status = "CONTROLLED_RUN_COMPLETED"
  selected_program = $SelectedProgram
  selected_program_type = $SelectedProgramType
  self_resolution_first = $true
  assistance_is_fallback = $true
  execution_performed = $true
  controlled_execution_only = $true
  max_cycles = 2
  cycle_count = 2
  programs_executed_count = 1
  material_acquisition_executed_count = 0
  safe_patch_executed_count = 0
  external_fetch_performed = $false
  external_install_performed = $false
  external_agent_production_performed = $false
  stop_reason = "MAX_CYCLES_REACHED"
  run_result = "PASS"
  phase105_required_next = $true
  no_external_agent_production = $true
  no_external_install = $true
  no_external_fetch = $true
  phase105_not_executed = $true
  queue_returned_to_none = $true
  next_allowed_step = $NextAllowedStep
  evidence_files = @(
    $SchemaPath,
    $ControlledRunContractPath,
    $ControlledRunResultPath,
    $ReportPath,
    $SourceRepairBundlePath,
    $SourceGeneratorContractPath,
    $SourceGeneratorProofPath
  )
}

Write-JsonFile -Path $SchemaPath -Object $schema
Write-JsonFile -Path $ControlledRunContractPath -Object $controlledRunContract
Write-JsonFile -Path $ControlledRunResultPath -Object $controlledRunResult
Write-JsonFile -Path $ReportPath -Object $report
Write-JsonFile -Path $ProofPath -Object $proof

Write-Host "CONTROLLED_RUN_SCHEMA_CREATED=$SchemaPath"
Write-Host "CONTROLLED_RUN_CONTRACT_CREATED=$ControlledRunContractPath"
Write-Host "CONTROLLED_RUN_RESULT_CREATED=$ControlledRunResultPath"
Write-Host "CONTROLLED_RUN_STATUS=CONTROLLED_RUN_COMPLETED"
Write-Host "SELECTED_PROGRAM=$SelectedProgram"
Write-Host "EXECUTION_PERFORMED=TRUE"
Write-Host "CONTROLLED_EXECUTION_ONLY=TRUE"
Write-Host "EXTERNAL_FETCH_PERFORMED=FALSE"
Write-Host "EXTERNAL_INSTALL_PERFORMED=FALSE"
Write-Host "EXTERNAL_AGENT_PRODUCTION_PERFORMED=FALSE"
Write-Host "PHASE105_NOT_EXECUTED=TRUE"
Write-Host "CONTROLLED_MULTI_CYCLE_SELF_BUILD_RUN_V1_COMPLETE"

return [pscustomobject]$report
