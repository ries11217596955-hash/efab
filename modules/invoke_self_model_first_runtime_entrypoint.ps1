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

    $status = "BLOCKED"
    $decisionId = ""
    $entryMode = ""
    $currentNeed = ""
    $nextStep = "PHASE125_RUN_SELF_MODEL_FIRST_CONTROLLER_GOVERNED_TRIAL_V1"
    $reason = ""

    if ($null -eq $Queue -or $Queue.active_task_id -ne "NONE") {
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
      $SelfModel.current_detected_need -eq "NEED_SELF_BUILD_OPERATION_CAPABILITY_SELECTOR"
    ) {
      $status = "PASS"
      $decisionId = "ENTRYPOINT_USE_SELF_MODEL_CAPABILITY_SELECTOR_NEED_V1"
      $entryMode = "SELF_MODEL_FIRST_SELF_BUILD_OPERATION_CAPABILITY_SELECTOR_READY"
      $currentNeed = "NEED_SELF_BUILD_OPERATION_CAPABILITY_SELECTOR"
      $nextStep = "PHASE133_BUILD_SELF_BUILD_OPERATION_CAPABILITY_SELECTOR_V1"
      $reason = "Self-model requests the operation capability selector. Runtime should build the selector without replaying old routes."
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



