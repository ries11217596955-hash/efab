param(
  [string]$ExecutionPath = "self_build_programs/executions/SELF_BUILD_PROGRAM_OWNER_MATERIAL_INPUT_BOOTSTRAP_001_V1_001_EXECUTION.json",
  [string]$RegressionProofPath = "proofs/self_development/PHASE165I_SELF_BUILD_LOOP_REGRESSION_HARNESS_V1.json",
  [string]$IntegrationProofPath = "proofs/self_development/PHASE165J_CANONICAL_DYNAMIC_LOOP_TRIAL_OR_INTEGRATION_PROOF_V1.json",
  [string]$FailedQuarantineProofPath = "proofs/self_development/PHASE165J_ADD_FAILED_SELF_BUILD_QUARANTINE_PATH_V1.json",
  [string]$LineagePath = "self_build_programs/lineage/SELF_BUILD_CAUSE_LINEAGE_EXAMPLE_V1.json",
  [string]$ContractPath = "self_build_programs/contracts/SELF_BUILD_CAUSE_LINEAGE_CONTRACT_V1.json",
  [string]$OutputPath = "self_build_programs/absorption/SELF_BUILD_PROGRAM_OWNER_MATERIAL_INPUT_BOOTSTRAP_001_V1_001_ABSORPTION_DECISION.json"
)

$ErrorActionPreference = "Stop"

function Read-JsonRequired([string]$Path) {
  if (-not (Test-Path $Path)) { throw "Missing required file: $Path" }
  return Get-Content $Path -Raw | ConvertFrom-Json
}

$Execution = Read-JsonRequired $ExecutionPath
$Regression = Read-JsonRequired $RegressionProofPath
$Integration = Read-JsonRequired $IntegrationProofPath
$FailedQuarantine = Read-JsonRequired $FailedQuarantineProofPath
$Lineage = Read-JsonRequired $LineagePath
$Contract = Read-JsonRequired $ContractPath

$Errors = @()
function Add-Error([string]$Code) { $script:Errors += $Code }

$ProgramId = [string]$Execution.program_id
$LineageId = [string]$Execution.source.lineage_id

if ([string]::IsNullOrWhiteSpace($ProgramId)) { Add-Error "PROGRAM_ID_EMPTY" }
if ([string]::IsNullOrWhiteSpace($LineageId)) { Add-Error "LINEAGE_ID_EMPTY" }

if ([string]$Regression.program_id -ne $ProgramId) { Add-Error "REGRESSION_PROGRAM_ID_MISMATCH" }
if ([string]$Integration.program_id -ne $ProgramId) { Add-Error "INTEGRATION_PROGRAM_ID_MISMATCH" }
if ([string]$Lineage.program.program_id -ne $ProgramId) { Add-Error "LINEAGE_PROGRAM_ID_MISMATCH" }

if ([bool]$Regression.validation_passed -ne $true) { Add-Error "REGRESSION_NOT_PASSING" }
if ([bool]$Integration.validation_passed -ne $true) { Add-Error "INTEGRATION_NOT_PASSING" }
if ([bool]$FailedQuarantine.validation_passed -ne $true) { Add-Error "FAILED_QUARANTINE_PATH_NOT_PASSING" }

if ([bool]$Execution.execution_performed -ne $true) { Add-Error "EXECUTION_NOT_PERFORMED" }
if ([bool]$Execution.completed_loop -ne $true) { Add-Error "LOOP_NOT_COMPLETED" }
if ([bool]$Execution.controlled_runtime -ne $true) { Add-Error "CONTROLLED_RUNTIME_NOT_TRUE" }
if ([bool]$Execution.queue_returned_to_none -ne $true) { Add-Error "QUEUE_NOT_RETURNED_TO_NONE" }
if ([bool]$Execution.lineage.execution_lineage_preserved -ne $true) { Add-Error "EXECUTION_LINEAGE_NOT_PRESERVED" }

