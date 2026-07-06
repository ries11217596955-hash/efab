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

function Invoke-SelfModelAwareDecisionLoop {
  param([string]$RepoRoot, [string]$RunId, [string]$OutputRoot)
  Push-Location $RepoRoot
  try {
    if (-not (Test-Path $OutputRoot)) { New-Item -ItemType Directory -Force -Path $OutputRoot | Out-Null }
    $SelfModelPath = "self_model/BUILDER_SELF_MODEL.json"
    $SelfModel = Read-JsonOptional $SelfModelPath
    $P118 = Read-JsonOptional "proofs/self_development/PHASE118_BUILD_SELF_MODEL_UPDATE_ENGINE_V1.json"
    $status = "BLOCKED"; $decisionId = ""; $detectedNeed = ""; $nextStep = "PHASE120_BUILD_AUTONOMOUS_LOOP_CONTROLLER_V1"; $reason = ""
    if ($null -eq $SelfModel) {
      $status = "BLOCKED"; $decisionId = "DECISION_REPAIR_SELF_MODEL_MISSING_V1"; $detectedNeed = "NEED_SELF_MODEL_REPAIR"; $nextStep = "PHASE120_REPAIR_SELF_MODEL_MISSING_V1"; $reason = "Self-model is missing or unreadable."
    } elseif ($SelfModel.status -eq "PASS" -and $SelfModel.current_detected_need -eq "NEED_SELF_MODEL_AWARE_DECISION_LOOP" -and $P118.status -eq "PASS") {
      $status = "PASS"; $decisionId = "DECISION_BUILD_AUTONOMOUS_LOOP_CONTROLLER_V1"; $detectedNeed = "NEED_AUTONOMOUS_LOOP_CONTROLLER"; $nextStep = "PHASE120_BUILD_AUTONOMOUS_LOOP_CONTROLLER_V1"; $reason = "Self-model says the next missing capability is a decision loop. This loop now reads the self-model and selects the next controller-building move."
    } else {
      $status = "BLOCKED"; $decisionId = "DECISION_REVIEW_SELF_MODEL_STATE_V1"; $detectedNeed = "NEED_SELF_MODEL_STATE_REVIEW"; $nextStep = "PHASE120_REVIEW_SELF_MODEL_DECISION_INPUTS_V1"; $reason = "Self-model state is unexpected for PHASE119."
    }
    $Output = [ordered]@{
      status = $status
      engine_name = "SELF_MODEL_AWARE_DECISION_LOOP_V1"
      run_id = $RunId
      self_model_path = $SelfModelPath
      self_model_status = if ($null -ne $SelfModel) { $SelfModel.status } else { "__MISSING__" }
      self_model_source_need = if ($null -ne $SelfModel) { $SelfModel.current_detected_need } else { "__MISSING__" }
      decision_id = $decisionId
      selected_need_id = $detectedNeed
      selected_action_kind = "BUILD_NEXT_CAPABILITY"
      selected_target_capability = "AUTONOMOUS_LOOP_CONTROLLER"
      proposed_next_step = $nextStep
      reason = $reason
      queue_mutated = $false
      manual_active_task_seed = $false
      autonomy_claimed = $false
      codex_used = $false
      main_touched = $false
    }
    $OutputPath = Join-Path $OutputRoot "SELF_MODEL_AWARE_DECISION_LOOP_OUTPUT.json"
    Write-JsonFile $OutputPath $Output 20
    $Output["output_path"] = $OutputPath
    return [pscustomobject]$Output
  } finally { Pop-Location }
}
