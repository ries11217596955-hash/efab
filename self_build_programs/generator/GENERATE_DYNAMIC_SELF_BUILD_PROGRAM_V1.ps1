param(
  [string]$DecisionPath = "self_build_batch/decision_kernel/PHASE165E_DYNAMIC_GAP_DECISION_V1.json",
  [string]$SelectedPath = "self_build_batch/owner_material_inputs/selected/SELECTED_OWNER_MATERIAL_INPUT.json",
  [string]$IdentityPath = "self_build_programs/identity/SELF_BUILD_PROGRAM_IDENTITY_EXAMPLE_V1.json",
  [string]$LineagePath = "self_build_programs/lineage/SELF_BUILD_CAUSE_LINEAGE_EXAMPLE_V1.json",
  [string]$OutputDir = "self_build_programs/generated"
)

$ErrorActionPreference = "Stop"

$Decision = Get-Content $DecisionPath -Raw | ConvertFrom-Json
$Selected = Get-Content $SelectedPath -Raw | ConvertFrom-Json
$Identity = Get-Content $IdentityPath -Raw | ConvertFrom-Json
$Lineage = Get-Content $LineagePath -Raw | ConvertFrom-Json

$ProgramId = [string]$Identity.program_id
$DecisionProgramId = [string]$Decision.program_id
$SelectedMaterialId = [string]$Selected.selected_material_id
$IdentityMaterialId = [string]$Identity.source_material_id
$LineageId = [string]$Lineage.lineage_id
$LineageMaterialId = [string]$Lineage.owner_material.selected_material_id

if ([string]::IsNullOrWhiteSpace($ProgramId)) { throw "program_id is empty" }
if ($ProgramId -eq "SELF_BUILD_PROGRAM_001") { throw "program_id is still fixed SELF_BUILD_PROGRAM_001" }
if ($DecisionProgramId -ne $ProgramId) { throw "decision program_id does not match identity program_id" }
if ($SelectedMaterialId -ne $IdentityMaterialId) { throw "selected material does not match identity source material" }
if ($LineageMaterialId -ne $SelectedMaterialId) { throw "lineage material does not match selected material" }
if ([string]$Decision.selected_next_step -ne "PHASE165F_PATCH_PROGRAM_GENERATOR_FOR_DYNAMIC_SELF_BUILD_PROGRAMS") { throw "decision does not target PHASE165F" }
if ([bool]$Decision.evidence_ready -ne $true) { throw "decision evidence_ready is not true" }
if ([bool]$Decision.not_atom -ne $true) { throw "decision not_atom is not true" }
if ([bool]$Decision.lineage_required -ne $true) { throw "decision lineage_required is not true" }

$OutputPath = Join-Path $OutputDir ($ProgramId + ".json")

$DynamicProgram = [pscustomobject]@{
  schema_version = "dynamic_self_build_program_candidate_v1"
  phase = "PHASE88"
  generated_by = "GENERATE_DYNAMIC_SELF_BUILD_PROGRAM_V1"
  created_utc = (Get-Date).ToUniversalTime().ToString("o")
  program_id = $ProgramId
  status = "GENERATED_CANDIDATE"
  admission_required = $true
  admission_performed = $false
  execution_performed = $false
  source = [pscustomobject]@{
    selected_material_id = $SelectedMaterialId
    source_material_id = $IdentityMaterialId
    selected_source_file = [string]$Selected.selected_source_file
    selector = [string]$Selected.selector
    decision_id = [string]$Decision.decision_id
    decision_path = $DecisionPath
    identity_path = $IdentityPath
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
  }
  dynamic_generation = [pscustomobject]@{
    fixed_self_build_program_001_used = $false
    generated_from_selected_material = $true
    generated_from_dynamic_identity = $true
    generated_from_lineage = $true
    next_required_step = "PHASE165G_PATCH_ADMISSION_FOR_DYNAMIC_PROGRAMS"
  }
  safety = [pscustomobject]@{
    no_admission = $true
    no_execution = $true
    no_external_agent_production = $true
    no_external_fetch_or_install = $true
    no_protected_state_mutation = $true
  }
  owner_material = $Selected.selected_candidate.owner_material
}

$DynamicProgram | ConvertTo-Json -Depth 60 | Set-Content -Encoding UTF8 -Path $OutputPath
$DynamicProgram | ConvertTo-Json -Depth 60
