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

function Invoke-AutonomousLoopController {
  param([string]$RepoRoot, [string]$RunId, $DecisionLoop, [string]$OutputRoot)
  Push-Location $RepoRoot
  try {
    if (-not (Test-Path $OutputRoot)) { New-Item -ItemType Directory -Force -Path $OutputRoot | Out-Null }
    $SelfModel = Read-JsonOptional "self_model/BUILDER_SELF_MODEL.json"
    $P119 = Read-JsonOptional "proofs/self_development/PHASE119_BUILD_SELF_MODEL_AWARE_DECISION_LOOP_V1.json"
    $status = "BLOCKED"; $reason = ""; $nextStep = "PHASE121_RUN_BOUNDED_AUTONOMOUS_LOOP_TRIAL_V1"
    if ($DecisionLoop.status -eq "PASS" -and $DecisionLoop.selected_need_id -eq "NEED_AUTONOMOUS_LOOP_CONTROLLER" -and $DecisionLoop.selected_target_capability -eq "AUTONOMOUS_LOOP_CONTROLLER" -and $P119.status -eq "PASS") {
      $status = "PASS"; $reason = "Self-model-aware decision selected autonomous loop controller. Controller is created with bounded steps, queue safety, proof gates, and explicit stop rules."
    } else {
      $status = "BLOCKED"; $reason = "Decision loop output or PHASE119 proof is missing/unexpected."; $nextStep = "PHASE121_REVIEW_LOOP_CONTROLLER_INPUTS_V1"
    }
    $Controller = [ordered]@{
      status = $status
      controller_id = "AUTONOMOUS_LOOP_CONTROLLER_V1"
      created_by = "PHASE120_BUILD_AUTONOMOUS_LOOP_CONTROLLER_V1"
      run_id = $RunId
      active_line = "AGENT_BUILDER / SELF_BUILD"
      mode = "BOUNDED_SELF_BUILD_LOOP"
      max_runtime_calls_per_trial = 2
      max_internal_steps_per_runtime_call = 1
      max_generated_actions_per_trial = 1
      require_queue_none_at_start = $true
      require_clean_worktree_at_start = $true
      require_proof_before_next_phase = $true
      allowed_line = "AGENT_BUILDER / SELF_BUILD"
      forbidden = @("touch main", "use Codex", "install dependencies", "fetch internet materials", "execute external agent production", "claim full autonomy", "ignore dirty worktree", "continue after FAIL")
      stop_conditions = @("runtime exit nonzero", "queue unsafe", "unexpected changed file", "missing proof", "validator fail", "same stale need repeats after proof says closed", "max runtime calls reached")
      next_trial = "PHASE121_RUN_BOUNDED_AUTONOMOUS_LOOP_TRIAL_V1"
      autonomy_claimed = $false
      codex_used = $false
      main_touched = $false
    }
    $ControllerPath = "self_control/AUTONOMOUS_LOOP_CONTROLLER.json"
    Write-JsonFile $ControllerPath $Controller 20
    $Output = [ordered]@{ status = $status; engine_name = "AUTONOMOUS_LOOP_CONTROLLER_BUILDER_V1"; run_id = $RunId; controller_created = ($status -eq "PASS"); controller_path = $ControllerPath; selected_need_id = $DecisionLoop.selected_need_id; selected_target_capability = $DecisionLoop.selected_target_capability; proposed_next_step = $nextStep; reason = $reason; queue_mutated = $false; autonomy_claimed = $false; codex_used = $false; main_touched = $false }
    $OutputPath = Join-Path $OutputRoot "AUTONOMOUS_LOOP_CONTROLLER_OUTPUT.json"
    Write-JsonFile $OutputPath $Output 20
    $Output["output_path"] = $OutputPath
    return [pscustomobject]$Output
  } finally { Pop-Location }
}
