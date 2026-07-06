param(
  [Parameter(Mandatory=$true)]
  [string]$CycleRoot,

  [Parameter(Mandatory=$true)]
  [string]$TrialRoot,

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
  $Object | ConvertTo-Json -Depth 60 | Set-Content -Path $Path -Encoding UTF8
}

if ([string]::IsNullOrWhiteSpace($OutputRoot)) {
  $stamp = Get-Date -Format "yyyyMMdd_HHmmss"
  $OutputRoot = Join-Path (Split-Path -Parent $CycleRoot) "PHASE162_CONTROLLER_WITH_NEXT_CYCLE_TRIAL_$stamp"
}

New-Item -ItemType Directory -Force -Path $OutputRoot | Out-Null

$cycle = Read-Json (Join-Path $CycleRoot "autonomous_admission_cycle_result.json")
$cycleValidation = Read-Json (Join-Path $CycleRoot "autonomous_admission_cycle_validation.json")

$trial = Read-Json (Join-Path $TrialRoot "next_cycle_improvement_trial_result.json")
$trialValidation = Read-Json (Join-Path $TrialRoot "next_cycle_improvement_trial_validation.json")

$safety = Read-Json (Join-Path $SafetyRoot "accept_safety_contract_result.json")
$safetyContract = Read-Json (Join-Path $SafetyRoot "accept_safety_contract_scaffold.json")
$safetyValidation = Read-Json (Join-Path $SafetyRoot "accept_safety_contract_validation.json")

$atomGenerated = [bool]$cycle.preconditions.atom_generated
$freezeProven = [bool]$cycle.preconditions.freeze_evidence_proven
$partialUsefulness = [bool]$cycle.preconditions.partial_usefulness_proven
$usefulnessForAccept = [bool]$cycle.preconditions.usefulness_validated_for_accept

$safetyContractsPresent = (
  ([string]$safetyValidation.status -eq "PASS") -and
  ([bool]$safety.accept_safety_contracts_present -eq $true)
)

$safetyForAccept = [bool]$safety.safety_validated_for_accept
$ownerReviewGranted = [bool]$safetyContract.owner_review_gate.granted
$rollbackTested = [bool]$safetyContract.rollback_plan.rollback_tested

$nextCyclePartial = (
  ([string]$trialValidation.status -eq "PASS") -and
  ([bool]$trial.next_cycle_improvement_trial_passed -eq $true) -and
  ([bool]$trial.next_cycle_improvement_proven_partial -eq $true) -and
  ([int]$trial.measured_capability_score_delta -gt 0)
)

$nextCycleForAccept = [bool]$trial.next_cycle_improvement_proven_for_accept
$liveDaemonAutonomousAbsorbProven = $false
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
  next_cycle_improvement_proven_partial = $nextCyclePartial
  next_cycle_improvement_proven_for_accept = $nextCycleForAccept
  live_task_success_delta_proven = $liveTaskSuccessDeltaProven
  live_daemon_autonomous_absorb_proven = $liveDaemonAutonomousAbsorbProven
}

$blocking = @()
foreach ($p in $preconditions.GetEnumerator()) {
  if (-not [bool]$p.Value) { $blocking += $p.Key }
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
  $nextCycleForAccept -and
  $liveTaskSuccessDeltaProven -and
  $liveDaemonAutonomousAbsorbProven
)

$nextMachineAction = if (-not $nextCyclePartial) {
  "RUN_NEXT_CYCLE_IMPROVEMENT_TRIAL_SANDBOX"
} elseif (-not $safetyForAccept) {
  "ACTIVATE_AND_TEST_ACCEPT_SAFETY_CONTRACTS_IN_DRY_RUN"
} elseif (-not $ownerReviewGranted) {
  "REQUEST_OWNER_REVIEW_FOR_CONTROLLED_ACCEPT"
} elseif (-not $liveDaemonAutonomousAbsorbProven) {
  "RUN_BOUNDED_LIVE_DAEMON_ABSORB_TRIAL"
} else {
  "CONTROLLED_ACCEPT_READY_FOR_FINAL_REVIEW"
}

$machineDecision = if ($acceptReady) { "ACCEPT_READY" } else { "ACCEPT_BLOCKED_AUTONOMOUS_CYCLE" }

