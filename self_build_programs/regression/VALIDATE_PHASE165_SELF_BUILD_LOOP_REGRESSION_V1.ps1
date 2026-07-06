param(
  [string]$OutputPath = "proofs/self_development/PHASE165I_SELF_BUILD_LOOP_REGRESSION_HARNESS_V1.json"
)

$ErrorActionPreference = "Stop"

function Read-JsonRequired([string]$Path) {
  if (-not (Test-Path $Path)) { throw "Missing required file: $Path" }
  return Get-Content $Path -Raw | ConvertFrom-Json
}

$SelectedPath = "self_build_batch/owner_material_inputs/selected/SELECTED_OWNER_MATERIAL_INPUT.json"
$IdentityPath = "self_build_programs/identity/SELF_BUILD_PROGRAM_IDENTITY_EXAMPLE_V1.json"
$LineagePath = "self_build_programs/lineage/SELF_BUILD_CAUSE_LINEAGE_EXAMPLE_V1.json"
$DecisionPath = "self_build_batch/decision_kernel/PHASE165E_DYNAMIC_GAP_DECISION_V1.json"
$ProgramPath = "self_build_programs/generated/SELF_BUILD_PROGRAM_OWNER_MATERIAL_INPUT_BOOTSTRAP_001_V1_001.json"
$AdmissionPath = "self_build_programs/admission/SELF_BUILD_PROGRAM_OWNER_MATERIAL_INPUT_BOOTSTRAP_001_V1_001_ADMISSION.json"
$ExecutionPath = "self_build_programs/executions/SELF_BUILD_PROGRAM_OWNER_MATERIAL_INPUT_BOOTSTRAP_001_V1_001_EXECUTION.json"

$Selected = Read-JsonRequired $SelectedPath
$Identity = Read-JsonRequired $IdentityPath
$Lineage = Read-JsonRequired $LineagePath
$Decision = Read-JsonRequired $DecisionPath
$Program = Read-JsonRequired $ProgramPath
$Admission = Read-JsonRequired $AdmissionPath
$Execution = Read-JsonRequired $ExecutionPath

$Errors = @()

function Add-Error([string]$Code) {
  $script:Errors += $Code
}

$ProgramId = [string]$Identity.program_id
$MaterialId = [string]$Selected.selected_material_id
$LineageId = [string]$Lineage.lineage_id
$RequiredPath = "PHASE87->PHASE88->PHASE89->PHASE90"

if ([string]::IsNullOrWhiteSpace($MaterialId)) { Add-Error "SELECTED_MATERIAL_ID_EMPTY" }
if ([string]::IsNullOrWhiteSpace($ProgramId)) { Add-Error "PROGRAM_ID_EMPTY" }
if ($ProgramId -eq "SELF_BUILD_PROGRAM_001") { Add-Error "PROGRAM_ID_STILL_FIXED_BOOTSTRAP" }
if ([string]::IsNullOrWhiteSpace($LineageId)) { Add-Error "LINEAGE_ID_EMPTY" }

if ([string]$Identity.source_material_id -ne $MaterialId) { Add-Error "IDENTITY_MATERIAL_MISMATCH" }
if ([string]$Lineage.owner_material.selected_material_id -ne $MaterialId) { Add-Error "LINEAGE_OWNER_MATERIAL_MISMATCH" }
if ([string]$Lineage.program.program_id -ne $ProgramId) { Add-Error "LINEAGE_PROGRAM_ID_MISMATCH" }

if ([string]$Decision.program_id -ne $ProgramId) { Add-Error "DECISION_PROGRAM_ID_MISMATCH" }
if ([string]$Decision.lineage_id -ne $LineageId) { Add-Error "DECISION_LINEAGE_ID_MISMATCH" }
if ([bool]$Decision.evidence_ready -ne $true) { Add-Error "DECISION_EVIDENCE_NOT_READY" }
if ([string]$Decision.selected_next_step -ne "PHASE165F_PATCH_PROGRAM_GENERATOR_FOR_DYNAMIC_SELF_BUILD_PROGRAMS") { Add-Error "DECISION_NEXT_STEP_MISMATCH" }

if ([string]$Program.program_id -ne $ProgramId) { Add-Error "PROGRAM_ID_MISMATCH" }
if ([string]$Program.status -ne "GENERATED_CANDIDATE") { Add-Error "PROGRAM_STATUS_MISMATCH" }
if ([bool]$Program.admission_required -ne $true) { Add-Error "PROGRAM_ADMISSION_REQUIRED_NOT_TRUE" }
if ([bool]$Program.admission_performed -ne $false) { Add-Error "PROGRAM_ADMISSION_PERFORMED_SHOULD_BE_FALSE" }
if ([bool]$Program.execution_performed -ne $false) { Add-Error "PROGRAM_EXECUTION_PERFORMED_SHOULD_BE_FALSE" }

if ([string]$Admission.program_id -ne $ProgramId) { Add-Error "ADMISSION_PROGRAM_ID_MISMATCH" }
if ([string]$Admission.status -ne "PASS") { Add-Error "ADMISSION_STATUS_NOT_PASS" }
if ([string]$Admission.admission_decision -ne "ADMIT_CANDIDATE_FOR_CONTROLLED_EXECUTION") { Add-Error "ADMISSION_DECISION_MISMATCH" }
if ([bool]$Admission.admission_performed -ne $true) { Add-Error "ADMISSION_PERFORMED_NOT_TRUE" }
if ([bool]$Admission.execution_performed -ne $false) { Add-Error "ADMISSION_EXECUTION_PERFORMED_SHOULD_BE_FALSE" }
if ([bool]$Admission.no_execution_guarantee -ne $true) { Add-Error "ADMISSION_NO_EXECUTION_GUARANTEE_NOT_TRUE" }

