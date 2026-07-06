param(
  [string]$ResultPath = "self_build_programs/canonical_trials/PHASE165N_FIRST_DYNAMIC_OWNER_MATERIAL_CANONICAL_TRIAL_V1/PHASE165N_FIRST_DYNAMIC_OWNER_MATERIAL_CANONICAL_TRIAL_RESULT_V1.json"
)

$ErrorActionPreference = "Stop"

function Read-JsonRequired([string]$Path) {
  if (-not (Test-Path $Path)) { throw "Missing required file: $Path" }
  return Get-Content $Path -Raw | ConvertFrom-Json
}

function Has-Text([string]$Path, [string]$Pattern) {
  if (-not (Test-Path $Path)) { return $false }
  return [bool](Select-String -Path $Path -Pattern $Pattern -SimpleMatch -Quiet)
}

$RepairProofPath = "proofs/self_development/PHASE165N_ROUTE_REPAIR_DYNAMIC_CANONICAL_TASK_DESCRIPTOR_AND_ENTRYPOINT_CONTRACT_V1.json"
$MProofPath = "proofs/self_development/PHASE165M_RUN_FIRST_DYNAMIC_OWNER_MATERIAL_SELF_BUILD_DRY_RUN_V1.json"
$OrchestratorPath = "orchestrator/run.ps1"

$RepairProof = Read-JsonRequired $RepairProofPath
$MProof = Read-JsonRequired $MProofPath

$ProgramId = [string]$MProof.program_id
$LineageId = [string]$MProof.lineage_id
$SelectedMaterialId = [string]$MProof.selected_material_id

$Task88Path = "tasks/TASK_SELF_BUILD_PROGRAM_GENERATOR_V1_001.json"
$Task89Path = "tasks/TASK_GENERATED_PROGRAM_ADMISSION_V1_001.json"
$Task90Path = "tasks/TASK_BUILDER_EXECUTES_OWN_GENERATED_SELF_BUILD_PROGRAM_V1_001.json"
$Pack89Path = "packs/PHASE89_GENERATED_PROGRAM_ADMISSION_V1/APPLY.ps1"
$Pack90Path = "packs/PHASE90_BUILDER_EXECUTES_OWN_GENERATED_SELF_BUILD_PROGRAM_V1/APPLY.ps1"

$FixedSignalCount = @(
  Select-String -Path $Task88Path -Pattern "SELF_BUILD_PROGRAM_001" -SimpleMatch
  Select-String -Path $Task89Path -Pattern "SELF_BUILD_PROGRAM_001" -SimpleMatch
  Select-String -Path $Task90Path -Pattern "SELF_BUILD_PROGRAM_001" -SimpleMatch
  Select-String -Path $Pack89Path -Pattern "SELF_BUILD_PROGRAM_001" -SimpleMatch
  Select-String -Path $Pack90Path -Pattern "SELF_BUILD_PROGRAM_001" -SimpleMatch
).Count

$PreflightReady = (
  [bool]$RepairProof.validation_passed -eq $true -and
  [int]$RepairProof.fixed_signal_count_after -eq 0 -and
  [bool]$RepairProof.canonical_trial_ready_after_repair -eq $true -and
  [bool]$MProof.validation_passed -eq $true -and
  [bool]$MProof.dynamic_program_generated -eq $true -and
  [bool]$MProof.dynamic_admission_performed -eq $true -and
  [bool]$MProof.dynamic_execution_performed -eq $true -and
  [bool]$MProof.completed_loop -eq $true -and
  [int]$FixedSignalCount -eq 0
)

$Errors = @()
if (-not $PreflightReady) { $Errors += "PREFLIGHT_NOT_READY" }
if (-not (Test-Path $OrchestratorPath)) { $Errors += "ORCHESTRATOR_MISSING" }

$OrchestratorExitCode = $null
$OrchestratorOutput = @()
$CanonicalTrialExecuted = $false

if ($Errors.Count -eq 0) {
  $CanonicalTrialExecuted = $true

  try {
    $OrchestratorOutput = @(& powershell -NoProfile -ExecutionPolicy Bypass -File $OrchestratorPath 2>&1)
    $OrchestratorExitCode = $LASTEXITCODE
  } catch {
    $OrchestratorOutput = @($_.Exception.Message)
    $OrchestratorExitCode = 1
  }
}

$ProgramPath = "self_build_programs/generated/$ProgramId.json"
$AdmissionPath = "self_build_programs/admission/${ProgramId}_ADMISSION.json"
$ExecutionPath = "self_build_programs/executions/${ProgramId}_EXECUTION.json"
$AbsorptionPath = "self_build_programs/absorption/${ProgramId}_ABSORPTION_DECISION.json"
$MemoryPath = "self_build_programs/memory/${ProgramId}_MEMORY_ABSORPTION.json"

$ProgramExists = Test-Path $ProgramPath
$AdmissionExists = Test-Path $AdmissionPath
$ExecutionExists = Test-Path $ExecutionPath
$AbsorptionExists = Test-Path $AbsorptionPath
$MemoryExists = Test-Path $MemoryPath