$result = [ordered]@{
  schema = "PHASE162_CONTROLLER_CONSUME_NEXT_CYCLE_TRIAL_V1"
  status = "PASS"
  created_at = (Get-Date -Format o)
  loop_target = "builder_lives_creates_atom_absorbs_safe_atom_next_cycle_stronger"
  controller_mode = "AUTONOMOUS_DRY_RUN_NO_ACCEPTED_CORE_WRITES"
  previous_cycle_root = $CycleRoot
  next_cycle_trial_root = $TrialRoot
  safety_root = $SafetyRoot
  preconditions = $preconditions
  machine_decision = $machineDecision
  next_machine_action = $nextMachineAction
  blocking_reasons = $blocking
  consumed_next_cycle_trial = [ordered]@{
    validation_status = [string]$trialValidation.status
    trial_passed = [bool]$trial.next_cycle_improvement_trial_passed
    score_before = [int]$trial.measured_capability_score_before
    score_after = [int]$trial.measured_capability_score_after
    score_delta = [int]$trial.measured_capability_score_delta
    proven_partial = [bool]$trial.next_cycle_improvement_proven_partial
    proven_for_accept = [bool]$trial.next_cycle_improvement_proven_for_accept
  }
  accepted_atom_claimed = $false
  accepted_state_mutated = $false
  accepted_memory_mutated = $false
  accepted_self_model_mutated = $false
}

$nextRequest = [ordered]@{
  schema = "PHASE162_ACCEPT_SAFETY_CONTRACT_DRY_RUN_ACTIVATION_REQUEST_V1"
  status = "READY_TO_BUILD"
  created_at = (Get-Date -Format o)
  reason = "Next-cycle sandbox improvement is partial-proven. Controller must now test safety contracts in dry-run before any accept."
  required_trial = [ordered]@{
    mode = "DRY_RUN_ONLY_NO_ACCEPTED_CORE_WRITES"
    objective = "prove accept write contracts can validate target paths, rollback, owner gate, and forbidden writes"
    expected_machine_decision = "ACCEPT_BLOCKED_AUTONOMOUS_CYCLE"
    forbidden = @(
      "mutate_accepted_memory",
      "mutate_accepted_self_model",
      "mutate_pack_registry",
      "claim_absorb_complete",
      "claim_accept_ready"
    )
  }
  next_module_to_build = "invoke_phase162_accept_safety_contract_dry_run_activation_001.ps1"
}

Write-Json -Path (Join-Path $OutputRoot "controller_with_next_cycle_trial_result.json") -Object $result
Write-Json -Path (Join-Path $OutputRoot "accept_safety_contract_dry_run_activation_request.json") -Object $nextRequest

@"
# PHASE162 Controller Consumes Next-Cycle Trial Report

## Result

- status: PASS
- machine_decision: $machineDecision
- next_machine_action: $nextMachineAction
- next_cycle_improvement_proven_partial: $nextCyclePartial
- next_cycle_improvement_proven_for_accept: $nextCycleForAccept
- safety_validated_for_accept: $safetyForAccept
- accepted_atom_claimed: false
- accepted_state_mutated: false
- accepted_memory_mutated: false
- accepted_self_model_mutated: false

## Meaning

The autonomous controller now consumes the next-cycle sandbox trial result.

The cycle advanced from asking for next-cycle trial to asking for safety-contract dry-run activation.

## Boundary

No accepted core write happened. This is still not absorb.

## Target

Builder must eventually run, create atom, absorb safe atom automatically, and prove the next cycle is stronger.
"@ | Set-Content -Path (Join-Path $OutputRoot "PHASE162_CONTROLLER_CONSUME_NEXT_CYCLE_TRIAL_REPORT.md") -Encoding UTF8

[pscustomobject]@{
  status = "PASS"
  output_root = $OutputRoot
  machine_decision = $machineDecision
  next_machine_action = $nextMachineAction
  next_cycle_improvement_proven_partial = $nextCyclePartial
  next_cycle_improvement_proven_for_accept = $nextCycleForAccept
  safety_validated_for_accept = $safetyForAccept
  accepted_state_mutated = $false
  accepted_memory_mutated = $false
  accepted_self_model_mutated = $false
}
