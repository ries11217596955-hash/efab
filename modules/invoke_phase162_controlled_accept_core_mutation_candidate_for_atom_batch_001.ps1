param(
  [Parameter(Mandatory=$true)]
  [string]$ControllerRoot,

  [Parameter(Mandatory=$true)]
  [string]$RepoRoot,

  [string]$OutputRoot = ""
)

$ErrorActionPreference = "Stop"

function Resolve-ExistingPath {
  param([string]$MaybePath, [string]$RepoRoot)

  if (Test-Path -LiteralPath $MaybePath) {
    return (Get-Item -LiteralPath $MaybePath).FullName
  }

  $joined = Join-Path $RepoRoot $MaybePath
  if (Test-Path -LiteralPath $joined) {
    return (Get-Item -LiteralPath $joined).FullName
  }

  throw "MISSING_PATH=$MaybePath"
}

function Read-Json {
  param([string]$Path)
  if (-not (Test-Path -LiteralPath $Path)) { throw "MISSING_FILE=$Path" }
  return Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json
}

function Ensure-Dir {
  param([string]$Path)
  if ($Path -and -not (Test-Path -LiteralPath $Path)) {
    New-Item -ItemType Directory -Force -Path $Path | Out-Null
  }
}

function Write-Json {
  param([string]$Path, [object]$Object)
  Ensure-Dir (Split-Path -Parent $Path)
  ConvertTo-Json -InputObject $Object -Depth 100 | Set-Content -Path $Path -Encoding UTF8
}

function Write-JsonArray {
  param([string]$Path, [object[]]$Array)
  Ensure-Dir (Split-Path -Parent $Path)
  if ($Array.Count -eq 0) {
    "[]" | Set-Content -Path $Path -Encoding UTF8
  } else {
    ConvertTo-Json -InputObject $Array -Depth 100 | Set-Content -Path $Path -Encoding UTF8
  }
}

function Get-PathFingerprint {
  param([string]$Path)

  if (-not (Test-Path -LiteralPath $Path)) {
    return [ordered]@{ exists = $false; length = 0; sha256 = "ABSENT" }
  }

  $item = Get-Item -LiteralPath $Path

  if ($item.PSIsContainer) {
    return [ordered]@{ exists = $true; length = -1; sha256 = "DIRECTORY" }
  }

  return [ordered]@{
    exists = $true
    length = $item.Length
    sha256 = (Get-FileHash -Algorithm SHA256 -LiteralPath $Path).Hash
  }
}

if ([string]::IsNullOrWhiteSpace($OutputRoot)) {
  $stamp = Get-Date -Format "yyyyMMdd_HHmmss"
  $OutputRoot = Join-Path (Split-Path -Parent $ControllerRoot) "PHASE162_CONTROLLED_ACCEPT_CORE_MUTATION_CANDIDATE_FOR_ATOM_BATCH_$stamp"
}

New-Item -ItemType Directory -Force -Path $OutputRoot | Out-Null

$controller = Read-Json (Join-Path $ControllerRoot "controller_consume_bounded_runtime_absorb_trial_batch_result.json")
$controllerValidation = Read-Json (Join-Path $ControllerRoot "controller_consume_bounded_runtime_absorb_trial_batch_validation.json")
$request = Read-Json (Join-Path $ControllerRoot "controlled_accept_core_mutation_candidate_for_atom_batch_request.json")

$runtimeRoot = Resolve-ExistingPath -MaybePath ([string]$controller.runtime_root) -RepoRoot $RepoRoot
$runtime = Read-Json (Join-Path $runtimeRoot "bounded_real_runtime_autonomous_absorb_trial_result.json")
$runtimeValidation = Read-Json (Join-Path $runtimeRoot "bounded_real_runtime_autonomous_absorb_trial_validation.json")
$runtimeDecision = Read-Json (Join-Path $runtimeRoot "runtime_autonomous_absorb_decision.json")

$candidateRoot = Resolve-ExistingPath -MaybePath ([string]$runtime.candidate_root) -RepoRoot $RepoRoot
$candidate = Read-Json (Join-Path $candidateRoot "controlled_accept_candidate_dry_run_result.json")
$candidateValidation = Read-Json (Join-Path $candidateRoot "controlled_accept_candidate_dry_run_validation.json")
$deltas = @(Read-Json (Join-Path $candidateRoot "controlled_accept_candidate_atom_deltas.json"))
$blocked = @(Read-Json (Join-Path $candidateRoot "controlled_accept_candidate_blocked_atoms.json"))

