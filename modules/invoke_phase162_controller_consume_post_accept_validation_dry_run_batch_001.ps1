param(
  [Parameter(Mandatory=$true)]
  [string]$PostAcceptRoot,

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
  $OutputRoot = Join-Path (Split-Path -Parent $PostAcceptRoot) "PHASE162_CONTROLLER_WITH_POST_ACCEPT_VALIDATION_DRY_RUN_BATCH_$stamp"
}

New-Item -ItemType Directory -Force -Path $OutputRoot | Out-Null

$postAccept = Read-Json (Join-Path $PostAcceptRoot "post_accept_validation_dry_run_result.json")
$postAcceptValidation = Read-Json (Join-Path $PostAcceptRoot "post_accept_validation_dry_run_validation.json")
$postAcceptChecks = Read-Json (Join-Path $PostAcceptRoot "post_accept_validation_checks.json")

$postAcceptOk = (
  ([string]$postAcceptValidation.status -eq "PASS") -and
  ([string]$postAccept.status -eq "PASS") -and
  ([bool]$postAccept.post_accept_validation_dry_run_passed -eq $true) -and
  ([bool]$postAccept.memory_schema_valid -eq $true) -and
  ([bool]$postAccept.self_model_schema_valid -eq $true) -and
  ([bool]$postAccept.registry_consistency_valid -eq $true) -and
  ([bool]$postAccept.next_cycle_visibility_valid -eq $true) -and
  ([bool]$postAccept.protected_targets_unchanged -eq $true) -and
  ([int]$postAccept.staged_atom_count -gt 0)
)

$acceptedCoreSafe = (
  ([bool]$postAccept.accepted_state_mutated -eq $false) -and
  ([bool]$postAccept.accepted_memory_mutated -eq $false) -and
  ([bool]$postAccept.accepted_self_model_mutated -eq $false)
)

$readyForBoundedRuntimeTrial = ($postAcceptOk -and $acceptedCoreSafe)

$preconditions = [ordered]@{
  post_accept_validation_status_pass = ([string]$postAcceptValidation.status -eq "PASS")
  post_accept_validation_dry_run_passed = [bool]$postAccept.post_accept_validation_dry_run_passed
  memory_schema_valid = [bool]$postAccept.memory_schema_valid
  self_model_schema_valid = [bool]$postAccept.self_model_schema_valid
  registry_consistency_valid = [bool]$postAccept.registry_consistency_valid
  next_cycle_visibility_valid = [bool]$postAccept.next_cycle_visibility_valid
  protected_targets_unchanged = [bool]$postAccept.protected_targets_unchanged
  staged_atom_count_positive = ([int]$postAccept.staged_atom_count -gt 0)
  accepted_core_not_mutated = [bool]$acceptedCoreSafe
  real_runtime_autonomous_absorb_proven = $false
}

$blockingForFinalAccept = @(
  "real_runtime_autonomous_absorb_not_proven",
  "accepted_core_write_not_authorized_in_controller_consume_step"
)

$result = [ordered]@{
  schema = "PHASE162_CONTROLLER_CONSUME_POST_ACCEPT_VALIDATION_DRY_RUN_BATCH_V1"
  status = if ($readyForBoundedRuntimeTrial) { "PASS" } else { "BLOCKED_INPUT_NOT_READY" }
  created_at = (Get-Date -Format o)
  loop_target = "builder_lives_creates_atom_or_batch_absorbs_safe_atoms_next_cycle_stronger"
  controller_mode = "AUTONOMOUS_CONTROLLER_NO_ACCEPTED_CORE_WRITES"
  post_accept_root = $PostAcceptRoot
  preconditions = $preconditions
  batch_size = [int]$postAccept.batch_size
  staged_atom_count = [int]$postAccept.staged_atom_count
  blocked_atom_count = [int]$postAccept.blocked_atom_count
  machine_decision = "ACCEPT_BLOCKED_AUTONOMOUS_CYCLE"
  next_machine_action = if ($readyForBoundedRuntimeTrial) { "BUILD_BOUNDED_REAL_RUNTIME_AUTONOMOUS_ABSORB_TRIAL_FOR_ATOM_BATCH" } else { "REPAIR_POST_ACCEPT_VALIDATION_DRY_RUN_BATCH" }
  decision_summary = "Post-accept validation dry-run passed. Final accept remains blocked until bounded real-runtime autonomous absorb is proven."
  blocking_for_final_accept = $blockingForFinalAccept
  consumed_post_accept_validation = [ordered]@{
    validation_status = [string]$postAcceptValidation.status
    post_accept_validation_dry_run_passed = [bool]$postAccept.post_accept_validation_dry_run_passed
    next_cycle_visibility_valid = [bool]$postAccept.next_cycle_visibility_valid
    protected_targets_unchanged = [bool]$postAccept.protected_targets_unchanged
    overlay_file_count = [int]$postAccept.overlay_file_count
  }
  accepted_atom_claimed = $false
  accepted_state_mutated = $false
  accepted_memory_mutated = $false
  accepted_self_model_mutated = $false
}

