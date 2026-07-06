param(
  [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path,
  [string]$OutputRoot = 'reports/self_development',
  [Parameter(Mandatory=$true)][string]$AcceptedSubjectHead,
  [string]$AcceptedPhase = 'PHASE161E_SELF_MAP_AUTO_REFRESH_AFTER_ACCEPTED_CHANGE',
  [string]$CommitMessageOrPhaseLabel = 'PHASE161E accepted-change self-map refresh',
  [string]$MapRefreshResultPath = 'reports/self_development/self_map_refresh_after_acceptance_result.json',
  [string]$ProofPath = 'proofs/self_development/PHASE161E_SELF_MAP_AUTO_REFRESH_PROOF.json'
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

$root = (Resolve-Path $RepoRoot).Path
$outputFull = Join-Path $root $OutputRoot
if (-not (Test-Path -LiteralPath $outputFull)) {
  New-Item -ItemType Directory -Path $outputFull | Out-Null
}

$changedFiles = @()
try {
  $changedFiles = @(git -C $root show --name-only --format= $AcceptedSubjectHead 2>$null | Where-Object { $_ -and $_.Trim().Length -gt 0 } | ForEach-Object { $_ -replace '\\','/' })
} catch {
  $changedFiles = @()
}

$refreshFull = Join-Path $root $MapRefreshResultPath
$nextAllowed = $false
$nextReason = 'Refresh result missing.'
if (Test-Path -LiteralPath $refreshFull) {
  $refresh = Get-Content -LiteralPath $refreshFull -Raw | ConvertFrom-Json
  $nextAllowed = [bool]$refresh.map_is_ready_for_next_decision
  $nextReason = $(if ($nextAllowed) { 'Self knowledge is ready for the next decision.' } else { 'Self knowledge is not ready.' })
}

$snapshot = [pscustomobject][ordered]@{
  accepted_subject_head = $AcceptedSubjectHead
  accepted_phase = $AcceptedPhase
  commit_message_or_phase_label = $CommitMessageOrPhaseLabel
  changed_files_since_previous_baseline = @($changedFiles)
  map_refresh_result_path = $MapRefreshResultPath
  self_model_active_map_path = 'reports/self_development/SELF_MODEL_ACTIVE_MAP.json'
  memory_report_path = 'reports/self_development/self_map_memory_report.md'
  proof_path = $ProofPath
  next_decision_allowed = $nextAllowed
  next_decision_reason = $nextReason
  created_at = (Get-Date).ToUniversalTime().ToString('o')
}

$snapshotPath = Join-Path $outputFull 'accepted_change_memory_snapshot.json'
$snapshot | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $snapshotPath -Encoding UTF8
$snapshot
