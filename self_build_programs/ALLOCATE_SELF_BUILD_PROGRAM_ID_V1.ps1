param(
  [Parameter(Mandatory=$true)][string]$SelectedOwnerMaterialPath,
  [Parameter(Mandatory=$true)][string]$OutputPath,
  [string]$ContractPath = "self_build_programs/contracts/SELF_BUILD_PROGRAM_IDENTITY_CONTRACT_V1.json",
  [string]$Version = "V1",
  [string]$Sequence = "001"
)

$ErrorActionPreference = "Stop"

$Selected = Get-Content $SelectedOwnerMaterialPath -Raw | ConvertFrom-Json
$Contract = Get-Content $ContractPath -Raw | ConvertFrom-Json

$MaterialId = [string]$Selected.selected_material_id
if ([string]::IsNullOrWhiteSpace($MaterialId)) {
  throw "selected_material_id is empty"
}

$SafeMaterial = ($MaterialId.ToUpperInvariant() -replace "[^A-Z0-9]+","_").Trim("_")
if ([string]::IsNullOrWhiteSpace($SafeMaterial)) {
  throw "normalized material id is empty"
}

$ProgramId = "SELF_BUILD_PROGRAM_${SafeMaterial}_${Version}_${Sequence}"

if ($ProgramId.Length -gt [int]$Contract.id_rules.max_length) {
  $Hash = (Get-FileHash -Algorithm SHA256 -Path $SelectedOwnerMaterialPath).Hash.Substring(0,12)
  $ProgramId = "SELF_BUILD_PROGRAM_${Hash}_${Version}_${Sequence}"
}

if ($ProgramId -notmatch [string]$Contract.id_rules.allowed_pattern) {
  throw "program_id does not match contract pattern: $ProgramId"
}

$Identity = [pscustomobject]@{
  program_identity_schema = "self_build_program_identity_v1"
  program_id = $ProgramId
  source_material_id = $MaterialId
  source_material_selector = [string]$Selected.selector
  source_material_path = $SelectedOwnerMaterialPath
  selected_source_file = [string]$Selected.selected_source_file
  created_utc = (Get-Date).ToUniversalTime().ToString("o")
  required_path = [string]$Contract.required_path
  not_atom = [bool]$Contract.not_atom
  lineage_required = [bool]$Contract.lineage_required
}

$Identity | ConvertTo-Json -Depth 30 | Set-Content -Encoding UTF8 -Path $OutputPath
$Identity | ConvertTo-Json -Depth 30
