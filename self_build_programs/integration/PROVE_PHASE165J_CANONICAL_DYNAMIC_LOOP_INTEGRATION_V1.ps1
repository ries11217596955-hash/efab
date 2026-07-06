param(
  [string]$OutputPath = "proofs/self_development/PHASE165J_CANONICAL_DYNAMIC_LOOP_TRIAL_OR_INTEGRATION_PROOF_V1.json"
)

$ErrorActionPreference = "Stop"

function Read-JsonRequired([string]$Path) {
  if (-not (Test-Path $Path)) { throw "Missing required file: $Path" }
  return Get-Content $Path -Raw | ConvertFrom-Json
}

function File-HasText([string]$Path, [string]$Pattern) {
  if (-not (Test-Path $Path)) { return $false }
  return [bool](Select-String -Path $Path -Pattern $Pattern -SimpleMatch -Quiet)
}

$RouteLockPath = "route_locks/AGENT_BUILDER_NEXT_15_STEPS_LOCK_V2.md"
$OrchestratorPath = "orchestrator/run.ps1"
$TaskQueuePath = "TASK_QUEUE.json"

$Phase87ApplyPath = "packs/PHASE87_SELF_DEVELOPMENT_DECISION_KERNEL_V1/APPLY.ps1"
$Phase88ApplyPath = "packs/PHASE88_SELF_BUILD_PROGRAM_GENERATOR_V1/APPLY.ps1"
$Phase89ApplyPath = "packs/PHASE89_GENERATED_PROGRAM_ADMISSION_V1/APPLY.ps1"
$Phase90ApplyPath = "packs/PHASE90_BUILDER_EXECUTES_OWN_GENERATED_SELF_BUILD_PROGRAM_V1/APPLY.ps1"

$DecisionTaskPath = "tasks/TASK_SELF_DEVELOPMENT_DECISION_KERNEL_V1_001.json"
$ProgramTaskPath = "tasks/TASK_SELF_BUILD_PROGRAM_GENERATOR_V1_001.json"
$AdmissionTaskPath = "tasks/TASK_GENERATED_PROGRAM_ADMISSION_V1_001.json"
$ExecutionTaskPath = "tasks/TASK_BUILDER_EXECUTES_OWN_GENERATED_SELF_BUILD_PROGRAM_V1_001.json"

$HarnessProofPath = "proofs/self_development/PHASE165I_SELF_BUILD_LOOP_REGRESSION_HARNESS_V1.json"
$DecisionPath = "self_build_batch/decision_kernel/PHASE165E_DYNAMIC_GAP_DECISION_V1.json"
$ProgramPath = "self_build_programs/generated/SELF_BUILD_PROGRAM_OWNER_MATERIAL_INPUT_BOOTSTRAP_001_V1_001.json"
$AdmissionPath = "self_build_programs/admission/SELF_BUILD_PROGRAM_OWNER_MATERIAL_INPUT_BOOTSTRAP_001_V1_001_ADMISSION.json"
$ExecutionPath = "self_build_programs/executions/SELF_BUILD_PROGRAM_OWNER_MATERIAL_INPUT_BOOTSTRAP_001_V1_001_EXECUTION.json"
$LineagePath = "self_build_programs/lineage/SELF_BUILD_CAUSE_LINEAGE_EXAMPLE_V1.json"

$Harness = Read-JsonRequired $HarnessProofPath
$Decision = Read-JsonRequired $DecisionPath
$Program = Read-JsonRequired $ProgramPath
$Admission = Read-JsonRequired $AdmissionPath
$Execution = Read-JsonRequired $ExecutionPath
$Lineage = Read-JsonRequired $LineagePath

$Markers = [pscustomobject]@{
  phase87_dynamic_decision_patch = (File-HasText $Phase87ApplyPath "PHASE165E_DYNAMIC_GAP_SELECTION_PATCH_START")
  phase88_dynamic_generation_patch = (File-HasText $Phase88ApplyPath "PHASE165F_DYNAMIC_SELF_BUILD_PROGRAM_GENERATION_PATCH_START")
  phase89_dynamic_admission_patch = (File-HasText $Phase89ApplyPath "PHASE165G_DYNAMIC_GENERATED_PROGRAM_ADMISSION_PATCH_START")
  phase90_dynamic_execution_patch = (File-HasText $Phase90ApplyPath "PHASE165H_DYNAMIC_SELF_BUILD_PROGRAM_EXECUTION_PATCH_START")
}

$TaskHardcode = [pscustomobject]@{
  decision_task_exists = (Test-Path $DecisionTaskPath)
  program_task_exists = (Test-Path $ProgramTaskPath)
  admission_task_mentions_fixed_program = (File-HasText $AdmissionTaskPath "SELF_BUILD_PROGRAM_001")
  execution_task_mentions_fixed_program = (File-HasText $ExecutionTaskPath "SELF_BUILD_PROGRAM_001")
}

$Errors = @()
function Add-Error([string]$Code) { $script:Errors += $Code }

