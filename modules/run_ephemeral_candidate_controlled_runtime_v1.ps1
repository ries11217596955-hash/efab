param(
  [Parameter(Mandatory=$true)]
  [ValidateRange(1, 100000)]
  [int]$MaxCycles,
  [ValidateRange(1, 100)]
  [int]$BatchSize = 100,
  [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path,
  [string]$RuntimeRoot = '',
  [string]$StopFile = '',
  [string]$HeartbeatPath = '',
  [string]$SummaryPath = '',
  [ValidateSet('CompactAccepted')]
  [string]$RetentionMode = 'CompactAccepted',
  [ValidateSet('SyntheticV1','StructuredV1')]
  [string]$CandidateGeneratorMode = 'SyntheticV1'
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

function ConvertTo-ControlledRuntimeFullPath {
  param([string]$Root, [string]$Path)
  if ([System.IO.Path]::IsPathRooted($Path)) {
    return [System.IO.Path]::GetFullPath($Path)
  }
  return [System.IO.Path]::GetFullPath((Join-Path $Root $Path))
}

function Get-ControlledRuntimeRelativePath {
  param([string]$Root, [string]$Path)
  $rootFull = [System.IO.Path]::GetFullPath($Root).TrimEnd('\','/')
  $pathFull = [System.IO.Path]::GetFullPath($Path)
  if (-not $pathFull.StartsWith($rootFull + [System.IO.Path]::DirectorySeparatorChar, [System.StringComparison]::OrdinalIgnoreCase)) {
    return $Path
  }
  return ($pathFull.Substring($rootFull.Length + 1) -replace '\\', '/')
}

function Write-ControlledRuntimeJson {
  param([string]$Path, [object]$Value)
  $parent = Split-Path -Parent $Path
  if ($parent) { New-Item -ItemType Directory -Force -Path $parent | Out-Null }
  $json = ($Value | ConvertTo-Json -Depth 100) -replace "`r`n", "`n"
  [System.IO.File]::WriteAllText($Path, $json + "`n", [System.Text.UTF8Encoding]::new($false))
}

function Test-ControlledRuntimeUnderRuntimeRoot {
  param([string]$RepoRoot, [string]$Path)
  $runtimeRoot = [System.IO.Path]::GetFullPath((Join-Path $RepoRoot '.runtime')).TrimEnd('\','/')
  $full = [System.IO.Path]::GetFullPath($Path).TrimEnd('\','/')
  return ($full.Equals($runtimeRoot, [System.StringComparison]::OrdinalIgnoreCase) -or
    $full.StartsWith($runtimeRoot + [System.IO.Path]::DirectorySeparatorChar, [System.StringComparison]::OrdinalIgnoreCase))
}

function Remove-ControlledRuntimeCleanupPath {
  param(
    [Parameter(Mandatory=$true)][string]$Path,
    [ValidateSet('file','dir')][string]$Kind,
    [int]$Attempts = 12
  )

  if (-not (Test-Path -LiteralPath $Path)) { return $true }

  for ($attempt = 1; $attempt -le $Attempts; $attempt += 1) {
    try {
      if (-not (Test-Path -LiteralPath $Path)) { return $true }
      if ($Kind -eq 'dir') {
        Remove-Item -LiteralPath $Path -Recurse -Force -ErrorAction Stop
      } else {
        Remove-Item -LiteralPath $Path -Force -ErrorAction Stop
      }
      if (-not (Test-Path -LiteralPath $Path)) { return $true }
    } catch [System.UnauthorizedAccessException] {
    } catch [System.IO.IOException] {
    }

    if ($attempt -lt $Attempts) {
      if (Test-Path -LiteralPath $Path) {
        if ($Kind -eq 'dir') {
          Get-ChildItem -LiteralPath $Path -Recurse -Force -ErrorAction SilentlyContinue | ForEach-Object {
            try { $_.Attributes = [System.IO.FileAttributes]::Normal } catch { }
          }
        } else {
          try { [System.IO.File]::SetAttributes($Path, [System.IO.FileAttributes]::Normal) } catch { }
        }
      }
      [System.GC]::Collect()
      [System.GC]::WaitForPendingFinalizers()
      Start-Sleep -Milliseconds ([Math]::Min(1000, 100 * $attempt))
    }
  }

  return (-not (Test-Path -LiteralPath $Path))
}

function Get-ControlledRuntimeCleanupBytes {
  param([object[]]$Entries)

  $totalBytes = 0L
  foreach ($entry in @($Entries)) {
    if (-not (Test-Path -LiteralPath $entry.path)) { continue }
    if ($entry.kind -eq 'dir') {
      $sum = (Get-ChildItem -LiteralPath $entry.path -Recurse -Force -File -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum
      if ($null -ne $sum) { $totalBytes += [int64]$sum }
    } else {
      $totalBytes += [int64](Get-Item -LiteralPath $entry.path -Force).Length
    }
  }
  return $totalBytes
}

function Get-ControlledRuntimeCleanupEntries {
  param(
    [string]$RepoRoot,
    [string]$RuntimeRootFull,
    [string[]]$ManifestPaths
  )

  $runtimeFull = [System.IO.Path]::GetFullPath($RuntimeRootFull).TrimEnd('\','/')
  $entries = @()
  foreach ($manifestPath in @($ManifestPaths | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -Unique)) {
    $manifestFull = ConvertTo-ControlledRuntimeFullPath -Root $RepoRoot -Path $manifestPath
    if (-not (Test-Path -LiteralPath $manifestFull)) { continue }
    $manifest = Get-Content -LiteralPath $manifestFull -Raw | ConvertFrom-Json
    foreach ($entry in @($manifest.entries)) {
      $entryFull = [System.IO.Path]::GetFullPath([string]$entry.path)
      if (-not ($entryFull.Equals($runtimeFull, [System.StringComparison]::OrdinalIgnoreCase) -or
          $entryFull.StartsWith($runtimeFull + [System.IO.Path]::DirectorySeparatorChar, [System.StringComparison]::OrdinalIgnoreCase))) {
        throw "PENDING_CLEANUP_PATH_OUTSIDE_RUNTIME=$entryFull"
      }
      $entries += [pscustomobject][ordered]@{
        manifest_path = $manifestFull
        path = $entryFull
        kind = [string]$entry.kind
      }
    }
  }
  return @($entries)
}

function Invoke-ControlledRuntimeCleanupDrainOnce {
  param([object[]]$Entries)

  $remaining = @()
  foreach ($entry in @($Entries)) {
    $deleted = Remove-ControlledRuntimeCleanupPath -Path $entry.path -Kind $entry.kind
    if (-not $deleted) {
      $remaining += $entry
    }
  }

  foreach ($manifestGroup in (@($Entries) | Group-Object manifest_path)) {
    $manifestFull = [string]$manifestGroup.Name
    $stillPending = @($remaining | Where-Object { [string]$_.manifest_path -eq $manifestFull })
    if ($stillPending.Count -eq 0) {
      Remove-ControlledRuntimeCleanupPath -Path $manifestFull -Kind 'file' | Out-Null
    } else {
      $updated = [ordered]@{
        schema = 'retention_cleanup_pending_v1'
        status = 'PENDING'
        entries = @($stillPending | ForEach-Object { [ordered]@{ path = $_.path; kind = $_.kind } })
        pending_cleanup_count = $stillPending.Count
        runtime_ready = $false
      }
      Write-ControlledRuntimeJson -Path $manifestFull -Value $updated
    }
  }

  return @($remaining)
}

function Invoke-ControlledRuntimePendingCleanup {
  param(
    [string]$RepoRoot,
    [string]$RuntimeRootFull,
    [string[]]$ManifestPaths,
    [int64]$SoftByteBound = 10485760,
    [int64]$LowWatermarkBytes = 5242880,
    [int64]$HardByteBound = 104857600,
    [int]$SoftCountBound = 20,
    [int]$HardCountBound = 200,
    [int]$MaxBackpressureWaitSeconds = 300,
    [int]$NoProgressAttemptLimit = 10,
    [int]$DrainSleepMilliseconds = 1000
  )

  $entries = @(Get-ControlledRuntimeCleanupEntries -RepoRoot $RepoRoot -RuntimeRootFull $RuntimeRootFull -ManifestPaths $ManifestPaths)
  $totalBytes = 0L
  $pressureEvent = ($entries.Count -gt $SoftCountBound)
  $backpressureEvent = $pressureEvent
  $drainIterations = 0
  $waitSeconds = 0
  $noProgressEvents = 0
  $noProgressAttempts = 0
  $maxPendingBeforeBackpressure = 0L
  $minPendingAfterBackpressure = if ($pressureEvent) { [int64]::MaxValue } else { 0L }
  $lastRemainingBytes = [int64]::MaxValue
  $lastRemainingCount = $entries.Count
  $remaining = @($entries)
  $remainingBytes = 0L
  $started = Get-Date

  while ($true) {
    if ($remaining.Count -eq 0) {
      $remainingBytes = 0L
      if ($pressureEvent) { $minPendingAfterBackpressure = 0L }
      break
    }

    $drainIterations += 1
    $remaining = @(Invoke-ControlledRuntimeCleanupDrainOnce -Entries $remaining)
    $remaining = @(Get-ControlledRuntimeCleanupEntries -RepoRoot $RepoRoot -RuntimeRootFull $RuntimeRootFull -ManifestPaths $ManifestPaths)
    $remainingBytes = Get-ControlledRuntimeCleanupBytes -Entries $remaining
    if (-not $pressureEvent -and $remainingBytes -gt $SoftByteBound) {
      $pressureEvent = $true
      $backpressureEvent = $true
      $minPendingAfterBackpressure = [int64]::MaxValue
    }
    if ($pressureEvent -and $remainingBytes -gt $maxPendingBeforeBackpressure) { $maxPendingBeforeBackpressure = $remainingBytes }
    if ($pressureEvent -and $remainingBytes -lt $minPendingAfterBackpressure) { $minPendingAfterBackpressure = $remainingBytes }

    if ($remaining.Count -lt $lastRemainingCount -or $remainingBytes -lt $lastRemainingBytes) {
      $noProgressAttempts = 0
    } else {
      $noProgressAttempts += 1
    }
    $lastRemainingBytes = $remainingBytes
    $lastRemainingCount = $remaining.Count

    if (-not $pressureEvent) { break }
    if ($remainingBytes -le $LowWatermarkBytes -and $remaining.Count -le $SoftCountBound) { break }

    $elapsedSeconds = [int]((Get-Date) - $started).TotalSeconds
    if ($elapsedSeconds -ge $MaxBackpressureWaitSeconds) {
      break
    }
    if ($noProgressAttempts -ge $NoProgressAttemptLimit) {
      $noProgressEvents += 1
      break
    }

    Start-Sleep -Milliseconds $DrainSleepMilliseconds
    $waitSeconds += [int][Math]::Ceiling($DrainSleepMilliseconds / 1000.0)
  }

  if ($pressureEvent -and $minPendingAfterBackpressure -eq [int64]::MaxValue) {
    $minPendingAfterBackpressure = $remainingBytes
  }

  if ($remaining.Count -gt $HardCountBound) {
    throw "PENDING_CLEANUP_COUNT_EXCEEDS_HARD_BOUND timing=after_drain count=$($remaining.Count) hard_bound=$HardCountBound initial_count=$($entries.Count)"
  }
  if ($remainingBytes -gt $HardByteBound) {
    throw "PENDING_CLEANUP_BYTES_EXCEEDS_HARD_BOUND timing=after_drain bytes=$remainingBytes hard_bound=$HardByteBound initial_bytes=$totalBytes"
  }
  if ($pressureEvent -and $remainingBytes -gt $HardByteBound -and $noProgressEvents -gt 0) {
    throw "PENDING_CLEANUP_NO_PROGRESS timing=after_backpressure bytes=$remainingBytes low_watermark=$LowWatermarkBytes attempts=$NoProgressAttemptLimit initial_bytes=$totalBytes"
  }

  return [pscustomobject][ordered]@{
    pending_cleanup_initial_count = $entries.Count
    pending_cleanup_initial_bytes = $totalBytes
    pending_cleanup_final_count = $remaining.Count
    pending_cleanup_final_bytes = $remainingBytes
    cleanup_pressure_event = $pressureEvent
    cleanup_backpressure_event = $backpressureEvent
    cleanup_drain_iterations = $drainIterations
    cleanup_backpressure_wait_seconds = $waitSeconds
    max_pending_before_backpressure = $maxPendingBeforeBackpressure
    min_pending_after_backpressure = $minPendingAfterBackpressure
    backpressure_no_progress_events = $noProgressEvents
    cleanup_soft_byte_bound = $SoftByteBound
    cleanup_low_watermark_bytes = $LowWatermarkBytes
    cleanup_hard_byte_bound = $HardByteBound
    cleanup_soft_count_bound = $SoftCountBound
    cleanup_hard_count_bound = $HardCountBound
  }
}

$root = (Resolve-Path $RepoRoot).Path
if ([string]::IsNullOrWhiteSpace($RuntimeRoot)) {
  $RuntimeRoot = ".runtime/controlled_ephemeral_runtime_{0}" -f (Get-Date).ToUniversalTime().ToString('yyyyMMdd_HHmmss')
}
$runtimeRootFull = ConvertTo-ControlledRuntimeFullPath -Root $root -Path $RuntimeRoot
if (-not (Test-ControlledRuntimeUnderRuntimeRoot -RepoRoot $root -Path $runtimeRootFull)) {
  throw "RUNTIME_ROOT_MUST_BE_UNDER_DOT_RUNTIME=$runtimeRootFull"
}

New-Item -ItemType Directory -Force -Path $runtimeRootFull | Out-Null
$runtimeRootRel = Get-ControlledRuntimeRelativePath -Root $root -Path $runtimeRootFull

if ([string]::IsNullOrWhiteSpace($HeartbeatPath)) {
  $HeartbeatPath = Join-Path $runtimeRootFull 'heartbeat.json'
}
if ([string]::IsNullOrWhiteSpace($SummaryPath)) {
  $SummaryPath = Join-Path $runtimeRootFull 'summary.json'
}
$heartbeatFull = ConvertTo-ControlledRuntimeFullPath -Root $root -Path $HeartbeatPath
$summaryFull = ConvertTo-ControlledRuntimeFullPath -Root $root -Path $SummaryPath
$stopFileFull = if ([string]::IsNullOrWhiteSpace($StopFile)) { '' } else { ConvertTo-ControlledRuntimeFullPath -Root $root -Path $StopFile }

$generator = if ($CandidateGeneratorMode -eq 'StructuredV1') {
  Join-Path $root 'modules/generate_structured_ephemeral_candidate_batch_v1.ps1'
} else {
  Join-Path $root 'modules/generate_ephemeral_d2b_candidate_batch_v1.ps1'
}
$legacyRunner = Join-Path $root 'modules/run_phase165s_d2b_big_curriculum_autonomous_learn_until_empty_001.ps1'
foreach ($required in @($generator, $legacyRunner)) {
  if (-not (Test-Path -LiteralPath $required)) { throw "REQUIRED_MODULE_MISSING=$required" }
}

$runId = "controlled_ephemeral_runtime_{0}" -f (Get-Date).ToUniversalTime().ToString('yyyyMMddHHmmss')
$cycleResults = @()
$pendingCleanupManifests = @()
$seedCleanupManifest = Join-Path $runtimeRootFull 'cleanup_pending.json'
if (Test-Path -LiteralPath $seedCleanupManifest) {
  $pendingCleanupManifests += $seedCleanupManifest
}
$cleanupSoftByteBound = 10485760L
$cleanupLowWatermarkBytes = 5242880L
$cleanupHardByteBound = 104857600L
$cleanupSoftCountBound = 20
$cleanupHardCountBound = 200
$maxBackpressureWaitSecondsPerEvent = 300
$noProgressAttemptLimit = 10
$drainSleepMilliseconds = 1000
$cleanupPressureEvents = 0
$cleanupBackpressureEvents = 0
$cleanupBackpressureWaitSecondsTotal = 0
$cleanupDrainIterationsTotal = 0
$backpressureNoProgressEvents = 0
$pendingCleanupPeakBytes = 0L
$pendingCleanupPeakCount = 0
$maxPendingBeforeBackpressure = 0L
$minPendingAfterBackpressure = 0L
$failureStage = ''
$failureDecisionTiming = ''
$pendingCleanupFailureBytes = 0L
$pendingCleanupFailureCount = 0
$status = 'PASS'
$stopReason = ''
$failedCycle = $null
$failureReason = ''

function Update-ControlledRuntimeCleanupStats {
  param([object]$CleanupStatus)
  if ($null -eq $CleanupStatus) { return }
  $counts = @([int]$CleanupStatus.pending_cleanup_initial_count, [int]$CleanupStatus.pending_cleanup_final_count)
  $bytes = @([int64]$CleanupStatus.pending_cleanup_initial_bytes, [int64]$CleanupStatus.pending_cleanup_final_bytes)
  $maxCount = (@($counts) | Measure-Object -Maximum).Maximum
  $maxBytes = (@($bytes) | Measure-Object -Maximum).Maximum
  if ($null -ne $maxCount -and [int]$maxCount -gt $script:pendingCleanupPeakCount) { $script:pendingCleanupPeakCount = [int]$maxCount }
  if ($null -ne $maxBytes -and [int64]$maxBytes -gt $script:pendingCleanupPeakBytes) { $script:pendingCleanupPeakBytes = [int64]$maxBytes }
  if ([bool]$CleanupStatus.cleanup_pressure_event) { $script:cleanupPressureEvents += [Math]::Max(1, [int]$CleanupStatus.cleanup_drain_iterations) }
  if ([bool]$CleanupStatus.cleanup_backpressure_event) { $script:cleanupBackpressureEvents += 1 }
  $script:cleanupBackpressureWaitSecondsTotal += [int]$CleanupStatus.cleanup_backpressure_wait_seconds
  $script:cleanupDrainIterationsTotal += [int]$CleanupStatus.cleanup_drain_iterations
  $script:backpressureNoProgressEvents += [int]$CleanupStatus.backpressure_no_progress_events
  if ([int64]$CleanupStatus.max_pending_before_backpressure -gt $script:maxPendingBeforeBackpressure) {
    $script:maxPendingBeforeBackpressure = [int64]$CleanupStatus.max_pending_before_backpressure
  }
  $minAfter = [int64]$CleanupStatus.min_pending_after_backpressure
  if ([bool]$CleanupStatus.cleanup_backpressure_event -and ($script:minPendingAfterBackpressure -eq 0L -or $minAfter -lt $script:minPendingAfterBackpressure)) {
    $script:minPendingAfterBackpressure = $minAfter
  }
}

try {
  for ($cycle = 1; $cycle -le $MaxCycles; $cycle += 1) {
    $preCycleCleanupStatus = Invoke-ControlledRuntimePendingCleanup -RepoRoot $root -RuntimeRootFull $runtimeRootFull -ManifestPaths $pendingCleanupManifests -SoftByteBound $cleanupSoftByteBound -LowWatermarkBytes $cleanupLowWatermarkBytes -HardByteBound $cleanupHardByteBound -SoftCountBound $cleanupSoftCountBound -HardCountBound $cleanupHardCountBound -MaxBackpressureWaitSeconds $maxBackpressureWaitSecondsPerEvent -NoProgressAttemptLimit $noProgressAttemptLimit -DrainSleepMilliseconds $drainSleepMilliseconds
    Update-ControlledRuntimeCleanupStats -CleanupStatus $preCycleCleanupStatus
    if (-not [string]::IsNullOrWhiteSpace($stopFileFull) -and (Test-Path -LiteralPath $stopFileFull)) {
      $status = 'STOPPED_BY_STOP_FILE'
      $stopReason = "STOP_FILE_PRESENT_BEFORE_CYCLE_$cycle"
      break
    }

    $cycleText = '{0:d4}' -f $cycle
    $cycleBatchId = "${runId}_cycle_$cycleText"
    $cycleRootRel = "$runtimeRootRel/cycle_$cycleText"
    $outputRootRel = "$cycleRootRel/output"
    $workRootRel = "$cycleRootRel/workroot"
    $acceptedCoreDeltaRootRel = "$cycleRootRel/accepted_core_delta"
    $workCurrentFull = Join-Path (ConvertTo-ControlledRuntimeFullPath -Root $root -Path $workRootRel) 'phase165s_d2b_work_current'

    $generatorJson = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $generator `
      -RepoRoot $root `
      -Count $BatchSize `
      -OutputRoot $cycleRootRel `
      -BatchId $cycleBatchId
    if ($LASTEXITCODE -ne 0) {
      throw "GENERATOR_FAILED cycle=$cycle exit=$LASTEXITCODE output=$($generatorJson -join ' ')"
    }
    $generatorResult = ($generatorJson -join "`n") | ConvertFrom-Json
    $candidateBatchPath = [string]$generatorResult.candidate_batch_path

    $runnerJson = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $legacyRunner `
      -RepoRoot $root `
      -OutputRoot $outputRootRel `
      -WorkRoot $workRootRel `
      -CandidateBatchPath $candidateBatchPath `
      -BatchSize $BatchSize `
      -RetentionMode $RetentionMode `
      -AcceptedCoreMode RuntimeDeltaOnly `
      -AcceptedCoreRoot $acceptedCoreDeltaRootRel `
      -EmitJson
    $runnerExitCode = $LASTEXITCODE
    if ($runnerExitCode -ne 0) {
      throw "LEGACY_RUNNER_FAILED cycle=$cycle exit=$runnerExitCode output=$($runnerJson -join ' ')"
    }

    $runnerResult = ($runnerJson -join "`n") | ConvertFrom-Json
    $retention = $runnerResult.post_batch_retention
    $pendingManifests = @()
    if ($retention -and ($retention.PSObject.Properties.Name -contains 'cleanup_pending_path') -and -not [string]::IsNullOrWhiteSpace([string]$retention.cleanup_pending_path)) {
      $pendingManifests += [string]$retention.cleanup_pending_path
    }
    if (($runnerResult.PSObject.Properties.Name -contains 'cleanup_pending_path') -and -not [string]::IsNullOrWhiteSpace([string]$runnerResult.cleanup_pending_path)) {
      $pendingManifests += [string]$runnerResult.cleanup_pending_path
    }
    $pendingCleanupManifests += @($pendingManifests)
    $pendingCleanupManifests = @($pendingCleanupManifests | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -Unique)
    $cleanupStatus = Invoke-ControlledRuntimePendingCleanup -RepoRoot $root -RuntimeRootFull $runtimeRootFull -ManifestPaths $pendingManifests -SoftByteBound $cleanupSoftByteBound -LowWatermarkBytes $cleanupLowWatermarkBytes -HardByteBound $cleanupHardByteBound -SoftCountBound $cleanupSoftCountBound -HardCountBound $cleanupHardCountBound -MaxBackpressureWaitSeconds $maxBackpressureWaitSecondsPerEvent -NoProgressAttemptLimit $noProgressAttemptLimit -DrainSleepMilliseconds $drainSleepMilliseconds
    Update-ControlledRuntimeCleanupStats -CleanupStatus $cleanupStatus
    $acceptedCount = [int]$runnerResult.accepted_atom_count
    $receiptCount = if ($retention.PSObject.Properties.Name -contains 'receipt_count') { [int]$retention.receipt_count } else { 0 }
    $candidateMaterialPruned = (-not (Test-Path -LiteralPath (Join-Path $root $candidateBatchPath)))
    $workCurrentExistsAfterSuccess = (Test-Path -LiteralPath $workCurrentFull)
    $retentionHeavyTracePruned = $false
    if ($retention.PSObject.Properties.Name -contains 'heavy_trace_pruned') {
      $retentionHeavyTracePruned = [bool]$retention.heavy_trace_pruned
    }
    $runnerCandidateMaterialPruned = $false
    if ($runnerResult.PSObject.Properties.Name -contains 'candidate_material_pruned') {
      $runnerCandidateMaterialPruned = [bool]$runnerResult.candidate_material_pruned
    }
    $heavyTracePruned = ($retentionHeavyTracePruned -or (-not $workCurrentExistsAfterSuccess))
    $cycleResult = [ordered]@{
      cycle = $cycle
      batch_id = $cycleBatchId
      candidate_generator_mode = $CandidateGeneratorMode
      candidate_batch_path = $candidateBatchPath
      output_root = $outputRootRel
      work_root = $workRootRel
      accepted_core_mode = if ($runnerResult.PSObject.Properties.Name -contains 'accepted_core_mode') { [string]$runnerResult.accepted_core_mode } else { '' }
      accepted_core_delta_root = if ($runnerResult.PSObject.Properties.Name -contains 'accepted_core_delta_root') { [string]$runnerResult.accepted_core_delta_root } else { $acceptedCoreDeltaRootRel }
      runtime_delta_written = if ($runnerResult.PSObject.Properties.Name -contains 'runtime_delta_written') { [bool]$runnerResult.runtime_delta_written } else { $false }
      runner_exit_code = $runnerExitCode
      runner_final_status = [string]$runnerResult.status
      accepted_count = $acceptedCount
      receipt_count = $receiptCount
      retention_status = [string]$retention.status
      retention_gate_invoked = if ($retention.PSObject.Properties.Name -contains 'retention_gate_invoked') { [bool]$retention.retention_gate_invoked } else { $false }
      heavy_trace_pruned = $heavyTracePruned
      pending_cleanup_pre_cycle_count = [int]$preCycleCleanupStatus.pending_cleanup_final_count
      pending_cleanup_pre_cycle_bytes = [int64]$preCycleCleanupStatus.pending_cleanup_final_bytes
      pending_cleanup_initial_count = [int]$cleanupStatus.pending_cleanup_initial_count
      pending_cleanup_initial_bytes = [int64]$cleanupStatus.pending_cleanup_initial_bytes
      pending_cleanup_final_count = [int]$cleanupStatus.pending_cleanup_final_count
      pending_cleanup_final_bytes = [int64]$cleanupStatus.pending_cleanup_final_bytes
      cleanup_pressure_event = ([bool]$preCycleCleanupStatus.cleanup_pressure_event -or [bool]$cleanupStatus.cleanup_pressure_event)
      cleanup_backpressure_event = ([bool]$preCycleCleanupStatus.cleanup_backpressure_event -or [bool]$cleanupStatus.cleanup_backpressure_event)
      cleanup_drain_iterations = ([int]$preCycleCleanupStatus.cleanup_drain_iterations + [int]$cleanupStatus.cleanup_drain_iterations)
      cleanup_backpressure_wait_seconds = ([int]$preCycleCleanupStatus.cleanup_backpressure_wait_seconds + [int]$cleanupStatus.cleanup_backpressure_wait_seconds)
      cleanup_soft_byte_bound = $cleanupSoftByteBound
      cleanup_low_watermark_bytes = $cleanupLowWatermarkBytes
      cleanup_hard_byte_bound = $cleanupHardByteBound
      candidate_material_pruned = $candidateMaterialPruned
      runner_candidate_material_pruned = ($runnerCandidateMaterialPruned -or $candidateMaterialPruned)
      work_current_exists_after_success = $workCurrentExistsAfterSuccess
      runtime_ready = $false
    }
    $cycleResults += $cycleResult

    $cyclePass = (
      [string]$cycleResult.retention_status -eq 'PASS' -and
      [bool]$cycleResult.retention_gate_invoked -eq $true -and
      [int]$cycleResult.pending_cleanup_final_count -le $cleanupHardCountBound -and
      [int64]$cycleResult.pending_cleanup_final_bytes -le $cleanupHardByteBound -and
      [string]$cycleResult.accepted_core_mode -eq 'RuntimeDeltaOnly' -and
      [bool]$cycleResult.runtime_delta_written -eq $true -and
      [int]$cycleResult.accepted_count -eq $BatchSize -and
      [int]$cycleResult.receipt_count -eq [int]$cycleResult.accepted_count
    )
    if (-not $cyclePass) {
      $status = 'FAILED'
      $failedCycle = $cycle
      $failureReason = 'CYCLE_INVARIANT_FAILED'
      break
    }

    $heartbeat = [ordered]@{
      schema = 'CONTROLLED_EPHEMERAL_RUNTIME_HEARTBEAT_V1'
      status = 'RUNNING'
      run_id = $runId
      heartbeat_utc = (Get-Date).ToUniversalTime().ToString('o')
      design_mode = 'RuntimeDeltaOnly'
      candidate_generator_mode = $CandidateGeneratorMode
      completed_cycles = $cycleResults.Count
      max_cycles = $MaxCycles
      total_accepted = (@($cycleResults | ForEach-Object { [int]$_['accepted_count'] }) | Measure-Object -Sum).Sum
      total_receipts = (@($cycleResults | ForEach-Object { [int]$_['receipt_count'] }) | Measure-Object -Sum).Sum
      pending_cleanup_current_count = [int]$cycleResult.pending_cleanup_final_count
      pending_cleanup_current_bytes = [int64]$cycleResult.pending_cleanup_final_bytes
      pending_cleanup_total_bytes = [int64]$cycleResult.pending_cleanup_initial_bytes
      pending_cleanup_final_count = [int]$cycleResult.pending_cleanup_final_count
      pending_cleanup_final_bytes = [int64]$cycleResult.pending_cleanup_final_bytes
      pending_cleanup_peak_bytes = $pendingCleanupPeakBytes
      pending_cleanup_peak_count = $pendingCleanupPeakCount
      cleanup_pressure_events = $cleanupPressureEvents
      cleanup_backpressure_events = $cleanupBackpressureEvents
      cleanup_backpressure_wait_seconds_total = $cleanupBackpressureWaitSecondsTotal
      cleanup_drain_iterations_total = $cleanupDrainIterationsTotal
      cleanup_soft_byte_bound = $cleanupSoftByteBound
      cleanup_low_watermark_bytes = $cleanupLowWatermarkBytes
      cleanup_hard_byte_bound = $cleanupHardByteBound
      max_pending_before_backpressure = $maxPendingBeforeBackpressure
      min_pending_after_backpressure = $minPendingAfterBackpressure
      backpressure_no_progress_events = $backpressureNoProgressEvents
      cleanup_lifecycle_mode = 'DeferredCleanupQueue'
      runtime_delta_written = (@($cycleResults | Where-Object { [bool]$_['runtime_delta_written'] -ne $true }).Count -eq 0)
      runtime_ready = $false
    }
    Write-ControlledRuntimeJson -Path $heartbeatFull -Value $heartbeat
  }
} catch {
  $status = 'FAILED'
  if ($null -eq $failedCycle) { $failedCycle = $cycleResults.Count + 1 }
  $failureReason = $_.Exception.Message
  $failureStage = 'cycle_or_pre_cycle'
  $failureDecisionTiming = if ($failureReason -match 'timing=after_drain') { 'after_drain' } else { 'unknown' }
}

$finalCleanupStatus = [pscustomobject][ordered]@{
  pending_cleanup_initial_count = 0
  pending_cleanup_initial_bytes = 0
  pending_cleanup_final_count = 0
  pending_cleanup_final_bytes = 0
  cleanup_pressure_event = $false
  cleanup_backpressure_event = $false
  cleanup_drain_iterations = 0
  cleanup_backpressure_wait_seconds = 0
  max_pending_before_backpressure = 0
  min_pending_after_backpressure = 0
  backpressure_no_progress_events = 0
  cleanup_soft_byte_bound = $cleanupSoftByteBound
  cleanup_low_watermark_bytes = $cleanupLowWatermarkBytes
  cleanup_hard_byte_bound = $cleanupHardByteBound
}
try {
  $finalCleanupStatus = Invoke-ControlledRuntimePendingCleanup -RepoRoot $root -RuntimeRootFull $runtimeRootFull -ManifestPaths $pendingCleanupManifests -SoftByteBound $cleanupSoftByteBound -LowWatermarkBytes $cleanupLowWatermarkBytes -HardByteBound $cleanupHardByteBound -SoftCountBound $cleanupSoftCountBound -HardCountBound $cleanupHardCountBound -MaxBackpressureWaitSeconds $maxBackpressureWaitSecondsPerEvent -NoProgressAttemptLimit $noProgressAttemptLimit -DrainSleepMilliseconds $drainSleepMilliseconds
  Update-ControlledRuntimeCleanupStats -CleanupStatus $finalCleanupStatus
} catch {
  $status = 'FAILED'
  if ($null -eq $failedCycle) { $failedCycle = [Math]::Max(1, $cycleResults.Count) }
  $failureReason = "RETENTION_CLEANUP_FINAL_FAILED $($_.Exception.Message)"
  $failureStage = 'final_cleanup'
  $failureDecisionTiming = if ($_.Exception.Message -match 'timing=after_drain') { 'after_drain' } else { 'unknown' }
  if ($_.Exception.Message -match 'bytes=(\d+)') { $pendingCleanupFailureBytes = [int64]$Matches[1] }
  if ($_.Exception.Message -match 'count=(\d+)') { $pendingCleanupFailureCount = [int]$Matches[1] }
}

foreach ($cycleResult in $cycleResults) {
  $candidatePathNow = Join-Path $root ([string]$cycleResult['candidate_batch_path'])
  $workRootNow = Join-Path (ConvertTo-ControlledRuntimeFullPath -Root $root -Path ([string]$cycleResult['work_root'])) 'phase165s_d2b_work_current'
  $candidatePrunedNow = (-not (Test-Path -LiteralPath $candidatePathNow))
  $workCurrentExistsNow = (Test-Path -LiteralPath $workRootNow)
  $cycleResult['candidate_material_pruned'] = $candidatePrunedNow
  $cycleResult['runner_candidate_material_pruned'] = ([bool]$cycleResult['runner_candidate_material_pruned'] -or $candidatePrunedNow)
  $cycleResult['work_current_exists_after_success'] = $workCurrentExistsNow
  $cycleResult['heavy_trace_pruned'] = ([bool]$cycleResult['heavy_trace_pruned'] -or (-not $workCurrentExistsNow))
}

if ($status -eq 'PASS' -and ([int]$finalCleanupStatus.pending_cleanup_final_count -ne 0 -or [int64]$finalCleanupStatus.pending_cleanup_final_bytes -ne 0)) {
  $status = 'FAILED'
  $failedCycle = [Math]::Max(1, $cycleResults.Count)
  $failureReason = 'PENDING_CLEANUP_NOT_DRAINED'
  $failureStage = 'final_invariant'
  $failureDecisionTiming = 'after_drain'
  $pendingCleanupFailureBytes = [int64]$finalCleanupStatus.pending_cleanup_final_bytes
  $pendingCleanupFailureCount = [int]$finalCleanupStatus.pending_cleanup_final_count
}

if ($status -eq 'PASS' -and $cycleResults.Count -lt $MaxCycles) {
  $status = 'INCOMPLETE'
}

$totalAccepted = 0
$totalReceipts = 0
foreach ($cycleResult in $cycleResults) {
  $totalAccepted += [int]$cycleResult['accepted_count']
  $totalReceipts += [int]$cycleResult['receipt_count']
}
$failedCycles = @($cycleResults | Where-Object {
  [int]$_['accepted_count'] -ne $BatchSize -or
  [int]$_['receipt_count'] -ne [int]$_['accepted_count'] -or
  [string]$_['retention_status'] -ne 'PASS' -or
  [bool]$_['candidate_material_pruned'] -ne $true -or
  [bool]$_['work_current_exists_after_success'] -ne $false
})
if ($status -eq 'PASS' -and $failedCycles.Count -gt 0) {
  $status = 'FAILED'
  $failedCycle = [int]$failedCycles[0]['cycle']
  $failureReason = 'FAILED_CYCLE_IN_SUMMARY'
}

$summary = [ordered]@{
  schema = 'CONTROLLED_EPHEMERAL_RUNTIME_SUMMARY_V1'
  status = $status
  run_id = $runId
  created_utc = (Get-Date).ToUniversalTime().ToString('o')
  max_cycles = $MaxCycles
  batch_size = $BatchSize
  completed_cycles = $cycleResults.Count
  total_accepted = $totalAccepted
  total_receipts = $totalReceipts
  failed_cycles = $failedCycles.Count
  failed_cycle = $failedCycle
  failure_reason = $failureReason
  stop_reason = $stopReason
  retention_mode = $RetentionMode
  design_mode = 'RuntimeDeltaOnly'
  candidate_generator_mode = $CandidateGeneratorMode
  cleanup_lifecycle_mode = 'DeferredCleanupQueue'
  runtime_delta_written = (@($cycleResults | Where-Object { [bool]$_['runtime_delta_written'] -ne $true }).Count -eq 0)
  pending_cleanup_current_count = [int]$finalCleanupStatus.pending_cleanup_final_count
  pending_cleanup_current_bytes = [int64]$finalCleanupStatus.pending_cleanup_final_bytes
  pending_cleanup_total_bytes = [int64]$finalCleanupStatus.pending_cleanup_initial_bytes
  pending_cleanup_final_count = [int]$finalCleanupStatus.pending_cleanup_final_count
  pending_cleanup_final_bytes = [int64]$finalCleanupStatus.pending_cleanup_final_bytes
  cleanup_soft_byte_bound = $cleanupSoftByteBound
  cleanup_low_watermark_bytes = $cleanupLowWatermarkBytes
  cleanup_hard_byte_bound = $cleanupHardByteBound
  pending_cleanup_peak_bytes = $pendingCleanupPeakBytes
  pending_cleanup_peak_count = $pendingCleanupPeakCount
  cleanup_pressure_events = $cleanupPressureEvents
  cleanup_backpressure_events = $cleanupBackpressureEvents
  cleanup_backpressure_wait_seconds_total = $cleanupBackpressureWaitSecondsTotal
  cleanup_drain_iterations_total = $cleanupDrainIterationsTotal
  max_pending_before_backpressure = $maxPendingBeforeBackpressure
  min_pending_after_backpressure = $minPendingAfterBackpressure
  backpressure_no_progress_events = $backpressureNoProgressEvents
  max_backpressure_wait_seconds_per_event = $maxBackpressureWaitSecondsPerEvent
  no_progress_attempt_limit = $noProgressAttemptLimit
  drain_sleep_milliseconds = $drainSleepMilliseconds
  failure_stage = $failureStage
  failure_decision_timing = $failureDecisionTiming
  pending_cleanup_failure_bytes = $pendingCleanupFailureBytes
  pending_cleanup_failure_count = $pendingCleanupFailureCount
  runtime_root = $runtimeRootRel
  heartbeat_path = (Get-ControlledRuntimeRelativePath -Root $root -Path $heartbeatFull)
  summary_path = (Get-ControlledRuntimeRelativePath -Root $root -Path $summaryFull)
  cycle_results = @($cycleResults)
  runtime_ready = $false
}
Write-ControlledRuntimeJson -Path $summaryFull -Value $summary

$summary | ConvertTo-Json -Depth 100
