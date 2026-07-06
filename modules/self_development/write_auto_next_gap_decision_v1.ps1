[CmdletBinding()]
param(
  [string]$SourceBatchSummaryPath = "self_build_batch/proof_aggregation/BATCH_PLAN_EXAMPLE_V1_PROOF_SUMMARY_DRY_RUN.json",
  [string]$SourceAggregatorProofPath = "proofs/self_development/BATCH_PROOF_AGGREGATOR_V1.json",
  [string]$SourceQuarantineRegistryPath = "self_build_batch/quarantine/BATCH_PLAN_EXAMPLE_V1_QUARANTINE_BLOCKER_DRY_RUN.json",
  [string]$RouteLockPath = "AGENT_BUILDER_NEXT_15_STEPS_LOCK_V2_R2.md",
  [string]$SchemaPath = "contracts/self_development/auto_next_gap_decision_v1.schema.json",
  [string]$DecisionKernelPath = "self_build_batch/next_actions/AUTO_NEXT_GAP_DECISION_KERNEL_V1.json",
  [string]$DryRunActionPlanPath = "self_build_batch/next_actions/BATCH_PLAN_EXAMPLE_V1_NEXT_ACTION_PLAN_DRY_RUN.json",
  [string]$ReportPath = "reports/self_development/AUTO_NEXT_GAP_DECISION_V1_REPORT.json",
  [string]$ProofPath = "proofs/self_development/AUTO_NEXT_GAP_DECISION_V1.json",
  [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
)

$ErrorActionPreference = "Stop"

$Phase = "PHASE102_AUTO_NEXT_GAP_DECISION_V1"
$TaskId = "TASK_AUTO_NEXT_GAP_DECISION_V1_001"
$RouteLockVersion = "V2_R2"
$BaselineCommit = "cc0856e"
$NextAllowedStep = "PHASE103_REPAIR_LOOP_GENERATOR_V1"

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

function Select-FirstRecordByStatus {
  param(
    [object[]]$Records,
    [string[]]$Statuses
  )

  foreach ($status in $Statuses) {
    $record = $Records | Where-Object { "$(Get-PropertyValue -Object $_ -Name "status")" -eq $status } | Select-Object -First 1
    if ($null -ne $record) {
      return $record
    }
  }
  return $null
}

function New-Decision {
  param(
    [object]$Record,
    [string]$DecisionId,
    [string]$MissingCapability,
    [string[]]$RequiredModules,
    [string]$Decision,
    [string]$SelfResolutionPath,
    [string]$RequiredProgramType,
    [bool]$CanSelfResolveNow,
    [bool]$AdmissionRequired,
    [bool]$MaterialPolicyRequired,
    [bool]$FallbackAllowedOnlyIfSelfBlocked,
    [string]$FallbackReason,
    [string[]]$ProofRequirements,
    [string]$NextExecutableStep,
    [string]$NextActionOwner
  )

  return [pscustomobject][ordered]@{
    decision_id = $DecisionId
    source_record_id = "$(Get-PropertyValue -Object $Record -Name "record_id")"
    item_id = "$(Get-PropertyValue -Object $Record -Name "item_id")"
    source_status = "$(Get-PropertyValue -Object $Record -Name "status")"
    source_reason = "$(Get-PropertyValue -Object $Record -Name "reason")"
    gap = "$(Get-PropertyValue -Object $Record -Name "source_gap")"
    missing_capability = $MissingCapability
    required_modules = $RequiredModules
    decision = $Decision
    self_resolution_path = $SelfResolutionPath
    required_program_type = $RequiredProgramType
    can_self_resolve_now = $CanSelfResolveNow
    execution_allowed_now = $false
    admission_required = $AdmissionRequired
    material_policy_required = $MaterialPolicyRequired
    fallback_allowed_only_if_self_blocked = $FallbackAllowedOnlyIfSelfBlocked
    fallback_reason = $FallbackReason
    proof_requirements = $ProofRequirements
    next_executable_step = $NextExecutableStep
    next_action_owner = $NextActionOwner
  }
}

Write-Host "AUTO_NEXT_GAP_DECISION_V1_START"

$batchSummary = Read-JsonRequired $SourceBatchSummaryPath
$aggregatorProof = Read-JsonRequired $SourceAggregatorProofPath
$quarantineRegistry = Read-JsonRequired $SourceQuarantineRegistryPath

if (-not (Test-Path -LiteralPath (Join-RepoPath $RouteLockPath))) {
  throw "MISSING_ROUTE_LOCK=$RouteLockPath"
}
if ("$(Get-PropertyValue -Object $aggregatorProof -Name "status")" -ne "PASS") {
  throw "PHASE101_PROOF_STATUS_NOT_PASS"
}
if ("$(Get-PropertyValue -Object $aggregatorProof -Name "next_allowed_step")" -ne "PHASE102_AUTO_NEXT_GAP_DECISION_V1") {
  throw "PHASE101_PROOF_NEXT_STEP_MISMATCH"
}
if ("$(Get-PropertyValue -Object $batchSummary -Name "status")" -ne "DRY_RUN_AGGREGATED") {
  throw "SOURCE_BATCH_SUMMARY_STATUS_NOT_AGGREGATED"
}
foreach ($falseField in @("execution_performed", "real_items_executed", "real_items_marked_pass")) {
  if ([bool](Get-PropertyValue -Object $batchSummary -Name $falseField)) {
    throw "SOURCE_BATCH_SUMMARY_$($falseField.ToUpperInvariant())_TRUE"
  }
}
if (-not [bool](Get-PropertyValue -Object $batchSummary -Name "no_fake_pass")) {
  throw "SOURCE_BATCH_SUMMARY_NO_FAKE_PASS_NOT_TRUE"
}
if (-not [bool](Get-PropertyValue -Object $batchSummary -Name "no_hidden_failures")) {
  throw "SOURCE_BATCH_SUMMARY_NO_HIDDEN_FAILURES_NOT_TRUE"
}
if ([int](Get-PropertyValue -Object $batchSummary -Name "unresolved_record_count") -lt 4) {
  throw "SOURCE_BATCH_SUMMARY_UNRESOLVED_RECORD_COUNT_LT_4"
}
if ("$(Get-PropertyValue -Object $quarantineRegistry -Name "status")" -ne "DRY_RUN_INITIALIZED") {
  throw "SOURCE_QUARANTINE_REGISTRY_STATUS_NOT_INITIALIZED"
}
if ([int](Get-PropertyValue -Object $quarantineRegistry -Name "record_count") -lt 4) {
  throw "SOURCE_QUARANTINE_REGISTRY_RECORD_COUNT_LT_4"
}

$records = @(As-Array (Get-PropertyValue -Object $quarantineRegistry -Name "records"))
$failedRecord = Select-FirstRecordByStatus -Records $records -Statuses @("FAILED")
$quarantinedRecord = Select-FirstRecordByStatus -Records $records -Statuses @("QUARANTINED")
$blockedRecord = Select-FirstRecordByStatus -Records $records -Statuses @("BLOCKED")
$fallbackRecord = Select-FirstRecordByStatus -Records $records -Statuses @("NEEDS_OWNER_DECISION", "NEEDS_CODEX_REPAIR", "NEEDS_MATERIAL")

if ($null -eq $failedRecord) { throw "FAILED_RECORD_MISSING" }
if ($null -eq $quarantinedRecord) { throw "QUARANTINED_RECORD_MISSING" }
if ($null -eq $blockedRecord) { throw "BLOCKED_RECORD_MISSING" }
if ($null -eq $fallbackRecord) { throw "FALLBACK_RECORD_MISSING" }

$decisionPriority = @(
  "SELF_EXECUTE_WITH_EXISTING_CAPABILITY",
  "SELF_BUILD_REQUIRED_MODULES",
  "SELF_ACQUIRE_MATERIAL_UNDER_POLICY",
  "SELF_PATCH_SAFE_LOCAL_SCOPE",
  "CONTINUE_AFTER_SELF_REPAIR",
  "CODEX_REPAIR_REQUIRED_FALLBACK",
  "OWNER_DECISION_REQUIRED_FALLBACK",
  "BLOCKED_BY_POLICY",
  "QUARANTINED_FOR_LATER"
)

$decisions = @(
  (New-Decision `
    -Record $blockedRecord `
    -DecisionId "DECISION_SELF_BUILD_REQUIRED_MODULES_001" `
    -MissingCapability "repair_loop_generator_v1" `
    -RequiredModules @("modules/self_development/write_repair_loop_generator_v1.ps1", "packs/PHASE103_REPAIR_LOOP_GENERATOR_V1/APPLY.ps1", "packs/PHASE103_REPAIR_LOOP_GENERATOR_V1/VALIDATE.ps1") `
    -Decision "SELF_BUILD_REQUIRED_MODULES" `
    -SelfResolutionPath "Generate a PHASE103 repair-loop program that turns unresolved batch records into bounded repair candidates." `
    -RequiredProgramType "SELF_BUILD_REPAIR_LOOP_PROGRAM" `
    -CanSelfResolveNow $true `
    -AdmissionRequired $true `
    -MaterialPolicyRequired $false `
    -FallbackAllowedOnlyIfSelfBlocked $true `
    -FallbackReason "Codex fallback is permitted only if Builder cannot synthesize the repair-loop seed or validator." `
    -ProofRequirements @("PHASE103 seed validator must pass", "No runtime execution before admission", "No hidden unresolved records") `
    -NextExecutableStep "PHASE103_REPAIR_LOOP_GENERATOR_V1::SELF_BUILD_REQUIRED_MODULES" `
    -NextActionOwner "No owner action required unless PHASE103 policy or validation blocks self-build generation."),
  (New-Decision `
    -Record $quarantinedRecord `
    -DecisionId "DECISION_SELF_ACQUIRE_MATERIAL_UNDER_POLICY_001" `
    -MissingCapability "material_request_packet_for_quarantined_batch_items_v1" `
    -RequiredModules @("modules/self_development/write_material_request_candidate_v1.ps1", "contracts/operations/self_build_delivery_conveyor_v1.json") `
    -Decision "SELF_ACQUIRE_MATERIAL_UNDER_POLICY" `
    -SelfResolutionPath "Prepare a policy-gated material request candidate for quarantined items without fetching or installing anything." `
    -RequiredProgramType "MATERIAL_ACQUISITION_CANDIDATE_PROGRAM" `
    -CanSelfResolveNow $true `
    -AdmissionRequired $true `
    -MaterialPolicyRequired $true `
    -FallbackAllowedOnlyIfSelfBlocked $true `
    -FallbackReason "Owner fallback is permitted only if material policy requires explicit approval." `
    -ProofRequirements @("Material policy gate must approve request shape", "No external fetch", "No install") `
    -NextExecutableStep "PHASE103_REPAIR_LOOP_GENERATOR_V1::SELF_ACQUIRE_MATERIAL_UNDER_POLICY" `
    -NextActionOwner "Review only if the future material policy gate blocks automatic material request preparation."),
  (New-Decision `
    -Record $failedRecord `
    -DecisionId "DECISION_SELF_PATCH_SAFE_LOCAL_SCOPE_001" `
    -MissingCapability "safe_local_patch_plan_for_failed_batch_items_v1" `
    -RequiredModules @("modules/self_development/write_safe_local_repair_patch_plan_v1.ps1", "packs/PHASE103_REPAIR_LOOP_GENERATOR_V1/VALIDATE.ps1") `
    -Decision "SELF_PATCH_SAFE_LOCAL_SCOPE" `
    -SelfResolutionPath "Create a safe local patch plan for isolated failed items, preserving admission and proof requirements." `
    -RequiredProgramType "SAFE_LOCAL_PATCH_CANDIDATE_PROGRAM" `
    -CanSelfResolveNow $true `
    -AdmissionRequired $true `
    -MaterialPolicyRequired $false `
    -FallbackAllowedOnlyIfSelfBlocked $true `
    -FallbackReason "Codex repair fallback is permitted only after the safe local patch plan fails validation." `
    -ProofRequirements @("Patch scope must be declared", "Validation must pass before runtime", "No PASS without proof") `
    -NextExecutableStep "PHASE103_REPAIR_LOOP_GENERATOR_V1::SELF_PATCH_SAFE_LOCAL_SCOPE" `
    -NextActionOwner "No owner action required unless safe local scope cannot be proven."),
  (New-Decision `
    -Record $fallbackRecord `
    -DecisionId "DECISION_OWNER_DECISION_FALLBACK_001" `
    -MissingCapability "systemic_failure_owner_decision_packet_v1" `
    -RequiredModules @("modules/self_development/write_owner_decision_packet_v1.ps1") `
    -Decision "OWNER_DECISION_REQUIRED_FALLBACK" `
    -SelfResolutionPath "Self-resolution is blocked by a systemic stop condition; prepare an owner decision packet rather than treating owner as the primary executor." `
    -RequiredProgramType "OWNER_DECISION_PACKET" `
    -CanSelfResolveNow $false `
    -AdmissionRequired $false `
    -MaterialPolicyRequired $false `
    -FallbackAllowedOnlyIfSelfBlocked $true `
    -FallbackReason "Systemic failure policy requires owner decision before retry or continuation." `
    -ProofRequirements @("Systemic stop reason must be preserved", "No automatic continuation", "No hidden failure") `
    -NextExecutableStep "PHASE103_REPAIR_LOOP_GENERATOR_V1::OWNER_DECISION_FALLBACK_PACKET" `
    -NextActionOwner "Review systemic stop condition only if PHASE103 cannot produce a bounded repair candidate.")
)

$decisionCount = Get-SafeCount -Value $decisions
$selfResolvableCount = Get-SafeCount -Value @($decisions | Where-Object { [bool](Get-PropertyValue -Object $_ -Name "can_self_resolve_now") })
$materialAcquisitionCandidateCount = Get-SafeCount -Value @($decisions | Where-Object { "$(Get-PropertyValue -Object $_ -Name "decision")" -eq "SELF_ACQUIRE_MATERIAL_UNDER_POLICY" })
$safePatchCandidateCount = Get-SafeCount -Value @($decisions | Where-Object { "$(Get-PropertyValue -Object $_ -Name "decision")" -eq "SELF_PATCH_SAFE_LOCAL_SCOPE" })
$fallbackCount = Get-SafeCount -Value @($decisions | Where-Object { "$(Get-PropertyValue -Object $_ -Name "decision")" -in @("CODEX_REPAIR_REQUIRED_FALLBACK", "OWNER_DECISION_REQUIRED_FALLBACK") })
$blockedCount = Get-SafeCount -Value @($decisions | Where-Object { "$(Get-PropertyValue -Object $_ -Name "decision")" -eq "BLOCKED_BY_POLICY" })

if ($decisionCount -lt 4) { throw "DECISION_COUNT_LT_4" }
if ($selfResolvableCount -lt 2) { throw "SELF_RESOLVABLE_COUNT_LT_2" }
if ($materialAcquisitionCandidateCount -lt 1) { throw "MATERIAL_ACQUISITION_CANDIDATE_COUNT_LT_1" }
if ($safePatchCandidateCount -lt 1) { throw "SAFE_PATCH_CANDIDATE_COUNT_LT_1" }
if ($fallbackCount -lt 1) { throw "FALLBACK_COUNT_LT_1" }

foreach ($fallbackDecision in @($decisions | Where-Object { "$(Get-PropertyValue -Object $_ -Name "decision")" -in @("CODEX_REPAIR_REQUIRED_FALLBACK", "OWNER_DECISION_REQUIRED_FALLBACK") })) {
  if ([bool](Get-PropertyValue -Object $fallbackDecision -Name "can_self_resolve_now")) {
    throw "FALLBACK_DECISION_SELF_RESOLVABLE_TRUE"
  }
  if (-not [bool](Get-PropertyValue -Object $fallbackDecision -Name "fallback_allowed_only_if_self_blocked")) {
    throw "FALLBACK_DECISION_NOT_MARKED_SELF_BLOCKED"
  }
}

$selectedNextExecutableStep = "PHASE103_REPAIR_LOOP_GENERATOR_V1::SELF_BUILD_REQUIRED_MODULES"
$generatedAt = Get-UtcStamp
$decisionPolicy = [ordered]@{
  self_resolution_first = $true
  assistance_is_fallback = $true
  codex_is_not_primary_executor = $true
  owner_is_not_primary_executor = $true
  prefer_self_build_program = $true
  prefer_material_acquisition_under_policy_when_material_missing = $true
  prefer_safe_local_patch_when_scope_is_proven_and_small = $true
  no_blind_external_fetch = $true
  no_blind_install = $true
  admission_required_before_execution = $true
  proof_required_after_execution = $true
  no_fake_pass = $true
  no_hidden_failures = $true
  no_external_agent_production = $true
  no_external_install = $true
  no_external_fetch = $true
}

$schema = [ordered]@{
  '$schema' = "https://json-schema.org/draft/2020-12/schema"
  schema_id = "auto_next_gap_decision_v1"
  title = "Auto Next Gap Decision V1"
  type = "object"
  required = @(
    "decision_kernel_id",
    "version",
    "status",
    "active_line",
    "input_sources",
    "decision_priority",
    "decision_policy",
    "action_plan_contract",
    "self_resolution_first",
    "assistance_is_fallback",
    "execution_allowed",
    "next_allowed_step"
  )
  properties = [ordered]@{
    decision_kernel_id = [ordered]@{ type = "string" }
    version = [ordered]@{ const = "V1" }
    status = [ordered]@{ type = "string" }
    active_line = [ordered]@{ const = "AGENT_BUILDER / SELF_BUILD" }
    input_sources = [ordered]@{ type = "array" }
    decision_priority = [ordered]@{ type = "array"; items = [ordered]@{ enum = $decisionPriority } }
    decision_policy = [ordered]@{ type = "object" }
    action_plan_contract = [ordered]@{
      type = "object"
      required = @(
        "plan_id",
        "status",
        "source_batch_summary",
        "source_quarantine_registry",
        "self_resolution_first",
        "assistance_is_fallback",
        "decisions",
        "decision_count",
        "self_resolvable_count",
        "material_acquisition_candidate_count",
        "safe_patch_candidate_count",
        "fallback_count",
        "blocked_count",
        "selected_next_executable_step",
        "execution_allowed",
        "program_generation_required_next",
        "next_allowed_step"
      )
    }
    self_resolution_first = [ordered]@{ const = $true }
    assistance_is_fallback = [ordered]@{ const = $true }
    execution_allowed = [ordered]@{ const = $false }
    next_allowed_step = [ordered]@{ const = $NextAllowedStep }
  }
  additionalProperties = $true
}

$inputSources = @(
  "self_build_batch/proof_aggregation/BATCH_PLAN_EXAMPLE_V1_PROOF_SUMMARY_DRY_RUN.json",
  "self_build_batch/quarantine/BATCH_PLAN_EXAMPLE_V1_QUARANTINE_BLOCKER_DRY_RUN.json",
  "proofs/self_development/BATCH_PROOF_AGGREGATOR_V1.json"
)

$actionPlan = [ordered]@{
  plan_id = "BATCH_PLAN_EXAMPLE_V1_NEXT_ACTION_PLAN_DRY_RUN"
  version = "V1"
  status = "DRY_RUN_NEXT_ACTIONS_READY"
  active_line = "AGENT_BUILDER / SELF_BUILD"
  generated_at = $generatedAt
  source_batch_summary = $SourceBatchSummaryPath
  source_quarantine_registry = $SourceQuarantineRegistryPath
  self_resolution_first = $true
  assistance_is_fallback = $true
  decision_priority = $decisionPriority
  decisions = $decisions
  decision_count = $decisionCount
  self_resolvable_count = $selfResolvableCount
  material_acquisition_candidate_count = $materialAcquisitionCandidateCount
  safe_patch_candidate_count = $safePatchCandidateCount
  fallback_count = $fallbackCount
  blocked_count = $blockedCount
  selected_next_executable_step = $selectedNextExecutableStep
  execution_allowed = $false
  program_generation_required_next = $true
  next_allowed_step = $NextAllowedStep
}

$decisionKernel = [ordered]@{
  decision_kernel_id = "AUTO_NEXT_GAP_DECISION_KERNEL_V1"
  version = "V1"
  status = "ACTIVE_DECISION_KERNEL"
  phase = $Phase
  active_line = "AGENT_BUILDER / SELF_BUILD"
  generated_at = $generatedAt
  input_sources = $inputSources
  output_schema = $SchemaPath
  decision_priority = $decisionPriority
  decision_policy = $decisionPolicy
  action_plan_contract = $actionPlan
  self_resolution_first = $true
  assistance_is_fallback = $true
  execution_allowed = $false
  next_allowed_step = $NextAllowedStep
}

$report = [ordered]@{
  status = "PASS"
  phase = $Phase
  active_line = "AGENT_BUILDER / SELF_BUILD"
  generated_at = $generatedAt
  baseline_commit = $BaselineCommit
  decision_kernel_created = $DecisionKernelPath
  schema_created = $SchemaPath
  dry_run_action_plan_created = $DryRunActionPlanPath
  dry_run_action_plan_status = "DRY_RUN_NEXT_ACTIONS_READY"
  self_resolution_first = $true
  assistance_is_fallback = $true
  decision_count = $decisionCount
  self_resolvable_count = $selfResolvableCount
  material_acquisition_candidate_count = $materialAcquisitionCandidateCount
  safe_patch_candidate_count = $safePatchCandidateCount
  fallback_count = $fallbackCount
  selected_next_executable_step = $selectedNextExecutableStep
  execution_allowed = $false
  program_generation_required_next = $true
  phase103_required_next = $true
  no_external_agent_production = $true
  no_external_install = $true
  no_external_fetch = $true
  phase103_not_executed = $true
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
  decision_kernel_created = $true
  schema_created = $true
  dry_run_action_plan_created = $true
  dry_run_action_plan_status = "DRY_RUN_NEXT_ACTIONS_READY"
  self_resolution_first = $true
  assistance_is_fallback = $true
  codex_is_fallback_not_primary = $true
  owner_is_fallback_not_primary = $true
  decision_count = $decisionCount
  self_resolvable_count = $selfResolvableCount
  material_acquisition_candidate_count = $materialAcquisitionCandidateCount
  safe_patch_candidate_count = $safePatchCandidateCount
  fallback_count = $fallbackCount
  selected_next_executable_step = $selectedNextExecutableStep
  execution_allowed = $false
  program_generation_required_next = $true
  phase103_required_next = $true
  no_external_agent_production = $true
  no_external_install = $true
  no_external_fetch = $true
  phase103_not_executed = $true
  queue_returned_to_none = $true
  next_allowed_step = $NextAllowedStep
  evidence_files = @(
    $SchemaPath,
    $DecisionKernelPath,
    $DryRunActionPlanPath,
    $ReportPath,
    $SourceBatchSummaryPath,
    $SourceAggregatorProofPath,
    $SourceQuarantineRegistryPath
  )
}

Write-JsonFile -Path $SchemaPath -Object $schema
Write-JsonFile -Path $DecisionKernelPath -Object $decisionKernel
Write-JsonFile -Path $DryRunActionPlanPath -Object $actionPlan
Write-JsonFile -Path $ReportPath -Object $report
Write-JsonFile -Path $ProofPath -Object $proof

Write-Host "AUTO_NEXT_GAP_DECISION_SCHEMA_CREATED=$SchemaPath"
Write-Host "AUTO_NEXT_GAP_DECISION_KERNEL_CREATED=$DecisionKernelPath"
Write-Host "AUTO_NEXT_GAP_ACTION_PLAN_DRY_RUN_CREATED=$DryRunActionPlanPath"
Write-Host "DRY_RUN_ACTION_PLAN_STATUS=DRY_RUN_NEXT_ACTIONS_READY"
Write-Host "SELF_RESOLUTION_FIRST=TRUE"
Write-Host "ASSISTANCE_IS_FALLBACK=TRUE"
Write-Host "EXECUTION_ALLOWED=FALSE"
Write-Host "PROGRAM_GENERATION_REQUIRED_NEXT=TRUE"
Write-Host "NO_EXTERNAL_AGENT_PRODUCTION=TRUE"
Write-Host "AUTO_NEXT_GAP_DECISION_REPORT_WRITTEN=$ReportPath"
Write-Host "AUTO_NEXT_GAP_DECISION_PROOF_WRITTEN=$ProofPath"
Write-Host "AUTO_NEXT_GAP_DECISION_V1_COMPLETE"

return [pscustomobject]$report
