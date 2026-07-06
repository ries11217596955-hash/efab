param(
  [Parameter(Mandatory=$true)][string]$RepoRoot,
  [Parameter(Mandatory=$true)][string]$OutDir,
  [string]$InboxDir = "owner_orders/candidate_inbox",
  [switch]$DryRun
)

$ErrorActionPreference = "Stop"

Set-Location -LiteralPath $RepoRoot
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null

function Read-JsonFile {
  param([Parameter(Mandatory=$true)][string]$Path)
  if (-not (Test-Path -LiteralPath $Path)) { return $null }
  return (Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json)
}

$RequiredFiles = @(
  "README.md",
  "AGENTS.md",
  "CAPABILITY_ROADMAP.json",
  "GENESIS_STATE.json",
  "TASK_QUEUE.json",
  "packs/registry.json",
  "orchestrator/run.ps1",
  "proofs/self_development/PHASE164B_ACCEPTED_ATOM_BATCH_REPLAY_ORCHESTRATOR_V1.json",
  "schemas/self_development/OWNER_CANDIDATE_INBOX_ITEM_SCHEMA_V1.json",
  "owner_orders/candidate_inbox/README.md"
)

$Missing = @()
foreach ($Path in $RequiredFiles) {
  if (-not (Test-Path -LiteralPath $Path)) { $Missing += $Path }
}

$Phase164BProof = Read-JsonFile -Path "proofs/self_development/PHASE164B_ACCEPTED_ATOM_BATCH_REPLAY_ORCHESTRATOR_V1.json"
$Phase164BStatus = "UNKNOWN"
if ($null -ne $Phase164BProof -and ($Phase164BProof.PSObject.Properties.Name -contains "status")) {
  $Phase164BStatus = [string]$Phase164BProof.status
}

$RequiredCandidateFields = @(
  "candidate_id",
  "title",
  "source_type",
  "provenance",
  "intended_capability",
  "risk_notes",
  "acceptance_expectation"
)

$CandidateFiles = @()
if (Test-Path -LiteralPath $InboxDir) {
  $CandidateFiles = @(Get-ChildItem -LiteralPath $InboxDir -Filter "*.candidate.json" -File)
}

$CandidateChecks = @()
foreach ($File in $CandidateFiles) {
  $CandidateStatus = "READY_FOR_QUARANTINE_REVIEW"
  $MissingFields = @()
  $ReadError = $null

  try {
    $Json = Get-Content -LiteralPath $File.FullName -Raw | ConvertFrom-Json

    foreach ($Field in $RequiredCandidateFields) {
      if (-not ($Json.PSObject.Properties.Name -contains $Field)) {
        $MissingFields += $Field
      }
    }

    if ($MissingFields.Count -gt 0) {
      $CandidateStatus = "INVALID_SHAPE"
    }
  }
  catch {
    $CandidateStatus = "INVALID_JSON"
    $ReadError = $_.Exception.Message
  }

  $CandidateChecks += [ordered]@{
    path = $File.FullName
    name = $File.Name
    status = $CandidateStatus
    missing_fields = $MissingFields
    read_error = $ReadError
    mutation_mode = "none"
  }
}

$InvalidCandidateCount = @($CandidateChecks | Where-Object { $_.status -ne "READY_FOR_QUARANTINE_REVIEW" }).Count
$ReadyCandidateCount = @($CandidateChecks | Where-Object { $_.status -eq "READY_FOR_QUARANTINE_REVIEW" }).Count

$ValidationPass = (
  $DryRun.IsPresent -and
  $Missing.Count -eq 0 -and
  $Phase164BStatus -eq "PASS" -and
  $InvalidCandidateCount -eq 0
)

$Status = if ($ValidationPass) { "PASS" } else { "FAIL" }

$ManifestPath = Join-Path $OutDir "owner_candidate_inbox_intake_manifest.json"
$ValidationPath = Join-Path $OutDir "owner_candidate_inbox_intake_validation.json"
$ReportPath = Join-Path $OutDir "OWNER_CANDIDATE_INBOX_INTAKE_REPORT.md"

$Manifest = [ordered]@{
  schema = "OWNER_CANDIDATE_INBOX_INTAKE_MANIFEST_V1"
  created_at = (Get-Date).ToUniversalTime().ToString("o")
  mode = "DRY_RUN_NO_PROMOTION"
  inbox_dir = $InboxDir
  required_files_missing = $Missing
  candidate_file_count = $CandidateFiles.Count
  ready_candidate_count = $ReadyCandidateCount
  invalid_candidate_count = $InvalidCandidateCount
  candidate_checks = $CandidateChecks
  phase164b_status = $Phase164BStatus
  accepted_core_mutation = $false
  route_lock_mutation = $false
  codex_execution = $false
  promotion_performed = $false
}

$Validation = [ordered]@{
  schema = "OWNER_CANDIDATE_INBOX_INTAKE_VALIDATION_V1"
  status = $Status
  dry_run = $DryRun.IsPresent
  missing_required_count = $Missing.Count
  phase164b_status = $Phase164BStatus
  candidate_file_count = $CandidateFiles.Count
  ready_candidate_count = $ReadyCandidateCount
  invalid_candidate_count = $InvalidCandidateCount
  accepted_core_mutation = $false
  route_lock_mutation = $false
  codex_execution = $false
  promotion_performed = $false
}

$Manifest | ConvertTo-Json -Depth 80 | Set-Content -LiteralPath $ManifestPath -Encoding UTF8
$Validation | ConvertTo-Json -Depth 80 | Set-Content -LiteralPath $ValidationPath -Encoding UTF8

@"
# Owner Candidate Inbox Intake Report

Status: $Status

Mode: DRY_RUN_NO_PROMOTION

Checked:
- missing required count: $($Missing.Count)
- PHASE164B status: $Phase164BStatus
- candidate files: $($CandidateFiles.Count)
- ready candidates: $ReadyCandidateCount
- invalid candidates: $InvalidCandidateCount
- accepted core mutation: false
- route lock mutation: false
- Codex execution: false
- promotion performed: false

Meaning:
This organ creates the controlled input gate for owner-supplied candidates.

Candidate is not an atom.
Candidate can become an atom only after quarantine, sandbox, validation, proof, and explicit promotion.

Next:
Connect quarantine/sandbox promotion logic after Owner approval.
"@ | Set-Content -LiteralPath $ReportPath -Encoding UTF8

[ordered]@{
  status = $Status
  manifest_path = $ManifestPath
  validation_path = $ValidationPath
  report_path = $ReportPath
} | ConvertTo-Json -Depth 80
