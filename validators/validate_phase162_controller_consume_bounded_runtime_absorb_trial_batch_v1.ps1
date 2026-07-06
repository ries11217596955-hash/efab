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

$result = Read-Json (Join-Path $OutputRoot "controller_consume_bounded_runtime_absorb_trial_batch_result.json")
$request = Read-Json (Join-Path $OutputRoot "controlled_accept_core_mutation_candidate_for_atom_batch_request.json")

$checks = [ordered]@{
  status_pass = ([string]$result.status -eq "PASS")
  decision_blocked = ([string]$result.machine_decision -eq "ACCEPT_BLOCKED_AUTONOMOUS_CYCLE")
  next_action_prepare_candidate = ([string]$result.next_machine_action -eq "PREPARE_CONTROLLED_ACCEPT_CORE_MUTATION_CANDIDATE_FOR_ATOM_BATCH")
  runtime_trial_passed = ([bool]$result.preconditions.bounded_runtime_autonomous_absorb_trial_passed -eq $true)
  runtime_overlay_created = ([bool]$result.preconditions.runtime_overlay_created -eq $true)
  next_cycle_visibility_valid = ([bool]$result.preconditions.next_cycle_visibility_valid -eq $true)
  strength_delta_positive = ([bool]$result.preconditions.measured_strength_delta_positive -eq $true)
  protected_targets_unchanged = ([bool]$result.preconditions.protected_targets_unchanged -eq $true)
  runtime_decision_explained = ([bool]$result.preconditions.runtime_decision_explained -eq $true)
  accepted_core_not_mutated = ([bool]$result.preconditions.accepted_core_not_mutated -eq $true)
  request_ready = ([string]$request.status -eq "READY_TO_BUILD")
  request_module_named = ([string]$request.next_module_to_build -eq "invoke_phase162_controlled_accept_core_mutation_candidate_for_atom_batch_001.ps1")
  no_accepted_atom_claim = ([bool]$result.accepted_atom_claimed -eq $false)
  accepted_state_mutated_false = ([bool]$result.accepted_state_mutated -eq $false)
  accepted_memory_mutated_false = ([bool]$result.accepted_memory_mutated -eq $false)
  accepted_self_model_mutated_false = ([bool]$result.accepted_self_model_mutated -eq $false)
}

$failed = @($checks.GetEnumerator() | Where-Object { -not [bool]$_.Value } | ForEach-Object { $_.Key })
$status = if ($failed.Count -eq 0) { "PASS" } else { "FAIL" }

$validation = [ordered]@{
  schema = "PHASE162_CONTROLLER_CONSUME_BOUNDED_RUNTIME_ABSORB_TRIAL_BATCH_VALIDATION_V1"
  status = $status
  created_at = (Get-Date -Format o)
  output_root = $OutputRoot
  checks = $checks
  failed_checks = $failed
  machine_decision = [string]$result.machine_decision
  next_machine_action = [string]$result.next_machine_action
}

$validationPath = Join-Path $OutputRoot "controller_consume_bounded_runtime_absorb_trial_batch_validation.json"
$validation | ConvertTo-Json -Depth 100 | Set-Content -Path $validationPath -Encoding UTF8

if ($status -ne "PASS") {
  throw "PHASE162_CONTROLLER_CONSUME_BOUNDED_RUNTIME_ABSORB_TRIAL_BATCH_VALIDATION_FAILED"
}

Write-Host "PHASE162_CONTROLLER_CONSUME_BOUNDED_RUNTIME_ABSORB_TRIAL_BATCH_VALIDATION=PASS"
Write-Host "MACHINE_DECISION=$($result.machine_decision)"
Write-Host "NEXT_MACHINE_ACTION=$($result.next_machine_action)"
Write-Host "STAGED_ATOM_COUNT=$($result.staged_atom_count)"
Write-Host "MEASURED_STRENGTH_DELTA=$($result.consumed_runtime_trial.measured_strength_delta)"
Write-Host "VALIDATION_RESULT=$validationPath"