if ([string]$FailedQuarantine.quarantine_decision -ne "QUARANTINE") { Add-Error "FAILED_PATH_NOT_QUARANTINE" }
if ([bool]$FailedQuarantine.failed_program_accepted -ne $false) { Add-Error "FAILED_PROGRAM_ACCEPTED" }
if ([bool]$FailedQuarantine.failed_program_promoted -ne $false) { Add-Error "FAILED_PROGRAM_PROMOTED" }
if ([bool]$FailedQuarantine.failed_program_silently_retried -ne $false) { Add-Error "FAILED_PROGRAM_SILENTLY_RETRIED" }

$Allowed = @($Contract.allowed_absorption_decisions)
foreach ($Decision in @("KEEP","ROLLBACK","QUARANTINE","PROMOTE","UPDATE_MEMORY","OWNER_REVIEW_REQUIRED")) {
  if ($Allowed -notcontains $Decision) { Add-Error "MISSING_ALLOWED_DECISION_$Decision" }
}

$SuccessEvidenceReady = ($Errors.Count -eq 0)

$AbsorptionDecision = if ($SuccessEvidenceReady) { "KEEP" } else { "OWNER_REVIEW_REQUIRED" }
$PromoteNow = $false
$RollbackRequired = $false
$QuarantineRequired = -not $SuccessEvidenceReady
$MemoryUpdateRequired = $SuccessEvidenceReady

$Absorption = [pscustomobject]@{
  schema_version = "self_build_absorption_decision_gate_v1"
  phase = "PHASE165K_ADD_SELF_BUILD_ABSORPTION_DECISION_GATE"
  created_utc = (Get-Date).ToUniversalTime().ToString("o")
  absorption_id = "${ProgramId}_ABSORPTION"
  program_id = $ProgramId
  lineage_id = $LineageId
  status = if ($SuccessEvidenceReady) { "PASS" } else { "OWNER_REVIEW_REQUIRED" }
  absorption_decision = $AbsorptionDecision
  allowed_decisions = $Allowed

  decision_basis = [pscustomobject]@{
    regression_passed = [bool]$Regression.validation_passed
    integration_passed = [bool]$Integration.validation_passed
    execution_performed = [bool]$Execution.execution_performed
    completed_loop = [bool]$Execution.completed_loop
    controlled_runtime = [bool]$Execution.controlled_runtime
    queue_returned_to_none = [bool]$Execution.queue_returned_to_none
    lineage_preserved = [bool]$Execution.lineage.execution_lineage_preserved
    failed_quarantine_path_passed = [bool]$FailedQuarantine.validation_passed
    failed_programs_not_silently_accepted = [bool](
      [bool]$FailedQuarantine.failed_program_accepted -eq $false -and
      [bool]$FailedQuarantine.failed_program_promoted -eq $false -and
      [bool]$FailedQuarantine.failed_program_silently_retried -eq $false
    )
  }

  action = [pscustomobject]@{
    keep = [bool]($AbsorptionDecision -eq "KEEP")
    rollback_required = [bool]$RollbackRequired
    quarantine_required = [bool]$QuarantineRequired
    promote_now = [bool]$PromoteNow
    memory_update_required = [bool]$MemoryUpdateRequired
    owner_review_required = [bool]($AbsorptionDecision -eq "OWNER_REVIEW_REQUIRED")
    next_required_step = "PHASE165L_CONNECT_ABSORPTION_TO_BUILDER_MEMORY"
  }

  boundary = [pscustomobject]@{
    memory_mutated = $false
    protected_state_mutated = $false
    route_lock_mutated = $false
    task_queue_mutated = $false
    program_executed_again = $false
    external_agent_production = $false
    external_fetch_or_install = $false
    codex_used = $false
  }

  errors = @($Errors)
}

$Absorption | ConvertTo-Json -Depth 80 | Set-Content -Encoding UTF8 -Path $OutputPath

if (-not $SuccessEvidenceReady) {
  throw "PHASE165K_ABSORPTION_GATE_REQUIRES_OWNER_REVIEW: $($Errors -join ',')"
}

$Absorption | ConvertTo-Json -Depth 80
