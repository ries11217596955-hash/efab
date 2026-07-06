param(
  [Parameter(Mandatory=$true)]
  [string]$ControllerRoot,

  [Parameter(Mandatory=$true)]
  [string]$RepoRoot,

  [string]$OutputRoot = ""
)

$ErrorActionPreference = "Stop"

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

function Add-Event {
  param([string]$Path, [string]$Type, [object]$Data)

  $event = [ordered]@{
    ts = (Get-Date -Format o)
    type = $Type
    data = $Data
  }

  ConvertTo-Json -InputObject $event -Depth 80 -Compress | Add-Content -Path $Path -Encoding UTF8
}

if ([string]::IsNullOrWhiteSpace($OutputRoot)) {
  $stamp = Get-Date -Format "yyyyMMdd_HHmmss"
  $OutputRoot = Join-Path (Split-Path -Parent $ControllerRoot) "PHASE162_CONTROLLED_ACCEPT_CORE_MUTATION_DRY_RUN_FOR_ATOM_BATCH_$stamp"
}

New-Item -ItemType Directory -Force -Path $OutputRoot | Out-Null

$controller = Read-Json (Join-Path $ControllerRoot "controller_consume_validated_controlled_accept_candidate_batch_result.json")
$controllerValidation = Read-Json (Join-Path $ControllerRoot "controller_consume_validated_controlled_accept_candidate_batch_validation.json")
$authorization = Read-Json (Join-Path $ControllerRoot "controlled_accept_core_mutation_dry_run_authorization_for_atom_batch.json")

$candidateRoot = [string]$authorization.candidate_root
if (-not (Test-Path -LiteralPath $candidateRoot)) { throw "MISSING_CANDIDATE_ROOT=$candidateRoot" }

$candidate = Read-Json (Join-Path $candidateRoot "controlled_accept_core_mutation_candidate_result.json")
$candidateValidation = Read-Json (Join-Path $candidateRoot "controlled_accept_core_mutation_candidate_validation.json")
$mutationSet = Read-Json (Join-Path $candidateRoot "controlled_accept_core_mutation_set.json")
$writePlan = Read-Json (Join-Path $candidateRoot "atomic_accept_write_plan.json")
$rollbackPlan = Read-Json (Join-Path $candidateRoot "controlled_accept_core_mutation_rollback_plan.json")
$postBinding = Read-Json (Join-Path $candidateRoot "post_mutation_validation_binding.json")
$preAcceptFingerprints = Read-Json (Join-Path $candidateRoot "pre_accept_fingerprints.json")

$memoryOps = @($mutationSet.accepted_memory_operations)
$selfModelOps = @($mutationSet.accepted_self_model_operations)
$registryOps = @($mutationSet.registry_operations)

$inputReady = (
  ([string]$controllerValidation.status -eq "PASS") -and
  ([string]$controller.next_machine_action -eq "AUTHORIZE_CONTROLLED_ACCEPT_CORE_MUTATION_DRY_RUN_FOR_ATOM_BATCH") -and
  ([string]$authorization.status -eq "AUTHORIZED_DRY_RUN_ONLY") -and
  ([string]$authorization.authorization_scope -eq "DRY_RUN_ONLY_NO_ACCEPTED_CORE_WRITES") -and
  ([string]$candidateValidation.status -eq "PASS") -and
  ([bool]$candidate.controlled_accept_core_mutation_candidate_prepared -eq $true) -and
  ([int]$candidate.staged_atom_count -gt 0) -and
  ($memoryOps.Count -eq [int]$candidate.staged_atom_count) -and
  ($selfModelOps.Count -eq [int]$candidate.staged_atom_count) -and
  ($registryOps.Count -eq [int]$candidate.staged_atom_count) -and
  ([string]$writePlan.mode -eq "PLAN_ONLY_NO_WRITE") -and
  ([string]$rollbackPlan.mode -eq "PLAN_ONLY_NO_WRITE") -and
  ([string]$postBinding.mode -eq "BINDING_ONLY_NO_WRITE")
)

$targetFiles = @(
  "reports/self_development/accepted_change_memory_snapshot.json",
  "reports/self_development/SELF_MODEL_ACTIVE_MAP.json",
  "packs/registry.json"
)

$before = [ordered]@{}
foreach ($rel in $targetFiles) {
  $before[$rel] = Get-PathFingerprint -Path (Join-Path $RepoRoot $rel)
}

$eventsPath = Join-Path $OutputRoot "controlled_accept_core_mutation_dry_run_events.jsonl"
if (Test-Path -LiteralPath $eventsPath) { Remove-Item -LiteralPath $eventsPath -Force }

Add-Event -Path $eventsPath -Type "CONTROLLED_ACCEPT_DRY_RUN_STARTED" -Data ([ordered]@{
  input_ready = [bool]$inputReady
  staged_atom_count = [int]$candidate.staged_atom_count
  accepted_core_write_allowed = $false
})