if ([string]$Execution.program_id -ne $ProgramId) { Add-Error "EXECUTION_PROGRAM_ID_MISMATCH" }
if ([string]$Execution.admission_id -ne [string]$Admission.admission_id) { Add-Error "EXECUTION_ADMISSION_ID_MISMATCH" }
if ([string]$Execution.status -ne "PASS") { Add-Error "EXECUTION_STATUS_NOT_PASS" }
if ([bool]$Execution.execution_performed -ne $true) { Add-Error "EXECUTION_PERFORMED_NOT_TRUE" }
if ([bool]$Execution.completed_loop -ne $true) { Add-Error "EXECUTION_COMPLETED_LOOP_NOT_TRUE" }
if ([bool]$Execution.controlled_runtime -ne $true) { Add-Error "EXECUTION_CONTROLLED_RUNTIME_NOT_TRUE" }
if ([bool]$Execution.queue_returned_to_none -ne $true) { Add-Error "EXECUTION_QUEUE_RETURNED_TO_NONE_NOT_TRUE" }

foreach ($Obj in @($Selected,$Identity,$Lineage,$Decision,$Program,$Admission,$Execution)) {
  if ([string]$Obj.required_path -and [string]$Obj.required_path -ne $RequiredPath) {
    Add-Error "REQUIRED_PATH_MISMATCH"
  }
}

if ([bool]$Decision.not_atom -ne $true) { Add-Error "DECISION_NOT_ATOM_NOT_TRUE" }
if ([bool]$Program.lineage.not_atom -ne $true) { Add-Error "PROGRAM_NOT_ATOM_NOT_TRUE" }
if ([bool]$Admission.lineage.not_atom -ne $true) { Add-Error "ADMISSION_NOT_ATOM_NOT_TRUE" }
if ([bool]$Execution.lineage.not_atom -ne $true) { Add-Error "EXECUTION_NOT_ATOM_NOT_TRUE" }

if ([bool]$Execution.lineage.execution_lineage_preserved -ne $true) { Add-Error "EXECUTION_LINEAGE_NOT_PRESERVED" }
if ([bool]$Execution.controlled_execution.external_agent_production -ne $false) { Add-Error "EXTERNAL_AGENT_PRODUCTION_TRUE" }
if ([bool]$Execution.controlled_execution.external_fetch_or_install -ne $false) { Add-Error "EXTERNAL_FETCH_OR_INSTALL_TRUE" }
if ([bool]$Execution.controlled_execution.protected_state_mutation -ne $false) { Add-Error "PROTECTED_STATE_MUTATION_TRUE" }
if ([bool]$Execution.controlled_execution.route_lock_mutation -ne $false) { Add-Error "ROUTE_LOCK_MUTATION_TRUE" }
if ([bool]$Execution.controlled_execution.codex_used -ne $false) { Add-Error "CODEX_USED_TRUE" }

$Status = if ($Errors.Count -eq 0) { "PASS" } else { "FAIL" }

$Proof = [pscustomobject]@{
  phase = "PHASE165I_SELF_BUILD_LOOP_REGRESSION_HARNESS"
  created_utc = (Get-Date).ToUniversalTime().ToString("o")
  mode = "READ_ONLY_REGRESSION_VALIDATE_PHASE87_TO_PHASE90_DYNAMIC_SELF_BUILD_LOOP"
  status = $Status
  validation_passed = [bool]($Status -eq "PASS")
  errors = @($Errors)

  selected_material_id = $MaterialId
  program_id = $ProgramId
  lineage_id = $LineageId
  required_path = $RequiredPath

  decision_evidence_ready = [bool]$Decision.evidence_ready
  program_status = [string]$Program.status
  admission_status = [string]$Admission.status
  admission_performed = [bool]$Admission.admission_performed
  execution_status = [string]$Execution.status
  execution_performed = [bool]$Execution.execution_performed
  completed_loop = [bool]$Execution.completed_loop
  controlled_runtime = [bool]$Execution.controlled_runtime
  queue_returned_to_none = [bool]$Execution.queue_returned_to_none
  lineage_preserved = [bool]$Execution.lineage.execution_lineage_preserved

  no_external_agent_production = [bool](-not [bool]$Execution.controlled_execution.external_agent_production)
  no_external_fetch_or_install = [bool](-not [bool]$Execution.controlled_execution.external_fetch_or_install)
  no_protected_state_mutation = [bool](-not [bool]$Execution.controlled_execution.protected_state_mutation)
  no_route_lock_mutation = [bool](-not [bool]$Execution.controlled_execution.route_lock_mutation)
  codex_used = [bool]$Execution.controlled_execution.codex_used

  canonical_state_mutated = $false
  route_lock_mutated = $false
  program_executed_again = $false
  harness_read_only = $true

  checked_artifacts = [pscustomobject]@{
    selected = $SelectedPath
    identity = $IdentityPath
    lineage = $LineagePath
    decision = $DecisionPath
    program = $ProgramPath
    admission = $AdmissionPath
    execution = $ExecutionPath
  }

  conclusion = "PHASE165I regression harness validates the full dynamic PHASE87->PHASE88->PHASE89->PHASE90 self-build loop without mutating canonical state."
  next_locked_step_after_build = "PHASE165J_CANONICAL_DYNAMIC_LOOP_TRIAL_OR_INTEGRATION_PROOF"
}

$Proof | ConvertTo-Json -Depth 80 | Set-Content -Encoding UTF8 -Path $OutputPath

if ($Status -ne "PASS") {
  throw "PHASE165I_REGRESSION_FAILED: $($Errors -join ',')"
}

$Proof | ConvertTo-Json -Depth 80
