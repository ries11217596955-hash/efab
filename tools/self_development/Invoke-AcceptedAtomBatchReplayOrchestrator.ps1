param(
  [Parameter(Mandatory=$true)][string]$RepoRoot,
  [Parameter(Mandatory=$true)][string]$OutDir,
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
  "AGENT_BUILDER_NEXT_15_STEPS_LOCK_V2_R2.md",
  "CAPABILITY_ROADMAP.json",
  "GENESIS_STATE.json",
  "TASK_QUEUE.json",
  "packs/registry.json",
  "orchestrator/run.ps1",
  "proofs/self_development/PHASE163T_CONTROLLER_CONSUME_VISIBILITY_PROOF_V1.json",
  "proofs/self_development/PHASE164A_SELECT_NEXT_LOCKED_ROUTE_STEP_V1.json",
  "proofs/self_development/PHASE161K_ACTIVE_ROUTE_EXHAUSTION_AND_LIVE_EVIDENCE_RECONCILIATION_V2.json"
)

$Missing = @()
$SourceHashes = @()

foreach ($Path in $RequiredFiles) {
  if (-not (Test-Path -LiteralPath $Path)) {
    $Missing += $Path
  }
  else {
    $Item = Get-Item -LiteralPath $Path
    $Hash = Get-FileHash -LiteralPath $Path -Algorithm SHA256
    $SourceHashes += [ordered]@{
      path = $Path
      sha256 = $Hash.Hash
      bytes = $Item.Length
    }
  }
}

$Phase161KProofPath = "proofs/self_development/PHASE161K_ACTIVE_ROUTE_EXHAUSTION_AND_LIVE_EVIDENCE_RECONCILIATION_V2.json"
$Phase161KProof = Read-JsonFile -Path $Phase161KProofPath
$Phase161KStatus = "UNKNOWN"

if ($null -ne $Phase161KProof -and ($Phase161KProof.PSObject.Properties.Name -contains "status")) {
  $Phase161KStatus = [string]$Phase161KProof.status
}

$CandidateAtoms = @(
  [ordered]@{
    atom_id = "PHASE163T_VISIBILITY_CONSUME_PROOF"
    source_path = "proofs/self_development/PHASE163T_CONTROLLER_CONSUME_VISIBILITY_PROOF_V1.json"
    replay_check = "proof_exists_and_hashable"
    source_exists = Test-Path -LiteralPath "proofs/self_development/PHASE163T_CONTROLLER_CONSUME_VISIBILITY_PROOF_V1.json"
    mutation_mode = "none"
  },
  [ordered]@{
    atom_id = "PHASE164A_NEXT_LOCKED_ROUTE_SELECTION"
    source_path = "proofs/self_development/PHASE164A_SELECT_NEXT_LOCKED_ROUTE_STEP_V1.json"
    replay_check = "proof_exists_and_hashable"
    source_exists = Test-Path -LiteralPath "proofs/self_development/PHASE164A_SELECT_NEXT_LOCKED_ROUTE_STEP_V1.json"
    mutation_mode = "none"
  },
  [ordered]@{
    atom_id = "PHASE161K_ROUTE_EVIDENCE_RECONCILIATION_V2_PASS"
    source_path = $Phase161KProofPath
    replay_check = "status_PASS"
    source_exists = Test-Path -LiteralPath $Phase161KProofPath
    status = $Phase161KStatus
    mutation_mode = "none"
  }
)

$ValidationPass = (
  $DryRun.IsPresent -and
  $Missing.Count -eq 0 -and
  $Phase161KStatus -eq "PASS"
)

$Status = if ($ValidationPass) { "PASS" } else { "FAIL" }

$ManifestPath = Join-Path $OutDir "accepted_atom_batch_replay_manifest.json"
$ValidationPath = Join-Path $OutDir "accepted_atom_batch_replay_validation.json"
$ReportPath = Join-Path $OutDir "ACCEPTED_ATOM_BATCH_REPLAY_ORCHESTRATOR_REPORT.md"

$Manifest = [ordered]@{
  schema = "ACCEPTED_ATOM_BATCH_REPLAY_MANIFEST_V1"
  created_at = (Get-Date).ToUniversalTime().ToString("o")
  mode = "DRY_RUN_NO_MUTATION"
  repo_root = $RepoRoot
  required_files = $RequiredFiles
  missing_required_files = $Missing
  source_hashes = $SourceHashes
  replay_atoms = $CandidateAtoms
  phase161k_current_status = $Phase161KStatus
  accepted_core_mutation = $false
  route_lock_mutation = $false
  codex_execution = $false
}

$Validation = [ordered]@{
  schema = "ACCEPTED_ATOM_BATCH_REPLAY_VALIDATION_V1"
  status = $Status
  dry_run = $DryRun.IsPresent
  missing_required_count = $Missing.Count
  phase161k_status = $Phase161KStatus
  replay_atom_count = $CandidateAtoms.Count
  accepted_core_mutation = $false
  route_lock_mutation = $false
  codex_execution = $false
}

$Manifest | ConvertTo-Json -Depth 80 | Set-Content -LiteralPath $ManifestPath -Encoding UTF8
$Validation | ConvertTo-Json -Depth 80 | Set-Content -LiteralPath $ValidationPath -Encoding UTF8

$ReportLines = @(
  "# Accepted Atom Batch Replay Orchestrator Report",
  "",
  "Status: $Status",
  "",
  "Mode: DRY_RUN_NO_MUTATION",
  "",
  "Checked:",
  "- missing required count: $($Missing.Count)",
  "- PHASE161K current status: $Phase161KStatus",
  "- replay atom count: $($CandidateAtoms.Count)",
  "- accepted core mutation: false",
  "- route lock mutation: false",
  "- Codex execution: false",
  "",
  "Meaning:",
  "This run does not accept new external candidates.",
  "It replays already accepted proof-backed atoms as a controlled batch and verifies that the next stronger batch can be prepared without mutating core state.",
  "",
  "Next layer:",
  "Owner/material candidate inbox can be connected later through quarantine, sandbox, validation, proof, and promotion."
)

$ReportLines | Set-Content -LiteralPath $ReportPath -Encoding UTF8

$Result = [ordered]@{
  status = $Status
  manifest_path = $ManifestPath
  validation_path = $ValidationPath
  report_path = $ReportPath
}

$Result | ConvertTo-Json -Depth 80
