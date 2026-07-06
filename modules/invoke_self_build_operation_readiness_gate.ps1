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

function Invoke-SelfBuildOperationReadinessGate {
  param(
    [string]$RepoRoot,
    [string]$RunId,
    $Entry,
    [string]$OutputRoot
  )

  Push-Location $RepoRoot

  try {
    if (-not (Test-Path $OutputRoot)) {
      New-Item -ItemType Directory -Force -Path $OutputRoot | Out-Null
    }

    $SelfModel = Read-JsonOptional "self_model/BUILDER_SELF_MODEL.json"
    $Contract = Read-JsonOptional "self_control/SELF_BUILD_OPERATION_CONTRACT.json"
    $P124 = Read-JsonOptional "proofs/self_development/PHASE124_BUILD_SELF_MODEL_FIRST_RUNTIME_ENTRYPOINT_V1.json"
    $P125 = Read-JsonOptional "proofs/self_development/PHASE125_RUN_SELF_MODEL_FIRST_CONTROLLER_GOVERNED_TRIAL_V1.json"
    $P127 = Read-JsonOptional "proofs/self_development/PHASE127_BUILD_SELF_BUILD_OPERATION_CONTRACT_V1.json"
    $P128 = Read-JsonOptional "proofs/self_development/PHASE128_RUN_SELF_BUILD_OPERATION_CONTRACT_SMOKE_V1.json"
    $P129 = Read-JsonOptional "proofs/self_development/PHASE129_BUILD_OPERATION_CONTRACT_AWARE_SELF_MODEL_ADVANCE_V1.json"

    $status = "BLOCKED"
    $decision = "NOT_READY"
    $nextStep = "PHASE131_REVIEW_SELF_BUILD_OPERATION_READINESS_INPUTS_V1"
    $reason = ""

    if (
      $Entry.status -eq "PASS" -and
      $Entry.current_need -eq "NEED_SELF_BUILD_OPERATION_READINESS_GATE" -and
      $SelfModel.status -eq "PASS" -and
      $SelfModel.current_detected_need -eq "NEED_SELF_BUILD_OPERATION_READINESS_GATE" -and
      $Contract.status -eq "PASS" -and
      $P124.status -eq "PASS" -and
      $P125.status -eq "PASS" -and
      $P127.status -eq "PASS" -and
      $P128.status -eq "PASS" -and
      $P129.status -eq "PASS" -and
      $P129.current_detected_need -eq "NEED_SELF_BUILD_OPERATION_READINESS_GATE"
    ) {
      $status = "PASS"
      $decision = "READY_FOR_CONTRACT_GOVERNED_SELF_BUILD_OPERATION_TRIAL"
      $nextStep = "PHASE131_RUN_CONTRACT_GOVERNED_SELF_BUILD_OPERATION_TRIAL_V1"
      $reason = "Builder has self-model-first runtime, controller-governed trial, operation contract, contract smoke, and operation-contract-aware self-model. Ready for one bounded contract-governed self-build operation trial."
    } else {
      $reason = "Required self-model, contract, or proof chain is missing/unexpected."
    }

    $Gate = [ordered]@{
      status = $status
      gate_id = "SELF_BUILD_OPERATION_READINESS_GATE_V1"
      created_by = "PHASE130_BUILD_SELF_BUILD_OPERATION_READINESS_GATE_V1"
      run_id = $RunId
      active_line = "AGENT_BUILDER / SELF_BUILD"
      scope = "SELF_BUILD_OPERATION_ONLY"
      decision = $decision
      ready = ($status -eq "PASS")
      allowed_next_step = $nextStep
      required_closed_needs = @(
        "NEED_DECISION_TO_ACTION_ENGINE",
        "NEED_AUTONOMOUS_LOOP_CONTROLLER",
        "NEED_CONTROLLER_GOVERNED_SELF_BUILD_TRIAL",
        "NEED_SELF_BUILD_OPERATION_CONTRACT"
      )
      required_proofs = @(
        "PHASE124_BUILD_SELF_MODEL_FIRST_RUNTIME_ENTRYPOINT_V1",
        "PHASE125_RUN_SELF_MODEL_FIRST_CONTROLLER_GOVERNED_TRIAL_V1",
        "PHASE127_BUILD_SELF_BUILD_OPERATION_CONTRACT_V1",
        "PHASE128_RUN_SELF_BUILD_OPERATION_CONTRACT_SMOKE_V1",
        "PHASE129_BUILD_OPERATION_CONTRACT_AWARE_SELF_MODEL_ADVANCE_V1"
      )
      allowed_trial_constraints = [ordered]@{
        max_runtime_calls = 1
        require_queue_none_at_start = $true
        require_clean_worktree_at_start = $true
        allow_external_agent_production = $false
        allow_main_touch = $false
        allow_dependency_install = $false
        require_result_report_proof = $true
        require_diff_scope_gate = $true
      }
      stop_conditions = @(
        "wrong branch",
        "dirty worktree",
        "queue not NONE",
        "missing proof",
        "runtime nonzero exit",
        "unexpected changed file",
        "legacy replay signal",
        "validator fail",
        "push failed"
      )
      reason = $reason
      autonomy_claimed = $false
      codex_used = $false
      main_touched = $false
    }

    $GatePath = "self_control/SELF_BUILD_OPERATION_READINESS_GATE.json"
    Write-JsonFile $GatePath $Gate 30

    $Output = [ordered]@{
      status = $status
      engine_name = "SELF_BUILD_OPERATION_READINESS_GATE_BUILDER_V1"
      run_id = $RunId
      gate_created = ($status -eq "PASS")
      gate_path = $GatePath
      decision = $decision
      proposed_next_step = $nextStep
      reason = $reason
      queue_mutated = $false
      autonomy_claimed = $false
      codex_used = $false
      main_touched = $false
    }

    $OutputPath = Join-Path $OutputRoot "SELF_BUILD_OPERATION_READINESS_GATE_OUTPUT.json"
    Write-JsonFile $OutputPath $Output 20
    $Output["output_path"] = $OutputPath

    return [pscustomobject]$Output
  } finally {
    Pop-Location
  }
}
