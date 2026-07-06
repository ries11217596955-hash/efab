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

function Invoke-SelfBuildOperationCapabilitySelector {
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
    $Gate = Read-JsonOptional "self_control/SELF_BUILD_OPERATION_READINESS_GATE.json"
    $P131 = Read-JsonOptional "proofs/self_development/PHASE131_RUN_CONTRACT_GOVERNED_SELF_BUILD_OPERATION_TRIAL_V1.json"
    $P132 = Read-JsonOptional "proofs/self_development/PHASE132_BUILD_OPERATION_TRIAL_AWARE_SELF_MODEL_ADVANCE_V1.json"

    $status = "BLOCKED"
    $reason = ""
    $selectedNeed = ""
    $selectedCapability = ""
    $nextStep = "PHASE134_REVIEW_CAPABILITY_SELECTOR_INPUTS_V1"

    if (
      $Entry.status -eq "PASS" -and
      $Entry.current_need -eq "NEED_SELF_BUILD_OPERATION_CAPABILITY_SELECTOR" -and
      $SelfModel.status -eq "PASS" -and
      $SelfModel.current_detected_need -eq "NEED_SELF_BUILD_OPERATION_CAPABILITY_SELECTOR" -and
      $Contract.status -eq "PASS" -and
      $Gate.status -eq "PASS" -and
      $P131.status -eq "PASS" -and
      $P132.status -eq "PASS"
    ) {
      $status = "PASS"
      $selectedNeed = "NEED_MATERIAL_ACQUISITION_BOOTSTRAP"
      $selectedCapability = "MATERIAL_ACQUISITION_BOOTSTRAP"
      $nextStep = "PHASE134_BUILD_MATERIAL_ACQUISITION_BOOTSTRAP_V1"
      $reason = "Builder is past readiness gate and has a contract-governed operation trial. Next real self-build operation should bootstrap material acquisition so Builder can accept external materials through governance instead of writing everything from scratch."
    } else {
      $reason = "Entry, self-model, contract, readiness gate, PHASE131 proof, or PHASE132 proof is missing/unexpected."
    }

    $Selector = [ordered]@{
      status = $status
      selector_id = "SELF_BUILD_OPERATION_CAPABILITY_SELECTOR_V1"
      created_by = "PHASE133_BUILD_SELF_BUILD_OPERATION_CAPABILITY_SELECTOR_V1"
      run_id = $RunId
      active_line = "AGENT_BUILDER / SELF_BUILD"
      scope = "SELECT_NEXT_SELF_BUILD_OPERATION_CAPABILITY"
      selection_policy = [ordered]@{
        prefer_real_operational_capability = $true
        avoid_smoke_for_smoke = $true
        avoid_external_agent_production = $true
        require_contract_governance = $true
        require_material_governance_before_external_material_use = $true
      }
      candidate_capabilities = @(
        [ordered]@{
          need_id = "NEED_MATERIAL_ACQUISITION_BOOTSTRAP"
          capability_id = "MATERIAL_ACQUISITION_BOOTSTRAP"
          priority = 1
          reason = "Starts governed material intake/catalog path; enables reuse of libraries/templates/workflows later."
          next_step = "PHASE134_BUILD_MATERIAL_ACQUISITION_BOOTSTRAP_V1"
        },
        [ordered]@{
          need_id = "NEED_OPERATION_TELEMETRY_SUMMARY"
          capability_id = "OPERATION_TELEMETRY_SUMMARY"
          priority = 2
          reason = "Useful, but less foundational than material intake."
          next_step = "PHASE134_BUILD_OPERATION_TELEMETRY_SUMMARY_V1"
        },
        [ordered]@{
          need_id = "NEED_EXTERNAL_AGENT_PRODUCTION_READINESS_REVIEW"
          capability_id = "EXTERNAL_AGENT_PRODUCTION_READINESS_REVIEW"
          priority = 3
          reason = "Deferred until material bootstrap and governance are in place."
          next_step = "PHASE134_REVIEW_EXTERNAL_AGENT_PRODUCTION_READINESS_V1"
        }
      )
      selected_need_id = $selectedNeed
      selected_capability_id = $selectedCapability
      selected_next_step = $nextStep
      reason = $reason
      autonomy_claimed = $false
      codex_used = $false
      main_touched = $false
    }

    $SelectorPath = "self_control/SELF_BUILD_OPERATION_CAPABILITY_SELECTOR.json"
    Write-JsonFile $SelectorPath $Selector 30

    $Output = [ordered]@{
      status = $status
      engine_name = "SELF_BUILD_OPERATION_CAPABILITY_SELECTOR_BUILDER_V1"
      run_id = $RunId
      selector_created = ($status -eq "PASS")
      selector_path = $SelectorPath
      source_need = $Entry.current_need
      selected_need_id = $selectedNeed
      selected_capability_id = $selectedCapability
      proposed_next_step = $nextStep
      reason = $reason
      queue_mutated = $false
      autonomy_claimed = $false
      codex_used = $false
      main_touched = $false
    }

    $OutputPath = Join-Path $OutputRoot "SELF_BUILD_OPERATION_CAPABILITY_SELECTOR_OUTPUT.json"
    Write-JsonFile $OutputPath $Output 20
    $Output["output_path"] = $OutputPath

    return [pscustomobject]$Output
  } finally {
    Pop-Location
  }
}
