param(
  [string]$AbsorptionDecisionPath = "self_build_programs/absorption/SELF_BUILD_PROGRAM_OWNER_MATERIAL_INPUT_BOOTSTRAP_001_V1_001_ABSORPTION_DECISION.json",
  [string]$KProofPath = "proofs/self_development/PHASE165K_ADD_SELF_BUILD_ABSORPTION_DECISION_GATE_V1.json",
  [string]$RegressionProofPath = "proofs/self_development/PHASE165I_SELF_BUILD_LOOP_REGRESSION_HARNESS_V1.json",
  [string]$IntegrationProofPath = "proofs/self_development/PHASE165J_CANONICAL_DYNAMIC_LOOP_TRIAL_OR_INTEGRATION_PROOF_V1.json",
  [string]$FailedQuarantineProofPath = "proofs/self_development/PHASE165J_ADD_FAILED_SELF_BUILD_QUARANTINE_PATH_V1.json",
  [string]$LineagePath = "self_build_programs/lineage/SELF_BUILD_CAUSE_LINEAGE_EXAMPLE_V1.json",
  [string]$OutputPath = "self_build_programs/memory/SELF_BUILD_PROGRAM_OWNER_MATERIAL_INPUT_BOOTSTRAP_001_V1_001_MEMORY_ABSORPTION.json"
)

$ErrorActionPreference = "Stop"

function Read-JsonRequired([string]$Path) {
  if (-not (Test-Path $Path)) { throw "Missing required file: $Path" }
  return Get-Content $Path -Raw | ConvertFrom-Json
}

$Decision = Read-JsonRequired $AbsorptionDecisionPath
$KProof = Read-JsonRequired $KProofPath
$Regression = Read-JsonRequired $RegressionProofPath
$Integration = Read-JsonRequired $IntegrationProofPath
$FailedQuarantine = Read-JsonRequired $FailedQuarantineProofPath
$Lineage = Read-JsonRequired $LineagePath

$Errors = @()
function Add-Error([string]$Code) { $script:Errors += $Code }

$ProgramId = [string]$Decision.program_id
$LineageId = [string]$Decision.lineage_id

if ([string]::IsNullOrWhiteSpace($ProgramId)) { Add-Error "PROGRAM_ID_EMPTY" }
if ([string]::IsNullOrWhiteSpace($LineageId)) { Add-Error "LINEAGE_ID_EMPTY" }

if ([string]$Decision.absorption_decision -ne "KEEP") { Add-Error "ABSORPTION_DECISION_NOT_KEEP" }
if ([bool]$Decision.action.memory_update_required -ne $true) { Add-Error "MEMORY_UPDATE_NOT_REQUIRED" }
if ([bool]$Decision.action.promote_now -ne $false) { Add-Error "PROMOTE_NOW_NOT_FALSE" }

if ([bool]$KProof.validation_passed -ne $true) { Add-Error "PHASE165K_PROOF_NOT_PASSING" }
if ([string]$KProof.absorption_decision -ne "KEEP") { Add-Error "PHASE165K_NOT_KEEP" }
if ([bool]$Regression.validation_passed -ne $true) { Add-Error "REGRESSION_NOT_PASSING" }
if ([bool]$Integration.validation_passed -ne $true) { Add-Error "INTEGRATION_NOT_PASSING" }
if ([bool]$FailedQuarantine.validation_passed -ne $true) { Add-Error "FAILED_QUARANTINE_NOT_PASSING" }

if ([string]$Regression.program_id -ne $ProgramId) { Add-Error "REGRESSION_PROGRAM_MISMATCH" }
if ([string]$Integration.program_id -ne $ProgramId) { Add-Error "INTEGRATION_PROGRAM_MISMATCH" }
if ([string]$Lineage.program.program_id -ne $ProgramId) { Add-Error "LINEAGE_PROGRAM_MISMATCH" }

if ([bool]$Regression.execution_performed -ne $true) { Add-Error "REGRESSION_EXECUTION_NOT_TRUE" }
if ([bool]$Regression.completed_loop -ne $true) { Add-Error "REGRESSION_LOOP_NOT_COMPLETED" }
if ([bool]$Regression.lineage_preserved -ne $true) { Add-Error "REGRESSION_LINEAGE_NOT_PRESERVED" }

$Status = if ($Errors.Count -eq 0) { "PASS" } else { "FAIL" }

$MemoryRecord = [pscustomobject]@{
  schema_version = "builder_memory_absorption_record_v1"
  phase = "PHASE165L_CONNECT_ABSORPTION_TO_BUILDER_MEMORY"
  created_utc = (Get-Date).ToUniversalTime().ToString("o")
  status = $Status
  memory_record_id = "${ProgramId}_MEMORY_ABSORPTION"
  program_id = $ProgramId
  lineage_id = $LineageId

  memory_event = [pscustomobject]@{
    event_type = "SELF_BUILD_LOOP_EXPERIENCE_ABSORBED_AS_RECORD"
    absorption_decision = "KEEP"
    memory_update_required = $true
    promote_now = $false
    learning_summary = "Dynamic owner-material self-build loop completed PHASE87->PHASE88->PHASE89->PHASE90, passed regression/integration checks, passed failed-program quarantine path, and was kept for memory absorption."
  }

  proof_chain = [pscustomobject]@{
    absorption_decision = $AbsorptionDecisionPath
    phase165k_proof = $KProofPath
    regression_proof = $RegressionProofPath
    integration_proof = $IntegrationProofPath
    failed_quarantine_proof = $FailedQuarantineProofPath
    lineage = $LineagePath
  }

  facts_absorbed = [pscustomobject]@{
    dynamic_decision_present = $true
    dynamic_program_generated = $true
    dynamic_admission_performed = $true
    dynamic_execution_performed = $true
    completed_loop = [bool]$Regression.completed_loop
    lineage_preserved = [bool]$Regression.lineage_preserved
    failed_programs_quarantined_with_reason = [bool]$FailedQuarantine.validation_passed
    absorption_keep_decision = $true
  }

  boundary = [pscustomobject]@{
    protected_self_model_mutated = $false
    genesis_state_mutated = $false
    capability_roadmap_mutated = $false
    route_lock_mutated = $false
    task_queue_mutated = $false
    program_executed_again = $false
    promote_performed = $false
    external_agent_production = $false
    external_fetch_or_install = $false
    codex_used = $false
  }

  errors = @($Errors)
  next_required_step = "PHASE165M_PROMOTION_OR_CANONICAL_TASK_DESCRIPTOR_DYNAMIC_CONTRACT_SCOPE"
}

$MemoryRecord | ConvertTo-Json -Depth 80 | Set-Content -Encoding UTF8 -Path $OutputPath

if ($Status -ne "PASS") {
  throw "PHASE165L_MEMORY_ABSORPTION_RECORD_FAILED: $($Errors -join ',')"
}

$MemoryRecord | ConvertTo-Json -Depth 80
