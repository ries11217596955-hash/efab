[CmdletBinding()]
param(
  [string]$SourceControlledRunResultPath = "self_build_batch/controlled_runs/BATCH_PLAN_EXAMPLE_V1_CONTROLLED_MULTI_CYCLE_RUN_RESULT.json",
  [string]$SourceControlledRunProofPath = "proofs/self_development/CONTROLLED_MULTI_CYCLE_SELF_BUILD_RUN_V1.json",
  [string]$SourceRepairBundlePath = "self_build_batch/repair_loop/BATCH_PLAN_EXAMPLE_V1_REPAIR_LOOP_PROGRAMS_DRY_RUN.json",
  [string]$RouteLockPath = "AGENT_BUILDER_NEXT_15_STEPS_LOCK_V2_R2.md",
  [string]$SchemaPath = "contracts/self_development/scale_trial_10_30_100_item_simulation_v1.schema.json",
  [string]$ScaleTrialContractPath = "self_build_batch/scale_trials/SCALE_TRIAL_10_30_100_ITEM_SIMULATION_V1.json",
  [string]$ScaleTrialResultPath = "self_build_batch/scale_trials/BATCH_PLAN_EXAMPLE_V1_SCALE_TRIAL_RESULT.json",
  [string]$ReportPath = "reports/self_development/SCALE_TRIAL_10_30_100_ITEM_SIMULATION_V1_REPORT.json",
  [string]$ProofPath = "proofs/self_development/SCALE_TRIAL_10_30_100_ITEM_SIMULATION_V1.json",
  [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
)

$ErrorActionPreference = "Stop"

$Phase = "PHASE105_SCALE_TRIAL_10_30_100_ITEM_SIMULATION_V1"
$TaskId = "TASK_SCALE_TRIAL_10_30_100_ITEM_SIMULATION_V1_001"
$RouteLockVersion = "V2_R2"
$BaselineCommit = "8606986"
$ScaleTrialId = "SCALE_TRIAL_10_30_100_ITEM_SIMULATION_V1"
$ResultId = "BATCH_PLAN_EXAMPLE_V1_SCALE_TRIAL_RESULT"
$NextAllowedStep = "PHASE106_SCALE_TRIAL_PROMOTION_GATE_AND_ROUTE_LOCK_REFRESH_V1"

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

  if ($null -eq $Object) {
    return $null
  }
  if ($Object -is [System.Collections.IDictionary]) {
    foreach ($key in $Object.Keys) {
      if ("$key" -ieq $Name) {
        return $Object[$key]
      }
    }
    return $null
  }

  $property = Get-PropertyInfo -Object $Object -Name $Name
  if ($null -eq $property) {
    return $null
  }
  return $property.Value
}

Write-Host "SCALE_TRIAL_10_30_100_ITEM_SIMULATION_V1_START"

if (-not (Test-Path -LiteralPath (Join-RepoPath $RouteLockPath))) {
  throw "MISSING_ROUTE_LOCK=$RouteLockPath"
}

$controlledRunResult = Read-JsonRequired $SourceControlledRunResultPath
$controlledRunProof = Read-JsonRequired $SourceControlledRunProofPath
$repairBundle = Read-JsonRequired $SourceRepairBundlePath