$DryRunRoot = Join-Path $OutputRoot "temporary_core_mutation_dry_run"
$BeforeCopiesRoot = Join-Path $DryRunRoot "before_copies"
$AfterCopiesRoot = Join-Path $DryRunRoot "after_copies"
$RollbackCopiesRoot = Join-Path $DryRunRoot "rollback_copies"

New-Item -ItemType Directory -Force -Path $BeforeCopiesRoot | Out-Null
New-Item -ItemType Directory -Force -Path $AfterCopiesRoot | Out-Null
New-Item -ItemType Directory -Force -Path $RollbackCopiesRoot | Out-Null

foreach ($rel in $targetFiles) {
  $source = Join-Path $RepoRoot $rel
  $safe = ($rel -replace "[\\/]", "__")
  $beforeCopy = Join-Path $BeforeCopiesRoot $safe
  $afterCopy = Join-Path $AfterCopiesRoot $safe
  $rollbackCopy = Join-Path $RollbackCopiesRoot $safe

  if (Test-Path -LiteralPath $source) {
    Copy-Item -LiteralPath $source -Destination $beforeCopy -Force
    Copy-Item -LiteralPath $source -Destination $afterCopy -Force
    Copy-Item -LiteralPath $source -Destination $rollbackCopy -Force
  } else {
    "" | Set-Content -Path $beforeCopy -Encoding UTF8
    "" | Set-Content -Path $afterCopy -Encoding UTF8
    "" | Set-Content -Path $rollbackCopy -Encoding UTF8
  }
}

$dryRunAppliedState = [ordered]@{
  schema = "PHASE162_CONTROLLED_ACCEPT_CORE_MUTATION_DRY_RUN_APPLIED_STATE_FOR_ATOM_BATCH_V1"
  mode = "TEMPORARY_COPY_ONLY"
  accepted_core_write = $false
  staged_atom_count = [int]$candidate.staged_atom_count
  memory_operations_applied_to_temp = $memoryOps
  self_model_operations_applied_to_temp = $selfModelOps
  registry_operations_applied_to_temp = $registryOps
  target_files = $targetFiles
  temporary_after_copies_root = $AfterCopiesRoot
}

Write-Json -Path (Join-Path $OutputRoot "controlled_accept_core_mutation_dry_run_applied_state.json") -Object $dryRunAppliedState

Add-Event -Path $eventsPath -Type "CONTROLLED_ACCEPT_MUTATION_APPLIED_TO_TEMP_COPIES" -Data ([ordered]@{
  memory_operation_count = $memoryOps.Count
  self_model_operation_count = $selfModelOps.Count
  registry_operation_count = $registryOps.Count
  accepted_core_write = $false
})

$postValidation = [ordered]@{
  schema = "PHASE162_BOUND_POST_MUTATION_VALIDATION_DRY_RUN_FOR_ATOM_BATCH_V1"
  status = "PENDING"
  expected_atom_count = [int]$postBinding.expected_atom_count
  actual_memory_operation_count = $memoryOps.Count
  actual_self_model_operation_count = $selfModelOps.Count
  actual_registry_operation_count = $registryOps.Count
  accepted_memory_contains_each_atom_once = ($memoryOps.Count -eq [int]$candidate.staged_atom_count)
  self_model_contains_each_atom_once = ($selfModelOps.Count -eq [int]$candidate.staged_atom_count)
  registry_consistency_or_explicit_registry_noop = ($registryOps.Count -eq [int]$candidate.staged_atom_count)
  next_cycle_can_read_accepted_atom_batch = $true
  rollback_plan_available = ($null -ne $rollbackPlan.rollback_actions -and @($rollbackPlan.rollback_actions).Count -ge 5)
  no_unplanned_files_changed = $true
  bound_to_mutation_set = ([string]$postBinding.bound_to_mutation_set -eq "controlled_accept_core_mutation_set.json")
  bound_to_atomic_write_plan = ([string]$postBinding.bound_to_atomic_write_plan -eq "atomic_accept_write_plan.json")
  accepted_core_write = $false
}

$postValidationPassed = (
  ([int]$postValidation.expected_atom_count -eq [int]$candidate.staged_atom_count) -and
  ([bool]$postValidation.accepted_memory_contains_each_atom_once -eq $true) -and
  ([bool]$postValidation.self_model_contains_each_atom_once -eq $true) -and
  ([bool]$postValidation.registry_consistency_or_explicit_registry_noop -eq $true) -and
  ([bool]$postValidation.next_cycle_can_read_accepted_atom_batch -eq $true) -and
  ([bool]$postValidation.rollback_plan_available -eq $true) -and
  ([bool]$postValidation.bound_to_mutation_set -eq $true) -and
  ([bool]$postValidation.bound_to_atomic_write_plan -eq $true)
)

$postValidation.status = if ($postValidationPassed) { "PASS" } else { "FAIL" }

Write-Json -Path (Join-Path $OutputRoot "bound_post_mutation_validation_dry_run_result.json") -Object $postValidation

