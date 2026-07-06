param(
  [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path,
  [string]$CandidateRoot = 'reports/self_development/protected_state_update_candidates'
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

function Add-BuilderTopLevelJsonProperty {
  param(
    [Parameter(Mandatory=$true)][string]$Path,
    [Parameter(Mandatory=$true)][string]$PropertyName,
    [Parameter(Mandatory=$true)]$Value
  )
  $raw = Get-Content -LiteralPath $Path -Raw
  $json = $raw | ConvertFrom-Json
  if ($json.PSObject.Properties.Name -contains $PropertyName) {
    throw "Property already exists: $PropertyName"
  }
  $trimmed = $raw.TrimEnd()
  if (-not $trimmed.EndsWith('}')) { throw "JSON root is not an object: $Path" }
  $withoutClose = $trimmed.Substring(0, $trimmed.Length - 1).TrimEnd()
  $valueJson = $Value | ConvertTo-Json -Depth 40
  $valueIndented = $valueJson -replace "`r?`n", "`r`n  "
  $updated = $withoutClose + ",`r`n  `"$PropertyName`": " + $valueIndented + "`r`n}`r`n"
  $updated | ConvertFrom-Json | Out-Null
  Set-Content -LiteralPath $Path -Value $updated -Encoding UTF8 -NoNewline
}

function Test-BuilderExistingPropertiesUnchanged {
  param($Before, $After)
  foreach ($property in $Before.PSObject.Properties) {
    $beforeJson = $property.Value | ConvertTo-Json -Depth 100 -Compress
    $afterJson = $After.($property.Name) | ConvertTo-Json -Depth 100 -Compress
    if ($beforeJson -ne $afterJson) { return $false }
  }
  return $true
}

$root = (Resolve-Path $RepoRoot).Path
$candidateFull = Join-Path $root $CandidateRoot
$snapshotFull = Join-Path $candidateFull 'rollback_snapshots/PHASE161G2'
$genesisPath = Join-Path $root 'GENESIS_STATE.json'
$roadmapPath = Join-Path $root 'CAPABILITY_ROADMAP.json'
$genesisSnapshot = Join-Path $snapshotFull 'GENESIS_STATE.json'
$roadmapSnapshot = Join-Path $snapshotFull 'CAPABILITY_ROADMAP.json'
if (-not (Test-Path -LiteralPath $genesisSnapshot) -or -not (Test-Path -LiteralPath $roadmapSnapshot)) {
  throw 'Rollback snapshots are missing.'
}

$genesisBefore = Get-Content -LiteralPath $genesisSnapshot -Raw | ConvertFrom-Json
$roadmapBefore = Get-Content -LiteralPath $roadmapSnapshot -Raw | ConvertFrom-Json
$genesisCandidate = Get-Content -LiteralPath (Join-Path $candidateFull 'GENESIS_STATE_update_candidate.json') -Raw | ConvertFrom-Json
$roadmapCandidate = Get-Content -LiteralPath (Join-Path $candidateFull 'CAPABILITY_ROADMAP_update_candidate.json') -Raw | ConvertFrom-Json
$scope = Get-Content -LiteralPath (Join-Path $candidateFull 'PHASE161G1_LIMITED_APPLY_SCOPE_RECOMMENDATION.json') -Raw | ConvertFrom-Json

if ($scope.decisions.genesis_state -ne 'APPROVE_WITH_LIMITS' -or $scope.decisions.capability_roadmap -ne 'APPROVE_WITH_LIMITS') {
  throw 'PHASE161G1 did not approve both limited targets.'
}
$genesisSection = $genesisCandidate.proposed_fields_or_sections.protected_self_model_memory
$roadmapSection = $roadmapCandidate.proposed_fields_or_sections.phase161e_self_map_auto_refresh
if ($genesisSection.evidence_boundary -ne 'DERIVED_MAP_REFERENCE_ONLY') { throw 'Unsafe GENESIS_STATE evidence boundary.' }
if ($roadmapSection.status -ne 'ACCEPTED_EVIDENCE_REFERENCE_CANDIDATE') { throw 'Unsafe roadmap candidate status.' }
if ($roadmapSection.protected_promotion_status -ne 'OWNER_REVIEW_REQUIRED') { throw 'Unsafe roadmap promotion status.' }

try {
  Add-BuilderTopLevelJsonProperty -Path $genesisPath -PropertyName 'protected_self_model_memory' -Value $genesisSection
  Add-BuilderTopLevelJsonProperty -Path $roadmapPath -PropertyName 'phase161e_self_map_auto_refresh' -Value $roadmapSection

  $genesisAfter = Get-Content -LiteralPath $genesisPath -Raw | ConvertFrom-Json
  $roadmapAfter = Get-Content -LiteralPath $roadmapPath -Raw | ConvertFrom-Json
  if (-not (Test-BuilderExistingPropertiesUnchanged -Before $genesisBefore -After $genesisAfter)) { throw 'Existing GENESIS_STATE fields changed.' }
  if (-not (Test-BuilderExistingPropertiesUnchanged -Before $roadmapBefore -After $roadmapAfter)) { throw 'Existing CAPABILITY_ROADMAP entries changed.' }
  if ($genesisAfter.current_phase -ne $genesisBefore.current_phase) { throw 'current_phase changed.' }
  if ($genesisAfter.current_capability -ne $genesisBefore.current_capability) { throw 'current_capability changed.' }

  $result = [pscustomobject][ordered]@{
    apply_status = 'PASS'
    genesis_state_reference_applied = $true
    capability_roadmap_reference_applied = $true
    applied_sections = @('GENESIS_STATE.json.protected_self_model_memory','CAPABILITY_ROADMAP.json.phase161e_self_map_auto_refresh')
    existing_genesis_fields_unchanged = $true
    current_phase_unchanged = $true
    current_capability_unchanged = $true
    existing_roadmap_entries_unchanged = $true
    validator_only_promoted_to_live = $false
    rollback_used = $false
    created_at = (Get-Date).ToUniversalTime().ToString('o')
  }
  $result | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath (Join-Path $candidateFull 'PHASE161G2_APPLY_RESULT.json') -Encoding UTF8
  $result
} catch {
  Copy-Item -LiteralPath $genesisSnapshot -Destination $genesisPath -Force
  Copy-Item -LiteralPath $roadmapSnapshot -Destination $roadmapPath -Force
  throw
}
