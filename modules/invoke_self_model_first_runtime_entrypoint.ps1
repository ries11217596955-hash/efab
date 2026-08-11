function Read-JsonOptional {
  param([string]$Path)
  if (-not (Test-Path $Path)) { return $null }
  try { return Get-Content $Path -Raw | ConvertFrom-Json } catch { return $null }
}

function Write-JsonFile {
  param($Path, $Object, [int]$Depth = 20)
  $dir = Split-Path $Path -Parent
  if ($dir -and -not (Test-Path $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
  $Object | ConvertTo-Json -Depth $Depth | Set-Content -Path $Path -Encoding UTF8
}

function Invoke-SelfModelFirstRuntimeEntrypoint {
  param(
    [string]$RepoRoot,
    [string]$RunId,
    [string]$OutputRoot
  )

  Push-Location $RepoRoot

  try {
    if (-not (Test-Path $OutputRoot)) {
      New-Item -ItemType Directory -Force -Path $OutputRoot | Out-Null
    }

    $Queue = Read-JsonOptional "TASK_QUEUE.json"
    $SelfModel = Read-JsonOptional "self_model/BUILDER_SELF_MODEL.json"
    $Controller = Read-JsonOptional "self_control/AUTONOMOUS_LOOP_CONTROLLER.json"
    $P123 = Read-JsonOptional "proofs/self_development/PHASE123_RUN_CONTROLLER_GOVERNED_SELF_BUILD_TRIAL_V1.json"
    $P131 = Read-JsonOptional "proofs/self_development/PHASE131_RUN_CONTRACT_GOVERNED_SELF_BUILD_OPERATION_TRIAL_V1.json"
    $P132 = Read-JsonOptional "proofs/self_development/PHASE132_BUILD_OPERATION_TRIAL_AWARE_SELF_MODEL_ADVANCE_V1.json"
    $CurrentState = Read-JsonOptional "self_control/CURRENT_AGENT_BUILDER_STATE.json"
    $NextAction = Read-JsonOptional "self_control/NEXT_ACTION.json"
    $ProofPointer = Read-JsonOptional "self_control/LAST_ACCEPTED_PROOF_POINTER.json"
    $ActiveRouteLock = Read-JsonOptional "route_locks/ACTIVE_ROUTE_LOCK.json"

    $CurrentBranch = ""
    $CurrentHead = ""
    try { $CurrentBranch = (& git branch --show-current 2>$null | Select-Object -First 1).Trim() } catch {}
    try { $CurrentHead = (& git rev-parse HEAD 2>$null | Select-Object -First 1).Trim() } catch {}

    $ActiveRouteFile = if ($null -ne $ActiveRouteLock -and $ActiveRouteLock.PSObject.Properties.Name -contains "active_route_lock_file") { [string]$ActiveRouteLock.active_route_lock_file } else { "" }
    $ActiveRouteBaseline = if ($null -ne $ActiveRouteLock -and $ActiveRouteLock.PSObject.Properties.Name -contains "route_baseline_head") { [string]$ActiveRouteLock.route_baseline_head } else { "" }
    $ActiveRouteTarget = if ($null -ne $ActiveRouteLock -and $ActiveRouteLock.PSObject.Properties.Name -contains "next_target_phase") { [string]$ActiveRouteLock.next_target_phase } else { "" }
    $ActiveRouteBaselineValid = $false
    if ($ActiveRouteBaseline -ne "") {
      try {
        & git merge-base --is-ancestor $ActiveRouteBaseline HEAD 2>$null
        $ActiveRouteBaselineValid = ($LASTEXITCODE -eq 0)
      } catch { $ActiveRouteBaselineValid = $false }
    }
    $ActiveRouteValid = (
      $null -ne $ActiveRouteLock -and
      $ActiveRouteLock.active_route_lock_status -eq "ACTIVE_ROUTE_LOCK" -and
      $ActiveRouteFile -ne "" -and
      (Test-Path -LiteralPath $ActiveRouteFile) -and
      $ActiveRouteTarget -ne "" -and
      $ActiveRouteBaselineValid
    )

    $StateCapsulePresent = ($null -ne $CurrentState -or $null -ne $NextAction -or $null -ne $ProofPointer)
    $StateCapsuleConsistent = (
      $null -ne $CurrentState -and
      $null -ne $NextAction -and
      $null -ne $ProofPointer -and
      $CurrentState.status -eq "PASS" -and
      $NextAction.status -eq "PASS" -and
      $ProofPointer.status -eq "PASS" -and
      $CurrentState.next_allowed_step -eq $NextAction.next_allowed_step -and
      $CurrentState.next_allowed_step -eq $ProofPointer.next_allowed_step -and
      $CurrentState.last_accepted_proof -eq $ProofPointer.last_accepted_proof -and
      $CurrentState.pending_current_proof -eq $ProofPointer.pending_current_proof
    )
    $StateBranchMatches = ($null -ne $CurrentState -and $CurrentBranch -ne "" -and $CurrentState.branch -eq $CurrentBranch)
    $StateHeadMatches = ($null -ne $CurrentState -and $CurrentHead -ne "" -and $CurrentState.accepted_head -ne "" -and $CurrentHead.StartsWith([string]$CurrentState.accepted_head, [System.StringComparison]::OrdinalIgnoreCase))
    $StateProofsExist = (
      $null -ne $CurrentState -and
      $CurrentState.last_accepted_proof -ne "" -and
      $CurrentState.pending_current_proof -ne "" -and
      (Test-Path -LiteralPath $CurrentState.last_accepted_proof) -and
      (Test-Path -LiteralPath $CurrentState.pending_current_proof)
    )

    $status = "BLOCKED"
    $decisionId = ""
    $entryMode = ""
    $currentNeed = ""
    $nextStep = "PHASE125_RUN_SELF_MODEL_FIRST_CONTROLLER_GOVERNED_TRIAL_V1"
    $reason = ""

    if ($ActiveRouteValid) {
      $status = "BLOCKED"
      $decisionId = "ENTRY_BLOCKED_ACTIVE_ROUTE_NOT_WIRED_V1"
      $entryMode = "ACTIVE_ROUTE_EXECUTION_WIRING_STOP"
      $currentNeed = "NEED_ACTIVE_ROUTE_EXECUTION_WIRING"
      $nextStep = $ActiveRouteTarget
      $reason = "A valid active route lock exists and its baseline is an ancestor of current HEAD, but the orchestrator has no execution wiring for this route."
    } elseif ($StateCapsulePresent -and (-not $StateCapsuleConsistent -or -not $StateBranchMatches -or -not $StateHeadMatches -or -not $StateProofsExist)) {
      $status = "BLOCKED"
      $decisionId = "ENTRY_BLOCKED_STALE_STATE_CAPSULE_V1"
      $entryMode = "STATE_CAPSULE_RECONCILIATION_STOP"
      $currentNeed = "NEED_CURRENT_STATE_RECONCILIATION"
      $nextStep = "REBUILD_CURRENT_STATE_FROM_FRESH_REPO_RUNTIME_V1"
      $reason = "State capsule is incomplete, stale for the current branch or HEAD, or references missing proofs."
    } elseif ($null -eq $Queue -or $Queue.active_task_id -ne "NONE") {
      $status = "BLOCKED"
      $decisionId = "ENTRY_BLOCKED_QUEUE_NOT_READY_V1"
      $entryMode = "QUEUE_SAFETY_STOP"
      $currentNeed = "NEED_QUEUE_SAFETY_REVIEW"
      $nextStep = "PHASE125_REVIEW_ENTRYPOINT_QUEUE_STATE_V1"
      $reason = "Self-model-first entrypoint requires active_task_id NONE."
    } elseif (
      $null -ne $SelfModel -and
      $null -ne $Controller -and
      $SelfModel.status -eq "PASS" -and
      $Controller.status -eq "PASS" -and
      $SelfModel.current_detected_need -eq "NEED_CONTROLLER_GOVERNED_SELF_BUILD_TRIAL" -and
      $P123.status -eq "PASS"
    ) {
      $status = "PASS"
      $decisionId = "ENTRYPOINT_USE_SELF_MODEL_CURRENT_NEED_V1"
      $entryMode = "SELF_MODEL_FIRST_CONTROLLER_GOVERNED_TRIAL_READY"
      $currentNeed = "NEED_CONTROLLER_GOVERNED_SELF_BUILD_TRIAL"
      $nextStep = "PHASE125_RUN_SELF_MODEL_FIRST_CONTROLLER_GOVERNED_TRIAL_V1"
      $reason = "Self-model already records the current need. Runtime should enter through self-model first and avoid replaying prior organ-build path."
    } elseif (
      $null -ne $SelfModel -and
      $null -ne $Controller -and
      $SelfModel.status -eq "PASS" -and
      $Controller.status -eq "PASS" -and
      $SelfModel.current_detected_need -eq "NEED_SELF_BUILD_OPERATION_CONTRACT"
    ) {
      $status = "PASS"
      $decisionId = "ENTRYPOINT_USE_SELF_MODEL_OPERATION_CONTRACT_NEED_V1"
      $entryMode = "SELF_MODEL_FIRST_SELF_BUILD_OPERATION_CONTRACT_READY"
      $currentNeed = "NEED_SELF_BUILD_OPERATION_CONTRACT"
      $nextStep = "PHASE127_BUILD_SELF_BUILD_OPERATION_CONTRACT_V1"
      $reason = "Self-model already records the self-build operation contract need. Runtime should enter contract build without replaying prior routes."
    } elseif (
      $null -ne $SelfModel -and
      $null -ne $Controller -and
      $SelfModel.status -eq "PASS" -and
      $Controller.status -eq "PASS" -and
      $SelfModel.current_detected_need -eq "NEED_SELF_BUILD_OPERATION_READINESS_GATE"
    ) {
      $status = "PASS"
      $decisionId = "ENTRYPOINT_USE_SELF_MODEL_READINESS_GATE_NEED_V1"
      $entryMode = "SELF_MODEL_FIRST_SELF_BUILD_OPERATION_READINESS_GATE_READY"
      $currentNeed = "NEED_SELF_BUILD_OPERATION_READINESS_GATE"
      $nextStep = "PHASE130_BUILD_SELF_BUILD_OPERATION_READINESS_GATE_V1"
      $reason = "Self-model requests the self-build operation readiness gate. Runtime should build the gate without replaying old routes."
    } elseif (
      $null -ne $SelfModel -and
      $null -ne $Controller -and
      $SelfModel.status -eq "PASS" -and
      $Controller.status -eq "PASS" -and
      $SelfModel.current_detected_need -eq "NEED_SELF_BUILD_OPERATION_CAPABILITY_SELECTOR" -and
      ($null -eq $P131 -or $P131.status -ne "PASS" -or $null -eq $P132 -or $P132.status -ne "PASS")
    ) {
      $status = "BLOCKED"
      $decisionId = "ENTRY_BLOCKED_SELECTOR_PROOFS_MISSING_V1"
      $entryMode = "SELF_MODEL_PROOF_CONSISTENCY_STOP"
      $currentNeed = "NEED_SELF_MODEL_PROOF_CONSISTENCY_REVIEW"
      $nextStep = "PHASE133_REVIEW_SELF_MODEL_SELECTOR_PROOFS_V1"
      $reason = "Self-model requests the operation capability selector, but PHASE131 or PHASE132 proof is missing or not PASS."
    } elseif (
      $null -ne $SelfModel -and
      $null -ne $Controller -and
      $SelfModel.status -eq "PASS" -and
      $Controller.status -eq "PASS" -and
      $SelfModel.current_detected_need -eq "NEED_SELF_BUILD_OPERATION_CAPABILITY_SELECTOR" -and
      $null -ne $P131 -and
      $P131.status -eq "PASS" -and
      $null -ne $P132 -and
      $P132.status -eq "PASS"
    ) {
      $status = "PASS"
      $decisionId = "ENTRYPOINT_USE_SELF_MODEL_CAPABILITY_SELECTOR_NEED_V1"
      $entryMode = "SELF_MODEL_FIRST_SELF_BUILD_OPERATION_CAPABILITY_SELECTOR_READY"
      $currentNeed = "NEED_SELF_BUILD_OPERATION_CAPABILITY_SELECTOR"
      $nextStep = "PHASE133_BUILD_SELF_BUILD_OPERATION_CAPABILITY_SELECTOR_V1"
      $reason = "Self-model requests the operation capability selector and the required PHASE131 and PHASE132 proofs are PASS."
    } else {
      $status = "BLOCKED"
      $decisionId = "ENTRY_BLOCKED_SELF_MODEL_OR_CONTROLLER_UNEXPECTED_V1"
      $entryMode = "STATE_REVIEW"
      $currentNeed = "NEED_SELF_MODEL_ENTRYPOINT_REVIEW"
      $nextStep = "PHASE125_REVIEW_SELF_MODEL_FIRST_ENTRYPOINT_INPUTS_V1"
      $reason = "Self-model, controller, or PHASE123 proof is missing/unexpected."
    }

    $Output = [ordered]@{
      status = $status
      engine_name = "SELF_MODEL_FIRST_RUNTIME_ENTRYPOINT_V1"
      run_id = $RunId
      decision_id = $decisionId
      entry_mode = $entryMode
      current_need = $currentNeed
      proposed_next_step = $nextStep
      used_self_model_first = ($status -eq "PASS")
      replayed_controller_build_path = $false
      queue_mutated = $false
      reason = $reason
      autonomy_claimed = $false
      codex_used = $false
      main_touched = $false
    }

    $OutputPath = Join-Path $OutputRoot "SELF_MODEL_FIRST_RUNTIME_ENTRYPOINT_OUTPUT.json"
    Write-JsonFile $OutputPath $Output 20
    $Output["output_path"] = $OutputPath

    return [pscustomobject]$Output
  } finally {
    Pop-Location
  }
}



