param(
  [string]$DynamicProgramPath = "self_build_programs/generated/SELF_BUILD_PROGRAM_OWNER_MATERIAL_INPUT_BOOTSTRAP_001_V1_001.json",
  [string]$LineagePath = "self_build_programs/lineage/SELF_BUILD_CAUSE_LINEAGE_EXAMPLE_V1.json",
  [string]$OutputDir = "self_build_programs/admission"
)

$ErrorActionPreference = "Stop"

$Program = Get-Content $DynamicProgramPath -Raw | ConvertFrom-Json
$Lineage = Get-Content $LineagePath -Raw | ConvertFrom-Json

$ProgramId = [string]$Program.program_id
$LineageId = [string]$Program.source.lineage_id
$LineageProgramId = [string]$Lineage.program.program_id
$SelectedMaterialId = [string]$Program.source.selected_material_id
$LineageMaterialId = [string]$Lineage.owner_material.selected_material_id

if ([string]::IsNullOrWhiteSpace($ProgramId)) { throw "program_id is empty" }
if ($ProgramId -eq "SELF_BUILD_PROGRAM_001") { throw "program_id is still fixed SELF_BUILD_PROGRAM_001" }
if ($ProgramId -ne $LineageProgramId) { throw "program_id mismatch with lineage" }
if ($SelectedMaterialId -ne $LineageMaterialId) { throw "selected material mismatch with lineage" }
if ([string]$Program.status -ne "GENERATED_CANDIDATE") { throw "program status is not GENERATED_CANDIDATE" }
if ([bool]$Program.admission_required -ne $true) { throw "admission_required is not true" }
if ([bool]$Program.admission_performed -ne $false) { throw "program already says admission_performed=true" }
if ([bool]$Program.execution_performed -ne $false) { throw "program already says execution_performed=true" }
if ([bool]$Program.lineage.lineage_required -ne $true) { throw "lineage_required is not true" }
if ([bool]$Program.lineage.not_atom -ne $true) { throw "not_atom is not true" }

$AdmissionId = "${ProgramId}_ADMISSION"
$OutputPath = Join-Path $OutputDir ($AdmissionId + ".json")

$Admission = [pscustomobject]@{
  schema_version = "dynamic_generated_program_admission_v1"
  phase = "PHASE89"
  admitted_by = "ADMIT_DYNAMIC_SELF_BUILD_PROGRAM_V1"
  created_utc = (Get-Date).ToUniversalTime().ToString("o")
  admission_id = $AdmissionId
  program_id = $ProgramId
  status = "PASS"
  admission_status = "ADMITTED_FOR_CONTROLLED_EXECUTION"
  admission_decision = "ADMIT_CANDIDATE_FOR_CONTROLLED_EXECUTION"
  admission_required = $true
  admission_performed = $true
  execution_performed = $false
  no_execution_guarantee = $true
  next_required_step = "PHASE165H_PATCH_EXECUTION_FOR_DYNAMIC_PROGRAMS"
  canonical_execution_step_after_patch = "PHASE90_BUILDER_EXECUTES_OWN_GENERATED_SELF_BUILD_PROGRAM_V1"

  source = [pscustomobject]@{
    dynamic_program_path = $DynamicProgramPath
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
  }

  safety = [pscustomobject]@{
    no_execution = $true
    no_phase90_execution = $true
    no_external_agent_production = $true
    no_external_fetch_or_install = $true
    no_protected_state_mutation = $true
  }
}

$Admission | ConvertTo-Json -Depth 60 | Set-Content -Encoding UTF8 -Path $OutputPath
$Admission | ConvertTo-Json -Depth 60
