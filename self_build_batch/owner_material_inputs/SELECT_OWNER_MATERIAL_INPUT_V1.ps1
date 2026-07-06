param(
  [string]$InboxDir = "self_build_batch/owner_material_inputs/inbox",
  [string]$SelectedPath = "self_build_batch/owner_material_inputs/selected/SELECTED_OWNER_MATERIAL_INPUT.json",
  [switch]$ApplyActive,
  [string]$ActivePath = "self_build_batch/owner_material_inputs/ACTIVE_OWNER_MATERIAL_INPUT.json"
)

$ErrorActionPreference = "Stop"

$CandidateFiles = @(Get-ChildItem -Path $InboxDir -Filter "*.json" -File | Sort-Object Name)

$CandidateRows = @()
foreach ($File in $CandidateFiles) {
  $Obj = Get-Content $File.FullName -Raw | ConvertFrom-Json
  $Status = if ($Obj.PSObject.Properties.Name -contains "status") { [string]$Obj.status } else { "READY" }
  $Priority = if ($Obj.PSObject.Properties.Name -contains "priority") { [int]$Obj.priority } else { 0 }
  $MaterialId = if ($Obj.PSObject.Properties.Name -contains "material_id") { [string]$Obj.material_id } else { [IO.Path]::GetFileNameWithoutExtension($File.Name) }

  if ($Status -eq "READY") {
    $CandidateRows += [pscustomobject]@{
      file_name = $File.Name
      material_id = $MaterialId
      priority = $Priority
      status = $Status
      object = $Obj
    }
  }
}

if ($CandidateRows.Count -lt 1) {
  throw "No READY owner material candidates found in inbox."
}

$Chosen = @($CandidateRows | Sort-Object @{Expression="priority";Descending=$true}, @{Expression="file_name";Descending=$false})[0]

$Envelope = [pscustomobject]@{
  schema_version = "selected_owner_material_input_v1"
  selected_utc = (Get-Date).ToUniversalTime().ToString("o")
  selector = "SELECT_OWNER_MATERIAL_INPUT_V1"
  selection_mode = "governed_inbox_priority"
  selected_material_id = $Chosen.material_id
  selected_source_file = $Chosen.file_name
  candidate_count = [int]$CandidateRows.Count
  not_atom = $true
  required_path = "PHASE87->PHASE88->PHASE89->PHASE90"
  apply_active_requested = [bool]$ApplyActive
  selected_candidate = $Chosen.object
}

$Envelope | ConvertTo-Json -Depth 40 | Set-Content -Encoding UTF8 -Path $SelectedPath

if ($ApplyActive) {
  $Envelope | ConvertTo-Json -Depth 40 | Set-Content -Encoding UTF8 -Path $ActivePath
}

$Envelope | ConvertTo-Json -Depth 40
