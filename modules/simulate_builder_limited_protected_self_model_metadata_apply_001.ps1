param(
  [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path,
  [string]$CandidateRoot = 'reports/self_development/protected_state_update_candidates'
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

function ConvertTo-StableJson {
  param($Value)
  return ($Value | ConvertTo-Json -Depth 100 -Compress)
}

$root = (Resolve-Path $RepoRoot).Path
$candidateFull = Join-Path $root $CandidateRoot
$simulationDir = Join-Path $candidateFull 'phase161g1_simulation'
if (-not (Test-Path -LiteralPath $simulationDir)) {
  New-Item -ItemType Directory -Path $simulationDir | Out-Null
}

$genesisPath = Join-Path $root 'GENESIS_STATE.json'
$roadmapPath = Join-Path $root 'CAPABILITY_ROADMAP.json'
$genesisCandidatePath = Join-Path $candidateFull 'GENESIS_STATE_update_candidate.json'
$roadmapCandidatePath = Join-Path $candidateFull 'CAPABILITY_ROADMAP_update_candidate.json'

$beforeHashes = @{
  'GENESIS_STATE.json' = (Get-FileHash -LiteralPath $genesisPath -Algorithm SHA256).Hash
  'CAPABILITY_ROADMAP.json' = (Get-FileHash -LiteralPath $roadmapPath -Algorithm SHA256).Hash
}

$errors = New-Object System.Collections.Generic.List[string]
$genesis = Get-Content -LiteralPath $genesisPath -Raw | ConvertFrom-Json
$roadmap = Get-Content -LiteralPath $roadmapPath -Raw | ConvertFrom-Json
$genesisCandidate = Get-Content -LiteralPath $genesisCandidatePath -Raw | ConvertFrom-Json
$roadmapCandidate = Get-Content -LiteralPath $roadmapCandidatePath -Raw | ConvertFrom-Json

$genesisBefore = $genesis | ConvertTo-Json -Depth 100 | ConvertFrom-Json
$roadmapBefore = $roadmap | ConvertTo-Json -Depth 100 | ConvertFrom-Json
$genesisSim = $genesis | ConvertTo-Json -Depth 100 | ConvertFrom-Json
$roadmapSim = $roadmap | ConvertTo-Json -Depth 100 | ConvertFrom-Json

$genesisSection = $genesisCandidate.proposed_fields_or_sections.protected_self_model_memory
$roadmapSection = $roadmapCandidate.proposed_fields_or_sections.phase161e_self_map_auto_refresh
$genesisSim | Add-Member -NotePropertyName 'protected_self_model_memory' -NotePropertyValue $genesisSection -Force
$roadmapSim | Add-Member -NotePropertyName 'phase161e_self_map_auto_refresh' -NotePropertyValue $roadmapSection -Force

$genesisSimPath = Join-Path $simulationDir 'GENESIS_STATE.simulated.json'
$roadmapSimPath = Join-Path $simulationDir 'CAPABILITY_ROADMAP.simulated.json'
$genesisSim | ConvertTo-Json -Depth 100 | Set-Content -LiteralPath $genesisSimPath -Encoding UTF8
$roadmapSim | ConvertTo-Json -Depth 100 | Set-Content -LiteralPath $roadmapSimPath -Encoding UTF8

$genesisParsePass = $true
$roadmapParsePass = $true
try { Get-Content -LiteralPath $genesisSimPath -Raw | ConvertFrom-Json | Out-Null } catch { $genesisParsePass = $false; $errors.Add($_.Exception.Message) }
try { Get-Content -LiteralPath $roadmapSimPath -Raw | ConvertFrom-Json | Out-Null } catch { $roadmapParsePass = $false; $errors.Add($_.Exception.Message) }

$genesisExistingUnchanged = $true
foreach ($property in $genesisBefore.PSObject.Properties) {
  if ((ConvertTo-StableJson $property.Value) -ne (ConvertTo-StableJson $genesisSim.($property.Name))) {
    $genesisExistingUnchanged = $false
    $errors.Add("GENESIS_STATE existing field changed: $($property.Name)")
  }
}

$roadmapExistingUnchanged = $true
foreach ($property in $roadmapBefore.PSObject.Properties) {
  if ((ConvertTo-StableJson $property.Value) -ne (ConvertTo-StableJson $roadmapSim.($property.Name))) {
    $roadmapExistingUnchanged = $false
    $errors.Add("CAPABILITY_ROADMAP existing field changed: $($property.Name)")
  }
}

$currentPhaseUnchanged = (ConvertTo-StableJson $genesisBefore.current_phase) -eq (ConvertTo-StableJson $genesisSim.current_phase)
$currentCapabilityUnchanged = (ConvertTo-StableJson $genesisBefore.current_capability) -eq (ConvertTo-StableJson $genesisSim.current_capability)
$evidenceBoundaryPass = $genesisSim.protected_self_model_memory.evidence_boundary -eq 'DERIVED_MAP_REFERENCE_ONLY'
$roadmapStatusCautious = $roadmapSim.phase161e_self_map_auto_refresh.status -eq 'ACCEPTED_EVIDENCE_REFERENCE_CANDIDATE'
$promotionStatusCautious = $roadmapSim.phase161e_self_map_auto_refresh.protected_promotion_status -eq 'OWNER_REVIEW_REQUIRED'
$validatorOnlyNotPromoted = $evidenceBoundaryPass -and $roadmapStatusCautious -and $promotionStatusCautious

$afterHashes = @{
  'GENESIS_STATE.json' = (Get-FileHash -LiteralPath $genesisPath -Algorithm SHA256).Hash
  'CAPABILITY_ROADMAP.json' = (Get-FileHash -LiteralPath $roadmapPath -Algorithm SHA256).Hash
}
$protectedModified = $beforeHashes['GENESIS_STATE.json'] -ne $afterHashes['GENESIS_STATE.json'] -or $beforeHashes['CAPABILITY_ROADMAP.json'] -ne $afterHashes['CAPABILITY_ROADMAP.json']
if ($protectedModified) { $errors.Add('Protected file hash changed during simulation.') }

$errorArray = $errors.ToArray()
$result = [pscustomobject][ordered]@{
  simulation_status = $(if ($errorArray.Count -eq 0 -and $genesisParsePass -and $roadmapParsePass) { 'PASS' } else { 'FAIL' })
  protected_files_modified_directly = $protectedModified
  genesis_simulation_parse_pass = $genesisParsePass
  capability_roadmap_simulation_parse_pass = $roadmapParsePass
  genesis_existing_fields_unchanged = $genesisExistingUnchanged
  current_phase_unchanged = $currentPhaseUnchanged
  current_capability_unchanged = $currentCapabilityUnchanged
  readiness_and_status_claims_unchanged = $genesisExistingUnchanged
  roadmap_existing_entries_unchanged = $roadmapExistingUnchanged
  evidence_boundary_preserved = $evidenceBoundaryPass
  capability_candidate_status_cautious = $roadmapStatusCautious
  protected_promotion_status_cautious = $promotionStatusCautious
  validator_only_not_promoted_to_live = $validatorOnlyNotPromoted
  simulated_genesis_path = "$CandidateRoot/phase161g1_simulation/GENESIS_STATE.simulated.json"
  simulated_capability_roadmap_path = "$CandidateRoot/phase161g1_simulation/CAPABILITY_ROADMAP.simulated.json"
  owner_approval_required = $true
  validation_errors = $errorArray
  created_at = (Get-Date).ToUniversalTime().ToString('o')
}
$result | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath (Join-Path $candidateFull 'PHASE161G1_SIMULATED_APPLY_RESULT.json') -Encoding UTF8
$result
