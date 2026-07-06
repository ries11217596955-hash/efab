param(
  [Parameter(Mandatory=$true)]
  [string]$FreezeRoot,

  [Parameter(Mandatory=$true)]
  [string]$UsefulnessRoot,

  [Parameter(Mandatory=$true)]
  [string]$SafetyRoot,

  [string]$OutputRoot = ""
)

$ErrorActionPreference = "Stop"

function Read-Json {
  param([string]$Path)
  if (-not (Test-Path -LiteralPath $Path)) { throw "MISSING_FILE=$Path" }
  return Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json
}

function Write-Json {
  param([string]$Path, [object]$Object)
  $dir = Split-Path -Parent $Path
  if ($dir -and -not (Test-Path -LiteralPath $dir)) {
    New-Item -ItemType Directory -Force -Path $dir | Out-Null
  }
  $Object | ConvertTo-Json -Depth 40 | Set-Content -Path $Path -Encoding UTF8
}

if ([string]::IsNullOrWhiteSpace($OutputRoot)) {
  $stamp = Get-Date -Format "yyyyMMdd_HHmmss"
  $OutputRoot = Join-Path (Split-Path -Parent $FreezeRoot) "PHASE162_AUTONOMOUS_ADMISSION_CYCLE_$stamp"
}

New-Item -ItemType Directory -Force -Path $OutputRoot | Out-Null

$freeze = Read-Json (Join-Path $FreezeRoot "frozen_atom_candidate_evidence.json")
$freezeValidation = Read-Json (Join-Path $FreezeRoot "validation_result.json")

$usefulness = Read-Json (Join-Path $UsefulnessRoot "usefulness_safety_blockers_result.json")
$usefulnessValidation = Read-Json (Join-Path $UsefulnessRoot "usefulness_safety_blockers_validation.json")

$safety = Read-Json (Join-Path $SafetyRoot "accept_safety_contract_result.json")
$safetyContract = Read-Json (Join-Path $SafetyRoot "accept_safety_contract_scaffold.json")
$safetyValidation = Read-Json (Join-Path $SafetyRoot "accept_safety_contract_validation.json")

$atomGenerated = (
  ([bool]$freeze.atom_candidate_summary_present_on_this_pc -eq $true) -and
  ([int]$freeze.selected_skill_candidate_count -gt 0)
)

$freezeProven = (
  ([string]$freeze.status -eq "FROZEN") -and
  ([string]$freezeValidation.status -eq "PASS")
)

$partialUsefulness = (
  ([string]$usefulnessValidation.status -eq "PASS") -and
  ([bool]$usefulness.usefulness_validated_partial -eq $true)
)

$usefulnessForAccept = ([bool]$usefulness.usefulness_validated_for_accept -eq $true)

$safetyContractsPresent = (
  ([string]$safetyValidation.status -eq "PASS") -and
  ([bool]$safety.accept_safety_contracts_present -eq $true)
)

$safetyForAccept = ([bool]$safety.safety_validated_for_accept -eq $true)
$ownerReviewGranted = ([bool]$safetyContract.owner_review_gate.granted -eq $true)
$rollbackTested = ([bool]$safetyContract.rollback_plan.rollback_tested -eq $true)
$nextCycleImprovementProven = $false
$liveTaskSuccessDeltaProven = $false

$preconditions = [ordered]@{
  atom_generated = $atomGenerated
  freeze_evidence_proven = $freezeProven
  partial_usefulness_proven = $partialUsefulness
  usefulness_validated_for_accept = $usefulnessForAccept
  safety_contracts_present = $safetyContractsPresent
  safety_validated_for_accept = $safetyForAccept
  owner_review_granted = $ownerReviewGranted
  rollback_tested = $rollbackTested
  next_cycle_improvement_proven = $nextCycleImprovementProven
  live_task_success_delta_proven = $liveTaskSuccessDeltaProven
}

$blocking = @()

foreach ($p in $preconditions.GetEnumerator()) {
  if (-not [bool]$p.Value) {
    $blocking += $p.Key
  }
}

$acceptReady = (
  $atomGenerated -and
  $freezeProven -and
  $partialUsefulness -and
  $usefulnessForAccept -and
  $safetyContractsPresent -and
  $safetyForAccept -and
  $ownerReviewGranted -and
  $rollbackTested -and
  $nextCycleImprovementProven -and
  $liveTaskSuccessDeltaProven
)

$machineDecision = if ($acceptReady) { "ACCEPT_READY" } else { "ACCEPT_BLOCKED_AUTONOMOUS_CYCLE" }