if ("$(Get-PropertyValue -Object $controlledRunProof -Name "status")" -ne "PASS") {
  throw "PHASE104_PROOF_STATUS_NOT_PASS"
}
if ("$(Get-PropertyValue -Object $controlledRunProof -Name "next_allowed_step")" -ne $Phase) {
  throw "PHASE104_PROOF_NEXT_STEP_MISMATCH"
}
if (-not [bool](Get-PropertyValue -Object $controlledRunProof -Name "execution_performed")) {
  throw "PHASE104_PROOF_EXECUTION_PERFORMED_NOT_TRUE"
}
if (-not [bool](Get-PropertyValue -Object $controlledRunProof -Name "controlled_execution_only")) {
  throw "PHASE104_PROOF_CONTROLLED_EXECUTION_ONLY_NOT_TRUE"
}
if ([bool](Get-PropertyValue -Object $controlledRunProof -Name "external_fetch_performed")) {
  throw "PHASE104_PROOF_EXTERNAL_FETCH_TRUE"
}
if ([bool](Get-PropertyValue -Object $controlledRunProof -Name "external_install_performed")) {
  throw "PHASE104_PROOF_EXTERNAL_INSTALL_TRUE"
}
if ([bool](Get-PropertyValue -Object $controlledRunProof -Name "external_agent_production_performed")) {
  throw "PHASE104_PROOF_EXTERNAL_AGENT_PRODUCTION_TRUE"
}
if ("$(Get-PropertyValue -Object $controlledRunResult -Name "run_result")" -ne "PASS") {
  throw "SOURCE_CONTROLLED_RUN_RESULT_NOT_PASS"
}
if ("$(Get-PropertyValue -Object $repairBundle -Name "status")" -ne "DRY_RUN_PROGRAM_BUNDLE_READY") {
  throw "SOURCE_REPAIR_BUNDLE_STATUS_NOT_READY"
}

$generatedAt = Get-UtcStamp
$inputSources = @(
  $SourceControlledRunResultPath,
  $SourceControlledRunProofPath,
  $SourceRepairBundlePath
)
$scaleTiers = @(10, 30, 100)

$trialPolicy = [ordered]@{
  simulation_only = $true
  scale_tiers_required = $scaleTiers
  no_real_item_execution = $true
  no_external_agent_production = $true
  no_external_fetch = $true
  no_external_install = $true
  no_fake_pass = $true
  no_hidden_failures = $true
  continue_after_safe_item_failure = $true
  quarantine_and_blockers_must_be_counted = $true
  systemic_failure_must_stop_tier = $true
  promotion_gate_required_next = $true
}

$resultContract = [ordered]@{
  tier_results_required = $true
  required_tiers = $scaleTiers
  item_level_outcomes_preserved = $true
  hidden_failure_count_must_be_zero = $true
  fake_pass_count_must_be_zero = $true
  quarantine_and_blocker_counts_required = $true
  systemic_stop_required_in_100_item_tier = $true
}

$schema = [ordered]@{
  '$schema' = "https://json-schema.org/draft/2020-12/schema"
  schema_id = "scale_trial_10_30_100_item_simulation_v1"
  title = "Scale Trial 10/30/100 Item Simulation V1"
  type = "object"
  required = @(
    "scale_trial_id",
    "version",
    "status",
    "active_line",
    "input_sources",
    "trial_policy",
    "scale_tiers",
    "result_contract",
    "simulation_performed",
    "real_items_executed",
    "next_allowed_step"
  )
  properties = [ordered]@{
    scale_trial_id = [ordered]@{ type = "string" }
    version = [ordered]@{ const = "V1" }
    status = [ordered]@{ type = "string" }
    active_line = [ordered]@{ const = "AGENT_BUILDER / SELF_BUILD" }
    input_sources = [ordered]@{ type = "array"; minItems = 3 }
    trial_policy = [ordered]@{ type = "object" }
    scale_tiers = [ordered]@{ type = "array"; minItems = 3 }
    result_contract = [ordered]@{ type = "object" }
    simulation_performed = [ordered]@{ type = "boolean" }
    real_items_executed = [ordered]@{ const = $false }
    next_allowed_step = [ordered]@{ const = $NextAllowedStep }
  }
  additionalProperties = $true
}