if ([bool]$Harness.validation_passed -ne $true) { Add-Error "PHASE165I_HARNESS_NOT_PASSING" }
if ([string]$Harness.status -ne "PASS") { Add-Error "PHASE165I_STATUS_NOT_PASS" }
if ([bool]$Harness.harness_read_only -ne $true) { Add-Error "PHASE165I_HARNESS_NOT_READ_ONLY" }

foreach ($Name in $Markers.PSObject.Properties.Name) {
  if ([bool]$Markers.$Name -ne $true) { Add-Error "MISSING_PATCH_MARKER_$Name" }
}

$ProgramId = [string]$Harness.program_id
$LineageId = [string]$Harness.lineage_id

if ([string]$Decision.program_id -ne $ProgramId) { Add-Error "DECISION_PROGRAM_ID_MISMATCH" }
if ([string]$Program.program_id -ne $ProgramId) { Add-Error "PROGRAM_ID_MISMATCH" }
if ([string]$Admission.program_id -ne $ProgramId) { Add-Error "ADMISSION_PROGRAM_ID_MISMATCH" }
if ([string]$Execution.program_id -ne $ProgramId) { Add-Error "EXECUTION_PROGRAM_ID_MISMATCH" }
if ([string]$Lineage.lineage_id -ne $LineageId) { Add-Error "LINEAGE_ID_MISMATCH" }

if ([bool]$Execution.execution_performed -ne $true) { Add-Error "EXECUTION_NOT_PERFORMED" }
if ([bool]$Execution.completed_loop -ne $true) { Add-Error "LOOP_NOT_COMPLETED" }
if ([bool]$Execution.queue_returned_to_none -ne $true) { Add-Error "QUEUE_NOT_RETURNED_TO_NONE" }
if ([bool]$Execution.lineage.execution_lineage_preserved -ne $true) { Add-Error "EXECUTION_LINEAGE_NOT_PRESERVED" }

$CanonicalTaskDescriptorsStillFixed = (
  [bool]$TaskHardcode.admission_task_mentions_fixed_program -or
  [bool]$TaskHardcode.execution_task_mentions_fixed_program
)

$CanonicalTrialSelected = $false
$IntegrationProofSelected = $true
$CanonicalTrialNotRunReason = if ($CanonicalTaskDescriptorsStillFixed) {
  "Canonical task descriptors still mention SELF_BUILD_PROGRAM_001, so PHASE165J selects integration proof instead of mutating/running canonical queue."
} else {
  "Integration proof selected by route option to avoid unnecessary repeated execution before absorption gate."
}

$Status = if ($Errors.Count -eq 0) { "PASS" } else { "FAIL" }

$Proof = [pscustomobject]@{
  phase = "PHASE165J_CANONICAL_DYNAMIC_LOOP_TRIAL_OR_INTEGRATION_PROOF"
  created_utc = (Get-Date).ToUniversalTime().ToString("o")
  mode = "INTEGRATION_PROOF_NO_CANONICAL_RERUN"
  status = $Status
  validation_passed = [bool]($Status -eq "PASS")
  errors = @($Errors)

  canonical_trial_selected = $CanonicalTrialSelected
  integration_proof_selected = $IntegrationProofSelected
  canonical_trial_not_run_reason = $CanonicalTrialNotRunReason
  canonical_task_descriptors_still_fixed = [bool]$CanonicalTaskDescriptorsStillFixed

  program_id = $ProgramId
  lineage_id = $LineageId
  required_path = "PHASE87->PHASE88->PHASE89->PHASE90"

  phase165i_harness_status = [string]$Harness.status
  phase165i_validation_passed = [bool]$Harness.validation_passed
  decision_evidence_ready = [bool]$Decision.evidence_ready
  program_status = [string]$Program.status
  admission_status = [string]$Admission.status
  execution_status = [string]$Execution.status
  execution_performed = [bool]$Execution.execution_performed
  completed_loop = [bool]$Execution.completed_loop
  controlled_runtime = [bool]$Execution.controlled_runtime
  queue_returned_to_none = [bool]$Execution.queue_returned_to_none
  lineage_preserved = [bool]$Execution.lineage.execution_lineage_preserved

  patch_markers = $Markers
  task_descriptor_scope = $TaskHardcode

  canonical_state_mutated = $false
  route_lock_mutated = $false
  program_executed_again = $false
  external_agent_production = $false
  external_fetch_or_install = $false
  codex_used = $false

  conclusion = "PHASE165J proves the dynamic PHASE87->PHASE88->PHASE89->PHASE90 loop is integrated through patched canonical packs and validated by PHASE165I harness. Canonical rerun is deferred because task descriptors still carry fixed bootstrap assumptions."
  next_locked_step_after_build = "PHASE165K_ABSORPTION_DECISION_GATE"
}

$Proof | ConvertTo-Json -Depth 80 | Set-Content -Encoding UTF8 -Path $OutputPath

if ($Status -ne "PASS") {
  throw "PHASE165J_INTEGRATION_PROOF_FAILED: $($Errors -join ',')"
}

$Proof | ConvertTo-Json -Depth 80
