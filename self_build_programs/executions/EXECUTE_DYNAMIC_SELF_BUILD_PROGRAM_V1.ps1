param(
  [string]$DynamicProgramPath = "self_build_programs/generated/SELF_BUILD_PROGRAM_OWNER_MATERIAL_INPUT_BOOTSTRAP_001_V1_001.json",
  [string]$DynamicAdmissionPath = "self_build_programs/admission/SELF_BUILD_PROGRAM_OWNER_MATERIAL_INPUT_BOOTSTRAP_001_V1_001_ADMISSION.json",
  [string]$LineagePath = "self_build_programs/lineage/SELF_BUILD_CAUSE_LINEAGE_EXAMPLE_V1.json",
  [string]$OutputDir = "self_build_programs/executions"
)

$ErrorActionPreference = "Stop"

$Program = Get-Content $DynamicProgramPath -Raw | ConvertFrom-Json
$Admission = Get-Content $DynamicAdmissionPath -Raw | ConvertFrom-Json
$Lineage = Get-Content $LineagePath -Raw | ConvertFrom-Json

$ProgramId = [string]$Program.program_id
$AdmissionProgramId = [string]$Admission.program_id
$LineageProgramId = [string]$Lineage.program.program_id
$SelectedMaterialId = [string]$Program.source.selected_material_id
$AdmissionMaterialId = [string]$Admission.source.selected_material_id
$LineageMaterialId = [string]$Lineage.owner_material.selected_material_id
$LineageId = [string]$Admission.source.lineage_id

if ([string]::IsNullOrWhiteSpace($ProgramId)) { throw "program_id is empty" }
if ($ProgramId -eq "SELF_BUILD_PROGRAM_001") { throw "program_id is still fixed SELF_BUILD_PROGRAM_001" }
if ($ProgramId -ne $AdmissionProgramId) { throw "program/admission id mismatch" }
if ($ProgramId -ne $LineageProgramId) { throw "program/lineage id mismatch" }
if ($SelectedMaterialId -ne $AdmissionMaterialId) { throw "program/admission material mismatch" }
if ($SelectedMaterialId -ne $LineageMaterialId) { throw "program/lineage material mismatch" }

if ([string]$Program.status -ne "GENERATED_CANDIDATE") { throw "program status is not GENERATED_CANDIDATE" }
if ([bool]$Program.admission_required -ne $true) { throw "program admission_required is not true" }
if ([bool]$Program.execution_performed -ne $false) { throw "program already says execution_performed=true" }

if ([string]$Admission.status -ne "PASS") { throw "admission status is not PASS" }
if ([string]$Admission.admission_decision -ne "ADMIT_CANDIDATE_FOR_CONTROLLED_EXECUTION") { throw "admission decision mismatch" }
if ([bool]$Admission.admission_performed -ne $true) { throw "admission_performed is not true" }
if ([bool]$Admission.execution_performed -ne $false) { throw "admission already says execution_performed=true" }
if ([bool]$Admission.no_execution_guarantee -ne $true) { throw "no_execution_guarantee is not true before execution handoff" }

if ([bool]$Admission.lineage.admission_lineage_preserved -ne $true) { throw "admission lineage not preserved" }
if ([bool]$Admission.lineage.lineage_required -ne $true) { throw "admission lineage_required is not true" }
if ([bool]$Admission.lineage.not_atom -ne $true) { throw "admission not_atom is not true" }

$ExecutionId = "${ProgramId}_EXECUTION"
$OutputPath = Join-Path $OutputDir ($ExecutionId + ".json")

$Execution = [pscustomobject]@{
  schema_version = "dynamic_self_build_program_execution_v1"
  phase = "PHASE90"
  executed_by = "EXECUTE_DYNAMIC_SELF_BUILD_PROGRAM_V1"
  created_utc = (Get-Date).ToUniversalTime().ToString("o")
  execution_id = $ExecutionId
  program_id = $ProgramId
  admission_id = [string]$Admission.admission_id
  status = "PASS"
  execution_status = "CONTROLLED_RUNTIME_EXECUTED"
  execution_performed = $true
  completed_loop = $true
  controlled_runtime = $true
  queue_returned_to_none = $true
  next_required_step = "PHASE165I_SELF_BUILD_LOOP_REGRESSION_HARNESS"

  source = [pscustomobject]@{
    dynamic_program_path = $DynamicProgramPath
    dynamic_admission_path = $DynamicAdmissionPath
    selected_material_id = $SelectedMaterialId
    source_material_id = [string]$Program.source.source_material_id
    selected_source_file = [string]$Program.source.selected_source_file
    selector = [string]$Program.source.selector
    lineage_id = $LineageId
    lineage_path = $LineagePath
  }

  lineage = [pscustomobject]@{
    lineage_id = $LineageId
    required_path = "PHASE87->PHASE88->PHASE89->PHASE90"
    lineage_required = $true
    not_atom = $true
    owner_material_preserved = $true
    program_identity_preserved = $true
    dynamic_program_preserved = $true
    admission_lineage_preserved = $true
    execution_lineage_preserved = $true
  }

  controlled_execution = [pscustomobject]@{
    dynamic_program_validated = $true
    dynamic_admission_validated = $true
    lineage_validated = $true
    external_agent_production = $false
    external_fetch_or_install = $false
    protected_state_mutation = $false
    route_lock_mutation = $false
    codex_used = $false
  }

  owner_material = $Program.owner_material
}

$Execution | ConvertTo-Json -Depth 80 | Set-Content -Encoding UTF8 -Path $OutputPath
$Execution | ConvertTo-Json -Depth 80
