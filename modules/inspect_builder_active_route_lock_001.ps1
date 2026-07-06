param(
  [string]$RepoRoot = "."
)

$ErrorActionPreference = "Stop"

function Normalize-Phase160LActiveRoutePath {
  param([string]$Path)
  return [System.IO.Path]::GetFullPath($Path).TrimEnd([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar)
}

function Resolve-Phase160LActiveRouteRepoRoot {
  param([string]$RepoRootParameter)
  if (-not [string]::IsNullOrWhiteSpace($RepoRootParameter) -and $RepoRootParameter -ne ".") {
    return Normalize-Phase160LActiveRoutePath -Path $RepoRootParameter
  }
  $scriptRoot = $PSScriptRoot
  if ([string]::IsNullOrWhiteSpace($scriptRoot) -and -not [string]::IsNullOrWhiteSpace($PSCommandPath)) {
    $scriptRoot = Split-Path -Path $PSCommandPath -Parent
  }
  if ([string]::IsNullOrWhiteSpace($scriptRoot)) {
    throw "PHASE160L_ACTIVE_ROUTE_SCRIPT_ROOT_UNAVAILABLE"
  }
  return Normalize-Phase160LActiveRoutePath -Path (Join-Path $scriptRoot "..")
}

function Resolve-Phase160LActiveRoutePath {
  param([string]$Root, [string]$Path)
  if ([System.IO.Path]::IsPathRooted($Path)) {
    return [System.IO.Path]::GetFullPath($Path)
  }
  return [System.IO.Path]::GetFullPath((Join-Path $Root $Path))
}

function Get-Phase160LActiveDeclaredStatus {
  param([string]$Text)
  if ($Text -match "(?im)^\s*status\s*:\s*([A-Z0-9_]+)") {
    return $Matches[1]
  }
  if ($Text -match "(?im)^\s*Status\s*:\s*([A-Z0-9_]+)") {
    return $Matches[1]
  }
  return "UNKNOWN"
}

function Get-Phase160LActiveLockedStepCount {
  param([string]$Text)
  return @([regex]::Matches($Text, "(?m)^\s*\d+\.\s+\S.+$")).Count
}

$resolvedRoot = Resolve-Phase160LActiveRouteRepoRoot -RepoRootParameter $RepoRoot
$pushed = $false

try {
  Push-Location $resolvedRoot
  $pushed = $true
  foreach ($identityFile in @("CAPABILITY_ROADMAP.json", "GENESIS_STATE.json", "TASK_QUEUE.json", "packs/registry.json", "orchestrator/run.ps1")) {
    if (-not (Test-Path -LiteralPath (Resolve-Phase160LActiveRoutePath -Root $resolvedRoot -Path $identityFile))) {
      throw "STOP=WRONG_AGENT_BUILDER_REPO missing=$identityFile"
    }
  }

  $indexPath = Resolve-Phase160LActiveRoutePath -Root $resolvedRoot -Path "route_locks/ACTIVE_ROUTE_LOCK.json"
  if (-not (Test-Path -LiteralPath $indexPath)) {
    throw "PHASE160L_ACTIVE_ROUTE_INDEX_MISSING"
  }
  $index = Get-Content -LiteralPath $indexPath -Raw | ConvertFrom-Json
  $activePath = [string]$index.active_route_lock_file
  $activeFull = Resolve-Phase160LActiveRoutePath -Root $resolvedRoot -Path $activePath
  if (-not (Test-Path -LiteralPath $activeFull)) {
    throw "PHASE160L_ACTIVE_ROUTE_FILE_MISSING=$activePath"
  }
  $text = Get-Content -LiteralPath $activeFull -Raw
  [ordered]@{
    status = "PASS"
    active_route_lock_file = $activePath
    active_route_lock_version = [string]$index.active_route_lock_version
    active_route_lock_status = [string]$index.active_route_lock_status
    declared_status = Get-Phase160LActiveDeclaredStatus -Text $text
    next_target_phase = [string]$index.next_target_phase
    points_to_phase161 = ($text -match "PHASE161_BATCH_SCHOOL_FOUNDATION")
    locked_step_count = Get-Phase160LActiveLockedStepCount -Text $text
    route_principle_present = ($text -match "no single-symptom repair; batch readiness first")
    owner_approval_required_for_route_change = ($index.owner_approval_required_for_route_change -eq $true)
    no_silent_route_change = ($index.no_silent_route_change -eq $true)
    route_baseline_head = [string]$index.route_baseline_head
    owner_accepted_baseline_head = [string]$index.owner_accepted_baseline_head
    inspected_at = (Get-Date).ToUniversalTime().ToString("o")
  } | ConvertTo-Json -Depth 100
} finally {
  if ($pushed) {
    Pop-Location
  }
}
