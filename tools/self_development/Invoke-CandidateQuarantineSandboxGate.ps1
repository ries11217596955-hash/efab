param(
  [Parameter(Mandatory=$true)][string]$RepoRoot,
  [Parameter(Mandatory=$true)][string]$OutDir,
  [string]$InboxDir = "owner_orders/candidate_inbox",
  [string]$QuarantineDir = "owner_orders/candidate_quarantine",
  [string]$SandboxDir = "runtime_sessions/candidate_sandbox",
  [switch]$DryRun
)

$ErrorActionPreference = "Stop"

Set-Location -LiteralPath $RepoRoot
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
New-Item -ItemType Directory -Force -Path $QuarantineDir | Out-Null
New-Item -ItemType Directory -Force -Path $SandboxDir | Out-Null

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
  "proofs/self_development/PHASE164C_OWNER_CANDIDATE_INBOX_INTAKE_V1.json",
  "schemas/self_development/OWNER_CANDIDATE_INBOX_ITEM_SCHEMA_V1.json",
  "schemas/self_development/CANDIDATE_QUARANTINE_RECORD_SCHEMA_V1.json",
  "owner_orders/candidate_inbox/README.md",
  "owner_orders/candidate_quarantine/README.md"
)

$Missing = @()
foreach ($Path in $RequiredFiles) {
  if (-not (Test-Path -LiteralPath $Path)) { $Missing += $Path }
}

$Phase164CProof = Read-JsonFile -Path "proofs/self_development/PHASE164C_OWNER_CANDIDATE_INBOX_INTAKE_V1.json"
$Phase164CStatus = "UNKNOWN"
if ($null -ne $Phase164CProof -and ($Phase164CProof.PSObject.Properties.Name -contains "status")) {
  $Phase164CStatus = [string]$Phase164CProof.status
}

$CandidateFiles = @()
if (Test-Path -LiteralPath $InboxDir) {
  $CandidateFiles = @(Get-ChildItem -LiteralPath $InboxDir -Filter "*.candidate.json" -File)
}

$CandidateGateChecks = @()

foreach ($File in $CandidateFiles) {
  $Status = "QUARANTINE_READY"
  $CandidateId = $File.BaseName
  $Risk = "not_reviewed"
  $ReadError = $null

  try {
    $Json = Get-Content -LiteralPath $File.FullName -Raw | ConvertFrom-Json
    if ($Json.PSObject.Properties.Name -contains "candidate_id") {
      $CandidateId = [string]$Json.candidate_id
    }
    if ($Json.PSObject.Properties.Name -contains "risk_notes") {
      $Risk = [string]$Json.risk_notes
    }
  }
  catch {
    $Status = "INVALID_JSON"
    $ReadError = $_.Exception.Message
  }

  $CandidateGateChecks += [ordered]@{
    candidate_id = $CandidateId
    source_path = $File.FullName
    quarantine_status = $Status
    sandbox_status = "NOT_RUN"
    promotion_allowed = $false
    risk_notes = $Risk
    read_error = $ReadError
    mutation_mode = "none"
  }
}

$InvalidCandidateCount = @($CandidateGateChecks | Where-Object { $_.quarantine_status -ne "QUARANTINE_READY" }).Count
$QuarantineReadyCount = @($CandidateGateChecks | Where-Object { $_.quarantine_status -eq "QUARANTINE_READY" }).Count

$ValidationPass = (
  $DryRun.IsPresent -and
  $Missing.Count -eq 0 -and
  $Phase164CStatus -eq "PASS" -and
  $InvalidCandidateCount -eq 0
)

$GateStatus = if ($ValidationPass) { "PASS" } else { "FAIL" }

$ManifestPath = Join-Path $OutDir "candidate_quarantine_sandbox_gate_manifest.json"
$ValidationPath = Join-Path $OutDir "candidate_quarantine_sandbox_gate_validation.json"
$ReportPath = Join-Path $OutDir "CANDIDATE_QUARANTINE_SANDBOX_GATE_REPORT.md"

$Manifest = [ordered]@{
  schema = "CANDIDATE_QUARANTINE_SANDBOX_GATE_MANIFEST_V1"
  created_at = (Get-Date).ToUniversalTime().ToString("o")
  mode = "DRY_RUN_NO_PROMOTION_NO_SANDBOX_EXECUTION"
  inbox_dir = $InboxDir
  quarantine_dir = $QuarantineDir
  sandbox_dir = $SandboxDir
  required_files_missing = $Missing
  candidate_file_count = $CandidateFiles.Count
  quarantine_ready_count = $QuarantineReadyCount
  invalid_candidate_count = $InvalidCandidateCount
  candidate_gate_checks = $CandidateGateChecks
  phase164c_status = $Phase164CStatus
  accepted_core_mutation = $false
  route_lock_mutation = $false
  codex_execution = $false
  promotion_performed = $false
}

$Validation = [ordered]@{
  schema = "CANDIDATE_QUARANTINE_SANDBOX_GATE_VALIDATION_V1"
  status = $GateStatus
  dry_run = $DryRun.IsPresent
  missing_required_count = $Missing.Count
  phase164c_status = $Phase164CStatus
  candidate_file_count = $CandidateFiles.Count
  quarantine_ready_count = $QuarantineReadyCount
  invalid_candidate_count = $InvalidCandidateCount
  accepted_core_mutation = $false
  route_lock_mutation = $false
  codex_execution = $false
  promotion_performed = $false
}

$Manifest | ConvertTo-Json -Depth 80 | Set-Content -LiteralPath $ManifestPath -Encoding UTF8
$Validation | ConvertTo-Json -Depth 80 | Set-Content -LiteralPath $ValidationPath -Encoding UTF8

@"
# Candidate Quarantine Sandbox Gate Report

Status: $GateStatus

Mode: DRY_RUN_NO_PROMOTION_NO_SANDBOX_EXECUTION

Checked:
- missing required count: $($Missing.Count)
- PHASE164C status: $Phase164CStatus
- candidate files: $($CandidateFiles.Count)
- quarantine ready candidates: $QuarantineReadyCount
- invalid candidates: $InvalidCandidateCount
- accepted core mutation: false
- route lock mutation: false
- Codex execution: false
- promotion performed: false

Meaning:
This organ creates the quarantine and sandbox gate after Owner Candidate Inbox.

Candidate still is not an atom.
Candidate can become an atom only after sandbox validation, proof, and explicit promotion.
"@ | Set-Content -LiteralPath $ReportPath -Encoding UTF8

[ordered]@{
  status = $GateStatus
  manifest_path = $ManifestPath
  validation_path = $ValidationPath
  report_path = $ReportPath
} | ConvertTo-Json -Depth 80
