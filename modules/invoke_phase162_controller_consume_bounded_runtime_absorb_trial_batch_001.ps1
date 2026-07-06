param(
  [Parameter(Mandatory=$true)]
  [string]$RuntimeRoot,

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
  ConvertTo-Json -InputObject $Object -Depth 100 | Set-Content -Path $Path -Encoding UTF8
}

if ([string]::IsNullOrWhiteSpace($OutputRoot)) {
  $stamp = Get-Date -Format "yyyyMMdd_HHmmss"
  $OutputRoot = Join-Path (Split-Path -Parent $RuntimeRoot) "PHASE162_CONTROLLER_WITH_BOUNDED_RUNTIME_ABSORB_TRIAL_BATCH_$stamp"
}

New-Item -ItemType Directory -Force -Path $OutputRoot | Out-Null

$trial = Read-Json (Join-Path $RuntimeRoot "bounded_real_runtime_autonomous_absorb_trial_result.json")
$trialValidation = Read-Json (Join-Path $RuntimeRoot "bounded_real_runtime_autonomous_absorb_trial_validation.json")
$decision = Read-Json (Join-Path $RuntimeRoot "runtime_autonomous_absorb_decision.json")
$afterCycle = Read-Json (Join-Path $RuntimeRoot "runtime_after_absorb_cycle.json")

$runtimeOk = (
  ([string]$trialValidation.status -eq "PASS") -and
  ([string]$trial.status -eq "PASS") -and
  ([bool]$trial.bounded_runtime_autonomous_absorb_trial_passed -eq $true) -and
  ([bool]$trial.runtime_overlay_absorb_allowed -eq $true) -and
  ([bool]$trial.runtime_overlay_created -eq $true) -and
  ([bool]$trial.next_cycle_visibility_valid -eq $true) -and
  ([int]$trial.measured_strength_delta -gt 0) -and
  ([bool]$trial.protected_targets_unchanged -eq $true) -and
  ([string]$decision.decision_code -eq "ALLOW_RUNTIME_OVERLAY_ABSORB_DENY_FINAL_ACCEPT")
)

$acceptedCoreSafe = (
  ([bool]$trial.accepted_state_mutated -eq $false) -and
  ([bool]$trial.accepted_memory_mutated -eq $false) -and
  ([bool]$trial.accepted_self_model_mutated -eq $false)
)

$readyForCoreMutationCandidate = ($runtimeOk -and $acceptedCoreSafe -and ([int]$trial.staged_atom_count -gt 0))

$preconditions = [ordered]@{
  runtime_trial_validation_passed = ([string]$trialValidation.status -eq "PASS")
  bounded_runtime_autonomous_absorb_trial_passed = [bool]$trial.bounded_runtime_autonomous_absorb_trial_passed
  runtime_overlay_absorb_allowed = [bool]$trial.runtime_overlay_absorb_allowed
  runtime_overlay_created = [bool]$trial.runtime_overlay_created
  next_cycle_visibility_valid = [bool]$trial.next_cycle_visibility_valid
  measured_strength_delta_positive = ([int]$trial.measured_strength_delta -gt 0)
  protected_targets_unchanged = [bool]$trial.protected_targets_unchanged
  runtime_decision_explained = (-not [string]::IsNullOrWhiteSpace([string]$decision.decision_code))
  accepted_core_not_mutated = [bool]$acceptedCoreSafe
  staged_atom_count_positive = ([int]$trial.staged_atom_count -gt 0)
  controlled_accept_core_mutation_candidate_prepared = $false
}

$blockingForFinalAccept = @(
  "controlled_accept_core_mutation_candidate_not_prepared",
  "pre_accept_snapshot_not_frozen",
  "atomic_accept_write_plan_not_validated",
  "post_mutation_validation_not_bound_to_write_plan"
)

