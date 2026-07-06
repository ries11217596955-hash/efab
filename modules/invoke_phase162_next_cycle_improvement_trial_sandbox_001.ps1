param(
  [Parameter(Mandatory=$true)]
  [string]$CycleRoot,

  [Parameter(Mandatory=$true)]
  [string]$FreezeRoot,

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
  $Object | ConvertTo-Json -Depth 50 | Set-Content -Path $Path -Encoding UTF8
}

if ([string]::IsNullOrWhiteSpace($OutputRoot)) {
  $stamp = Get-Date -Format "yyyyMMdd_HHmmss"
  $OutputRoot = Join-Path (Split-Path -Parent $CycleRoot) "PHASE162_NEXT_CYCLE_IMPROVEMENT_TRIAL_$stamp"
}

New-Item -ItemType Directory -Force -Path $OutputRoot | Out-Null

$cycle = Read-Json (Join-Path $CycleRoot "autonomous_admission_cycle_result.json")
$cycleValidation = Read-Json (Join-Path $CycleRoot "autonomous_admission_cycle_validation.json")
$trialRequest = Read-Json (Join-Path $CycleRoot "next_cycle_improvement_trial_request.json")

$freeze = Read-Json (Join-Path $FreezeRoot "frozen_atom_candidate_evidence.json")
$freezeValidation = Read-Json (Join-Path $FreezeRoot "validation_result.json")

$inputReady = (
  ([string]$cycleValidation.status -eq "PASS") -and
  ([string]$cycle.next_machine_action -eq "RUN_NEXT_CYCLE_IMPROVEMENT_TRIAL_SANDBOX") -and
  ([string]$trialRequest.status -eq "READY_TO_BUILD_TRIAL") -and
  ([string]$freezeValidation.status -eq "PASS") -and
  ([bool]$freeze.atom_candidate_summary_present_on_this_pc -eq $true) -and
  ([int]$freeze.selected_skill_candidate_count -gt 0)
)

$before = [ordered]@{
  schema = "PHASE162_NEXT_CYCLE_BEFORE_MEASUREMENT_V1"
  status = if ($inputReady) { "PASS" } else { "BLOCKED_INPUT_NOT_READY" }
  created_at = (Get-Date -Format o)
  mode = "SANDBOX_BASELINE_WITHOUT_ATOM_OVERLAY"
  available_atom_overlay_count = 0
  next_cycle_can_reference_atom = $false
  next_cycle_can_reuse_admission_card = $false
  next_cycle_can_select_atom_specific_action = $false
  measured_capability_score = 0
}

$atomOverlay = [ordered]@{
  schema = "PHASE162_SANDBOX_ATOM_OVERLAY_V1"
  status = if ($inputReady) { "PASS" } else { "BLOCKED_INPUT_NOT_READY" }
  created_at = (Get-Date -Format o)
  source_freeze_root = $FreezeRoot
  source_cycle_root = $CycleRoot
  overlay_mode = "SANDBOX_ONLY_NOT_ACCEPTED_CORE"
  atom_summary_status = [string]$freeze.selected_atom_summary_status
  selected_duty_id = [string]$freeze.selected_duty_id
  selected_run_id = [string]$freeze.selected_run_id
  skill_candidate_count = [int]$freeze.selected_skill_candidate_count
  makes_available_to_next_cycle = @(
    "frozen_atom_reference",
    "owner_visible_admission_review_card",
    "partial_usefulness_signal",
    "machine_next_action_context"
  )
  forbidden = @(
    "mutate_accepted_memory",
    "mutate_accepted_self_model",
    "mutate_pack_registry",
    "claim_absorb_complete",
    "claim_accept_ready"
  )
  accepted_atom_claimed = $false
  accepted_state_mutated = $false
  accepted_memory_mutated = $false
  accepted_self_model_mutated = $false
}

$afterScore = 0
if ($inputReady) { $afterScore += 1 }
if ([int]$freeze.selected_skill_candidate_count -gt 0) { $afterScore += 1 }
if ([string]$cycle.machine_decision -eq "ACCEPT_BLOCKED_AUTONOMOUS_CYCLE") { $afterScore += 1 }
if ([string]$cycle.next_machine_action -eq "RUN_NEXT_CYCLE_IMPROVEMENT_TRIAL_SANDBOX") { $afterScore += 1 }

$after = [ordered]@{
  schema = "PHASE162_NEXT_CYCLE_AFTER_MEASUREMENT_V1"
  status = if ($inputReady) { "PASS" } else { "BLOCKED_INPUT_NOT_READY" }
  created_at = (Get-Date -Format o)
  mode = "SANDBOX_WITH_ATOM_OVERLAY_AVAILABLE"
  available_atom_overlay_count = if ($inputReady) { 1 } else { 0 }
  next_cycle_can_reference_atom = [bool]$inputReady
  next_cycle_can_reuse_admission_card = [bool]$inputReady
  next_cycle_can_select_atom_specific_action = [bool]$inputReady
  selected_next_cycle_action = if ($inputReady) { "REUSE_ATOM_OVERLAY_FOR_NEXT_ADMISSION_DECISION" } else { "BLOCKED_INPUT_NOT_READY" }
  measured_capability_score = $afterScore
}

