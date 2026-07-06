param(
  [Parameter(Mandatory=$true)]
  [string]$OutputRoot
)

$ErrorActionPreference = "Stop"

function Read-Json {
  param([string]$Path)
  if (-not (Test-Path -LiteralPath $Path)) { throw "MISSING_FILE=$Path" }
  return Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json
}

$result = Read-Json (Join-Path $OutputRoot "controlled_accept_core_mutation_candidate_result.json")
$mutationSet = Read-Json (Join-Path $OutputRoot "controlled_accept_core_mutation_set.json")
$writePlan = Read-Json (Join-Path $OutputRoot "atomic_accept_write_plan.json")
$rollbackPlan = Read-Json (Join-Path $OutputRoot "controlled_accept_core_mutation_rollback_plan.json")
$postBinding = Read-Json (Join-Path $OutputRoot "post_mutation_validation_binding.json")
$fingerprints = Read-Json (Join-Path $OutputRoot "pre_accept_fingerprints.json")

$memoryOps = @($mutationSet.accepted_memory_operations)
$selfModelOps = @($mutationSet.accepted_self_model_operations)
$registryOps = @($mutationSet.registry_operations)

$checks = [ordered]@{
  status_pass = ([string]$result.status -eq "PASS")
  candidate_prepared_true = ([bool]$result.controlled_accept_core_mutation_candidate_prepared -eq $true)
  mutation_set_prepared_true = ([bool]$result.mutation_set_prepared -eq $true)
  pre_accept_fingerprints_frozen_true = ([bool]$result.pre_accept_fingerprints_frozen -eq $true)
  atomic_write_plan_prepared_true = ([bool]$result.atomic_write_plan_prepared -eq $true)
  rollback_plan_prepared_true = ([bool]$result.rollback_plan_prepared -eq $true)
  post_binding_prepared_true = ([bool]$result.post_mutation_validation_binding_prepared -eq $true)
  staged_atom_count_positive = ([int]$result.staged_atom_count -gt 0)
  memory_ops_match = ($memoryOps.Count -eq [int]$result.staged_atom_count)
  self_model_ops_match = ($selfModelOps.Count -eq [int]$result.staged_atom_count)
  registry_ops_match = ($registryOps.Count -eq [int]$result.staged_atom_count)
  write_plan_no_write = ([string]$writePlan.mode -eq "PLAN_ONLY_NO_WRITE")
  rollback_plan_no_write = ([string]$rollbackPlan.mode -eq "PLAN_ONLY_NO_WRITE")
  post_binding_no_write = ([string]$postBinding.mode -eq "BINDING_ONLY_NO_WRITE")
  fingerprint_targets_present = (
    $null -ne $fingerprints.'reports/self_development/accepted_change_memory_snapshot.json' -and
    $null -ne $fingerprints.'reports/self_development/SELF_MODEL_ACTIVE_MAP.json' -and
    $null -ne $fingerprints.'packs/registry.json'
  )
  protected_targets_unchanged_true = ([bool]$result.protected_targets_unchanged -eq $true)
  final_accept_ready_false = ([bool]$result.final_accept_ready -eq $false)
  decision_blocked = ([string]$result.machine_decision -eq "ACCEPT_BLOCKED_AUTONOMOUS_CYCLE")
  next_action_validate = ([string]$result.next_machine_action -eq "VALIDATE_CONTROLLED_ACCEPT_CORE_MUTATION_CANDIDATE_FOR_ATOM_BATCH")
  no_accepted_atom_claim = ([bool]$result.accepted_atom_claimed -eq $false)
  accepted_state_mutated_false = ([bool]$result.accepted_state_mutated -eq $false)
  accepted_memory_mutated_false = ([bool]$result.accepted_memory_mutated -eq $false)
  accepted_self_model_mutated_false = ([bool]$result.accepted_self_model_mutated -eq $false)
}

$failed = @($checks.GetEnumerator() | Where-Object { -not [bool]$_.Value } | ForEach-Object { $_.Key })
$status = if ($failed.Count -eq 0) { "PASS" } else { "FAIL" }

$validation = [ordered]@{
  schema = "PHASE162_CONTROLLED_ACCEPT_CORE_MUTATION_CANDIDATE_FOR_ATOM_BATCH_VALIDATION_V1"
  status = $status
  created_at = (Get-Date -Format o)
  output_root = $OutputRoot
  checks = $checks
  failed_checks = $failed
  next_machine_action = [string]$result.next_machine_action
}

$validationPath = Join-Path $OutputRoot "controlled_accept_core_mutation_candidate_validation.json"
$validation | ConvertTo-Json -Depth 100 | Set-Content -Path $validationPath -Encoding UTF8

if ($status -ne "PASS") {
  throw "PHASE162_CONTROLLED_ACCEPT_CORE_MUTATION_CANDIDATE_FOR_ATOM_BATCH_VALIDATION_FAILED"
}

Write-Host "PHASE162_CONTROLLED_ACCEPT_CORE_MUTATION_CANDIDATE_FOR_ATOM_BATCH_VALIDATION=PASS"
Write-Host "CONTROLLED_ACCEPT_CORE_MUTATION_CANDIDATE_PREPARED=$($result.controlled_accept_core_mutation_candidate_prepared)"
Write-Host "STAGED_ATOM_COUNT=$($result.staged_atom_count)"
Write-Host "PROTECTED_TARGETS_UNCHANGED=$($result.protected_targets_unchanged)"
Write-Host "NEXT_MACHINE_ACTION=$($result.next_machine_action)"
Write-Host "VALIDATION_RESULT=$validationPath"
