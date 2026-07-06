function Invoke-DecisionToActionEngine {
  param(
    [string]$RepoRoot,
    [string]$RunId,
    $Need,
    [string]$OutputRoot
  )

  Push-Location $RepoRoot

  try {
    if (-not (Test-Path $OutputRoot)) {
      New-Item -ItemType Directory -Force -Path $OutputRoot | Out-Null
    }

    $status = "BLOCKED"
    $decisionId = ""
    $actionKind = ""
    $actionRequestPath = ""
    $reason = ""
    $nextStep = "PHASE113_BUILD_DECISION_ACTION_ADMISSION_BRIDGE_V1"

    if ($Need.status -eq "PASS" -and $Need.detected_need_id -eq "NEED_DECISION_TO_ACTION_ENGINE") {
      $status = "PASS"
      $decisionId = "DECISION_BUILD_DECISION_ACTION_ADMISSION_BRIDGE_V1"
      $actionKind = "BUILD_NEXT_CAPABILITY"
      $reason = "Self-need detection found that Builder cannot yet translate a detected need into an executable self-build action. The next honest action is to build the admission bridge."
    } else {
      $status = "BLOCKED"
      $decisionId = "DECISION_REVIEW_UNEXPECTED_NEED_STATE_V1"
      $actionKind = "STATE_REVIEW"
      $reason = "Need state is missing, blocked, or unexpected."
      $nextStep = "PHASE113_REVIEW_DECISION_TO_ACTION_INPUT_STATE_V1"
    }

    $ActionRequest = [ordered]@{
      action_request_id = "ACTION_REQUEST_FROM_SELF_NEED_${RunId}"
      status = $status
      decision_id = $decisionId
      action_kind = $actionKind
      source_engine = "SELF_NEED_DETECTION_ENGINE_V1"
      source_need_id = $Need.detected_need_id
      source_diagnosis = $Need.diagnosis
      source_missing_capability = $Need.missing_capability
      target_capability = "DECISION_ACTION_ADMISSION_BRIDGE"
      proposed_next_step = $nextStep
      requested_outcome = "Convert a self-diagnosed need into an admissible self-build task/pack without manual active_task_id seeding."
      acceptance_criteria = @(
        "action request is generated from self-need output",
        "active_task_id remains NONE during generation",
        "no manual pack priority change is required",
        "next phase can admit this action request safely",
        "no full autonomy is claimed"
      )
      constraints = @(
        "do not touch main",
        "do not use Codex",
        "do not fetch internet materials",
        "do not install dependencies",
        "do not fake PASS",
        "do not directly execute the requested action in this phase"
      )
      reason = $reason
      created_by_builder_runtime = $true
      manual_active_task_seed = $false
      autonomy_claimed = $false
      codex_used = $false
    }

    $actionRequestPath = Join-Path $OutputRoot "ACTION_REQUEST.json"
    $ActionRequest | ConvertTo-Json -Depth 20 | Set-Content -Path $actionRequestPath -Encoding UTF8

    $EngineOutput = [ordered]@{
      status = $status
      engine_name = "DECISION_TO_ACTION_ENGINE_V1"
      run_id = $RunId
      decision_id = $decisionId
      action_kind = $actionKind
      action_request_path = $actionRequestPath
      source_need_id = $Need.detected_need_id
      source_diagnosis = $Need.diagnosis
      proposed_next_step = $nextStep
      reason = $reason
      manual_active_task_seed = $false
      queue_mutated = $false
      autonomy_claimed = $false
      codex_used = $false
    }

    $OutputPath = Join-Path $OutputRoot "DECISION_TO_ACTION_ENGINE_OUTPUT.json"
    $EngineOutput | ConvertTo-Json -Depth 20 | Set-Content -Path $OutputPath -Encoding UTF8

    $EngineOutput["output_path"] = $OutputPath

    return [pscustomobject]$EngineOutput
  } finally {
    Pop-Location
  }
}
