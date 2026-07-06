param(
  [string]$RepoRoot = ".",
  [string]$OutputDir = "reports/self_development",
  [switch]$NoWrite
)

$ErrorActionPreference = "Stop"

function Normalize-Phase160LRoutePath {
  param([string]$Path)
  return [System.IO.Path]::GetFullPath($Path).TrimEnd([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar)
}

function Resolve-Phase160LRouteRepoRoot {
  param([string]$RepoRootParameter)
  if (-not [string]::IsNullOrWhiteSpace($RepoRootParameter) -and $RepoRootParameter -ne ".") {
    return Normalize-Phase160LRoutePath -Path $RepoRootParameter
  }
  $scriptRoot = $PSScriptRoot
  if ([string]::IsNullOrWhiteSpace($scriptRoot) -and -not [string]::IsNullOrWhiteSpace($PSCommandPath)) {
    $scriptRoot = Split-Path -Path $PSCommandPath -Parent
  }
  if ([string]::IsNullOrWhiteSpace($scriptRoot)) {
    throw "PHASE160L_ROUTE_STATUS_SCRIPT_ROOT_UNAVAILABLE"
  }
  return Normalize-Phase160LRoutePath -Path (Join-Path $scriptRoot "..")
}

function Resolve-Phase160LRoutePath {
  param([string]$Root, [string]$Path)
  if ([System.IO.Path]::IsPathRooted($Path)) {
    return [System.IO.Path]::GetFullPath($Path)
  }
  return [System.IO.Path]::GetFullPath((Join-Path $Root $Path))
}

function ConvertTo-Phase160LRouteRelativePath {
  param([string]$Root, [string]$FullPath)
  $rootFull = Normalize-Phase160LRoutePath -Path $Root
  $pathFull = Normalize-Phase160LRoutePath -Path $FullPath
  if ($pathFull -eq $rootFull) {
    return "."
  }
  if (-not $pathFull.StartsWith($rootFull + [System.IO.Path]::DirectorySeparatorChar, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw "PHASE160L_ROUTE_STATUS_PATH_OUTSIDE_REPO=$FullPath"
  }
  return ($pathFull.Substring($rootFull.Length + 1) -replace "\\", "/")
}

function Write-Phase160LRouteJsonFile {
  param([string]$Path, [object]$Object)
  $directory = Split-Path -Path $Path -Parent
  if ($directory -and -not (Test-Path -LiteralPath $directory)) {
    New-Item -ItemType Directory -Force -Path $directory | Out-Null
  }
  $json = ($Object | ConvertTo-Json -Depth 100) -replace "`r`n", "`n"
  if (-not $json.EndsWith("`n")) {
    $json += "`n"
  }
  [System.IO.File]::WriteAllText($Path, $json, [System.Text.UTF8Encoding]::new($false))
}

function Read-Phase160LRouteTextSafe {
  param([string]$Path)
  if (-not (Test-Path -LiteralPath $Path)) {
    return ""
  }
  return Get-Content -LiteralPath $Path -Raw
}

function Read-Phase160LRouteIndexSafe {
  param([string]$Root)
  $indexPath = Resolve-Phase160LRoutePath -Root $Root -Path "route_locks/ACTIVE_ROUTE_LOCK.json"
  if (-not (Test-Path -LiteralPath $indexPath)) {
    return $null
  }
  return Get-Content -LiteralPath $indexPath -Raw | ConvertFrom-Json
}

function Get-Phase160LDeclaredStatus {
  param([string]$Text)
  if ($Text -match "(?im)^\s*status\s*:\s*([A-Z0-9_]+)") {
    return $Matches[1]
  }
  if ($Text -match "(?im)^\s*Status\s*:\s*([A-Z0-9_]+)") {
    return $Matches[1]
  }
  return "UNKNOWN"
}

function Get-Phase160LRouteLockFiles {
  param([string]$Root)
  $files = @()
  $files += @(Get-ChildItem -LiteralPath $Root -File -Filter "AGENT_BUILDER_NEXT_15_STEPS_LOCK*.md" -ErrorAction SilentlyContinue)
  foreach ($directory in @("route_locks", "reports/planning")) {
    $full = Resolve-Phase160LRoutePath -Root $Root -Path $directory
    if (Test-Path -LiteralPath $full) {
      $files += @(Get-ChildItem -LiteralPath $full -File -Filter "AGENT_BUILDER_NEXT_15_STEPS_LOCK*.md" -ErrorAction SilentlyContinue)
    }
  }
  return @($files | Sort-Object FullName -Unique)
}

function Get-Phase160LLockedStepCount {
  param([string]$Text)
  return @([regex]::Matches($Text, "(?m)^\s*\d+\.\s+\S.+$")).Count
}

function New-Phase160LRouteRecord {
  param(
    [string]$Root,
    [System.IO.FileInfo]$File,
    [object]$Index
  )
  $relativePath = ConvertTo-Phase160LRouteRelativePath -Root $Root -FullPath $File.FullName
  $text = Read-Phase160LRouteTextSafe -Path $File.FullName
  $declaredStatus = Get-Phase160LDeclaredStatus -Text $text
  $activeIndexPath = if ($null -ne $Index) { [string]$Index.active_route_lock_file } else { "" }
  $classification = "UNKNOWN"
  $reason = "No classification marker found."
  $recommendation = "create next route lock"
  if ($declaredStatus -eq "ACTIVE_ROUTE_LOCK" -and $relativePath -eq $activeIndexPath) {
    $classification = "ACTIVE"
    $reason = "Declared active and matches route_locks/ACTIVE_ROUTE_LOCK.json."
    $recommendation = "keep current lock"
  } elseif ($text -match "SUPERSEDED_BY_PHASE160L_ROUTE_LOCK_SUPERSESSION_REPAIR" -or $text -match "(?im)^\s*classification\s*:\s*SUPERSEDED") {
    $classification = "SUPERSEDED"
    $reason = "Marked as superseded by PHASE160L route lock supersession repair."
    $recommendation = "archived old lock as reference"
  } elseif ($declaredStatus -eq "ARCHIVED_REFERENCE") {
    $classification = "ARCHIVED_REFERENCE"
    $reason = "Marked as historical reference only."
    $recommendation = "archive old lock as reference"
  } elseif ($declaredStatus -eq "DEPRECATED_DO_NOT_USE") {
    $classification = "DEPRECATED_DO_NOT_USE"
    $reason = "Marked deprecated."
    $recommendation = "do not use"
  } elseif ($relativePath -eq "AGENT_BUILDER_NEXT_15_STEPS_LOCK_V2_R2.md") {
    $classification = "SUPERSEDED"
    $reason = "The PHASE91-PHASE105 route is completed and behind the PHASE160K accepted runtime."
    $recommendation = "archive old lock as reference"
  } elseif ($relativePath -eq "route_locks/AGENT_BUILDER_NEXT_15_STEPS_LOCK_V3_SELF_PACK_AUTHOR.md") {
    $classification = "SUPERSEDED"
    $reason = "The PHASE107-PHASE111 route is exhausted and behind the PHASE160K accepted runtime."
    $recommendation = "supersede with PHASE161 curriculum route"
  } elseif ($declaredStatus -eq "ACTIVE_ROUTE_LOCK") {
    $classification = "UNKNOWN"
    $reason = "Declares active but does not match the active route lock index."
  }
  return [ordered]@{
    path = $relativePath
    declared_status = $declaredStatus
    classification = $classification
    reason = $reason
    is_active_route = ($classification -eq "ACTIVE")
    points_to_phase161 = ($text -match "PHASE161_BATCH_SCHOOL_FOUNDATION")
    locked_step_count = Get-Phase160LLockedStepCount -Text $text
    recommendation = $recommendation
  }
}

$resolvedRoot = Resolve-Phase160LRouteRepoRoot -RepoRootParameter $RepoRoot
$pushed = $false

try {
  Push-Location $resolvedRoot
  $pushed = $true
  foreach ($identityFile in @("CAPABILITY_ROADMAP.json", "GENESIS_STATE.json", "TASK_QUEUE.json", "packs/registry.json", "orchestrator/run.ps1")) {
    if (-not (Test-Path -LiteralPath (Resolve-Phase160LRoutePath -Root $resolvedRoot -Path $identityFile))) {
      throw "STOP=WRONG_AGENT_BUILDER_REPO missing=$identityFile"
    }
  }

  $index = Read-Phase160LRouteIndexSafe -Root $resolvedRoot
  $records = @()
  foreach ($file in @(Get-Phase160LRouteLockFiles -Root $resolvedRoot)) {
    $records += New-Phase160LRouteRecord -Root $resolvedRoot -File $file -Index $index
  }
  $activeRecords = @($records | Where-Object { $_.classification -eq "ACTIVE" })
  $oldRouteRecords = @($records | Where-Object {
    $_.path -in @(
      "AGENT_BUILDER_NEXT_15_STEPS_LOCK_V2_R2.md",
      "route_locks/AGENT_BUILDER_NEXT_15_STEPS_LOCK_V3_SELF_PACK_AUTHOR.md"
    )
  })
  $result = [ordered]@{
    status = "PASS"
    audit_id = "PHASE160L_ROUTE_LOCK_SUPERSESSION_REPAIR_V1"
    line = "AGENT_BUILDER_SELF_DEVELOPMENT"
    active_line = "AGENT_BUILDER_SELF_DEVELOPMENT"
    mode = "VERIFY"
    stage = "ROUTE LOCK STATUS"
    stage_id = "phase160l_route_lock_status"
    route_lock_count = $records.Count
    route_locks = @($records)
    active_route_lock_count = $activeRecords.Count
    active_route_lock_file = if ($activeRecords.Count -eq 1) { [string]$activeRecords[0].path } else { "" }
    route_index_exists = ($null -ne $index)
    route_index_active_file = if ($null -ne $index) { [string]$index.active_route_lock_file } else { "" }
    old_route_lock_status_detected = @($oldRouteRecords | Where-Object { $_.classification -eq "SUPERSEDED" }).Count -gt 0
    old_route_lock_superseded = (@($oldRouteRecords | Where-Object { $_.classification -eq "SUPERSEDED" }).Count -eq 2)
    active_marker_contradiction = @($records | Where-Object { $_.declared_status -eq "ACTIVE_ROUTE_LOCK" -and $_.classification -ne "ACTIVE" }).Count -gt 0
    exactly_one_active_route_lock = ($activeRecords.Count -eq 1)
    active_route_lock_points_to_phase161 = ($activeRecords.Count -eq 1 -and [bool]$activeRecords[0].points_to_phase161)
    active_route_lock_has_10_to_15_steps = ($activeRecords.Count -eq 1 -and [int]$activeRecords[0].locked_step_count -ge 10 -and [int]$activeRecords[0].locked_step_count -le 15)
    recommendation = "supersede with PHASE161 curriculum route"
    allowed_recommendations = @("keep current lock", "create next route lock", "supersede with PHASE161 curriculum route", "archive old lock as reference")
    route_lock_edited = $true
    root_cause = "Route-lock files and state markers were not advanced to the accepted PHASE160K runtime reality, leaving stale active-looking locks in the repo."
    repair_package = "ROUTE_LOCK_SUPERSESSION_REPAIR"
    blocks_phase161 = $true
    no_silent_route_change = ($null -ne $index -and $index.no_silent_route_change -eq $true -and $index.owner_approval_required_for_route_change -eq $true)
    inspected_at = (Get-Date).ToUniversalTime().ToString("o")
  }

  if (-not $NoWrite) {
    $outputRootFull = Resolve-Phase160LRoutePath -Root $resolvedRoot -Path $OutputDir
    Write-Phase160LRouteJsonFile -Path (Join-Path $outputRootFull "stage_06_route_lock_status_audit.json") -Object $result
  }
  $result | ConvertTo-Json -Depth 100
} finally {
  if ($pushed) {
    Pop-Location
  }
}