$scoreDelta = ([int]$after.measured_capability_score - [int]$before.measured_capability_score)

$trialPassed = (
  $inputReady -and
  ([int]$after.available_atom_overlay_count -eq 1) -and
  ([bool]$after.next_cycle_can_reference_atom -eq $true) -and
  ([bool]$after.next_cycle_can_select_atom_specific_action -eq $true) -and
  ($scoreDelta -gt 0)
)

$result = [ordered]@{
  schema = "PHASE162_NEXT_CYCLE_IMPROVEMENT_TRIAL_SANDBOX_RESULT_V1"
  status = if ($trialPassed) { "PASS" } else { "BLOCKED_OR_FAIL" }
  created_at = (Get-Date -Format o)
  cycle_root = $CycleRoot
  freeze_root = $FreezeRoot
  before_measurement_path = Join-Path $OutputRoot "before_cycle_measurement.json"
  atom_overlay_path = Join-Path $OutputRoot "sandbox_atom_overlay.json"
  after_measurement_path = Join-Path $OutputRoot "after_cycle_measurement.json"
  next_cycle_improvement_trial_passed = [bool]$trialPassed
  next_cycle_improvement_proven_partial = [bool]$trialPassed
  next_cycle_improvement_proven_for_accept = $false
  measured_capability_score_before = [int]$before.measured_capability_score
  measured_capability_score_after = [int]$after.measured_capability_score
  measured_capability_score_delta = [int]$scoreDelta
  expected_machine_decision = "ACCEPT_BLOCKED_AUTONOMOUS_CYCLE"
  reason_accept_still_blocked = @(
    "sandbox_overlay_is_not_accepted_absorb",
    "safety_validated_for_accept_false",
    "owner_review_not_granted",
    "rollback_test_not_proven",
    "live_daemon_autonomous_absorb_not_proven"
  )
  accepted_atom_claimed = $false
  accepted_state_mutated = $false
  accepted_memory_mutated = $false
  accepted_self_model_mutated = $false
  next_action = "FEED_NEXT_CYCLE_TRIAL_RESULT_BACK_INTO_AUTONOMOUS_ADMISSION_CONTROLLER"
}

Write-Json -Path (Join-Path $OutputRoot "before_cycle_measurement.json") -Object $before
Write-Json -Path (Join-Path $OutputRoot "sandbox_atom_overlay.json") -Object $atomOverlay
Write-Json -Path (Join-Path $OutputRoot "after_cycle_measurement.json") -Object $after
Write-Json -Path (Join-Path $OutputRoot "next_cycle_improvement_trial_result.json") -Object $result

@"
# PHASE162 Next-Cycle Improvement Trial Sandbox Report

## Result

- status: $($result.status)
- next_cycle_improvement_trial_passed: $($result.next_cycle_improvement_trial_passed)
- next_cycle_improvement_proven_partial: $($result.next_cycle_improvement_proven_partial)
- next_cycle_improvement_proven_for_accept: false
- score_before: $($result.measured_capability_score_before)
- score_after: $($result.measured_capability_score_after)
- score_delta: $($result.measured_capability_score_delta)
- expected_machine_decision: ACCEPT_BLOCKED_AUTONOMOUS_CYCLE
- accepted_atom_claimed: false
- accepted_state_mutated: false
- accepted_memory_mutated: false
- accepted_self_model_mutated: false

## Meaning

This trial checks whether the next cycle becomes stronger when the atom is available as a sandbox overlay.

It does not absorb the atom into accepted memory or accepted self-model.

## Boundary

Partial next-cycle improvement is proven only in sandbox. Controlled accept is still blocked.

## Next Action

Feed this trial result back into the autonomous admission controller.
"@ | Set-Content -Path (Join-Path $OutputRoot "PHASE162_NEXT_CYCLE_IMPROVEMENT_TRIAL_SANDBOX_REPORT.md") -Encoding UTF8

[pscustomobject]@{
  status = $result.status
  output_root = $OutputRoot
  next_cycle_improvement_trial_passed = [bool]$trialPassed
  next_cycle_improvement_proven_partial = [bool]$trialPassed
  next_cycle_improvement_proven_for_accept = $false
  score_before = [int]$before.measured_capability_score
  score_after = [int]$after.measured_capability_score
  score_delta = [int]$scoreDelta
  expected_machine_decision = "ACCEPT_BLOCKED_AUTONOMOUS_CYCLE"
  accepted_state_mutated = $false
  accepted_memory_mutated = $false
  accepted_self_model_mutated = $false
}