$inputReady = (
  ([string]$controllerValidation.status -eq "PASS") -and
  ([string]$controller.next_machine_action -eq "PREPARE_CONTROLLED_ACCEPT_CORE_MUTATION_CANDIDATE_FOR_ATOM_BATCH") -and
  ([string]$request.status -eq "READY_TO_BUILD") -and
  ([string]$runtimeValidation.status -eq "PASS") -and
  ([bool]$runtime.bounded_runtime_autonomous_absorb_trial_passed -eq $true) -and
  ([int]$runtime.measured_strength_delta -gt 0) -and
  ([bool]$runtime.protected_targets_unchanged -eq $true) -and
  ([string]$runtimeDecision.decision_code -eq "ALLOW_RUNTIME_OVERLAY_ABSORB_DENY_FINAL_ACCEPT") -and
  ([string]$candidateValidation.status -eq "PASS") -and
  ([int]$candidate.staged_atom_count -gt 0) -and
  ($deltas.Count -eq [int]$candidate.staged_atom_count)
)

$targetFiles = @(
  "reports/self_development/accepted_change_memory_snapshot.json",
  "reports/self_development/SELF_MODEL_ACTIVE_MAP.json",
  "packs/registry.json"
)

$preAcceptFingerprints = [ordered]@{}
foreach ($rel in $targetFiles) {
  $preAcceptFingerprints[$rel] = Get-PathFingerprint -Path (Join-Path $RepoRoot $rel)
}

$memoryOps = @()
$selfModelOps = @()
$registryOps = @()
$atomIndex = 0

foreach ($d in $deltas) {
  $atomIndex += 1

  $memoryOps += [ordered]@{
    operation_id = "memory_append_atom_$atomIndex"
    operation = "append_accepted_atom_memory_record"
    target = "reports/self_development/accepted_change_memory_snapshot.json"
    atom_id = [string]$d.atom_id
    source_freeze_root = [string]$d.source_freeze_root
    payload = [ordered]@{
      atom_id = [string]$d.atom_id
      accepted_state = "CONTROLLED_ACCEPT_PENDING_EXECUTION"
      source_freeze_root = [string]$d.source_freeze_root
      runtime_absorb_trial_root = $runtimeRoot
      measured_strength_delta = [int]$runtime.measured_strength_delta
      evidence = @(
        "freeze_evidence",
        "policy_gate",
        "rollback_rehearsal",
        "post_accept_validation_dry_run",
        "bounded_runtime_autonomous_absorb_trial"
      )
    }
  }

  $selfModelOps += [ordered]@{
    operation_id = "self_model_append_atom_$atomIndex"
    operation = "append_absorbed_atom_capability_note"
    target = "reports/self_development/SELF_MODEL_ACTIVE_MAP.json"
    atom_id = [string]$d.atom_id
    payload = [ordered]@{
      atom_id = [string]$d.atom_id
      capability_delta = "admission_can_prepare_controlled_accept_for_batch_atom"
      visible_to_next_cycle = $true
      runtime_absorb_trial_root = $runtimeRoot
    }
  }

  $registryOps += [ordered]@{
    operation_id = "registry_record_atom_$atomIndex"
    operation = "record_accepted_atom_reference_after_final_authorization"
    target = "packs/registry.json"
    atom_id = [string]$d.atom_id
    payload = [ordered]@{
      atom_id = [string]$d.atom_id
      admission_status = "CONTROLLED_ACCEPT_PENDING_EXECUTION"
      final_write_allowed_now = $false
    }
  }
}

$mutationSet = [ordered]@{
  schema = "PHASE162_CONTROLLED_ACCEPT_CORE_MUTATION_SET_FOR_ATOM_BATCH_V1"
  status = if ($inputReady) { "PASS" } else { "BLOCKED_INPUT_NOT_READY" }
  mode = "CANDIDATE_ONLY_NO_ACCEPTED_CORE_WRITES"
  batch_size = [int]$candidate.batch_size
  staged_atom_count = [int]$candidate.staged_atom_count
  blocked_atom_count = [int]$candidate.blocked_atom_count
  accepted_memory_operations = $memoryOps
  accepted_self_model_operations = $selfModelOps
  registry_operations = $registryOps
  blocked_atoms_preserved = $blocked
  final_write_allowed_now = $false
}

