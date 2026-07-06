param(
  [Parameter(Mandatory=$true)]
  [string]$ValidatedRoot,

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
  $OutputRoot = Join-Path (Split-Path -Parent $ValidatedRoot) "PHASE162_CONTROLLER_WITH_VALIDATED_CONTROLLED_ACCEPT_CANDIDATE_BATCH_$stamp"
}

New-Item -ItemType Directory -Force -Path $OutputRoot | Out-Null

$deep = Read-Json (Join-Path $ValidatedRoot "controlled_accept_core_mutation_candidate_deep_validation_result.json")
$deepValidation = Read-Json (Join-Path $ValidatedRoot "controlled_accept_core_mutation_candidate_deep_validation_validation.json")
$deepChecks = Read-Json (Join-Path $ValidatedRoot "controlled_accept_core_mutation_candidate_deep_validation_checks.json")

$candidateRoot = [string]$deep.candidate_root
if (-not (Test-Path -LiteralPath $candidateRoot)) { throw "MISSING_CANDIDATE_ROOT=$candidateRoot" }

$candidate = Read-Json (Join-Path $candidateRoot "controlled_accept_core_mutation_candidate_result.json")
$mutationSet = Read-Json (Join-Path $candidateRoot "controlled_accept_core_mutation_set.json")
$writePlan = Read-Json (Join-Path $candidateRoot "atomic_accept_write_plan.json")
$rollbackPlan = Read-Json (Join-Path $candidateRoot "controlled_accept_core_mutation_rollback_plan.json")
$postBinding = Read-Json (Join-Path $candidateRoot "post_mutation_validation_binding.json")

$deepOk = (
  ([string]$deepValidation.status -eq "PASS") -and
  ([string]$deep.status -eq "PASS") -and
  ([bool]$deep.controlled_accept_core_mutation_candidate_deep_validated -eq $true) -and
  ([bool]$deepChecks.upstream_ok -eq $true) -and
  ([bool]$deepChecks.ops_counts_valid -eq $true) -and
  ([bool]$deepChecks.no_write_modes -eq $true) -and
  ([bool]$deepChecks.final_write_denied_everywhere -eq $true) -and
  ([bool]$deepChecks.write_plan_valid -eq $true) -and
  ([bool]$deepChecks.rollback_plan_valid -eq $true) -and
  ([bool]$deepChecks.post_mutation_validation_binding_valid -eq $true) -and
  ([bool]$deepChecks.accepted_core_safe -eq $true)
)

$candidateOk = (
  ([string]$candidate.status -eq "PASS") -and
  ([bool]$candidate.controlled_accept_core_mutation_candidate_prepared -eq $true) -and
  ([bool]$candidate.protected_targets_unchanged -eq $true) -and
  ([int]$candidate.staged_atom_count -gt 0) -and
  ([string]$writePlan.mode -eq "PLAN_ONLY_NO_WRITE") -and
  ([string]$rollbackPlan.mode -eq "PLAN_ONLY_NO_WRITE") -and
  ([string]$postBinding.mode -eq "BINDING_ONLY_NO_WRITE")
)

$acceptedCoreSafe = (
  ([bool]$deep.accepted_state_mutated -eq $false) -and
  ([bool]$deep.accepted_memory_mutated -eq $false) -and
  ([bool]$deep.accepted_self_model_mutated -eq $false) -and
  ([bool]$candidate.accepted_state_mutated -eq $false) -and
  ([bool]$candidate.accepted_memory_mutated -eq $false) -and
  ([bool]$candidate.accepted_self_model_mutated -eq $false)
)

$readyForDryRun = ($deepOk -and $candidateOk -and $acceptedCoreSafe)

$preconditions = [ordered]@{
  deep_validation_passed = ([string]$deepValidation.status -eq "PASS")
  candidate_deep_validated = [bool]$deep.controlled_accept_core_mutation_candidate_deep_validated
  candidate_prepared = [bool]$candidate.controlled_accept_core_mutation_candidate_prepared
  ops_counts_valid = [bool]$deepChecks.ops_counts_valid
  no_write_modes = [bool]$deepChecks.no_write_modes
  final_write_denied_everywhere = [bool]$deepChecks.final_write_denied_everywhere
  write_plan_valid = [bool]$deepChecks.write_plan_valid
  rollback_plan_valid = [bool]$deepChecks.rollback_plan_valid
  post_mutation_validation_binding_valid = [bool]$deepChecks.post_mutation_validation_binding_valid
  accepted_core_safe = [bool]$acceptedCoreSafe
  protected_targets_unchanged = [bool]$candidate.protected_targets_unchanged
  controlled_accept_dry_run_executed = $false
}

$blockingForFinalAccept = @(
  "controlled_accept_core_mutation_dry_run_not_executed",
  "future_real_write_authorization_not_issued",
  "accepted_core_write_not_authorized_in_controller_consume_step"
)

