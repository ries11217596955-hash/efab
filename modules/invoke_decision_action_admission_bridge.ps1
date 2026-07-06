function Invoke-DecisionActionAdmissionBridge {
  param(
    [string]$RepoRoot,
    [string]$RunId,
    $Action,
    [string]$OutputRoot
  )

  Push-Location $RepoRoot

  try {
    if (-not (Test-Path $OutputRoot)) {
      New-Item -ItemType Directory -Force -Path $OutputRoot | Out-Null
    }

    $actionRequestPath = "$($Action.action_request_path)"
    if ([string]::IsNullOrWhiteSpace($actionRequestPath)) {
      throw "Action request path is empty."
    }

    if (-not (Test-Path $actionRequestPath)) {
      throw "Action request missing: $actionRequestPath"
    }

    $Request = Get-Content $actionRequestPath -Raw | ConvertFrom-Json

    $status = "BLOCKED"
    $admissionId = ""
    $admittedActionId = ""
    $reason = ""
    $nextStep = "PHASE114_BUILD_ADMITTED_ACTION_EXECUTION_ENGINE_V1"

    if (
      $Action.status -eq "PASS" -and
      $Request.status -eq "PASS" -and
      $Request.action_kind -eq "BUILD_NEXT_CAPABILITY" -and
      $Request.target_capability -eq "DECISION_ACTION_ADMISSION_BRIDGE" -and
      $Request.manual_active_task_seed -eq $false
    ) {
      $status = "PASS"
      $admissionId = "ADMISSION_DECISION_ACTION_BRIDGE_V1"
      $admittedActionId = "ADMITTED_ACTION_BUILD_EXECUTION_ENGINE_V1"
      $reason = "Action request is valid and can be admitted as the next self-build move. It is not executed in this phase."
    } else {
      $status = "BLOCKED"
      $admissionId = "ADMISSION_BLOCKED_REVIEW_ACTION_REQUEST_V1"
      $admittedActionId = ""
      $reason = "Action request did not satisfy admission criteria."
      $nextStep = "PHASE114_REVIEW_ACTION_ADMISSION_BLOCKER_V1"
    }

    $AdmissionRecord = [ordered]@{
      admission_id = $admissionId
      status = $status
      source_action_request_path = $actionRequestPath
      source_action_request_id = $Request.action_request_id
      source_decision_id = $Request.decision_id
      source_action_kind = $Request.action_kind
      source_target_capability = $Request.target_capability
      admitted_action_id = $admittedActionId
      admitted = ($status -eq "PASS")
      executed = $false
      queue_mutated = $false
      active_task_id_written = $false
      reason = $reason
      next_allowed_step = $nextStep
    }

    $AdmittedAction = [ordered]@{
      admitted_action_id = $admittedActionId
      status = $status
      action_kind = "BUILD_NEXT_CAPABILITY"
      source_admission_id = $admissionId
      source_action_request_path = $actionRequestPath
      target_capability = "ADMITTED_ACTION_EXECUTION_ENGINE"
      proposed_next_step = $nextStep
      requested_outcome = "Build the engine that can transform an admitted action into an executable self-build task/pack safely."
      acceptance_criteria = @(
        "reads admitted action record",
        "does not require manual active_task_id seed",
        "creates executable self-build move only after admission",
        "keeps queue safe",
        "does not claim full autonomy"
      )
      constraints = @(
        "do not touch main",
        "do not use Codex",
        "do not fetch internet materials",
        "do not install dependencies",
        "do not execute admitted action in PHASE113"
      )
      created_by_builder_runtime = $true
      executed = $false
      autonomy_claimed = $false
      codex_used = $false
    }

    $AdmissionRecordPath = Join-Path $OutputRoot "ACTION_ADMISSION_RECORD.json"
    $AdmittedActionPath = Join-Path $OutputRoot "ADMITTED_ACTION.json"
    $OutputPath = Join-Path $OutputRoot "DECISION_ACTION_ADMISSION_BRIDGE_OUTPUT.json"

    $AdmissionRecord | ConvertTo-Json -Depth 20 | Set-Content -Path $AdmissionRecordPath -Encoding UTF8
    $AdmittedAction | ConvertTo-Json -Depth 20 | Set-Content -Path $AdmittedActionPath -Encoding UTF8

    $BridgeOutput = [ordered]@{
      status = $status
      engine_name = "DECISION_ACTION_ADMISSION_BRIDGE_V1"
      run_id = $RunId
      admission_id = $admissionId
      admitted_action_id = $admittedActionId
      source_action_request_path = $actionRequestPath
      admission_record_path = $AdmissionRecordPath
      admitted_action_path = $AdmittedActionPath
      admitted = ($status -eq "PASS")
      executed = $false
      queue_mutated = $false
      active_task_id_written = $false
      proposed_next_step = $nextStep
      reason = $reason
      autonomy_claimed = $false
      codex_used = $false
    }

    $BridgeOutput | ConvertTo-Json -Depth 20 | Set-Content -Path $OutputPath -Encoding UTF8
    $BridgeOutput["output_path"] = $OutputPath

    return [pscustomobject]$BridgeOutput
  } finally {
    Pop-Location
  }
}
