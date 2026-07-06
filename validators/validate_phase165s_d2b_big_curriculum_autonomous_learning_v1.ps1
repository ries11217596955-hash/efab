param(
  [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path,
  [string]$OutputRoot = 'reports/self_development/phase165s_d2b_big_curriculum_autonomous_learning'
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

function Read-D2BJson {
  param([string]$Path)
  if (-not (Test-Path -LiteralPath $Path)) { throw "MISSING_FILE=$Path" }
  return Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json
}

function Get-D2BJsonLineCount {
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

function Get-D2BCount {
  param($Root, [string]$Property, [string]$AtomId)
  if ($null -eq $Root -or -not ($Root.PSObject.Properties.Name -contains $Property)) { return 0 }
  return @($Root.$Property | Where-Object { [string]$_.atom_id -eq $AtomId }).Count
}

$root = (Resolve-Path $RepoRoot).Path
$outputFull = if ([System.IO.Path]::IsPathRooted($OutputRoot)) { [System.IO.Path]::GetFullPath($OutputRoot) } else { Join-Path $root $OutputRoot }
$state = Read-D2BJson (Join-Path $outputFull 'queue_state.json')
$resume = Read-D2BJson (Join-Path $outputFull 'resume_state.json')
$summary = Read-D2BJson (Join-Path $outputFull 'final_summary.json')
$manifest = Read-D2BJson (Join-Path $root 'reports/self_development/phase165s_d2_big_curriculum_material_factory/school_ready_manifest.json')
$acceptedLogCount = Get-D2BJsonLineCount (Join-Path $outputFull 'accepted_log.jsonl')
$quarantineLogCount = Get-D2BJsonLineCount (Join-Path $outputFull 'quarantine_log.jsonl')
$skippedLogCount = Get-D2BJsonLineCount (Join-Path $outputFull 'skipped_log.jsonl')
$failedLogCount = Get-D2BJsonLineCount (Join-Path $outputFull 'failed_log.jsonl')
$recoveryLogCount = Get-D2BJsonLineCount (Join-Path $outputFull 'recovery_log.jsonl')
$checkpointCount = @(Get-ChildItem -LiteralPath (Join-Path $outputFull 'checkpoints') -File -Filter 'checkpoint_*.json' -ErrorAction SilentlyContinue).Count
$unauthorizedDirty = @(git -C $root status --short -- CAPABILITY_ROADMAP.json GENESIS_STATE.json TASK_QUEUE.json orchestrator/run.ps1 route_locks)
$memory = Read-D2BJson (Join-Path $root 'reports/self_development/accepted_change_memory_snapshot.json')
$selfMap = Read-D2BJson (Join-Path $root 'reports/self_development/SELF_MODEL_ACTIVE_MAP.json')
$registry = Read-D2BJson (Join-Path $root 'packs/registry.json')
$lastAtomId = [string]$state.last_atom_id
$lastMemoryCount = if ($lastAtomId) { Get-D2BCount $memory 'phase162_accepted_atom_memory_records' $lastAtomId } else { 0 }
$lastSelfMapCount = if ($lastAtomId) { Get-D2BCount $selfMap 'phase162_absorbed_atom_capability_notes' $lastAtomId } else { 0 }
$lastRegistryCount = if ($lastAtomId) { Get-D2BCount $registry 'phase162_accepted_atom_references' $lastAtomId } else { 0 }
$lastVisibilityTotal = $lastMemoryCount + $lastSelfMapCount + $lastRegistryCount

$commonChecks = [ordered]@{
  total_count_matches_manifest = ([int]$summary.total_candidate_count -eq [int]$manifest.total_candidate_count)
  state_resume_cursor_match = ([int]$state.shard_index -eq [int]$resume.shard_index -and [int]$state.line_index -eq [int]$resume.line_index)
  state_resume_counts_match = ([int]$state.processed_count -eq [int]$resume.processed_count -and [int]$state.remaining_count -eq [int]$resume.remaining_count)
  processed_plus_remaining_matches_total = ([int]$state.processed_count + [int]$state.remaining_count -eq [int]$manifest.total_candidate_count)
  accepted_log_consistent = ($acceptedLogCount -eq [int]$state.accepted_count)
  quarantine_log_consistent = ($quarantineLogCount -eq [int]$state.quarantine_count)
  skipped_log_consistent = ($skippedLogCount -eq [int]$state.skipped_duplicate_count)
  failed_log_consistent = ($failedLogCount - $recoveryLogCount -eq [int]$state.failed_count)
  recovery_log_consistent = ($recoveryLogCount -eq [int]$state.recovered_failure_count)
  summary_counts_match_state = (
    [int]$summary.accepted_atom_count -eq [int]$state.accepted_count -and
    [int]$summary.quarantine_count -eq [int]$state.quarantine_count -and
    [int]$summary.failed_count -eq [int]$state.failed_count -and
    [int]$summary.recovered_failure_count -eq [int]$state.recovered_failure_count -and
    [int]$summary.processed_count -eq [int]$state.processed_count -and
    [int]$summary.remaining_count -eq [int]$state.remaining_count -and
    [int]$summary.current_shard_index -eq [int]$state.shard_index -and
    [int]$summary.current_line_index -eq [int]$state.line_index
  )
  checkpoint_count_consistent = ($checkpointCount -eq [int]$state.checkpoint_count)
  owner_interrupt_not_used = ([bool]$summary.owner_interrupt_used -eq $false)
  resume_supported = ([bool]$summary.resume_supported -eq $true)
  heartbeat_present = (Test-Path -LiteralPath (Join-Path $outputFull 'heartbeat.json'))
  unauthorized_protected_state_clean = ($unauthorizedDirty.Count -eq 0)
}
$commonFailed = @($commonChecks.GetEnumerator() | Where-Object { -not [bool]$_.Value } | ForEach-Object { [string]$_.Key })
if ($commonFailed.Count -gt 0) {
  Write-Host 'PHASE165S_D2B_BIG_CURRICULUM_AUTONOMOUS_LEARNING_VALIDATE_RESULT=FAIL'
  Write-Host "FAIL_REASON=$($commonFailed -join ';')"
  exit 1
}

if ([string]$summary.status -eq 'BLOCKED_PARTIAL_ACCEPTED_SURFACE' -or
    [string]$state.status -eq 'BLOCKED_PARTIAL_ACCEPTED_SURFACE' -or
    ($lastVisibilityTotal -gt 0 -and -not ($lastMemoryCount -eq 1 -and $lastSelfMapCount -eq 1 -and $lastRegistryCount -eq 1))) {
  Write-Host 'PHASE165S_D2B_BIG_CURRICULUM_AUTONOMOUS_LEARNING_VALIDATE_RESULT=BLOCKED_PARTIAL_ACCEPTED_SURFACE'
  Write-Host "ATOM_ID=$lastAtomId"
  Write-Host "VISIBILITY_COUNTS=memory:$lastMemoryCount,self_map:$lastSelfMapCount,registry:$lastRegistryCount"
  Write-Host 'NEXT_REQUIRED_ACTION=BLOCKED_PARTIAL_ACCEPTED_SURFACE_RECONCILIATION_REQUIRED'
  exit 1
}

if ([string]$summary.status -eq 'STOPPED_BY_SIGNAL') {
  if ([bool]$summary.queue_empty -or [int]$state.failed_count -ne 0 -or -not [bool]$summary.stopped_by_signal) {
    Write-Host 'PHASE165S_D2B_BIG_CURRICULUM_AUTONOMOUS_LEARNING_VALIDATE_RESULT=FAIL'
    Write-Host 'FAIL_REASON=STOPPED_STATE_INCONSISTENT'
    exit 1
  }
  Write-Host 'PHASE165S_D2B_BIG_CURRICULUM_AUTONOMOUS_LEARNING_VALIDATE_RESULT=STOPPED_RESUMABLE'
  Write-Host "PROCESSED_COUNT=$($state.processed_count)"
  Write-Host "REMAINING_COUNT=$($state.remaining_count)"
  exit 0
}

if (-not [bool]$summary.queue_empty) {
  if ([string]$summary.status -eq 'HARD_ERROR' -or [int]$state.failed_count -gt 0) {
    Write-Host 'PHASE165S_D2B_BIG_CURRICULUM_AUTONOMOUS_LEARNING_VALIDATE_RESULT=FAIL'
    Write-Host 'FAIL_REASON=HARD_ERROR_REQUIRES_TRIAGE'
    exit 1
  }
  if ([string]$summary.status -eq 'RUNNING_ACTIVE' -or [string]$state.status -eq 'RUNNING') {
    if ([string]$summary.status -ne 'RUNNING_ACTIVE' -or [string]$state.status -ne 'RUNNING') {
      Write-Host 'PHASE165S_D2B_BIG_CURRICULUM_AUTONOMOUS_LEARNING_VALIDATE_RESULT=FAIL'
      Write-Host 'FAIL_REASON=ACTIVE_RUN_STATUS_MISMATCH'
      exit 1
    }
    Write-Host 'PHASE165S_D2B_BIG_CURRICULUM_AUTONOMOUS_LEARNING_VALIDATE_RESULT=RUNNING_ACTIVE'
    Write-Host "PROCESSED_COUNT=$($state.processed_count)"
    Write-Host "REMAINING_COUNT=$($state.remaining_count)"
    exit 0
  }
  if ([string]$summary.status -ne 'INCOMPLETE_RESUMABLE' -or [string]$state.status -ne 'RUNNING_READY_TO_RESUME') {
    Write-Host 'PHASE165S_D2B_BIG_CURRICULUM_AUTONOMOUS_LEARNING_VALIDATE_RESULT=FAIL'
    Write-Host 'FAIL_REASON=INCOMPLETE_RUN_NOT_MARKED_SAFE_TO_RESUME'
    exit 1
  }
  Write-Host 'PHASE165S_D2B_BIG_CURRICULUM_AUTONOMOUS_LEARNING_VALIDATE_RESULT=INCOMPLETE_RESUMABLE'
  Write-Host "PROCESSED_COUNT=$($state.processed_count)"
  Write-Host "REMAINING_COUNT=$($state.remaining_count)"
  exit 0
}

$finalChecks = [ordered]@{
  status_pass_queue_empty = ([string]$summary.status -eq 'PASS_QUEUE_EMPTY')
  all_candidates_processed = ([int]$state.processed_count -eq [int]$manifest.total_candidate_count -and [int]$state.remaining_count -eq 0)
  no_failures = ([int]$state.failed_count -eq 0)
  quarantine_expected = ([int]$summary.quarantine_count -eq [int]$summary.quarantine_expected_count)
  safe_outcomes_reconciled = ([int]$summary.accepted_atom_count + [int]$summary.denied_count + [int]$summary.invalid_safe_candidate_count + [int]$summary.skipped_duplicate_count + [int]$summary.dynamic_quarantine_count -eq [int]$manifest.safe_candidate_count)
  policy_guard_used = ([bool]$summary.autonomous_policy_guard_used)
  phase162_executor_used = ([bool]$summary.phase162_executor_used)
  stopped_by_signal_false = ([bool]$summary.stopped_by_signal -eq $false)
}

$sampleIds = @()
if (Test-Path -LiteralPath (Join-Path $outputFull 'accepted_log.jsonl')) {
  $lines = @(Get-Content -LiteralPath (Join-Path $outputFull 'accepted_log.jsonl') | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
  if ($lines.Count -gt 0) {
    $sampleIds += [string](($lines[0] | ConvertFrom-Json).atom_id)
    if ($lines.Count -gt 1) { $sampleIds += [string](($lines[-1] | ConvertFrom-Json).atom_id) }
  }
}
$sampleVisible = $sampleIds.Count -gt 0
foreach ($atomId in $sampleIds) {
  $sampleVisible = $sampleVisible -and
    (Get-D2BCount $memory 'phase162_accepted_atom_memory_records' $atomId) -eq 1 -and
    (Get-D2BCount $selfMap 'phase162_absorbed_atom_capability_notes' $atomId) -eq 1 -and
    (Get-D2BCount $registry 'phase162_accepted_atom_references' $atomId) -eq 1
}
$finalChecks['fresh_visibility_sample_passes'] = [bool]$sampleVisible
$failedFinal = @($finalChecks.GetEnumerator() | Where-Object { -not [bool]$_.Value } | ForEach-Object { [string]$_.Key })
if ($failedFinal.Count -gt 0) {
  Write-Host 'PHASE165S_D2B_BIG_CURRICULUM_AUTONOMOUS_LEARNING_VALIDATE_RESULT=FAIL'
  Write-Host "FAIL_REASON=$($failedFinal -join ';')"
  exit 1
}

Write-Host 'PHASE165S_D2B_BIG_CURRICULUM_AUTONOMOUS_LEARNING_VALIDATE_RESULT=PASS'
Write-Host "TOTAL_CANDIDATE_COUNT=$($summary.total_candidate_count)"
Write-Host "ACCEPTED_ATOM_COUNT=$($summary.accepted_atom_count)"
Write-Host "QUARANTINE_COUNT=$($summary.quarantine_count)"
Write-Host "FAILED_COUNT=$($summary.failed_count)"
Write-Host 'OWNER_INTERRUPT_USED=False'
exit 0
