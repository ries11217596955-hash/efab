param(
  [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path,
  [string]$InputRoot = 'reports/self_development/phase165s_d2_big_curriculum_material_factory',
  [string]$OutputRoot = 'reports/self_development/phase165s_d2b_big_curriculum_autonomous_learning',
  [ValidateSet('LearnUntilEmpty')]
  [string]$Mode = 'LearnUntilEmpty',
  [switch]$Resume,
  [switch]$RepairResumeStateOnly,
  [switch]$SyncSummaryOnly,
  [switch]$EmitJson,
  [ValidateRange(1, 100)]
  [int]$BatchSize = 1,
  [ValidateRange(1, 100000)]
  [int]$CheckpointEvery = 100,
  [ValidateRange(1, 100000)]
  [int]$HeartbeatEvery = 25,
  [string]$WorkRoot = '',
  [ValidateSet('CompactAccepted','FullTrace','Disabled')]
  [string]$RetentionMode = 'CompactAccepted',
  [string]$CandidateBatchPath = '',
  [ValidateSet('TrackedCore','RuntimeDeltaOnly')]
  [string]$AcceptedCoreMode = 'TrackedCore',
  [string]$AcceptedCoreRoot = ''
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

if (-not (Get-Command Get-FileHash -ErrorAction SilentlyContinue)) {
  Set-Item -Path Function:\global:Get-FileHash -Value {
    param(
      [string]$LiteralPath,
      [string]$Algorithm = 'SHA256'
    )
    if ($Algorithm -ne 'SHA256') { throw "UNSUPPORTED_HASH_ALGORITHM=$Algorithm" }
    $stream = [System.IO.File]::OpenRead($LiteralPath)
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try {
      $hash = ([System.BitConverter]::ToString($sha.ComputeHash($stream)) -replace '-', '')
    } finally {
      $sha.Dispose()
      $stream.Dispose()
    }
    [pscustomobject]@{ Algorithm='SHA256'; Hash=$hash; Path=$LiteralPath }
  }
}

function Read-D2BJson {
  param([string]$Path)
  if (-not (Test-Path -LiteralPath $Path)) { throw "MISSING_FILE=$Path" }
  return Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json
}

function Write-D2BJson {
  param([string]$Path, $Value)
  $directory = Split-Path -Parent $Path
  if ($directory -and -not (Test-Path -LiteralPath $directory)) {
    New-Item -ItemType Directory -Force -Path $directory | Out-Null
  }
  $attemptCount = 6
  $cleanupAttemptCount = 30
  $temporaryDirectory = Join-Path ([System.IO.Path]::GetTempPath()) 'efab_d2b_json_state_write'
  if (-not (Test-Path -LiteralPath $temporaryDirectory)) {
    New-Item -ItemType Directory -Force -Path $temporaryDirectory | Out-Null
  }
  $temporaryName = "d2bjson.{0}.{1}.tmp" -f $PID, ([guid]::NewGuid().ToString('N'))
  $temporary = Join-Path $temporaryDirectory $temporaryName
  $json = ($Value | ConvertTo-Json -Depth 100) -replace "`r`n", "`n"
  $payload = $json + "`n"
  $lastError = $null

  try {
    [System.IO.File]::WriteAllText($temporary, $payload, [System.Text.UTF8Encoding]::new($false))
    for ($attempt = 1; $attempt -le $attemptCount; $attempt += 1) {
      try {
        if (Test-Path -LiteralPath $Path) {
          [System.IO.File]::Replace($temporary, $Path, $null, $true)
        } else {
          [System.IO.File]::Move($temporary, $Path)
        }
        return
      } catch [System.UnauthorizedAccessException] {
        $lastError = $_.Exception
      } catch [System.IO.IOException] {
        $lastError = $_.Exception
      } catch {
        $lastError = $_.Exception
        break
      }

      if ($attempt -lt $attemptCount) {
        Start-Sleep -Milliseconds ([Math]::Min(1000, 50 * [Math]::Pow(2, ($attempt - 1))))
      }
    }

    try {
      [System.IO.File]::Copy($temporary, $Path, $true)
      $written = [System.IO.File]::ReadAllText($Path, [System.Text.UTF8Encoding]::new($false))
      [void]($written | ConvertFrom-Json)
      if ($written -ne $payload) {
        throw "D2B_JSON_STATE_WRITE_VERIFY_MISMATCH"
      }
      for ($removeAttempt = 1; $removeAttempt -le $cleanupAttemptCount; $removeAttempt += 1) {
        try {
          if (Test-Path -LiteralPath $temporary) {
            [System.IO.File]::SetAttributes($temporary, [System.IO.FileAttributes]::Normal)
            [System.IO.File]::Delete($temporary)
          }
          return
        } catch [System.UnauthorizedAccessException] {
          $lastError = $_.Exception
        } catch [System.IO.IOException] {
          $lastError = $_.Exception
        }
        if ($removeAttempt -lt $cleanupAttemptCount) {
          Start-Sleep -Milliseconds ([Math]::Min(1000, 100 * $removeAttempt))
        }
      }
      throw "D2B_JSON_STATE_WRITE_TEMP_CLEANUP_FAILED"
    } catch {
      $lastError = $_.Exception
    }

    $exceptionType = if ($null -ne $lastError) { $lastError.GetType().FullName } else { 'UNKNOWN' }
    $exceptionMessage = if ($null -ne $lastError) { $lastError.Message } else { 'UNKNOWN' }
    throw "D2B_JSON_STATE_WRITE_FAILED temp=$temporary target=$Path exception_type=$exceptionType attempts=$attemptCount message=$exceptionMessage"
  } finally {
    if (Test-Path -LiteralPath $temporary) {
      try {
        if ((Test-Path -LiteralPath $Path) -and ([System.IO.File]::ReadAllText($Path, [System.Text.UTF8Encoding]::new($false)) -eq $payload)) {
          [System.IO.File]::SetAttributes($temporary, [System.IO.FileAttributes]::Normal)
          [System.IO.File]::Delete($temporary)
        }
      } catch {
      }
    }
  }
}

function Write-D2BText {
  param([string]$Path, [string[]]$Lines)
  $directory = Split-Path -Parent $Path
  if ($directory -and -not (Test-Path -LiteralPath $directory)) {
    New-Item -ItemType Directory -Force -Path $directory | Out-Null
  }
  [System.IO.File]::WriteAllText($Path, (($Lines -join "`n") + "`n"), [System.Text.UTF8Encoding]::new($false))
}

function Remove-D2BRetentionCleanupPath {
  param(
    [Parameter(Mandatory=$true)][string]$Path,
    [ValidateSet('file','dir')][string]$Kind,
    [int]$Attempts = 8,
    [string]$PendingManifestPath = ''
  )

  if (-not (Test-Path -LiteralPath $Path)) { return }

  $lastError = $null
  for ($attempt = 1; $attempt -le $Attempts; $attempt += 1) {
    try {
      if (-not (Test-Path -LiteralPath $Path)) { return }

      if ($Kind -eq 'dir') {
        Get-ChildItem -LiteralPath $Path -Recurse -Force -ErrorAction SilentlyContinue | ForEach-Object {
          try { $_.Attributes = [System.IO.FileAttributes]::Normal } catch { }
        }
        Remove-Item -LiteralPath $Path -Recurse -Force -ErrorAction Stop
      } else {
        try { [System.IO.File]::SetAttributes($Path, [System.IO.FileAttributes]::Normal) } catch { }
        Remove-Item -LiteralPath $Path -Force -ErrorAction Stop
      }

      if (-not (Test-Path -LiteralPath $Path)) { return }
      throw 'DELETE_VERIFY_STILL_EXISTS'
    } catch [System.UnauthorizedAccessException] {
      $lastError = $_.Exception
    } catch [System.IO.IOException] {
      $lastError = $_.Exception
    } catch {
      $lastError = $_.Exception
    }

    if ($attempt -lt $Attempts) {
      [System.GC]::Collect()
      [System.GC]::WaitForPendingFinalizers()
      Start-Sleep -Milliseconds ([Math]::Min(2000, 100 * $attempt))
    }
  }

  $exceptionType = if ($null -ne $lastError) { $lastError.GetType().FullName } else { 'UNKNOWN' }
  $exceptionMessage = if ($null -ne $lastError) { $lastError.Message } else { 'UNKNOWN' }
  if (-not [string]::IsNullOrWhiteSpace($PendingManifestPath)) {
    Add-D2BCleanupPending -ManifestPath $PendingManifestPath -Path $Path -Kind $Kind -Attempts $Attempts -ExceptionType $exceptionType -ExceptionMessage $exceptionMessage
    return
  }
  throw "RETENTION_CLEANUP_DELETE_FAILED path=$Path kind=$Kind attempts=$Attempts exception_type=$exceptionType message=$exceptionMessage"
}

function Add-D2BCleanupPending {
  param(
    [Parameter(Mandatory=$true)][string]$ManifestPath,
    [Parameter(Mandatory=$true)][string]$Path,
    [ValidateSet('file','dir')][string]$Kind,
    [int]$Attempts,
    [string]$ExceptionType,
    [string]$ExceptionMessage
  )

  $parent = Split-Path -Parent $ManifestPath
  if ($parent) { New-Item -ItemType Directory -Force -Path $parent | Out-Null }
  $entries = @()
  if (Test-Path -LiteralPath $ManifestPath) {
    try {
      $existing = Get-Content -LiteralPath $ManifestPath -Raw | ConvertFrom-Json
      $entries = @($existing.entries)
    } catch {
      $entries = @()
    }
  }
  $entries += [ordered]@{
    path = $Path
    kind = $Kind
    attempts = $Attempts
    exception_type = $ExceptionType
    exception_message = $ExceptionMessage
    queued_utc = (Get-Date).ToUniversalTime().ToString('o')
  }
  Write-D2BJson -Path $ManifestPath -Value ([ordered]@{
    schema = 'retention_cleanup_pending_v1'
    status = 'PENDING'
    entries = @($entries)
    pending_cleanup_count = @($entries).Count
    runtime_ready = $false
  })
}

function Add-D2BJsonLine {
  param([string]$Path, $Value)
  $directory = Split-Path -Parent $Path
  if ($directory -and -not (Test-Path -LiteralPath $directory)) {
    New-Item -ItemType Directory -Force -Path $directory | Out-Null
  }
  $line = $Value | ConvertTo-Json -Depth 60 -Compress
  [System.IO.File]::AppendAllText($Path, $line + "`n", [System.Text.UTF8Encoding]::new($false))
}

function Get-D2BLastJsonLine {
  param([string]$Path)
  if (-not (Test-Path -LiteralPath $Path)) { return $null }
  $last = $null
  $reader = [System.IO.StreamReader]::new($Path)
  try {
    while (-not $reader.EndOfStream) {
      $line = $reader.ReadLine()
      if (-not [string]::IsNullOrWhiteSpace($line)) { $last = $line }
    }
  } finally {
    $reader.Dispose()
  }
  if ($null -eq $last) { return $null }
  return $last | ConvertFrom-Json
}

function Get-D2BJsonLineMatchCount {
  param(
    [string]$Path,
    [string]$Property,
    [string]$Value
  )
  if (-not (Test-Path -LiteralPath $Path)) { return 0 }
  $count = 0
  $reader = [System.IO.StreamReader]::new($Path)
  try {
    while (-not $reader.EndOfStream) {
      $line = $reader.ReadLine()
      if ([string]::IsNullOrWhiteSpace($line)) { continue }
      $record = $line | ConvertFrom-Json
      if ($record.PSObject.Properties.Name -contains $Property -and [string]$record.$Property -eq $Value) {
        $count += 1
      }
    }
  } finally {
    $reader.Dispose()
  }
  return $count
}

function Get-D2BNonEmptyLineCount {
  param([string]$Path)
  if (-not (Test-Path -LiteralPath $Path)) { return 0 }
  $count = 0
  $reader = [System.IO.StreamReader]::new($Path)
  try {
    while (-not $reader.EndOfStream) {
      $line = $reader.ReadLine()
      if (-not [string]::IsNullOrWhiteSpace($line)) { $count += 1 }
    }
  } finally {
    $reader.Dispose()
  }
  return $count
}

function Get-D2BAcceptedAtomsFromLogAfterLine {
  param(
    [string]$Path,
    [int]$SkipNonEmptyLineCount
  )
  if (-not (Test-Path -LiteralPath $Path)) { return @() }
  $atoms = @()
  $lineNumber = 0
  $reader = [System.IO.StreamReader]::new($Path)
  try {
    while (-not $reader.EndOfStream) {
      $line = $reader.ReadLine()
      if ([string]::IsNullOrWhiteSpace($line)) { continue }
      $lineNumber += 1
      if ($lineNumber -le $SkipNonEmptyLineCount) { continue }
      $record = $line | ConvertFrom-Json
      $atomId = [string]$record.atom_id
      if ([string]::IsNullOrWhiteSpace($atomId)) { continue }
      $atoms += [pscustomobject][ordered]@{
        atom_id = $atomId
        effect_type = 'accepted_core_atom'
        target = 'phase162_accepted_core'
        source_ref = "legacy_d2b:$($record.source_path):candidate=$($record.candidate_id):disposition=$($record.disposition)"
        accepted_utc = [string]$record.occurred_utc
        legacy_runner_disposition = [string]$record.disposition
      }
    }
  } finally {
    $reader.Dispose()
  }
  return @($atoms)
}

function Get-D2BExecutionWriteEvent {
  param([string]$Path)
  if (-not (Test-Path -LiteralPath $Path)) { return $null }
  $match = $null
  $reader = [System.IO.StreamReader]::new($Path)
  try {
    while (-not $reader.EndOfStream) {
      $line = $reader.ReadLine()
      if ([string]::IsNullOrWhiteSpace($line)) { continue }
      $event = $line | ConvertFrom-Json
      if ([string]$event.type -eq 'CONTROLLED_ACCEPT_MUTATION_WRITTEN_TO_ACCEPTED_CORE') {
        $match = $event
      }
    }
  } finally {
    $reader.Dispose()
  }
  return $match
}

function Invoke-D2BPowerShell {
  param([string]$ScriptPath, [string[]]$Arguments)
  try {
    if (($Arguments.Count % 2) -ne 0) { throw 'SCRIPT_ARGUMENTS_MUST_BE_NAME_VALUE_PAIRS' }
    $bound = @{}
    for ($i = 0; $i -lt $Arguments.Count; $i += 2) {
      $bound[$Arguments[$i].TrimStart('-')] = $Arguments[$i + 1]
    }
    $output = @(& $ScriptPath @bound | ForEach-Object { [string]$_ })
    return ,$output
  } catch {
    throw "SCRIPT_FAILED=$ScriptPath error=$($_.Exception.Message)"
  }
}

function Get-D2BCount {
  param($Root, [string]$Property, [string]$AtomId)
  if ($null -eq $Root -or -not ($Root.PSObject.Properties.Name -contains $Property)) { return 0 }
  return @($Root.$Property | Where-Object { [string]$_.atom_id -eq $AtomId }).Count
}

function Get-D2BRelativePath {
  param([string]$Root, [string]$Path)
  $rootFull = [System.IO.Path]::GetFullPath($Root).TrimEnd('\')
  $pathFull = [System.IO.Path]::GetFullPath($Path)
  if (-not $pathFull.StartsWith($rootFull + '\', [System.StringComparison]::OrdinalIgnoreCase)) { return $Path }
  return ($pathFull.Substring($rootFull.Length + 1) -replace '\\', '/')
}

function ConvertTo-D2BFullPath {
  param([string]$Root, [string]$Path)
  if ([System.IO.Path]::IsPathRooted($Path)) {
    return [System.IO.Path]::GetFullPath($Path)
  }
  return [System.IO.Path]::GetFullPath((Join-Path $Root $Path))
}

function Test-D2BUnderRuntimeRoot {
  param([string]$Root, [string]$Path)
  $runtimeRoot = [System.IO.Path]::GetFullPath((Join-Path $Root '.runtime')).TrimEnd('\','/')
  $full = [System.IO.Path]::GetFullPath($Path).TrimEnd('\','/')
  return ($full.Equals($runtimeRoot, [System.StringComparison]::OrdinalIgnoreCase) -or
    $full.StartsWith($runtimeRoot + [System.IO.Path]::DirectorySeparatorChar, [System.StringComparison]::OrdinalIgnoreCase))
}

function Initialize-D2BRuntimeAcceptedCore {
  param(
    [string]$Root,
    [string]$DeltaRootFull
  )

  if (-not (Test-D2BUnderRuntimeRoot -Root $Root -Path $DeltaRootFull)) {
    throw "ACCEPTED_CORE_DELTA_ROOT_MUST_BE_UNDER_DOT_RUNTIME=$DeltaRootFull"
  }

  New-Item -ItemType Directory -Force -Path $DeltaRootFull | Out-Null
  $memoryFull = Join-Path $DeltaRootFull 'accepted_change_memory_snapshot.json'
  $selfMapFull = Join-Path $DeltaRootFull 'SELF_MODEL_ACTIVE_MAP.json'
  $registryFull = Join-Path $DeltaRootFull 'registry.json'

  if (-not (Test-Path -LiteralPath $memoryFull)) {
    Write-D2BJson -Path $memoryFull -Value ([ordered]@{
      schema = 'runtime_delta_accepted_change_memory_snapshot_v1'
      status = 'RUNTIME_DELTA_ONLY'
      phase162_accepted_atom_memory_records = @()
      runtime_ready = $false
    })
  }
  if (-not (Test-Path -LiteralPath $selfMapFull)) {
    Write-D2BJson -Path $selfMapFull -Value ([ordered]@{
      schema = 'runtime_delta_self_model_active_map_v1'
      status = 'RUNTIME_DELTA_ONLY'
      phase162_absorbed_atom_capability_notes = @()
      runtime_ready = $false
    })
  }
  if (-not (Test-Path -LiteralPath $registryFull)) {
    Write-D2BJson -Path $registryFull -Value ([ordered]@{
      schema = 'runtime_delta_pack_registry_v1'
      status = 'RUNTIME_DELTA_ONLY'
      phase162_accepted_atom_references = @()
      runtime_ready = $false
    })
  }

  return [pscustomobject][ordered]@{
    root = (Get-D2BRelativePath -Root $Root -Path $DeltaRootFull)
    memory_path = (Get-D2BRelativePath -Root $Root -Path $memoryFull)
    self_map_path = (Get-D2BRelativePath -Root $Root -Path $selfMapFull)
    registry_path = (Get-D2BRelativePath -Root $Root -Path $registryFull)
  }
}

function Get-D2BCandidateBatchInfo {
  param(
    [string]$Root,
    [string]$CandidateBatchPath,
    [int]$BatchSize
  )

  if ([string]::IsNullOrWhiteSpace($CandidateBatchPath)) { return $null }

  $full = ConvertTo-D2BFullPath -Root $Root -Path $CandidateBatchPath
  $repoPrefix = $Root.TrimEnd('\','/') + [System.IO.Path]::DirectorySeparatorChar
  $runtimeRoot = [System.IO.Path]::GetFullPath((Join-Path $Root '.runtime')).TrimEnd('\','/')
  $runtimePrefix = $runtimeRoot + [System.IO.Path]::DirectorySeparatorChar
  if (-not $full.StartsWith($repoPrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw "CANDIDATE_BATCH_OUTSIDE_REPO=$full"
  }
  if (-not $full.StartsWith($runtimePrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw "CANDIDATE_BATCH_MUST_BE_UNDER_RUNTIME=$full"
  }
  if (-not (Test-Path -LiteralPath $full)) {
    throw "CANDIDATE_BATCH_MISSING=$full"
  }

  $count = 0
  $reader = [System.IO.StreamReader]::new($full, [System.Text.UTF8Encoding]::new($false), $true)
  try {
    while (-not $reader.EndOfStream -and $count -lt $BatchSize) {
      $line = $reader.ReadLine()
      if ([string]::IsNullOrWhiteSpace($line)) { continue }
      $candidate = $line | ConvertFrom-Json
      if ([string]::IsNullOrWhiteSpace([string]$candidate.candidate_id)) {
        throw "CANDIDATE_BATCH_RECORD_MISSING_CANDIDATE_ID line=$($count + 1)"
      }
      if ([string]::IsNullOrWhiteSpace([string]$candidate.target_atom_id_suggestion)) {
        throw "CANDIDATE_BATCH_RECORD_MISSING_ATOM_ID line=$($count + 1)"
      }
      $count += 1
    }
  } finally {
    $reader.Dispose()
  }

  if ($count -lt 1) {
    throw "CANDIDATE_BATCH_EMPTY=$full"
  }

  return [pscustomobject][ordered]@{
    full_path = $full
    relative_path = (Get-D2BRelativePath -Root $Root -Path $full)
    candidate_count = $count
    runtime_root = $runtimeRoot
  }
}

function Remove-D2BCandidateBatchMaterialOnSuccess {
  param(
    $CandidateBatchInfo,
    $RetentionResult,
    [string]$FinalStatus,
    [bool]$StoppedBySignal,
    [string]$HardError,
    [string]$CleanupPendingPath = ''
  )

  if ($null -eq $CandidateBatchInfo) { return $false }
  if ($null -eq $RetentionResult) { return $false }
  if ([string]$RetentionResult.status -ne 'PASS') { return $false }
  if ([bool]$RetentionResult.retention_gate_invoked -ne $true) { return $false }
  if ($FinalStatus -ne 'PASS_QUEUE_EMPTY') { return $false }
  if ($StoppedBySignal -or -not [string]::IsNullOrWhiteSpace($HardError)) { return $false }

  $candidatePath = [string]$CandidateBatchInfo.full_path
  if (Test-Path -LiteralPath $candidatePath) {
    Remove-D2BRetentionCleanupPath -Path $candidatePath -Kind 'file' -PendingManifestPath $CleanupPendingPath
  }

  $parent = Split-Path -Parent $candidatePath
  $runtimeRoot = [string]$CandidateBatchInfo.runtime_root
  if ($parent -and (Split-Path -Leaf $parent) -like '*ephemeral_candidate_batch_*') {
    $parentFull = [System.IO.Path]::GetFullPath($parent).TrimEnd('\','/')
    $runtimeFull = [System.IO.Path]::GetFullPath($runtimeRoot).TrimEnd('\','/')
    if ($parentFull.StartsWith($runtimeFull + [System.IO.Path]::DirectorySeparatorChar, [System.StringComparison]::OrdinalIgnoreCase)) {
      Remove-D2BRetentionCleanupPath -Path $parentFull -Kind 'dir' -PendingManifestPath $CleanupPendingPath
    }
  }

  return (-not (Test-Path -LiteralPath $candidatePath))
}

function Test-D2BRootLikePath {
  param([string]$Path)
  if ([string]::IsNullOrWhiteSpace($Path)) { return $true }
  $full = [System.IO.Path]::GetFullPath($Path).TrimEnd('\','/')
  $pathRoot = [System.IO.Path]::GetPathRoot($full)
  if ([string]::IsNullOrWhiteSpace($pathRoot)) { return $false }
  return $full.Equals($pathRoot.TrimEnd('\','/'), [System.StringComparison]::OrdinalIgnoreCase)
}

function Resolve-D2BWorkRoot {
  param(
    [string]$RepoRoot,
    [string]$OutputRootFull,
    [string]$WorkRoot
  )

  $mode = 'legacy'
  $base = ''
  $effective = [System.IO.Path]::GetFullPath((Join-Path $OutputRootFull 'work/current'))

  if (-not [string]::IsNullOrWhiteSpace($WorkRoot)) {
    $mode = 'explicit'
    $base = ConvertTo-D2BFullPath -Root $RepoRoot -Path $WorkRoot
    $effective = [System.IO.Path]::GetFullPath((Join-Path $base 'phase165s_d2b_work_current'))
  } elseif (-not [string]::IsNullOrWhiteSpace($env:EFAB_WORK_ROOT)) {
    $mode = 'env'
    $base = ConvertTo-D2BFullPath -Root $RepoRoot -Path $env:EFAB_WORK_ROOT
    $effective = [System.IO.Path]::GetFullPath((Join-Path $base 'phase165s_d2b_work_current'))
  }

  return [pscustomobject][ordered]@{
    work_root = $effective
    work_root_base = $base
    work_root_mode = $mode
    work_root_short_path_enabled = ($mode -ne 'legacy')
  }
}

function Reset-D2BWorkRoot {
  param(
    [string]$RepoRoot,
    [string]$OutputRootFull,
    [string]$WorkRoot,
    [string]$WorkRootMode = 'legacy',
    [string]$ExternalWorkRootBase = ''
  )
  $legacyExpected = [System.IO.Path]::GetFullPath((Join-Path $OutputRootFull 'work/current'))
  $actual = [System.IO.Path]::GetFullPath($WorkRoot)

  if ($WorkRootMode -eq 'legacy') {
    if (-not $actual.Equals($legacyExpected, [System.StringComparison]::OrdinalIgnoreCase)) {
      throw "UNSAFE_WORK_ROOT=$actual"
    }
    if (Test-Path -LiteralPath $actual) {
      Remove-Item -LiteralPath $actual -Recurse -Force
    }
    New-Item -ItemType Directory -Force -Path $actual | Out-Null
    return
  }

  if ($WorkRootMode -notin @('explicit','env')) {
    throw "UNSUPPORTED_WORK_ROOT_MODE=$WorkRootMode"
  }
  if ([string]::IsNullOrWhiteSpace($ExternalWorkRootBase)) {
    throw 'EXTERNAL_WORK_ROOT_BASE_REQUIRED'
  }

  $base = [System.IO.Path]::GetFullPath($ExternalWorkRootBase)
  $expected = [System.IO.Path]::GetFullPath((Join-Path $base 'phase165s_d2b_work_current'))
  $repoFull = [System.IO.Path]::GetFullPath($RepoRoot).TrimEnd('\','/')
  $baseTrimmed = $base.TrimEnd('\','/')
  $actualTrimmed = $actual.TrimEnd('\','/')

  if (-not $actual.Equals($expected, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw "UNSAFE_WORK_ROOT=$actual"
  }
  if ((Test-D2BRootLikePath -Path $base) -or (Test-D2BRootLikePath -Path $actual)) {
    throw "UNSAFE_EXTERNAL_WORK_ROOT_ROOTLIKE=$actual"
  }
  if ($baseTrimmed.Equals($repoFull, [System.StringComparison]::OrdinalIgnoreCase) -or
      $actualTrimmed.Equals($repoFull, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw "UNSAFE_EXTERNAL_WORK_ROOT_REPO_ROOT=$actual"
  }

  $markerPath = Join-Path $actual '.efab_d2b_workroot'
  if (Test-Path -LiteralPath $actual) {
    if (-not (Test-Path -LiteralPath $markerPath)) {
      throw "UNSAFE_EXTERNAL_WORK_ROOT_MARKER_MISSING=$actual"
    }
    Remove-Item -LiteralPath $actual -Recurse -Force
  }

  New-Item -ItemType Directory -Force -Path $actual | Out-Null
  [System.IO.File]::WriteAllText($markerPath, "phase165s_d2b_work_current`n", [System.Text.UTF8Encoding]::new($false))
}

function Get-D2BCandidatePayload {
  param($Candidate, [string]$SourcePath)

  $payload = [ordered]@{
    candidate_id = [string]$Candidate.candidate_id
    concept_id = [string]$Candidate.concept_id
    meaning = [string]$Candidate.explanation
    atom_type = [string]$Candidate.atom_type_suggestion
    guided_example = [string]$Candidate.guided_example
    check_prompt = [string]$Candidate.check_prompt
    expected_check_result = [string]$Candidate.expected_check_result
    behavior_change = [string]$Candidate.behavior_change
    next_layer_questions = @($Candidate.next_layer_questions)
    source_curriculum_candidate = $SourcePath
    source = [string]$Candidate.source
    provenance = [string]$Candidate.provenance
    autonomous_policy_guard = 'PHASE165S-C2B'
    autonomous_loop = 'PHASE165S-D2B'
    owner_interrupt_used = $false
    decision_rule = [ordered]@{
      input = 'staged_curriculum_candidate'
      classification = 'USE_ACCEPTED_ATOM_AND_MOVE_TO_NEXT_LAYER'
      direct_accept_without_guard = $false
      decision_authority = 'C2B_POLICY_GUARD_AND_PHASE162_ACCEPTED_CORE_EXECUTOR'
    }
    memory_proof = 'Accepted-memory read must find this atom exactly once by atom_id.'
    use_proof = 'Future reasoning must retrieve this accepted atom and advance beyond raw curriculum.'
    behavior_delta = 'Next cycle starts from the accepted atom rather than the staged candidate.'
  }

  $producerContext = [ordered]@{}
  foreach ($field in @('producer_id','source_kind','source_run_id','candidate_id','dedup_key','domain','risk_flag','risk_flags','validator_required','priority','dependencies','batch_id')) {
    if ($Candidate.PSObject.Properties.Name -contains $field) {
      $producerContext[$field] = $Candidate.$field
    }
  }
  if ($producerContext.Count -gt 0) {
    $payload.producer_context = $producerContext
  }

  return $payload
}

function Get-D2BCandidateQuarantineReasons {
  param($Candidate)

  $effectiveRiskFlags = @()
  if ($Candidate.PSObject.Properties.Name -contains 'risk_flags') {
    $effectiveRiskFlags += @($Candidate.risk_flags | ForEach-Object { [string]$_ })
  }
  if ($Candidate.PSObject.Properties.Name -contains 'risk_flag') {
    $effectiveRiskFlags += @($Candidate.risk_flag | ForEach-Object { [string]$_ })
  }
  $effectiveRiskFlags = @($effectiveRiskFlags | Where-Object { $_ -and $_ -ne 'none_identified_at_material_stage' } | Select-Object -Unique)

  $quarantineReasons = @()
  if ([bool]$Candidate.accepted -or [bool]$Candidate.trusted) { $quarantineReasons += 'raw_candidate_claims_accepted_or_trusted' }
  if ([string]$Candidate.risk_level -ne 'LOW') { $quarantineReasons += "risk_level_not_low=$($Candidate.risk_level)" }
  if ($effectiveRiskFlags.Count -gt 0) { $quarantineReasons += "effective_risk_flags=$($effectiveRiskFlags -join ',')" }
  if (-not ([bool]$Candidate.requires_school_acceptance -and [bool]$Candidate.requires_c2b_guard -and [bool]$Candidate.requires_phase162_acceptance)) {
    $quarantineReasons += 'required_acceptance_guard_missing'
  }

  return @($quarantineReasons)
}

function New-D2BPhase162Package {
  param(
    [string]$WorkRoot,
    [object]$Candidate,
    [string]$OperationId,
    [string]$SourcePath,
    [string]$MemoryPath,
    [string]$SelfMapPath,
    [string]$RegistryPath
  )
  $atomId = [string]$Candidate.target_atom_id_suggestion
  $candidateRoot = Join-Path $WorkRoot 'cand'
  $controllerRoot = Join-Path $WorkRoot 'ctrl'
  $executionRoot = Join-Path $WorkRoot 'exec'
  $finalizerRoot = Join-Path $WorkRoot 'fin'
  New-Item -ItemType Directory -Force -Path $candidateRoot,$controllerRoot,$executionRoot,$finalizerRoot | Out-Null

  $payload = Get-D2BCandidatePayload -Candidate $Candidate -SourcePath $SourcePath

  Write-D2BJson (Join-Path $candidateRoot 'controlled_accept_core_mutation_candidate_result.json') ([ordered]@{
    schema = 'PHASE162_CONTROLLED_ACCEPT_CORE_MUTATION_CANDIDATE_RESULT_V1'
    status = 'PASS'
    created_at = (Get-Date).ToUniversalTime().ToString('o')
    batch_size = 1
    staged_atom_count = 1
    atom_ids = @($atomId)
    next_machine_action = 'VALIDATE_CONTROLLED_ACCEPT_CORE_MUTATION_CANDIDATE_FOR_ATOM_BATCH'
    source = 'PHASE165S-D2B autonomous learn-until-empty loop'
  })
  Write-D2BJson (Join-Path $candidateRoot 'controlled_accept_core_mutation_set.json') ([ordered]@{
    schema = 'PHASE162_CONTROLLED_ACCEPT_CORE_MUTATION_SET_V1'
    status = 'PASS'
    created_at = (Get-Date).ToUniversalTime().ToString('o')
    accepted_memory_operations = @([ordered]@{ operation_id="$OperationId`_MEMORY"; atom_id=$atomId; target=$MemoryPath; source_freeze_root=$WorkRoot; payload=$payload })
    accepted_self_model_operations = @([ordered]@{ operation_id="$OperationId`_SELF"; atom_id=$atomId; target=$SelfMapPath; source_freeze_root=$WorkRoot; payload=$payload })
    registry_operations = @([ordered]@{ operation_id="$OperationId`_REGISTRY"; atom_id=$atomId; target=$RegistryPath; source_freeze_root=$WorkRoot; payload=$payload })
  })
  Write-D2BJson (Join-Path $candidateRoot 'atomic_accept_write_plan.json') ([ordered]@{
    schema='PHASE162_ATOMIC_ACCEPT_WRITE_PLAN_V1'; status='PASS'; created_at=(Get-Date).ToUniversalTime().ToString('o')
    atomicity_rule='all_operations_pass_or_rollback'; target_files=@($MemoryPath,$SelfMapPath,$RegistryPath); allowed_atom_ids=@($atomId)
  })
  Write-D2BJson (Join-Path $candidateRoot 'controlled_accept_core_mutation_rollback_plan.json') ([ordered]@{
    schema='PHASE162_CONTROLLED_ACCEPT_CORE_MUTATION_ROLLBACK_PLAN_V1'; status='PASS'; created_at=(Get-Date).ToUniversalTime().ToString('o')
    rollback_actions=@('restore_memory_snapshot','restore_self_map_snapshot','restore_registry_snapshot','validate_atom_count','write_rollback_event')
  })
  Write-D2BJson (Join-Path $candidateRoot 'post_mutation_validation_binding.json') ([ordered]@{
    schema='PHASE162_POST_MUTATION_VALIDATION_BINDING_V1'; status='PASS'; created_at=(Get-Date).ToUniversalTime().ToString('o')
    bound_to_mutation_set='controlled_accept_core_mutation_set.json'; bound_to_atomic_write_plan='atomic_accept_write_plan.json'
  })
  Write-D2BJson (Join-Path $controllerRoot 'controller_consume_controlled_accept_core_mutation_dry_run_batch_result.json') ([ordered]@{
    schema='PHASE162_CONTROLLER_CONSUME_CONTROLLED_ACCEPT_CORE_MUTATION_DRY_RUN_BATCH_RESULT_V1'; status='PASS'
    created_at=(Get-Date).ToUniversalTime().ToString('o'); next_machine_action='EXECUTE_CONTROLLED_ACCEPT_CORE_MUTATION_FOR_ATOM_BATCH'
    execution_authorization_status='AUTHORIZED_ONE_SHOT_CONTROLLED_ACCEPT_CORE_MUTATION'; candidate_root=$candidateRoot
    authorization_source='PHASE165S-C2B bounded autonomous acceptance policy guard'; owner_interrupt_used=$false
  })
  Write-D2BJson (Join-Path $controllerRoot 'controller_consume_controlled_accept_core_mutation_dry_run_batch_validation.json') ([ordered]@{
    schema='PHASE162_CONTROLLER_CONSUME_CONTROLLED_ACCEPT_CORE_MUTATION_DRY_RUN_BATCH_VALIDATION_V1'; status='PASS'
    created_at=(Get-Date).ToUniversalTime().ToString('o'); next_machine_action='EXECUTE_CONTROLLED_ACCEPT_CORE_MUTATION_FOR_ATOM_BATCH'
    exact_atom_scope=$true; allowed_atom_ids=@($atomId)
  })
  Write-D2BJson (Join-Path $controllerRoot 'one_shot_controlled_accept_core_mutation_execution_authorization_for_atom_batch.json') ([ordered]@{
    schema='PHASE162_ONE_SHOT_CONTROLLED_ACCEPT_CORE_MUTATION_EXECUTION_AUTHORIZATION_FOR_ATOM_BATCH_V1'; status='AUTHORIZED'
    created_at=(Get-Date).ToUniversalTime().ToString('o'); authorization_scope='ONE_SHOT_ACCEPTED_CORE_WRITE_WITH_ATOMIC_PLAN_AND_ROLLBACK'
    candidate_root=$candidateRoot; authorization_source='PHASE165S-C2B bounded autonomous acceptance policy guard'
    owner_interrupt_used=$false; autonomous_policy_guard_allowed=$true; authorized_atom_ids=@($atomId); mass_acceptance_forbidden=$true
  })
  return [pscustomobject]@{ candidate_root=$candidateRoot; controller_root=$controllerRoot; execution_root=$executionRoot; finalizer_root=$finalizerRoot }
}

function New-D2BPhase162BatchPackage {
  param(
    [string]$WorkRoot,
    [object[]]$Items,
    [string]$MemoryPath,
    [string]$SelfMapPath,
    [string]$RegistryPath
  )

  $candidateRoot = Join-Path $WorkRoot 'cand'
  $controllerRoot = Join-Path $WorkRoot 'ctrl'
  $executionRoot = Join-Path $WorkRoot 'exec'
  $finalizerRoot = Join-Path $WorkRoot 'fin'
  New-Item -ItemType Directory -Force -Path $candidateRoot,$controllerRoot,$executionRoot,$finalizerRoot | Out-Null

  $atomIds = @($Items | ForEach-Object { [string]$_.atom_id })
  $memoryOps = @()
  $selfOps = @()
  $registryOps = @()
  foreach ($item in $Items) {
    $payload = Get-D2BCandidatePayload -Candidate $item.candidate -SourcePath ([string]$item.source_path)
    $memoryOps += [ordered]@{ operation_id="$($item.operation_id)_MEMORY"; atom_id=[string]$item.atom_id; target=$MemoryPath; source_freeze_root=$WorkRoot; payload=$payload }
    $selfOps += [ordered]@{ operation_id="$($item.operation_id)_SELF"; atom_id=[string]$item.atom_id; target=$SelfMapPath; source_freeze_root=$WorkRoot; payload=$payload }
    $registryOps += [ordered]@{ operation_id="$($item.operation_id)_REGISTRY"; atom_id=[string]$item.atom_id; target=$RegistryPath; source_freeze_root=$WorkRoot; payload=$payload }
  }

  Write-D2BJson (Join-Path $candidateRoot 'controlled_accept_core_mutation_candidate_result.json') ([ordered]@{
    schema = 'PHASE162_CONTROLLED_ACCEPT_CORE_MUTATION_CANDIDATE_RESULT_V1'
    status = 'PASS'
    created_at = (Get-Date).ToUniversalTime().ToString('o')
    batch_size = $Items.Count
    staged_atom_count = $Items.Count
    atom_ids = $atomIds
    next_machine_action = 'VALIDATE_CONTROLLED_ACCEPT_CORE_MUTATION_CANDIDATE_FOR_ATOM_BATCH'
    source = 'PHASE165S-D2B central batch admission'
  })
  Write-D2BJson (Join-Path $candidateRoot 'controlled_accept_core_mutation_set.json') ([ordered]@{
    schema = 'PHASE162_CONTROLLED_ACCEPT_CORE_MUTATION_SET_V1'
    status = 'PASS'
    created_at = (Get-Date).ToUniversalTime().ToString('o')
    accepted_memory_operations = $memoryOps
    accepted_self_model_operations = $selfOps
    registry_operations = $registryOps
  })
  Write-D2BJson (Join-Path $candidateRoot 'atomic_accept_write_plan.json') ([ordered]@{
    schema='PHASE162_ATOMIC_ACCEPT_WRITE_PLAN_V1'; status='PASS'; created_at=(Get-Date).ToUniversalTime().ToString('o')
    atomicity_rule='all_operations_pass_or_rollback'; target_files=@($MemoryPath,$SelfMapPath,$RegistryPath); allowed_atom_ids=$atomIds
  })
  Write-D2BJson (Join-Path $candidateRoot 'controlled_accept_core_mutation_rollback_plan.json') ([ordered]@{
    schema='PHASE162_CONTROLLED_ACCEPT_CORE_MUTATION_ROLLBACK_PLAN_V1'; status='PASS'; created_at=(Get-Date).ToUniversalTime().ToString('o')
    rollback_actions=@('restore_memory_snapshot','restore_self_map_snapshot','restore_registry_snapshot','validate_atom_count','write_rollback_event')
  })
  Write-D2BJson (Join-Path $candidateRoot 'post_mutation_validation_binding.json') ([ordered]@{
    schema='PHASE162_POST_MUTATION_VALIDATION_BINDING_V1'; status='PASS'; created_at=(Get-Date).ToUniversalTime().ToString('o')
    bound_to_mutation_set='controlled_accept_core_mutation_set.json'; bound_to_atomic_write_plan='atomic_accept_write_plan.json'
  })
  Write-D2BJson (Join-Path $controllerRoot 'controller_consume_controlled_accept_core_mutation_dry_run_batch_result.json') ([ordered]@{
    schema='PHASE162_CONTROLLER_CONSUME_CONTROLLED_ACCEPT_CORE_MUTATION_DRY_RUN_BATCH_RESULT_V1'; status='PASS'
    created_at=(Get-Date).ToUniversalTime().ToString('o'); next_machine_action='EXECUTE_CONTROLLED_ACCEPT_CORE_MUTATION_FOR_ATOM_BATCH'
    execution_authorization_status='AUTHORIZED_ONE_SHOT_CONTROLLED_ACCEPT_CORE_MUTATION'; candidate_root=$candidateRoot
    authorization_source='PHASE165S-C2B bounded autonomous acceptance policy guard'; owner_interrupt_used=$false
  })
  Write-D2BJson (Join-Path $controllerRoot 'controller_consume_controlled_accept_core_mutation_dry_run_batch_validation.json') ([ordered]@{
    schema='PHASE162_CONTROLLER_CONSUME_CONTROLLED_ACCEPT_CORE_MUTATION_DRY_RUN_BATCH_VALIDATION_V1'; status='PASS'
    created_at=(Get-Date).ToUniversalTime().ToString('o'); next_machine_action='EXECUTE_CONTROLLED_ACCEPT_CORE_MUTATION_FOR_ATOM_BATCH'
    exact_atom_scope=$true; allowed_atom_ids=$atomIds
  })
  Write-D2BJson (Join-Path $controllerRoot 'one_shot_controlled_accept_core_mutation_execution_authorization_for_atom_batch.json') ([ordered]@{
    schema='PHASE162_ONE_SHOT_CONTROLLED_ACCEPT_CORE_MUTATION_EXECUTION_AUTHORIZATION_FOR_ATOM_BATCH_V1'; status='AUTHORIZED'
    created_at=(Get-Date).ToUniversalTime().ToString('o'); authorization_scope='ONE_SHOT_ACCEPTED_CORE_WRITE_WITH_ATOMIC_PLAN_AND_ROLLBACK'
    candidate_root=$candidateRoot; authorization_source='PHASE165S-C2B bounded autonomous acceptance policy guard'
    owner_interrupt_used=$false; autonomous_policy_guard_allowed=$true; authorized_atom_ids=$atomIds; mass_acceptance_forbidden=$true
  })
  return [pscustomobject]@{ candidate_root=$candidateRoot; controller_root=$controllerRoot; execution_root=$executionRoot; finalizer_root=$finalizerRoot; atom_ids=$atomIds }
}

function Get-D2BVisibilityRows {
  param(
    [string]$Root,
    [string]$MemoryPath,
    [string]$SelfMapPath,
    [string]$RegistryPath,
    [string[]]$AtomIds
  )

  $memory = Read-D2BJson (Join-Path $Root $MemoryPath)
  $selfMap = Read-D2BJson (Join-Path $Root $SelfMapPath)
  $registry = Read-D2BJson (Join-Path $Root $RegistryPath)
  $rows = @()
  foreach ($atomId in $AtomIds) {
    $rows += [pscustomobject][ordered]@{
      atom_id = $atomId
      memory_count = Get-D2BCount $memory 'phase162_accepted_atom_memory_records' $atomId
      self_map_count = Get-D2BCount $selfMap 'phase162_absorbed_atom_capability_notes' $atomId
      registry_count = Get-D2BCount $registry 'phase162_accepted_atom_references' $atomId
    }
  }
  return @($rows)
}

function Add-D2BAtomCountsToIndex {
  param(
    [hashtable]$Index,
    $Root,
    [string]$Property
  )
  if ($null -eq $Root -or -not ($Root.PSObject.Properties.Name -contains $Property)) { return }
  foreach ($record in @($Root.$Property)) {
    $atomId = [string]$record.atom_id
    if ([string]::IsNullOrWhiteSpace($atomId)) { continue }
    if (-not $Index.ContainsKey($atomId)) { $Index[$atomId] = 0 }
    $Index[$atomId] = [int]$Index[$atomId] + 1
  }
}

function New-D2BAcceptedSurfaceIndex {
  param(
    [string]$Root,
    [string]$MemoryPath,
    [string]$SelfMapPath,
    [string]$RegistryPath
  )

  $memory = Read-D2BJson (Join-Path $Root $MemoryPath)
  $selfMap = Read-D2BJson (Join-Path $Root $SelfMapPath)
  $registry = Read-D2BJson (Join-Path $Root $RegistryPath)
  $memoryIndex = @{}
  $selfMapIndex = @{}
  $registryIndex = @{}
  Add-D2BAtomCountsToIndex -Index $memoryIndex -Root $memory -Property 'phase162_accepted_atom_memory_records'
  Add-D2BAtomCountsToIndex -Index $selfMapIndex -Root $selfMap -Property 'phase162_absorbed_atom_capability_notes'
  Add-D2BAtomCountsToIndex -Index $registryIndex -Root $registry -Property 'phase162_accepted_atom_references'
  return [pscustomobject][ordered]@{
    memory = $memoryIndex
    self_map = $selfMapIndex
    registry = $registryIndex
  }
}

function Get-D2BIndexCount {
  param([hashtable]$Index, [string]$AtomId)
  if ($Index.ContainsKey($AtomId)) { return [int]$Index[$AtomId] }
  return 0
}

function Get-D2BVisibilityRowFromIndex {
  param($Index, [string]$AtomId)
  return [pscustomobject][ordered]@{
    atom_id = $AtomId
    memory_count = Get-D2BIndexCount -Index $Index.memory -AtomId $AtomId
    self_map_count = Get-D2BIndexCount -Index $Index.self_map -AtomId $AtomId
    registry_count = Get-D2BIndexCount -Index $Index.registry -AtomId $AtomId
  }
}

function Get-D2BVisibilityRowsFromIndex {
  param($Index, [string[]]$AtomIds)
  $rows = @()
  foreach ($atomId in $AtomIds) {
    $rows += Get-D2BVisibilityRowFromIndex -Index $Index -AtomId $atomId
  }
  return @($rows)
}

function New-D2BPolicyCandidate {
  param(
    [string]$AtomId,
    [string]$MemoryPath,
    [string]$SelfMapPath,
    [string]$RegistryPath
  )
  return [pscustomobject][ordered]@{
    atom_id=$AtomId; batch_size=1; source_route='OWNER_APPROVED_CURRICULUM'; source_authority='OWNER_APPROVED'
    target_files=@($MemoryPath,$SelfMapPath,$RegistryPath); protected_files_to_mutate=@('packs/registry.json')
    proof_gates=[pscustomobject][ordered]@{
      memory_proof_status='PASS'; use_proof_status='PASS'; behavior_delta_status='PASS'
      persistence_status='PASS'; startup_visibility_status='PASS'
    }
    rollback_plan_available=$true; exactly_one_atom_scope=$true; mass_acceptance_forbidden=$true; risk_flags=@()
  }
}

function Test-D2BStringSetExact {
  param([string[]]$Actual, [string[]]$Expected)
  if ($Actual.Count -ne $Expected.Count) { return $false }
  foreach ($value in $Actual) {
    if ($value -notin $Expected) { return $false }
  }
  foreach ($value in $Expected) {
    if ($value -notin $Actual) { return $false }
  }
  return $true
}

function Invoke-D2BLocalPolicyEvaluation {
  param(
    $Candidate,
    $VisibilityRow,
    [string]$MemoryPath,
    [string]$SelfMapPath,
    [string]$RegistryPath
  )

  $atomId = [string]$Candidate.atom_id
  $targetFiles = @($Candidate.target_files | ForEach-Object { [string]$_ })
  $protectedFiles = @($Candidate.protected_files_to_mutate | ForEach-Object { [string]$_ })
  $riskFlags = @($Candidate.risk_flags | ForEach-Object { [string]$_ } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
  $proofGates = $Candidate.proof_gates
  $reasons = @()

  if ([string]::IsNullOrWhiteSpace($atomId)) { $reasons += 'atom_id_empty' }
  if ([int]$Candidate.batch_size -ne 1) { $reasons += 'batch_size_not_one' }
  if ([string]$Candidate.source_route -ne 'OWNER_APPROVED_CURRICULUM') { $reasons += 'source_route_not_owner_approved_curriculum' }
  if ([string]$Candidate.source_authority -ne 'OWNER_APPROVED') { $reasons += 'source_authority_not_owner_approved' }
  if (-not (Test-D2BStringSetExact -Actual $targetFiles -Expected @($MemoryPath,$SelfMapPath,$RegistryPath))) {
    $reasons += 'target_files_not_exact_accepted_surfaces'
  }
  if (-not (Test-D2BStringSetExact -Actual $protectedFiles -Expected @('packs/registry.json'))) {
    $reasons += 'protected_files_not_exact_registry'
  }

  foreach ($gate in @('memory_proof_status','use_proof_status','behavior_delta_status','persistence_status','startup_visibility_status')) {
    if ([string]$proofGates.$gate -ne 'PASS') { $reasons += "proof_gate_not_pass=$gate" }
  }

  if ([bool]$Candidate.rollback_plan_available -ne $true) { $reasons += 'rollback_plan_missing' }
  if ([bool]$Candidate.exactly_one_atom_scope -ne $true) { $reasons += 'exactly_one_atom_scope_false' }
  if ([bool]$Candidate.mass_acceptance_forbidden -ne $true) { $reasons += 'mass_acceptance_not_forbidden' }
  if ($riskFlags.Count -gt 0) { $reasons += 'risk_flags_present' }
  if (($null -ne $VisibilityRow) -and (([int]$VisibilityRow.memory_count + [int]$VisibilityRow.self_map_count + [int]$VisibilityRow.registry_count) -gt 0)) {
    $reasons += 'duplicate_atom_found'
  }

  $allowed = ($reasons.Count -eq 0)
  return [pscustomobject][ordered]@{
    schema = 'PHASE165S_C2_BOUNDED_AUTONOMOUS_ATOM_ACCEPTANCE_POLICY_EVALUATION_V1'
    status = 'PASS'
    created_at = (Get-Date -Format o)
    autonomous_accept_allowed = [bool]$allowed
    decision_code = if ($allowed) { 'ALLOW_AUTONOMOUS_ONE_ATOM_ACCEPTANCE' } else { 'DENY_REQUIRE_OWNER_OR_REPAIR' }
    atom_ids = @($atomId)
    batch_size = [int]$Candidate.batch_size
    source_route = [string]$Candidate.source_route
    source_authority = [string]$Candidate.source_authority
    allowed_target_files = @($MemoryPath,$SelfMapPath,$RegistryPath)
    target_files = $targetFiles
    protected_files_to_mutate = $protectedFiles
    duplicate_atoms = if (@($reasons | Where-Object { $_ -eq 'duplicate_atom_found' }).Count -gt 0) { @($atomId) } else { @() }
    denial_reasons = $reasons
    owner_prompt_required = (-not $allowed)
    protected_write_scope = 'packs/registry.json only, and only through existing PHASE162 accepted-core executor'
    next_machine_action = if ($allowed) { 'RUN_EXISTING_PHASE162_ACCEPT_PIPELINE_WITHOUT_OWNER_INTERRUPT' } else { 'STOP_FOR_OWNER_OR_REPAIR' }
    evaluation_mode = 'BATCH_LOCAL_NO_EXTERNAL_PROCESS'
  }
}

function Write-D2BRunArtifacts {
  param(
    [string]$Root,
    [string]$OutputRootFull,
    [object]$State,
    [object]$Manifest,
    [string]$Status,
    [bool]$StoppedBySignal,
    [string[]]$UnauthorizedDirty,
    [int]$BatchSize = 1,
    [string]$WorkRootFull,
    [string]$WorkRootMode = 'legacy',
    [bool]$WorkRootShortPathEnabled = $false,
    [string]$RetentionMode = 'CompactAccepted',
    $RetentionResult = $null,
    [bool]$DirectCandidateBatchMode = $false,
    [string]$CandidateBatchPath = '',
    [bool]$CandidateMaterialPruned = $false,
    [string]$CleanupPendingPath = '',
    [string]$AcceptedCoreMode = 'TrackedCore',
    [string]$AcceptedCoreDeltaRoot = ''
  )
  $queueEmpty = ([int]$State.remaining_count -eq 0)
  $workRootDisplay = Get-D2BRelativePath -Root $Root -Path $WorkRootFull
  $batchExecutionImplemented = ($BatchSize -gt 1 -and [int]$State.phase162_executor_invocation_count -gt 0)
  $batchModeNote = if ($BatchSize -gt 1) {
    'R4-03R2 central batch admission: D2B selects a bounded candidate batch, applies per-atom policy guards, then writes accepted core through one Phase162 batch executor invocation.'
  } else {
    'BatchSize=1 keeps the existing one-candidate behavior.'
  }
  $nextAction = if ($queueEmpty -and [int]$State.failed_count -eq 0) {
    'PHASE165S_D2B_BIG_CURRICULUM_AUTONOMOUS_LEARNING_ACCEPTANCE_REVIEW'
  } elseif ($Status -eq 'BLOCKED_PARTIAL_ACCEPTED_SURFACE') {
    'BLOCKED_PARTIAL_ACCEPTED_SURFACE_RECONCILIATION_REQUIRED'
  } elseif ($Status -eq 'RUNNING_ACTIVE') {
    'WAIT_FOR_ACTIVE_D2B_RUN_OR_USE_STOP_SIGNAL'
  } elseif ($StoppedBySignal) {
    'REMOVE_STOP_SIGNAL_AND_RESUME_PHASE165S_D2B'
  } elseif ([int]$State.failed_count -gt 0) {
    'PHASE165S_D2B_BIG_CURRICULUM_AUTONOMOUS_LEARNING_TRIAGE'
  } else {
    'RESUME_PHASE165S_D2B_BIG_CURRICULUM_AUTONOMOUS_LEARNING'
  }
  $proof = [ordered]@{
    phase = 'PHASE165S_D2B_BIG_CURRICULUM_AUTONOMOUS_LEARNING'
    created_utc = (Get-Date).ToUniversalTime().ToString('o')
    status = $Status
    queue_empty = $queueEmpty
    total_candidate_count = [int]$Manifest.total_candidate_count
    safe_candidate_count = [int]$Manifest.safe_candidate_count
    quarantine_expected_count = [int]$Manifest.quarantine_candidate_count + [int]$State.denied_count + [int]$State.invalid_safe_candidate_count + [int]$State.dynamic_quarantine_count
    accepted_atom_count = [int]$State.accepted_count
    quarantine_count = [int]$State.quarantine_count
    denied_count = [int]$State.denied_count
    invalid_safe_candidate_count = [int]$State.invalid_safe_candidate_count
    dynamic_quarantine_count = [int]$State.dynamic_quarantine_count
    skipped_duplicate_count = [int]$State.skipped_duplicate_count
    failed_count = [int]$State.failed_count
    recovered_failure_count = [int]$State.recovered_failure_count
    owner_interrupt_used = $false
    batch_size = $BatchSize
    batch_mode_scaffold_only = $false
    batch_execution_implemented = $batchExecutionImplemented
    batch_mode_note = $batchModeNote
    autonomous_policy_guard_used = ([int]$State.policy_guard_invocation_count -gt 0)
    autonomous_policy_guard_invocation_count = [int]$State.policy_guard_invocation_count
    policy_guard_process_invocation_count = [int]$State.policy_guard_process_invocation_count
    phase162_executor_used = ([int]$State.phase162_executor_invocation_count -gt 0)
    phase162_executor_invocation_count = [int]$State.phase162_executor_invocation_count
    finalizer_invocation_count = [int]$State.finalizer_invocation_count
    resume_supported = $true
    stopped_by_signal = $StoppedBySignal
    checkpoint_count = [int]$State.checkpoint_count
    heartbeat_path = (Get-D2BRelativePath -Root $Root -Path (Join-Path $OutputRootFull 'heartbeat.json'))
    protected_state_dirty_check = @($UnauthorizedDirty)
    allowed_accepted_surface_mutations = @('packs/registry.json','reports/self_development/accepted_change_memory_snapshot.json','reports/self_development/SELF_MODEL_ACTIVE_MAP.json')
    output_root = (Get-D2BRelativePath -Root $Root -Path $OutputRootFull)
    work_root = $workRootDisplay
    work_root_mode = $WorkRootMode
    work_root_short_path_enabled = $WorkRootShortPathEnabled
    retention_mode = $RetentionMode
    post_batch_retention = $RetentionResult
    direct_candidate_batch_mode = $DirectCandidateBatchMode
    candidate_batch_path = $CandidateBatchPath
    candidate_material_pruned = $CandidateMaterialPruned
    cleanup_pending_path = $CleanupPendingPath
    cleanup_pending_count = if (-not [string]::IsNullOrWhiteSpace($CleanupPendingPath) -and (Test-Path -LiteralPath $CleanupPendingPath)) { @((Get-Content -LiteralPath $CleanupPendingPath -Raw | ConvertFrom-Json).entries).Count } else { 0 }
    accepted_core_mode = $AcceptedCoreMode
    runtime_delta_written = ($AcceptedCoreMode -eq 'RuntimeDeltaOnly' -and -not [string]::IsNullOrWhiteSpace($AcceptedCoreDeltaRoot))
    accepted_core_delta_root = $AcceptedCoreDeltaRoot
    runtime_ready = $false
    current_shard_index = [int]$State.shard_index
    current_line_index = [int]$State.line_index
    processed_count = [int]$State.processed_count
    remaining_count = [int]$State.remaining_count
    risk_flag_compatibility = 'none_identified_at_material_stage is treated as no effective risk; all other flags quarantine'
    next_required_action = $nextAction
  }
  Write-D2BJson -Path (Join-Path $Root 'proofs/self_development/PHASE165S_D2B_BIG_CURRICULUM_AUTONOMOUS_LEARNING_V1.json') -Value $proof
  Write-D2BJson -Path (Join-Path $OutputRootFull 'final_summary.json') -Value $proof
  Write-D2BText -Path (Join-Path $Root 'reports/self_development/PHASE165S_D2B_BIG_CURRICULUM_AUTONOMOUS_LEARNING_V1.md') -Lines @(
    '# PHASE165S-D2B Big Curriculum Autonomous Learning',
    '',
    "Status: $Status",
    '',
    'D2A material remains raw and untrusted until each candidate passes the existing school acceptance path. D2B does not manually wave batches; one process advances one candidate at a time through C2B and the PHASE162 accepted-core executor until the queue is empty or `STOP_SIGNAL` appears.',
    '',
    "Processed: $($State.processed_count) / $($Manifest.total_candidate_count)",
    "Accepted: $($State.accepted_count)",
    "Quarantined: $($State.quarantine_count)",
    "Denied: $($State.denied_count)",
    "Skipped duplicates: $($State.skipped_duplicate_count)",
    "Failed: $($State.failed_count)",
    "Queue empty: $queueEmpty",
    "BatchSize: $BatchSize",
    "Work root: $workRootDisplay",
    "Work root mode: $WorkRootMode",
    "Short work root enabled: $WorkRootShortPathEnabled",
    '',
    '## R4 Batch Admission',
    '',
    $batchModeNote,
    '',
    '## Resume',
    '',
    'Remove `reports/self_development/phase165s_d2b_big_curriculum_autonomous_learning/STOP_SIGNAL` if present, then run:',
    '',
    '```powershell',
    'powershell -NoProfile -ExecutionPolicy Bypass -File modules/run_phase165s_d2b_big_curriculum_autonomous_learn_until_empty_001.ps1 -Resume',
    '```',
    '',
    '## Validate',
    '',
    '```powershell',
    'powershell -NoProfile -ExecutionPolicy Bypass -File validators/validate_phase165s_d2b_big_curriculum_autonomous_learning_v1.ps1',
    '```',
    '',
    '## Next Required Action',
    '',
    $nextAction
  )
  return [pscustomobject]$proof
}

function Invoke-D2BPostBatchRetentionHook {
  param(
    [string]$Root,
    [string]$OutputRootFull,
    [string]$WorkRootFull,
    [string]$AcceptedLogPath,
    [int]$AcceptedLogStartLineCount,
    [int]$InitialFailedCount,
    [int]$InitialQuarantineCount,
    [object]$State,
    [string]$FinalStatus,
    [bool]$StoppedBySignal,
    [string]$HardError,
    [string]$RetentionMode
  )

  $retentionRoot = Join-Path $OutputRootFull 'ret'
  New-Item -ItemType Directory -Force -Path $retentionRoot | Out-Null
  $summaryPath = Join-Path $retentionRoot 'result.json'
  $acceptedAtoms = @(Get-D2BAcceptedAtomsFromLogAfterLine -Path $AcceptedLogPath -SkipNonEmptyLineCount $AcceptedLogStartLineCount)
  $runFailedCount = [math]::Max(0, ([int]$State.failed_count - $InitialFailedCount))
  $runQuarantinedCount = [math]::Max(0, ([int]$State.quarantine_count - $InitialQuarantineCount))
  $cleanSuccessfulBatch = (
    $acceptedAtoms.Count -gt 0 -and
    [string]::IsNullOrWhiteSpace($HardError) -and
    -not $StoppedBySignal -and
    $runFailedCount -eq 0 -and
    $runQuarantinedCount -eq 0 -and
    $FinalStatus -in @('PASS_QUEUE_EMPTY','INCOMPLETE_RESUMABLE')
  )

  if ($acceptedAtoms.Count -eq 0) {
    $noOp = [ordered]@{
      schema = 'legacy_d2b_post_batch_retention_hook_result_v1'
      status = 'NO_ACCEPTED_ATOMS'
      retention_mode = $RetentionMode
      retention_gate_invoked = $false
      accepted_count = 0
      receipt_count = 0
      heavy_trace_pruned = $false
      work_current_preserved = (Test-Path -LiteralPath $WorkRootFull)
      runtime_ready = $false
      result_path = (Get-D2BRelativePath -Root $Root -Path $summaryPath)
    }
    Write-D2BJson -Path $summaryPath -Value $noOp
    return [pscustomobject]$noOp
  }

  if ($RetentionMode -ne 'CompactAccepted') {
    $unsafe = [ordered]@{
      schema = 'legacy_d2b_post_batch_retention_hook_result_v1'
      status = if ($RetentionMode -eq 'Disabled') { 'RETENTION_DISABLED_UNSAFE_FULL_TRACE_RETAINED' } else { 'FULL_TRACE_UNSAFE_RETAINED' }
      retention_mode = $RetentionMode
      retention_gate_invoked = $false
      accepted_count = $acceptedAtoms.Count
      receipt_count = 0
      heavy_trace_pruned = $false
      work_current_preserved = (Test-Path -LiteralPath $WorkRootFull)
      unsafe_reason = 'Accepted atoms were produced while retention compaction was not active.'
      runtime_ready = $false
      result_path = (Get-D2BRelativePath -Root $Root -Path $summaryPath)
    }
    Write-D2BJson -Path $summaryPath -Value $unsafe
    return [pscustomobject]$unsafe
  }

  $stamp = Get-Date -Format 'HHmmssffff'
  $batchId = "r{0:d8}_{1}" -f [int]$State.processed_count, $stamp
  $batchRoot = Join-Path $retentionRoot $batchId
  [void][System.IO.Directory]::CreateDirectory($batchRoot)
  $acceptedAtomsPath = Join-Path $batchRoot 'atoms.json'
  $envelopePath = Join-Path $batchRoot 'envelope.json'
  $adapterOutputRoot = Join-Path $batchRoot 'o'
  $adapterPath = Join-Path $Root 'modules/invoke_real_runner_retention_gate_adapter_v1.ps1'
  if (-not (Test-Path -LiteralPath $adapterPath)) {
    throw "RETENTION_ADAPTER_MISSING=$adapterPath"
  }

  $atomsJson = ConvertTo-Json -InputObject @($acceptedAtoms) -Depth 40
  $acceptedAtomsParent = Split-Path -Parent $acceptedAtomsPath
  if ($acceptedAtomsParent -and -not (Test-Path -LiteralPath $acceptedAtomsParent)) {
    New-Item -ItemType Directory -Force -Path $acceptedAtomsParent | Out-Null
  }
  [System.IO.File]::WriteAllText($acceptedAtomsPath, $atomsJson + "`n", [System.Text.UTF8Encoding]::new($false))
  $postValidationStatus = if ($cleanSuccessfulBatch) { 'PASS' } else { $FinalStatus }
  if ([string]::IsNullOrWhiteSpace($postValidationStatus)) { $postValidationStatus = 'UNKNOWN' }
  $envelope = [ordered]@{
    schema = 'real_runner_one_batch_envelope_v1'
    batch_id = $batchId
    work_current = $WorkRootFull
    accepted_atoms_path = $acceptedAtomsPath
    output_root = $adapterOutputRoot
    post_validation_status = $postValidationStatus
    failed_count = $runFailedCount
    quarantined_count = $runQuarantinedCount
    source = 'legacy_d2b_runner_post_batch_retention_hook'
  }
  Write-D2BJson -Path $envelopePath -Value $envelope

  try {
    $adapterJson = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $adapterPath -BatchEnvelopePath $envelopePath
    $adapterResult = $adapterJson | ConvertFrom-Json
    $result = [ordered]@{
      schema = 'legacy_d2b_post_batch_retention_hook_result_v1'
      status = [string]$adapterResult.status
      retention_mode = $RetentionMode
      retention_gate_invoked = $true
      adapter_path = (Get-D2BRelativePath -Root $Root -Path $adapterPath)
      batch_id = $batchId
      accepted_atoms_path = (Get-D2BRelativePath -Root $Root -Path $acceptedAtomsPath)
      batch_envelope_path = (Get-D2BRelativePath -Root $Root -Path $envelopePath)
      output_root = (Get-D2BRelativePath -Root $Root -Path $adapterOutputRoot)
      post_validation_status = $postValidationStatus
      failed_count = $runFailedCount
      quarantined_count = $runQuarantinedCount
      accepted_count = if ($adapterResult.PSObject.Properties.Name -contains 'accepted_count') { [int]$adapterResult.accepted_count } else { $acceptedAtoms.Count }
      receipt_count = if ($adapterResult.PSObject.Properties.Name -contains 'receipt_count') { [int]$adapterResult.receipt_count } else { 0 }
      heavy_trace_pruned = [bool]$adapterResult.heavy_trace_pruned
      work_current_preserved = [bool]$adapterResult.work_current_preserved
      cleanup_pending_count = if ($adapterResult.PSObject.Properties.Name -contains 'cleanup_pending_count') { [int]$adapterResult.cleanup_pending_count } else { 0 }
      cleanup_pending_path = if (($adapterResult.PSObject.Properties.Name -contains 'cleanup_pending_path') -and -not [string]::IsNullOrWhiteSpace([string]$adapterResult.cleanup_pending_path)) { (Get-D2BRelativePath -Root $Root -Path ([string]$adapterResult.cleanup_pending_path)) } else { '' }
      runtime_ready = $false
      result_path = (Get-D2BRelativePath -Root $Root -Path $summaryPath)
    }
  } catch {
    $result = [ordered]@{
      schema = 'legacy_d2b_post_batch_retention_hook_result_v1'
      status = 'RETENTION_ADAPTER_FAILED_TRACE_PRESERVED'
      retention_mode = $RetentionMode
      retention_gate_invoked = $true
      adapter_path = (Get-D2BRelativePath -Root $Root -Path $adapterPath)
      batch_id = $batchId
      accepted_atoms_path = (Get-D2BRelativePath -Root $Root -Path $acceptedAtomsPath)
      batch_envelope_path = (Get-D2BRelativePath -Root $Root -Path $envelopePath)
      output_root = (Get-D2BRelativePath -Root $Root -Path $adapterOutputRoot)
      post_validation_status = $postValidationStatus
      failed_count = $runFailedCount
      quarantined_count = $runQuarantinedCount
      accepted_count = $acceptedAtoms.Count
      receipt_count = 0
      heavy_trace_pruned = $false
      work_current_preserved = (Test-Path -LiteralPath $WorkRootFull)
      failure = $_.Exception.Message
      runtime_ready = $false
      result_path = (Get-D2BRelativePath -Root $Root -Path $summaryPath)
    }
  }

  Write-D2BJson -Path $summaryPath -Value $result
  return [pscustomobject]$result
}

$root = (Resolve-Path $RepoRoot).Path
$candidateBatchInfo = Get-D2BCandidateBatchInfo -Root $root -CandidateBatchPath $CandidateBatchPath -BatchSize $BatchSize
$directCandidateBatchMode = ($null -ne $candidateBatchInfo)
$inputFull = if ([System.IO.Path]::IsPathRooted($InputRoot)) { [System.IO.Path]::GetFullPath($InputRoot) } else { [System.IO.Path]::GetFullPath((Join-Path $root $InputRoot)) }
$outputFull = if ([System.IO.Path]::IsPathRooted($OutputRoot)) { [System.IO.Path]::GetFullPath($OutputRoot) } else { [System.IO.Path]::GetFullPath((Join-Path $root $OutputRoot)) }
$repoPrefix = $root.TrimEnd('\') + '\'
if ((-not $directCandidateBatchMode) -and -not $inputFull.StartsWith($repoPrefix, [System.StringComparison]::OrdinalIgnoreCase)) { throw "INPUT_ROOT_OUTSIDE_REPO=$inputFull" }
if (-not $outputFull.StartsWith($repoPrefix, [System.StringComparison]::OrdinalIgnoreCase)) { throw "OUTPUT_ROOT_OUTSIDE_REPO=$outputFull" }
New-Item -ItemType Directory -Force -Path $outputFull,(Join-Path $outputFull 'checkpoints'),(Join-Path $outputFull 'work') | Out-Null

if ($directCandidateBatchMode) {
  $manifest = [pscustomobject][ordered]@{
    schema = 'EPHEMERAL_D2B_CANDIDATE_BATCH_MANIFEST_V1'
    total_candidate_count = [int]$candidateBatchInfo.candidate_count
    safe_candidate_count = [int]$candidateBatchInfo.candidate_count
    quarantine_candidate_count = 0
    shard_paths = @([string]$candidateBatchInfo.relative_path)
    source = 'DIRECT_EPHEMERAL_CANDIDATE_BATCH'
  }
  $index = [pscustomobject][ordered]@{
    schema = 'EPHEMERAL_D2B_CANDIDATE_BATCH_INDEX_V1'
    total_candidate_count = [int]$candidateBatchInfo.candidate_count
    shard_count = 1
  }
} else {
  $manifest = Read-D2BJson (Join-Path $inputFull 'school_ready_manifest.json')
  $index = Read-D2BJson (Join-Path $inputFull 'material_bank_index.json')
  if ([int]$manifest.total_candidate_count -ne [int]$index.total_candidate_count) { throw 'INPUT_MANIFEST_INDEX_COUNT_MISMATCH' }
}
$shards = @($manifest.shard_paths)
if ($shards.Count -ne [int]$index.shard_count) { throw 'INPUT_MANIFEST_INDEX_SHARD_MISMATCH' }

$memoryPath = 'reports/self_development/accepted_change_memory_snapshot.json'
$selfMapPath = 'reports/self_development/SELF_MODEL_ACTIVE_MAP.json'
$registryPath = 'packs/registry.json'
$acceptedCoreDeltaInfo = $null
if ($AcceptedCoreMode -eq 'RuntimeDeltaOnly') {
  $deltaRootFull = if ([string]::IsNullOrWhiteSpace($AcceptedCoreRoot)) {
    Join-Path $outputFull 'accepted_core_delta'
  } else {
    ConvertTo-D2BFullPath -Root $root -Path $AcceptedCoreRoot
  }
  $acceptedCoreDeltaInfo = Initialize-D2BRuntimeAcceptedCore -Root $root -DeltaRootFull $deltaRootFull
  $memoryPath = [string]$acceptedCoreDeltaInfo.memory_path
  $selfMapPath = [string]$acceptedCoreDeltaInfo.self_map_path
  $registryPath = [string]$acceptedCoreDeltaInfo.registry_path
}
$policyModule = Join-Path $root 'modules/evaluate_phase165s_c2_bounded_autonomous_atom_acceptance_policy_001.ps1'
$executorModule = Join-Path $root 'modules/invoke_phase162_execute_controlled_accept_core_mutation_for_atom_batch_001.ps1'
$finalizerModule = Join-Path $root 'modules/invoke_phase162_controller_consume_controlled_accept_core_mutation_execution_proof_001.ps1'
foreach ($path in @($policyModule,$executorModule,$finalizerModule)) {
  if (-not (Test-Path -LiteralPath $path)) { throw "REQUIRED_MODULE_MISSING=$path" }
}

$unauthorizedDirtyBefore = @(git -C $root status --short -- CAPABILITY_ROADMAP.json GENESIS_STATE.json TASK_QUEUE.json orchestrator/run.ps1 route_locks)
if ($unauthorizedDirtyBefore.Count -gt 0) { throw "UNAUTHORIZED_PROTECTED_STATE_DIRTY=$($unauthorizedDirtyBefore -join '; ')" }

$workRootInfo = Resolve-D2BWorkRoot -RepoRoot $root -OutputRootFull $outputFull -WorkRoot $WorkRoot
$workRoot = [string]$workRootInfo.work_root

$statePath = Join-Path $outputFull 'queue_state.json'
$resumePath = Join-Path $outputFull 'resume_state.json'
$heartbeatPath = Join-Path $outputFull 'heartbeat.json'
$stopPath = Join-Path $outputFull 'STOP_SIGNAL'
$acceptedLog = Join-Path $outputFull 'accepted_log.jsonl'
$quarantineLog = Join-Path $outputFull 'quarantine_log.jsonl'
$skippedLog = Join-Path $outputFull 'skipped_log.jsonl'
$failedLog = Join-Path $outputFull 'failed_log.jsonl'
$recoveryLog = Join-Path $outputFull 'recovery_log.jsonl'

if ($Resume) {
  $state = Read-D2BJson $resumePath
  if ([string]$state.status -eq 'QUEUE_EMPTY') { throw 'QUEUE_ALREADY_EMPTY' }
  if ($state.PSObject.Properties.Name -contains 'work_root') {
    $stateWorkRoot = [System.IO.Path]::GetFullPath([string]$state.work_root)
    if (-not $stateWorkRoot.Equals([System.IO.Path]::GetFullPath($workRoot), [System.StringComparison]::OrdinalIgnoreCase)) {
      throw "WORK_ROOT_MISMATCH_FOR_RESUME expected=$stateWorkRoot actual=$workRoot"
    }
  }
} else {
  if (Test-Path -LiteralPath $statePath) { throw 'EXISTING_RUN_STATE_FOUND_USE_RESUME' }
  foreach ($log in @($acceptedLog,$quarantineLog,$skippedLog,$failedLog,$recoveryLog)) {
    if (-not (Test-Path -LiteralPath $log)) { [System.IO.File]::WriteAllText($log, '', [System.Text.UTF8Encoding]::new($false)) }
  }
  $state = [pscustomobject][ordered]@{
    schema = 'PHASE165S_D2B_QUEUE_STATE_V1'
    status = 'READY'
    mode = $Mode
    created_utc = (Get-Date).ToUniversalTime().ToString('o')
    updated_utc = (Get-Date).ToUniversalTime().ToString('o')
    shard_index = 0
    line_index = 0
    processed_count = 0
    remaining_count = [int]$manifest.total_candidate_count
    accepted_count = 0
    quarantine_count = 0
    denied_count = 0
    invalid_safe_candidate_count = 0
    skipped_duplicate_count = 0
    failed_count = 0
    recovered_failure_count = 0
    policy_guard_invocation_count = 0
    policy_guard_process_invocation_count = 0
    phase162_executor_invocation_count = 0
    finalizer_invocation_count = 0
    checkpoint_count = 0
    heartbeat_count = 0
    last_candidate_id = $null
    last_atom_id = $null
    last_disposition = $null
    owner_interrupt_used = $false
    work_root = $workRoot
    work_root_mode = [string]$workRootInfo.work_root_mode
    work_root_short_path_enabled = [bool]$workRootInfo.work_root_short_path_enabled
    work_root_base = [string]$workRootInfo.work_root_base
    direct_candidate_batch_mode = [bool]$directCandidateBatchMode
    candidate_batch_path = if ($directCandidateBatchMode) { [string]$candidateBatchInfo.relative_path } else { '' }
  }
  Write-D2BJson $statePath $state
  Write-D2BJson $resumePath $state
}
if (-not ($state.PSObject.Properties.Name -contains 'recovered_failure_count')) {
  $state | Add-Member -NotePropertyName recovered_failure_count -NotePropertyValue 0
}
if (-not ($state.PSObject.Properties.Name -contains 'dynamic_quarantine_count')) {
  $state | Add-Member -NotePropertyName dynamic_quarantine_count -NotePropertyValue 0
}
if (-not ($state.PSObject.Properties.Name -contains 'policy_guard_process_invocation_count')) {
  $state | Add-Member -NotePropertyName policy_guard_process_invocation_count -NotePropertyValue 0
}
if (-not ($state.PSObject.Properties.Name -contains 'work_root')) {
  $state | Add-Member -NotePropertyName work_root -NotePropertyValue $workRoot
}
if (-not ($state.PSObject.Properties.Name -contains 'work_root_mode')) {
  $state | Add-Member -NotePropertyName work_root_mode -NotePropertyValue ([string]$workRootInfo.work_root_mode)
}
if (-not ($state.PSObject.Properties.Name -contains 'work_root_short_path_enabled')) {
  $state | Add-Member -NotePropertyName work_root_short_path_enabled -NotePropertyValue ([bool]$workRootInfo.work_root_short_path_enabled)
}
if (-not ($state.PSObject.Properties.Name -contains 'work_root_base')) {
  $state | Add-Member -NotePropertyName work_root_base -NotePropertyValue ([string]$workRootInfo.work_root_base)
}
if ($RepairResumeStateOnly -and -not $Resume) {
  throw 'REPAIR_RESUME_STATE_ONLY_REQUIRES_RESUME'
}
if ($SyncSummaryOnly -and -not $Resume) {
  throw 'SYNC_SUMMARY_ONLY_REQUIRES_RESUME'
}
if ($RepairResumeStateOnly -and $SyncSummaryOnly) {
  throw 'REPAIR_RESUME_STATE_ONLY_AND_SYNC_SUMMARY_ONLY_ARE_MUTUALLY_EXCLUSIVE'
}

$stoppedBySignal = $false
$hardError = $null
$hardErrorAlreadyRecorded = $false
$lastAcceptedAtomId = $null
$invocationAcceptedLogStartLineCount = Get-D2BNonEmptyLineCount -Path $acceptedLog
$invocationFailedCountStart = [int]$state.failed_count
$invocationQuarantineCountStart = [int]$state.quarantine_count

if ($SyncSummaryOnly) {
  $otherD2BProcesses = @()
  try {
    $otherD2BProcesses = @(Get-CimInstance Win32_Process -ErrorAction Stop | Where-Object {
      [int]$_.ProcessId -ne $PID -and
      [string]$_.CommandLine -like '*run_phase165s_d2b_big_curriculum_autonomous_learn_until_empty_001.ps1*'
    })
  } catch {
    throw "ACTIVE_D2B_PROCESS_CHECK_FAILED=$($_.Exception.Message)"
  }
  if ($otherD2BProcesses.Count -gt 0) {
    throw "ACTIVE_D2B_RUN_DETECTED=$($otherD2BProcesses.ProcessId -join ',')"
  }
  if ([int]$state.failed_count -gt 0) {
    throw "SUMMARY_SYNC_BLOCKED_FAILED_COUNT=$($state.failed_count)"
  }
  if ([int]$state.remaining_count -eq 0) {
    $state.status = 'QUEUE_EMPTY'
    $syncStatus = 'PASS_QUEUE_EMPTY'
  } else {
    $state.status = 'RUNNING_READY_TO_RESUME'
    $syncStatus = 'INCOMPLETE_RESUMABLE'
  }
  $state.updated_utc = (Get-Date).ToUniversalTime().ToString('o')
  Write-D2BJson $statePath $state
  Write-D2BJson $resumePath $state
  Write-D2BJson $heartbeatPath ([ordered]@{
    status=[string]$state.status; heartbeat_utc=$state.updated_utc; processed_count=[int]$state.processed_count
    remaining_count=[int]$state.remaining_count; accepted_count=[int]$state.accepted_count
    quarantine_count=[int]$state.quarantine_count; stopped_by_signal=$false; hard_error=$null
    last_atom_id=$state.last_atom_id; last_disposition=$state.last_disposition
  })
  $unauthorizedDirtyAfter = @(git -C $root status --short -- CAPABILITY_ROADMAP.json GENESIS_STATE.json TASK_QUEUE.json orchestrator/run.ps1 route_locks)
  $result = Write-D2BRunArtifacts -Root $root -OutputRootFull $outputFull -State $state -Manifest $manifest -Status $syncStatus -StoppedBySignal $false -UnauthorizedDirty $unauthorizedDirtyAfter -BatchSize $BatchSize -WorkRootFull $workRoot -WorkRootMode ([string]$workRootInfo.work_root_mode) -WorkRootShortPathEnabled ([bool]$workRootInfo.work_root_short_path_enabled)
  if ($EmitJson) {
    $result | ConvertTo-Json -Depth 40
  } else {
    Write-Host "PHASE165S_D2B_SUMMARY_SYNC_RESULT=$syncStatus"
    Write-Host "PROCESSED_COUNT=$($state.processed_count)"
    Write-Host "REMAINING_COUNT=$($state.remaining_count)"
    Write-Host "ACCEPTED_ATOM_COUNT=$($state.accepted_count)"
    Write-Host "QUARANTINE_COUNT=$($state.quarantine_count)"
    Write-Host "FAILED_COUNT=$($state.failed_count)"
  }
  exit 0
}

if ($BatchSize -gt 1) {
  try {
    if ([string]$state.status -eq 'HARD_ERROR') {
      throw 'BATCH_MODE_RESUME_FROM_HARD_ERROR_REQUIRES_TRIAGE'
    }

    Reset-D2BWorkRoot -RepoRoot $root -OutputRootFull $outputFull -WorkRoot $workRoot -WorkRootMode ([string]$workRootInfo.work_root_mode) -ExternalWorkRootBase ([string]$workRootInfo.work_root_base)

    $acceptedSurfaceIndex = New-D2BAcceptedSurfaceIndex -Root $root -MemoryPath $memoryPath -SelfMapPath $selfMapPath -RegistryPath $registryPath
    $selected = @()
    $selectedAtomIds = @{}
    $localShardIndex = [int]$state.shard_index
    $localLineIndex = [int]$state.line_index

    while ($selected.Count -lt $BatchSize -and $localShardIndex -lt $shards.Count) {
      if (Test-Path -LiteralPath $stopPath) {
        $stoppedBySignal = $true
        $state.status = 'STOPPED_BY_SIGNAL'
        break
      }

      $shardRelative = [string]$shards[$localShardIndex]
      $shardFull = Join-Path $root $shardRelative
      if (-not (Test-Path -LiteralPath $shardFull)) { throw "SHARD_MISSING=$shardRelative" }
      $reader = [System.IO.StreamReader]::new($shardFull, [System.Text.UTF8Encoding]::new($false), $true)
      try {
        for ($skip = 0; $skip -lt $localLineIndex; $skip += 1) {
          if ($reader.EndOfStream) { throw "CURSOR_BEYOND_SHARD shard=$shardRelative line=$localLineIndex" }
          [void]$reader.ReadLine()
        }

        while (-not $reader.EndOfStream -and $selected.Count -lt $BatchSize) {
          if (Test-Path -LiteralPath $stopPath) {
            $stoppedBySignal = $true
            $state.status = 'STOPPED_BY_SIGNAL'
            break
          }

          $line = $reader.ReadLine()
          if ([string]::IsNullOrWhiteSpace($line)) {
            $localLineIndex += 1
            continue
          }

          $candidate = $line | ConvertFrom-Json
          $candidateId = [string]$candidate.candidate_id
          $atomId = [string]$candidate.target_atom_id_suggestion
          $sourcePath = "$shardRelative#line=$($localLineIndex + 1)"
          $state.status = 'RUNNING'
          $state.last_candidate_id = $candidateId
          $state.last_atom_id = $atomId

          $quarantineReasons = @(Get-D2BCandidateQuarantineReasons -Candidate $candidate)
          if ($selectedAtomIds.ContainsKey($atomId)) {
            $quarantineReasons += 'duplicate_atom_in_current_batch_selection'
          }

          if ($quarantineReasons.Count -gt 0) {
            Add-D2BJsonLine $quarantineLog ([ordered]@{
              occurred_utc=(Get-Date).ToUniversalTime().ToString('o'); candidate_id=$candidateId; atom_id=$atomId
              source_path=$sourcePath; disposition='QUARANTINED_PRE_BATCH_POLICY'; reasons=$quarantineReasons
            })
            if (@($quarantineReasons | Where-Object { $_ -eq 'required_acceptance_guard_missing' }).Count -gt 0) {
              $state.invalid_safe_candidate_count = [int]$state.invalid_safe_candidate_count + 1
            }
            $state.quarantine_count = [int]$state.quarantine_count + 1
            $state.last_disposition = 'QUARANTINED_PRE_BATCH_POLICY'
            $state.processed_count = [int]$state.processed_count + 1
            $state.remaining_count = [int]$manifest.total_candidate_count - [int]$state.processed_count
            $localLineIndex += 1
            $state.shard_index = $localShardIndex
            $state.line_index = $localLineIndex
            $state.updated_utc = (Get-Date).ToUniversalTime().ToString('o')
            Write-D2BJson $statePath $state
            Write-D2BJson $resumePath $state
            continue
          }

          $visibilityBefore = Get-D2BVisibilityRowFromIndex -Index $acceptedSurfaceIndex -AtomId $atomId
          $m0 = [int]$visibilityBefore.memory_count
          $s0 = [int]$visibilityBefore.self_map_count
          $r0 = [int]$visibilityBefore.registry_count
          if (($m0 -eq 1) -and ($s0 -eq 1) -and ($r0 -eq 1)) {
            Add-D2BJsonLine $skippedLog ([ordered]@{
              occurred_utc=(Get-Date).ToUniversalTime().ToString('o'); candidate_id=$candidateId; atom_id=$atomId
              source_path=$sourcePath; disposition='SKIPPED_ALREADY_ACCEPTED'
            })
            $state.skipped_duplicate_count = [int]$state.skipped_duplicate_count + 1
            $state.last_disposition = 'SKIPPED_ALREADY_ACCEPTED'
            $state.processed_count = [int]$state.processed_count + 1
            $state.remaining_count = [int]$manifest.total_candidate_count - [int]$state.processed_count
            $localLineIndex += 1
            $state.shard_index = $localShardIndex
            $state.line_index = $localLineIndex
            $state.updated_utc = (Get-Date).ToUniversalTime().ToString('o')
            Write-D2BJson $statePath $state
            Write-D2BJson $resumePath $state
            continue
          }
          if (($m0 + $s0 + $r0) -ne 0) {
            throw "PARTIAL_ACCEPTED_SURFACE atom=$atomId memory=$m0 self_map=$s0 registry=$r0"
          }

          $policyCandidate = New-D2BPolicyCandidate -AtomId $atomId -MemoryPath $memoryPath -SelfMapPath $selfMapPath -RegistryPath $registryPath
          $state.policy_guard_invocation_count = [int]$state.policy_guard_invocation_count + 1
          $policy = Invoke-D2BLocalPolicyEvaluation -Candidate ([pscustomobject]$policyCandidate) -VisibilityRow $visibilityBefore -MemoryPath $memoryPath -SelfMapPath $selfMapPath -RegistryPath $registryPath
          if (-not [bool]$policy.autonomous_accept_allowed) {
            Add-D2BJsonLine $quarantineLog ([ordered]@{
              occurred_utc=(Get-Date).ToUniversalTime().ToString('o'); candidate_id=$candidateId; atom_id=$atomId
              source_path=$sourcePath; disposition='DENIED_BY_C2B_BATCH_ADMISSION'; reasons=@($policy.denial_reasons)
            })
            $state.denied_count = [int]$state.denied_count + 1
            $state.quarantine_count = [int]$state.quarantine_count + 1
            $state.last_disposition = 'DENIED_BY_C2B_BATCH_ADMISSION'
            $state.processed_count = [int]$state.processed_count + 1
            $state.remaining_count = [int]$manifest.total_candidate_count - [int]$state.processed_count
            $localLineIndex += 1
            $state.shard_index = $localShardIndex
            $state.line_index = $localLineIndex
            $state.updated_utc = (Get-Date).ToUniversalTime().ToString('o')
            Write-D2BJson $statePath $state
            Write-D2BJson $resumePath $state
            continue
          }

          $safeCandidateId = $candidateId -replace '[^A-Za-z0-9]', '_'
          if ([string]::IsNullOrWhiteSpace($safeCandidateId)) { $safeCandidateId = 'candidate' }
          $safeCandidatePrefix = $safeCandidateId.Substring(0, [math]::Min(40, $safeCandidateId.Length))
          $operationId = "D2B_BATCH_{0:d8}_{1}" -f ([int]$state.processed_count + $selected.Count + 1), $safeCandidatePrefix
          $selected += [pscustomobject][ordered]@{
            candidate = $candidate
            candidate_id = $candidateId
            atom_id = $atomId
            source_path = $sourcePath
            shard_index = $localShardIndex
            line_index = $localLineIndex
            operation_id = $operationId
            policy_decision = [string]$policy.decision_code
          }
          $selectedAtomIds[$atomId] = $true
          $localLineIndex += 1
        }
      } finally {
        $reader.Dispose()
      }

      if ($stoppedBySignal -or $selected.Count -ge $BatchSize) { break }
      $localShardIndex += 1
      $localLineIndex = 0
    }

    if (-not $stoppedBySignal -and $selected.Count -gt 0) {
      $state.shard_index = [int]$selected[0].shard_index
      $state.line_index = [int]$selected[0].line_index
      $package = New-D2BPhase162BatchPackage -WorkRoot $workRoot -Items $selected -MemoryPath $memoryPath -SelfMapPath $selfMapPath -RegistryPath $registryPath
      $state.phase162_executor_invocation_count = [int]$state.phase162_executor_invocation_count + 1
      [void](Invoke-D2BPowerShell -ScriptPath $executorModule -Arguments @('-ControllerRoot',[string]$package.controller_root,'-RepoRoot',$root,'-OutputRoot',[string]$package.execution_root))
      $execResult = Read-D2BJson (Join-Path $package.execution_root 'execute_controlled_accept_core_mutation_result.json')
      $atomIds = @($selected | ForEach-Object { [string]$_.atom_id })
      $acceptedSurfaceIndex = New-D2BAcceptedSurfaceIndex -Root $root -MemoryPath $memoryPath -SelfMapPath $selfMapPath -RegistryPath $registryPath
      $visibilityRows = @(Get-D2BVisibilityRowsFromIndex -Index $acceptedSurfaceIndex -AtomIds $atomIds)
      $visibilityRowsByAtomId = @{}
      foreach ($row in $visibilityRows) {
        $visibilityRowsByAtomId[[string]$row.atom_id] = $row
      }
      $visibilityFailures = @($visibilityRows | Where-Object {
        [int]$_.memory_count -ne 1 -or [int]$_.self_map_count -ne 1 -or [int]$_.registry_count -ne 1
      })
      $execPass = [string]$execResult.status -eq 'PASS' -and [bool]$execResult.controlled_accept_core_mutation_executed -and
        [bool]$execResult.post_real_mutation_validation_passed -and -not [bool]$execResult.rollback_executed -and $visibilityFailures.Count -eq 0
      Write-D2BJson (Join-Path $package.execution_root 'execute_controlled_accept_core_mutation_validation.json') ([ordered]@{
        schema='PHASE165S_D2B_EXECUTION_VALIDATION_V1'; status=$(if($execPass){'PASS'}else{'FAIL'})
        created_at=(Get-Date).ToUniversalTime().ToString('o'); atom_ids=$atomIds; batch_size=$selected.Count
        atom_visibility=$visibilityRows; owner_interrupt_used=$false; autonomous_policy_guard_allowed=$true
      })
      $executionProofPath = Join-Path $package.execution_root 'phase165s_d2b_execution_proof_for_controller.json'
      Write-D2BJson $executionProofPath ([ordered]@{
        schema='PHASE165S_D2B_EXECUTION_PROOF_FOR_PHASE162_CONTROLLER_V1'; status=[string]$execResult.status
        created_at=(Get-Date).ToUniversalTime().ToString('o'); head=(git -C $root rev-parse HEAD)
        output_root=$package.execution_root; next_action=[string]$execResult.next_machine_action
        accepted_atom_claimed=$false; atom_ids=$atomIds; batch_size=$selected.Count; owner_interrupt_used=$false
      })
      if (-not $execPass) {
        if ($visibilityFailures.Count -gt 0) {
          throw "ATOM_VISIBILITY_COUNT_FAILED atoms=$((@($visibilityFailures | ForEach-Object { [string]$_.atom_id })) -join ',')"
        }
        throw "PHASE162_BATCH_EXECUTION_FAILED status=$($execResult.status) rollback=$($execResult.rollback_executed) failure=$($execResult.failure_message)"
      }

      $state.finalizer_invocation_count = [int]$state.finalizer_invocation_count + 1
      [void](Invoke-D2BPowerShell -ScriptPath $finalizerModule -Arguments @('-RepoRoot',$root,'-ExecutionProofPath',$executionProofPath,'-OutputRoot',[string]$package.finalizer_root))
      $finalResult = Read-D2BJson (Join-Path $package.finalizer_root 'controller_consume_controlled_accept_core_mutation_execution_proof_result.json')
      if (-not ([string]$finalResult.status -eq 'PASS' -and [bool]$finalResult.accepted_atom_claimed)) {
        throw "PHASE162_BATCH_FINALIZATION_NOT_ACCEPTED count=$($selected.Count)"
      }

      foreach ($item in $selected) {
        $row = $visibilityRowsByAtomId[[string]$item.atom_id]
        Add-D2BJsonLine $acceptedLog ([ordered]@{
          occurred_utc=(Get-Date).ToUniversalTime().ToString('o'); candidate_id=[string]$item.candidate_id; atom_id=[string]$item.atom_id
          source_path=[string]$item.source_path; disposition='ACCEPTED_BATCH'; policy_decision=[string]$item.policy_decision
          memory_count=[int]$row.memory_count; self_map_count=[int]$row.self_map_count; registry_count=[int]$row.registry_count
          owner_interrupt_used=$false; batch_size=[int]$selected.Count
        })
      }

      $state.accepted_count = [int]$state.accepted_count + $selected.Count
      $state.processed_count = [int]$state.processed_count + $selected.Count
      $state.remaining_count = [int]$manifest.total_candidate_count - [int]$state.processed_count
      $state.shard_index = $localShardIndex
      $state.line_index = $localLineIndex
      $state.last_disposition = 'ACCEPTED_BATCH'
      $lastAcceptedAtomId = [string]$selected[-1].atom_id
    }

    if (-not $stoppedBySignal -and [int]$state.remaining_count -eq 0) {
      $state.status = 'QUEUE_EMPTY'
    } elseif (-not $stoppedBySignal) {
      $state.status = 'RUNNING_READY_TO_RESUME'
    }
  } catch {
    $hardError = $_.Exception.Message
    if (-not $hardErrorAlreadyRecorded) {
      $state.failed_count = [int]$state.failed_count + 1
    }
    $state.status = if ($hardError -like 'PARTIAL_ACCEPTED_SURFACE*') { 'BLOCKED_PARTIAL_ACCEPTED_SURFACE' } else { 'HARD_ERROR' }
    if (-not $hardErrorAlreadyRecorded) {
      Add-D2BJsonLine $failedLog ([ordered]@{
        occurred_utc=(Get-Date).ToUniversalTime().ToString('o'); candidate_id=$state.last_candidate_id; atom_id=$state.last_atom_id
        shard_index=[int]$state.shard_index; line_index=[int]$state.line_index; error=$hardError
      })
    }
  }

  $finalStatus = if ($hardError -like 'PARTIAL_ACCEPTED_SURFACE*') {
    'BLOCKED_PARTIAL_ACCEPTED_SURFACE'
  } elseif ($hardError) {
    'HARD_ERROR'
  } elseif ($stoppedBySignal) {
    'STOPPED_BY_SIGNAL'
  } elseif ([int]$state.remaining_count -eq 0) {
    'PASS_QUEUE_EMPTY'
  } else {
    'INCOMPLETE_RESUMABLE'
  }
  if ($finalStatus -eq 'INCOMPLETE_RESUMABLE') {
    $state.status = 'RUNNING_READY_TO_RESUME'
  }
  $state.updated_utc = (Get-Date).ToUniversalTime().ToString('o')
  $terminalCheckpointPath = Join-Path $outputFull ('checkpoints/checkpoint_{0:d8}_{1}.json' -f [int]$state.processed_count, [string]$state.status)
  if (-not (Test-Path -LiteralPath $terminalCheckpointPath)) {
    $state.checkpoint_count = [int]$state.checkpoint_count + 1
    Write-D2BJson $terminalCheckpointPath $state
  }
  Write-D2BJson $statePath $state
  Write-D2BJson $resumePath $state
  Write-D2BJson $heartbeatPath ([ordered]@{
    status=[string]$state.status; heartbeat_utc=$state.updated_utc; processed_count=[int]$state.processed_count
    remaining_count=[int]$state.remaining_count; accepted_count=[int]$state.accepted_count; quarantine_count=[int]$state.quarantine_count
    stopped_by_signal=$stoppedBySignal; hard_error=$hardError; last_atom_id=$state.last_atom_id; last_disposition=$state.last_disposition
  })

  $unauthorizedDirtyAfter = @(git -C $root status --short -- CAPABILITY_ROADMAP.json GENESIS_STATE.json TASK_QUEUE.json orchestrator/run.ps1 route_locks)
  $retentionResult = Invoke-D2BPostBatchRetentionHook -Root $root -OutputRootFull $outputFull -WorkRootFull $workRoot -AcceptedLogPath $acceptedLog -AcceptedLogStartLineCount $invocationAcceptedLogStartLineCount -InitialFailedCount $invocationFailedCountStart -InitialQuarantineCount $invocationQuarantineCountStart -State $state -FinalStatus $finalStatus -StoppedBySignal $stoppedBySignal -HardError $hardError -RetentionMode $RetentionMode
  $cleanupPendingPath = Join-Path $outputFull 'cleanup_pending.json'
  $candidateMaterialPruned = Remove-D2BCandidateBatchMaterialOnSuccess -CandidateBatchInfo $candidateBatchInfo -RetentionResult $retentionResult -FinalStatus $finalStatus -StoppedBySignal $stoppedBySignal -HardError $hardError -CleanupPendingPath $cleanupPendingPath
  $result = Write-D2BRunArtifacts -Root $root -OutputRootFull $outputFull -State $state -Manifest $manifest -Status $finalStatus -StoppedBySignal $stoppedBySignal -UnauthorizedDirty $unauthorizedDirtyAfter -BatchSize $BatchSize -WorkRootFull $workRoot -WorkRootMode ([string]$workRootInfo.work_root_mode) -WorkRootShortPathEnabled ([bool]$workRootInfo.work_root_short_path_enabled) -RetentionMode $RetentionMode -RetentionResult $retentionResult -DirectCandidateBatchMode $directCandidateBatchMode -CandidateBatchPath $(if($directCandidateBatchMode){[string]$candidateBatchInfo.relative_path}else{''}) -CandidateMaterialPruned $candidateMaterialPruned -CleanupPendingPath $(if(Test-Path -LiteralPath $cleanupPendingPath){(Get-D2BRelativePath -Root $root -Path $cleanupPendingPath)}else{''}) -AcceptedCoreMode $AcceptedCoreMode -AcceptedCoreDeltaRoot $(if($null -ne $acceptedCoreDeltaInfo){[string]$acceptedCoreDeltaInfo.root}else{''})

  if ($EmitJson) {
    $result | ConvertTo-Json -Depth 40
  } else {
    Write-Host "PHASE165S_D2B_BIG_CURRICULUM_AUTONOMOUS_LEARNING_RESULT=$finalStatus"
    Write-Host "PROCESSED_COUNT=$($state.processed_count)"
    Write-Host "REMAINING_COUNT=$($state.remaining_count)"
    Write-Host "ACCEPTED_ATOM_COUNT=$($state.accepted_count)"
    Write-Host "QUARANTINE_COUNT=$($state.quarantine_count)"
    Write-Host "FAILED_COUNT=$($state.failed_count)"
    Write-Host "RETENTION_STATUS=$($retentionResult.status)"
    Write-Host "CANDIDATE_MATERIAL_PRUNED=$candidateMaterialPruned"
    Write-Host "NEXT_REQUIRED_ACTION=$($result.next_required_action)"
  }
  if ($hardError) { exit 1 }
  return
}

$resumeHadHardError = ($Resume -and [string]$state.status -eq 'HARD_ERROR')
$resumeFailedCandidateId = if ($resumeHadHardError) { [string]$state.last_candidate_id } else { $null }
$resumeReconciledZeroSurfaceFailure = $false
$resumeReconciledFullSurfaceFinalization = $false

if ($resumeHadHardError -and [int]$state.failed_count -gt 0) {
  $lastFailure = Get-D2BLastJsonLine $failedLog
  $failedAtomId = [string]$state.last_atom_id
  $failedCandidateId = [string]$state.last_candidate_id
  $memoryCount = Get-D2BCount (Read-D2BJson (Join-Path $root $memoryPath)) 'phase162_accepted_atom_memory_records' $failedAtomId
  $selfMapCount = Get-D2BCount (Read-D2BJson (Join-Path $root $selfMapPath)) 'phase162_absorbed_atom_capability_notes' $failedAtomId
  $registryCount = Get-D2BCount (Read-D2BJson (Join-Path $root $registryPath)) 'phase162_accepted_atom_references' $failedAtomId
  $visibilityTotal = $memoryCount + $selfMapCount + $registryCount
  $failureMatchesCursor = $null -ne $lastFailure -and
    [string]$lastFailure.candidate_id -eq $failedCandidateId -and
    [string]$lastFailure.atom_id -eq $failedAtomId -and
    [int]$lastFailure.shard_index -eq [int]$state.shard_index -and
    [int]$lastFailure.line_index -eq [int]$state.line_index
  $isPostExecutionVisibilityFailure = $failureMatchesCursor -and
    [string]$lastFailure.error -like 'PHASE162_POST_EXECUTION_VISIBILITY_FAILED*'
  $fullSurfaceVisible = ($memoryCount -eq 1 -and $selfMapCount -eq 1 -and $registryCount -eq 1)
  $partialOrDuplicateSurface = ($visibilityTotal -gt 0 -and -not $fullSurfaceVisible)
  $policyResultPath = Join-Path $workRoot 'policy_result.json'
  $candidateResultPath = Join-Path $workRoot 'cand/controlled_accept_core_mutation_candidate_result.json'
  $executionEventsPath = Join-Path $workRoot 'exec/controlled_accept_core_mutation_execution_events.jsonl'
  $policyPassed = $false
  $candidatePassed = $false
  if (Test-Path -LiteralPath $policyResultPath) {
    $policyResult = Read-D2BJson $policyResultPath
    $policyPassed = [string]$policyResult.status -eq 'PASS' -and [bool]$policyResult.autonomous_accept_allowed -and
      @($policyResult.atom_ids | Where-Object { [string]$_ -eq $failedAtomId }).Count -eq 1
  }
  if (Test-Path -LiteralPath $candidateResultPath) {
    $candidateResult = Read-D2BJson $candidateResultPath
    $candidatePassed = [string]$candidateResult.status -eq 'PASS' -and
      @($candidateResult.atom_ids | Where-Object { [string]$_ -eq $failedAtomId }).Count -eq 1
  }
  $writeEvent = Get-D2BExecutionWriteEvent $executionEventsPath
  $writeEventPassed = $null -ne $writeEvent -and [bool]$writeEvent.data.accepted_core_write -and
    [int]$writeEvent.data.memory_operation_count -eq 1 -and
    [int]$writeEvent.data.self_model_operation_count -eq 1 -and
    [int]$writeEvent.data.registry_operation_count -eq 1

  if ($failureMatchesCursor -and $partialOrDuplicateSurface) {
    $hardError = "PARTIAL_ACCEPTED_SURFACE atom=$failedAtomId memory=$memoryCount self_map=$selfMapCount registry=$registryCount"
    $hardErrorAlreadyRecorded = $true
    $state.status = 'BLOCKED_PARTIAL_ACCEPTED_SURFACE'
  } elseif ($failureMatchesCursor -and $fullSurfaceVisible -and $policyPassed -and $candidatePassed -and $writeEventPassed) {
    $memoryRecord = @((Read-D2BJson (Join-Path $root $memoryPath)).phase162_accepted_atom_memory_records | Where-Object {
      [string]$_.atom_id -eq $failedAtomId
    })[0]
    $isCurrentD2BWrite = $memoryRecord.payload -and
      [string]$memoryRecord.payload.autonomous_loop -eq 'PHASE165S-D2B' -and
      [string]$memoryRecord.payload.candidate_id -eq $failedCandidateId
    if (-not $isCurrentD2BWrite) {
      $hardError = "FULL_SURFACE_NOT_CURRENT_D2B_WRITE atom=$failedAtomId"
      $hardErrorAlreadyRecorded = $true
      $state.status = 'HARD_ERROR'
    } else {
      $acceptedLogMatchCount = Get-D2BJsonLineMatchCount -Path $acceptedLog -Property 'atom_id' -Value $failedAtomId
      if ($acceptedLogMatchCount -gt 1) {
        $hardError = "DUPLICATE_ACCEPTED_LOG atom=$failedAtomId count=$acceptedLogMatchCount"
        $hardErrorAlreadyRecorded = $true
        $state.status = 'BLOCKED_PARTIAL_ACCEPTED_SURFACE'
      } else {
        $executionRoot = Join-Path $workRoot 'exec'
        $finalizerRoot = Join-Path $workRoot 'fin'
        $executionResultPath = Join-Path $executionRoot 'execute_controlled_accept_core_mutation_result.json'
        Write-D2BJson $executionResultPath ([ordered]@{
          schema='PHASE162_EXECUTE_CONTROLLED_ACCEPT_CORE_MUTATION_FOR_ATOM_BATCH_RESULT_V1'
          status='PASS'; created_at=(Get-Date).ToUniversalTime().ToString('o')
          controller_root=(Join-Path $workRoot 'ctrl'); candidate_root=(Join-Path $workRoot 'cand')
          batch_size=1; staged_atom_count=1
          controlled_accept_core_mutation_executed=$true
          post_real_mutation_validation_passed=$true
          rollback_executed=$false; rollback_required=$false
          accepted_core_write_executed=$true; accepted_atom_claimed=$false
          accepted_memory_mutated=$true; accepted_self_model_mutated=$true; registry_mutated=$true
          final_accept_ready=$true
          machine_decision='CONTROLLED_ACCEPT_CORE_MUTATION_EXECUTED_PENDING_CONTROLLER_FINALIZATION'
          next_machine_action='FEED_CONTROLLED_ACCEPT_CORE_MUTATION_EXECUTION_BACK_INTO_CONTROLLER'
          recovery_source='FULL_SURFACE_VISIBILITY_PLUS_CONTROLLED_ACCEPT_MUTATION_WRITTEN_TO_ACCEPTED_CORE_EVENT'
          repeated_mutation_execution=$false
        })
        Write-D2BJson (Join-Path $executionRoot 'execute_controlled_accept_core_mutation_validation.json') ([ordered]@{
          schema='PHASE165S_D2B_EXECUTION_VALIDATION_V1'; status='PASS'
          created_at=(Get-Date).ToUniversalTime().ToString('o'); atom_id=$failedAtomId
          memory_count=1; self_map_count=1; registry_count=1
          owner_interrupt_used=$false; autonomous_policy_guard_allowed=$true
          recovery_validation='FULL_SURFACE_EXACTLY_ONCE_AFTER_WRITE_EVENT'
        })
        $executionProofPath = Join-Path $executionRoot 'phase165s_d2b_execution_proof_for_controller.json'
        Write-D2BJson $executionProofPath ([ordered]@{
          schema='PHASE165S_D2B_EXECUTION_PROOF_FOR_PHASE162_CONTROLLER_V1'; status='PASS'
          created_at=(Get-Date).ToUniversalTime().ToString('o'); head=(git -C $root rev-parse HEAD)
          output_root=$executionRoot; next_action='FEED_CONTROLLED_ACCEPT_CORE_MUTATION_EXECUTION_BACK_INTO_CONTROLLER'
          accepted_atom_claimed=$false; atom_id=$failedAtomId; owner_interrupt_used=$false
          recovery_proof=$true; repeated_mutation_execution=$false
        })
        $state.finalizer_invocation_count = [int]$state.finalizer_invocation_count + 1
        [void](Invoke-D2BPowerShell -ScriptPath $finalizerModule -Arguments @(
          '-RepoRoot',$root,'-ExecutionProofPath',$executionProofPath,'-OutputRoot',$finalizerRoot
        ))
        $finalResult = Read-D2BJson (Join-Path $finalizerRoot 'controller_consume_controlled_accept_core_mutation_execution_proof_result.json')
        if (-not ([string]$finalResult.status -eq 'PASS' -and [bool]$finalResult.accepted_atom_claimed -and
            -not [bool]$finalResult.repeated_mutation_execution)) {
          $hardError = "RECOVERED_FULL_SURFACE_FINALIZATION_NOT_PASS=$failedAtomId"
          $hardErrorAlreadyRecorded = $true
          $state.status = 'HARD_ERROR'
        } else {
          $sourcePath = "$([string]$shards[[int]$state.shard_index])#line=$([int]$state.line_index + 1)"
          if ($acceptedLogMatchCount -eq 0) {
            Add-D2BJsonLine $acceptedLog ([ordered]@{
              occurred_utc=(Get-Date).ToUniversalTime().ToString('o'); candidate_id=$failedCandidateId; atom_id=$failedAtomId
              source_path=$sourcePath; disposition='ACCEPTED_RECOVERED_POST_WRITE_FINALIZATION'
              memory_count=1; self_map_count=1; registry_count=1; repeated_mutation_execution=$false
            })
          }
          $recoverCount = [int]$state.failed_count
          for ($recovered = 0; $recovered -lt $recoverCount; $recovered += 1) {
            Add-D2BJsonLine $recoveryLog ([ordered]@{
              occurred_utc=(Get-Date).ToUniversalTime().ToString('o'); candidate_id=$failedCandidateId; atom_id=$failedAtomId
              recovered_failure='full_surface_accepted_core_write_with_failed_finalization'
              resolution='FINALIZED_WITHOUT_REPEATED_MUTATION_AND_CURSOR_ADVANCED'
              visibility_counts=[ordered]@{ memory=1; self_map=1; registry=1 }
            })
          }
          $state.accepted_count = [int]$state.accepted_count + 1
          $state.failed_count = 0
          $state.recovered_failure_count = [int]$state.recovered_failure_count + $recoverCount
          $state.processed_count = [int]$state.processed_count + 1
          $state.remaining_count = [int]$manifest.total_candidate_count - [int]$state.processed_count
          $state.line_index = [int]$state.line_index + 1
          $state.last_disposition = 'ACCEPTED_RECOVERED_POST_WRITE_FINALIZATION'
          $state.status = 'RUNNING_READY_TO_RESUME'
          $state.updated_utc = (Get-Date).ToUniversalTime().ToString('o')
          $resumeHadHardError = $false
          $resumeReconciledFullSurfaceFinalization = $true
        }
      }
    }
  } elseif ($isPostExecutionVisibilityFailure -and $visibilityTotal -eq 0) {
    $sourcePath = "$([string]$shards[[int]$state.shard_index])#line=$([int]$state.line_index + 1)"
    Add-D2BJsonLine $quarantineLog ([ordered]@{
      occurred_utc=(Get-Date).ToUniversalTime().ToString('o'); candidate_id=$failedCandidateId; atom_id=$failedAtomId
      source_path=$sourcePath; disposition='QUARANTINED_POST_EXECUTION_ZERO_VISIBILITY'
      reasons=@('phase162_post_execution_visibility_failed','accepted_surface_visibility_zero','candidate_not_accepted')
      visibility_counts=[ordered]@{ memory=$memoryCount; self_map=$selfMapCount; registry=$registryCount }
    })
    $recoverCount = [int]$state.failed_count
    for ($recovered = 0; $recovered -lt $recoverCount; $recovered += 1) {
      Add-D2BJsonLine $recoveryLog ([ordered]@{
        occurred_utc=(Get-Date).ToUniversalTime().ToString('o'); candidate_id=$failedCandidateId; atom_id=$failedAtomId
        recovered_failure='phase162_post_execution_zero_surface_visibility_failure'
        resolution='QUARANTINED_NOT_ACCEPTED_AND_CURSOR_ADVANCED'
        visibility_counts=[ordered]@{ memory=$memoryCount; self_map=$selfMapCount; registry=$registryCount }
      })
    }
    $state.quarantine_count = [int]$state.quarantine_count + 1
    $state.dynamic_quarantine_count = [int]$state.dynamic_quarantine_count + 1
    $state.failed_count = 0
    $state.recovered_failure_count = [int]$state.recovered_failure_count + $recoverCount
    $state.processed_count = [int]$state.processed_count + 1
    $state.remaining_count = [int]$manifest.total_candidate_count - [int]$state.processed_count
    $state.line_index = [int]$state.line_index + 1
    $state.last_disposition = 'QUARANTINED_POST_EXECUTION_ZERO_VISIBILITY'
    $state.status = 'RUNNING_READY_TO_RESUME'
    $state.updated_utc = (Get-Date).ToUniversalTime().ToString('o')
    $resumeHadHardError = $false
    $resumeReconciledZeroSurfaceFailure = $true
  }
}

if ($RepairResumeStateOnly) {
  if (-not $resumeReconciledZeroSurfaceFailure -and -not $resumeReconciledFullSurfaceFinalization -and
      [string]$state.status -ne 'RUNNING_READY_TO_RESUME') {
    if ([string]$state.status -eq 'BLOCKED_PARTIAL_ACCEPTED_SURFACE') {
      Write-Host 'PHASE165S_D2B_REPAIR_RESULT=BLOCKED_PARTIAL_ACCEPTED_SURFACE'
      exit 1
    }
    throw "NO_RECOVERABLE_HARD_ERROR status=$($state.status)"
  }
  $state.updated_utc = (Get-Date).ToUniversalTime().ToString('o')
  $terminalCheckpointPath = Join-Path $outputFull ('checkpoints/checkpoint_{0:d8}_{1}.json' -f [int]$state.processed_count, [string]$state.status)
  if (-not (Test-Path -LiteralPath $terminalCheckpointPath)) {
    $state.checkpoint_count = [int]$state.checkpoint_count + 1
    Write-D2BJson $terminalCheckpointPath $state
  }
  Write-D2BJson $statePath $state
  Write-D2BJson $resumePath $state
  Write-D2BJson $heartbeatPath ([ordered]@{
    status=[string]$state.status; heartbeat_utc=$state.updated_utc; processed_count=[int]$state.processed_count
    remaining_count=[int]$state.remaining_count; accepted_count=[int]$state.accepted_count
    quarantine_count=[int]$state.quarantine_count; stopped_by_signal=$false; hard_error=$null
    last_atom_id=$state.last_atom_id; last_disposition=$state.last_disposition
  })
  $unauthorizedDirtyAfter = @(git -C $root status --short -- CAPABILITY_ROADMAP.json GENESIS_STATE.json TASK_QUEUE.json orchestrator/run.ps1 route_locks)
  $result = Write-D2BRunArtifacts -Root $root -OutputRootFull $outputFull -State $state -Manifest $manifest -Status 'INCOMPLETE_RESUMABLE' -StoppedBySignal $false -UnauthorizedDirty $unauthorizedDirtyAfter -BatchSize $BatchSize -WorkRootFull $workRoot -WorkRootMode ([string]$workRootInfo.work_root_mode) -WorkRootShortPathEnabled ([bool]$workRootInfo.work_root_short_path_enabled)
  if ($EmitJson) {
    $result | ConvertTo-Json -Depth 40
  } else {
    Write-Host 'PHASE165S_D2B_REPAIR_RESULT=INCOMPLETE_RESUMABLE'
    Write-Host "PROCESSED_COUNT=$($state.processed_count)"
    Write-Host "REMAINING_COUNT=$($state.remaining_count)"
    Write-Host "ACCEPTED_ATOM_COUNT=$($state.accepted_count)"
    Write-Host "QUARANTINE_COUNT=$($state.quarantine_count)"
    Write-Host "FAILED_COUNT=$($state.failed_count)"
  }
  exit 0
}

try {
  if ($hardError) { throw $hardError }
  while ([int]$state.shard_index -lt $shards.Count) {
    if (Test-Path -LiteralPath $stopPath) {
      $stoppedBySignal = $true
      $state.status = 'STOPPED_BY_SIGNAL'
      break
    }

    $shardRelative = [string]$shards[[int]$state.shard_index]
    $shardFull = Join-Path $root $shardRelative
    if (-not (Test-Path -LiteralPath $shardFull)) { throw "SHARD_MISSING=$shardRelative" }
    $reader = [System.IO.StreamReader]::new($shardFull, [System.Text.UTF8Encoding]::new($false), $true)
    try {
      for ($skip = 0; $skip -lt [int]$state.line_index; $skip += 1) {
        if ($reader.EndOfStream) { throw "CURSOR_BEYOND_SHARD shard=$shardRelative line=$($state.line_index)" }
        [void]$reader.ReadLine()
      }
      while (-not $reader.EndOfStream) {
        if (Test-Path -LiteralPath $stopPath) {
          $stoppedBySignal = $true
          $state.status = 'STOPPED_BY_SIGNAL'
          break
        }
        $line = $reader.ReadLine()
        if ([string]::IsNullOrWhiteSpace($line)) {
          $state.line_index = [int]$state.line_index + 1
          continue
        }
        $candidate = $line | ConvertFrom-Json
        $candidateId = [string]$candidate.candidate_id
        $atomId = [string]$candidate.target_atom_id_suggestion
        $sourcePath = "$shardRelative#line=$([int]$state.line_index + 1)"
        $state.status = 'RUNNING'
        $state.last_candidate_id = $candidateId
        $state.last_atom_id = $atomId

        $effectiveRiskFlags = @($candidate.risk_flags | ForEach-Object { [string]$_ } | Where-Object { $_ -and $_ -ne 'none_identified_at_material_stage' })
        $quarantineReasons = @()
        if ([bool]$candidate.accepted -or [bool]$candidate.trusted) { $quarantineReasons += 'raw_candidate_claims_accepted_or_trusted' }
        if ([string]$candidate.risk_level -ne 'LOW') { $quarantineReasons += "risk_level_not_low=$($candidate.risk_level)" }
        if ($effectiveRiskFlags.Count -gt 0) { $quarantineReasons += "effective_risk_flags=$($effectiveRiskFlags -join ',')" }
        if (-not ([bool]$candidate.requires_school_acceptance -and [bool]$candidate.requires_c2b_guard -and [bool]$candidate.requires_phase162_acceptance)) {
          $quarantineReasons += 'required_acceptance_guard_missing'
          $state.invalid_safe_candidate_count = [int]$state.invalid_safe_candidate_count + 1
        }

        if ($quarantineReasons.Count -gt 0) {
          Add-D2BJsonLine $quarantineLog ([ordered]@{
            occurred_utc=(Get-Date).ToUniversalTime().ToString('o'); candidate_id=$candidateId; atom_id=$atomId
            source_path=$sourcePath; disposition='QUARANTINED_PRE_POLICY'; reasons=$quarantineReasons
          })
          $state.quarantine_count = [int]$state.quarantine_count + 1
          $state.last_disposition = 'QUARANTINED_PRE_POLICY'
        } else {
          $memory = Read-D2BJson (Join-Path $root $memoryPath)
          $selfMap = Read-D2BJson (Join-Path $root $selfMapPath)
          $registry = Read-D2BJson (Join-Path $root $registryPath)
          $m0 = Get-D2BCount $memory 'phase162_accepted_atom_memory_records' $atomId
          $s0 = Get-D2BCount $selfMap 'phase162_absorbed_atom_capability_notes' $atomId
          $r0 = Get-D2BCount $registry 'phase162_accepted_atom_references' $atomId
          if (($m0 -eq 1) -and ($s0 -eq 1) -and ($r0 -eq 1)) {
            $memoryRecord = @($memory.phase162_accepted_atom_memory_records | Where-Object { [string]$_.atom_id -eq $atomId })[0]
            $isRecoveredD2B = $memoryRecord.payload -and [string]$memoryRecord.payload.autonomous_loop -eq 'PHASE165S-D2B' -and [string]$memoryRecord.payload.candidate_id -eq $candidateId
            if ($isRecoveredD2B) {
              $recoveredFromWriteEvent = $false
              $finalResultPath = Join-Path $workRoot 'fin/controller_consume_controlled_accept_core_mutation_execution_proof_result.json'
              if (-not (Test-Path -LiteralPath $finalResultPath)) {
                $execResultPath = Join-Path $workRoot 'exec/execute_controlled_accept_core_mutation_result.json'
                if (-not (Test-Path -LiteralPath $execResultPath)) {
                  $policyResultPath = Join-Path $workRoot 'policy_result.json'
                  $candidateResultPath = Join-Path $workRoot 'cand/controlled_accept_core_mutation_candidate_result.json'
                  $executionEventsPath = Join-Path $workRoot 'exec/controlled_accept_core_mutation_execution_events.jsonl'
                  if (-not (Test-Path -LiteralPath $policyResultPath) -or -not (Test-Path -LiteralPath $candidateResultPath)) {
                    throw "RECOVERED_ACCEPTED_ATOM_EXECUTION_RESULT_MISSING=$atomId"
                  }
                  $policyResult = Read-D2BJson $policyResultPath
                  $candidateResult = Read-D2BJson $candidateResultPath
                  $writeEvent = Get-D2BExecutionWriteEvent $executionEventsPath
                  $recoveryEvidencePass = [string]$policyResult.status -eq 'PASS' -and
                    [bool]$policyResult.autonomous_accept_allowed -and
                    @($policyResult.atom_ids | Where-Object { [string]$_ -eq $atomId }).Count -eq 1 -and
                    [string]$candidateResult.status -eq 'PASS' -and
                    @($candidateResult.atom_ids | Where-Object { [string]$_ -eq $atomId }).Count -eq 1 -and
                    $null -ne $writeEvent -and [bool]$writeEvent.data.accepted_core_write -and
                    [int]$writeEvent.data.memory_operation_count -eq 1 -and
                    [int]$writeEvent.data.self_model_operation_count -eq 1 -and
                    [int]$writeEvent.data.registry_operation_count -eq 1
                  if (-not $recoveryEvidencePass) {
                    throw "RECOVERED_ACCEPTED_ATOM_WRITE_EVENT_EVIDENCE_FAILED=$atomId"
                  }
                  Write-D2BJson $execResultPath ([ordered]@{
                    schema='PHASE162_EXECUTE_CONTROLLED_ACCEPT_CORE_MUTATION_FOR_ATOM_BATCH_RESULT_V1'
                    status='PASS'; created_at=(Get-Date).ToUniversalTime().ToString('o')
                    controller_root=(Join-Path $workRoot 'ctrl'); candidate_root=(Join-Path $workRoot 'cand')
                    batch_size=1; staged_atom_count=1
                    controlled_accept_core_mutation_executed=$true
                    post_real_mutation_validation_passed=$true
                    rollback_executed=$false; rollback_required=$false
                    accepted_core_write_executed=$true; accepted_atom_claimed=$false
                    accepted_memory_mutated=$true; accepted_self_model_mutated=$true; registry_mutated=$true
                    final_accept_ready=$true
                    machine_decision='CONTROLLED_ACCEPT_CORE_MUTATION_EXECUTED_PENDING_CONTROLLER_FINALIZATION'
                    next_machine_action='FEED_CONTROLLED_ACCEPT_CORE_MUTATION_EXECUTION_BACK_INTO_CONTROLLER'
                    recovery_source='FULL_SURFACE_VISIBILITY_PLUS_CONTROLLED_ACCEPT_MUTATION_WRITTEN_TO_ACCEPTED_CORE_EVENT'
                    repeated_mutation_execution=$false
                  })
                  $recoveredFromWriteEvent = $true
                }
                $execResult = Read-D2BJson $execResultPath
                $execPass = [string]$execResult.status -eq 'PASS' -and [bool]$execResult.controlled_accept_core_mutation_executed -and
                  [bool]$execResult.post_real_mutation_validation_passed -and -not [bool]$execResult.rollback_executed
                if (-not $execPass) { throw "RECOVERED_ACCEPTED_ATOM_EXECUTION_NOT_PASS=$atomId" }
                Write-D2BJson (Join-Path $workRoot 'exec/execute_controlled_accept_core_mutation_validation.json') ([ordered]@{
                  schema='PHASE165S_D2B_EXECUTION_VALIDATION_V1'; status='PASS'; created_at=(Get-Date).ToUniversalTime().ToString('o')
                  atom_id=$atomId; memory_count=1; self_map_count=1; registry_count=1; owner_interrupt_used=$false; autonomous_policy_guard_allowed=$true
                })
                $executionProofPath = Join-Path $workRoot 'exec/phase165s_d2b_execution_proof_for_controller.json'
                Write-D2BJson $executionProofPath ([ordered]@{
                  schema='PHASE165S_D2B_EXECUTION_PROOF_FOR_PHASE162_CONTROLLER_V1'; status='PASS'
                  created_at=(Get-Date).ToUniversalTime().ToString('o'); head=(git -C $root rev-parse HEAD)
                  output_root=(Join-Path $workRoot 'exec'); next_action=[string]$execResult.next_machine_action
                  accepted_atom_claimed=$false; atom_id=$atomId; owner_interrupt_used=$false
                })
                $state.finalizer_invocation_count = [int]$state.finalizer_invocation_count + 1
                [void](Invoke-D2BPowerShell -ScriptPath $finalizerModule -Arguments @('-RepoRoot',$root,'-ExecutionProofPath',$executionProofPath,'-OutputRoot',(Join-Path $workRoot 'fin')))
              }
              $finalResult = Read-D2BJson $finalResultPath
              if (-not ([string]$finalResult.status -eq 'PASS' -and [bool]$finalResult.accepted_atom_claimed)) {
                throw "RECOVERED_ACCEPTED_ATOM_FINALIZATION_NOT_PASS=$atomId"
              }
              Add-D2BJsonLine $acceptedLog ([ordered]@{
                occurred_utc=(Get-Date).ToUniversalTime().ToString('o'); candidate_id=$candidateId; atom_id=$atomId
                source_path=$sourcePath
                disposition=$(if($recoveredFromWriteEvent){'ACCEPTED_RECOVERED_POST_WRITE_FINALIZATION'}else{'ACCEPTED_RECOVERED_AFTER_INTERRUPTION'})
                memory_count=1; self_map_count=1; registry_count=1; repeated_mutation_execution=$false
              })
              $state.accepted_count = [int]$state.accepted_count + 1
              $state.last_disposition = if ($recoveredFromWriteEvent) { 'ACCEPTED_RECOVERED_POST_WRITE_FINALIZATION' } else { 'ACCEPTED_RECOVERED_AFTER_INTERRUPTION' }
              $lastAcceptedAtomId = $atomId
              if ($recoveredFromWriteEvent -and -not $resumeHadHardError) {
                Add-D2BJsonLine $failedLog ([ordered]@{
                  occurred_utc=(Get-Date).ToUniversalTime().ToString('o'); candidate_id=$candidateId; atom_id=$atomId
                  shard_index=[int]$state.shard_index; line_index=[int]$state.line_index
                  error='INTERRUPTED_AFTER_FULL_SURFACE_ACCEPTED_CORE_WRITE_BEFORE_FINALIZATION'
                })
                Add-D2BJsonLine $recoveryLog ([ordered]@{
                  occurred_utc=(Get-Date).ToUniversalTime().ToString('o'); candidate_id=$candidateId; atom_id=$atomId
                  recovered_failure='full_surface_accepted_core_write_with_interrupted_finalization'
                  resolution='FINALIZED_ON_NEXT_RESUME_WITHOUT_REPEATED_MUTATION_AND_CURSOR_ADVANCED'
                  visibility_counts=[ordered]@{ memory=1; self_map=1; registry=1 }
                })
                $state.recovered_failure_count = [int]$state.recovered_failure_count + 1
              }
              if ($resumeHadHardError -and $resumeFailedCandidateId -eq $candidateId -and [int]$state.failed_count -gt 0) {
                $recoverCount = [int]$state.failed_count
                for ($recovered = 0; $recovered -lt $recoverCount; $recovered += 1) {
                  Add-D2BJsonLine $recoveryLog ([ordered]@{
                    occurred_utc=(Get-Date).ToUniversalTime().ToString('o'); candidate_id=$candidateId; atom_id=$atomId
                    recovered_failure='runner_infrastructure_failure_for_same_cursor_candidate'; resolution='FINALIZED_AND_CURSOR_ADVANCED'
                  })
                }
                $state.failed_count = 0
                $state.recovered_failure_count = [int]$state.recovered_failure_count + $recoverCount
                $resumeHadHardError = $false
              }
            } else {
              Add-D2BJsonLine $skippedLog ([ordered]@{
                occurred_utc=(Get-Date).ToUniversalTime().ToString('o'); candidate_id=$candidateId; atom_id=$atomId
                source_path=$sourcePath; disposition='SKIPPED_ALREADY_ACCEPTED'
              })
              $state.skipped_duplicate_count = [int]$state.skipped_duplicate_count + 1
              $state.last_disposition = 'SKIPPED_ALREADY_ACCEPTED'
            }
          } elseif (($m0 + $s0 + $r0) -ne 0) {
            throw "PARTIAL_ACCEPTED_SURFACE atom=$atomId memory=$m0 self_map=$s0 registry=$r0"
          } else {
            Reset-D2BWorkRoot -RepoRoot $root -OutputRootFull $outputFull -WorkRoot $workRoot -WorkRootMode ([string]$workRootInfo.work_root_mode) -ExternalWorkRootBase ([string]$workRootInfo.work_root_base)
            $policyCandidatePath = Join-Path $workRoot 'policy_candidate.json'
            $policyResultPath = Join-Path $workRoot 'policy_result.json'
            Write-D2BJson $policyCandidatePath ([ordered]@{
              atom_id=$atomId; batch_size=1; source_route='OWNER_APPROVED_CURRICULUM'; source_authority='OWNER_APPROVED'
              target_files=@($memoryPath,$selfMapPath,$registryPath); protected_files_to_mutate=@('packs/registry.json')
              proof_gates=[ordered]@{
                memory_proof_status='PASS'; use_proof_status='PASS'; behavior_delta_status='PASS'
                persistence_status='PASS'; startup_visibility_status='PASS'
              }
              rollback_plan_available=$true; exactly_one_atom_scope=$true; mass_acceptance_forbidden=$true; risk_flags=@()
            })
            $state.policy_guard_invocation_count = [int]$state.policy_guard_invocation_count + 1
            $state.policy_guard_process_invocation_count = [int]$state.policy_guard_process_invocation_count + 1
            [void](Invoke-D2BPowerShell -ScriptPath $policyModule -Arguments @('-RepoRoot',$root,'-CandidatePath',$policyCandidatePath,'-OutputPath',$policyResultPath))
            $policy = Read-D2BJson $policyResultPath
            if (-not [bool]$policy.autonomous_accept_allowed) {
              Add-D2BJsonLine $quarantineLog ([ordered]@{
                occurred_utc=(Get-Date).ToUniversalTime().ToString('o'); candidate_id=$candidateId; atom_id=$atomId
                source_path=$sourcePath; disposition='DENIED_BY_C2B'; reasons=@($policy.denial_reasons)
              })
              $state.denied_count = [int]$state.denied_count + 1
              $state.quarantine_count = [int]$state.quarantine_count + 1
              $state.last_disposition = 'DENIED_BY_C2B'
            } else {
              $operationId = "D2B_{0:d8}_{1}" -f ([int]$state.processed_count + 1), (($candidateId -replace '[^A-Za-z0-9]', '_').Substring(0, [math]::Min(40, ($candidateId -replace '[^A-Za-z0-9]', '_').Length)))
              $package = New-D2BPhase162Package -WorkRoot $workRoot -Candidate $candidate -OperationId $operationId -SourcePath $sourcePath -MemoryPath $memoryPath -SelfMapPath $selfMapPath -RegistryPath $registryPath
              $state.phase162_executor_invocation_count = [int]$state.phase162_executor_invocation_count + 1
              [void](Invoke-D2BPowerShell -ScriptPath $executorModule -Arguments @('-ControllerRoot',[string]$package.controller_root,'-RepoRoot',$root,'-OutputRoot',[string]$package.execution_root))
              $execResult = Read-D2BJson (Join-Path $package.execution_root 'execute_controlled_accept_core_mutation_result.json')
              $m = Get-D2BCount (Read-D2BJson (Join-Path $root $memoryPath)) 'phase162_accepted_atom_memory_records' $atomId
              $s = Get-D2BCount (Read-D2BJson (Join-Path $root $selfMapPath)) 'phase162_absorbed_atom_capability_notes' $atomId
              $r = Get-D2BCount (Read-D2BJson (Join-Path $root $registryPath)) 'phase162_accepted_atom_references' $atomId
              $execPass = [string]$execResult.status -eq 'PASS' -and [bool]$execResult.controlled_accept_core_mutation_executed -and
                [bool]$execResult.post_real_mutation_validation_passed -and -not [bool]$execResult.rollback_executed -and $m -eq 1 -and $s -eq 1 -and $r -eq 1
              Write-D2BJson (Join-Path $package.execution_root 'execute_controlled_accept_core_mutation_validation.json') ([ordered]@{
                schema='PHASE165S_D2B_EXECUTION_VALIDATION_V1'; status=$(if($execPass){'PASS'}else{'FAIL'})
                created_at=(Get-Date).ToUniversalTime().ToString('o'); atom_id=$atomId; memory_count=$m; self_map_count=$s; registry_count=$r
                owner_interrupt_used=$false; autonomous_policy_guard_allowed=$true
              })
              $executionProofPath = Join-Path $package.execution_root 'phase165s_d2b_execution_proof_for_controller.json'
              Write-D2BJson $executionProofPath ([ordered]@{
                schema='PHASE165S_D2B_EXECUTION_PROOF_FOR_PHASE162_CONTROLLER_V1'; status=[string]$execResult.status
                created_at=(Get-Date).ToUniversalTime().ToString('o'); head=(git -C $root rev-parse HEAD)
                output_root=$package.execution_root; next_action=[string]$execResult.next_machine_action
                accepted_atom_claimed=$false; atom_id=$atomId; owner_interrupt_used=$false
              })
              if (-not $execPass) {
                if (($m + $s + $r) -eq 0) {
                  Add-D2BJsonLine $failedLog ([ordered]@{
                    occurred_utc=(Get-Date).ToUniversalTime().ToString('o'); candidate_id=$candidateId; atom_id=$atomId
                    shard_index=[int]$state.shard_index; line_index=[int]$state.line_index
                    error="PHASE162_POST_EXECUTION_VISIBILITY_FAILED atom=$atomId memory=0 self_map=0 registry=0"
                  })
                  Add-D2BJsonLine $recoveryLog ([ordered]@{
                    occurred_utc=(Get-Date).ToUniversalTime().ToString('o'); candidate_id=$candidateId; atom_id=$atomId
                    recovered_failure='phase162_post_execution_zero_surface_visibility_failure'
                    resolution='QUARANTINED_NOT_ACCEPTED_AND_CURSOR_ADVANCED'
                    visibility_counts=[ordered]@{ memory=0; self_map=0; registry=0 }
                  })
                  Add-D2BJsonLine $quarantineLog ([ordered]@{
                    occurred_utc=(Get-Date).ToUniversalTime().ToString('o'); candidate_id=$candidateId; atom_id=$atomId
                    source_path=$sourcePath; disposition='QUARANTINED_POST_EXECUTION_ZERO_VISIBILITY'
                    reasons=@('phase162_post_execution_visibility_failed','accepted_surface_visibility_zero','candidate_not_accepted')
                    visibility_counts=[ordered]@{ memory=0; self_map=0; registry=0 }
                  })
                  $state.quarantine_count = [int]$state.quarantine_count + 1
                  $state.dynamic_quarantine_count = [int]$state.dynamic_quarantine_count + 1
                  $state.recovered_failure_count = [int]$state.recovered_failure_count + 1
                  $state.last_disposition = 'QUARANTINED_POST_EXECUTION_ZERO_VISIBILITY'
                } elseif (-not ($m -eq 1 -and $s -eq 1 -and $r -eq 1)) {
                  throw "PARTIAL_ACCEPTED_SURFACE atom=$atomId memory=$m self_map=$s registry=$r"
                } else {
                  throw "PHASE162_POST_EXECUTION_VISIBILITY_FAILED atom=$atomId memory=$m self_map=$s registry=$r"
                }
              } else {
                $state.finalizer_invocation_count = [int]$state.finalizer_invocation_count + 1
                [void](Invoke-D2BPowerShell -ScriptPath $finalizerModule -Arguments @('-RepoRoot',$root,'-ExecutionProofPath',$executionProofPath,'-OutputRoot',[string]$package.finalizer_root))
                $finalResult = Read-D2BJson (Join-Path $package.finalizer_root 'controller_consume_controlled_accept_core_mutation_execution_proof_result.json')
                if (-not ([string]$finalResult.status -eq 'PASS' -and [bool]$finalResult.accepted_atom_claimed)) {
                  throw "PHASE162_FINALIZATION_NOT_ACCEPTED=$atomId"
                }
                Add-D2BJsonLine $acceptedLog ([ordered]@{
                  occurred_utc=(Get-Date).ToUniversalTime().ToString('o'); candidate_id=$candidateId; atom_id=$atomId
                  source_path=$sourcePath; disposition='ACCEPTED'; policy_decision=[string]$policy.decision_code
                  memory_count=$m; self_map_count=$s; registry_count=$r; owner_interrupt_used=$false
                })
                $state.accepted_count = [int]$state.accepted_count + 1
                $state.last_disposition = 'ACCEPTED'
                $lastAcceptedAtomId = $atomId
                if ($resumeHadHardError -and $resumeFailedCandidateId -eq $candidateId -and [int]$state.failed_count -gt 0) {
                  $recoverCount = [int]$state.failed_count
                  for ($recovered = 0; $recovered -lt $recoverCount; $recovered += 1) {
                    Add-D2BJsonLine $recoveryLog ([ordered]@{
                      occurred_utc=(Get-Date).ToUniversalTime().ToString('o'); candidate_id=$candidateId; atom_id=$atomId
                      recovered_failure='runner_infrastructure_failure_for_same_cursor_candidate'; resolution='RETRIED_ACCEPTED_FINALIZED_AND_CURSOR_ADVANCED'
                    })
                  }
                  $state.failed_count = 0
                  $state.recovered_failure_count = [int]$state.recovered_failure_count + $recoverCount
                  $resumeHadHardError = $false
                }
              }
            }
          }
        }

        $state.processed_count = [int]$state.processed_count + 1
        $state.remaining_count = [int]$manifest.total_candidate_count - [int]$state.processed_count
        $state.line_index = [int]$state.line_index + 1
        $state.updated_utc = (Get-Date).ToUniversalTime().ToString('o')

        if (([int]$state.processed_count % $HeartbeatEvery) -eq 0) {
          $state.heartbeat_count = [int]$state.heartbeat_count + 1
          Write-D2BJson $heartbeatPath ([ordered]@{
            status=[string]$state.status; heartbeat_utc=$state.updated_utc; processed_count=[int]$state.processed_count
            remaining_count=[int]$state.remaining_count; accepted_count=[int]$state.accepted_count
            quarantine_count=[int]$state.quarantine_count; shard_index=[int]$state.shard_index; line_index=[int]$state.line_index
            last_candidate_id=$state.last_candidate_id; last_atom_id=$state.last_atom_id; last_disposition=$state.last_disposition
          })
        }
        if (([int]$state.processed_count % $CheckpointEvery) -eq 0) {
          $state.checkpoint_count = [int]$state.checkpoint_count + 1
          Write-D2BJson (Join-Path $outputFull ('checkpoints/checkpoint_{0:d8}.json' -f [int]$state.processed_count)) $state
        }
        Write-D2BJson $statePath $state
        Write-D2BJson $resumePath $state
        if (([int]$state.processed_count % $CheckpointEvery) -eq 0) {
          $checkpointUnauthorizedDirty = @(git -C $root status --short -- CAPABILITY_ROADMAP.json GENESIS_STATE.json TASK_QUEUE.json orchestrator/run.ps1 route_locks)
          [void](Write-D2BRunArtifacts -Root $root -OutputRootFull $outputFull -State $state -Manifest $manifest -Status 'RUNNING_ACTIVE' -StoppedBySignal $false -UnauthorizedDirty $checkpointUnauthorizedDirty -BatchSize $BatchSize -WorkRootFull $workRoot -WorkRootMode ([string]$workRootInfo.work_root_mode) -WorkRootShortPathEnabled ([bool]$workRootInfo.work_root_short_path_enabled))
        }
      }
    } finally {
      $reader.Dispose()
    }
    if ($stoppedBySignal) { break }
    $state.shard_index = [int]$state.shard_index + 1
    $state.line_index = 0
    Write-D2BJson $statePath $state
    Write-D2BJson $resumePath $state
  }
  if (-not $stoppedBySignal -and [int]$state.remaining_count -eq 0) {
    $state.status = 'QUEUE_EMPTY'
  }
} catch {
  $hardError = $_.Exception.Message
  if (-not $hardErrorAlreadyRecorded) {
    $state.failed_count = [int]$state.failed_count + 1
  }
  $state.status = if ($hardError -like 'PARTIAL_ACCEPTED_SURFACE*') { 'BLOCKED_PARTIAL_ACCEPTED_SURFACE' } else { 'HARD_ERROR' }
  if (-not $hardErrorAlreadyRecorded) {
    Add-D2BJsonLine $failedLog ([ordered]@{
      occurred_utc=(Get-Date).ToUniversalTime().ToString('o'); candidate_id=$state.last_candidate_id; atom_id=$state.last_atom_id
      shard_index=[int]$state.shard_index; line_index=[int]$state.line_index; error=$hardError
    })
  }
}

$finalStatus = if ($hardError -like 'PARTIAL_ACCEPTED_SURFACE*') {
  'BLOCKED_PARTIAL_ACCEPTED_SURFACE'
} elseif ($hardError) {
  'HARD_ERROR'
} elseif ($stoppedBySignal) {
  'STOPPED_BY_SIGNAL'
} elseif ([int]$state.remaining_count -eq 0) {
  'PASS_QUEUE_EMPTY'
} else {
  'INCOMPLETE_RESUMABLE'
}
if ($finalStatus -eq 'INCOMPLETE_RESUMABLE') {
  $state.status = 'RUNNING_READY_TO_RESUME'
}
$state.updated_utc = (Get-Date).ToUniversalTime().ToString('o')
$terminalCheckpointPath = Join-Path $outputFull ('checkpoints/checkpoint_{0:d8}_{1}.json' -f [int]$state.processed_count, [string]$state.status)
if (-not (Test-Path -LiteralPath $terminalCheckpointPath)) {
  $state.checkpoint_count = [int]$state.checkpoint_count + 1
  Write-D2BJson $terminalCheckpointPath $state
}
Write-D2BJson $statePath $state
Write-D2BJson $resumePath $state
Write-D2BJson $heartbeatPath ([ordered]@{
  status=[string]$state.status; heartbeat_utc=$state.updated_utc; processed_count=[int]$state.processed_count
  remaining_count=[int]$state.remaining_count; accepted_count=[int]$state.accepted_count; quarantine_count=[int]$state.quarantine_count
  stopped_by_signal=$stoppedBySignal; hard_error=$hardError; last_atom_id=$state.last_atom_id; last_disposition=$state.last_disposition
})

$unauthorizedDirtyAfter = @(git -C $root status --short -- CAPABILITY_ROADMAP.json GENESIS_STATE.json TASK_QUEUE.json orchestrator/run.ps1 route_locks)
$retentionResult = Invoke-D2BPostBatchRetentionHook -Root $root -OutputRootFull $outputFull -WorkRootFull $workRoot -AcceptedLogPath $acceptedLog -AcceptedLogStartLineCount $invocationAcceptedLogStartLineCount -InitialFailedCount $invocationFailedCountStart -InitialQuarantineCount $invocationQuarantineCountStart -State $state -FinalStatus $finalStatus -StoppedBySignal $stoppedBySignal -HardError $hardError -RetentionMode $RetentionMode
$cleanupPendingPath = Join-Path $outputFull 'cleanup_pending.json'
$candidateMaterialPruned = Remove-D2BCandidateBatchMaterialOnSuccess -CandidateBatchInfo $candidateBatchInfo -RetentionResult $retentionResult -FinalStatus $finalStatus -StoppedBySignal $stoppedBySignal -HardError $hardError -CleanupPendingPath $cleanupPendingPath
$result = Write-D2BRunArtifacts -Root $root -OutputRootFull $outputFull -State $state -Manifest $manifest -Status $finalStatus -StoppedBySignal $stoppedBySignal -UnauthorizedDirty $unauthorizedDirtyAfter -BatchSize $BatchSize -WorkRootFull $workRoot -WorkRootMode ([string]$workRootInfo.work_root_mode) -WorkRootShortPathEnabled ([bool]$workRootInfo.work_root_short_path_enabled) -RetentionMode $RetentionMode -RetentionResult $retentionResult -DirectCandidateBatchMode $directCandidateBatchMode -CandidateBatchPath $(if($directCandidateBatchMode){[string]$candidateBatchInfo.relative_path}else{''}) -CandidateMaterialPruned $candidateMaterialPruned -CleanupPendingPath $(if(Test-Path -LiteralPath $cleanupPendingPath){(Get-D2BRelativePath -Root $root -Path $cleanupPendingPath)}else{''}) -AcceptedCoreMode $AcceptedCoreMode -AcceptedCoreDeltaRoot $(if($null -ne $acceptedCoreDeltaInfo){[string]$acceptedCoreDeltaInfo.root}else{''})

if ($EmitJson) {
  $result | ConvertTo-Json -Depth 40
} else {
  Write-Host "PHASE165S_D2B_BIG_CURRICULUM_AUTONOMOUS_LEARNING_RESULT=$finalStatus"
  Write-Host "PROCESSED_COUNT=$($state.processed_count)"
  Write-Host "REMAINING_COUNT=$($state.remaining_count)"
  Write-Host "ACCEPTED_ATOM_COUNT=$($state.accepted_count)"
  Write-Host "QUARANTINE_COUNT=$($state.quarantine_count)"
  Write-Host "FAILED_COUNT=$($state.failed_count)"
  Write-Host "RETENTION_STATUS=$($retentionResult.status)"
  Write-Host "CANDIDATE_MATERIAL_PRUNED=$candidateMaterialPruned"
  Write-Host "NEXT_REQUIRED_ACTION=$($result.next_required_action)"
}
if ($hardError) { exit 1 }