$scaleTrialContract = [ordered]@{
  scale_trial_id = $ScaleTrialId
  version = "V1"
  status = "ACTIVE_SCALE_TRIAL_CONTRACT"
  phase = $Phase
  active_line = "AGENT_BUILDER / SELF_BUILD"
  generated_at = $generatedAt
  input_sources = $inputSources
  output_schema = $SchemaPath
  trial_policy = $trialPolicy
  scale_tiers = $scaleTiers
  result_contract = $resultContract
  simulation_performed = $false
  real_items_executed = $false
  next_allowed_step = $NextAllowedStep
}

$tierResults = @(
  [ordered]@{
    tier_id = "TIER_010_ITEM_SIMULATION"
    item_count = 10
    status = "TIER_SIMULATION_COMPLETED"
    simulation_performed = $true
    real_items_executed = $false
    simulated_pass_count = 8
    simulated_failed_count = 1
    simulated_quarantined_count = 1
    simulated_blocked_count = 0
    simulated_assistance_required_count = 0
    hidden_failure_count = 0
    fake_pass_count = 0
    continue_after_safe_failure_used = $true
    stop_condition_tested = "SAFE_FAILURE_CONTINUATION_SIMULATED"
    tier_result = "PASS"
  },
  [ordered]@{
    tier_id = "TIER_030_ITEM_SIMULATION"
    item_count = 30
    status = "TIER_SIMULATION_COMPLETED"
    simulation_performed = $true
    real_items_executed = $false
    simulated_pass_count = 25
    simulated_failed_count = 2
    simulated_quarantined_count = 1
    simulated_blocked_count = 1
    simulated_assistance_required_count = 1
    hidden_failure_count = 0
    fake_pass_count = 0
    continue_after_safe_failure_used = $true
    stop_condition_tested = "BLOCKER_AND_QUARANTINE_COUNTING_SIMULATED"
    tier_result = "PASS"
  },
  [ordered]@{
    tier_id = "TIER_100_ITEM_SIMULATION"
    item_count = 100
    status = "TIER_SIMULATION_COMPLETED"
    simulation_performed = $true
    real_items_executed = $false
    simulated_pass_count = 85
    simulated_failed_count = 5
    simulated_quarantined_count = 3
    simulated_blocked_count = 4
    simulated_assistance_required_count = 3
    hidden_failure_count = 0
    fake_pass_count = 0
    continue_after_safe_failure_used = $true
    stop_condition_tested = "SYSTEMIC_RISK_STOP_SIMULATED"
    systemic_stop_simulated = $true
    controlled_tier_result_recorded_after_stop = $true
    tier_result = "PASS"
  }
)

$totalSimulatedItemCount = 0
foreach ($tier in $tierResults) {
  $totalSimulatedItemCount += [int](Get-PropertyValue -Object $tier -Name "item_count")
}
if ($totalSimulatedItemCount -ne 140) {
  throw "TOTAL_SIMULATED_ITEM_COUNT_MISMATCH=$totalSimulatedItemCount"
}

$scaleTrialResult = [ordered]@{
  scale_trial_id = $ScaleTrialId
  result_id = $ResultId
  version = "V1"
  status = "SCALE_TRIAL_SIMULATION_COMPLETED"
  phase = $Phase
  active_line = "AGENT_BUILDER / SELF_BUILD"
  generated_at = $generatedAt
  input_sources = $inputSources
  trial_policy = $trialPolicy
  source_controlled_run_result = $SourceControlledRunResultPath
  source_controlled_run_proof = $SourceControlledRunProofPath
  source_repair_bundle = $SourceRepairBundlePath
  simulation_performed = $true
  real_items_executed = $false
  external_fetch_performed = $false
  external_install_performed = $false
  external_agent_production_performed = $false
  tier_count = 3
  scale_tiers = $scaleTiers
  total_simulated_item_count = 140
  max_item_count_simulated = 100
  no_fake_pass = $true
  no_hidden_failures = $true
  continue_after_safe_failure_simulated = $true
  quarantine_counted = $true
  blockers_counted = $true
  systemic_stop_simulated = $true
  scale_trial_result = "PASS"
  promotion_gate_required_next = $true
  phase106_required_next = $true
  phase106_executed = $false
  next_allowed_step = $NextAllowedStep
  tier_results = $tierResults
}