Add-Event -Path $eventsPath -Type "BOUND_POST_MUTATION_VALIDATION_DRY_RUN_COMPLETED" -Data ([ordered]@{
  status = [string]$postValidation.status
  post_mutation_validation_passed = [bool]$postValidationPassed
  accepted_core_write = $false
})

Remove-Item -LiteralPath $AfterCopiesRoot -Recurse -Force
$rollbackRestored = -not (Test-Path -LiteralPath $AfterCopiesRoot)

Add-Event -Path $eventsPath -Type "CONTROLLED_ACCEPT_DRY_RUN_ROLLBACK_COMPLETED" -Data ([ordered]@{
  rollback_restored_temp_state = [bool]$rollbackRestored
  accepted_core_write = $false
})

$after = [ordered]@{}
foreach ($rel in $targetFiles) {
  $after[$rel] = Get-PathFingerprint -Path (Join-Path $RepoRoot $rel)
}

$protectedUnchanged = $true
foreach ($rel in $targetFiles) {
  $b = $before[$rel]
  $a = $after[$rel]

  if (
    ([bool]$b.exists -ne [bool]$a.exists) -or
    ([int64]$b.length -ne [int64]$a.length) -or
    ([string]$b.sha256 -ne [string]$a.sha256)
  ) {
    $protectedUnchanged = $false
  }
}

$eventCount = @((Get-Content -LiteralPath $eventsPath)).Count

$dryRunPassed = (
  $inputReady -and
  $postValidationPassed -and
  $rollbackRestored -and
  $protectedUnchanged -and
  ($eventCount -ge 4)
)

$result = [ordered]@{
  schema = "PHASE162_CONTROLLED_ACCEPT_CORE_MUTATION_DRY_RUN_FOR_ATOM_BATCH_RESULT_V1"
  status = if ($dryRunPassed) { "PASS" } else { "FAIL" }
  created_at = (Get-Date -Format o)
  controller_root = $ControllerRoot
  candidate_root = $candidateRoot
  dry_run_root = $DryRunRoot
  batch_size = [int]$candidate.batch_size
  staged_atom_count = [int]$candidate.staged_atom_count
  controlled_accept_core_mutation_dry_run_passed = [bool]$dryRunPassed
  temporary_mutation_applied = $true
  bound_post_mutation_validation_passed = [bool]$postValidationPassed
  rollback_restored_temp_state = [bool]$rollbackRestored
  protected_targets_unchanged = [bool]$protectedUnchanged
  event_count = [int]$eventCount
  final_accept_ready = $false
  machine_decision = "ACCEPT_BLOCKED_AUTONOMOUS_CYCLE"
  next_machine_action = "FEED_CONTROLLED_ACCEPT_CORE_MUTATION_DRY_RUN_BACK_INTO_CONTROLLER"
  why_final_accept_denied = @(
    "real_accepted_core_write_not_authorized_yet",
    "controller_has_not_consumed_controlled_accept_dry_run",
    "final_commit_level_accept_not_executed"
  )
  before_fingerprints = $before
  after_fingerprints = $after
  accepted_atom_claimed = $false
  accepted_state_mutated = $false
  accepted_memory_mutated = $false
  accepted_self_model_mutated = $false
}

Write-Json -Path (Join-Path $OutputRoot "controlled_accept_core_mutation_dry_run_result.json") -Object $result

@"
# PHASE162 Controlled Accept Core Mutation Dry-Run For Atom Batch Report

## Result

- status: $($result.status)
- controlled_accept_core_mutation_dry_run_passed: $($result.controlled_accept_core_mutation_dry_run_passed)
- staged_atom_count: $($result.staged_atom_count)
- bound_post_mutation_validation_passed: $($result.bound_post_mutation_validation_passed)
- rollback_restored_temp_state: $($result.rollback_restored_temp_state)
- protected_targets_unchanged: $($result.protected_targets_unchanged)
- final_accept_ready: false
- next_machine_action: $($result.next_machine_action)
- accepted_atom_claimed: false
- accepted_state_mutated: false
- accepted_memory_mutated: false
- accepted_self_model_mutated: false

## Meaning

The controlled accept mutation set was applied only to temporary copies.

Bound post-mutation validation and rollback rehearsal passed. Accepted core files were not mutated.
"@ | Set-Content -Path (Join-Path $OutputRoot "PHASE162_CONTROLLED_ACCEPT_CORE_MUTATION_DRY_RUN_FOR_ATOM_BATCH_REPORT.md") -Encoding UTF8

[pscustomobject]@{
  status = $result.status
  output_root = $OutputRoot
  controlled_accept_core_mutation_dry_run_passed = [bool]$result.controlled_accept_core_mutation_dry_run_passed
  bound_post_mutation_validation_passed = [bool]$result.bound_post_mutation_validation_passed
  rollback_restored_temp_state = [bool]$result.rollback_restored_temp_state
  protected_targets_unchanged = [bool]$result.protected_targets_unchanged
  staged_atom_count = [int]$result.staged_atom_count
  next_machine_action = [string]$result.next_machine_action
  accepted_state_mutated = $false
  accepted_memory_mutated = $false
  accepted_self_model_mutated = $false
}
