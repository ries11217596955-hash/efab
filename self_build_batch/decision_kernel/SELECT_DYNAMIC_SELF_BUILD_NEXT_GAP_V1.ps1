param(
  [string]$SelectedPath = "self_build_batch/owner_material_inputs/selected/SELECTED_OWNER_MATERIAL_INPUT.json",
  [string]$IdentityPath = "self_build_programs/identity/SELF_BUILD_PROGRAM_IDENTITY_EXAMPLE_V1.json",
  [string]$LineagePath = "self_build_programs/lineage/SELF_BUILD_CAUSE_LINEAGE_EXAMPLE_V1.json",
  [string]$OutputPath = "self_build_batch/decision_kernel/PHASE165E_DYNAMIC_GAP_DECISION_V1.json"
)

$ErrorActionPreference = "Stop"

$SelectedExists = Test-Path $SelectedPath
$IdentityExists = Test-Path $IdentityPath
$LineageExists = Test-Path $LineagePath

$Selected = if ($SelectedExists) { Get-Content $SelectedPath -Raw | ConvertFrom-Json } else { $null }
$Identity = if ($IdentityExists) { Get-Content $IdentityPath -Raw | ConvertFrom-Json } else { $null }
$Lineage = if ($LineageExists) { Get-Content $LineagePath -Raw | ConvertFrom-Json } else { $null }

$SelectedMaterialId = if ($Selected) { [string]$Selected.selected_material_id } else { "" }
$IdentityMaterialId = if ($Identity) { [string]$Identity.source_material_id } else { "" }
$ProgramId = if ($Identity) { [string]$Identity.program_id } else { "" }
$LineageId = if ($Lineage) { [string]$Lineage.lineage_id } else { "" }

$LineageOwnerMaterialId = ""
$LineageProgramMaterialId = ""

if ($Lineage -and ($Lineage.PSObject.Properties.Name -contains "owner_material")) {
  $LineageOwnerMaterialId = [string]$Lineage.owner_material.selected_material_id
}
elseif ($Lineage -and ($Lineage.PSObject.Properties.Name -contains "selected_material_id")) {
  $LineageOwnerMaterialId = [string]$Lineage.selected_material_id
}

if ($Lineage -and ($Lineage.PSObject.Properties.Name -contains "program")) {
  $LineageProgramMaterialId = [string]$Lineage.program.source_material_id
}

$MaterialToIdentityMatch = (
  -not [string]::IsNullOrWhiteSpace($SelectedMaterialId) -and
  -not [string]::IsNullOrWhiteSpace($IdentityMaterialId) -and
  $SelectedMaterialId -eq $IdentityMaterialId
)

$LineageMaterialMatch = (
  -not [string]::IsNullOrWhiteSpace($LineageOwnerMaterialId) -and
  $LineageOwnerMaterialId -eq $SelectedMaterialId -and
  (
    [string]::IsNullOrWhiteSpace($LineageProgramMaterialId) -or
    $LineageProgramMaterialId -eq $IdentityMaterialId
  )
)

$ProgramIdDynamic = (
  -not [string]::IsNullOrWhiteSpace($ProgramId) -and
  $ProgramId -ne "SELF_BUILD_PROGRAM_001"
)

$RequiredPathPreserved = (
  $Selected -ne $null -and
  $Identity -ne $null -and
  $Lineage -ne $null -and
  [string]$Selected.required_path -eq "PHASE87->PHASE88->PHASE89->PHASE90" -and
  [string]$Identity.required_path -eq "PHASE87->PHASE88->PHASE89->PHASE90" -and
  [string]$Lineage.required_path -eq "PHASE87->PHASE88->PHASE89->PHASE90"
)

$EvidenceReady = (
  $SelectedExists -and
  $IdentityExists -and
  $LineageExists -and
  $MaterialToIdentityMatch -and
  $LineageMaterialMatch -and
  $ProgramIdDynamic -and
  $RequiredPathPreserved
)

