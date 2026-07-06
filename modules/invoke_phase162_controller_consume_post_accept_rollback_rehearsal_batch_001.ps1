param(
  [Parameter(Mandatory=$true)]
  [string]$RollbackRoot,

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
  $OutputRoot = Join-Path (Split-Path -Parent $RollbackRoot) "PHASE162_CONTROLLER_WITH_POST_ACCEPT_ROLLBACK_REHEARSAL_BATCH_$stamp"
}

New-Item -ItemType Directory -Force -Path $OutputRoot | Out-Null

$rehearsal = Read-Json (Join-Path $RollbackRoot "post_accept_rollback_rehearsal_result.json")
$validation = Read-Json (Join-Path $RollbackRoot "post_accept_rollback_rehearsal_validation.json")
$rollback = Read-Json (Join-Path $RollbackRoot "rollback_rehearsal_result.json")
$overlay = Read-Json (Join-Path $RollbackRoot "overlay_apply_state.json")

$rollbackOk = (
  ([string]$validation.status -eq "PASS") -and
  ([string]$rehearsal.status -eq "PASS") -and
  ([bool]$rehearsal.rollback_rehearsal_passed -eq $true) -and
  ([bool]$rehearsal.overlay_apply_passed -eq $true) -and
  ([int]$rehearsal.overlay_file_count_before_rollback -ge 4) -and
  ([bool]$rehearsal.overlay_removed_after_rollback -eq $true) -and
  ([bool]$rehearsal.protected_targets_unchanged -eq $true) -and
  ([string]$rollback.status -eq "PASS") -and
  ([string]$overlay.status -eq "PASS")
)

$acceptedCoreSafe = (
  ([bool]$rehearsal.accepted_state_mutated -eq $false) -and
  ([bool]$rehearsal.accepted_memory_mutated -eq $false) -and
  ([bool]$rehearsal.accepted_self_model_mutated -eq $false)
)

$readyForPostAcceptValidationDryRun = ($rollbackOk -and $acceptedCoreSafe -and ([int]$rehearsal.staged_atom_count -gt 0))

$preconditions = [ordered]@{
  rollback_validation_passed = ([string]$validation.status -eq "PASS")
  rollback_rehearsal_passed = [bool]$rehearsal.rollback_rehearsal_passed
  overlay_apply_passed = [bool]$rehearsal.overlay_apply_passed
  overlay_file_count_before_rollback = [int]$rehearsal.overlay_file_count_before_rollback
  overlay_removed_after_rollback = [bool]$rehearsal.overlay_removed_after_rollback
  protected_targets_unchanged = [bool]$rehearsal.protected_targets_unchanged
  staged_atom_count_positive = ([int]$rehearsal.staged_atom_count -gt 0)
  accepted_core_not_mutated = [bool]$acceptedCoreSafe
  post_accept_validation_run = $false
  real_runtime_autonomous_absorb_proven = $false
}

$blockingForFinalAccept = @(
  "post_accept_validation_not_run",
  "real_runtime_autonomous_absorb_not_proven",
  "accepted_core_write_not_authorized_in_controller_consume_step"
)

