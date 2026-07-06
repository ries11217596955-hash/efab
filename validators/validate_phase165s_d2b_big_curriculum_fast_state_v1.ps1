param(
  [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path,
  [string]$InputRoot = 'reports/self_development/phase165s_d2_big_curriculum_material_factory',
  [string]$OutputRoot = 'reports/self_development/phase165s_d2b_big_curriculum_autonomous_learning'
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

function Read-D2BFastJson {
  param([string]$Path)
  if (-not (Test-Path -LiteralPath $Path)) { throw "MISSING_FILE=$Path" }
  return Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json
}

function Get-D2BFastJsonLineCount {
  param([string]$Path)
  if (-not (Test-Path -LiteralPath $Path)) { return 0 }
  $count = 0
  $reader = [System.IO.StreamReader]::new($Path)
  try {
    while (-not $reader.EndOfStream) {
      if (-not [string]::IsNullOrWhiteSpace($reader.ReadLine())) { $count += 1 }
    }
  } finally {
    $reader.Dispose()
  }
  return $count
}

function Get-D2BInt {
  param($Value, [string]$Property, [int]$Default = 0)
  if ($null -eq $Value -or -not ($Value.PSObject.Properties.Name -contains $Property) -or $null -eq $Value.$Property) {
    return $Default
  }
  return [int]$Value.$Property
}

function Get-D2BString {
  param($Value, [string]$Property, [string]$Default = '')
  if ($null -eq $Value -or -not ($Value.PSObject.Properties.Name -contains $Property) -or $null -eq $Value.$Property) {
    return $Default
  }
  return [string]$Value.$Property
}

function Get-D2BBool {
  param($Value, [string]$Property, [bool]$Default = $false)
  if ($null -eq $Value -or -not ($Value.PSObject.Properties.Name -contains $Property) -or $null -eq $Value.$Property) {
    return $Default
  }
  return [bool]$Value.$Property
}

function Write-D2BFail {
  param([string[]]$Reasons)
  Write-Host 'PHASE165S_D2B_FAST_VALIDATE_RESULT=FAIL'
  Write-Host "FAIL_REASON=$($Reasons -join ';')"
  exit 1
}

$root = (Resolve-Path $RepoRoot).Path
$inputFull = if ([System.IO.Path]::IsPathRooted($InputRoot)) { [System.IO.Path]::GetFullPath($InputRoot) } else { [System.IO.Path]::GetFullPath((Join-Path $root $InputRoot)) }
$outputFull = if ([System.IO.Path]::IsPathRooted($OutputRoot)) { [System.IO.Path]::GetFullPath($OutputRoot) } else { [System.IO.Path]::GetFullPath((Join-Path $root $OutputRoot)) }

try {
  $state = Read-D2BFastJson (Join-Path $outputFull 'queue_state.json')
  $resume = Read-D2BFastJson (Join-Path $outputFull 'resume_state.json')
  $summary = Read-D2BFastJson (Join-Path $outputFull 'final_summary.json')
  $manifest = Read-D2BFastJson (Join-Path $inputFull 'school_ready_manifest.json')
} catch {
  Write-D2BFail @($_.Exception.Message)
}

$acceptedLogCount = Get-D2BFastJsonLineCount (Join-Path $outputFull 'accepted_log.jsonl')
$quarantineLogCount = Get-D2BFastJsonLineCount (Join-Path $outputFull 'quarantine_log.jsonl')
$skippedLogCount = Get-D2BFastJsonLineCount (Join-Path $outputFull 'skipped_log.jsonl')
$failedLogCount = Get-D2BFastJsonLineCount (Join-Path $outputFull 'failed_log.jsonl')
$recoveryLogCount = Get-D2BFastJsonLineCount (Join-Path $outputFull 'recovery_log.jsonl')
$checkpointCount = @(Get-ChildItem -LiteralPath (Join-Path $outputFull 'checkpoints') -File -Filter 'checkpoint_*.json' -ErrorAction SilentlyContinue).Count
$heartbeatPath = Join-Path $outputFull 'heartbeat.json'
$protectedDirty = @(git -C $root status --short -- `
  CAPABILITY_ROADMAP.json `
  GENESIS_STATE.json `
  TASK_QUEUE.json `
  orchestrator/run.ps1 `
  route_locks `
  packs/registry.json `
  reports/self_development/accepted_change_memory_snapshot.json `
  reports/self_development/SELF_MODEL_ACTIVE_MAP.json)

$stateProcessed = Get-D2BInt $state 'processed_count'
$stateRemaining = Get-D2BInt $state 'remaining_count'
$stateAccepted = Get-D2BInt $state 'accepted_count'
$stateQuarantine = Get-D2BInt $state 'quarantine_count'
$stateSkipped = Get-D2BInt $state 'skipped_duplicate_count'
$stateFailed = Get-D2BInt $state 'failed_count'
$stateRecovered = Get-D2BInt $state 'recovered_failure_count'
$stateCheckpoint = Get-D2BInt $state 'checkpoint_count'
$stateShard = Get-D2BInt $state 'shard_index'
$stateLine = Get-D2BInt $state 'line_index'
$resumeProcessed = Get-D2BInt $resume 'processed_count'
$resumeRemaining = Get-D2BInt $resume 'remaining_count'
$resumeAccepted = Get-D2BInt $resume 'accepted_count'
$resumeQuarantine = Get-D2BInt $resume 'quarantine_count'
$resumeSkipped = Get-D2BInt $resume 'skipped_duplicate_count'
$resumeFailed = Get-D2BInt $resume 'failed_count'
$resumeRecovered = Get-D2BInt $resume 'recovered_failure_count'
$resumeShard = Get-D2BInt $resume 'shard_index'
$resumeLine = Get-D2BInt $resume 'line_index'
$manifestTotal = Get-D2BInt $manifest 'total_candidate_count'
$summaryStatus = Get-D2BString $summary 'status'
$stateStatus = Get-D2BString $state 'status'

$checks = [ordered]@{
  total_count_matches_manifest = ((Get-D2BInt $summary 'total_candidate_count') -eq $manifestTotal)
  state_resume_cursor_match = ($stateShard -eq $resumeShard -and $stateLine -eq $resumeLine)
  state_resume_counts_match = (
    $stateProcessed -eq $resumeProcessed -and
    $stateRemaining -eq $resumeRemaining -and
    $stateAccepted -eq $resumeAccepted -and
    $stateQuarantine -eq $resumeQuarantine -and
    $stateSkipped -eq $resumeSkipped -and
    $stateFailed -eq $resumeFailed -and
    $stateRecovered -eq $resumeRecovered
  )
  processed_plus_remaining_matches_total = (($stateProcessed + $stateRemaining) -eq $manifestTotal)
  accepted_log_consistent = ($acceptedLogCount -eq $stateAccepted)
  quarantine_log_consistent = ($quarantineLogCount -eq $stateQuarantine)
  skipped_log_consistent = ($skippedLogCount -eq $stateSkipped)
  failed_log_consistent = (($failedLogCount - $recoveryLogCount) -eq $stateFailed)
  recovery_log_consistent = ($recoveryLogCount -eq $stateRecovered)
  summary_counts_match_state = (
    (Get-D2BInt $summary 'accepted_atom_count') -eq $stateAccepted -and
    (Get-D2BInt $summary 'quarantine_count') -eq $stateQuarantine -and
    (Get-D2BInt $summary 'skipped_duplicate_count') -eq $stateSkipped -and
    (Get-D2BInt $summary 'failed_count') -eq $stateFailed -and
    (Get-D2BInt $summary 'recovered_failure_count') -eq $stateRecovered -and
    (Get-D2BInt $summary 'processed_count') -eq $stateProcessed -and
    (Get-D2BInt $summary 'remaining_count') -eq $stateRemaining -and
    (Get-D2BInt $summary 'current_shard_index') -eq $stateShard -and
    (Get-D2BInt $summary 'current_line_index') -eq $stateLine
  )
  checkpoint_count_consistent = ($checkpointCount -eq $stateCheckpoint)
  heartbeat_present = (Test-Path -LiteralPath $heartbeatPath)
  unauthorized_protected_state_clean = ($protectedDirty.Count -eq 0)
}

$failedChecks = @($checks.GetEnumerator() | Where-Object { -not [bool]$_.Value } | ForEach-Object { [string]$_.Key })
if ($failedChecks.Count -gt 0) {
  Write-D2BFail $failedChecks
}

if ($summaryStatus -eq 'BLOCKED_PARTIAL_ACCEPTED_SURFACE' -or $stateStatus -eq 'BLOCKED_PARTIAL_ACCEPTED_SURFACE') {
  Write-D2BFail @('BLOCKED_PARTIAL_ACCEPTED_SURFACE_REQUIRES_FULL_VALIDATOR_OR_RECONCILIATION')
}
if ($summaryStatus -eq 'HARD_ERROR' -or $stateStatus -eq 'HARD_ERROR' -or $stateFailed -gt 0) {
  Write-D2BFail @('HARD_ERROR_REQUIRES_TRIAGE')
}

if ((Get-D2BBool $summary 'queue_empty') -or $stateRemaining -eq 0) {
  if ($summaryStatus -ne 'PASS_QUEUE_EMPTY' -or $stateStatus -ne 'QUEUE_EMPTY') {
    Write-D2BFail @('QUEUE_EMPTY_STATUS_MISMATCH')
  }
  Write-Host 'PHASE165S_D2B_FAST_VALIDATE_RESULT=FAST_PASS_QUEUE_EMPTY'
} elseif ($summaryStatus -eq 'RUNNING_ACTIVE' -and $stateStatus -eq 'RUNNING') {
  Write-Host 'PHASE165S_D2B_FAST_VALIDATE_RESULT=FAST_PASS_RUNNING'
} elseif ($summaryStatus -eq 'INCOMPLETE_RESUMABLE' -and $stateStatus -eq 'RUNNING_READY_TO_RESUME') {
  Write-Host 'PHASE165S_D2B_FAST_VALIDATE_RESULT=FAST_PASS_INCOMPLETE_RESUMABLE'
} elseif ($summaryStatus -eq 'STOPPED_BY_SIGNAL' -and $stateStatus -eq 'STOPPED_BY_SIGNAL' -and (Get-D2BBool $summary 'stopped_by_signal')) {
  Write-Host 'PHASE165S_D2B_FAST_VALIDATE_RESULT=FAST_PASS_INCOMPLETE_RESUMABLE'
} else {
  Write-D2BFail @("UNSUPPORTED_STATUS_PAIR summary=$summaryStatus state=$stateStatus")
}

Write-Host "PROCESSED_COUNT=$stateProcessed"
Write-Host "REMAINING_COUNT=$stateRemaining"
Write-Host "ACCEPTED_LOG_COUNT=$acceptedLogCount"
Write-Host "QUARANTINE_LOG_COUNT=$quarantineLogCount"
Write-Host "SKIPPED_LOG_COUNT=$skippedLogCount"
Write-Host "FAILED_LOG_COUNT=$failedLogCount"
Write-Host "RECOVERY_LOG_COUNT=$recoveryLogCount"
exit 0
