param(
  [Parameter(Mandatory=$true)][string]$RepoRoot,
  [Parameter(Mandatory=$true)][string]$OutDir,
  [string]$InboxDir = "owner_orders/candidate_inbox",
  [string]$BridgeOutboxDir = "owner_orders/candidate_self_growth_bridge_outbox",
  [switch]$DryRun
)

$ErrorActionPreference = "Stop"

Set-Location -LiteralPath $RepoRoot
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
New-Item -ItemType Directory -Force -Path $BridgeOutboxDir | Out-Null

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
  "proofs/self_development/PHASE164D_CANDIDATE_QUARANTINE_AND_SANDBOX_GATE_V1.json",
  "schemas/self_development/OWNER_CANDIDATE_INBOX_ITEM_SCHEMA_V1.json",
  "schemas/self_development/CANDIDATE_QUARANTINE_RECORD_SCHEMA_V1.json",
  "schemas/self_development/OWNER_CANDIDATE_TO_SELF_GROWTH_BRIDGE_TASK_SCHEMA_V1.json",
  "owner_orders/candidate_inbox/README.md",
  "owner_orders/candidate_quarantine/README.md",
  "runtime_sessions/candidate_sandbox/README.md"
)

$Missing = @()
foreach ($Path in $RequiredFiles) {
  if (-not (Test-Path -LiteralPath $Path)) { $Missing += $Path }
}