$atomicWritePlan = [ordered]@{
  schema = "PHASE162_ATOMIC_ACCEPT_WRITE_PLAN_FOR_ATOM_BATCH_V1"
  status = if ($inputReady) { "PASS" } else { "BLOCKED_INPUT_NOT_READY" }
  mode = "PLAN_ONLY_NO_WRITE"
  order = @(
    "freeze_pre_accept_fingerprints",
    "apply_accepted_memory_operations",
    "apply_accepted_self_model_operations",
    "apply_registry_operations",
    "run_bound_post_mutation_validation",
    "if_validation_fails_run_rollback_plan",
    "emit_accept_or_rollback_proof"
  )
  target_files = $targetFiles
  staged_atom_count = [int]$candidate.staged_atom_count
  atomicity_rule = "all_operations_pass_or_rollback"
  final_write_allowed_now = $false
}

$rollbackPlan = [ordered]@{
  schema = "PHASE162_CONTROLLED_ACCEPT_CORE_MUTATION_ROLLBACK_PLAN_FOR_ATOM_BATCH_V1"
  status = if ($inputReady) { "PASS" } else { "BLOCKED_INPUT_NOT_READY" }
  mode = "PLAN_ONLY_NO_WRITE"
  pre_accept_fingerprints = $preAcceptFingerprints
  rollback_actions = @(
    "restore_accepted_change_memory_snapshot_from_pre_accept_snapshot",
    "restore_SELF_MODEL_ACTIVE_MAP_from_pre_accept_snapshot",
    "restore_packs_registry_from_pre_accept_snapshot",
    "rerun_bound_post_mutation_validation",
    "emit_rollback_proof"
  )
  final_write_allowed_now = $false
}

$postMutationValidationBinding = [ordered]@{
  schema = "PHASE162_POST_MUTATION_VALIDATION_BINDING_FOR_ATOM_BATCH_V1"
  status = if ($inputReady) { "PASS" } else { "BLOCKED_INPUT_NOT_READY" }
  mode = "BINDING_ONLY_NO_WRITE"
  must_run_after_future_write = @(
    "validate_accepted_memory_contains_each_atom_once",
    "validate_self_model_contains_each_atom_once",
    "validate_registry_consistency_or_explicit_registry_noop",
    "validate_next_cycle_can_read_accepted_atom_batch",
    "validate_no_unplanned_files_changed",
    "validate_rollback_plan_available"
  )
  expected_atom_count = [int]$candidate.staged_atom_count
  bound_to_mutation_set = "controlled_accept_core_mutation_set.json"
  bound_to_atomic_write_plan = "atomic_accept_write_plan.json"
  final_write_allowed_now = $false
}

$afterFingerprints = [ordered]@{}
foreach ($rel in $targetFiles) {
  $afterFingerprints[$rel] = Get-PathFingerprint -Path (Join-Path $RepoRoot $rel)
}

$protectedUnchanged = $true
foreach ($rel in $targetFiles) {
  $b = $preAcceptFingerprints[$rel]
  $a = $afterFingerprints[$rel]

  if (
    ([bool]$b.exists -ne [bool]$a.exists) -or
    ([int64]$b.length -ne [int64]$a.length) -or
    ([string]$b.sha256 -ne [string]$a.sha256)
  ) {
    $protectedUnchanged = $false
  }
}

$candidatePrepared = (
  $inputReady -and
  ($memoryOps.Count -eq [int]$candidate.staged_atom_count) -and
  ($selfModelOps.Count -eq [int]$candidate.staged_atom_count) -and
  ($registryOps.Count -eq [int]$candidate.staged_atom_count) -and
  $protectedUnchanged
)

