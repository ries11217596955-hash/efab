param(
  [Parameter(Mandatory=$true)]
  [string]$CandidateRoot,

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
  $Object | ConvertTo-Json -Depth 100 | Set-Content -Path $Path -Encoding UTF8
}

if ([string]::IsNullOrWhiteSpace($OutputRoot)) {
  $stamp = Get-Date -Format "yyyyMMdd_HHmmss"
  $OutputRoot = Join-Path (Split-Path -Parent $CandidateRoot) "PHASE162_CONTROLLER_WITH_CONTROLLED_ACCEPT_CANDIDATE_BATCH_$stamp"
}

New-Item -ItemType Directory -Force -Path $OutputRoot | Out-Null

$candidate = Read-Json (Join-Path $CandidateRoot "controlled_accept_candidate_dry_run_result.json")
$validation = Read-Json (Join-Path $CandidateRoot "controlled_accept_candidate_dry_run_validation.json")
$deltas = @(Read-Json (Join-Path $CandidateRoot "controlled_accept_candidate_atom_deltas.json"))
$blocked = @(Read-Json (Join-Path $CandidateRoot "controlled_accept_candidate_blocked_atoms.json"))
$rollbackPlan = Read-Json (Join-Path $CandidateRoot "controlled_accept_candidate_rollback_plan.json")
$commitPlan = Read-Json (Join-Path $CandidateRoot "controlled_accept_candidate_commit_plan.json")

$candidateValid = (
  ([string]$validation.status -eq "PASS") -and
  ([string]$candidate.status -eq "PASS") -and
  ([bool]$candidate.batch_aware -eq $true) -and
  ([int]$candidate.staged_atom_count -gt 0) -and
  ([bool]$candidate.controlled_accept_candidate_created -eq $true) -and
  ([bool]$candidate.accept_commit_plan_staged -eq $true) -and
  ([bool]$candidate.rollback_plan_staged -eq $true)
)

$acceptedCoreSafe = (
  ([bool]$candidate.accepted_state_mutated -eq $false) -and
  ([bool]$candidate.accepted_memory_mutated -eq $false) -and
  ([bool]$candidate.accepted_self_model_mutated -eq $false)
)

$perAtomOk = (
  ($deltas.Count -eq [int]$candidate.staged_atom_count) -and
  ($blocked.Count -eq [int]$candidate.blocked_atom_count)
)

$rollbackRehearsed = [bool]$rollbackPlan.rollback_tested
$postAcceptValidationRun = $false
$realRuntimeAutonomousAbsorbProven = $false

$preconditions = [ordered]@{
  candidate_validation_passed = ([string]$validation.status -eq "PASS")
  candidate_batch_aware = [bool]$candidate.batch_aware
  staged_atom_count_positive = ([int]$candidate.staged_atom_count -gt 0)
  per_atom_deltas_match = [bool]$perAtomOk
  commit_plan_staged = [bool]$candidate.accept_commit_plan_staged
  rollback_plan_staged = [bool]$candidate.rollback_plan_staged
  rollback_rehearsed = [bool]$rollbackRehearsed
  post_accept_validation_run = [bool]$postAcceptValidationRun
  real_runtime_autonomous_absorb_proven = [bool]$realRuntimeAutonomousAbsorbProven
  accepted_core_not_mutated = [bool]$acceptedCoreSafe
}

$blockingForFinalAccept = @()
if (-not $rollbackRehearsed) { $blockingForFinalAccept += "post_accept_rollback_not_rehearsed" }
if (-not $postAcceptValidationRun) { $blockingForFinalAccept += "post_accept_validation_not_run" }
if (-not $realRuntimeAutonomousAbsorbProven) { $blockingForFinalAccept += "real_runtime_autonomous_absorb_not_proven" }
$blockingForFinalAccept += "accepted_core_write_not_authorized_in_controller_consume_step"

$readyForRollbackRehearsal = ($candidateValid -and $acceptedCoreSafe -and $perAtomOk)

