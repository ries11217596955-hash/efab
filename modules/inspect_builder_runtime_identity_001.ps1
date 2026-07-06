param(
  [string]$SessionRoot = "",
  [string]$RunId = "",
  [ValidateSet("Initialize", "GuardCheck")]
  [string]$Mode = "GuardCheck",
  [string]$GuardLabel = "runtime_guard"
)

$ErrorActionPreference = "Stop"

function Normalize-Phase160EIdentityFullPath {
  param([string]$Path)
  return [System.IO.Path]::GetFullPath($Path).TrimEnd([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar)
}

function Resolve-Phase160EIdentityRepoRoot {
  $scriptRootCandidate = $PSScriptRoot
  if ([string]::IsNullOrWhiteSpace($scriptRootCandidate) -and -not [string]::IsNullOrWhiteSpace($PSCommandPath)) {
    $scriptRootCandidate = Split-Path -Path $PSCommandPath -Parent
  }
  if ([string]::IsNullOrWhiteSpace($scriptRootCandidate) -and -not [string]::IsNullOrWhiteSpace($MyInvocation.MyCommand.Path)) {
    $scriptRootCandidate = Split-Path -Path $MyInvocation.MyCommand.Path -Parent
  }
  if ([string]::IsNullOrWhiteSpace($scriptRootCandidate)) {
    throw "PHASE160E_IDENTITY_SCRIPT_ROOT_UNAVAILABLE"
  }
  return Normalize-Phase160EIdentityFullPath -Path (Join-Path $scriptRootCandidate "..")
}

function Resolve-Phase160EIdentityPath {
  param([string]$RepoRoot, [string]$Path)
  if ([System.IO.Path]::IsPathRooted($Path)) {
    return [System.IO.Path]::GetFullPath($Path)
  }
  return [System.IO.Path]::GetFullPath((Join-Path $RepoRoot $Path))
}

function ConvertTo-Phase160EIdentityRelativePath {
  param([string]$RepoRoot, [string]$FullPath)
  $root = Normalize-Phase160EIdentityFullPath -Path $RepoRoot
  $full = Normalize-Phase160EIdentityFullPath -Path $FullPath
  if ($full -eq $root) {
    return "."
  }
  if (-not $full.StartsWith($root + [System.IO.Path]::DirectorySeparatorChar, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw "PHASE160E_IDENTITY_PATH_OUTSIDE_REPO=$FullPath"
  }
  return ($full.Substring($root.Length + 1) -replace "\\", "/")
}

function Write-Phase160EIdentityJsonFile {
  param([string]$Path, [object]$Object, [int]$Depth = 100)
  $directory = Split-Path -Path $Path -Parent
  if ($directory -and -not (Test-Path -LiteralPath $directory)) {
    New-Item -ItemType Directory -Force -Path $directory | Out-Null
  }
  $json = ($Object | ConvertTo-Json -Depth $Depth) -replace "`r`n", "`n"
  if (-not $json.EndsWith("`n")) {
    $json += "`n"
  }
  [System.IO.File]::WriteAllText($Path, $json, [System.Text.UTF8Encoding]::new($false))
}

function Add-Phase160EIdentityJsonLine {
  param([string]$Path, [object]$Object)
  $directory = Split-Path -Path $Path -Parent
  if ($directory -and -not (Test-Path -LiteralPath $directory)) {
    New-Item -ItemType Directory -Force -Path $directory | Out-Null
  }
  $line = $Object | ConvertTo-Json -Depth 100 -Compress
  [System.IO.File]::AppendAllText($Path, "$line`n", [System.Text.UTF8Encoding]::new($false))
}

function Read-Phase160EIdentityJsonSafe {
  param([string]$Path)
  try {
    if (-not (Test-Path -LiteralPath $Path)) {
      return $null
    }
    return Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json
  } catch {
    return $null
  }
}

function Get-Phase160EIdentityRemoteHead {
  param([string]$ExpectedBranch)
  $remoteHead = (git rev-parse --short "origin/$ExpectedBranch" 2>$null)
  if ([string]::IsNullOrWhiteSpace($remoteHead)) {
    throw "PHASE160E_IDENTITY_REMOTE_HEAD_UNAVAILABLE"
  }
  return $remoteHead.Trim()
}

function Get-Phase160EIdentityTrackedStatus {
  $lines = @(git status --short --untracked-files=all | ForEach-Object { [string]$_ } | Sort-Object)
  return $lines
}

function Get-Phase160EIdentityProtectedStatus {
  $lines = @(git status --short --untracked-files=no -- `
    TASK_QUEUE.json `
    GENESIS_STATE.json `
    CAPABILITY_ROADMAP.json `
    packs/registry.json `
    orchestrator/run.ps1 2>$null | ForEach-Object { [string]$_ } | Sort-Object)
  return $lines
}

function Get-Phase160EIdentityScriptHashes {
  param([string]$RepoRoot, [string[]]$Paths)
  $hashes = [ordered]@{}
  foreach ($path in $Paths) {
    $full = Resolve-Phase160EIdentityPath -RepoRoot $RepoRoot -Path $path
    if (Test-Path -LiteralPath $full) {
      $hashes[$path] = (Get-FileHash -LiteralPath $full -Algorithm SHA256).Hash
    } else {
      $hashes[$path] = "MISSING"
    }
  }
  return $hashes
}

function Get-Phase160EIdentityStatusCode {
  param([string]$Line)
  if ([string]::IsNullOrWhiteSpace($Line) -or $Line.Length -lt 2) {
    return ""
  }
  return $Line.Substring(0, 2)
}

function Get-Phase160EIdentityStatusPaths {
  param([string]$Line)
  if ([string]::IsNullOrWhiteSpace($Line) -or $Line.Length -lt 4) {
    return @()
  }
  $pathText = $Line.Substring(3).Trim()
  if ([string]::IsNullOrWhiteSpace($pathText)) {
    return @()
  }
  return @($pathText -split " -> " | ForEach-Object { ([string]$_).Trim() -replace "\\", "/" } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
}

function Test-Phase160EIdentityStatusPathPrefix {
  param([string]$Line, [string[]]$Prefixes)
  foreach ($path in @(Get-Phase160EIdentityStatusPaths -Line $Line)) {
    foreach ($prefix in $Prefixes) {
      if ($path.StartsWith($prefix, [System.StringComparison]::OrdinalIgnoreCase)) {
        return $true
      }
    }
  }
  return $false
}

function Test-Phase160EIdentityStatusPathExact {
  param([string]$Line, [string[]]$Paths)
  foreach ($path in @(Get-Phase160EIdentityStatusPaths -Line $Line)) {
    foreach ($candidate in $Paths) {
      if ($path -eq ($candidate -replace "\\", "/")) {
        return $true
      }
    }
  }
  return $false
}

function Test-Phase160EIdentityAllowedRuntimeStatusLine {
  param([string]$Line, [string]$RunId)
  $code = Get-Phase160EIdentityStatusCode -Line $Line
  if ($code -eq "??") {
    $allowedPrefixes = @(
      "runtime_sessions/live_growth_console/",
      "runtime_sessions/live_growth_self_growth/",
      "runtime_sessions/newborn_reflex/"
    )
    if (-not [string]::IsNullOrWhiteSpace($RunId) -and $RunId -ne "NONE") {
      $allowedPrefixes += "runtime_sessions/live_growth/$RunId/"
    }
    return Test-Phase160EIdentityStatusPathPrefix -Line $Line -Prefixes $allowedPrefixes
  }
  if ($code -eq " M") {
    return Test-Phase160EIdentityStatusPathExact -Line $Line -Paths @("runtime_sessions/live_growth_console/PHASE160_LIVE_OBSERVER_CONSOLE_REPAIR_001/console_output_sample.txt")
  }
  return $false
}

function Test-Phase160EIdentityUnsafeRepoStatusLine {
  param([string]$Line)
  $unsafePrefixes = @(
    "modules/",
    "validators/",
    "reports/",
    "proofs/",
    "contracts/",
    "route_change_requests/"
  )
  return Test-Phase160EIdentityStatusPathPrefix -Line $Line -Prefixes $unsafePrefixes
}

function Test-Phase160EIdentityProtectedStatusLine {
  param([string]$Line)
  return Test-Phase160EIdentityStatusPathExact -Line $Line -Paths @(
    "TASK_QUEUE.json",
    "GENESIS_STATE.json",
    "CAPABILITY_ROADMAP.json",
    "packs/registry.json",
    "orchestrator/run.ps1"
  )
}

function ConvertTo-Phase160EIdentityStatusBaseline {
  param([object]$Baseline, [string]$RunId)
  $capturedAt = (Get-Date).ToUniversalTime().ToString("o")
  if ($null -eq $Baseline) {
    $statusLines = @()
  } elseif ($Baseline.PSObject.Properties.Name -contains "status_lines") {
    $statusLines = @($Baseline.status_lines | ForEach-Object { [string]$_ } | Sort-Object)
    if ($Baseline.PSObject.Properties.Name -contains "captured_at" -and -not [string]::IsNullOrWhiteSpace([string]$Baseline.captured_at)) {
      $capturedAt = [string]$Baseline.captured_at
    }
  } else {
    $statusLines = @($Baseline | ForEach-Object { [string]$_ } | Sort-Object)
  }
  $allowedRuntime = @($statusLines | Where-Object { Test-Phase160EIdentityAllowedRuntimeStatusLine -Line $_ -RunId $RunId })
  $unsafeLines = @($statusLines | Where-Object { -not (Test-Phase160EIdentityAllowedRuntimeStatusLine -Line $_ -RunId $RunId) -and (Test-Phase160EIdentityUnsafeRepoStatusLine -Line $_) })
  return [ordered]@{
    clean = $statusLines.Count -eq 0
    status_lines = $statusLines
    allowed_runtime_output_lines = $allowedRuntime
    unsafe_tracked_mutation_lines = $unsafeLines
    captured_at = $capturedAt
  }
}

function New-Phase160EIdentityStatusClassification {
  param(
    [string[]]$StatusLines,
    [string[]]$BaselineStatusLines,
    [string]$RunId
  )
  $baselineSet = @{}
  foreach ($line in @($BaselineStatusLines)) {
    $baselineSet[[string]$line] = $true
  }
  $allowedRuntime = @()
  $allowedTrackedSamples = @()
  $unsafeCode = @()
  $protected = @()
  $unknown = @()
  foreach ($line in @($StatusLines)) {
    $lineText = [string]$line
    $isAllowedRuntime = Test-Phase160EIdentityAllowedRuntimeStatusLine -Line $lineText -RunId $RunId
    if ($isAllowedRuntime) {
      $allowedRuntime += $lineText
      if ((Get-Phase160EIdentityStatusCode -Line $lineText) -eq " M") {
        $allowedTrackedSamples += $lineText
      }
      continue
    }
    $isBaseline = $baselineSet.ContainsKey($lineText)
    $isProtected = Test-Phase160EIdentityProtectedStatusLine -Line $lineText
    if ($isProtected) {
      $protected += $lineText
      continue
    }
    if ($isBaseline) {
      continue
    }
    if (Test-Phase160EIdentityUnsafeRepoStatusLine -Line $lineText) {
      $unsafeCode += $lineText
      continue
    }
    $unknown += $lineText
  }
  return [ordered]@{
    allowed_runtime_outputs = @($allowedRuntime | Sort-Object)
    allowed_tracked_runtime_sample_changes = @($allowedTrackedSamples | Sort-Object)
    unsafe_tracked_code_mutations = @($unsafeCode | Sort-Object)
    unsafe_protected_state_mutations = @($protected | Sort-Object)
    unknown_status_lines = @($unknown | Sort-Object)
  }
}

function Get-Phase160EIdentityHashDriftLines {
  param([string]$RepoRoot, [object]$BaselineHashes)
  $drift = @()
  if ($null -eq $BaselineHashes) {
    return @()
  }
  foreach ($property in @($BaselineHashes.PSObject.Properties)) {
    $path = [string]$property.Name
    $baselineHash = [string]$property.Value
    $full = Resolve-Phase160EIdentityPath -RepoRoot $RepoRoot -Path $path
    $currentHash = if (Test-Path -LiteralPath $full) { (Get-FileHash -LiteralPath $full -Algorithm SHA256).Hash } else { "MISSING" }
    if ($currentHash -ne $baselineHash) {
      $drift += "HASH_CHANGED $path"
    }
  }
  return @($drift | Sort-Object)
}

function Assert-Phase160EIdentityRunIdSafe {
  param([string]$RunId)
  if ([string]::IsNullOrWhiteSpace($RunId)) {
    return
  }
  if ($RunId.IndexOfAny([char[]]@("/", "\")) -ge 0) {
    throw "PHASE160E_IDENTITY_RUN_ID_MUST_BE_LEAF=$RunId"
  }
}

$RepoRoot = Resolve-Phase160EIdentityRepoRoot
$ExpectedBranch = "phase110-idempotent-autonomy-trial-runtime"
$Pushed = $false

try {
  Push-Location $RepoRoot
  $Pushed = $true

  foreach ($identityFile in @("CAPABILITY_ROADMAP.json", "GENESIS_STATE.json", "TASK_QUEUE.json", "packs/registry.json", "orchestrator/run.ps1")) {
    if (-not (Test-Path -LiteralPath (Resolve-Phase160EIdentityPath -RepoRoot $RepoRoot -Path $identityFile))) {
      throw "STOP=WRONG_AGENT_BUILDER_REPO missing=$identityFile"
    }
  }

  Assert-Phase160EIdentityRunIdSafe -RunId $RunId
  if (-not [string]::IsNullOrWhiteSpace($RunId) -and [string]::IsNullOrWhiteSpace($SessionRoot)) {
    $SessionRoot = "runtime_sessions/live_growth/$RunId"
  }
  if ([string]::IsNullOrWhiteSpace($SessionRoot)) {
    throw "PHASE160E_IDENTITY_SESSION_ROOT_REQUIRED"
  }

  $SessionRootFull = Resolve-Phase160EIdentityPath -RepoRoot $RepoRoot -Path $SessionRoot
  $SessionRootRelative = ConvertTo-Phase160EIdentityRelativePath -RepoRoot $RepoRoot -FullPath $SessionRootFull
  $ManifestPath = Join-Path $SessionRootFull "run_manifest.json"
  $RuntimeIdentityPath = Join-Path $SessionRootFull "runtime_identity.json"
  $RuntimeGuardPath = Join-Path $SessionRootFull "runtime_guard.json"
  $CandidateWorkspace = Join-Path $SessionRootFull "candidate_workspace"
  $ChangeLedgerPath = Join-Path $CandidateWorkspace "change_ledger.jsonl"
  foreach ($directory in @(
    $SessionRootFull,
    $CandidateWorkspace,
    (Join-Path $CandidateWorkspace "candidate_bundles"),
    (Join-Path $CandidateWorkspace "candidate_queue"),
    (Join-Path $CandidateWorkspace "candidate_quarantine"),
    (Join-Path $SessionRootFull "promotion_bundle"),
    (Join-Path $SessionRootFull "task_lifecycle"),
    (Join-Path $SessionRootFull "task_lifecycle/task_completion_receipts")
  )) {
    New-Item -ItemType Directory -Force -Path $directory | Out-Null
  }

  $Branch = (git branch --show-current).Trim()
  $Head = (git rev-parse --short HEAD).Trim()
  $RemoteHead = Get-Phase160EIdentityRemoteHead -ExpectedBranch $ExpectedBranch
  $ExpectedHeadSource = "CURRENT_SYNCED_REPO_HEAD"
  $KeyScripts = @(
    "modules/start_builder_live_growth_daemon_001.ps1",
    "modules/invoke_builder_live_self_growth_duty_step_001.ps1",
    "modules/watch_builder_live_console_001.ps1",
    "modules/watch_builder_live_growth_session_observer_001.ps1",
    "modules/inspect_builder_runtime_identity_001.ps1",
    "modules/invoke_builder_candidate_workspace_step_001.ps1",
    "modules/finalize_builder_promotion_bundle_001.ps1",
    "modules/select_builder_self_initiated_useful_goal_001.ps1",
    "modules/invoke_builder_internal_active_task_creation_001.ps1",
    "modules/score_builder_self_growth_goal_001.ps1",
    "modules/inspect_builder_self_growth_evidence_001.ps1"
  )

  if ($Mode -eq "Initialize") {
    $RawTrackedStatusBaseline = Get-Phase160EIdentityTrackedStatus
    $TrackedStatusBaseline = ConvertTo-Phase160EIdentityStatusBaseline -Baseline $RawTrackedStatusBaseline -RunId $RunId
    $ProtectedStatusLines = Get-Phase160EIdentityProtectedStatus
    $ProtectedStatus = [ordered]@{
      clean = $ProtectedStatusLines.Count -eq 0
      status_lines = $ProtectedStatusLines
      captured_at = (Get-Date).ToUniversalTime().ToString("o")
    }
    $ScriptHashes = Get-Phase160EIdentityScriptHashes -RepoRoot $RepoRoot -Paths $KeyScripts
    $StartedAt = (Get-Date).ToUniversalTime().ToString("o")
    $CurrentBranchAtStart = (git branch --show-current).Trim()
    $CurrentHeadAtStart = (git rev-parse --short HEAD).Trim()
    $Manifest = [ordered]@{
      run_id = if ([string]::IsNullOrWhiteSpace($RunId)) { "NONE" } else { $RunId }
      repo_root = $RepoRoot
      session_root = $SessionRootRelative
      branch = $Branch
      current_branch = $CurrentBranchAtStart
      run_head = $Head
      current_head = $CurrentHeadAtStart
      head_match = $Head -eq $CurrentHeadAtStart
      branch_match = $Branch -eq $CurrentBranchAtStart
      remote_head = $RemoteHead
      expected_head_source = $ExpectedHeadSource
      started_at = $StartedAt
      live_repo_mutation_allowed = $false
      commit_allowed = $false
      push_allowed = $false
      branch_switch_allowed = $false
      protected_state_mutation_allowed = $false
      runtime_only_write_policy = $true
      key_script_paths = $KeyScripts
      key_script_hashes = $ScriptHashes
      tracked_status_baseline = $TrackedStatusBaseline
      protected_status_at_start = $ProtectedStatus
      run_manifest_status = "PASS"
    }
    Write-Phase160EIdentityJsonFile -Path $ManifestPath -Object $Manifest
    Write-Phase160EIdentityJsonFile -Path $RuntimeIdentityPath -Object ([ordered]@{
      status = "PASS"
      run_id = $Manifest.run_id
      branch = $Branch
      run_head = $Head
      current_head = $Head
      remote_head = $RemoteHead
      head_match = $true
      tracked_status_baseline = $TrackedStatusBaseline
      protected_status_at_start = $ProtectedStatus
      runtime_identity_written_at = $StartedAt
      live_repo_mutation_allowed = $false
    })
    Add-Phase160EIdentityJsonLine -Path $ChangeLedgerPath -Object ([ordered]@{
      event_type = "candidate_workspace_initialized"
      source = "runtime_identity"
      run_id = $Manifest.run_id
      run_head = $Head
      occurred_at = $StartedAt
    })
  }

  $ManifestForGuard = Read-Phase160EIdentityJsonSafe -Path $ManifestPath
  if ($null -eq $ManifestForGuard) {
    throw "PHASE160E_IDENTITY_RUN_MANIFEST_MISSING=$SessionRootRelative/run_manifest.json"
  }

  $CurrentBranch = (git branch --show-current).Trim()
  $CurrentHead = (git rev-parse --short HEAD).Trim()
  $CurrentTrackedStatus = Get-Phase160EIdentityTrackedStatus
  $BaselineObject = ConvertTo-Phase160EIdentityStatusBaseline -Baseline $ManifestForGuard.tracked_status_baseline -RunId ([string]$ManifestForGuard.run_id)
  $BaselineTrackedStatus = @($BaselineObject.status_lines | ForEach-Object { [string]$_ } | Sort-Object)
  $ProtectedStatus = Get-Phase160EIdentityProtectedStatus
  $RuntimeStaged = @(git diff --cached --name-only -- runtime_sessions)
  $BranchMatches = $CurrentBranch -eq [string]$ManifestForGuard.branch
  $HeadMatches = $CurrentHead -eq [string]$ManifestForGuard.run_head
  $Classification = New-Phase160EIdentityStatusClassification -StatusLines $CurrentTrackedStatus -BaselineStatusLines $BaselineTrackedStatus -RunId ([string]$ManifestForGuard.run_id)
  $HashDriftLines = Get-Phase160EIdentityHashDriftLines -RepoRoot $RepoRoot -BaselineHashes $ManifestForGuard.key_script_hashes
  $Classification.unsafe_tracked_code_mutations = @(@($Classification.unsafe_tracked_code_mutations) + @($HashDriftLines) | Sort-Object)
  $ProtectedClean = @($Classification.unsafe_protected_state_mutations).Count -eq 0
  $baselineComparable = @($BaselineTrackedStatus | Where-Object { -not (Test-Phase160EIdentityAllowedRuntimeStatusLine -Line $_ -RunId ([string]$ManifestForGuard.run_id)) } | Sort-Object)
  $currentComparable = @($CurrentTrackedStatus | Where-Object { -not (Test-Phase160EIdentityAllowedRuntimeStatusLine -Line $_ -RunId ([string]$ManifestForGuard.run_id)) } | Sort-Object)
  $TrackedStatusMatches = (($currentComparable -join "`n") -eq ($baselineComparable -join "`n")) -and @($HashDriftLines).Count -eq 0
  $RuntimeOutputsStaged = $RuntimeStaged.Count -gt 0
  $BranchOrHeadMismatch = -not ($BranchMatches -and $HeadMatches)
  $UnsafeTrackedCodeMutationCount = @($Classification.unsafe_tracked_code_mutations).Count
  $ProtectedStateMutationCount = @($Classification.unsafe_protected_state_mutations).Count
  $UnknownStatusLineCount = @($Classification.unknown_status_lines).Count
  $BlockedReasons = @()
  if ($BranchOrHeadMismatch) { $BlockedReasons += "branch_or_head_mismatch" }
  if ($ProtectedStateMutationCount -gt 0) { $BlockedReasons += "protected_state_mutation" }
  if ($RuntimeOutputsStaged) { $BlockedReasons += "runtime_outputs_staged" }
  if ($UnsafeTrackedCodeMutationCount -gt 0) { $BlockedReasons += "unsafe_tracked_code_mutation" }
  if ($UnknownStatusLineCount -gt 0) { $BlockedReasons += "unknown_status_lines" }
  if (-not $TrackedStatusMatches -and $UnsafeTrackedCodeMutationCount -eq 0 -and $ProtectedStateMutationCount -eq 0 -and $UnknownStatusLineCount -eq 0) { $BlockedReasons += "tracked_status_baseline_mismatch" }
  $GuardPassed = ($BranchMatches -and $HeadMatches -and $ProtectedClean -and $TrackedStatusMatches -and -not $RuntimeOutputsStaged -and $UnsafeTrackedCodeMutationCount -eq 0 -and $UnknownStatusLineCount -eq 0)
  $Guard = [ordered]@{
    status = if ($GuardPassed) { "PASS" } else { "BLOCKED" }
    guard_label = $GuardLabel
    run_id = [string]$ManifestForGuard.run_id
    branch = [string]$ManifestForGuard.branch
    current_branch = $CurrentBranch
    run_head = [string]$ManifestForGuard.run_head
    current_head = $CurrentHead
    head_match = $HeadMatches
    branch_match = $BranchMatches
    protected_files_clean = $ProtectedClean
    tracked_status_matches_run_baseline = $TrackedStatusMatches
    runtime_outputs_staged = $RuntimeOutputsStaged
    allowed_runtime_outputs = @($Classification.allowed_runtime_outputs)
    allowed_tracked_runtime_sample_changes = @($Classification.allowed_tracked_runtime_sample_changes)
    unsafe_tracked_code_mutations = @($Classification.unsafe_tracked_code_mutations)
    unsafe_protected_state_mutations = @($Classification.unsafe_protected_state_mutations)
    staged_runtime_outputs = @($RuntimeStaged | ForEach-Object { [string]$_ } | Sort-Object)
    branch_or_head_mismatch = $BranchOrHeadMismatch
    unknown_status_lines = @($Classification.unknown_status_lines)
    allowed_runtime_output_count = @($Classification.allowed_runtime_outputs).Count
    allowed_tracked_runtime_sample_change = @($Classification.allowed_tracked_runtime_sample_changes).Count -gt 0
    unsafe_tracked_code_mutation_count = $UnsafeTrackedCodeMutationCount
    protected_state_mutation_count = $ProtectedStateMutationCount
    unknown_status_line_count = $UnknownStatusLineCount
    blocked_reasons = @($BlockedReasons)
    candidate_production_enabled = $GuardPassed
    commit_performed = $false
    push_performed = $false
    branch_switch_performed = $false
    protected_state_mutated = $ProtectedStateMutationCount -gt 0
    checked_at = (Get-Date).ToUniversalTime().ToString("o")
  }
  Write-Phase160EIdentityJsonFile -Path $RuntimeGuardPath -Object $Guard
  Write-Phase160EIdentityJsonFile -Path $RuntimeIdentityPath -Object ([ordered]@{
    status = if ($GuardPassed) { "PASS" } else { "BLOCKED" }
    run_id = [string]$ManifestForGuard.run_id
    branch = [string]$ManifestForGuard.branch
    run_head = [string]$ManifestForGuard.run_head
    current_head = $CurrentHead
    remote_head = [string]$ManifestForGuard.remote_head
    head_match = $HeadMatches
    live_repo_guard = $Guard.status
    candidate_production_enabled = $GuardPassed
    blocked_reasons = @($BlockedReasons)
    updated_at = (Get-Date).ToUniversalTime().ToString("o")
  })
  Add-Phase160EIdentityJsonLine -Path $ChangeLedgerPath -Object ([ordered]@{
    event_type = if ($GuardPassed) { "live_repo_guard_passed" } else { "live_repo_guard_failed" }
    source = "runtime_identity"
    guard_label = $GuardLabel
    run_id = [string]$ManifestForGuard.run_id
    run_head = [string]$ManifestForGuard.run_head
    current_head = $CurrentHead
    status = $Guard.status
    occurred_at = (Get-Date).ToUniversalTime().ToString("o")
  })

  if (-not $GuardPassed) {
    $BlockerQueuePath = Join-Path $SessionRootFull "blocker_queue"
    New-Item -ItemType Directory -Force -Path $BlockerQueuePath | Out-Null
    Write-Phase160EIdentityJsonFile -Path (Join-Path $BlockerQueuePath "blocker_phase160e_runtime_guard.json") -Object ([ordered]@{
      status = "BLOCKED"
      blocker_id = "PHASE160E_RUNTIME_GUARD_FAILED"
      guard_label = $GuardLabel
      branch_match = $BranchMatches
      head_match = $HeadMatches
      protected_files_clean = $ProtectedClean
      tracked_status_matches_run_baseline = $TrackedStatusMatches
      runtime_outputs_staged = $RuntimeOutputsStaged
      blocked_reasons = @($BlockedReasons)
      allowed_runtime_output_count = @($Classification.allowed_runtime_outputs).Count
      unsafe_tracked_code_mutation_count = $UnsafeTrackedCodeMutationCount
      protected_state_mutation_count = $ProtectedStateMutationCount
      unknown_status_line_count = $UnknownStatusLineCount
      candidate_production_disabled = $true
      created_at = (Get-Date).ToUniversalTime().ToString("o")
    })
  }

  [pscustomobject][ordered]@{
    status = $Guard.status
    mode = $Mode
    run_id = [string]$ManifestForGuard.run_id
    session_root = $SessionRootRelative
    branch = [string]$ManifestForGuard.branch
    run_head = [string]$ManifestForGuard.run_head
    current_head = $CurrentHead
    remote_head = [string]$ManifestForGuard.remote_head
    expected_head_source = [string]$ManifestForGuard.expected_head_source
    head_match = $HeadMatches
    live_repo_guard = $Guard.status
    candidate_production_enabled = $GuardPassed
    tracked_status_matches_run_baseline = $TrackedStatusMatches
    runtime_outputs_staged = $RuntimeOutputsStaged
    allowed_runtime_output_count = @($Classification.allowed_runtime_outputs).Count
    allowed_tracked_runtime_sample_change = @($Classification.allowed_tracked_runtime_sample_changes).Count -gt 0
    unsafe_tracked_code_mutation_count = $UnsafeTrackedCodeMutationCount
    protected_state_mutation_count = $ProtectedStateMutationCount
    unknown_status_line_count = $UnknownStatusLineCount
    blocked_reasons = @($BlockedReasons)
    run_manifest_written = Test-Path -LiteralPath $ManifestPath
    runtime_identity_written = Test-Path -LiteralPath $RuntimeIdentityPath
    runtime_guard_written = Test-Path -LiteralPath $RuntimeGuardPath
  } | ConvertTo-Json -Depth 20
} finally {
  if ($Pushed) {
    Pop-Location
  }
}
