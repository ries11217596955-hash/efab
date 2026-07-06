param(
  [string]$RepoRoot = "",
  [string]$SessionRoot = "",
  [string]$SchoolRunId = ""
)

$ErrorActionPreference = "Stop"

function Normalize-Phase161AFullPath {
  param([string]$Path)
  return [System.IO.Path]::GetFullPath($Path).TrimEnd([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar)
}

function Resolve-Phase161ARepoRoot {
  param([string]$RepoRoot)
  if (-not [string]::IsNullOrWhiteSpace($RepoRoot)) {
    return Normalize-Phase161AFullPath -Path $RepoRoot
  }
  $scriptRootCandidate = $PSScriptRoot
  if ([string]::IsNullOrWhiteSpace($scriptRootCandidate) -and -not [string]::IsNullOrWhiteSpace($PSCommandPath)) {
    $scriptRootCandidate = Split-Path -Path $PSCommandPath -Parent
  }
  if ([string]::IsNullOrWhiteSpace($scriptRootCandidate) -and -not [string]::IsNullOrWhiteSpace($MyInvocation.MyCommand.Path)) {
    $scriptRootCandidate = Split-Path -Path $MyInvocation.MyCommand.Path -Parent
  }
  if ([string]::IsNullOrWhiteSpace($scriptRootCandidate)) {
    throw "PHASE161A_SCRIPT_ROOT_UNAVAILABLE"
  }
  return Normalize-Phase161AFullPath -Path (Join-Path $scriptRootCandidate "..")
}

function Resolve-Phase161APath {
  param(
    [string]$RepoRoot,
    [string]$Path
  )
  if ([string]::IsNullOrWhiteSpace($Path)) {
    return ""
  }
  if ([System.IO.Path]::IsPathRooted($Path)) {
    return [System.IO.Path]::GetFullPath($Path)
  }
  return [System.IO.Path]::GetFullPath((Join-Path $RepoRoot $Path))
}

function ConvertTo-Phase161ARelativePath {
  param([string]$RepoRoot, [string]$FullPath)
  if ([string]::IsNullOrWhiteSpace($FullPath)) {
    return "NONE"
  }
  $normalizedRoot = Normalize-Phase161AFullPath -Path $RepoRoot
  $normalizedPath = Normalize-Phase161AFullPath -Path $FullPath
  if ($normalizedPath -eq $normalizedRoot) {
    return "."
  }
  if (-not $normalizedPath.StartsWith($normalizedRoot + [System.IO.Path]::DirectorySeparatorChar, [System.StringComparison]::OrdinalIgnoreCase)) {
    return $FullPath
  }
  return ($normalizedPath.Substring($normalizedRoot.Length + 1) -replace "\\", "/")
}

function Read-Phase161AJsonSafe {
  param([string]$Path)
  try {
    if ([string]::IsNullOrWhiteSpace($Path) -or -not (Test-Path -LiteralPath $Path)) {
      return $null
    }
    return Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json
  } catch {
    return $null
  }
}

function Get-Phase161APropertyValue {
  param(
    [object]$Object,
    [string]$Name,
    [object]$DefaultValue = $null
  )
  if ($null -ne $Object -and $Object.PSObject.Properties.Name -contains $Name) {
    return $Object.$Name
  }
  return $DefaultValue
}

function Get-Phase161ARouteLockSnapshot {
  param([string]$RepoRoot)
  $activeRoutePath = Join-Path $RepoRoot "route_locks/ACTIVE_ROUTE_LOCK.json"
  $activeRoute = Read-Phase161AJsonSafe -Path $activeRoutePath
  $lockFileRelative = if ($null -ne $activeRoute) { [string](Get-Phase161APropertyValue -Object $activeRoute -Name "active_route_lock_file" -DefaultValue "NONE") } else { "NONE" }
  $lockFilePath = if ($lockFileRelative -ne "NONE") { Resolve-Phase161APath -RepoRoot $RepoRoot -Path $lockFileRelative } else { "" }
  $lockText = ""
  if (-not [string]::IsNullOrWhiteSpace($lockFilePath) -and (Test-Path -LiteralPath $lockFilePath)) {
    $lockText = Get-Content -LiteralPath $lockFilePath -Raw
  }
  $stepCount = if ([string]::IsNullOrWhiteSpace($lockText)) { 0 } else { @([regex]::Matches($lockText, "(?m)^\s*\d+\.\s+")).Count }
  $version = if ($null -ne $activeRoute) { [string](Get-Phase161APropertyValue -Object $activeRoute -Name "active_route_lock_version" -DefaultValue "NONE") } else { "NONE" }
  $status = if ($null -ne $activeRoute) { [string](Get-Phase161APropertyValue -Object $activeRoute -Name "active_route_lock_status" -DefaultValue "MISSING") } else { "MISSING" }
  $target = if ($null -ne $activeRoute) { [string](Get-Phase161APropertyValue -Object $activeRoute -Name "next_target_phase" -DefaultValue "NONE") } else { "NONE" }
  $stamp = "MISSING"
  if ($status -ne "MISSING") {
    $stamp = "$status`:$version`:$target"
  }
  $phase161Lock = ($version -match "PHASE161" -or $lockFileRelative -match "PHASE161" -or $target -match "PHASE161")
  return [ordered]@{
    active_route_lock_file = $lockFileRelative
    active_route_lock_status = $status
    active_route_lock_version = $version
    active_route_lock_stamp = $stamp
    active_route_lock_stamp_exposed = ($stamp -ne "MISSING")
    next_target_phase = $target
    current_route_step_id = "PHASE161A_SCHOOL_ENTRY_FOUNDATION_V1"
    current_route_step_title = "School entry foundation"
    route_locked_step_count = $stepCount
    route_drift_detected = -not $phase161Lock
    route_exhausted = $false
    no_silent_route_change = if ($null -ne $activeRoute) { [bool](Get-Phase161APropertyValue -Object $activeRoute -Name "no_silent_route_change" -DefaultValue $true) } else { $true }
    owner_approval_required_for_route_change = if ($null -ne $activeRoute) { [bool](Get-Phase161APropertyValue -Object $activeRoute -Name "owner_approval_required_for_route_change" -DefaultValue $true) } else { $true }
  }
}

function Get-Phase161ALatestSchoolRunRoot {
  param(
    [string]$RepoRoot,
    [string]$SessionRoot,
    [string]$SchoolRunId
  )
  $schoolRunsRoot = Join-Path $RepoRoot "runtime_sessions/school_runs"
  if (-not [string]::IsNullOrWhiteSpace($SchoolRunId)) {
    $candidate = Join-Path $schoolRunsRoot $SchoolRunId
    if (Test-Path -LiteralPath (Join-Path $candidate "school_run_manifest.json")) {
      return $candidate
    }
  }
  if (-not [string]::IsNullOrWhiteSpace($SessionRoot)) {
    $sessionRootFull = Resolve-Phase161APath -RepoRoot $RepoRoot -Path $SessionRoot
    if (Test-Path -LiteralPath (Join-Path $sessionRootFull "school_run_manifest.json")) {
      return $sessionRootFull
    }
    $pointerPath = Join-Path $sessionRootFull "school_run_pointer.json"
    $pointer = Read-Phase161AJsonSafe -Path $pointerPath
    if ($null -ne $pointer) {
      $pointerRoot = [string](Get-Phase161APropertyValue -Object $pointer -Name "school_run_root" -DefaultValue "")
      $pointerId = [string](Get-Phase161APropertyValue -Object $pointer -Name "school_run_id" -DefaultValue "")
      if (-not [string]::IsNullOrWhiteSpace($pointerRoot)) {
        $candidate = Resolve-Phase161APath -RepoRoot $RepoRoot -Path $pointerRoot
        if (Test-Path -LiteralPath (Join-Path $candidate "school_run_manifest.json")) {
          return $candidate
        }
      }
      if (-not [string]::IsNullOrWhiteSpace($pointerId)) {
        $candidate = Join-Path $schoolRunsRoot $pointerId
        if (Test-Path -LiteralPath (Join-Path $candidate "school_run_manifest.json")) {
          return $candidate
        }
      }
    }
  }
  if (-not (Test-Path -LiteralPath $schoolRunsRoot)) {
    return ""
  }
  $runDirs = @(Get-ChildItem -LiteralPath $schoolRunsRoot -Directory -ErrorAction SilentlyContinue | Where-Object { Test-Path -LiteralPath (Join-Path $_.FullName "school_run_manifest.json") } | Sort-Object LastWriteTimeUtc, Name)
  if ($runDirs.Count -lt 1) {
    return ""
  }
  return $runDirs[-1].FullName
}

function Get-Phase161ASchoolRunSnapshot {
  param(
    [string]$RepoRoot,
    [string]$SchoolRunRoot,
    [object]$RouteSnapshot
  )
  if ([string]::IsNullOrWhiteSpace($SchoolRunRoot) -or -not (Test-Path -LiteralPath (Join-Path $SchoolRunRoot "school_run_manifest.json"))) {
    return [ordered]@{
      school_run_exists = $false
      school_run_root = "NONE"
      active_school_run_id = "NONE"
      active_curriculum_id = "NONE"
      school_lesson_total_count = 0
      school_lesson_pass_count = 0
      school_lesson_fail_count = 0
      school_lesson_quarantine_count = 0
      school_morning_review_written = $false
      run_continues_after_failed_lesson = $false
      quarantine_handled_separately = $false
      accepted_repo_mutated = $false
      protected_state_mutated = $false
      no_accepted_repo_mutation = $true
      no_protected_state_mutation = $true
    }
  }
  $manifestPath = Join-Path $SchoolRunRoot "school_run_manifest.json"
  $manifest = Read-Phase161AJsonSafe -Path $manifestPath
  $resultsRoot = Join-Path $SchoolRunRoot "lesson_results"
  $resultFiles = @()
  if (Test-Path -LiteralPath $resultsRoot) {
    $resultFiles = @(Get-ChildItem -LiteralPath $resultsRoot -File -Filter "*_result.json" -ErrorAction SilentlyContinue | Sort-Object Name)
  }
  $results = @()
  foreach ($resultFile in $resultFiles) {
    $result = Read-Phase161AJsonSafe -Path $resultFile.FullName
    if ($null -ne $result) {
      $results += $result
    }
  }
  $total = if ($null -ne $manifest -and $manifest.PSObject.Properties.Name -contains "lesson_total_count") { [int]$manifest.lesson_total_count } else { $results.Count }
  $pass = if ($null -ne $manifest -and $manifest.PSObject.Properties.Name -contains "lesson_pass_count") { [int]$manifest.lesson_pass_count } else { @($results | Where-Object { [string]$_.status -eq "PASS" }).Count }
  $fail = if ($null -ne $manifest -and $manifest.PSObject.Properties.Name -contains "lesson_fail_count") { [int]$manifest.lesson_fail_count } else { @($results | Where-Object { [string]$_.status -eq "FAIL" }).Count }
  $quarantine = if ($null -ne $manifest -and $manifest.PSObject.Properties.Name -contains "lesson_quarantine_count") { [int]$manifest.lesson_quarantine_count } else { @($results | Where-Object { [string]$_.status -eq "QUARANTINED" }).Count }
  $morningReviewPath = Join-Path $SchoolRunRoot "morning_review.json"
  $morningReviewWritten = Test-Path -LiteralPath $morningReviewPath
  $runContinuesAfterFailedLesson = if ($null -ne $manifest -and $manifest.PSObject.Properties.Name -contains "run_continues_after_failed_lesson") { [bool]$manifest.run_continues_after_failed_lesson } else { $false }
  $quarantineHandledSeparately = if ($null -ne $manifest -and $manifest.PSObject.Properties.Name -contains "quarantine_handled_separately") { [bool]$manifest.quarantine_handled_separately } else { ($fail -gt 0 -and $quarantine -gt 0) }
  $acceptedRepoMutated = if ($null -ne $manifest -and $manifest.PSObject.Properties.Name -contains "accepted_repo_mutated") { [bool]$manifest.accepted_repo_mutated } else { $false }
  $protectedStateMutated = if ($null -ne $manifest -and $manifest.PSObject.Properties.Name -contains "protected_state_mutated") { [bool]$manifest.protected_state_mutated } else { $false }
  return [ordered]@{
    school_run_exists = $true
    school_run_root = ConvertTo-Phase161ARelativePath -RepoRoot $RepoRoot -FullPath $SchoolRunRoot
    active_school_run_id = if ($null -ne $manifest -and $manifest.PSObject.Properties.Name -contains "school_run_id") { [string]$manifest.school_run_id } else { Split-Path -Path $SchoolRunRoot -Leaf }
    active_curriculum_id = if ($null -ne $manifest -and $manifest.PSObject.Properties.Name -contains "curriculum_id") { [string]$manifest.curriculum_id } else { "UNKNOWN" }
    school_lesson_total_count = $total
    school_lesson_pass_count = $pass
    school_lesson_fail_count = $fail
    school_lesson_quarantine_count = $quarantine
    school_morning_review_written = $morningReviewWritten
    run_continues_after_failed_lesson = $runContinuesAfterFailedLesson
    quarantine_handled_separately = $quarantineHandledSeparately
    accepted_repo_mutated = $acceptedRepoMutated
    protected_state_mutated = $protectedStateMutated
    no_accepted_repo_mutation = -not $acceptedRepoMutated
    no_protected_state_mutation = -not $protectedStateMutated
  }
}

function Get-Phase161ASchoolEntryState {
  param(
    [string]$RepoRoot = "",
    [string]$SessionRoot = "",
    [string]$SchoolRunId = ""
  )
  $resolvedRepoRoot = Resolve-Phase161ARepoRoot -RepoRoot $RepoRoot
  $routeSnapshot = Get-Phase161ARouteLockSnapshot -RepoRoot $resolvedRepoRoot
  $schoolRunRoot = Get-Phase161ALatestSchoolRunRoot -RepoRoot $resolvedRepoRoot -SessionRoot $SessionRoot -SchoolRunId $SchoolRunId
  $schoolRunSnapshot = Get-Phase161ASchoolRunSnapshot -RepoRoot $resolvedRepoRoot -SchoolRunRoot $schoolRunRoot -RouteSnapshot $routeSnapshot
  $schoolRouteDrift = [bool]$routeSnapshot.route_drift_detected
  $ownerReviewRequired = ([int]$schoolRunSnapshot.school_lesson_fail_count -gt 0 -or [int]$schoolRunSnapshot.school_lesson_quarantine_count -gt 0 -or $schoolRouteDrift)
  $state = [ordered]@{
    status = "PASS"
    surface_id = "PHASE161A_SCHOOL_ENTRY_STATE"
    resolved_repo_root = $resolvedRepoRoot
    school_entry_enabled = [bool]$schoolRunSnapshot.school_run_exists
    active_route_lock_file = [string]$routeSnapshot.active_route_lock_file
    active_route_lock_status = [string]$routeSnapshot.active_route_lock_status
    active_route_lock_version = [string]$routeSnapshot.active_route_lock_version
    active_route_lock_stamp = [string]$routeSnapshot.active_route_lock_stamp
    active_route_lock_stamp_exposed = [bool]$routeSnapshot.active_route_lock_stamp_exposed
    current_route_step_id = [string]$routeSnapshot.current_route_step_id
    current_route_step_title = [string]$routeSnapshot.current_route_step_title
    route_locked_step_count = [int]$routeSnapshot.route_locked_step_count
    next_target_phase = [string]$routeSnapshot.next_target_phase
    school_route_drift_detected = $schoolRouteDrift
    route_exhausted = [bool]$routeSnapshot.route_exhausted
    no_silent_route_change = [bool]$routeSnapshot.no_silent_route_change
    owner_approval_required_for_route_change = [bool]$routeSnapshot.owner_approval_required_for_route_change
    active_school_run_id = [string]$schoolRunSnapshot.active_school_run_id
    school_run_root = [string]$schoolRunSnapshot.school_run_root
    active_curriculum_id = [string]$schoolRunSnapshot.active_curriculum_id
    school_lesson_total_count = [int]$schoolRunSnapshot.school_lesson_total_count
    school_lesson_pass_count = [int]$schoolRunSnapshot.school_lesson_pass_count
    school_lesson_fail_count = [int]$schoolRunSnapshot.school_lesson_fail_count
    school_lesson_quarantine_count = [int]$schoolRunSnapshot.school_lesson_quarantine_count
    school_morning_review_written = [bool]$schoolRunSnapshot.school_morning_review_written
    school_owner_review_required = $ownerReviewRequired
    school_run_exists = [bool]$schoolRunSnapshot.school_run_exists
    run_continues_after_failed_lesson = [bool]$schoolRunSnapshot.run_continues_after_failed_lesson
    quarantine_handled_separately = [bool]$schoolRunSnapshot.quarantine_handled_separately
    no_accepted_repo_mutation = [bool]$schoolRunSnapshot.no_accepted_repo_mutation
    no_protected_state_mutation = [bool]$schoolRunSnapshot.no_protected_state_mutation
    inspected_at = (Get-Date).ToUniversalTime().ToString("o")
  }
  return [pscustomobject]$state
}

if (-not [string]::IsNullOrWhiteSpace($RepoRoot) -or -not [string]::IsNullOrWhiteSpace($SessionRoot) -or -not [string]::IsNullOrWhiteSpace($SchoolRunId)) {
  Get-Phase161ASchoolEntryState -RepoRoot $RepoRoot -SessionRoot $SessionRoot -SchoolRunId $SchoolRunId | ConvertTo-Json -Depth 30
}