$result = [ordered]@{
  schema = "PHASE162_CONTROLLER_CONSUME_BOUNDED_RUNTIME_ABSORB_TRIAL_BATCH_V1"
  status = if ($readyForCoreMutationCandidate) { "PASS" } else { "BLOCKED_INPUT_NOT_READY" }
  created_at = (Get-Date -Format o)
  loop_target = "builder_lives_creates_atom_or_batch_absorbs_safe_atoms_next_cycle_stronger"
  controller_mode = "AUTONOMOUS_CONTROLLER_NO_ACCEPTED_CORE_WRITES"
  runtime_root = $RuntimeRoot
  preconditions = $preconditions
  batch_size = [int]$trial.batch_size
  staged_atom_count = [int]$trial.staged_atom_count
  blocked_atom_count = [int]$trial.blocked_atom_count
  machine_decision = "ACCEPT_BLOCKED_AUTONOMOUS_CYCLE"
  next_machine_action = if ($readyForCoreMutationCandidate) { "PREPARE_CONTROLLED_ACCEPT_CORE_MUTATION_CANDIDATE_FOR_ATOM_BATCH" } else { "REPAIR_BOUNDED_RUNTIME_ABSORB_TRIAL_BATCH" }
  decision_summary = "Bounded real-runtime autonomous absorb trial passed. Final accept remains blocked until exact controlled accepted-core mutation candidate, pre-snapshot, atomic write plan, and bound post-mutation validation exist."
  blocking_for_final_accept = $blockingForFinalAccept
  consumed_runtime_trial = [ordered]@{
    validation_status = [string]$trialValidation.status
    bounded_runtime_autonomous_absorb_trial_passed = [bool]$trial.bounded_runtime_autonomous_absorb_trial_passed
    runtime_overlay_file_count = [int]$trial.runtime_overlay_file_count
    next_cycle_visibility_valid = [bool]$trial.next_cycle_visibility_valid
    measured_strength_delta = [int]$trial.measured_strength_delta
    selected_next_cycle_action = [string]$afterCycle.selected_next_cycle_action
  }
  accepted_atom_claimed = $false
  accepted_state_mutated = $false
  accepted_memory_mutated = $false
  accepted_self_model_mutated = $false
}

$request = [ordered]@{
  schema = "PHASE162_CONTROLLED_ACCEPT_CORE_MUTATION_CANDIDATE_FOR_ATOM_BATCH_REQUEST_V1"
  status = if ($readyForCoreMutationCandidate) { "READY_TO_BUILD" } else { "BLOCKED" }
  created_at = (Get-Date -Format o)
  reason = "Runtime absorb proof passed. Prepare exact accepted-core mutation candidate, but do not write accepted core yet."
  required_trial = [ordered]@{
    mode = "CANDIDATE_ONLY_NO_ACCEPTED_CORE_WRITES"
    objective = "build exact accepted-memory/self-model/registry mutation set for atom batch with pre-accept fingerprints, atomic write plan, rollback plan, and post-mutation validation binding"
    expected_machine_decision = "ACCEPT_BLOCKED_AUTONOMOUS_CYCLE"
    expected_next_if_pass = "AUTHORIZE_CONTROLLED_ACCEPT_CORE_MUTATION_DRY_RUN"
    forbidden = @(
      "mutate_accepted_memory",
      "mutate_accepted_self_model",
      "mutate_pack_registry",
      "claim_final_accept",
      "claim_real_absorb_complete"
    )
  }
  next_module_to_build = "invoke_phase162_controlled_accept_core_mutation_candidate_for_atom_batch_001.ps1"
}

Write-Json -Path (Join-Path $OutputRoot "controller_consume_bounded_runtime_absorb_trial_batch_result.json") -Object $result
Write-Json -Path (Join-Path $OutputRoot "controlled_accept_core_mutation_candidate_for_atom_batch_request.json") -Object $request

@"
# PHASE162 Controller Consumes Bounded Runtime Absorb Trial Batch Report

## Result

- status: $($result.status)
- machine_decision: $($result.machine_decision)
- next_machine_action: $($result.next_machine_action)
- staged_atom_count: $($result.staged_atom_count)
- measured_strength_delta: $($result.consumed_runtime_trial.measured_strength_delta)
- next_cycle_visibility_valid: $($result.consumed_runtime_trial.next_cycle_visibility_valid)
- accepted_atom_claimed: false
- accepted_state_mutated: false
- accepted_memory_mutated: false
- accepted_self_model_mutated: false

## Meaning

The controller consumed bounded real-runtime autonomous absorb proof.

It now requests an exact controlled accept core mutation candidate. This is still not final accept and still no accepted-core write.

## Why Final Accept Is Still Blocked

$($blockingForFinalAccept | ForEach-Object { "- $_" } | Out-String)
"@ | Set-Content -Path (Join-Path $OutputRoot "PHASE162_CONTROLLER_CONSUME_BOUNDED_RUNTIME_ABSORB_TRIAL_BATCH_REPORT.md") -Encoding UTF8

[pscustomobject]@{
  status = $result.status
  output_root = $OutputRoot
  machine_decision = [string]$result.machine_decision
  next_machine_action = [string]$result.next_machine_action
  staged_atom_count = [int]$result.staged_atom_count
  measured_strength_delta = [int]$result.consumed_runtime_trial.measured_strength_delta
  next_cycle_visibility_valid = [bool]$result.consumed_runtime_trial.next_cycle_visibility_valid
  accepted_state_mutated = $false
  accepted_memory_mutated = $false
  accepted_self_model_mutated = $false
}
