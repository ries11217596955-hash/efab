param(
  [string]$RepoRoot = "."
)

$ErrorActionPreference = "Stop"
$SeedRoot = Join-Path $RepoRoot "knowledge_library/internal/phase165s_e1b_seed"
$CatalogPath = Join-Path $SeedRoot "INTERNAL_REFERENCE_LIBRARY_CATALOG.json"
$ProofDir = Join-Path $RepoRoot "proofs/self_development"
$ReportDir = Join-Path $RepoRoot "reports/self_development"
New-Item -ItemType Directory -Force -Path $ProofDir, $ReportDir | Out-Null

$result = [ordered]@{
  schema_version = "phase165s_e1b_validator_result.v1"
  phase = "PHASE165S-E1B_INTERNAL_REFERENCE_LIBRARY_SEED"
  status = "UNKNOWN"
  seed_root = $SeedRoot
  catalog_path = $CatalogPath
  protected_state_mutation = $false
  accepted_atoms_created = 0
  school_curriculum_created = $false
  card_count = 0
  invalid_cards = @()
  missing_paths = @()
  checked_utc = (Get-Date).ToUniversalTime().ToString("o")
}

$requiredPaths = @(
  $SeedRoot,
  $CatalogPath,
  (Join-Path $SeedRoot "cards"),
  (Join-Path $SeedRoot "runbooks"),
  (Join-Path $SeedRoot "schemas/internal_reference_card.schema.json")
)

foreach ($p in $requiredPaths) {
  if (-not (Test-Path $p)) { $result.missing_paths += $p }
}

if ($result.missing_paths.Count -eq 0) {
  $catalog = Get-Content $CatalogPath -Raw | ConvertFrom-Json
  $cards = Get-ChildItem (Join-Path $SeedRoot "cards") -Filter "*.json" -File
  $result.card_count = @($cards).Count

  foreach ($cardFile in $cards) {
    try {
      $card = Get-Content $cardFile.FullName -Raw | ConvertFrom-Json
      $bad = @()
      if ($card.schema_version -ne "internal_reference_card.v1") { $bad += "schema_version" }
      if ($card.status -ne "INTERNAL_REFERENCE") { $bad += "status" }
      if ($card.trusted -ne $false) { $bad += "trusted_must_be_false" }
      if ($card.accepted_atom -ne $false) { $bad += "accepted_atom_must_be_false" }
      if ($card.creates_atom_only_after_gap_solved -ne $true) { $bad += "gap_solved_gate_missing" }
      if ([string]::IsNullOrWhiteSpace($card.reference_id)) { $bad += "reference_id" }
      if ([string]::IsNullOrWhiteSpace($card.domain)) { $bad += "domain" }
      if ([string]::IsNullOrWhiteSpace($card.answer)) { $bad += "answer" }
      if ($bad.Count -gt 0) {
        $result.invalid_cards += [ordered]@{ path = $cardFile.FullName; issues = $bad }
      }
    } catch {
      $result.invalid_cards += [ordered]@{ path = $cardFile.FullName; issues = @("json_parse_error", $_.Exception.Message) }
    }
  }

  if ($result.card_count -lt 18) {
    $result.invalid_cards += [ordered]@{ path = "cards"; issues = @("expected_at_least_18_cards") }
  }
}

if ($result.missing_paths.Count -eq 0 -and $result.invalid_cards.Count -eq 0) {
  $result.status = "PASS_STAGED_INTERNAL_REFERENCE_LIBRARY_SEED"
} else {
  $result.status = "FAIL_INTERNAL_REFERENCE_LIBRARY_SEED"
}

$ProofPath = Join-Path $ProofDir "PHASE165S_E1B_INTERNAL_REFERENCE_LIBRARY_SEED_V1.json"
$ReportPath = Join-Path $ReportDir "PHASE165S_E1B_INTERNAL_REFERENCE_LIBRARY_SEED_V1.md"

$result | ConvertTo-Json -Depth 8 | Set-Content -Path $ProofPath -Encoding UTF8

$report = @"
# PHASE165S-E1B Internal Reference Library Seed

machine_decision=$($result.status)

## Counts
- card_count=$($result.card_count)
- missing_paths=$($result.missing_paths.Count)
- invalid_cards=$($result.invalid_cards.Count)
- accepted_atoms_created=0
- protected_state_mutation=False
- school_curriculum_created=False

## Paths
- seed_root=$SeedRoot
- catalog=$CatalogPath
- proof=$ProofPath
- report=$ReportPath

## Safety
This seed creates staged internal references only. It does not create accepted atoms and does not mutate protected state.
"@
$report | Set-Content -Path $ReportPath -Encoding UTF8

$result | ConvertTo-Json -Depth 8
if ($result.status -like "PASS*") {
  Write-Host "STOP=NONE"
  exit 0
} else {
  Write-Host "STOP=VALIDATION_FAILED"
  exit 1
}
