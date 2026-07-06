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

function Invoke-OperationTrialAwareSelfModelAdvance {
  param(
    [string]$RepoRoot,
    [string]$RunId,
    $Entry,
    $ReadinessGate,
    [string]$OutputRoot
  )

  Push-Location $RepoRoot

  try {
    if (-not (Test-Path $OutputRoot)) {
      New-Item -ItemType Directory -Force -Path $OutputRoot | Out-Null
    }

    $SelfModelPath = "self_model/BUILDER_SELF_MODEL.json"
    $SelfModel = Read-JsonOptional $SelfModelPath
    $Gate = Read-JsonOptional "self_control/SELF_BUILD_OPERATION_READINESS_GATE.json"
    $Contract = Read-JsonOptional "self_control/SELF_BUILD_OPERATION_CONTRACT.json"
    $P130 = Read-JsonOptional "proofs/self_development/PHASE130_BUILD_SELF_BUILD_OPERATION_READINESS_GATE_V1.json"
    $P131 = Read-JsonOptional "proofs/self_development/PHASE131_RUN_CONTRACT_GOVERNED_SELF_BUILD_OPERATION_TRIAL_V1.json"

    $status = "BLOCKED"
    $closedNeed = ""
    $currentNeed = "NEED_OPERATION_TRIAL_AWARE_SELF_MODEL_REVIEW"
    $nextStep = "PHASE133_REVIEW_OPERATION_TRIAL_AWARE_SELF_MODEL_INPUTS_V1"
    $reason = ""

    if (
      $Entry.status -eq "PASS" -and
      $Entry.current_need -eq "NEED_SELF_BUILD_OPERATION_READINESS_GATE" -and
      $ReadinessGate.status -eq "PASS" -and
      $ReadinessGate.decision -eq "READY_FOR_CONTRACT_GOVERNED_SELF_BUILD_OPERATION_TRIAL" -and
      $SelfModel.status -eq "PASS" -and
      $SelfModel.current_detected_need -eq "NEED_SELF_BUILD_OPERATION_READINESS_GATE" -and
      $Gate.status -eq "PASS" -and
      $Contract.status -eq "PASS" -and
      $P130.status -eq "PASS" -and
      $P131.status -eq "PASS" -and
      $P131.classification -eq "CONTRACT_GOVERNED_SELF_BUILD_OPERATION_TRIAL_PASS"
    ) {
      $status = "PASS"
      $closedNeed = "NEED_SELF_BUILD_OPERATION_READINESS_GATE"
      $currentNeed = "NEED_SELF_BUILD_OPERATION_CAPABILITY_SELECTOR"
      $nextStep = "PHASE133_BUILD_SELF_BUILD_OPERATION_CAPABILITY_SELECTOR_V1"
      $reason = "PHASE131 proved one bounded contract-governed self-build operation trial. Self-model can close readiness gate need and move to selecting the first real operational self-build capability."
    } else {
      $reason = "Entry, readiness gate, self-model, contract, PHASE130 proof, or PHASE131 proof is missing/unexpected."
    }

    $oldClosed = @()
    if ($null -ne $SelfModel -and $null -ne $SelfModel.closed_needs) { $oldClosed = @($SelfModel.closed_needs) }
    $closedNeeds = @($oldClosed + $closedNeed | Where-Object { $_ -and $_.Trim() -ne "" } | Sort-Object -Unique)

    $oldCaps = @()
    if ($null -ne $SelfModel -and $null -ne $SelfModel.proven_capabilities) { $oldCaps = @($SelfModel.proven_capabilities) }

    $Capabilities = @($oldCaps)
    $Capabilities += [ordered]@{ id = "SELF_BUILD_OPERATION_READINESS_GATE"; status = if ($P130.status -eq "PASS") { "PROVEN" } else { "UNKNOWN" }; proof = "PHASE130_BUILD_SELF_BUILD_OPERATION_READINESS_GATE_V1" }
    $Capabilities += [ordered]@{ id = "CONTRACT_GOVERNED_SELF_BUILD_OPERATION_TRIAL"; status = if ($P131.status -eq "PASS") { "PROVEN" } else { "UNKNOWN" }; proof = "PHASE131_RUN_CONTRACT_GOVERNED_SELF_BUILD_OPERATION_TRIAL_V1" }

    $UpdatedSelfModel = [ordered]@{
      status = $status
      self_model_id = "BUILDER_SELF_MODEL_V5_OPERATION_TRIAL_AWARE"
      updated_by = "OPERATION_TRIAL_AWARE_SELF_MODEL_ADVANCE_V1"
      run_id = $RunId
      active_line = "AGENT_BUILDER / SELF_BUILD"
      identity = "primitive_brain_cell_with_hands"
      local_first = $true
      external_brain_dependency = $false
      current_state_summary = "Builder passed one contract-governed self-build operation trial. Next need is a selector for the first real operational self-build capability."
      proven_capabilities = $Capabilities
      closed_needs = $closedNeeds
      current_detected_need = $currentNeed
      current_missing_capability = "SELF_BUILD_OPERATION_CAPABILITY_SELECTOR"
      recommended_next_step = $nextStep
      operation_trial_aware = $true
      source_phase131_classification = if ($null -ne $P131) { $P131.classification } else { "__MISSING__" }
      autonomy_claimed = $false
      codex_used = $false
      main_touched = $false
    }

    Write-JsonFile $SelfModelPath $UpdatedSelfModel 30

    $Output = [ordered]@{
      status = $status
      engine_name = "OPERATION_TRIAL_AWARE_SELF_MODEL_ADVANCE_V1"
      run_id = $RunId
      self_model_path = $SelfModelPath
      self_model_updated = ($status -eq "PASS")
      closed_need = $closedNeed
      current_detected_need = $currentNeed
      proposed_next_step = $nextStep
      reason = $reason
      queue_mutated = $false
      autonomy_claimed = $false
      codex_used = $false
      main_touched = $false
    }

    $OutputPath = Join-Path $OutputRoot "OPERATION_TRIAL_AWARE_SELF_MODEL_ADVANCE_OUTPUT.json"
    Write-JsonFile $OutputPath $Output 20
    $Output["output_path"] = $OutputPath

    return [pscustomobject]$Output
  } finally {
    Pop-Location
  }
}