$Phase164DProof = Read-JsonFile -Path "proofs/self_development/PHASE164D_CANDIDATE_QUARANTINE_AND_SANDBOX_GATE_V1.json"
$Phase164DStatus = "UNKNOWN"
if ($null -ne $Phase164DProof -and ($Phase164DProof.PSObject.Properties.Name -contains "status")) {
  $Phase164DStatus = [string]$Phase164DProof.status
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

$BridgeTasks = @()
$InvalidCandidateCount = 0

foreach ($File in $CandidateFiles) {
  $CandidateId = $File.BaseName
  $MissingFields = @()
  $ReadError = $null
  $CandidateValid = $true

  try {
    $Json = Get-Content -LiteralPath $File.FullName -Raw | ConvertFrom-Json

    if ($Json.PSObject.Properties.Name -contains "candidate_id") {
      $CandidateId = [string]$Json.candidate_id
    }

    foreach ($Field in $RequiredCandidateFields) {
      if (-not ($Json.PSObject.Properties.Name -contains $Field)) {
        $MissingFields += $Field
      }
    }

    if ($MissingFields.Count -gt 0) {
      $CandidateValid = $false
      $InvalidCandidateCount += 1
    }
  }
  catch {
    $CandidateValid = $false
    $InvalidCandidateCount += 1
    $ReadError = $_.Exception.Message
  }

  if ($CandidateValid) {
    $BridgeTasks += [ordered]@{
      bridge_task_id = "SELF_GROWTH_FROM_OWNER_CANDIDATE_$CandidateId"
      source_candidate_id = $CandidateId
      source_candidate_path = $File.FullName
      target_loop = "EXISTING_BUILDER_SELF_GROWTH_LOOP"
      requested_action = "ADAPT_OWNER_CANDIDATE_AS_ATOM_CANDIDATE_USING_EXISTING_BUILDER_ORGANS"
      status = "READY_FOR_EXISTING_BUILDER_SELF_GROWTH_INTAKE"
      atom_acceptance_allowed = $false
      required_next_gate = "BUILDER_SANDBOX_VALIDATE_PROOF_THEN_ACCEPT_OR_REJECT"
      created_at = (Get-Date).ToUniversalTime().ToString("o")
      mutation_mode = "none"
    }
  }
  else {
    $BridgeTasks += [ordered]@{
      bridge_task_id = "INVALID_OWNER_CANDIDATE_$CandidateId"
      source_candidate_id = $CandidateId
      source_candidate_path = $File.FullName
      target_loop = "NONE"
      requested_action = "OWNER_REPAIR_CANDIDATE_BEFORE_SELF_GROWTH_INTAKE"
      status = "INVALID_CANDIDATE_NOT_BRIDGED"
      atom_acceptance_allowed = $false
      required_next_gate = "OWNER_REPAIR"
      missing_fields = $MissingFields
      read_error = $ReadError
      created_at = (Get-Date).ToUniversalTime().ToString("o")
      mutation_mode = "none"
    }
  }
}

$ReadyBridgeTaskCount = @($BridgeTasks | Where-Object { $_.status -eq "READY_FOR_EXISTING_BUILDER_SELF_GROWTH_INTAKE" }).Count

$ValidationPass = (
  $DryRun.IsPresent -and
  $Missing.Count -eq 0 -and
  $Phase164DStatus -eq "PASS" -and
  $InvalidCandidateCount -eq 0
)

$Status = if ($ValidationPass) { "PASS" } else { "FAIL" }

$ManifestPath = Join-Path $OutDir "candidate_to_self_growth_bridge_manifest.json"
$ValidationPath = Join-Path $OutDir "candidate_to_self_growth_bridge_validation.json"
$BridgeTasksPath = Join-Path $OutDir "candidate_to_self_growth_bridge_tasks_preview.json"
$ReportPath = Join-Path $OutDir "CANDIDATE_TO_SELF_GROWTH_BRIDGE_REPORT.md"

$Manifest = [ordered]@{
  schema = "CANDIDATE_TO_SELF_GROWTH_BRIDGE_MANIFEST_V1"
  created_at = (Get-Date).ToUniversalTime().ToString("o")
  mode = "DRY_RUN_NO_TASK_QUEUE_MUTATION"
  inbox_dir = $InboxDir
  bridge_outbox_dir = $BridgeOutboxDir
  required_files_missing = $Missing
  phase164d_status = $Phase164DStatus
  candidate_file_count = $CandidateFiles.Count
  ready_bridge_task_count = $ReadyBridgeTaskCount
  invalid_candidate_count = $InvalidCandidateCount
  task_queue_mutation = $false
  accepted_core_mutation = $false
  route_lock_mutation = $false
  codex_execution = $false
}

$Validation = [ordered]@{
  schema = "CANDIDATE_TO_SELF_GROWTH_BRIDGE_VALIDATION_V1"
  status = $Status
  dry_run = $DryRun.IsPresent
  missing_required_count = $Missing.Count
  phase164d_status = $Phase164DStatus
  candidate_file_count = $CandidateFiles.Count
  ready_bridge_task_count = $ReadyBridgeTaskCount
  invalid_candidate_count = $InvalidCandidateCount
  task_queue_mutation = $false
  accepted_core_mutation = $false
  route_lock_mutation = $false
  codex_execution = $false
}

$Manifest | ConvertTo-Json -Depth 80 | Set-Content -LiteralPath $ManifestPath -Encoding UTF8
$Validation | ConvertTo-Json -Depth 80 | Set-Content -LiteralPath $ValidationPath -Encoding UTF8
$BridgeTasks | ConvertTo-Json -Depth 80 | Set-Content -LiteralPath $BridgeTasksPath -Encoding UTF8

@"
# Candidate To Self-Growth Bridge Report

Status: $Status

Mode: DRY_RUN_NO_TASK_QUEUE_MUTATION

Checked:
- missing required count: $($Missing.Count)
- PHASE164D status: $Phase164DStatus
- candidate files: $($CandidateFiles.Count)
- ready bridge tasks: $ReadyBridgeTaskCount
- invalid candidates: $InvalidCandidateCount
- task queue mutation: false
- accepted core mutation: false
- route lock mutation: false
- Codex execution: false

Meaning:
This organ does not promote candidates.
It converts valid owner candidates into task-shaped input for the existing Builder self-growth loop.

Correct route:
candidate -> existing Builder organs -> sandbox -> validation -> proof -> accept/reject.
"@ | Set-Content -LiteralPath $ReportPath -Encoding UTF8

[ordered]@{
  status = $Status
  manifest_path = $ManifestPath
  validation_path = $ValidationPath
  bridge_tasks_path = $BridgeTasksPath
  report_path = $ReportPath
} | ConvertTo-Json -Depth 80