$request = [ordered]@{
  schema = "PHASE162_BOUNDED_REAL_RUNTIME_AUTONOMOUS_ABSORB_TRIAL_FOR_ATOM_BATCH_REQUEST_V1"
  status = if ($readyForBoundedRuntimeTrial) { "READY_TO_BUILD" } else { "BLOCKED" }
  created_at = (Get-Date -Format o)
  reason = "All dry-run barriers passed. Prove bounded real-runtime autonomous absorb behavior for batch without accepted-core mutation."
  required_trial = [ordered]@{
    mode = "BOUNDED_RUNTIME_TRIAL_NO_ACCEPTED_CORE_WRITES"
    objective = "run a bounded Builder-like runtime cycle that sees staged atom batch, performs autonomous absorb decision in sandbox/runtime overlay, and proves next-cycle visibility/strength"
    expected_machine_decision = "ACCEPT_BLOCKED_AUTONOMOUS_CYCLE"
    expected_next_if_pass = "PREPARE_CONTROLLED_ACCEPT_CORE_MUTATION_CANDIDATE"
    forbidden = @(
      "mutate_accepted_memory",
      "mutate_accepted_self_model",
      "mutate_pack_registry",
      "claim_final_accept",
      "claim_real_absorb_complete",
      "run_unbounded_daemon"
    )
  }
  next_module_to_build = "invoke_phase162_bounded_real_runtime_autonomous_absorb_trial_for_atom_batch_001.ps1"
}

Write-Json -Path (Join-Path $OutputRoot "controller_consume_post_accept_validation_dry_run_batch_result.json") -Object $result
Write-Json -Path (Join-Path $OutputRoot "bounded_real_runtime_autonomous_absorb_trial_for_atom_batch_request.json") -Object $request

@"
# PHASE162 Controller Consumes Post-Accept Validation Dry-Run Batch Report

## Result

- status: $($result.status)
- machine_decision: $($result.machine_decision)
- next_machine_action: $($result.next_machine_action)
- staged_atom_count: $($result.staged_atom_count)
- post_accept_validation_dry_run_passed: $($result.preconditions.post_accept_validation_dry_run_passed)
- next_cycle_visibility_valid: $($result.preconditions.next_cycle_visibility_valid)
- protected_targets_unchanged: $($result.preconditions.protected_targets_unchanged)
- accepted_atom_claimed: false
- accepted_state_mutated: false
- accepted_memory_mutated: false
- accepted_self_model_mutated: false

## Meaning

The controller consumed post-accept validation dry-run proof.

It now moves to bounded real-runtime autonomous absorb trial for atom batch. Final accept is still blocked.

## Why Final Accept Is Still Blocked

$($blockingForFinalAccept | ForEach-Object { "- $_" } | Out-String)
"@ | Set-Content -Path (Join-Path $OutputRoot "PHASE162_CONTROLLER_CONSUME_POST_ACCEPT_VALIDATION_DRY_RUN_BATCH_REPORT.md") -Encoding UTF8

[pscustomobject]@{
  status = $result.status
  output_root = $OutputRoot
  machine_decision = [string]$result.machine_decision
  next_machine_action = [string]$result.next_machine_action
  staged_atom_count = [int]$result.staged_atom_count
  post_accept_validation_dry_run_passed = [bool]$result.preconditions.post_accept_validation_dry_run_passed
  next_cycle_visibility_valid = [bool]$result.preconditions.next_cycle_visibility_valid
  accepted_state_mutated = $false
  accepted_memory_mutated = $false
  accepted_self_model_mutated = $false
}
