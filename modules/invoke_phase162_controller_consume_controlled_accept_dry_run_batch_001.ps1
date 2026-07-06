param(
  [Parameter(Mandatory=$true)]
  [string]$DryRunRoot,

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
  $OutputRoot = Join-Path (Split-Path -Parent $DryRunRoot) "PHASE162_CONTROLLER_WITH_CONTROLLED_ACCEPT_DRY_RUN_BATCH_$stamp"
}

New-Item -ItemType Directory -Force -Path $OutputRoot | Out-Null

$dryRun = Read-Json (Join-Path $DryRunRoot "controlled_accept_core_mutation_dry_run_result.json")
$dryRunValidation = Read-Json (Join-Path $DryRunRoot "controlled_accept_core_mutation_dry_run_validation.json")
$postValidation = Read-Json (Join-Path $DryRunRoot "bound_post_mutation_validation_dry_run_result.json")
$applied = Read-Json (Join-Path $DryRunRoot "controlled_accept_core_mutation_dry_run_applied_state.json")

$candidateRoot = [string]$dryRun.candidate_root
if (-not (Test-Path -LiteralPath $candidateRoot)) { throw "MISSING_CANDIDATE_ROOT=$candidateRoot" }

$candidate = Read-Json (Join-Path $candidateRoot "controlled_accept_core_mutation_candidate_result.json")
$mutationSet = Read-Json (Join-Path $candidateRoot "controlled_accept_core_mutation_set.json")
$writePlan = Read-Json (Join-Path $candidateRoot "atomic_accept_write_plan.json")
$rollbackPlan = Read-Json (Join-Path $candidateRoot "controlled_accept_core_mutation_rollback_plan.json")
$postBinding = Read-Json (Join-Path $candidateRoot "post_mutation_validation_binding.json")

$dryRunOk = (
  ([string]$dryRunValidation.status -eq "PASS") -and
  ([string]$dryRun.status -eq "PASS") -and
  ([bool]$dryRun.controlled_accept_core_mutation_dry_run_passed -eq $true) -and
  ([bool]$dryRun.bound_post_mutation_validation_passed -eq $true) -and
  ([bool]$dryRun.rollback_restored_temp_state -eq $true) -and
  ([bool]$dryRun.protected_targets_unchanged -eq $true) -and
  ([int]$dryRun.staged_atom_count -gt 0)
)

$noWriteDryRun = (
  ([bool]$applied.accepted_core_write -eq $false) -and
  ([bool]$postValidation.accepted_core_write -eq $false)
)

$candidateOk = (
  ([string]$candidate.status -eq "PASS") -and
  ([bool]$candidate.controlled_accept_core_mutation_candidate_prepared -eq $true) -and
  ([bool]$candidate.atomic_write_plan_prepared -eq $true) -and
  ([bool]$candidate.rollback_plan_prepared -eq $true) -and
  ([bool]$candidate.post_mutation_validation_binding_prepared -eq $true) -and
  ([int]$candidate.staged_atom_count -eq [int]$dryRun.staged_atom_count)
)

$plansReady = (
  ([string]$writePlan.status -eq "PASS") -and
  ([string]$rollbackPlan.status -eq "PASS") -and
  ([string]$postBinding.status -eq "PASS") -and
  ([string]$writePlan.atomicity_rule -eq "all_operations_pass_or_rollback")
)

$acceptedCoreSafe = (
  ([bool]$dryRun.accepted_state_mutated -eq $false) -and
  ([bool]$dryRun.accepted_memory_mutated -eq $false) -and
  ([bool]$dryRun.accepted_self_model_mutated -eq $false)
)

$readyForExecution = ($dryRunOk -and $noWriteDryRun -and $candidateOk -and $plansReady -and $acceptedCoreSafe)

$preconditions = [ordered]@{
  controlled_accept_core_mutation_dry_run_passed = [bool]$dryRun.controlled_accept_core_mutation_dry_run_passed
  bound_post_mutation_validation_passed = [bool]$dryRun.bound_post_mutation_validation_passed
  rollback_restored_temp_state = [bool]$dryRun.rollback_restored_temp_state
  protected_targets_unchanged = [bool]$dryRun.protected_targets_unchanged
  dry_run_no_accepted_core_write = [bool]$noWriteDryRun
  candidate_prepared = [bool]$candidate.controlled_accept_core_mutation_candidate_prepared
  atomic_write_plan_prepared = [bool]$candidate.atomic_write_plan_prepared
  rollback_plan_prepared = [bool]$candidate.rollback_plan_prepared
  post_mutation_validation_binding_prepared = [bool]$candidate.post_mutation_validation_binding_prepared
  atomicity_rule_valid = ([string]$writePlan.atomicity_rule -eq "all_operations_pass_or_rollback")
  accepted_core_safe = [bool]$acceptedCoreSafe
  real_execution_done = $false
}

$blockingForFinalAccept = @(
  "real_controlled_accept_core_mutation_not_executed_yet",
  "post_real_mutation_validation_not_run_yet",
  "final_accept_proof_not_emitted_yet"
)

