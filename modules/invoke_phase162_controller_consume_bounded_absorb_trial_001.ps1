param(
  [Parameter(Mandatory=$true)]
  [string]$PolicyRoot,

  [Parameter(Mandatory=$true)]
  [string]$AbsorbTrialRoot,

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
  $Object | ConvertTo-Json -Depth 90 | Set-Content -Path $Path -Encoding UTF8
}

if ([string]::IsNullOrWhiteSpace($OutputRoot)) {
  $stamp = Get-Date -Format "yyyyMMdd_HHmmss"
  $OutputRoot = Join-Path (Split-Path -Parent $AbsorbTrialRoot) "PHASE162_CONTROLLER_WITH_BOUNDED_ABSORB_TRIAL_$stamp"
}

New-Item -ItemType Directory -Force -Path $OutputRoot | Out-Null

$policy = Read-Json (Join-Path $PolicyRoot "autonomous_accept_policy_gate_result.json")
$policyValidation = Read-Json (Join-Path $PolicyRoot "autonomous_accept_policy_gate_validation.json")

$trial = Read-Json (Join-Path $AbsorbTrialRoot "bounded_absorb_trial_result.json")
$trialValidation = Read-Json (Join-Path $AbsorbTrialRoot "bounded_absorb_trial_validation.json")

$boundedAbsorbPassed = (
  ([string]$trialValidation.status -eq "PASS") -and
  ([bool]$trial.sandbox_absorb_trial_passed -eq $true) -and
  ([bool]$trial.next_cycle_stronger_after_sandbox_absorb -eq $true) -and
  ([bool]$trial.denial_explanation_available -eq $true) -and
  ([int]$trial.measured_strength_delta -gt 0)
)

$policyOk = (
  ([string]$policyValidation.status -eq "PASS") -and
  ([bool]$policy.policy_gate_present -eq $true) -and
  ([bool]$policy.policy_granted_for_bounded_absorb_trial -eq $true)
)

$acceptedCoreSafe = (
  ([bool]$trial.accepted_state_mutated -eq $false) -and
  ([bool]$trial.accepted_memory_mutated -eq $false) -and
  ([bool]$trial.accepted_self_model_mutated -eq $false)
)

$preconditions = [ordered]@{
  autonomous_policy_gate_ok = $policyOk
  bounded_absorb_trial_passed = $boundedAbsorbPassed
  next_cycle_stronger_after_sandbox_absorb = [bool]$trial.next_cycle_stronger_after_sandbox_absorb
  denial_explanation_available = [bool]$trial.denial_explanation_available
  measured_strength_delta_positive = ([int]$trial.measured_strength_delta -gt 0)
  accepted_core_not_mutated = $acceptedCoreSafe
  final_accept_ready = $false
}

$blockingForFinalAccept = @(
  "controlled_accept_candidate_not_built",
  "accepted_memory_delta_not_staged",
  "accepted_self_model_delta_not_staged",
  "accept_commit_plan_not_validated",
  "post_accept_rollback_not_rehearsed",
  "real_runtime_autonomous_absorb_not_proven"
)

$nextMachineAction = if ($policyOk -and $boundedAbsorbPassed -and $acceptedCoreSafe) {
  "BUILD_CONTROLLED_ACCEPT_CANDIDATE_DRY_RUN"
} else {
  "REPAIR_BOUNDED_ABSORB_TRIAL_INPUTS"
}