$result = [ordered]@{
  schema = "PHASE162_CONTROLLED_ACCEPT_CORE_MUTATION_CANDIDATE_FOR_ATOM_BATCH_RESULT_V1"
  status = if ($candidatePrepared) { "PASS" } else { "FAIL" }
  created_at = (Get-Date -Format o)
  controller_root = $ControllerRoot
  runtime_root = $runtimeRoot
  candidate_root = $candidateRoot
  batch_size = [int]$candidate.batch_size
  staged_atom_count = [int]$candidate.staged_atom_count
  blocked_atom_count = [int]$candidate.blocked_atom_count
  controlled_accept_core_mutation_candidate_prepared = [bool]$candidatePrepared
  pre_accept_fingerprints_frozen = $true
  atomic_write_plan_prepared = ($atomicWritePlan.status -eq "PASS")
  rollback_plan_prepared = ($rollbackPlan.status -eq "PASS")
  post_mutation_validation_binding_prepared = ($postMutationValidationBinding.status -eq "PASS")
  mutation_set_prepared = ($mutationSet.status -eq "PASS")
  memory_operation_count = $memoryOps.Count
  self_model_operation_count = $selfModelOps.Count
  registry_operation_count = $registryOps.Count
  protected_targets_unchanged = [bool]$protectedUnchanged
  final_accept_ready = $false
  machine_decision = "ACCEPT_BLOCKED_AUTONOMOUS_CYCLE"
  next_machine_action = "VALIDATE_CONTROLLED_ACCEPT_CORE_MUTATION_CANDIDATE_FOR_ATOM_BATCH"
  why_final_accept_denied = @(
    "controlled_accept_core_mutation_candidate_not_validated_yet",
    "future_write_authorization_not_issued",
    "accepted_core_write_not_authorized_in_candidate_step"
  )
  before_fingerprints = $preAcceptFingerprints
  after_fingerprints = $afterFingerprints
  accepted_atom_claimed = $false
  accepted_state_mutated = $false
  accepted_memory_mutated = $false
  accepted_self_model_mutated = $false
}

Write-Json -Path (Join-Path $OutputRoot "pre_accept_fingerprints.json") -Object $preAcceptFingerprints
Write-Json -Path (Join-Path $OutputRoot "after_candidate_fingerprints.json") -Object $afterFingerprints
Write-Json -Path (Join-Path $OutputRoot "controlled_accept_core_mutation_set.json") -Object $mutationSet
Write-Json -Path (Join-Path $OutputRoot "atomic_accept_write_plan.json") -Object $atomicWritePlan
Write-Json -Path (Join-Path $OutputRoot "controlled_accept_core_mutation_rollback_plan.json") -Object $rollbackPlan
Write-Json -Path (Join-Path $OutputRoot "post_mutation_validation_binding.json") -Object $postMutationValidationBinding
Write-Json -Path (Join-Path $OutputRoot "controlled_accept_core_mutation_candidate_result.json") -Object $result

@"
# PHASE162 Controlled Accept Core Mutation Candidate For Atom Batch Report

## Result

- status: $($result.status)
- controlled_accept_core_mutation_candidate_prepared: $($result.controlled_accept_core_mutation_candidate_prepared)
- staged_atom_count: $($result.staged_atom_count)
- memory_operation_count: $($result.memory_operation_count)
- self_model_operation_count: $($result.self_model_operation_count)
- registry_operation_count: $($result.registry_operation_count)
- pre_accept_fingerprints_frozen: $($result.pre_accept_fingerprints_frozen)
- atomic_write_plan_prepared: $($result.atomic_write_plan_prepared)
- rollback_plan_prepared: $($result.rollback_plan_prepared)
- post_mutation_validation_binding_prepared: $($result.post_mutation_validation_binding_prepared)
- protected_targets_unchanged: $($result.protected_targets_unchanged)
- final_accept_ready: false
- next_machine_action: $($result.next_machine_action)
- accepted_atom_claimed: false
- accepted_state_mutated: false
- accepted_memory_mutated: false
- accepted_self_model_mutated: false

## Meaning

This prepares the exact accepted-core mutation candidate for the atom batch.

No accepted-core file is written in this step.
"@ | Set-Content -Path (Join-Path $OutputRoot "PHASE162_CONTROLLED_ACCEPT_CORE_MUTATION_CANDIDATE_FOR_ATOM_BATCH_REPORT.md") -Encoding UTF8

[pscustomobject]@{
  status = $result.status
  output_root = $OutputRoot
  controlled_accept_core_mutation_candidate_prepared = [bool]$result.controlled_accept_core_mutation_candidate_prepared
  staged_atom_count = [int]$result.staged_atom_count
  memory_operation_count = [int]$result.memory_operation_count
  self_model_operation_count = [int]$result.self_model_operation_count
  registry_operation_count = [int]$result.registry_operation_count
  protected_targets_unchanged = [bool]$result.protected_targets_unchanged
  next_machine_action = [string]$result.next_machine_action
  accepted_state_mutated = $false
  accepted_memory_mutated = $false
  accepted_self_model_mutated = $false
}