$nextMachineAction = if (-not $nextCycleImprovementProven) {
  "RUN_NEXT_CYCLE_IMPROVEMENT_TRIAL_SANDBOX"
} elseif (-not $safetyForAccept) {
  "ACTIVATE_AND_TEST_ACCEPT_SAFETY_CONTRACTS_IN_DRY_RUN"
} elseif (-not $ownerReviewGranted) {
  "REQUEST_OWNER_REVIEW_FOR_CONTROLLED_ACCEPT"
} else {
  "CONTROLLED_ACCEPT_READY_FOR_FINAL_REVIEW"
}

$cycle = [ordered]@{
  schema = "PHASE162_AUTONOMOUS_ADMISSION_CYCLE_CONTROLLER_V1"
  status = "PASS"
  created_at = (Get-Date -Format o)
  loop_target = "builder_lives_creates_atom_absorbs_safe_atom_next_cycle_stronger"
  controller_mode = "AUTONOMOUS_DRY_RUN_NO_ACCEPTED_CORE_WRITES"
  freeze_root = $FreezeRoot
  usefulness_root = $UsefulnessRoot
  safety_root = $SafetyRoot
  preconditions = $preconditions
  machine_decision = $machineDecision
  next_machine_action = $nextMachineAction
  blocking_reasons = $blocking
  accepted_atom_claimed = $false
  accepted_state_mutated = $false
  accepted_memory_mutated = $false
  accepted_self_model_mutated = $false
}

$nextTrial = [ordered]@{
  schema = "PHASE162_NEXT_CYCLE_IMPROVEMENT_TRIAL_REQUEST_V1"
  status = "READY_TO_BUILD_TRIAL"
  created_at = (Get-Date -Format o)
  reason = "Admission cycle needs proof that accepting or using the atom makes the next Builder cycle stronger."
  required_trial = [ordered]@{
    mode = "SANDBOX_ONLY"
    before_measurement = "builder_cycle_without_absorbed_atom"
    candidate_application = "apply_atom_in_sandbox_only"
    after_measurement = "builder_cycle_with_atom_available_in_sandbox"
    success_rule = "after_cycle_has_measurable_improvement_without_accepted_core_mutation"
    forbidden = @(
      "mutate_accepted_memory",
      "mutate_accepted_self_model",
      "claim_absorb_complete",
      "run_unbounded_live_daemon"
    )
  }
  expected_result_if_trial_missing = "ACCEPT_BLOCKED"
  next_module_to_build = "invoke_phase162_next_cycle_improvement_trial_sandbox_001.ps1"
}

Write-Json -Path (Join-Path $OutputRoot "autonomous_admission_cycle_result.json") -Object $cycle
Write-Json -Path (Join-Path $OutputRoot "next_cycle_improvement_trial_request.json") -Object $nextTrial

@"
# PHASE162 Autonomous Admission Cycle Controller Report

## Result

- status: PASS
- controller_mode: AUTONOMOUS_DRY_RUN_NO_ACCEPTED_CORE_WRITES
- machine_decision: $machineDecision
- next_machine_action: $nextMachineAction
- atom_generated: $atomGenerated
- freeze_evidence_proven: $freezeProven
- partial_usefulness_proven: $partialUsefulness
- safety_contracts_present: $safetyContractsPresent
- safety_validated_for_accept: $safetyForAccept
- next_cycle_improvement_proven: $nextCycleImprovementProven
- accepted_atom_claimed: false
- accepted_state_mutated: false
- accepted_memory_mutated: false
- accepted_self_model_mutated: false

## Meaning

This is the first machine-level admission controller.

It does not merely report one organ result. It consumes freeze, usefulness, and safety evidence and emits one machine decision plus the next machine action.

## Target Line

Builder must live, create an atom, validate it, absorb it only when safe, and then prove the next cycle is stronger.

## Current Blockers

$($blocking | ForEach-Object { "- $_" } | Out-String)

## Next Machine Action

$nextMachineAction
"@ | Set-Content -Path (Join-Path $OutputRoot "PHASE162_AUTONOMOUS_ADMISSION_CYCLE_CONTROLLER_REPORT.md") -Encoding UTF8

[pscustomobject]@{
  status = "PASS"
  output_root = $OutputRoot
  machine_decision = $machineDecision
  next_machine_action = $nextMachineAction
  atom_generated = $atomGenerated
  freeze_evidence_proven = $freezeProven
  partial_usefulness_proven = $partialUsefulness
  safety_contracts_present = $safetyContractsPresent
  safety_validated_for_accept = $safetyForAccept
  next_cycle_improvement_proven = $nextCycleImprovementProven
  accepted_state_mutated = $false
  accepted_memory_mutated = $false
  accepted_self_model_mutated = $false
}
