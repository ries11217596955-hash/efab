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

function Invoke-SelfModelUpdateEngine {
  param([string]$RepoRoot, [string]$RunId, $Need, [string]$OutputRoot)
  Push-Location $RepoRoot
  try {
    if (-not (Test-Path $OutputRoot)) { New-Item -ItemType Directory -Force -Path $OutputRoot | Out-Null }
    $SelfModelPath = "self_model/BUILDER_SELF_MODEL.json"
    $P110 = Read-JsonOptional "proofs/self_development/PHASE110_FINALIZE_IDEMPOTENT_AUTONOMY_TRIAL_V1.json"
    $P111 = Read-JsonOptional "proofs/self_development/PHASE111_BUILD_NEXT_ACTION_DECISION_KERNEL_V1.json"
    $P112 = Read-JsonOptional "proofs/self_development/PHASE112_BUILD_DECISION_TO_ACTION_ENGINE_V1.json"
    $P113 = Read-JsonOptional "proofs/self_development/PHASE113_BUILD_DECISION_ACTION_ADMISSION_BRIDGE_V1.json"
    $P114 = Read-JsonOptional "proofs/self_development/PHASE114_BUILD_ADMITTED_ACTION_EXECUTION_ENGINE_V1.json"
    $P115 = Read-JsonOptional "proofs/self_development/PHASE115_EXECUTE_BUILDER_QUEUED_ADMITTED_ACTION_V1.json"
    $P116 = Read-JsonOptional "proofs/self_development/PHASE116_BUILDER_AUTONOMOUS_CHAIN_SMOKE_V1.json"
    $P117 = Read-JsonOptional "proofs/self_development/PHASE117_BUILD_PROOF_AWARE_SELF_NEED_ENGINE_V1.json"
    $status = "BLOCKED"; $reason = ""; $currentNeed = ""; $nextStep = "PHASE119_BUILD_SELF_MODEL_AWARE_DECISION_LOOP_V1"
    if ($Need.status -eq "PASS" -and $Need.detected_need_id -eq "NEED_SELF_MODEL_UPDATE_ENGINE" -and $P117.status -eq "PASS" -and $P116.status -eq "PASS" -and $P115.status -eq "PASS" -and $P114.status -eq "PASS" -and $P113.status -eq "PASS" -and $P112.status -eq "PASS") {
      $status = "PASS"; $currentNeed = "NEED_SELF_MODEL_AWARE_DECISION_LOOP"; $reason = "Proof chain confirms Builder can detect need, create action request, admit action, generate executable move, execute queued move, run a two-step chain, and update diagnosis from proofs. Next missing organ is a decision loop that uses the self-model."
    } else {
      $status = "BLOCKED"; $currentNeed = "NEED_PROOF_CHAIN_REVIEW"; $nextStep = "PHASE119_REVIEW_SELF_MODEL_UPDATE_INPUTS_V1"; $reason = "Required proof chain or self-need input is missing/unexpected."
    }
    $Capabilities = @(
      [ordered]@{ id = "RUNTIME_REPEATABILITY"; status = if ($P110.status -eq "PASS") { "PROVEN" } else { "UNKNOWN" }; proof = "PHASE110_FINALIZE_IDEMPOTENT_AUTONOMY_TRIAL_V1" },
      [ordered]@{ id = "SELF_NEED_DETECTION"; status = if ($P111.status -eq "PASS") { "PROVEN" } else { "UNKNOWN" }; proof = "PHASE111_BUILD_NEXT_ACTION_DECISION_KERNEL_V1" },
      [ordered]@{ id = "DECISION_TO_ACTION"; status = if ($P112.status -eq "PASS") { "PROVEN" } else { "UNKNOWN" }; proof = "PHASE112_BUILD_DECISION_TO_ACTION_ENGINE_V1" },
      [ordered]@{ id = "ACTION_ADMISSION"; status = if ($P113.status -eq "PASS") { "PROVEN" } else { "UNKNOWN" }; proof = "PHASE113_BUILD_DECISION_ACTION_ADMISSION_BRIDGE_V1" },
      [ordered]@{ id = "ADMITTED_ACTION_TO_EXECUTABLE_MOVE"; status = if ($P114.status -eq "PASS") { "PROVEN" } else { "UNKNOWN" }; proof = "PHASE114_BUILD_ADMITTED_ACTION_EXECUTION_ENGINE_V1" },
      [ordered]@{ id = "BUILDER_QUEUED_ACTION_EXECUTION"; status = if ($P115.status -eq "PASS") { "PROVEN" } else { "UNKNOWN" }; proof = "PHASE115_EXECUTE_BUILDER_QUEUED_ADMITTED_ACTION_V1" },
      [ordered]@{ id = "TWO_STEP_AUTONOMOUS_CHAIN_SMOKE"; status = if ($P116.status -eq "PASS") { "PROVEN" } else { "UNKNOWN" }; proof = "PHASE116_BUILDER_AUTONOMOUS_CHAIN_SMOKE_V1" },
      [ordered]@{ id = "PROOF_AWARE_SELF_NEED"; status = if ($P117.status -eq "PASS") { "PROVEN" } else { "UNKNOWN" }; proof = "PHASE117_BUILD_PROOF_AWARE_SELF_NEED_ENGINE_V1" }
    )
    $SelfModel = [ordered]@{ status = $status; self_model_id = "BUILDER_SELF_MODEL_V1"; updated_by = "SELF_MODEL_UPDATE_ENGINE_V1"; run_id = $RunId; active_line = "AGENT_BUILDER / SELF_BUILD"; identity = "primitive_brain_cell_with_hands"; local_first = $true; external_brain_dependency = $false; current_state_summary = "Builder has a proof-backed self-build chain and can now update its self-model from proofs."; proven_capabilities = $Capabilities; closed_needs = @("NEED_DECISION_TO_ACTION_ENGINE","NEED_DECISION_ACTION_ADMISSION_BRIDGE","NEED_ADMITTED_ACTION_EXECUTION_ENGINE","NEED_PROOF_AWARE_SELF_NEED_ENGINE","NEED_SELF_MODEL_UPDATE_ENGINE"); current_detected_need = $currentNeed; current_missing_capability = "SELF_MODEL_AWARE_DECISION_LOOP"; recommended_next_step = $nextStep; last_source_need = $Need.detected_need_id; last_source_diagnosis = $Need.diagnosis; autonomy_claimed = $false; codex_used = $false; main_touched = $false }
    Write-JsonFile $SelfModelPath $SelfModel 24
    $Output = [ordered]@{ status = $status; engine_name = "SELF_MODEL_UPDATE_ENGINE_V1"; run_id = $RunId; self_model_path = $SelfModelPath; self_model_updated = ($status -eq "PASS"); source_need_id = $Need.detected_need_id; current_detected_need = $currentNeed; current_missing_capability = "SELF_MODEL_AWARE_DECISION_LOOP"; proposed_next_step = $nextStep; reason = $reason; queue_mutated = $false; autonomy_claimed = $false; codex_used = $false }
    $OutputPath = Join-Path $OutputRoot "SELF_MODEL_UPDATE_ENGINE_OUTPUT.json"
    Write-JsonFile $OutputPath $Output 20
    $Output["output_path"] = $OutputPath
    return [pscustomobject]$Output
  } finally { Pop-Location }
}
