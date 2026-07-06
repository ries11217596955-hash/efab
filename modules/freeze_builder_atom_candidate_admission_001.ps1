param(
  [string]$RepoRoot = "",
  [string]$EventsFile = "",
  [string]$OutputRoot = ""
)

$ErrorActionPreference = "Stop"

function Write-Phase162Json {
  param([string]$Path, [object]$Object)
  $dir = Split-Path -Parent $Path
  if ($dir -and -not (Test-Path -LiteralPath $dir)) {
    New-Item -ItemType Directory -Force -Path $dir | Out-Null
  }
  $Object | ConvertTo-Json -Depth 20 | Set-Content -Path $Path -Encoding UTF8
}

if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
  $RepoRoot = (Resolve-Path ".").Path
}

if ([string]::IsNullOrWhiteSpace($EventsFile)) {
  $EventsFile = Get-ChildItem (Join-Path $RepoRoot "reports/self_development") -File -Filter "PLAIN_LIFE_STOP_AND_PC_TRANSFER_LAST_100_EVENTS_*.jsonl" |
    Sort-Object LastWriteTime -Descending |
    Select-Object -First 1 |
    ForEach-Object { $_.FullName }
}

if ([string]::IsNullOrWhiteSpace($EventsFile) -or -not (Test-Path -LiteralPath $EventsFile)) {
  throw "PHASE162_EVENTS_FILE_MISSING"
}

if ([string]::IsNullOrWhiteSpace($OutputRoot)) {
  $stamp = Get-Date -Format "yyyyMMdd_HHmmss"
  $OutputRoot = Join-Path $RepoRoot "reports/self_development/phase162_admission_freeze_absorb/PHASE162_ATOM_FREEZE_QUARANTINE_$stamp"
}

New-Item -ItemType Directory -Force -Path $OutputRoot | Out-Null

$lines = Get-Content -LiteralPath $EventsFile -ErrorAction Stop
$events = @()

foreach ($line in $lines) {
  if ([string]::IsNullOrWhiteSpace($line)) { continue }
  try {
    $events += ($line | ConvertFrom-Json)
  } catch {
    # skip partial or invalid lines
  }
}

$bridgeEvents = @($events | Where-Object { [string]$_.event_type -eq "autonomous_atom_bridge_completed" })

if ($bridgeEvents.Count -lt 1) {
  throw "PHASE162_NO_AUTONOMOUS_ATOM_BRIDGE_COMPLETED_EVENT"
}

$selected = $bridgeEvents[$bridgeEvents.Count - 1]

$artifactPath = ""
if ($selected.PSObject.Properties.Name -contains "atom_candidate_summary_path") {
  $artifactPath = [string]$selected.atom_candidate_summary_path
}

$artifactFullPath = ""
$artifactPresent = $false
$candidateSummary = $null

if (-not [string]::IsNullOrWhiteSpace($artifactPath)) {
  if ([System.IO.Path]::IsPathRooted($artifactPath)) {
    $artifactFullPath = $artifactPath
  } else {
    $artifactFullPath = Join-Path $RepoRoot $artifactPath
  }

  $artifactPresent = Test-Path -LiteralPath $artifactFullPath

  if ($artifactPresent) {
    try {
      $candidateSummary = Get-Content -LiteralPath $artifactFullPath -Raw | ConvertFrom-Json
    } catch {
      $candidateSummary = $null
    }
  }
}

$freezePath = Join-Path $OutputRoot "frozen_atom_candidate_evidence.json"
$decisionPath = Join-Path $OutputRoot "admission_decision.json"
$reportPath = Join-Path $OutputRoot "PHASE162_ATOM_FREEZE_QUARANTINE_REPORT.md"

$reasons = @()
$reasons += "phase162_first_prototype_is_quarantine_only"
$reasons += "accepted_core_mutation_disallowed"

if (-not $artifactPresent) {
  $reasons += "source_atom_candidate_summary_artifact_not_present_on_this_pc"
}

if ([string]$selected.atom_summary_status -eq "SANDBOX_ATOM_CANDIDATE_NOT_ACCEPTED") {
  $reasons += "source_event_declares_sandbox_atom_candidate_not_accepted"
}

if ([bool]$selected.accepted_atom_claimed -eq $false) {
  $reasons += "source_event_declares_accepted_atom_false"
}

$frozen = [ordered]@{
  schema = "PHASE162_ATOM_CANDIDATE_FROZEN_EVIDENCE_V1"
  status = "FROZEN"
  created_at = (Get-Date -Format o)
  repo_head = (git -C $RepoRoot rev-parse --short HEAD)
  source_events_file = $EventsFile
  selected_event_type = [string]$selected.event_type
  selected_duty_id = [string]$selected.duty_id
  selected_run_id = [string]$selected.run_id
  selected_status = [string]$selected.status
  selected_atom_summary_status = [string]$selected.atom_summary_status
  selected_skill_candidate_count = $selected.skill_candidate_count
  selected_accepted_atom_claimed = [bool]$selected.accepted_atom_claimed
  atom_candidate_summary_path = $artifactPath
  atom_candidate_summary_present_on_this_pc = $artifactPresent
  candidate_summary_snapshot = $candidateSummary
  accepted_state_mutated = $false
  accepted_memory_mutated = $false
  accepted_self_model_mutated = $false
  accepted_core_mutation_allowed = $false
  safety_boundary = "session_local_freeze_only"
}

$decision = [ordered]@{
  schema = "PHASE162_ATOM_CANDIDATE_ADMISSION_DECISION_V1"
  status = "PASS"
  admission_decision = "QUARANTINE"
  created_at = (Get-Date -Format o)
  frozen_evidence_path = $freezePath
  reasons = $reasons
  usefulness_validated = $false
  safety_validated_for_accept = $false
  accept_ready = $false
  accepted_atom_claimed = $false
  accepted_state_mutated = $false
  accepted_memory_mutated = $false
  accepted_self_model_mutated = $false
  next_action = "KEEP_QUARANTINED_UNTIL_FULL_CANDIDATE_ARTIFACT_AND_ACCEPTANCE_VALIDATOR_EXIST"
}

Write-Phase162Json -Path $freezePath -Object $frozen
Write-Phase162Json -Path $decisionPath -Object $decision

@"
# PHASE162 Atom Candidate Freeze / Quarantine Report

## Result

- status: PASS
- admission_decision: QUARANTINE
- accepted_atom_claimed: false
- accepted_state_mutated: false
- accepted_memory_mutated: false
- accepted_self_model_mutated: false

## Source

- source_events_file: `$EventsFile`
- selected_duty_id: `$($selected.duty_id)`
- selected_run_id: `$($selected.run_id)`
- atom_summary_status: `$($selected.atom_summary_status)`
- skill_candidate_count: `$($selected.skill_candidate_count)`
- accepted_atom_claimed_from_source: `$($selected.accepted_atom_claimed)`

## Why Quarantine

This first PHASE162 prototype only proves freeze and quarantine. It does not accept or absorb the atom.

Reasons:

$($reasons | ForEach-Object { "- $_" } | Out-String)

## Created Artifacts

- frozen_evidence: `$freezePath`
- admission_decision: `$decisionPath`

## Boundary

No accepted core mutation is performed.
"@ | Set-Content -Path $reportPath -Encoding UTF8

[pscustomobject]@{
  status = "PASS"
  admission_decision = "QUARANTINE"
  output_root = $OutputRoot
  frozen_evidence_path = $freezePath
  admission_decision_path = $decisionPath
  report_path = $reportPath
  accepted_state_mutated = $false
  accepted_memory_mutated = $false
  accepted_self_model_mutated = $false
}