$result = [ordered]@{
  schema = "PHASE162_CONTROLLER_CONSUME_CONTROLLED_ACCEPT_CANDIDATE_BATCH_V1"
  status = if ($readyForRollbackRehearsal) { "PASS" } else { "BLOCKED_INPUT_NOT_READY" }
  created_at = (Get-Date -Format o)
  loop_target = "builder_lives_creates_atom_or_batch_absorbs_safe_atoms_next_cycle_stronger"
  controller_mode = "AUTONOMOUS_CONTROLLER_NO_ACCEPTED_CORE_WRITES"
  candidate_root = $CandidateRoot
  preconditions = $preconditions
  batch_size = [int]$candidate.batch_size
  staged_atom_count = [int]$candidate.staged_atom_count
  blocked_atom_count = [int]$candidate.blocked_atom_count
  machine_decision = "ACCEPT_BLOCKED_AUTONOMOUS_CYCLE"
  next_machine_action = if ($readyForRollbackRehearsal) { "REHEARSE_POST_ACCEPT_ROLLBACK_FOR_ATOM_BATCH" } else { "REPAIR_CONTROLLED_ACCEPT_CANDIDATE_BATCH" }
  decision_summary = "Controlled accept candidate is valid as dry-run, batch-aware, and staged per atom. Final accept remains blocked until rollback rehearsal and post-accept validation are proven."
  blocking_for_final_accept = $blockingForFinalAccept
  consumed_candidate = [ordered]@{
    validation_status = [string]$validation.status
    batch_aware = [bool]$candidate.batch_aware
    batch_size = [int]$candidate.batch_size
    staged_atom_count = [int]$candidate.staged_atom_count
    blocked_atom_count = [int]$candidate.blocked_atom_count
    final_accept_ready = [bool]$candidate.final_accept_ready
    commit_mode = [string]$commitPlan.commit_mode
    rollback_mode = [string]$rollbackPlan.rollback_mode
  }
  accepted_atom_claimed = $false
  accepted_state_mutated = $false
  accepted_memory_mutated = $false
  accepted_self_model_mutated = $false
}

$request = [ordered]@{
  schema = "PHASE162_POST_ACCEPT_ROLLBACK_REHEARSAL_FOR_ATOM_BATCH_REQUEST_V1"
  status = if ($readyForRollbackRehearsal) { "READY_TO_BUILD" } else { "BLOCKED" }
  created_at = (Get-Date -Format o)
  reason = "Controlled accept candidate dry-run is valid. Before any accepted core write, rehearse rollback using staged per-atom deltas."
  required_trial = [ordered]@{
    mode = "DRY_RUN_ONLY_NO_ACCEPTED_CORE_WRITES"
    batch_policy = "rehearse rollback for staged eligible atoms; preserve blocked atom reasons"
    objective = "prove staged accept deltas can be applied to temporary overlay and rolled back cleanly"
    expected_machine_decision = "ACCEPT_BLOCKED_AUTONOMOUS_CYCLE"
    forbidden = @(
      "mutate_accepted_memory",
      "mutate_accepted_self_model",
      "mutate_pack_registry",
      "claim_final_accept",
      "claim_real_absorb_complete"
    )
  }
  next_module_to_build = "invoke_phase162_post_accept_rollback_rehearsal_for_atom_batch_001.ps1"
}

Write-Json -Path (Join-Path $OutputRoot "controller_consume_controlled_accept_candidate_batch_result.json") -Object $result
Write-Json -Path (Join-Path $OutputRoot "post_accept_rollback_rehearsal_for_atom_batch_request.json") -Object $request

@"
# PHASE162 Controller Consumes Controlled Accept Candidate Batch Report

## Result

- status: $($result.status)
- machine_decision: $($result.machine_decision)
- next_machine_action: $($result.next_machine_action)
- batch_size: $($result.batch_size)
- staged_atom_count: $($result.staged_atom_count)
- blocked_atom_count: $($result.blocked_atom_count)
- accepted_atom_claimed: false
- accepted_state_mutated: false
- accepted_memory_mutated: false
- accepted_self_model_mutated: false

## Meaning

The autonomous controller consumed the validated batch-aware controlled accept candidate.

It does not permit final accept yet. It moves to rollback rehearsal for the staged per-atom deltas.

## Why Final Accept Is Still Blocked

$($blockingForFinalAccept | ForEach-Object { "- $_" } | Out-String)
"@ | Set-Content -Path (Join-Path $OutputRoot "PHASE162_CONTROLLER_CONSUME_CONTROLLED_ACCEPT_CANDIDATE_BATCH_REPORT.md") -Encoding UTF8

[pscustomobject]@{
  status = $result.status
  output_root = $OutputRoot
  machine_decision = [string]$result.machine_decision
  next_machine_action = [string]$result.next_machine_action
  batch_size = [int]$result.batch_size
  staged_atom_count = [int]$result.staged_atom_count
  blocked_atom_count = [int]$result.blocked_atom_count
  accepted_state_mutated = $false
  accepted_memory_mutated = $false
  accepted_self_model_mutated = $false
}