$result = [ordered]@{
  schema = "PHASE162_CONTROLLER_CONSUME_POST_ACCEPT_ROLLBACK_REHEARSAL_BATCH_V1"
  status = if ($readyForPostAcceptValidationDryRun) { "PASS" } else { "BLOCKED_INPUT_NOT_READY" }
  created_at = (Get-Date -Format o)
  loop_target = "builder_lives_creates_atom_or_batch_absorbs_safe_atoms_next_cycle_stronger"
  controller_mode = "AUTONOMOUS_CONTROLLER_NO_ACCEPTED_CORE_WRITES"
  rollback_root = $RollbackRoot
  preconditions = $preconditions
  batch_size = [int]$rehearsal.batch_size
  staged_atom_count = [int]$rehearsal.staged_atom_count
  blocked_atom_count = [int]$rehearsal.blocked_atom_count
  machine_decision = "ACCEPT_BLOCKED_AUTONOMOUS_CYCLE"
  next_machine_action = if ($readyForPostAcceptValidationDryRun) { "BUILD_POST_ACCEPT_VALIDATION_DRY_RUN_FOR_ATOM_BATCH" } else { "REPAIR_POST_ACCEPT_ROLLBACK_REHEARSAL_BATCH" }
  decision_summary = "Rollback rehearsal passed. Final accept remains blocked until post-accept validation dry-run and real-runtime autonomous absorb proof exist."
  blocking_for_final_accept = $blockingForFinalAccept
  accepted_atom_claimed = $false
  accepted_state_mutated = $false
  accepted_memory_mutated = $false
  accepted_self_model_mutated = $false
}

$request = [ordered]@{
  schema = "PHASE162_POST_ACCEPT_VALIDATION_DRY_RUN_FOR_ATOM_BATCH_REQUEST_V1"
  status = if ($readyForPostAcceptValidationDryRun) { "READY_TO_BUILD" } else { "BLOCKED" }
  created_at = (Get-Date -Format o)
  reason = "Rollback rehearsal passed. Now validate what would be checked immediately after a controlled accepted-core write, still in dry-run only."
  required_trial = [ordered]@{
    mode = "DRY_RUN_ONLY_NO_ACCEPTED_CORE_WRITES"
    objective = "simulate post-accept checks for batch staged deltas: schema, registry consistency, memory/self-model consistency, next-cycle visibility"
    expected_machine_decision = "ACCEPT_BLOCKED_AUTONOMOUS_CYCLE"
    forbidden = @(
      "mutate_accepted_memory",
      "mutate_accepted_self_model",
      "mutate_pack_registry",
      "claim_final_accept",
      "claim_real_absorb_complete"
    )
  }
  next_module_to_build = "invoke_phase162_post_accept_validation_dry_run_for_atom_batch_001.ps1"
}

Write-Json -Path (Join-Path $OutputRoot "controller_consume_post_accept_rollback_rehearsal_batch_result.json") -Object $result
Write-Json -Path (Join-Path $OutputRoot "post_accept_validation_dry_run_for_atom_batch_request.json") -Object $request

@"
# PHASE162 Controller Consumes Post-Accept Rollback Rehearsal Batch Report

## Result

- status: $($result.status)
- machine_decision: $($result.machine_decision)
- next_machine_action: $($result.next_machine_action)
- staged_atom_count: $($result.staged_atom_count)
- rollback_rehearsal_passed: $($result.preconditions.rollback_rehearsal_passed)
- protected_targets_unchanged: $($result.preconditions.protected_targets_unchanged)
- accepted_atom_claimed: false
- accepted_state_mutated: false
- accepted_memory_mutated: false
- accepted_self_model_mutated: false

## Meaning

The controller consumed rollback rehearsal proof.

It now moves to post-accept validation dry-run. Final accept is still blocked.

## Why Final Accept Is Still Blocked

$($blockingForFinalAccept | ForEach-Object { "- $_" } | Out-String)
"@ | Set-Content -Path (Join-Path $OutputRoot "PHASE162_CONTROLLER_CONSUME_POST_ACCEPT_ROLLBACK_REHEARSAL_BATCH_REPORT.md") -Encoding UTF8

[pscustomobject]@{
  status = $result.status
  output_root = $OutputRoot
  machine_decision = [string]$result.machine_decision
  next_machine_action = [string]$result.next_machine_action
  staged_atom_count = [int]$result.staged_atom_count
  rollback_rehearsal_passed = [bool]$result.preconditions.rollback_rehearsal_passed
  protected_targets_unchanged = [bool]$result.preconditions.protected_targets_unchanged
  accepted_state_mutated = $false
  accepted_memory_mutated = $false
  accepted_self_model_mutated = $false
}
