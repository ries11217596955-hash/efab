param(
  [string]$SessionRoot = "",
  [string]$RunId = "",
  [string]$DutyId = "NONE",
  [int]$TickNumber = 0
)

$ErrorActionPreference = "Stop"

function Normalize-Phase160FEvidenceFullPath {
  param([string]$Path)
  return [System.IO.Path]::GetFullPath($Path).TrimEnd([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar)
}

function Resolve-Phase160FEvidenceRepoRoot {
  $scriptRootCandidate = $PSScriptRoot
  if ([string]::IsNullOrWhiteSpace($scriptRootCandidate) -and -not [string]::IsNullOrWhiteSpace($PSCommandPath)) {
    $scriptRootCandidate = Split-Path -Path $PSCommandPath -Parent
  }
  if ([string]::IsNullOrWhiteSpace($scriptRootCandidate) -and -not [string]::IsNullOrWhiteSpace($MyInvocation.MyCommand.Path)) {
    $scriptRootCandidate = Split-Path -Path $MyInvocation.MyCommand.Path -Parent
  }
  if ([string]::IsNullOrWhiteSpace($scriptRootCandidate)) {
    throw "PHASE160F_EVIDENCE_SCRIPT_ROOT_UNAVAILABLE"
  }
  return Normalize-Phase160FEvidenceFullPath -Path (Join-Path $scriptRootCandidate "..")
}

function Resolve-Phase160FEvidencePath {
  param([string]$RepoRoot, [string]$Path)
  if ([System.IO.Path]::IsPathRooted($Path)) {
    return [System.IO.Path]::GetFullPath($Path)
  }
  return [System.IO.Path]::GetFullPath((Join-Path $RepoRoot $Path))
}

function ConvertTo-Phase160FEvidenceRelativePath {
  param([string]$RepoRoot, [string]$FullPath)
  $root = Normalize-Phase160FEvidenceFullPath -Path $RepoRoot
  $full = Normalize-Phase160FEvidenceFullPath -Path $FullPath
  if ($full -eq $root) {
    return "."
  }
  if (-not $full.StartsWith($root + [System.IO.Path]::DirectorySeparatorChar, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw "PHASE160F_EVIDENCE_PATH_OUTSIDE_REPO=$FullPath"
  }
  return ($full.Substring($root.Length + 1) -replace "\\", "/")
}

function Write-Phase160FEvidenceJsonFile {
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

function Read-Phase160FEvidenceJsonSafe {
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

function Get-Phase160FEvidenceFileCount {
  param([string]$Path, [string]$Pattern = "*.json")
  if (-not (Test-Path -LiteralPath $Path)) {
    return 0
  }
  return @(Get-ChildItem -LiteralPath $Path -File -Filter $Pattern -ErrorAction SilentlyContinue | Where-Object { $_.Name -ne "README.json" }).Count
}

function Get-Phase160FEvidenceLineCount {
  param([string]$Path)
  if (-not (Test-Path -LiteralPath $Path)) {
    return 0
  }
  return @((Get-Content -LiteralPath $Path -ErrorAction SilentlyContinue) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }).Count
}

function Assert-Phase160FEvidenceRunIdSafe {
  param([string]$RunId)
  if ([string]::IsNullOrWhiteSpace($RunId)) {
    return
  }
  if ($RunId.IndexOfAny([char[]]@("/", "\")) -ge 0) {
    throw "PHASE160F_EVIDENCE_RUN_ID_MUST_BE_LEAF=$RunId"
  }
}

$RepoRoot = Resolve-Phase160FEvidenceRepoRoot
$Pushed = $false

try {
  Push-Location $RepoRoot
  $Pushed = $true

  foreach ($identityFile in @("CAPABILITY_ROADMAP.json", "GENESIS_STATE.json", "TASK_QUEUE.json", "packs/registry.json", "orchestrator/run.ps1")) {
    if (-not (Test-Path -LiteralPath (Resolve-Phase160FEvidencePath -RepoRoot $RepoRoot -Path $identityFile))) {
      throw "STOP=WRONG_AGENT_BUILDER_REPO missing=$identityFile"
    }
  }

  Assert-Phase160FEvidenceRunIdSafe -RunId $RunId
  if (-not [string]::IsNullOrWhiteSpace($RunId) -and [string]::IsNullOrWhiteSpace($SessionRoot)) {
    $SessionRoot = "runtime_sessions/live_growth/$RunId"
  }
  if ([string]::IsNullOrWhiteSpace($SessionRoot)) {
    throw "PHASE160F_EVIDENCE_SESSION_ROOT_REQUIRED"
  }

  $SessionRootFull = Resolve-Phase160FEvidencePath -RepoRoot $RepoRoot -Path $SessionRoot
  $SessionRootRelative = ConvertTo-Phase160FEvidenceRelativePath -RepoRoot $RepoRoot -FullPath $SessionRootFull
  $SelectionRoot = Join-Path $SessionRootFull "self_initiated_goal_selection"
  New-Item -ItemType Directory -Force -Path $SelectionRoot | Out-Null

  $CurrentState = Read-Phase160FEvidenceJsonSafe -Path (Join-Path $SessionRootFull "current_state.json")
  $RunManifest = Read-Phase160FEvidenceJsonSafe -Path (Join-Path $SessionRootFull "run_manifest.json")
  $RuntimeGuard = Read-Phase160FEvidenceJsonSafe -Path (Join-Path $SessionRootFull "runtime_guard.json")
  $PromotionManifest = Read-Phase160FEvidenceJsonSafe -Path (Join-Path $SessionRootFull "promotion_bundle/promotion_manifest.json")
  $ActiveTaskState = Read-Phase160FEvidenceJsonSafe -Path (Join-Path $SessionRootFull "task_lifecycle/active_task_state.json")
  $Branch = (git branch --show-current).Trim()
  $Head = (git rev-parse --short HEAD).Trim()
  $Reports = @(Get-ChildItem -LiteralPath (Resolve-Phase160FEvidencePath -RepoRoot $RepoRoot -Path "reports/self_development") -File -ErrorAction SilentlyContinue | Select-Object -First 40 -ExpandProperty Name)
  $Proofs = @(Get-ChildItem -LiteralPath (Resolve-Phase160FEvidencePath -RepoRoot $RepoRoot -Path "proofs/self_development") -File -ErrorAction SilentlyContinue | Select-Object -First 40 -ExpandProperty Name)

  $TeacherInboxCount = Get-Phase160FEvidenceFileCount -Path (Join-Path $SessionRootFull "teacher_inbox")
  $TeacherDigestCount = Get-Phase160FEvidenceFileCount -Path (Join-Path $SessionRootFull "teacher_digest")
  $TeacherConsumedCount = Get-Phase160FEvidenceFileCount -Path (Join-Path $SessionRootFull "teacher_consumed") -Pattern "receipt_*.json"
  $TeacherQuarantineCount = Get-Phase160FEvidenceFileCount -Path (Join-Path $SessionRootFull "teacher_quarantine") -Pattern "quarantine_*.json"
  $CandidateCount = Get-Phase160FEvidenceFileCount -Path (Join-Path $SessionRootFull "candidate_workspace/candidate_bundles") -Pattern "candidate_manifest.json"
  if (Test-Path -LiteralPath (Join-Path $SessionRootFull "candidate_workspace/candidate_bundles")) {
    $CandidateCount = @(Get-ChildItem -LiteralPath (Join-Path $SessionRootFull "candidate_workspace/candidate_bundles") -File -Filter "candidate_manifest.json" -Recurse -ErrorAction SilentlyContinue).Count
  }

  $SelfStateInventory = [ordered]@{
    status = "PASS"
    run_id = if ([string]::IsNullOrWhiteSpace($RunId)) { "NONE" } else { $RunId }
    session_root = $SessionRootRelative
    duty_id = $DutyId
    tick_number = $TickNumber
    branch = $Branch
    current_head = $Head
    run_head = if ($null -ne $RunManifest -and $RunManifest.PSObject.Properties.Name -contains "run_head") { [string]$RunManifest.run_head } else { "NONE" }
    head_match = if ($null -ne $RunManifest -and $RunManifest.PSObject.Properties.Name -contains "run_head") { [string]$RunManifest.run_head -eq $Head } else { $false }
    live_repo_guard = if ($null -ne $RuntimeGuard -and $RuntimeGuard.PSObject.Properties.Name -contains "status") { [string]$RuntimeGuard.status } else { "UNKNOWN" }
    current_state_present = $null -ne $CurrentState
    run_manifest_present = $null -ne $RunManifest
    runtime_guard_present = $null -ne $RuntimeGuard
    event_log_line_count = Get-Phase160FEvidenceLineCount -Path (Join-Path $SessionRootFull "event_log.jsonl")
    experience_ledger_line_count = Get-Phase160FEvidenceLineCount -Path (Join-Path $SessionRootFull "self_growth/experience_ledger.jsonl")
    teacher_inbox_count = $TeacherInboxCount
    teacher_digest_count = $TeacherDigestCount
    teacher_consumed_count = $TeacherConsumedCount
    teacher_quarantine_count = $TeacherQuarantineCount
    candidate_count = $CandidateCount
    promotion_bundle_status = if ($null -ne $PromotionManifest -and $PromotionManifest.PSObject.Properties.Name -contains "promotion_status") { [string]$PromotionManifest.promotion_status } else { "NONE" }
    active_task_status = if ($null -ne $ActiveTaskState -and $ActiveTaskState.PSObject.Properties.Name -contains "status") { [string]$ActiveTaskState.status } else { "NONE" }
    safe_report_names = $Reports
    safe_proof_names = $Proofs
    inspected_at = (Get-Date).ToUniversalTime().ToString("o")
  }

  $CapabilityGapInventory = [ordered]@{
    status = "PASS"
    run_id = $SelfStateInventory.run_id
    gaps = @(
      [ordered]@{ gap_id = "SELF_INITIATED_USEFUL_GOAL_SELECTOR_HARDENING"; evidence = "no_teacher_inbox_requires_internal_goal_selection"; safety_boundary = "runtime_session_only" },
      [ordered]@{ gap_id = "PROMOTION_BUNDLE_HEALTH_INSPECTOR"; evidence = "promotion bundles need owner-readable completeness checks"; safety_boundary = "runtime_session_only" },
      [ordered]@{ gap_id = "RUNTIME_GUARD_REGRESSION_VALIDATOR"; evidence = "candidate production depends on live_repo_guard PASS"; safety_boundary = "runtime_session_only" },
      [ordered]@{ gap_id = "CANDIDATE_BUNDLE_COMPLETENESS_INSPECTOR"; evidence = "candidate bundles require fixed review files"; safety_boundary = "runtime_session_only" },
      [ordered]@{ gap_id = "LIVE_CONSOLE_FIELD_INTEGRITY_INSPECTOR"; evidence = "owner needs visible live fields"; safety_boundary = "runtime_session_only" }
    )
    candidate_workspace_state = if ($CandidateCount -gt 0) { "HAS_CANDIDATES" } else { "READY_FOR_FIRST_CANDIDATE" }
    no_teacher_inbox_required = $TeacherInboxCount -eq 0
    runtime_guard_required = $true
    created_at = (Get-Date).ToUniversalTime().ToString("o")
  }

  Write-Phase160FEvidenceJsonFile -Path (Join-Path $SelectionRoot "self_state_inventory.json") -Object $SelfStateInventory
  Write-Phase160FEvidenceJsonFile -Path (Join-Path $SelectionRoot "capability_gap_inventory.json") -Object $CapabilityGapInventory

  [pscustomobject][ordered]@{
    status = "PASS"
    run_id = $SelfStateInventory.run_id
    session_root = $SessionRootRelative
    selection_root = ConvertTo-Phase160FEvidenceRelativePath -RepoRoot $RepoRoot -FullPath $SelectionRoot
    self_state_inventory_written = $true
    capability_gap_inventory_written = $true
    teacher_inbox_count = $TeacherInboxCount
    live_repo_guard = $SelfStateInventory.live_repo_guard
    run_head = $SelfStateInventory.run_head
    current_head = $Head
    head_match = $SelfStateInventory.head_match
  } | ConvertTo-Json -Depth 20
} finally {
  if ($Pushed) {
    Pop-Location
  }
}
