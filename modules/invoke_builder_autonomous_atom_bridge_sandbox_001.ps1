param(
  [string]$RepoRoot = ".",
  [string]$SessionRoot,
  [string]$RunId = "",
  [string]$LegacyHead = "f55652d",
  [string]$BridgeRunId = "",
  [switch]$AllowBridgeModuleWorktreeChange
)

$ErrorActionPreference = "Stop"

function Write-BridgeJsonFile {
  param(
    [string]$Path,
    [object]$Object,
    [int]$Depth = 40
  )

  $dir = Split-Path -Path $Path -Parent
  if ($dir -and -not (Test-Path -LiteralPath $dir)) {
    New-Item -ItemType Directory -Force -Path $dir | Out-Null
  }

  $Object | ConvertTo-Json -Depth $Depth | Set-Content -LiteralPath $Path -Encoding UTF8
}

function Get-BridgeTrackedDirty {
  param(
    [string]$RepoRoot,
    [string[]]$AllowedNonRuntimeStatusPatterns = @()
  )

  $status = @(git -C $RepoRoot status --porcelain)
  $blocking = @()

  foreach ($line in $status) {
    if ($line -match '^\?\? runtime_sessions/' -or $line -match '^\?\? runtime_sessions\\') {
      continue
    }

    $allowed = $false
    foreach ($pattern in $AllowedNonRuntimeStatusPatterns) {
      if ($line -match $pattern) {
        $allowed = $true
        break
      }
    }

    if (-not $allowed) {
      $blocking += $line
    }
  }

  return $blocking.Count -gt 0
}