$result = [ordered]@{
  schema = "PHASE162_CONTROLLER_CONSUME_CONTROLLED_ACCEPT_CORE_MUTATION_DRY_RUN_BATCH_V1"
  status = if ($readyForExecution) { "PASS" } else { "BLOCKED_INPUT_NOT_READY" }
  created_at = (Get-Date -Format o)
  loop_target = "builder_lives_creates_atom_or_batch_absorbs_safe_atoms_next_cycle_stronger"
  controller_mode = "AUTONOMOUS_CONTROLLER_AUTHORIZES_ONE_SHOT_EXECUTION"
  dry_run_root = $DryRunRoot
  candidate_root = $candidateRoot
  preconditions = $preconditions
  batch_size = [int]$dryRun.batch_size
  staged_atom_count = [int]$dryRun.staged_atom_count
  machine_decision = "ACCEPT_BLOCKED_AUTONOMOUS_CYCLE"
  next_machine_action = if ($readyForExecution) { "EXECUTE_CONTROLLED_ACCEPT_CORE_MUTATION_FOR_ATOM_BATCH" } else { "REPAIR_CONTROLLED_ACCEPT_CORE_MUTATION_DRY_RUN_BATCH" }
  execution_authorization_status = if ($readyForExecution) { "AUTHORIZED_ONE_SHOT_CONTROLLED_ACCEPT_CORE_MUTATION" } else { "BLOCKED" }
  decision_summary = "Controlled accept dry-run passed. Controller authorizes exactly one bounded execution step. Final accept is still not claimed until real write and post-write validation pass."
  blocking_for_final_accept = $blockingForFinalAccept
  accepted_atom_claimed = $false
  accepted_state_mutated = $false
  accepted_memory_mutated = $false
  accepted_self_model_mutated = $false
}

$authorization = [ordered]@{
  schema = "PHASE162_ONE_SHOT_CONTROLLED_ACCEPT_CORE_MUTATION_EXECUTION_AUTHORIZATION_FOR_ATOM_BATCH_V1"
  status = if ($readyForExecution) { "AUTHORIZED" } else { "BLOCKED" }
  created_at = (Get-Date -Format o)
  authorization_scope = "ONE_SHOT_ACCEPTED_CORE_WRITE_WITH_ATOMIC_PLAN_AND_ROLLBACK"
  candidate_root = $candidateRoot
  dry_run_root = $DryRunRoot
  staged_atom_count = [int]$dryRun.staged_atom_count
  required_inputs = [ordered]@{
    mutation_set = "controlled_accept_core_mutation_set.json"
    atomic_write_plan = "atomic_accept_write_plan.json"
    rollback_plan = "controlled_accept_core_mutation_rollback_plan.json"
    post_mutation_validation_binding = "post_mutation_validation_binding.json"
    pre_accept_fingerprints = "pre_accept_fingerprints.json"
  }
  constraints = @(
    "execute_once_only",
    "write_only_declared_targets",
    "snapshot_before_write",
    "apply_all_operations_or_rollback",
    "run_bound_post_mutation_validation",
    "emit_accept_or_rollback_proof",
    "do_not_claim_final_accept_if_validation_fails"
  )
  next_module_to_build = "invoke_phase162_execute_controlled_accept_core_mutation_for_atom_batch_001.ps1"
}

Write-Json -Path (Join-Path $OutputRoot "controller_consume_controlled_accept_core_mutation_dry_run_batch_result.json") -Object $result
Write-Json -Path (Join-Path $OutputRoot "one_shot_controlled_accept_core_mutation_execution_authorization_for_atom_batch.json") -Object $authorization

@"
# PHASE162 Controller Consumes Controlled Accept Core Mutation Dry-Run Batch Report

## Result

- status: $($result.status)
- machine_decision: $($result.machine_decision)
- next_machine_action: $($result.next_machine_action)
- execution_authorization_status: $($result.execution_authorization_status)
- staged_atom_count: $($result.staged_atom_count)
- accepted_atom_claimed: false
- accepted_state_mutated: false
- accepted_memory_mutated: false
- accepted_self_model_mutated: false

## Meaning

Controller consumed the controlled accept dry-run proof.

It authorizes one bounded execution step only. Final accept is still not claimed before real write and post-write validation.

## Why Final Accept Is Still Blocked

$($blockingForFinalAccept | ForEach-Object { "- $_" } | Out-String)
"@ | Set-Content -Path (Join-Path $OutputRoot "PHASE162_CONTROLLER_CONSUME_CONTROLLED_ACCEPT_CORE_MUTATION_DRY_RUN_BATCH_REPORT.md") -Encoding UTF8

[pscustomobject]@{
  status = $result.status
  output_root = $OutputRoot
  machine_decision = [string]$result.machine_decision
  next_machine_action = [string]$result.next_machine_action
  execution_authorization_status = [string]$result.execution_authorization_status
  staged_atom_count = [int]$result.staged_atom_count
  accepted_state_mutated = $false
  accepted_memory_mutated = $false
  accepted_self_model_mutated = $false
}
