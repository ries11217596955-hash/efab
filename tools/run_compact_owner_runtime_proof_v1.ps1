param(
  [ValidateRange(1, 100000)]
  [int]$MaxCycles = 2,
  [ValidateRange(1, 100)]
  [int]$BatchSize = 100,
  [ValidateSet('SyntheticV1','StructuredV1')]
  [string]$CandidateGeneratorMode = 'StructuredV1',
  [ValidateSet('CompactAccepted')]
  [string]$RetentionMode = 'CompactAccepted',
  [string]$ProofCardRoot = 'proofs/runtime',
  [string]$RuntimeRoot = '',
  [switch]$KeepRawRuntime
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

function ConvertTo-OwnerProofFullPath {
  param([string]$Root, [string]$Path)
  if ([System.IO.Path]::IsPathRooted($Path)) {
    return [System.IO.Path]::GetFullPath($Path)
  }
  return [System.IO.Path]::GetFullPath((Join-Path $Root $Path))
}

function Test-OwnerProofPathUnderRoot {
  param([string]$Root, [string]$Path)
  $rootFull = [System.IO.Path]::GetFullPath($Root).TrimEnd('\','/')
  $pathFull = [System.IO.Path]::GetFullPath($Path).TrimEnd('\','/')
  return ($pathFull.Equals($rootFull, [System.StringComparison]::OrdinalIgnoreCase) -or
    $pathFull.StartsWith($rootFull + [System.IO.Path]::DirectorySeparatorChar, [System.StringComparison]::OrdinalIgnoreCase))
}

function Write-OwnerProofJson {
  param([string]$Path, [object]$Value)
  $parent = Split-Path -Parent $Path
  if ($parent) { New-Item -ItemType Directory -Force -Path $parent | Out-Null }
  $json = ($Value | ConvertTo-Json -Depth 100) -replace "`r`n", "`n"
  [System.IO.File]::WriteAllText($Path, $json + "`n", [System.Text.UTF8Encoding]::new($false))
}

function Get-OwnerProofJsonValue {
  param([object]$Object, [string]$Name, $Default = $null)
  if ($null -ne $Object -and $Object.PSObject.Properties.Name -contains $Name) {
    return $Object.PSObject.Properties[$Name].Value
  }
  return $Default
}

function Get-OwnerProofGitLines {
  param([string]$RepoRoot, [string[]]$Arguments)
  try {
    return @(& git -C $RepoRoot @Arguments 2>$null)
  } catch {
    return @("GIT_COMMAND_FAILED $($Arguments -join ' ')")
  }
}

function Get-OwnerProofRuntimeSize {
  param([string]$Path)
  $result = [ordered]@{ file_count = 0; bytes = 0L }
  if (-not (Test-Path -LiteralPath $Path)) { return $result }
  foreach ($file in @(Get-ChildItem -LiteralPath $Path -Recurse -Force -File -ErrorAction SilentlyContinue)) {
    $result.file_count += 1
    $result.bytes += [int64]$file.Length
  }
  return $result
}

function Get-OwnerProofLeftoverTargetCount {
  param([string]$RepoRoot, [object]$Summary)
  $targets = @{}
  $cycleResults = @(Get-OwnerProofJsonValue -Object $Summary -Name 'cycle_results' -Default @())
  foreach ($cycleResult in $cycleResults) {
    $candidatePath = [string](Get-OwnerProofJsonValue -Object $cycleResult -Name 'candidate_batch_path' -Default '')
    if (-not [string]::IsNullOrWhiteSpace($candidatePath)) {
      $candidateFull = ConvertTo-OwnerProofFullPath -Root $RepoRoot -Path $candidatePath
      $targets[$candidateFull] = $true
    }

    $workRoot = [string](Get-OwnerProofJsonValue -Object $cycleResult -Name 'work_root' -Default '')
    if (-not [string]::IsNullOrWhiteSpace($workRoot)) {
      $workCurrentFull = Join-Path (ConvertTo-OwnerProofFullPath -Root $RepoRoot -Path $workRoot) 'phase165s_d2b_work_current'
      $targets[$workCurrentFull] = $true
    }
  }

  $leftoverCount = 0
  foreach ($target in $targets.Keys) {
    if (Test-Path -LiteralPath $target -PathType Container) {
      $leftoverCount += 1
    }
  }
  return $leftoverCount
}

function Add-OwnerProofFailure {
  param([System.Collections.Generic.List[string]]$Failures, [string]$Reason)
  if (-not [string]::IsNullOrWhiteSpace($Reason)) {
    $Failures.Add($Reason) | Out-Null
  }
}

function Test-OwnerProofBytesEqual {
  param([byte[]]$Left, [byte[]]$Right)
  if ($null -eq $Left -or $null -eq $Right) { return ($null -eq $Left -and $null -eq $Right) }
  if ($Left.Length -ne $Right.Length) { return $false }
  for ($i = 0; $i -lt $Left.Length; $i += 1) {
    if ($Left[$i] -ne $Right[$i]) { return $false }
  }
  return $true
}

function Get-OwnerProofCanonicalArtifactPaths {
  param([string]$RepoRoot)

  $paths = [System.Collections.Generic.List[string]]::new()
  foreach ($relativePath in @(
    'reports/self_development/PHASE165S_D2B_BIG_CURRICULUM_AUTONOMOUS_LEARNING_V1.md',
    'proofs/self_development/PHASE165S_D2B_BIG_CURRICULUM_AUTONOMOUS_LEARNING_V1.json'
  )) {
    $paths.Add((ConvertTo-OwnerProofFullPath -Root $RepoRoot -Path $relativePath)) | Out-Null
  }

  foreach ($relativeDir in @('reports','proofs')) {
    $dirFull = ConvertTo-OwnerProofFullPath -Root $RepoRoot -Path $relativeDir
    if (Test-Path -LiteralPath $dirFull -PathType Container) {
      foreach ($file in @(Get-ChildItem -LiteralPath $dirFull -File -Force -ErrorAction SilentlyContinue)) {
        $paths.Add($file.FullName) | Out-Null
      }
    }
  }

  return @($paths | Select-Object -Unique)
}

function New-OwnerProofCanonicalArtifactGuard {
  param([string]$RepoRoot)

  $knownPaths = @(
    (ConvertTo-OwnerProofFullPath -Root $RepoRoot -Path 'reports/self_development/PHASE165S_D2B_BIG_CURRICULUM_AUTONOMOUS_LEARNING_V1.md'),
    (ConvertTo-OwnerProofFullPath -Root $RepoRoot -Path 'proofs/self_development/PHASE165S_D2B_BIG_CURRICULUM_AUTONOMOUS_LEARNING_V1.json')
  )
  $knownPathSet = @{}
  foreach ($path in $knownPaths) { $knownPathSet[$path] = $true }

  $snapshots = @{}
  foreach ($path in @(Get-OwnerProofCanonicalArtifactPaths -RepoRoot $RepoRoot)) {
    $exists = Test-Path -LiteralPath $path -PathType Leaf
    $snapshot = [ordered]@{
      path = $path
      known_canonical = $knownPathSet.ContainsKey($path)
      existed = $exists
      bytes = [byte[]]@()
      last_write_time_utc = $null
      attributes = $null
    }
    if ($exists) {
      $item = Get-Item -LiteralPath $path -Force
      $snapshot['bytes'] = [System.IO.File]::ReadAllBytes($path)
      $snapshot['last_write_time_utc'] = $item.LastWriteTimeUtc
      $snapshot['attributes'] = $item.Attributes
    }
    $snapshots[$path] = $snapshot
  }

  return [ordered]@{
    enabled = $true
    started_utc = (Get-Date).ToUniversalTime()
    snapshots = $snapshots
  }
}

function Restore-OwnerProofCanonicalArtifacts {
  param([string]$RepoRoot, [object]$Guard)

  $failures = [System.Collections.Generic.List[string]]::new()
  $restoredCount = 0
  $deletedCount = 0
  $affectedPaths = @{}

  foreach ($path in @($Guard['snapshots'].Keys)) {
    $affectedPaths[$path] = $true
  }
  foreach ($path in @(Get-OwnerProofCanonicalArtifactPaths -RepoRoot $RepoRoot)) {
    $affectedPaths[$path] = $true
  }

  foreach ($path in @($affectedPaths.Keys)) {
    $hasSnapshot = $Guard['snapshots'].ContainsKey($path)
    $snapshot = if ($hasSnapshot) { $Guard['snapshots'][$path] } else { $null }
    $existsNow = Test-Path -LiteralPath $path -PathType Leaf
    $isKnown = ($hasSnapshot -and [bool]$snapshot['known_canonical'])
    $createdAfterStart = ($existsNow -and -not $hasSnapshot)
    $touchedAfterStart = $false
    if ($existsNow) {
      $currentItem = Get-Item -LiteralPath $path -Force
      $touchedAfterStart = ($currentItem.LastWriteTimeUtc -ge [datetime]$Guard['started_utc'])
    }

    if (-not $isKnown -and -not $createdAfterStart -and -not $touchedAfterStart) {
      continue
    }

    try {
      if ($hasSnapshot -and [bool]$snapshot['existed']) {
        $parent = Split-Path -Parent $path
        if ($parent) { New-Item -ItemType Directory -Force -Path $parent | Out-Null }
        [System.IO.File]::WriteAllBytes($path, [byte[]]$snapshot['bytes'])
        if ($null -ne $snapshot['last_write_time_utc']) {
          [System.IO.File]::SetLastWriteTimeUtc($path, [datetime]$snapshot['last_write_time_utc'])
        }
        if ($null -ne $snapshot['attributes']) {
          [System.IO.File]::SetAttributes($path, [System.IO.FileAttributes]$snapshot['attributes'])
        }
        $restoredCount += 1
      } elseif ($existsNow) {
        Remove-Item -LiteralPath $path -Force -ErrorAction Stop
        $deletedCount += 1
      }
    } catch {
      $failures.Add("CANONICAL_ARTIFACT_GUARD_FAILED path=$path error=$($_.Exception.Message)") | Out-Null
    }
  }

  $routeSurfaceClean = ($failures.Count -eq 0)
  foreach ($path in @($affectedPaths.Keys)) {
    $hasSnapshot = $Guard['snapshots'].ContainsKey($path)
    if (-not $hasSnapshot) {
      if (Test-Path -LiteralPath $path -PathType Leaf) { $routeSurfaceClean = $false }
      continue
    }

    $snapshot = $Guard['snapshots'][$path]
    $existsNow = Test-Path -LiteralPath $path -PathType Leaf
    if ([bool]$snapshot['existed']) {
      if (-not $existsNow) {
        $routeSurfaceClean = $false
      } else {
        $currentBytes = [System.IO.File]::ReadAllBytes($path)
        if (-not (Test-OwnerProofBytesEqual -Left $currentBytes -Right ([byte[]]$snapshot['bytes']))) {
          $routeSurfaceClean = $false
        }
      }
    } elseif ($existsNow -and [bool]$snapshot['known_canonical']) {
      $routeSurfaceClean = $false
    }
  }

  return [ordered]@{
    restored_count = $restoredCount
    deleted_count = $deletedCount
    failures = @($failures)
    route_surface_clean_after = $routeSurfaceClean
  }
}

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
Set-Location $repoRoot

if ([string]::IsNullOrWhiteSpace($RuntimeRoot)) {
  $RuntimeRoot = ".runtime/compact_owner_runtime_proof_{0}" -f (Get-Date).ToUniversalTime().ToString('yyyyMMdd_HHmmss')
}

$runtimeRootFull = ConvertTo-OwnerProofFullPath -Root $repoRoot -Path $RuntimeRoot
$runtimeParentFull = [System.IO.Path]::GetFullPath((Join-Path $repoRoot '.runtime'))
if (-not (Test-OwnerProofPathUnderRoot -Root $runtimeParentFull -Path $runtimeRootFull)) {
  throw "RUNTIME_ROOT_MUST_BE_UNDER_DOT_RUNTIME=$runtimeRootFull"
}

$proofCardRootFull = ConvertTo-OwnerProofFullPath -Root $repoRoot -Path $ProofCardRoot
$proofCardPath = Join-Path $proofCardRootFull ("compact_owner_runtime_proof_{0}.json" -f (Get-Date).ToUniversalTime().ToString('yyyyMMdd_HHmmss'))
$runtimeScript = Join-Path $repoRoot 'modules/run_ephemeral_candidate_controlled_runtime_v1.ps1'
$summaryPath = Join-Path $runtimeRootFull 'summary.json'

$branch = (Get-OwnerProofGitLines -RepoRoot $repoRoot -Arguments @('branch','--show-current') | Select-Object -First 1)
$head = (Get-OwnerProofGitLines -RepoRoot $repoRoot -Arguments @('rev-parse','HEAD') | Select-Object -First 1)
$gitStatusBefore = @(Get-OwnerProofGitLines -RepoRoot $repoRoot -Arguments @('status','--short'))
$canonicalArtifactGuard = New-OwnerProofCanonicalArtifactGuard -RepoRoot $repoRoot

$runtimeArgs = @(
  '-NoProfile',
  '-ExecutionPolicy', 'Bypass',
  '-File', $runtimeScript,
  '-MaxCycles', "$MaxCycles",
  '-BatchSize', "$BatchSize",
  '-RepoRoot', $repoRoot,
  '-RuntimeRoot', $runtimeRootFull,
  '-SummaryPath', $summaryPath,
  '-RetentionMode', $RetentionMode,
  '-CandidateGeneratorMode', $CandidateGeneratorMode
)

$runtimeExitCode = 1
$invokeFailure = ''
$pwshCommand = Get-Command pwsh -ErrorAction SilentlyContinue
if ($null -eq $pwshCommand) {
  $pwshCommand = Get-Command powershell -ErrorAction Stop
}

try {
  & $pwshCommand.Source @runtimeArgs *> $null
  $runtimeExitCode = if ($LASTEXITCODE -is [int]) { [int]$LASTEXITCODE } else { 0 }
} catch {
  $runtimeExitCode = 1
  $invokeFailure = $_.Exception.Message
}

$summaryExists = Test-Path -LiteralPath $summaryPath -PathType Leaf
$summary = $null
$summaryHash = ''
if ($summaryExists) {
  $summary = Get-Content -LiteralPath $summaryPath -Raw | ConvertFrom-Json
  $summaryHash = (Get-FileHash -LiteralPath $summaryPath -Algorithm SHA256).Hash.ToLowerInvariant()
}

$runtimeSize = Get-OwnerProofRuntimeSize -Path $runtimeRootFull
$leftoverTargetDirCount = if ($summaryExists) { Get-OwnerProofLeftoverTargetCount -RepoRoot $repoRoot -Summary $summary } else { 0 }

$summaryStatus = [string](Get-OwnerProofJsonValue -Object $summary -Name 'status' -Default '')
$completedCycles = [int](Get-OwnerProofJsonValue -Object $summary -Name 'completed_cycles' -Default 0)
$totalAccepted = [int](Get-OwnerProofJsonValue -Object $summary -Name 'total_accepted' -Default 0)
$totalReceipts = [int](Get-OwnerProofJsonValue -Object $summary -Name 'total_receipts' -Default 0)
$pendingCleanupFinalCount = [int](Get-OwnerProofJsonValue -Object $summary -Name 'pending_cleanup_final_count' -Default 0)
$pendingCleanupFinalBytes = [int64](Get-OwnerProofJsonValue -Object $summary -Name 'pending_cleanup_final_bytes' -Default 0)
$cleanupPressureEvents = [int](Get-OwnerProofJsonValue -Object $summary -Name 'cleanup_pressure_events' -Default 0)
$cleanupBackpressureEvents = [int](Get-OwnerProofJsonValue -Object $summary -Name 'cleanup_backpressure_events' -Default 0)
$cleanupBackpressureWaitSecondsTotal = [int](Get-OwnerProofJsonValue -Object $summary -Name 'cleanup_backpressure_wait_seconds_total' -Default 0)
$cleanupDrainIterationsTotal = [int](Get-OwnerProofJsonValue -Object $summary -Name 'cleanup_drain_iterations_total' -Default 0)
$runtimeReadyValue = Get-OwnerProofJsonValue -Object $summary -Name 'runtime_ready' -Default $null
$runtimeReady = if ($null -eq $runtimeReadyValue) { $null } else { [bool]$runtimeReadyValue }

$failures = [System.Collections.Generic.List[string]]::new()
if ($runtimeExitCode -ne 0) { Add-OwnerProofFailure -Failures $failures -Reason "RUNTIME_EXIT_CODE=$runtimeExitCode" }
if (-not [string]::IsNullOrWhiteSpace($invokeFailure)) { Add-OwnerProofFailure -Failures $failures -Reason "RUNTIME_INVOKE_FAILED=$invokeFailure" }
if (-not $summaryExists) { Add-OwnerProofFailure -Failures $failures -Reason 'SUMMARY_MISSING' }
if ($summaryExists -and $summaryStatus -ne 'PASS') { Add-OwnerProofFailure -Failures $failures -Reason "SUMMARY_STATUS=$summaryStatus" }
if ($completedCycles -ne $MaxCycles) { Add-OwnerProofFailure -Failures $failures -Reason "COMPLETED_CYCLES=$completedCycles" }
if ($totalAccepted -ne ($MaxCycles * $BatchSize)) { Add-OwnerProofFailure -Failures $failures -Reason "TOTAL_ACCEPTED=$totalAccepted" }
if ($totalReceipts -ne ($MaxCycles * $BatchSize)) { Add-OwnerProofFailure -Failures $failures -Reason "TOTAL_RECEIPTS=$totalReceipts" }
if ($pendingCleanupFinalCount -ne 0) { Add-OwnerProofFailure -Failures $failures -Reason "PENDING_CLEANUP_FINAL_COUNT=$pendingCleanupFinalCount" }
if ($pendingCleanupFinalBytes -ne 0) { Add-OwnerProofFailure -Failures $failures -Reason "PENDING_CLEANUP_FINAL_BYTES=$pendingCleanupFinalBytes" }
if ($leftoverTargetDirCount -ne 0) { Add-OwnerProofFailure -Failures $failures -Reason "LEFTOVER_TARGET_DIR_COUNT=$leftoverTargetDirCount" }
if ($runtimeReady -ne $false) { Add-OwnerProofFailure -Failures $failures -Reason "RUNTIME_READY=$runtimeReady" }

$ownerProofStatus = if ($failures.Count -eq 0) { 'PASS' } else { 'FAIL' }
$rawRuntimeRetention = if ($KeepRawRuntime) { 'KEPT' } else { 'DELETED' }
$rawRuntimeDeleted = $false

$proofCard = [ordered]@{
  schema = 'EFAB_COMPACT_OWNER_RUNTIME_PROOF_CARD_V1'
  created_utc = (Get-Date).ToUniversalTime().ToString('o')
  repo_root = $repoRoot
  branch = $branch
  head = $head
  git_status_short_before = @($gitStatusBefore)
  command = [ordered]@{
    runtime_script = $runtimeScript
    max_cycles = $MaxCycles
    batch_size = $BatchSize
    candidate_generator_mode = $CandidateGeneratorMode
    retention_mode = $RetentionMode
    proof_card_root = $proofCardRootFull
    runtime_root = $runtimeRootFull
    keep_raw_runtime = [bool]$KeepRawRuntime
  }
  runtime_arguments = @($runtimeArgs)
  runtime_root = $runtimeRootFull
  summary_path = $summaryPath
  runtime_exit_code = $runtimeExitCode
  summary_sha256 = $summaryHash
  status = $summaryStatus
  completed_cycles = $completedCycles
  total_accepted = $totalAccepted
  total_receipts = $totalReceipts
  pending_cleanup_final_count = $pendingCleanupFinalCount
  pending_cleanup_final_bytes = $pendingCleanupFinalBytes
  cleanup_pressure_events = $cleanupPressureEvents
  cleanup_backpressure_events = $cleanupBackpressureEvents
  cleanup_backpressure_wait_seconds_total = $cleanupBackpressureWaitSecondsTotal
  cleanup_drain_iterations_total = $cleanupDrainIterationsTotal
  leftover_target_dir_count = $leftoverTargetDirCount
  runtime_file_count_before_cleanup = [int]$runtimeSize['file_count']
  runtime_bytes_before_cleanup = [int64]$runtimeSize['bytes']
  canonical_artifact_guard_enabled = $true
  canonical_artifacts_snapshot_count = [int]$canonicalArtifactGuard['snapshots'].Count
  canonical_artifacts_restored_count = 0
  canonical_artifacts_deleted_count = 0
  canonical_artifact_guard_failures = @()
  route_surface_clean_after = $false
  raw_runtime_retention = $rawRuntimeRetention
  raw_runtime_deleted = $rawRuntimeDeleted
  runtime_ready = $runtimeReady
  owner_proof_status = $ownerProofStatus
  failure_reason = ($failures -join '; ')
}

Write-OwnerProofJson -Path $proofCardPath -Value $proofCard

$canonicalArtifactGuardResult = Restore-OwnerProofCanonicalArtifacts -RepoRoot $repoRoot -Guard $canonicalArtifactGuard
$proofCard['canonical_artifacts_restored_count'] = [int]$canonicalArtifactGuardResult['restored_count']
$proofCard['canonical_artifacts_deleted_count'] = [int]$canonicalArtifactGuardResult['deleted_count']
$proofCard['canonical_artifact_guard_failures'] = @($canonicalArtifactGuardResult['failures'])
$proofCard['route_surface_clean_after'] = [bool]$canonicalArtifactGuardResult['route_surface_clean_after']
foreach ($guardFailure in @($canonicalArtifactGuardResult['failures'])) {
  Add-OwnerProofFailure -Failures $failures -Reason $guardFailure
}
if (-not [bool]$canonicalArtifactGuardResult['route_surface_clean_after']) {
  Add-OwnerProofFailure -Failures $failures -Reason 'ROUTE_SURFACE_NOT_CLEAN_AFTER_GUARD'
}

if (-not $KeepRawRuntime) {
  try {
    if (Test-Path -LiteralPath $runtimeRootFull) {
      if (-not (Test-OwnerProofPathUnderRoot -Root $runtimeParentFull -Path $runtimeRootFull)) {
        throw "REFUSE_DELETE_OUTSIDE_DOT_RUNTIME=$runtimeRootFull"
      }
      Remove-Item -LiteralPath $runtimeRootFull -Recurse -Force -ErrorAction Stop
    }
    $rawRuntimeDeleted = (-not (Test-Path -LiteralPath $runtimeRootFull))
  } catch {
    $rawRuntimeDeleted = $false
    $rawRuntimeRetention = 'KEPT'
    Add-OwnerProofFailure -Failures $failures -Reason "RAW_RUNTIME_DELETE_FAILED=$($_.Exception.Message)"
  }
} else {
  $rawRuntimeRetention = 'KEPT'
  $rawRuntimeDeleted = $false
}

if ($failures.Count -gt 0) { $ownerProofStatus = 'FAIL' }
$proofCard['raw_runtime_retention'] = $rawRuntimeRetention
$proofCard['raw_runtime_deleted'] = $rawRuntimeDeleted
$proofCard['owner_proof_status'] = $ownerProofStatus
$proofCard['failure_reason'] = ($failures -join '; ')

Write-OwnerProofJson -Path $proofCardPath -Value $proofCard
$proofCard | ConvertTo-Json -Depth 100