$result = [ordered]@{
  schema = "PHASE162_CONTROLLER_CONSUME_VALIDATED_CONTROLLED_ACCEPT_CANDIDATE_BATCH_V1"
  status = if ($readyForDryRun) { "PASS" } else { "BLOCKED_INPUT_NOT_READY" }
  created_at = (Get-Date -Format o)
  loop_target = "builder_lives_creates_atom_or_batch_absorbs_safe_atoms_next_cycle_stronger"
  controller_mode = "AUTONOMOUS_CONTROLLER_NO_ACCEPTED_CORE_WRITES"
  validated_root = $ValidatedRoot
  candidate_root = $candidateRoot
  preconditions = $preconditions
  batch_size = [int]$candidate.batch_size
  staged_atom_count = [int]$candidate.staged_atom_count
  blocked_atom_count = [int]$candidate.blocked_atom_count
  machine_decision = "ACCEPT_BLOCKED_AUTONOMOUS_CYCLE"
  next_machine_action = if ($readyForDryRun) { "AUTHORIZE_CONTROLLED_ACCEPT_CORE_MUTATION_DRY_RUN_FOR_ATOM_BATCH" } else { "REPAIR_VALIDATED_CONTROLLED_ACCEPT_CANDIDATE_BATCH" }
  decision_summary = "Validated controlled accept candidate is ready. Controller authorizes dry-run only; accepted-core write remains forbidden."
  blocking_for_final_accept = $blockingForFinalAccept
  consumed_candidate = [ordered]@{
    memory_operation_count = [int]$candidate.memory_operation_count
    self_model_operation_count = [int]$candidate.self_model_operation_count
    registry_operation_count = [int]$candidate.registry_operation_count
    atomic_write_plan_prepared = [bool]$candidate.atomic_write_plan_prepared
    rollback_plan_prepared = [bool]$candidate.rollback_plan_prepared
    post_mutation_validation_binding_prepared = [bool]$candidate.post_mutation_validation_binding_prepared
  }
  accepted_atom_claimed = $false
  accepted_state_mutated = $false
  accepted_memory_mutated = $false
  accepted_self_model_mutated = $false
}

$request = [ordered]@{
  schema = "PHASE162_CONTROLLED_ACCEPT_CORE_MUTATION_DRY_RUN_FOR_ATOM_BATCH_AUTHORIZATION_V1"
  status = if ($readyForDryRun) { "AUTHORIZED_DRY_RUN_ONLY" } else { "BLOCKED" }
  created_at = (Get-Date -Format o)
  authorization_scope = "DRY_RUN_ONLY_NO_ACCEPTED_CORE_WRITES"
  reason = "Deep validated candidate may be exercised in a controlled dry-run. Real accepted-core write is still forbidden."
  candidate_root = $candidateRoot
  required_trial = [ordered]@{
    mode = "CONTROLLED_ACCEPT_CORE_MUTATION_DRY_RUN_ONLY"
    objective = "apply mutation set to temporary copies, run bound post-mutation validation, prove rollback, prove protected targets unchanged"
    expected_machine_decision = "ACCEPT_BLOCKED_AUTONOMOUS_CYCLE"
    expected_next_if_pass = "FEED_CONTROLLED_ACCEPT_CORE_MUTATION_DRY_RUN_BACK_INTO_CONTROLLER"
    forbidden = @(
      "mutate_accepted_memory",
      "mutate_accepted_self_model",
      "mutate_pack_registry",
      "claim_final_accept",
      "claim_real_absorb_complete"
    )
  }
  next_module_to_build = "invoke_phase162_controlled_accept_core_mutation_dry_run_for_atom_batch_001.ps1"
}

Write-Json -Path (Join-Path $OutputRoot "controller_consume_validated_controlled_accept_candidate_batch_result.json") -Object $result
Write-Json -Path (Join-Path $OutputRoot "controlled_accept_core_mutation_dry_run_authorization_for_atom_batch.json") -Object $request

@"
# PHASE162 Controller Consumes Validated Controlled Accept Candidate Batch Report

## Result

- status: $($result.status)
- machine_decision: $($result.machine_decision)
- next_machine_action: $($result.next_machine_action)
- staged_atom_count: $($result.staged_atom_count)
- accepted_atom_claimed: false
- accepted_state_mutated: false
- accepted_memory_mutated: false
- accepted_self_model_mutated: false

## Meaning

Controller consumed the deep-validated controlled accept candidate.

It authorizes only a controlled mutation dry-run. Real accepted-core write is still blocked.

## Why Final Accept Is Still Blocked

$($blockingForFinalAccept | ForEach-Object { "- $_" } | Out-String)
"@ | Set-Content -Path (Join-Path $OutputRoot "PHASE162_CONTROLLER_CONSUME_VALIDATED_CONTROLLED_ACCEPT_CANDIDATE_BATCH_REPORT.md") -Encoding UTF8

[pscustomobject]@{
  status = $result.status
  output_root = $OutputRoot
  machine_decision = [string]$result.machine_decision
  next_machine_action = [string]$result.next_machine_action
  staged_atom_count = [int]$result.staged_atom_count
  accepted_state_mutated = $false
  accepted_memory_mutated = $false
  accepted_self_model_mutated = $false
}