$result = [ordered]@{
  schema = "PHASE162_CONTROLLER_CONSUME_BOUNDED_ABSORB_TRIAL_V1"
  status = if ($policyOk -and $boundedAbsorbPassed -and $acceptedCoreSafe) { "PASS" } else { "BLOCKED_INPUT_NOT_READY" }
  created_at = (Get-Date -Format o)
  loop_target = "builder_lives_creates_atom_absorbs_safe_atom_next_cycle_stronger"
  controller_mode = "AUTONOMOUS_CONTROLLER_NO_ACCEPTED_CORE_WRITES"
  policy_root = $PolicyRoot
  absorb_trial_root = $AbsorbTrialRoot
  preconditions = $preconditions
  machine_decision = "ACCEPT_BLOCKED_AUTONOMOUS_CYCLE"
  next_machine_action = $nextMachineAction
  blocking_for_final_accept = $blockingForFinalAccept
  decision_summary = "Sandbox absorb rehearsal passed and made the next cycle stronger, but final accept is still blocked until a controlled accept candidate is staged and validated."
  consumed_absorb_trial = [ordered]@{
    validation_status = [string]$trialValidation.status
    sandbox_absorb_trial_passed = [bool]$trial.sandbox_absorb_trial_passed
    next_cycle_stronger_after_sandbox_absorb = [bool]$trial.next_cycle_stronger_after_sandbox_absorb
    denial_explanation_available = [bool]$trial.denial_explanation_available
    measured_strength_delta = [int]$trial.measured_strength_delta
    final_accept_ready = [bool]$trial.final_accept_ready
    why_final_accept_denied = $trial.why_final_accept_denied
  }
  accepted_atom_claimed = $false
  accepted_state_mutated = $false
  accepted_memory_mutated = $false
  accepted_self_model_mutated = $false
}

$request = [ordered]@{
  schema = "PHASE162_CONTROLLED_ACCEPT_CANDIDATE_DRY_RUN_REQUEST_V1"
  status = if ($nextMachineAction -eq "BUILD_CONTROLLED_ACCEPT_CANDIDATE_DRY_RUN") { "READY_TO_BUILD" } else { "BLOCKED" }
  created_at = (Get-Date -Format o)
  reason = "Bounded sandbox absorb trial passed. Build a dry-run candidate that stages exact accepted-memory/self-model deltas without applying them."
  required_trial = [ordered]@{
    mode = "DRY_RUN_ONLY_NO_ACCEPTED_CORE_WRITES"
    objective = "stage exact accept deltas, validate schema, validate rollback plan, explain remaining denial"
    expected_machine_decision = "ACCEPT_BLOCKED_AUTONOMOUS_CYCLE"
    forbidden = @(
      "mutate_accepted_memory",
      "mutate_accepted_self_model",
      "mutate_pack_registry",
      "claim_final_accept",
      "claim_absorb_complete_in_core"
    )
  }
  next_module_to_build = "invoke_phase162_controlled_accept_candidate_dry_run_001.ps1"
}

Write-Json -Path (Join-Path $OutputRoot "controller_with_bounded_absorb_trial_result.json") -Object $result
Write-Json -Path (Join-Path $OutputRoot "controlled_accept_candidate_dry_run_request.json") -Object $request

@"
# PHASE162 Controller Consumes Bounded Absorb Trial Report

## Result

- status: $($result.status)
- machine_decision: $($result.machine_decision)
- next_machine_action: $($result.next_machine_action)
- bounded_absorb_trial_passed: $boundedAbsorbPassed
- next_cycle_stronger_after_sandbox_absorb: $($trial.next_cycle_stronger_after_sandbox_absorb)
- denial_explanation_available: $($trial.denial_explanation_available)
- measured_strength_delta: $($trial.measured_strength_delta)
- final_accept_ready: false
- accepted_atom_claimed: false
- accepted_state_mutated: false
- accepted_memory_mutated: false
- accepted_self_model_mutated: false

## Meaning

The autonomous controller consumed the bounded sandbox absorb rehearsal.

It now moves to building a controlled accept candidate in dry-run mode. This is the next bridge from sandbox rehearsal toward real absorb.

## Why Final Accept Is Still Blocked

$($blockingForFinalAccept | ForEach-Object { "- $_" } | Out-String)
"@ | Set-Content -Path (Join-Path $OutputRoot "PHASE162_CONTROLLER_CONSUME_BOUNDED_ABSORB_TRIAL_REPORT.md") -Encoding UTF8

[pscustomobject]@{
  status = $result.status
  output_root = $OutputRoot
  machine_decision = [string]$result.machine_decision
  next_machine_action = [string]$result.next_machine_action
  bounded_absorb_trial_passed = $boundedAbsorbPassed
  next_cycle_stronger_after_sandbox_absorb = [bool]$trial.next_cycle_stronger_after_sandbox_absorb
  denial_explanation_available = [bool]$trial.denial_explanation_available
  measured_strength_delta = [int]$trial.measured_strength_delta
  accepted_state_mutated = $false
  accepted_memory_mutated = $false
  accepted_self_model_mutated = $false
}
