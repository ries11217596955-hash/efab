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

function Invoke-ControllerAwareSelfModelUpdate {
  param([string]$RepoRoot, [string]$RunId, $Controller, [string]$OutputRoot)
  Push-Location $RepoRoot
  try {
    if (-not (Test-Path $OutputRoot)) { New-Item -ItemType Directory -Force -Path $OutputRoot | Out-Null }
    $SelfModelPath = "self_model/BUILDER_SELF_MODEL.json"
    $SelfModel = Read-JsonOptional $SelfModelPath
    $ControllerDoc = Read-JsonOptional "self_control/AUTONOMOUS_LOOP_CONTROLLER.json"
    $P120 = Read-JsonOptional "proofs/self_development/PHASE120_BUILD_AUTONOMOUS_LOOP_CONTROLLER_V1.json"
    $P121 = Read-JsonOptional "proofs/self_development/PHASE121_RUN_BOUNDED_AUTONOMOUS_LOOP_TRIAL_V1.json"
    $status = "BLOCKED"; $reason = ""; $currentNeed = "NEED_CONTROLLER_AWARE_SELF_MODEL_REVIEW"; $nextStep = "PHASE123_REVIEW_CONTROLLER_AWARE_SELF_MODEL_INPUTS_V1"
    if ($null -ne $SelfModel -and $Controller.status -eq "PASS" -and $Controller.controller_created -eq $true -and $ControllerDoc.status -eq "PASS" -and $P120.status -eq "PASS" -and $P121.status -eq "PASS" -and $P121.classification -eq "BOUNDED_LOOP_PASS_BUT_CONTROLLER_NEED_IS_STALE") {
      $status = "PASS"; $currentNeed = "NEED_CONTROLLER_GOVERNED_SELF_BUILD_TRIAL"; $nextStep = "PHASE123_RUN_CONTROLLER_GOVERNED_SELF_BUILD_TRIAL_V1"; $reason = "PHASE120 built the controller and PHASE121 proved bounded loop control. Self-model now closes NEED_AUTONOMOUS_LOOP_CONTROLLER and moves to a controller-governed self-build trial." 
    } else {
      $status = "BLOCKED"; $reason = "Controller, PHASE120 proof, PHASE121 proof, or self-model is missing/unexpected." 
    }
    $oldClosedNeeds = @()
    if ($null -ne $SelfModel -and $null -ne $SelfModel.closed_needs) { $oldClosedNeeds = @($SelfModel.closed_needs) }
    $closedNeeds = @($oldClosedNeeds + "NEED_AUTONOMOUS_LOOP_CONTROLLER" | Sort-Object -Unique)
    $oldCaps = @()
    if ($null -ne $SelfModel -and $null -ne $SelfModel.proven_capabilities) { $oldCaps = @($SelfModel.proven_capabilities) }
    $Capabilities = @($oldCaps)
    $Capabilities += [ordered]@{ id = "AUTONOMOUS_LOOP_CONTROLLER"; status = if ($P120.status -eq "PASS") { "PROVEN" } else { "UNKNOWN" }; proof = "PHASE120_BUILD_AUTONOMOUS_LOOP_CONTROLLER_V1" }
    $Capabilities += [ordered]@{ id = "BOUNDED_AUTONOMOUS_LOOP_TRIAL"; status = if ($P121.status -eq "PASS") { "PROVEN" } else { "UNKNOWN" }; proof = "PHASE121_RUN_BOUNDED_AUTONOMOUS_LOOP_TRIAL_V1" }
    $UpdatedSelfModel = [ordered]@{
      status = $status
      self_model_id = "BUILDER_SELF_MODEL_V2_CONTROLLER_AWARE"
      updated_by = "CONTROLLER_AWARE_SELF_MODEL_UPDATE_V1"
      run_id = $RunId
      active_line = "AGENT_BUILDER / SELF_BUILD"
      identity = "primitive_brain_cell_with_hands"
      local_first = $true
      external_brain_dependency = $false
      current_state_summary = "Builder has a proof-backed self-build chain, a self-model, a self-model-aware decision loop, and a bounded autonomous loop controller." 
      proven_capabilities = $Capabilities
      closed_needs = $closedNeeds
      current_detected_need = $currentNeed
      current_missing_capability = "CONTROLLER_GOVERNED_SELF_BUILD_TRIAL"
      recommended_next_step = $nextStep
      controller_aware = $true
      controller_path = "self_control/AUTONOMOUS_LOOP_CONTROLLER.json"
      source_phase121_classification = if ($null -ne $P121) { $P121.classification } else { "__MISSING__" }
      autonomy_claimed = $false
      codex_used = $false
      main_touched = $false
    }
    Write-JsonFile $SelfModelPath $UpdatedSelfModel 30
    $Output = [ordered]@{ status = $status; engine_name = "CONTROLLER_AWARE_SELF_MODEL_UPDATE_V1"; run_id = $RunId; self_model_path = $SelfModelPath; self_model_updated = ($status -eq "PASS"); closed_need = "NEED_AUTONOMOUS_LOOP_CONTROLLER"; current_detected_need = $currentNeed; proposed_next_step = $nextStep; reason = $reason; queue_mutated = $false; autonomy_claimed = $false; codex_used = $false; main_touched = $false }
    $OutputPath = Join-Path $OutputRoot "CONTROLLER_AWARE_SELF_MODEL_UPDATE_OUTPUT.json"
    Write-JsonFile $OutputPath $Output 20
    $Output["output_path"] = $OutputPath
    return [pscustomobject]$Output
  } finally { Pop-Location }
}
