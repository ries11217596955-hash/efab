param(
  [string]$DryRunBase = "self_build_programs/dry_runs/PHASE165M_OWNER_MATERIAL_DYNAMIC_SELF_BUILD_DRY_RUN_V1",
  [string]$OutputPath = "self_build_programs/dry_runs/PHASE165M_OWNER_MATERIAL_DYNAMIC_SELF_BUILD_DRY_RUN_V1/PHASE165M_DYNAMIC_OWNER_MATERIAL_SELF_BUILD_DRY_RUN_RESULT_V1.json"
)

$ErrorActionPreference = "Stop"

$GeneratorPath = "self_build_programs/generator/GENERATE_DYNAMIC_SELF_BUILD_PROGRAM_V1.ps1"
$AdmissionPath = "self_build_programs/admission/ADMIT_DYNAMIC_SELF_BUILD_PROGRAM_V1.ps1"
$ExecutionPath = "self_build_programs/executions/EXECUTE_DYNAMIC_SELF_BUILD_PROGRAM_V1.ps1"
$AbsorptionGatePath = "self_build_programs/absorption/DECIDE_SELF_BUILD_ABSORPTION_V1.ps1"
$MemoryConnectorPath = "self_build_programs/memory/CONNECT_ABSORPTION_TO_BUILDER_MEMORY_V1.ps1"

$DecisionPath = "self_build_batch/decision_kernel/PHASE165E_DYNAMIC_GAP_DECISION_V1.json"
$SelectedPath = "self_build_batch/owner_material_inputs/selected/SELECTED_OWNER_MATERIAL_INPUT.json"
$IdentityPath = "self_build_programs/identity/SELF_BUILD_PROGRAM_IDENTITY_EXAMPLE_V1.json"
$LineagePath = "self_build_programs/lineage/SELF_BUILD_CAUSE_LINEAGE_EXAMPLE_V1.json"

$GeneratedDir = "$DryRunBase/generated"
$AdmissionDir = "$DryRunBase/admission"
$ExecutionDir = "$DryRunBase/executions"
$AbsorptionDir = "$DryRunBase/absorption"
$MemoryDir = "$DryRunBase/memory"

New-Item -ItemType Directory -Force -Path $GeneratedDir,$AdmissionDir,$ExecutionDir,$AbsorptionDir,$MemoryDir | Out-Null

$Identity = Get-Content $IdentityPath -Raw | ConvertFrom-Json
$ProgramId = [string]$Identity.program_id

if ([string]::IsNullOrWhiteSpace($ProgramId)) { throw "program_id is empty" }
if ($ProgramId -eq "SELF_BUILD_PROGRAM_001") { throw "program_id still fixed bootstrap" }

$DryProgramPath = "$GeneratedDir/$ProgramId.json"
$DryAdmissionPath = "$AdmissionDir/${ProgramId}_ADMISSION.json"
$DryExecutionPath = "$ExecutionDir/${ProgramId}_EXECUTION.json"
$DryAbsorptionPath = "$AbsorptionDir/${ProgramId}_ABSORPTION_DECISION.json"
$DryMemoryPath = "$MemoryDir/${ProgramId}_MEMORY_ABSORPTION.json"

& powershell -NoProfile -ExecutionPolicy Bypass -File $GeneratorPath `
  -DecisionPath $DecisionPath `
  -SelectedPath $SelectedPath `
  -IdentityPath $IdentityPath `
  -LineagePath $LineagePath `
  -OutputDir $GeneratedDir | Out-Null

& powershell -NoProfile -ExecutionPolicy Bypass -File $AdmissionPath `
  -DynamicProgramPath $DryProgramPath `
  -LineagePath $LineagePath `
  -OutputDir $AdmissionDir | Out-Null

& powershell -NoProfile -ExecutionPolicy Bypass -File $ExecutionPath `
  -DynamicProgramPath $DryProgramPath `
  -DynamicAdmissionPath $DryAdmissionPath `
  -LineagePath $LineagePath `
  -OutputDir $ExecutionDir | Out-Null

& powershell -NoProfile -ExecutionPolicy Bypass -File $AbsorptionGatePath `
  -ExecutionPath $DryExecutionPath `
  -OutputPath $DryAbsorptionPath | Out-Null

& powershell -NoProfile -ExecutionPolicy Bypass -File $MemoryConnectorPath `
  -AbsorptionDecisionPath $DryAbsorptionPath `
  -OutputPath $DryMemoryPath | Out-Null

