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

function Invoke-SelfBuildOperationContract {
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
    $Controller = Read-JsonOptional "self_control/AUTONOMOUS_LOOP_CONTROLLER.json"
    $P126 = Read-JsonOptional "proofs/self_development/PHASE126_BUILD_TRIAL_AWARE_SELF_MODEL_ADVANCE_V1.json"

    $status = "BLOCKED"
    $reason = ""
    $nextStep = "PHASE128_RUN_SELF_BUILD_OPERATION_CONTRACT_SMOKE_V1"

    if (
      $Entry.status -eq "PASS" -and
      $Entry.current_need -eq "NEED_SELF_BUILD_OPERATION_CONTRACT" -and
      $SelfModel.status -eq "PASS" -and
      $SelfModel.current_detected_need -eq "NEED_SELF_BUILD_OPERATION_CONTRACT" -and
      $Controller.status -eq "PASS" -and
      $P126.status -eq "PASS"
    ) {
      $status = "PASS"
      $reason = "Self-model requests a self-build operation contract and PHASE126 proof confirms the need."
    } else {
      $status = "BLOCKED"
      $nextStep = "PHASE128_REVIEW_SELF_BUILD_OPERATION_CONTRACT_INPUTS_V1"
      $reason = "Entry, self-model, controller, or PHASE126 proof is missing/unexpected."
    }

    $Contract = [ordered]@{
      status = $status
      contract_id = "SELF_BUILD_OPERATION_CONTRACT_V1"
      created_by = "PHASE127_BUILD_SELF_BUILD_OPERATION_CONTRACT_V1"
      run_id = $RunId
      active_line = "AGENT_BUILDER / SELF_BUILD"
      purpose = "Govern live self-build operation after self-model-first controller-governed trial."
      allowed_start_state = [ordered]@{
        branch = "phase110-idempotent-autonomy-trial-runtime"
        worktree = "CLEAN"
        active_task_id = "NONE"
        self_model_need = "NEED_SELF_BUILD_OPERATION_CONTRACT_OR_LATER"
      }
      allowed_operations = @(
        "read self_model",
        "read controller",
        "run bounded self-build runtime",
        "create one scoped capability per phase",
        "write result/report/proof",
        "validate JSON and PowerShell parse",
        "commit and push only after PASS"
      )
      forbidden_operations = @(
        "touch main",
        "claim full autonomy",
        "continue after FAIL",
        "ignore dirty worktree",
        "install dependencies without material policy",
        "fetch internet materials without material governance",
        "produce external agents before readiness gate",
        "commit transient runtime rewrites",
        "mix external-agent production with SELF_BUILD proof"
      )
      proof_gates = @(
        "baseline branch/head/worktree gate",
        "queue active_task_id gate",
        "previous proof next_allowed_step gate",
        "runtime exit code gate",
        "log signal gate",
        "JSON parse gate",
        "validator gate",
        "diff scope gate",
        "commit/push gate"
      )
      stop_conditions = @(
        "wrong branch",
        "dirty worktree before phase",
        "queue not NONE unless phase explicitly requires active task",
        "missing previous proof",
        "unexpected next_allowed_step",
        "runtime nonzero exit",
        "validator fail",
        "unexpected changed file",
        "legacy replay signal when forbidden",
        "transient output not restored",
        "push failed"
      )
      next_smoke = "PHASE128_RUN_SELF_BUILD_OPERATION_CONTRACT_SMOKE_V1"
      autonomy_claimed = $false
      codex_used = $false
      main_touched = $false
    }

    $ContractPath = "self_control/SELF_BUILD_OPERATION_CONTRACT.json"
    Write-JsonFile $ContractPath $Contract 30

    $Output = [ordered]@{
      status = $status
      engine_name = "SELF_BUILD_OPERATION_CONTRACT_BUILDER_V1"
      run_id = $RunId
      contract_created = ($status -eq "PASS")
      contract_path = $ContractPath
      source_need = $Entry.current_need
      proposed_next_step = $nextStep
      reason = $reason
      queue_mutated = $false
      autonomy_claimed = $false
      codex_used = $false
      main_touched = $false
    }

    $OutputPath = Join-Path $OutputRoot "SELF_BUILD_OPERATION_CONTRACT_OUTPUT.json"
    Write-JsonFile $OutputPath $Output 20
    $Output["output_path"] = $OutputPath

    return [pscustomobject]$Output
  } finally {
    Pop-Location
  }
}
