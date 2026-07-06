param(
  [string]$ContractPath = "self_build_programs/contracts/SELF_BUILD_CAUSE_LINEAGE_CONTRACT_V1.json",
  [string]$SelectedOwnerMaterialPath = "self_build_batch/owner_material_inputs/selected/SELECTED_OWNER_MATERIAL_INPUT.json",
  [string]$ProgramIdentityPath = "self_build_programs/identity/SELF_BUILD_PROGRAM_IDENTITY_EXAMPLE_V1.json",
  [string]$OutputPath = "self_build_programs/lineage/SELF_BUILD_CAUSE_LINEAGE_EXAMPLE_V1.json"
)

$ErrorActionPreference = "Stop"

$Contract = Get-Content $ContractPath -Raw | ConvertFrom-Json
$Selected = Get-Content $SelectedOwnerMaterialPath -Raw | ConvertFrom-Json
$Identity = Get-Content $ProgramIdentityPath -Raw | ConvertFrom-Json

$MaterialId = [string]$Selected.selected_material_id
$IdentityMaterialId = [string]$Identity.source_material_id
$ProgramId = [string]$Identity.program_id

if ([string]::IsNullOrWhiteSpace($MaterialId)) { throw "selected material id is empty" }
if ([string]::IsNullOrWhiteSpace($IdentityMaterialId)) { throw "identity source material id is empty" }
if ([string]::IsNullOrWhiteSpace($ProgramId)) { throw "program id is empty" }
if ($MaterialId -ne $IdentityMaterialId) { throw "material id mismatch between selected material and program identity" }

$LineageId = "LINEAGE_" + (($ProgramId.ToUpperInvariant() -replace "[^A-Z0-9]+","_").Trim("_"))

$Lineage = [pscustomobject]@{
  schema_version = "self_build_cause_lineage_v1"
  lineage_id = $LineageId
  created_utc = (Get-Date).ToUniversalTime().ToString("o")
  contract_path = $ContractPath
  required_chain = @($Contract.required_chain)
  required_path = [string]$Contract.required_path
  not_atom = [bool]$Contract.not_atom_required
  lineage_required = [bool]$Contract.lineage_required

  owner_material = [pscustomobject]@{
    status = "SELECTED"
    selected_material_id = $MaterialId
    selector = [string]$Selected.selector
    selected_source_file = [string]$Selected.selected_source_file
    selected_path = $SelectedOwnerMaterialPath
    not_atom = [bool]$Selected.not_atom
    required_path = [string]$Selected.required_path
  }

  decision = [pscustomobject]@{
    phase = "PHASE87"
    status = "PENDING_DYNAMIC_DECISION_PATCH"
    decision_id = $null
    decision_status = "PENDING"
    source_material_id = $MaterialId
    program_generation_allowed = $null
    evidence_refs = @()
  }

  program = [pscustomobject]@{
    phase = "PHASE88"
    status = "IDENTITY_ALLOCATED"
    program_id = $ProgramId
    program_identity_schema = [string]$Identity.program_identity_schema
    source_material_id = $IdentityMaterialId
    program_path = $null
    lineage_id = $LineageId
  }

  admission = [pscustomobject]@{
    phase = "PHASE89"
    status = "PENDING_DYNAMIC_ADMISSION_PATCH"
    admission_id = $null
    program_id = $ProgramId
    admission_status = "PENDING"
    no_execution_guarantee = $true
    lineage_preserved = $null
  }

  execution = [pscustomobject]@{
    phase = "PHASE90"
    status = "PENDING_DYNAMIC_EXECUTION_PATCH"
    execution_id = $null
    program_id = $ProgramId
    execution_status = "PENDING"
    execution_performed = $false
    controlled_runtime = $true
    lineage_preserved = $null
  }

  absorption = [pscustomobject]@{
    phase = "PHASE165K"
    status = "PENDING_ABSORPTION_DECISION_GATE"
    absorption_id = $null
    program_id = $ProgramId
    absorption_decision = "PENDING"
    allowed_decisions = @($Contract.allowed_absorption_decisions)
    memory_update_required = $true
  }

  invariants = [pscustomobject]@{
    material_to_identity_match = ($MaterialId -eq $IdentityMaterialId)
    program_id_dynamic = ($ProgramId -ne "SELF_BUILD_PROGRAM_001")
    required_path_preserved = ([string]$Contract.required_path -eq "PHASE87->PHASE88->PHASE89->PHASE90")
    not_atom_preserved = ([bool]$Selected.not_atom -eq $true)
    absorption_required = $true
  }
}

$Lineage | ConvertTo-Json -Depth 50 | Set-Content -Encoding UTF8 -Path $OutputPath
$Lineage | ConvertTo-Json -Depth 50