$Program = Get-Content $DryProgramPath -Raw | ConvertFrom-Json
$Admission = Get-Content $DryAdmissionPath -Raw | ConvertFrom-Json
$Execution = Get-Content $DryExecutionPath -Raw | ConvertFrom-Json
$Absorption = Get-Content $DryAbsorptionPath -Raw | ConvertFrom-Json
$Memory = Get-Content $DryMemoryPath -Raw | ConvertFrom-Json

$Errors = @()
function Add-Error([string]$Code) { $script:Errors += $Code }

if ([string]$Program.program_id -ne $ProgramId) { Add-Error "PROGRAM_ID_MISMATCH" }
if ([string]$Program.status -ne "GENERATED_CANDIDATE") { Add-Error "PROGRAM_NOT_GENERATED_CANDIDATE" }

if ([string]$Admission.program_id -ne $ProgramId) { Add-Error "ADMISSION_PROGRAM_ID_MISMATCH" }
if ([string]$Admission.status -ne "PASS") { Add-Error "ADMISSION_NOT_PASS" }
if ([bool]$Admission.admission_performed -ne $true) { Add-Error "ADMISSION_NOT_PERFORMED" }

if ([string]$Execution.program_id -ne $ProgramId) { Add-Error "EXECUTION_PROGRAM_ID_MISMATCH" }
if ([bool]$Execution.execution_performed -ne $true) { Add-Error "EXECUTION_NOT_PERFORMED" }
if ([bool]$Execution.completed_loop -ne $true) { Add-Error "LOOP_NOT_COMPLETED" }
if ([bool]$Execution.queue_returned_to_none -ne $true) { Add-Error "QUEUE_NOT_RETURNED_TO_NONE" }
if ([bool]$Execution.lineage.execution_lineage_preserved -ne $true) { Add-Error "LINEAGE_NOT_PRESERVED" }

if ([string]$Absorption.absorption_decision -ne "KEEP") { Add-Error "ABSORPTION_NOT_KEEP" }
if ([bool]$Absorption.action.promote_now -ne $false) { Add-Error "PROMOTE_NOW_NOT_FALSE" }

if ([string]$Memory.status -ne "PASS") { Add-Error "MEMORY_RECORD_NOT_PASS" }
if ([string]$Memory.memory_event.absorption_decision -ne "KEEP") { Add-Error "MEMORY_RECORD_NOT_KEEP" }

$Status = if ($Errors.Count -eq 0) { "PASS" } else { "FAIL" }

$Result = [pscustomobject]@{
  schema_version = "phase165m_dynamic_owner_material_self_build_dry_run_result_v1"
  phase = "PHASE165M_RUN_FIRST_DYNAMIC_OWNER_MATERIAL_SELF_BUILD_DRY_RUN"
  created_utc = (Get-Date).ToUniversalTime().ToString("o")
  status = $Status
  validation_passed = [bool]($Status -eq "PASS")
  errors = @($Errors)

  dry_run_mode = "NON_CANONICAL_PROBE"
  canonical_orchestrator_used = $false
  task_queue_used = $false
  task_queue_mutated = $false

  program_id = $ProgramId
  lineage_id = [string]$Execution.source.lineage_id
  selected_material_id = [string]$Execution.source.selected_material_id

  generated_program_path = $DryProgramPath
  admission_path = $DryAdmissionPath
  execution_path = $DryExecutionPath
  absorption_path = $DryAbsorptionPath
  memory_record_path = $DryMemoryPath

  dynamic_program_generated = [bool]($Program.status -eq "GENERATED_CANDIDATE")
  dynamic_admission_performed = [bool]$Admission.admission_performed
  dynamic_execution_performed = [bool]$Execution.execution_performed
  completed_loop = [bool]$Execution.completed_loop
  queue_returned_to_none = [bool]$Execution.queue_returned_to_none
  lineage_preserved = [bool]$Execution.lineage.execution_lineage_preserved
  absorption_decision = [string]$Absorption.absorption_decision
  memory_record_status = [string]$Memory.status

  protected_state_mutated = $false
  route_lock_mutated = $false
  external_agent_production = $false
  external_fetch_or_install = $false
  codex_used = $false

  next_locked_step_after_build = "PHASE165N_RUN_FIRST_DYNAMIC_OWNER_MATERIAL_SELF_BUILD_CANONICAL_TRIAL"
}

$Result | ConvertTo-Json -Depth 80 | Set-Content -Encoding UTF8 -Path $OutputPath

if ($Status -ne "PASS") {
  throw "PHASE165M_DRY_RUN_FAILED: $($Errors -join ',')"
}

$Result | ConvertTo-Json -Depth 80