$Program = if ($ProgramExists) { Read-JsonRequired $ProgramPath } else { $null }
$Admission = if ($AdmissionExists) { Read-JsonRequired $AdmissionPath } else { $null }
$Execution = if ($ExecutionExists) { Read-JsonRequired $ExecutionPath } else { $null }
$Absorption = if ($AbsorptionExists) { Read-JsonRequired $AbsorptionPath } else { $null }
$Memory = if ($MemoryExists) { Read-JsonRequired $MemoryPath } else { $null }

if (-not $ProgramExists) { $Errors += "DYNAMIC_PROGRAM_MISSING_AFTER_CANONICAL_RUN" }
if (-not $AdmissionExists) { $Errors += "DYNAMIC_ADMISSION_MISSING_AFTER_CANONICAL_RUN" }
if (-not $ExecutionExists) { $Errors += "DYNAMIC_EXECUTION_MISSING_AFTER_CANONICAL_RUN" }

$DynamicProgramGenerated = ($ProgramExists -and [string]$Program.status -eq "GENERATED_CANDIDATE")
$DynamicAdmissionPerformed = ($AdmissionExists -and [bool]$Admission.admission_performed -eq $true)
$DynamicExecutionPerformed = ($ExecutionExists -and [bool]$Execution.execution_performed -eq $true)
$CompletedLoop = ($ExecutionExists -and [bool]$Execution.completed_loop -eq $true)
$QueueReturnedToNone = ($ExecutionExists -and [bool]$Execution.queue_returned_to_none -eq $true)
$LineagePreserved = ($ExecutionExists -and [bool]$Execution.lineage.execution_lineage_preserved -eq $true)
$AbsorptionDecision = if ($AbsorptionExists) { [string]$Absorption.absorption_decision } else { "" }
$MemoryRecordStatus = if ($MemoryExists) { [string]$Memory.status } else { "" }

if (-not $DynamicProgramGenerated) { $Errors += "DYNAMIC_PROGRAM_NOT_GENERATED" }
if (-not $DynamicAdmissionPerformed) { $Errors += "DYNAMIC_ADMISSION_NOT_PERFORMED" }
if (-not $DynamicExecutionPerformed) { $Errors += "DYNAMIC_EXECUTION_NOT_PERFORMED" }
if (-not $CompletedLoop) { $Errors += "CANONICAL_LOOP_NOT_COMPLETED" }
if (-not $QueueReturnedToNone) { $Errors += "QUEUE_NOT_RETURNED_TO_NONE" }
if (-not $LineagePreserved) { $Errors += "LINEAGE_NOT_PRESERVED" }

$Status = if ($Errors.Count -eq 0) { "PASS" } else { "FAIL" }

$Result = [pscustomobject]@{
  schema_version = "phase165n_first_dynamic_owner_material_canonical_trial_result_v1"
  phase = "PHASE165N_RUN_FIRST_DYNAMIC_OWNER_MATERIAL_SELF_BUILD_CANONICAL_TRIAL"
  created_utc = (Get-Date).ToUniversalTime().ToString("o")
  status = $Status
  validation_passed = [bool]($Status -eq "PASS")
  errors = @($Errors)

  canonical_trial_executed = [bool]$CanonicalTrialExecuted
  orchestrator_used = [bool]$CanonicalTrialExecuted
  orchestrator_exit_code = $OrchestratorExitCode
  orchestrator_output_tail = @($OrchestratorOutput | Select-Object -Last 30)

  program_id = $ProgramId
  lineage_id = $LineageId
  selected_material_id = $SelectedMaterialId

  preflight_ready = [bool]$PreflightReady
  fixed_signal_count = [int]$FixedSignalCount

  dynamic_program_generated = [bool]$DynamicProgramGenerated
  dynamic_admission_performed = [bool]$DynamicAdmissionPerformed
  dynamic_execution_performed = [bool]$DynamicExecutionPerformed
  completed_loop = [bool]$CompletedLoop
  queue_returned_to_none = [bool]$QueueReturnedToNone
  lineage_preserved = [bool]$LineagePreserved
  absorption_decision = $AbsorptionDecision
  memory_record_status = $MemoryRecordStatus

  generated_program_path = $ProgramPath
  admission_path = $AdmissionPath
  execution_path = $ExecutionPath
  absorption_path = $AbsorptionPath
  memory_path = $MemoryPath

  external_agent_production = $false
  external_fetch_or_install = $false
  codex_used = $false

  next_locked_step_after_build = "PHASE165O_PROMOTION_OR_CANONICAL_DYNAMIC_CONTRACT_HARDENING_DECISION"
}

$Result | ConvertTo-Json -Depth 80 | Set-Content -Encoding UTF8 -Path $ResultPath

if ($Status -ne "PASS") {
  throw "PHASE165N_CANONICAL_TRIAL_FAILED: $($Errors -join ',')"
}

$Result | ConvertTo-Json -Depth 80