function Invoke-BuilderAutonomousAtomBridgeSandbox001 {
  param(
    [string]$RepoRoot = ".",
    [string]$SessionRoot,
    [string]$RunId = "",
    [string]$LegacyHead = "f55652d",
    [string]$BridgeRunId = ""
  )

  $RepoRootFull = [System.IO.Path]::GetFullPath($RepoRoot)

  if (-not (Test-Path -LiteralPath $RepoRootFull)) {
    throw "BRIDGE_REPO_ROOT_NOT_FOUND=$RepoRootFull"
  }

  if ([string]::IsNullOrWhiteSpace($SessionRoot)) {
    throw "BRIDGE_SESSION_ROOT_REQUIRED"
  }

  if ([string]::IsNullOrWhiteSpace($RunId)) {
    $RunId = "ATOM_BRIDGE_MODULE_" + (Get-Date -Format "yyyyMMdd_HHmmss")
  }

  if ([string]::IsNullOrWhiteSpace($BridgeRunId)) {
    $BridgeRunId = "PHASE154_BRIDGE_SANDBOX_REUSE_" + (Get-Date -Format "yyyyMMdd_HHmmss")
  }

  $SessionRootFull = [System.IO.Path]::GetFullPath((Join-Path $RepoRootFull $SessionRoot))
  New-Item -ItemType Directory -Force -Path $SessionRootFull | Out-Null

  $SandboxRepo = Join-Path $SessionRootFull "r"
  $RunLog = Join-Path $SessionRootFull "bounded_runtime_stdout_stderr.txt"
  $BridgeResultPath = Join-Path $SessionRootFull "bridge_result.json"
  $AtomSummaryPath = Join-Path $SessionRootFull "atom_candidate_summary.json"

  $Branch = (git -C $RepoRootFull branch --show-current).Trim()
  $Head = (git -C $RepoRootFull rev-parse --short HEAD).Trim()
  $Remote = (git -C $RepoRootFull rev-parse --short "origin/$Branch").Trim()

  if ($Head -ne $Remote) {
    throw "BRIDGE_HEAD_REMOTE_MISMATCH head=$Head remote=$Remote"
  }

  $AllowedDirtyPatterns = @()
  if ($AllowBridgeModuleWorktreeChange) {
    $AllowedDirtyPatterns += '^\?\? modules[\\/]invoke_builder_autonomous_atom_bridge_sandbox_001\.ps1$'
    $AllowedDirtyPatterns += '^.M modules[\\/]invoke_builder_autonomous_atom_bridge_sandbox_001\.ps1$'
    $AllowedDirtyPatterns += '^M. modules[\\/]invoke_builder_autonomous_atom_bridge_sandbox_001\.ps1$'
  }

  $MainTrackedDirtyBefore = Get-BridgeTrackedDirty -RepoRoot $RepoRootFull -AllowedNonRuntimeStatusPatterns $AllowedDirtyPatterns
  if ($MainTrackedDirtyBefore) {
    throw "BRIDGE_MAIN_REPO_TRACKED_DIRTY_BEFORE"
  }

  if (Test-Path -LiteralPath $SandboxRepo) {
    throw "BRIDGE_SANDBOX_REPO_ALREADY_EXISTS=$SandboxRepo"
  }

  git clone --quiet --local --no-hardlinks $RepoRootFull $SandboxRepo 2>$null | Out-Null
  if ($LASTEXITCODE -ne 0) {
    throw "BRIDGE_SANDBOX_CLONE_FAILED"
  }

  git -C $SandboxRepo checkout --quiet $Branch 2>$null | Out-Null
  if ($LASTEXITCODE -ne 0) {
    throw "BRIDGE_SANDBOX_CHECKOUT_FAILED"
  }

  git -C $SandboxRepo reset --quiet --hard $LegacyHead 2>$null | Out-Null
  if ($LASTEXITCODE -ne 0) {
    throw "BRIDGE_SANDBOX_RESET_FAILED=$LegacyHead"
  }

  $OverlayFiles = @(
    "modules/invoke_builder_bounded_self_growth_duty_loop_trial_001.ps1",
    "validators/validate_phase154_builder_bounded_self_growth_duty_loop_trial_v1.ps1",
    "route_change_requests/PHASE154_BOUNDED_SELF_GROWTH_DUTY_LOOP_TRIAL_ALIGNMENT_REQUEST.md"
  )

  foreach ($rel in $OverlayFiles) {
    $src = Join-Path $RepoRootFull $rel
    $dst = Join-Path $SandboxRepo $rel

    if (-not (Test-Path -LiteralPath $src)) {
      throw "BRIDGE_OVERLAY_SOURCE_MISSING=$rel"
    }

    New-Item -ItemType Directory -Force -Path (Split-Path $dst -Parent) | Out-Null
    Copy-Item -Force -LiteralPath $src -Destination $dst
  }

  $ModuleInSandbox = Join-Path $SandboxRepo "modules/invoke_builder_bounded_self_growth_duty_loop_trial_001.ps1"

  $runtimeOutput = @(pwsh -NoProfile -ExecutionPolicy Bypass -File $ModuleInSandbox -RepoRoot $SandboxRepo -RunId $BridgeRunId 2>&1 | ForEach-Object { [string]$_ })
  $runtimeExit = $LASTEXITCODE
  $runtimeOutput | Set-Content -LiteralPath $RunLog -Encoding UTF8

  if ($runtimeExit -ne 0) {
    $failure = [ordered]@{
      status = "FAIL"
      bridge_id = $RunId
      reason = "BOUNDED_RUNTIME_FAILED_IN_SANDBOX_OVERLAY"
      runtime_exit = $runtimeExit
      log_path = $RunLog
      created_at = (Get-Date).ToUniversalTime().ToString("o")
    }
    Write-BridgeJsonFile -Path $BridgeResultPath -Object $failure
    return [pscustomobject]$failure
  }

  $SandboxResult = Join-Path $SandboxRepo "self_control/BUILDER_BOUNDED_SELF_GROWTH_DUTY_LOOP_TRIAL_RESULT.json"
  $SandboxProof = Join-Path $SandboxRepo "proofs/self_development/PHASE154_BUILDER_BOUNDED_SELF_GROWTH_DUTY_LOOP_TRIAL_V1.json"
  $SandboxTrialRoot = Join-Path $SandboxRepo "living_learning_environment/self_growth_cycles/$BridgeRunId"
  $SandboxSkillIndex = Join-Path $SandboxTrialRoot "learned_skill_candidates_index.json"
  $SandboxStop = Join-Path $SandboxTrialRoot "runtime_stop_decision.json"

  foreach ($required in @($SandboxResult,$SandboxProof,$SandboxTrialRoot,$SandboxSkillIndex,$SandboxStop)) {
    if (-not (Test-Path -LiteralPath $required)) {
      throw "BRIDGE_MISSING_SANDBOX_OUTPUT=$required"
    }
  }

  $result = Get-Content -LiteralPath $SandboxResult -Raw | ConvertFrom-Json
  $proof = Get-Content -LiteralPath $SandboxProof -Raw | ConvertFrom-Json
  $skillIndex = Get-Content -LiteralPath $SandboxSkillIndex -Raw | ConvertFrom-Json
  $stop = Get-Content -LiteralPath $SandboxStop -Raw | ConvertFrom-Json

  $mainTrackedDirtyAfter = Get-BridgeTrackedDirty -RepoRoot $RepoRootFull -AllowedNonRuntimeStatusPatterns $AllowedDirtyPatterns

  $freshOutputs = (
    $result.run_id -eq $BridgeRunId -and
    $proof.run_id -eq $BridgeRunId -and
    $skillIndex.run_id -eq $BridgeRunId -and
    $stop.run_id -eq $BridgeRunId
  )

  $bridgePass = (
    $freshOutputs -and
    $result.status -eq "PASS" -and
    $result.bounded_self_growth_trial_proven -eq $true -and
    $result.all_cycles_validated -eq $true -and
    $result.safe_stop -eq $true -and
    $skillIndex.skill_candidate_count -eq 3 -and
    $stop.safe_stop -eq $true -and
    $result.accepted_state_mutated -eq $false -and
    $result.accepted_memory_mutated -eq $false -and
    $result.accepted_self_model_mutated -eq $false -and
    -not $mainTrackedDirtyAfter
  )

  $bridgeResult = [ordered]@{
    status = if ($bridgePass) { "PASS" } else { "REVIEW_REQUIRED" }
    bridge_id = $RunId
    mode = "legacy_head_with_phase154_overlay_sandbox_reuse"
    main_repo_head = $Head
    main_repo_remote = $Remote
    sandbox_branch = (git -C $SandboxRepo branch --show-current)
    sandbox_head = (git -C $SandboxRepo rev-parse --short HEAD)
    overlay_files_used = $OverlayFiles
    bridge_run_id = $BridgeRunId
    fresh_outputs_match_bridge_run_id = $freshOutputs
    bounded_runtime_result_status = $result.status
    bounded_self_growth_trial_proven = $result.bounded_self_growth_trial_proven
    cycle_count = $result.cycle_count
    all_cycles_validated = $result.all_cycles_validated
    safe_stop = $result.safe_stop
    skill_candidate_count = $skillIndex.skill_candidate_count
    final_next_growth_goal = $stop.final_next_growth_goal
    accepted_state_mutated = $result.accepted_state_mutated
    accepted_memory_mutated = $result.accepted_memory_mutated
    accepted_self_model_mutated = $result.accepted_self_model_mutated
    main_repo_tracked_dirty_after = $mainTrackedDirtyAfter
    direct_main_repo_runtime_call_used = $false
    promotion_allowed = $false
    accepted_atom_claimed = $false
    bridge_result_path = $BridgeResultPath
    atom_candidate_summary_path = $AtomSummaryPath
    created_at = (Get-Date).ToUniversalTime().ToString("o")
  }

  Write-BridgeJsonFile -Path $BridgeResultPath -Object $bridgeResult

  $candidates = @($skillIndex.skill_candidates | ForEach-Object {
    [ordered]@{
      cycle_id = $_.cycle_id
      skill_id = $_.skill_id
      selected_goal = $_.selected_goal
      validation_status = $_.validation_status
      sandbox_path = $_.path
    }
  })

  $atomSummary = [ordered]@{
    status = "SANDBOX_ATOM_CANDIDATE_NOT_ACCEPTED"
    bridge_id = $RunId
    source_runtime = "PHASE154_BOUNDED_SELF_GROWTH_DUTY_LOOP_TRIAL"
    skill_candidate_count = $skillIndex.skill_candidate_count
    skill_candidates = $candidates
    runtime_stop_safe = $stop.safe_stop
    stop_reason = $stop.stop_reason
    final_next_growth_goal = $stop.final_next_growth_goal
    memory_proof = "candidate_only_sandbox_outputs"
    use_proof = "skill_validation_result_PASS_inside_sandbox"
    behavior_delta = "not_accepted_not_promoted"
    accepted_memory_mutated = $false
    accepted_state_mutated = $false
    accepted_self_model_mutated = $false
    accepted_atom_claimed = $false
    next_required_step = "connect_live_daemon_autonomous_growth_hook_after_module_regression"
    created_at = (Get-Date).ToUniversalTime().ToString("o")
  }

  Write-BridgeJsonFile -Path $AtomSummaryPath -Object $atomSummary

  return [pscustomobject]$bridgeResult
}

Invoke-BuilderAutonomousAtomBridgeSandbox001 `
  -RepoRoot $RepoRoot `
  -SessionRoot $SessionRoot `
  -RunId $RunId `
  -LegacyHead $LegacyHead `
  -BridgeRunId $BridgeRunId `
  -AllowBridgeModuleWorktreeChange:$AllowBridgeModuleWorktreeChange


