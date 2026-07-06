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

function Invoke-OperationContractAwareSelfModelAdvance {
  param(
    [string]$RepoRoot,
    [string]$RunId,
    $Entry,
    $ContractOutput,
    [string]$OutputRoot
  )

  Push-Location $RepoRoot

  try {
    if (-not (Test-Path $OutputRoot)) {
      New-Item -ItemType Directory -Force -Path $OutputRoot | Out-Null
    }

    $SelfModelPath = "self_model/BUILDER_SELF_MODEL.json"
    $SelfModel = Read-JsonOptional $SelfModelPath
    $Contract = Read-JsonOptional "self_control/SELF_BUILD_OPERATION_CONTRACT.json"
    $P127 = Read-JsonOptional "proofs/self_development/PHASE127_BUILD_SELF_BUILD_OPERATION_CONTRACT_V1.json"
    $P128 = Read-JsonOptional "proofs/self_development/PHASE128_RUN_SELF_BUILD_OPERATION_CONTRACT_SMOKE_V1.json"

    $status = "BLOCKED"
    $closedNeed = ""
    $currentNeed = "NEED_OPERATION_CONTRACT_AWARE_SELF_MODEL_REVIEW"
    $nextStep = "PHASE130_REVIEW_OPERATION_CONTRACT_AWARE_SELF_MODEL_INPUTS_V1"
    $reason = ""

    if (
      $Entry.status -eq "PASS" -and
      $Entry.current_need -eq "NEED_SELF_BUILD_OPERATION_CONTRACT" -and
      $ContractOutput.status -eq "PASS" -and
      $ContractOutput.contract_created -eq $true -and
      $SelfModel.status -eq "PASS" -and
      $SelfModel.current_detected_need -eq "NEED_SELF_BUILD_OPERATION_CONTRACT" -and
      $Contract.status -eq "PASS" -and
      $P127.status -eq "PASS" -and
      $P128.status -eq "PASS" -and
      $P128.classification -eq "SELF_BUILD_OPERATION_CONTRACT_SMOKE_PASS_BUT_CONTRACT_NEED_STILL_OPEN"
    ) {
      $status = "PASS"
      $closedNeed = "NEED_SELF_BUILD_OPERATION_CONTRACT"
      $currentNeed = "NEED_SELF_BUILD_OPERATION_READINESS_GATE"
      $nextStep = "PHASE130_BUILD_SELF_BUILD_OPERATION_READINESS_GATE_V1"
      $reason = "PHASE127 built the self-build operation contract and PHASE128 proved its smoke path. Self-model can close the contract need and move to readiness gate."
    } else {
      $status = "BLOCKED"
      $reason = "Entry, contract output, self-model, operation contract, PHASE127 proof, or PHASE128 proof is missing/unexpected."
    }

    $oldClosed = @()
    if ($null -ne $SelfModel -and $null -ne $SelfModel.closed_needs) { $oldClosed = @($SelfModel.closed_needs) }
    $closedNeeds = @($oldClosed + $closedNeed | Where-Object { $_ -and $_.Trim() -ne "" } | Sort-Object -Unique)

    $oldCaps = @()
    if ($null -ne $SelfModel -and $null -ne $SelfModel.proven_capabilities) { $oldCaps = @($SelfModel.proven_capabilities) }

    $Capabilities = @($oldCaps)
    $Capabilities += [ordered]@{ id = "SELF_BUILD_OPERATION_CONTRACT"; status = if ($P127.status -eq "PASS") { "PROVEN" } else { "UNKNOWN" }; proof = "PHASE127_BUILD_SELF_BUILD_OPERATION_CONTRACT_V1" }
    $Capabilities += [ordered]@{ id = "SELF_BUILD_OPERATION_CONTRACT_SMOKE"; status = if ($P128.status -eq "PASS") { "PROVEN" } else { "UNKNOWN" }; proof = "PHASE128_RUN_SELF_BUILD_OPERATION_CONTRACT_SMOKE_V1" }

    $UpdatedSelfModel = [ordered]@{
      status = $status
      self_model_id = "BUILDER_SELF_MODEL_V4_OPERATION_CONTRACT_AWARE"
      updated_by = "OPERATION_CONTRACT_AWARE_SELF_MODEL_ADVANCE_V1"
      run_id = $RunId
      active_line = "AGENT_BUILDER / SELF_BUILD"
      identity = "primitive_brain_cell_with_hands"
      local_first = $true
      external_brain_dependency = $false
      current_state_summary = "Builder has a self-model-first path, bounded controller, and self-build operation contract. Next need is readiness gate, not another smoke loop."
      proven_capabilities = $Capabilities
      closed_needs = $closedNeeds
      current_detected_need = $currentNeed
      current_missing_capability = "SELF_BUILD_OPERATION_READINESS_GATE"
      recommended_next_step = $nextStep
      operation_contract_aware = $true
      source_phase128_classification = if ($null -ne $P128) { $P128.classification } else { "__MISSING__" }
      autonomy_claimed = $false
      codex_used = $false
      main_touched = $false
    }

    Write-JsonFile $SelfModelPath $UpdatedSelfModel 30

    $Output = [ordered]@{
      status = $status
      engine_name = "OPERATION_CONTRACT_AWARE_SELF_MODEL_ADVANCE_V1"
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

    $OutputPath = Join-Path $OutputRoot "OPERATION_CONTRACT_AWARE_SELF_MODEL_ADVANCE_OUTPUT.json"
    Write-JsonFile $OutputPath $Output 20
    $Output["output_path"] = $OutputPath

    return [pscustomobject]$Output
  } finally {
    Pop-Location
  }
}
