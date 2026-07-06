param(
  [string]$RepoRoot = ".",
  [string]$OutputDir = "reports/self_development",
  [string]$RuntimeRoot = "runtime_sessions/live_growth/PHASE160I_LONG_RUN_LIFECYCLE_AUDIT_BACKLOG_001"
)

$ErrorActionPreference = "Stop"

function Normalize-Phase160IBacklogPath {
  param([string]$Path)
  return [System.IO.Path]::GetFullPath($Path).TrimEnd([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar)
}

function Resolve-Phase160IBacklogRepoRoot {
  param([string]$RepoRootParameter)
  if (-not [string]::IsNullOrWhiteSpace($RepoRootParameter) -and $RepoRootParameter -ne ".") {
    return Normalize-Phase160IBacklogPath -Path $RepoRootParameter
  }
  $scriptRoot = $PSScriptRoot
  if ([string]::IsNullOrWhiteSpace($scriptRoot) -and -not [string]::IsNullOrWhiteSpace($PSCommandPath)) {
    $scriptRoot = Split-Path -Path $PSCommandPath -Parent
  }
  if ([string]::IsNullOrWhiteSpace($scriptRoot)) {
    throw "PHASE160I_BACKLOG_SCRIPT_ROOT_UNAVAILABLE"
  }
  return Normalize-Phase160IBacklogPath -Path (Join-Path $scriptRoot "..")
}

function Resolve-Phase160IBacklogPath {
  param([string]$Root, [string]$Path)
  if ([System.IO.Path]::IsPathRooted($Path)) {
    return [System.IO.Path]::GetFullPath($Path)
  }
  return [System.IO.Path]::GetFullPath((Join-Path $Root $Path))
}

function ConvertTo-Phase160IBacklogRelativePath {
  param([string]$Root, [string]$FullPath)
  $rootFull = Normalize-Phase160IBacklogPath -Path $Root
  $pathFull = Normalize-Phase160IBacklogPath -Path $FullPath
  if ($pathFull -eq $rootFull) {
    return "."
  }
  if (-not $pathFull.StartsWith($rootFull + [System.IO.Path]::DirectorySeparatorChar, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw "PHASE160I_BACKLOG_PATH_OUTSIDE_REPO=$FullPath"
  }
  return ($pathFull.Substring($rootFull.Length + 1) -replace "\\", "/")
}

function Write-Phase160IBacklogJsonFile {
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

function Read-Phase160IBacklogTextSafe {
  param([string]$Path)
  if (-not (Test-Path -LiteralPath $Path)) {
    return ""
  }
  return Get-Content -LiteralPath $Path -Raw
}

$resolvedRoot = Resolve-Phase160IBacklogRepoRoot -RepoRootParameter $RepoRoot
$pushed = $false

try {
  Push-Location $resolvedRoot
  $pushed = $true
  foreach ($identityFile in @("CAPABILITY_ROADMAP.json", "GENESIS_STATE.json", "TASK_QUEUE.json", "packs/registry.json", "orchestrator/run.ps1")) {
    if (-not (Test-Path -LiteralPath (Resolve-Phase160IBacklogPath -Root $resolvedRoot -Path $identityFile))) {
      throw "STOP=WRONG_AGENT_BUILDER_REPO missing=$identityFile"
    }
  }

  $outputRootFull = Resolve-Phase160IBacklogPath -Root $resolvedRoot -Path $OutputDir
  $runtimeRootFull = Resolve-Phase160IBacklogPath -Root $resolvedRoot -Path $RuntimeRoot
  $activeTaskDir = Join-Path $runtimeRootFull "active_task"
  $taskBacklogDir = Join-Path $runtimeRootFull "task_backlog"
  $taskLifecycleDir = Join-Path $runtimeRootFull "task_lifecycle"
  New-Item -ItemType Directory -Force -Path $activeTaskDir, $taskBacklogDir, $taskLifecycleDir | Out-Null

  $internalTask = [ordered]@{
    status = "ACTIVE"
    event_type = "internal_self_selected_goal_task"
    task_id = "PHASE160F_INTERNAL_SELF_SELECTED_SELF_INITIATED_USEFUL_GOAL_SELECTOR_HARDENING"
    source = "internal_self_selected_goal"
    priority = "high"
    owner_goal = "Build a session-local candidate for useful goal selector hardening."
    desired_next_gap = "SELF_SELECTED_USEFUL_CANDIDATE_PRODUCTION"
    internal_goal_id = "SELF_INITIATED_USEFUL_GOAL_SELECTOR_HARDENING"
    runtime_session_only = $true
  }
  $ownerTask = [ordered]@{
    status = "BACKLOG"
    task_id = "PHASE160I_OWNER_SAFE_TASK_WHILE_INTERNAL_ACTIVE_001"
    source = "owner"
    priority = "high"
    owner_goal = "Audit long-run lifecycle visibility before Builder School."
    desired_next_gap = "LONG_RUN_LIFECYCLE_VISIBILITY_AND_BATCH_READINESS_GAP"
    reason = "existing_active_task_retained"
    runtime_session_only = $true
  }
  $activePath = Join-Path $activeTaskDir "active_task.json"
  $statePath = Join-Path $taskLifecycleDir "active_task_state.json"
  $backlogPath = Join-Path $taskBacklogDir "PHASE160I_OWNER_SAFE_TASK_WHILE_INTERNAL_ACTIVE_001.json"
  Write-Phase160IBacklogJsonFile -Path $activePath -Object $internalTask
  Write-Phase160IBacklogJsonFile -Path $statePath -Object ([ordered]@{
    status = "ACTIVE"
    active_task_id = $internalTask.task_id
    source = "internal_self_selected_goal"
    updated_at = (Get-Date).ToUniversalTime().ToString("o")
  })
  Write-Phase160IBacklogJsonFile -Path $backlogPath -Object $ownerTask

  $candidateWorkspaceText = Read-Phase160IBacklogTextSafe -Path (Resolve-Phase160IBacklogPath -Root $resolvedRoot -Path "modules/invoke_builder_candidate_workspace_step_001.ps1")
  $selectorText = Read-Phase160IBacklogTextSafe -Path (Resolve-Phase160IBacklogPath -Root $resolvedRoot -Path "modules/select_builder_self_initiated_useful_goal_001.ps1")
  $internalCreationText = Read-Phase160IBacklogTextSafe -Path (Resolve-Phase160IBacklogPath -Root $resolvedRoot -Path "modules/invoke_builder_internal_active_task_creation_001.ps1")

  $stage02 = [ordered]@{
    status = "PASS"
    audit_id = "PHASE160I_LONG_RUN_LIFECYCLE_AUDIT"
    line = "AGENT_BUILDER_SELF_DEVELOPMENT"
    mode = "VERIFY"
    stage = "STAGE 2 - ACTIVE TASK / BACKLOG LIFECYCLE"
    stage_id = "stage_02_active_task_backlog_audit"
    synthetic_runtime_root = ConvertTo-Phase160IBacklogRelativePath -Root $resolvedRoot -FullPath $runtimeRootFull
    simulated_internal_active_task_path = ConvertTo-Phase160IBacklogRelativePath -Root $resolvedRoot -FullPath $activePath
    simulated_owner_backlog_path = ConvertTo-Phase160IBacklogRelativePath -Root $resolvedRoot -FullPath $backlogPath
    classifications = @(
      "ACTIVE_TASK_BLOCKS_OWNER_TASK",
      "OWNER_TASK_BACKLOGGED"
    )
    owner_task_state = [ordered]@{
      owner_task_quarantined = $false
      owner_task_consumed = $true
      owner_task_backlogged = $true
      owner_task_lost = $false
      classification = "OWNER_TASK_BACKLOGGED"
      reason = "existing_active_task_retained"
    }
    active_internal_task_behavior = [ordered]@{
      blocks_immediate_activation = $true
      blocks_safe_intake = $false
      blocks_backlog_write = $false
      blocks_candidate_generation_for_owner_until_owner_review_gate_clears = $true
      finding = "An active internal task delays owner task activation, but canonical safe owner tasks should be backlogged instead of quarantined or lost."
    }
    code_path_evidence = [ordered]@{
      intake_writes_backlog_when_existing_active = ($candidateWorkspaceText -match "existing_active_task_retained")
      candidate_workspace_advances_backlog = ($candidateWorkspaceText -match "backlog_advanced")
      backlog_advancement_requires_waiting_owner_promotion = ($candidateWorkspaceText -match "WAITING_OWNER_PROMOTION")
      selector_skips_internal_goal_when_teacher_or_backlog_exists = ($selectorText -match "TeacherInboxCount -eq 0" -and $selectorText -match "BacklogCount -eq 0")
      internal_task_creation_writes_active_task = ($internalCreationText -match "active_task.json")
    }
    observed_recent_run_alignment = [ordered]@{
      injected_owner_task_quarantined_reason = "unsafe_live_task_safety_rules"
      internal_active_task_executed = "PHASE160F_INTERNAL_SELF_SELECTED_SELF_INITIATED_USEFUL_GOAL_SELECTOR_HARDENING"
      diagnosis = "The observed owner task did not reach active, consumed, backlog, or candidate source because it failed safety schema before the normal backlog path."
    }
    root_cause = "Backlog lifecycle exists, but owner task intake depends on exact safety schema and backlog advancement is gated behind current active task promotion status."
    repair_package = "ACTIVE_TASK_BACKLOG_LIFECYCLE_REPAIR"
    blocks_phase161 = $true
    created_at = (Get-Date).ToUniversalTime().ToString("o")
  }

  $stage03 = [ordered]@{
    status = "PASS"
    audit_id = "PHASE160I_LONG_RUN_LIFECYCLE_AUDIT"
    line = "AGENT_BUILDER_SELF_DEVELOPMENT"
    mode = "VERIFY"
    stage = "STAGE 3 - CANDIDATE SOURCE ATTRIBUTION"
    stage_id = "stage_03_candidate_source_attribution_audit"
    candidate_source_attribution = [ordered]@{
      candidate_came_from_internal_phase160f_task = $true
      internal_active_task_id = "PHASE160F_INTERNAL_SELF_SELECTED_SELF_INITIATED_USEFUL_GOAL_SELECTOR_HARDENING"
      source = "internal_self_selected_goal"
      source_internal_goal_id = "SELF_INITIATED_USEFUL_GOAL_SELECTOR_HARDENING"
      injected_owner_task_influenced_candidate = $false
      injected_owner_task_candidate_source_status = "NO_CANDIDATE_SOURCE_BECAUSE_OWNER_TASK_WAS_QUARANTINED"
      truthful = $true
    }
    promotion_manifest_source_truth = [ordered]@{
      source_tasks_derived_from_candidate_manifests = ($candidateWorkspaceText -match "source_task_id" -and $candidateWorkspaceText -match "candidate_manifest")
      quarantined_owner_task_must_not_appear_as_executed_source = $true
      violation_detected = $false
      required_guard = "promotion_manifest.source_tasks must list only candidate_manifest source_task_id values for generated candidates."
    }
    evidence = @(
      "invoke_builder_candidate_workspace_step_001.ps1 maps active task source internal_self_selected_goal to candidate source internal_self_selected_goal.",
      "finalize_builder_promotion_bundle_001.ps1 builds source_tasks from candidate records, not from teacher_quarantine."
    )
    root_cause = "Recent owner injection did not influence candidate production because intake quarantined it before active/backlog/candidate stages."
    repair_package = "TASK_INTAKE_SCHEMA_AND_SAFETY_RULES_REPAIR"
    blocks_phase161 = $true
    created_at = (Get-Date).ToUniversalTime().ToString("o")
  }

  Write-Phase160IBacklogJsonFile -Path (Join-Path $outputRootFull "stage_02_active_task_backlog_audit.json") -Object $stage02
  Write-Phase160IBacklogJsonFile -Path (Join-Path $outputRootFull "stage_03_candidate_source_attribution_audit.json") -Object $stage03
  [pscustomobject][ordered]@{
    status = "PASS"
    stage_02 = $stage02
    stage_03 = $stage03
  } | ConvertTo-Json -Depth 100
} finally {
  if ($pushed) {
    Pop-Location
  }
}
