param(
  [string]$RepoRoot = "",
  [switch]$RefreshDecision,
  [switch]$EmitJson
)

$ErrorActionPreference = "Stop"

function Resolve-Phase161BInspectRepoRoot {
  param([string]$RepoRoot)
  if (-not [string]::IsNullOrWhiteSpace($RepoRoot)) {
    return [System.IO.Path]::GetFullPath($RepoRoot)
  }
  return [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
}

function Read-Phase161BInspectJsonSafe {
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

function Invoke-Phase161BInspectDecisionScript {
  param([string]$RepoRoot)
  $scriptPath = Join-Path $RepoRoot "modules/decide_builder_learning_mode_001.ps1"
  $output = @(powershell -NoProfile -ExecutionPolicy Bypass -File $scriptPath -RepoRoot $RepoRoot -EmitJson 2>&1 | ForEach-Object { [string]$_ })
  if ($LASTEXITCODE -ne 0) {
    throw "PHASE161B_INSPECT_DECISION_REFRESH_FAILED=$($output -join ' | ')"
  }
  return ($output -join "`n") | ConvertFrom-Json
}

function Get-Phase161BLearningModeState {
  param([string]$RepoRoot = "", [bool]$RefreshDecision = $false)
  $resolvedRepoRoot = Resolve-Phase161BInspectRepoRoot -RepoRoot $RepoRoot
  $decision = $null
  if ($RefreshDecision) {
    $decision = Invoke-Phase161BInspectDecisionScript -RepoRoot $resolvedRepoRoot
  } else {
    $decisionRoot = Join-Path $resolvedRepoRoot "runtime_sessions/learning_mode_decisions"
    if (Test-Path -LiteralPath $decisionRoot) {
      $files = @(Get-ChildItem -LiteralPath $decisionRoot -File -Filter "learning_mode_decision.json" -Recurse -ErrorAction SilentlyContinue | Sort-Object LastWriteTimeUtc, Name)
      if ($files.Count -gt 0) {
        $decision = Read-Phase161BInspectJsonSafe -Path $files[-1].FullName
      }
    }
  }
  if ($null -eq $decision) {
    return [pscustomobject][ordered]@{
      status = "PASS"
      learning_mode = "SELF_MODE"
      previous_learning_mode = "NONE"
      learning_mode_decision_reason = "NO_DECISION_RECORD_FOUND_DEFAULT_SELF_MODE"
      active_curriculum_id = "NONE"
      active_school_run_id = "NONE"
      absorption_required = $false
      last_absorption_id = "NONE"
      last_absorption_status = "NONE"
      recommended_next_self_gap = "NONE"
      selected_curriculum_source = "NONE"
      owner_curriculum_available = $false
      internal_curriculum_available = $false
      generated_curriculum_available = $false
      school_mode_allowed = $false
      self_mode_allowed = $true
      safe_idle_only = $false
      no_accepted_repo_mutation = $true
      no_protected_state_mutation = $true
      inspected_at = (Get-Date).ToUniversalTime().ToString("o")
    }
  }
  return [pscustomobject][ordered]@{
    status = "PASS"
    learning_mode = [string]$decision.learning_mode
    previous_learning_mode = [string]$decision.previous_learning_mode
    learning_mode_decision_reason = [string]$decision.decision_reason
    active_curriculum_id = [string]$decision.active_curriculum_id
    active_school_run_id = [string]$decision.active_school_run_id
    absorption_required = [bool]$decision.absorption_required
    last_absorption_id = [string]$decision.last_absorption_id
    last_absorption_status = [string]$decision.last_absorption_status
    recommended_next_self_gap = [string]$decision.recommended_next_self_gap
    selected_curriculum_source = [string]$decision.selected_curriculum_source
    owner_curriculum_available = [bool]$decision.owner_curriculum_available
    internal_curriculum_available = [bool]$decision.internal_curriculum_available
    generated_curriculum_available = [bool]$decision.generated_curriculum_available
    school_mode_allowed = [bool]$decision.school_mode_allowed
    self_mode_allowed = [bool]$decision.self_mode_allowed
    safe_idle_only = [bool]$decision.safe_idle_only
    no_accepted_repo_mutation = [bool]$decision.no_accepted_repo_mutation
    no_protected_state_mutation = [bool]$decision.no_protected_state_mutation
    inspected_at = (Get-Date).ToUniversalTime().ToString("o")
  }
}

if ($EmitJson) {
  Get-Phase161BLearningModeState -RepoRoot $RepoRoot -RefreshDecision ([bool]$RefreshDecision) | ConvertTo-Json -Depth 50
}