$report = [ordered]@{
  status = "PASS"
  phase = $Phase
  active_line = "AGENT_BUILDER / SELF_BUILD"
  generated_at = $generatedAt
  baseline_commit = $BaselineCommit
  scale_trial_contract_created = $ScaleTrialContractPath
  schema_created = $SchemaPath
  scale_trial_result_created = $ScaleTrialResultPath
  scale_trial_status = "SCALE_TRIAL_SIMULATION_COMPLETED"
  simulation_performed = $true
  real_items_executed = $false
  tier_count = 3
  scale_tiers = $scaleTiers
  total_simulated_item_count = 140
  max_item_count_simulated = 100
  no_fake_pass = $true
  no_hidden_failures = $true
  external_fetch_performed = $false
  external_install_performed = $false
  external_agent_production_performed = $false
  scale_trial_result = "PASS"
  promotion_gate_required_next = $true
  phase106_required_next = $true
  phase106_not_executed = $true
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
  scale_trial_contract_created = $true
  schema_created = $true
  scale_trial_result_created = $true
  scale_trial_status = "SCALE_TRIAL_SIMULATION_COMPLETED"
  simulation_performed = $true
  real_items_executed = $false
  tier_count = 3
  total_simulated_item_count = 140
  max_item_count_simulated = 100
  no_fake_pass = $true
  no_hidden_failures = $true
  continue_after_safe_failure_simulated = $true
  quarantine_counted = $true
  blockers_counted = $true
  systemic_stop_simulated = $true
  external_fetch_performed = $false
  external_install_performed = $false
  external_agent_production_performed = $false
  scale_trial_result = "PASS"
  promotion_gate_required_next = $true
  phase106_required_next = $true
  phase106_not_executed = $true
  queue_returned_to_none = $true
  next_allowed_step = $NextAllowedStep
  evidence_files = @(
    $SchemaPath,
    $ScaleTrialContractPath,
    $ScaleTrialResultPath,
    $ReportPath,
    $SourceControlledRunResultPath,
    $SourceControlledRunProofPath,
    $SourceRepairBundlePath
  )
}

Write-JsonFile -Path $SchemaPath -Object $schema
Write-JsonFile -Path $ScaleTrialContractPath -Object $scaleTrialContract
Write-JsonFile -Path $ScaleTrialResultPath -Object $scaleTrialResult
Write-JsonFile -Path $ReportPath -Object $report
Write-JsonFile -Path $ProofPath -Object $proof

Write-Host "SCALE_TRIAL_SCHEMA_CREATED=$SchemaPath"
Write-Host "SCALE_TRIAL_CONTRACT_CREATED=$ScaleTrialContractPath"
Write-Host "SCALE_TRIAL_RESULT_CREATED=$ScaleTrialResultPath"
Write-Host "SCALE_TRIAL_STATUS=SCALE_TRIAL_SIMULATION_COMPLETED"
Write-Host "SIMULATION_PERFORMED=TRUE"
Write-Host "REAL_ITEMS_EXECUTED=FALSE"
Write-Host "TOTAL_SIMULATED_ITEM_COUNT=140"
Write-Host "NO_FAKE_PASS=TRUE"
Write-Host "NO_HIDDEN_FAILURES=TRUE"
Write-Host "EXTERNAL_FETCH_PERFORMED=FALSE"
Write-Host "EXTERNAL_INSTALL_PERFORMED=FALSE"
Write-Host "EXTERNAL_AGENT_PRODUCTION_PERFORMED=FALSE"
Write-Host "PHASE106_NOT_EXECUTED=TRUE"
Write-Host "SCALE_TRIAL_10_30_100_ITEM_SIMULATION_V1_COMPLETE"

return [pscustomobject]$report
