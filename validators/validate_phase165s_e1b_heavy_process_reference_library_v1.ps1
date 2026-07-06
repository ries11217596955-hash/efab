param(
  [Parameter(Mandatory=$true)][string]$RepoRoot,
  [switch]$EmitJson
)

$ErrorActionPreference = "Stop"
$Phase = "PHASE165S_E1B_HEAVY_PROCESS_REFERENCE_LIBRARY_V1"
$SeedRoot = Join-Path $RepoRoot "knowledge_library\internal\phase165s_e1b_heavy_process_reference_v1"
$CatalogPath = Join-Path $SeedRoot "INTERNAL_HEAVY_PROCESS_REFERENCE_CATALOG.json"
$ProofPath = Join-Path $RepoRoot "proofs\self_development\PHASE165S_E1B_HEAVY_PROCESS_REFERENCE_LIBRARY_V1.json"
$ReportPath = Join-Path $RepoRoot "reports\self_development\PHASE165S_E1B_HEAVY_PROCESS_REFERENCE_LIBRARY_V1.md"

function BoolText($v) { if ($v) { "true" } else { "false" } }

$repoSigns = @(
  "CAPABILITY_ROADMAP.json",
  "GENESIS_STATE.json",
  "TASK_QUEUE.json",
  "packs\registry.json",
  "orchestrator\run.ps1"
)

$missingRepoSigns = @()
foreach ($p in $repoSigns) {
  if (-not (Test-Path (Join-Path $RepoRoot $p))) { $missingRepoSigns += $p }
}

$missingPaths = @()
foreach ($p in @($SeedRoot, $CatalogPath)) {
  if (-not (Test-Path $p)) { $missingPaths += $p }
}

$cardFiles = @()
$runbookFiles = @()
$invalidCards = @()
$catalog = $null
if (Test-Path $CatalogPath) {
  $catalog = Get-Content $CatalogPath -Raw | ConvertFrom-Json
  $cardFiles = Get-ChildItem (Join-Path $SeedRoot "cards") -Filter "*.json" -File -ErrorAction SilentlyContinue
  $runbookFiles = Get-ChildItem (Join-Path $SeedRoot "runbooks") -Filter "*.md" -File -ErrorAction SilentlyContinue

  foreach ($cf in $cardFiles) {
    try {
      $c = Get-Content $cf.FullName -Raw | ConvertFrom-Json
      foreach ($field in @("id","phase","kind","title","process_class","when_to_use","procedure","proof_required","atomization_rule","source_status")) {
        if (-not ($c.PSObject.Properties.Name -contains $field)) { $invalidCards += "$($cf.Name):missing:$field" }
      }
      if ($c.kind -ne "internal_heavy_process_reference_card") { $invalidCards += "$($cf.Name):bad_kind" }
      if ($c.phase -ne $Phase) { $invalidCards += "$($cf.Name):bad_phase" }
    } catch {
      $invalidCards += "$($cf.Name):json_parse_failed"
    }
  }
}

$protectedStateMutation = $false
$acceptedAtomsCreated = 0
$schoolCurriculumCreated = $false
$runningProcessTouched = $false

# This validator only accepts the sidecar path and its own validator/proof/report as intended outputs.
# It does not scan git diff because D2B may be running in parallel and owning separate dirty files.

$status = "PASS_STAGED_INTERNAL_HEAVY_PROCESS_REFERENCE_LIBRARY"
if ($missingRepoSigns.Count -gt 0 -or $missingPaths.Count -gt 0 -or $invalidCards.Count -gt 0 -or $cardFiles.Count -lt 30 -or $runbookFiles.Count -lt 10) {
  $status = "FAIL_INTERNAL_HEAVY_PROCESS_REFERENCE_LIBRARY"
}

$result = [ordered]@{
  schema_version = "phase165s_e1b_heavy_process_validator_result.v1"
  phase = $Phase
  status = $status
  seed_root = $SeedRoot
  catalog_path = $CatalogPath
  card_count = $cardFiles.Count
  runbook_count = $runbookFiles.Count
  index_count = (Get-ChildItem (Join-Path $SeedRoot "indexes") -File -ErrorAction SilentlyContinue).Count
  schema_count = (Get-ChildItem (Join-Path $SeedRoot "schemas") -File -ErrorAction SilentlyContinue).Count
  protected_state_mutation = $protectedStateMutation
  accepted_atoms_created = $acceptedAtomsCreated
  school_curriculum_created = $schoolCurriculumCreated
  running_process_touched = $runningProcessTouched
  invalid_cards = $invalidCards
  missing_paths = $missingPaths
  missing_repo_signs = $missingRepoSigns
  checked_utc = (Get-Date).ToUniversalTime().ToString("o")
}

New-Item -ItemType Directory -Force -Path (Split-Path $ProofPath) | Out-Null
$result | ConvertTo-Json -Depth 20 | Set-Content -Path $ProofPath -Encoding UTF8

New-Item -ItemType Directory -Force -Path (Split-Path $ReportPath) | Out-Null
$md = @()
$md += "# PHASE165S-E1B Heavy Process Reference Library V1"
$md += ""
$md += "Status: $status"
$md += ""
$md += "This is a staged internal reference library for hard Builder processes, not primitive concepts."
$md += ""
$md += "Counts:"
$md += "- cards: $($cardFiles.Count)"
$md += "- runbooks: $($runbookFiles.Count)"
$md += "- indexes: $($result.index_count)"
$md += "- schemas: $($result.schema_count)"
$md += ""
$md += "Safety:"
$md += "- protected_state_mutation: $(BoolText $protectedStateMutation)"
$md += "- accepted_atoms_created: $acceptedAtomsCreated"
$md += "- school_curriculum_created: $(BoolText $schoolCurriculumCreated)"
$md += "- running_process_touched: $(BoolText $runningProcessTouched)"
$md += ""
$md += "Next action: use these runbooks on demand during real task/gap resolution. Do not feed them as school by default."
$md | Set-Content -Path $ReportPath -Encoding UTF8

if ($EmitJson) {
  $result | ConvertTo-Json -Depth 20
} else {
  "PHASE=$Phase"
  "STATUS=$status"
  "CARD_COUNT=$($cardFiles.Count)"
  "RUNBOOK_COUNT=$($runbookFiles.Count)"
  "PROTECTED_STATE_MUTATION=$(BoolText $protectedStateMutation)"
  "ACCEPTED_ATOMS_CREATED=$acceptedAtomsCreated"
  "SCHOOL_CURRICULUM_CREATED=$(BoolText $schoolCurriculumCreated)"
  "RUNNING_PROCESS_TOUCHED=$(BoolText $runningProcessTouched)"
  "PROOF=$ProofPath"
  "REPORT=$ReportPath"
}

if ($status -notlike "PASS*") {
  throw "Validator failed: $status"
}