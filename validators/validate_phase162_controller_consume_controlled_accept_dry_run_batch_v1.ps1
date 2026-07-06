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

$result = Read-Json (Join-Path $OutputRoot "controller_consume_controlled_accept_core_mutation_dry_run_batch_result.json")
$authorization = Read-Json (Join-Path $OutputRoot "one_shot_controlled_accept_core_mutation_execution_authorization_for_atom_batch.json")

$checks = [ordered]@{
  status_pass = ([string]$result.status -eq "PASS")
  decision_still_blocked_until_execution = ([string]$result.machine_decision -eq "ACCEPT_BLOCKED_AUTONOMOUS_CYCLE")
  next_action_execute = ([string]$result.next_machine_action -eq "EXECUTE_CONTROLLED_ACCEPT_CORE_MUTATION_FOR_ATOM_BATCH")
  execution_authorized = ([string]$result.execution_authorization_status -eq "AUTHORIZED_ONE_SHOT_CONTROLLED_ACCEPT_CORE_MUTATION")
  auth_status_authorized = ([string]$authorization.status -eq "AUTHORIZED")
  auth_scope_one_shot = ([string]$authorization.authorization_scope -eq "ONE_SHOT_ACCEPTED_CORE_WRITE_WITH_ATOMIC_PLAN_AND_ROLLBACK")
  dry_run_passed = ([bool]$result.preconditions.controlled_accept_core_mutation_dry_run_passed -eq $true)
  post_validation_passed = ([bool]$result.preconditions.bound_post_mutation_validation_passed -eq $true)
  rollback_temp_passed = ([bool]$result.preconditions.rollback_restored_temp_state -eq $true)
  protected_targets_unchanged = ([bool]$result.preconditions.protected_targets_unchanged -eq $true)
  dry_run_no_write = ([bool]$result.preconditions.dry_run_no_accepted_core_write -eq $true)
  plans_ready = (
    ([bool]$result.preconditions.atomic_write_plan_prepared -eq $true) -and
    ([bool]$result.preconditions.rollback_plan_prepared -eq $true) -and
    ([bool]$result.preconditions.post_mutation_validation_binding_prepared -eq $true)
  )
  staged_atom_count_positive = ([int]$result.staged_atom_count -gt 0)
  no_accepted_atom_claim = ([bool]$result.accepted_atom_claimed -eq $false)
  accepted_state_mutated_false = ([bool]$result.accepted_state_mutated -eq $false)
  accepted_memory_mutated_false = ([bool]$result.accepted_memory_mutated -eq $false)
  accepted_self_model_mutated_false = ([bool]$result.accepted_self_model_mutated -eq $false)
}

$failed = @($checks.GetEnumerator() | Where-Object { -not [bool]$_.Value } | ForEach-Object { $_.Key })
$status = if ($failed.Count -eq 0) { "PASS" } else { "FAIL" }

$validation = [ordered]@{
  schema = "PHASE162_CONTROLLER_CONSUME_CONTROLLED_ACCEPT_CORE_MUTATION_DRY_RUN_BATCH_VALIDATION_V1"
  status = $status
  created_at = (Get-Date -Format o)
  output_root = $OutputRoot
  checks = $checks
  failed_checks = $failed
  machine_decision = [string]$result.machine_decision
  next_machine_action = [string]$result.next_machine_action
  execution_authorization_status = [string]$result.execution_authorization_status
}

$validationPath = Join-Path $OutputRoot "controller_consume_controlled_accept_core_mutation_dry_run_batch_validation.json"
$validation | ConvertTo-Json -Depth 100 | Set-Content -Path $validationPath -Encoding UTF8

if ($status -ne "PASS") {
  throw "PHASE162_CONTROLLER_CONSUME_CONTROLLED_ACCEPT_CORE_MUTATION_DRY_RUN_BATCH_VALIDATION_FAILED"
}

Write-Host "PHASE162_CONTROLLER_CONSUME_CONTROLLED_ACCEPT_CORE_MUTATION_DRY_RUN_BATCH_VALIDATION=PASS"
Write-Host "MACHINE_DECISION=$($result.machine_decision)"
Write-Host "NEXT_MACHINE_ACTION=$($result.next_machine_action)"
Write-Host "EXECUTION_AUTHORIZATION_STATUS=$($result.execution_authorization_status)"
Write-Host "STAGED_ATOM_COUNT=$($result.staged_atom_count)"
Write-Host "VALIDATION_RESULT=$validationPath"
