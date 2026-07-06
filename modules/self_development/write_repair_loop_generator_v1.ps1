[CmdletBinding()]
param(
  [string]$SourceNextActionPlanPath = "self_build_batch/next_actions/BATCH_PLAN_EXAMPLE_V1_NEXT_ACTION_PLAN_DRY_RUN.json",
  [string]$SourceDecisionKernelPath = "self_build_batch/next_actions/AUTO_NEXT_GAP_DECISION_KERNEL_V1.json",
  [string]$SourceDecisionProofPath = "proofs/self_development/AUTO_NEXT_GAP_DECISION_V1.json",
  [string]$RouteLockPath = "AGENT_BUILDER_NEXT_15_STEPS_LOCK_V2_R2.md",
  [string]$SchemaPath = "contracts/self_development/repair_loop_generator_v1.schema.json",
  [string]$RepairLoopGeneratorPath = "self_build_batch/repair_loop/REPAIR_LOOP_GENERATOR_V1.json",
  [string]$DryRunProgramBundlePath = "self_build_batch/repair_loop/BATCH_PLAN_EXAMPLE_V1_REPAIR_LOOP_PROGRAMS_DRY_RUN.json",
  [string]$ReportPath = "reports/self_development/REPAIR_LOOP_GENERATOR_V1_REPORT.json",
  [string]$ProofPath = "proofs/self_development/REPAIR_LOOP_GENERATOR_V1.json",
  [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
)

$ErrorActionPreference = "Stop"

$Phase = "PHASE103_REPAIR_LOOP_GENERATOR_V1"
$TaskId = "TASK_REPAIR_LOOP_GENERATOR_V1_001"
$RouteLockVersion = "V2_R2"
$BaselineCommit = "3e99885"
$NextAllowedStep = "PHASE104_CONTROLLED_MULTI_CYCLE_SELF_BUILD_RUN_V1"

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

function Get-DecisionByValue {
  param(
    [object[]]$Decisions,
    [string]$Decision
  )

  return ($Decisions | Where-Object { "$(Get-PropertyValue -Object $_ -Name "decision")" -eq $Decision } | Select-Object -First 1)
}

function New-ProgramDraft {
  param(
    [object]$Decision,
    [string]$ProgramId,
    [string]$ProgramType,
    [string]$Objective,
    [string[]]$PlannedFiles,
    [string[]]$AllowedScope,
    [string[]]$BlockedScope,
    [bool]$MaterialPolicyRequired,
    [string[]]$ProofRequirements,
    [string[]]$ValidationRequirements,
    [string]$ResumeAfterSuccess,
    [string]$NextRuntimeCandidate
  )

  return [pscustomobject][ordered]@{
    program_id = $ProgramId
    program_type = $ProgramType
    source_decision_id = "$(Get-PropertyValue -Object $Decision -Name "decision_id")"
    source_item_id = "$(Get-PropertyValue -Object $Decision -Name "item_id")"
    source_decision = "$(Get-PropertyValue -Object $Decision -Name "decision")"
    objective = $Objective
    missing_capability = "$(Get-PropertyValue -Object $Decision -Name "missing_capability")"
    required_modules = @(As-Array (Get-PropertyValue -Object $Decision -Name "required_modules"))
    planned_files = $PlannedFiles
    allowed_scope = $AllowedScope
    blocked_scope = $BlockedScope
    admission_required = $true
    execution_allowed_now = $false
    material_policy_required = $MaterialPolicyRequired
    proof_requirements = $ProofRequirements
    validation_requirements = $ValidationRequirements
    fallback_only_if_self_blocked = [bool](Get-PropertyValue -Object $Decision -Name "fallback_allowed_only_if_self_blocked")
    resume_after_success = $ResumeAfterSuccess
    next_runtime_candidate = $NextRuntimeCandidate
  }
}

Write-Host "REPAIR_LOOP_GENERATOR_V1_START"

$nextActionPlan = Read-JsonRequired $SourceNextActionPlanPath
$decisionKernel = Read-JsonRequired $SourceDecisionKernelPath
$decisionProof = Read-JsonRequired $SourceDecisionProofPath

if (-not (Test-Path -LiteralPath (Join-RepoPath $RouteLockPath))) {
  throw "MISSING_ROUTE_LOCK=$RouteLockPath"
}
if ("$(Get-PropertyValue -Object $decisionProof -Name "status")" -ne "PASS") {
  throw "PHASE102_PROOF_STATUS_NOT_PASS"
}
if ("$(Get-PropertyValue -Object $decisionProof -Name "next_allowed_step")" -ne "PHASE103_REPAIR_LOOP_GENERATOR_V1") {
  throw "PHASE102_PROOF_NEXT_STEP_MISMATCH"
}
if ("$(Get-PropertyValue -Object $nextActionPlan -Name "status")" -ne "DRY_RUN_NEXT_ACTIONS_READY") {
  throw "SOURCE_NEXT_ACTION_PLAN_STATUS_NOT_READY"
}
if (-not [bool](Get-PropertyValue -Object $nextActionPlan -Name "self_resolution_first")) {
  throw "SOURCE_NEXT_ACTION_PLAN_SELF_RESOLUTION_FIRST_NOT_TRUE"
}
if (-not [bool](Get-PropertyValue -Object $nextActionPlan -Name "program_generation_required_next")) {
  throw "SOURCE_NEXT_ACTION_PLAN_PROGRAM_GENERATION_REQUIRED_NEXT_NOT_TRUE"
}
if ([bool](Get-PropertyValue -Object $nextActionPlan -Name "execution_allowed")) {
  throw "SOURCE_NEXT_ACTION_PLAN_EXECUTION_ALLOWED_TRUE"
}
if ("$(Get-PropertyValue -Object $decisionKernel -Name "status")" -ne "ACTIVE_DECISION_KERNEL") {
  throw "SOURCE_DECISION_KERNEL_STATUS_NOT_ACTIVE"
}

$decisions = @(As-Array (Get-PropertyValue -Object $nextActionPlan -Name "decisions"))
$selfBuildDecision = Get-DecisionByValue -Decisions $decisions -Decision "SELF_BUILD_REQUIRED_MODULES"
$materialDecision = Get-DecisionByValue -Decisions $decisions -Decision "SELF_ACQUIRE_MATERIAL_UNDER_POLICY"
$safePatchDecision = Get-DecisionByValue -Decisions $decisions -Decision "SELF_PATCH_SAFE_LOCAL_SCOPE"
$fallbackDecision = Get-DecisionByValue -Decisions $decisions -Decision "OWNER_DECISION_REQUIRED_FALLBACK"

if ($null -eq $selfBuildDecision) { throw "SELF_BUILD_REQUIRED_MODULES_DECISION_MISSING" }
if ($null -eq $materialDecision) { throw "SELF_ACQUIRE_MATERIAL_UNDER_POLICY_DECISION_MISSING" }
if ($null -eq $safePatchDecision) { throw "SELF_PATCH_SAFE_LOCAL_SCOPE_DECISION_MISSING" }
if ($null -eq $fallbackDecision) { throw "OWNER_DECISION_REQUIRED_FALLBACK_DECISION_MISSING" }

$programTypes = @(
  "SELF_BUILD_REQUIRED_MODULES_PROGRAM",
  "MATERIAL_ACQUISITION_UNDER_POLICY_PROGRAM",
  "SAFE_LOCAL_PATCH_PROGRAM",
  "RESUME_AFTER_SELF_REPAIR_PLAN"
)

$programs = @(
  (New-ProgramDraft `
    -Decision $selfBuildDecision `
    -ProgramId "REPAIR_PROGRAM_SELF_BUILD_REQUIRED_MODULES_001" `
    -ProgramType "SELF_BUILD_REQUIRED_MODULES_PROGRAM" `
    -Objective "Create the controlled multi-cycle self-build run foundation from the selected PHASE103 self-build-required decision." `
    -PlannedFiles @("packs/PHASE104_CONTROLLED_MULTI_CYCLE_SELF_BUILD_RUN_V1/PACK.json", "packs/PHASE104_CONTROLLED_MULTI_CYCLE_SELF_BUILD_RUN_V1/APPLY.ps1", "packs/PHASE104_CONTROLLED_MULTI_CYCLE_SELF_BUILD_RUN_V1/VALIDATE.ps1", "modules/self_development/write_controlled_multi_cycle_self_build_run_v1.ps1", "tasks/TASK_CONTROLLED_MULTI_CYCLE_SELF_BUILD_RUN_V1_001.json") `
    -AllowedScope @("packs/PHASE104_CONTROLLED_MULTI_CYCLE_SELF_BUILD_RUN_V1/", "modules/self_development/", "contracts/self_development/", "self_build_batch/", "reports/self_development/", "proofs/self_development/", "tasks/", "TASK_QUEUE.json", "packs/registry.json", "CAPABILITY_ROADMAP.json", "GENESIS_STATE.json") `
    -BlockedScope @("generated_agents/", "applied_agents/", ".github/workflows/", "materials/", "operations/", "packs/PHASE78*", "packs/PHASE79*", "packs/PHASE80*", "packs/PHASE81*", "packs/PHASE82*", "packs/PHASE83*", "packs/PHASE84*", "packs/PHASE85*", "packs/PHASE86*", "packs/PHASE87*", "packs/PHASE88*", "packs/PHASE89*", "packs/PHASE90*", "packs/PHASE91*", "packs/PHASE92*", "packs/PHASE93*", "packs/PHASE94*", "packs/PHASE95*", "packs/PHASE96*", "packs/PHASE97*", "packs/PHASE98*", "packs/PHASE99*", "packs/PHASE100*", "packs/PHASE101*", "packs/PHASE102*") `
    -MaterialPolicyRequired $false `
    -ProofRequirements @("PHASE104 proof must PASS", "queue must return to NONE", "no generated program execution without admission", "no hidden unresolved records") `
    -ValidationRequirements @("PHASE104 seed validator passes", "PowerShell parser checks pass", "JSON parse checks pass", "selected pack count is exactly one") `
    -ResumeAfterSuccess "Continue into PHASE104 controlled multi-cycle runtime with admitted repair-loop program drafts only." `
    -NextRuntimeCandidate "PHASE104_CONTROLLED_MULTI_CYCLE_SELF_BUILD_RUN_V1"),
  (New-ProgramDraft `
    -Decision $materialDecision `
    -ProgramId "REPAIR_PROGRAM_MATERIAL_ACQUISITION_UNDER_POLICY_001" `
    -ProgramType "MATERIAL_ACQUISITION_UNDER_POLICY_PROGRAM" `
    -Objective "Prepare a policy-gated material acquisition request draft for quarantined batch items without fetching, installing, trusting, or using materials." `
    -PlannedFiles @("self_build_batch/repair_loop/material_requests/MATERIAL_REQUEST_CANDIDATE_DRY_RUN.json", "contracts/self_development/material_request_candidate_v1.schema.json") `
    -AllowedScope @("self_build_batch/repair_loop/", "contracts/self_development/", "reports/self_development/", "proofs/self_development/") `
    -BlockedScope @("materials/MATERIAL_CATALOG.json", "materials/MATERIAL_POLICY.json", "materials/quarantine/", "generated_agents/", "applied_agents/", ".github/workflows/", "operations/") `
    -MaterialPolicyRequired $true `
    -ProofRequirements @("provenance requirement recorded", "license requirement recorded", "risk review requirement recorded", "quarantine requirement recorded", "wrapper requirement recorded before use", "test requirement recorded before use", "proof requirement recorded before trusted use", "no external fetch performed") `
    -ValidationRequirements @("provenance field required", "license field required", "risk field required", "quarantine gate required", "wrapper/test/proof gates required before trusted use") `
    -ResumeAfterSuccess "Return material candidate to admission policy before any fetch, install, trust, wrapper, or use." `
    -NextRuntimeCandidate "PHASE104_CONTROLLED_MULTI_CYCLE_SELF_BUILD_RUN_V1"),
  (New-ProgramDraft `
    -Decision $safePatchDecision `
    -ProgramId "REPAIR_PROGRAM_SAFE_LOCAL_PATCH_001" `
    -ProgramType "SAFE_LOCAL_PATCH_PROGRAM" `
    -Objective "Draft a safe local patch program for isolated failed batch items while keeping execution blocked until admission." `
    -PlannedFiles @("self_build_batch/repair_loop/patch_plans/SAFE_LOCAL_PATCH_PLAN_DRY_RUN.json", "contracts/self_development/safe_local_patch_plan_v1.schema.json") `
    -AllowedScope @("self_build_batch/repair_loop/", "contracts/self_development/", "modules/self_development/", "reports/self_development/", "proofs/self_development/") `
    -BlockedScope @("generated_agents/", "applied_agents/", ".github/workflows/", "materials/", "operations/", "orchestrator/run.ps1") `
    -MaterialPolicyRequired $false `
    -ProofRequirements @("patch scope must be declared", "validation evidence required before completion", "no PASS without proof", "fallback only after self patch validation blocks") `
    -ValidationRequirements @("allowed scope non-empty", "blocked scope non-empty", "target files declared", "rollback/checkpoint plan declared") `
    -ResumeAfterSuccess "Resume the batch only after the safe patch program passes admission and proof gates." `
    -NextRuntimeCandidate "PHASE104_CONTROLLED_MULTI_CYCLE_SELF_BUILD_RUN_V1"),
  (New-ProgramDraft `
    -Decision $fallbackDecision `
    -ProgramId "REPAIR_PROGRAM_RESUME_AFTER_SELF_REPAIR_001" `
    -ProgramType "RESUME_AFTER_SELF_REPAIR_PLAN" `
    -Objective "Draft a resume-after-repair plan that keeps owner/Codex assistance as fallback when self-resolution is blocked." `
    -PlannedFiles @("self_build_batch/repair_loop/resume/RESUME_AFTER_SELF_REPAIR_PLAN_DRY_RUN.json") `
    -AllowedScope @("self_build_batch/repair_loop/", "reports/self_development/", "proofs/self_development/") `
    -BlockedScope @("generated_agents/", "applied_agents/", ".github/workflows/", "materials/", "operations/") `
    -MaterialPolicyRequired $false `
    -ProofRequirements @("systemic stop reason preserved", "no automatic continuation before admission", "owner/Codex fallback marked secondary", "resume conditions declared") `
    -ValidationRequirements @("resume trigger declared", "blocked condition declared", "fallback condition declared", "next runtime candidate declared") `
    -ResumeAfterSuccess "Resume controlled multi-cycle self-build only after repair proofs and admission checks pass." `
    -NextRuntimeCandidate "PHASE104_CONTROLLED_MULTI_CYCLE_SELF_BUILD_RUN_V1")
)

$programCount = Get-SafeCount -Value $programs
$selfBuildProgramCount = Get-SafeCount -Value @($programs | Where-Object { "$(Get-PropertyValue -Object $_ -Name "program_type")" -eq "SELF_BUILD_REQUIRED_MODULES_PROGRAM" })
$materialAcquisitionProgramCount = Get-SafeCount -Value @($programs | Where-Object { "$(Get-PropertyValue -Object $_ -Name "program_type")" -eq "MATERIAL_ACQUISITION_UNDER_POLICY_PROGRAM" })
$safePatchProgramCount = Get-SafeCount -Value @($programs | Where-Object { "$(Get-PropertyValue -Object $_ -Name "program_type")" -eq "SAFE_LOCAL_PATCH_PROGRAM" })
$resumePlanCount = Get-SafeCount -Value @($programs | Where-Object { "$(Get-PropertyValue -Object $_ -Name "program_type")" -eq "RESUME_AFTER_SELF_REPAIR_PLAN" })

if ($programCount -lt 4) { throw "PROGRAM_COUNT_LT_4" }
if ($selfBuildProgramCount -lt 1) { throw "SELF_BUILD_PROGRAM_COUNT_LT_1" }
if ($materialAcquisitionProgramCount -lt 1) { throw "MATERIAL_ACQUISITION_PROGRAM_COUNT_LT_1" }
if ($safePatchProgramCount -lt 1) { throw "SAFE_PATCH_PROGRAM_COUNT_LT_1" }
if ($resumePlanCount -lt 1) { throw "RESUME_PLAN_COUNT_LT_1" }

foreach ($program in $programs) {
  if ([bool](Get-PropertyValue -Object $program -Name "execution_allowed_now")) {
    throw "PROGRAM_EXECUTION_ALLOWED_NOW_TRUE"
  }
  if ((Get-SafeCount -Value @(As-Array (Get-PropertyValue -Object $program -Name "proof_requirements"))) -lt 1) {
    throw "PROGRAM_PROOF_REQUIREMENTS_MISSING"
  }
  if ((Get-SafeCount -Value @(As-Array (Get-PropertyValue -Object $program -Name "validation_requirements"))) -lt 1) {
    throw "PROGRAM_VALIDATION_REQUIREMENTS_MISSING"
  }
  if ((Get-SafeCount -Value @(As-Array (Get-PropertyValue -Object $program -Name "allowed_scope"))) -lt 1) {
    throw "PROGRAM_ALLOWED_SCOPE_MISSING"
  }
  if ((Get-SafeCount -Value @(As-Array (Get-PropertyValue -Object $program -Name "blocked_scope"))) -lt 1) {
    throw "PROGRAM_BLOCKED_SCOPE_MISSING"
  }
}

$selectedProgramForNextCycle = "REPAIR_PROGRAM_SELF_BUILD_REQUIRED_MODULES_001"
$generatedAt = Get-UtcStamp
$generatorPolicy = [ordered]@{
  generates_executable_program_drafts = $true
  self_resolution_first = $true
  assistance_is_fallback = $true
  codex_is_not_primary_executor = $true
  owner_is_not_primary_executor = $true
  no_program_execution_in_phase103 = $true
  admission_required_before_execution = $true
  proof_required_after_execution = $true
  no_blind_external_fetch = $true
  no_blind_install = $true
  no_external_agent_production = $true
  no_external_install = $true
  no_external_fetch = $true
}

$schema = [ordered]@{
  '$schema' = "https://json-schema.org/draft/2020-12/schema"
  schema_id = "repair_loop_generator_v1"
  title = "Repair Loop Generator V1"
  type = "object"
  required = @(
    "repair_loop_generator_id",
    "version",
    "status",
    "active_line",
    "input_sources",
    "generator_policy",
    "program_bundle_contract",
    "program_types",
    "execution_allowed",
    "next_allowed_step"
  )
  properties = [ordered]@{
    repair_loop_generator_id = [ordered]@{ type = "string" }
    version = [ordered]@{ const = "V1" }
    status = [ordered]@{ type = "string" }
    active_line = [ordered]@{ const = "AGENT_BUILDER / SELF_BUILD" }
    input_sources = [ordered]@{ type = "array" }
    generator_policy = [ordered]@{ type = "object" }
    program_bundle_contract = [ordered]@{
      type = "object"
      required = @(
        "bundle_id",
        "status",
        "source_next_action_plan",
        "self_resolution_first",
        "assistance_is_fallback",
        "program_generation_performed",
        "execution_performed",
        "programs",
        "program_count",
        "self_build_program_count",
        "material_acquisition_program_count",
        "safe_patch_program_count",
        "resume_plan_count",
        "admission_required_before_execution",
        "selected_program_for_next_cycle",
        "next_allowed_step"
      )
    }
    program_types = [ordered]@{ type = "array"; items = [ordered]@{ enum = $programTypes } }
    execution_allowed = [ordered]@{ const = $false }
    next_allowed_step = [ordered]@{ const = $NextAllowedStep }
  }
  additionalProperties = $true
}

$inputSources = @(
  "self_build_batch/next_actions/BATCH_PLAN_EXAMPLE_V1_NEXT_ACTION_PLAN_DRY_RUN.json",
  "self_build_batch/next_actions/AUTO_NEXT_GAP_DECISION_KERNEL_V1.json",
  "proofs/self_development/AUTO_NEXT_GAP_DECISION_V1.json"
)

$programBundle = [ordered]@{
  bundle_id = "BATCH_PLAN_EXAMPLE_V1_REPAIR_LOOP_PROGRAMS_DRY_RUN"
  version = "V1"
  status = "DRY_RUN_PROGRAM_BUNDLE_READY"
  active_line = "AGENT_BUILDER / SELF_BUILD"
  generated_at = $generatedAt
  source_next_action_plan = $SourceNextActionPlanPath
  self_resolution_first = $true
  assistance_is_fallback = $true
  program_generation_performed = $true
  execution_performed = $false
  execution_allowed = $false
  programs = $programs
  program_count = $programCount
  self_build_program_count = $selfBuildProgramCount
  material_acquisition_program_count = $materialAcquisitionProgramCount
  safe_patch_program_count = $safePatchProgramCount
  resume_plan_count = $resumePlanCount
  admission_required_before_execution = $true
  selected_program_for_next_cycle = $selectedProgramForNextCycle
  next_allowed_step = $NextAllowedStep
}

$repairLoopGenerator = [ordered]@{
  repair_loop_generator_id = "REPAIR_LOOP_GENERATOR_V1"
  version = "V1"
  status = "ACTIVE_REPAIR_LOOP_GENERATOR"
  phase = $Phase
  active_line = "AGENT_BUILDER / SELF_BUILD"
  generated_at = $generatedAt
  input_sources = $inputSources
  output_schema = $SchemaPath
  generator_policy = $generatorPolicy
  program_bundle_contract = $programBundle
  program_types = $programTypes
  execution_allowed = $false
  next_allowed_step = $NextAllowedStep
}

$report = [ordered]@{
  status = "PASS"
  phase = $Phase
  active_line = "AGENT_BUILDER / SELF_BUILD"
  generated_at = $generatedAt
  baseline_commit = $BaselineCommit
  repair_loop_generator_created = $RepairLoopGeneratorPath
  schema_created = $SchemaPath
  dry_run_program_bundle_created = $DryRunProgramBundlePath
  dry_run_program_bundle_status = "DRY_RUN_PROGRAM_BUNDLE_READY"
  self_resolution_first = $true
  assistance_is_fallback = $true
  program_generation_performed = $true
  execution_performed = $false
  execution_allowed = $false
  program_count = $programCount
  self_build_program_count = $selfBuildProgramCount
  material_acquisition_program_count = $materialAcquisitionProgramCount
  safe_patch_program_count = $safePatchProgramCount
  resume_plan_count = $resumePlanCount
  admission_required_before_execution = $true
  selected_program_for_next_cycle = $selectedProgramForNextCycle
  phase104_required_next = $true
  no_external_agent_production = $true
  no_external_install = $true
  no_external_fetch = $true
  phase104_not_executed = $true
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
  repair_loop_generator_created = $true
  schema_created = $true
  dry_run_program_bundle_created = $true
  dry_run_program_bundle_status = "DRY_RUN_PROGRAM_BUNDLE_READY"
  self_resolution_first = $true
  assistance_is_fallback = $true
  codex_is_fallback_not_primary = $true
  owner_is_fallback_not_primary = $true
  program_generation_performed = $true
  execution_performed = $false
  execution_allowed = $false
  program_count = $programCount
  self_build_program_count = $selfBuildProgramCount
  material_acquisition_program_count = $materialAcquisitionProgramCount
  safe_patch_program_count = $safePatchProgramCount
  resume_plan_count = $resumePlanCount
  admission_required_before_execution = $true
  selected_program_for_next_cycle = $selectedProgramForNextCycle
  phase104_required_next = $true
  no_external_agent_production = $true
  no_external_install = $true
  no_external_fetch = $true
  phase104_not_executed = $true
  queue_returned_to_none = $true
  next_allowed_step = $NextAllowedStep
  evidence_files = @(
    $SchemaPath,
    $RepairLoopGeneratorPath,
    $DryRunProgramBundlePath,
    $ReportPath,
    $SourceNextActionPlanPath,
    $SourceDecisionKernelPath,
    $SourceDecisionProofPath
  )
}

Write-JsonFile -Path $SchemaPath -Object $schema
Write-JsonFile -Path $RepairLoopGeneratorPath -Object $repairLoopGenerator
Write-JsonFile -Path $DryRunProgramBundlePath -Object $programBundle
Write-JsonFile -Path $ReportPath -Object $report
Write-JsonFile -Path $ProofPath -Object $proof

Write-Host "REPAIR_LOOP_GENERATOR_SCHEMA_CREATED=$SchemaPath"
Write-Host "REPAIR_LOOP_GENERATOR_CONTRACT_CREATED=$RepairLoopGeneratorPath"
Write-Host "REPAIR_LOOP_PROGRAM_BUNDLE_DRY_RUN_CREATED=$DryRunProgramBundlePath"
Write-Host "DRY_RUN_PROGRAM_BUNDLE_STATUS=DRY_RUN_PROGRAM_BUNDLE_READY"
Write-Host "PROGRAM_GENERATION_PERFORMED=TRUE"
Write-Host "EXECUTION_PERFORMED=FALSE"
Write-Host "EXECUTION_ALLOWED=FALSE"
Write-Host "NO_EXTERNAL_AGENT_PRODUCTION=TRUE"
Write-Host "REPAIR_LOOP_GENERATOR_REPORT_WRITTEN=$ReportPath"
Write-Host "REPAIR_LOOP_GENERATOR_PROOF_WRITTEN=$ProofPath"
Write-Host "REPAIR_LOOP_GENERATOR_V1_COMPLETE"

return [pscustomobject]$report