if (-not $SelectedExists) {
  $NextGap = "PHASE165B_GENERALIZE_OWNER_MATERIAL_INPUT_SELECTION"
  $Reason = "Selected owner material is missing."
}
elseif (-not $IdentityExists) {
  $NextGap = "PHASE165C_GENERALIZE_SELF_BUILD_PROGRAM_IDENTITY"
  $Reason = "Dynamic self-build program identity is missing."
}
elseif (-not $LineageExists) {
  $NextGap = "PHASE165D_BUILD_SELF_BUILD_CAUSE_LINEAGE_CONTRACT"
  $Reason = "Cause lineage contract/example is missing."
}
elseif (-not $MaterialToIdentityMatch) {
  $NextGap = "PHASE165E_REPAIR_MATERIAL_IDENTITY_LINEAGE_MISMATCH"
  $Reason = "Selected material and program identity material id do not match."
}
elseif (-not $LineageMaterialMatch) {
  $NextGap = "PHASE165E_REPAIR_LINEAGE_MATERIAL_MATCH"
  $Reason = "Lineage material id does not match selected material."
}
elseif (-not $ProgramIdDynamic) {
  $NextGap = "PHASE165C_REPAIR_DYNAMIC_SELF_BUILD_PROGRAM_IDENTITY"
  $Reason = "Program id is missing or still fixed SELF_BUILD_PROGRAM_001."
}
elseif (-not $RequiredPathPreserved) {
  $NextGap = "PHASE165D_REPAIR_REQUIRED_PATH_LINEAGE"
  $Reason = "Required PHASE87->PHASE88->PHASE89->PHASE90 path is not preserved."
}
else {
  $NextGap = "PHASE165F_PATCH_PROGRAM_GENERATOR_FOR_DYNAMIC_SELF_BUILD_PROGRAMS"
  $Reason = "Selected owner material, dynamic program identity, and lineage are present and consistent."
}

$Decision = [pscustomobject]@{
  schema_version = "phase165e_dynamic_gap_decision_v1"
  phase = "PHASE165E_PATCH_DECISION_KERNEL_FOR_DYNAMIC_GAP_SELECTION"
  decision_id = "PHASE165E_DYNAMIC_GAP_DECISION_V1"
  created_utc = (Get-Date).ToUniversalTime().ToString("o")
  selector = "SELECT_DYNAMIC_SELF_BUILD_NEXT_GAP_V1"
  decision_mode = "evidence_backed_dynamic_gap_selection"
  selected_next_gap = $NextGap
  selected_next_step = $NextGap
  recommended_next_step = $NextGap
  selection_reason = $Reason
  evidence_ready = [bool]$EvidenceReady
  hardcoded_phase88_recommendation = $false
  previous_fixed_recommendation_replaced = "PHASE88_SELF_BUILD_PROGRAM_GENERATOR_V1"
  selected_material_id = $SelectedMaterialId
  source_material_id = $IdentityMaterialId
  lineage_owner_material_id = $LineageOwnerMaterialId
  lineage_program_source_material_id = $LineageProgramMaterialId
  program_id = $ProgramId
  lineage_id = $LineageId
  required_path = "PHASE87->PHASE88->PHASE89->PHASE90"
  not_atom = $true
  lineage_required = $true
  external_agent_production_allowed = $false
  canonical_phase88_execution_requested = $false
  canonical_phase89_execution_requested = $false
  canonical_phase90_execution_requested = $false
  evidence = [pscustomobject]@{
    selected_owner_material_exists = [bool]$SelectedExists
    program_identity_exists = [bool]$IdentityExists
    lineage_exists = [bool]$LineageExists
    material_to_identity_match = [bool]$MaterialToIdentityMatch
    lineage_material_match = [bool]$LineageMaterialMatch
    program_id_dynamic = [bool]$ProgramIdDynamic
    required_path_preserved = [bool]$RequiredPathPreserved
  }
}

$Decision | ConvertTo-Json -Depth 30 | Set-Content -Encoding UTF8 -Path $OutputPath
$Decision | ConvertTo-Json -Depth 30
