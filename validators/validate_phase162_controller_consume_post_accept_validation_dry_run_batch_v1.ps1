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

$result = Read-Json (Join-Path $OutputRoot "controller_consume_post_accept_validation_dry_run_batch_result.json")
$request = Read-Json (Join-Path $OutputRoot "bounded_real_runtime_autonomous_absorb_trial_for_atom_batch_request.json")

$checks = [ordered]@{
  status_pass = ([string]$result.status -eq "PASS")
  decision_blocked = ([string]$result.machine_decision -eq "ACCEPT_BLOCKED_AUTONOMOUS_CYCLE")
  next_action_runtime_trial = ([string]$result.next_machine_action -eq "BUILD_BOUNDED_REAL_RUNTIME_AUTONOMOUS_ABSORB_TRIAL_FOR_ATOM_BATCH")
  post_accept_validation_passed = ([bool]$result.preconditions.post_accept_validation_dry_run_passed -eq $true)
  memory_schema_valid = ([bool]$result.preconditions.memory_schema_valid -eq $true)
  self_model_schema_valid = ([bool]$result.preconditions.self_model_schema_valid -eq $true)
  registry_consistency_valid = ([bool]$result.preconditions.registry_consistency_valid -eq $true)
  next_cycle_visibility_valid = ([bool]$result.preconditions.next_cycle_visibility_valid -eq $true)
  protected_targets_unchanged = ([bool]$result.preconditions.protected_targets_unchanged -eq $true)
  accepted_core_not_mutated = ([bool]$result.preconditions.accepted_core_not_mutated -eq $true)
  request_ready = ([string]$request.status -eq "READY_TO_BUILD")
  request_module_named = ([string]$request.next_module_to_build -eq "invoke_phase162_bounded_real_runtime_autonomous_absorb_trial_for_atom_batch_001.ps1")
  no_accepted_atom_claim = ([bool]$result.accepted_atom_claimed -eq $false)
  accepted_state_mutated_false = ([bool]$result.accepted_state_mutated -eq $false)
  accepted_memory_mutated_false = ([bool]$result.accepted_memory_mutated -eq $false)
  accepted_self_model_mutated_false = ([bool]$result.accepted_self_model_mutated -eq $false)
}

$failed = @($checks.GetEnumerator() | Where-Object { -not [bool]$_.Value } | ForEach-Object { $_.Key })
$status = if ($failed.Count -eq 0) { "PASS" } else { "FAIL" }

$validation = [ordered]@{
  schema = "PHASE162_CONTROLLER_CONSUME_POST_ACCEPT_VALIDATION_DRY_RUN_BATCH_VALIDATION_V1"
  status = $status
  created_at = (Get-Date -Format o)
  output_root = $OutputRoot
  checks = $checks
  failed_checks = $failed
  machine_decision = [string]$result.machine_decision
  next_machine_action = [string]$result.next_machine_action
}

$validationPath = Join-Path $OutputRoot "controller_consume_post_accept_validation_dry_run_batch_validation.json"
$validation | ConvertTo-Json -Depth 100 | Set-Content -Path $validationPath -Encoding UTF8

if ($status -ne "PASS") {
  throw "PHASE162_CONTROLLER_CONSUME_POST_ACCEPT_VALIDATION_DRY_RUN_BATCH_VALIDATION_FAILED"
}

Write-Host "PHASE162_CONTROLLER_CONSUME_POST_ACCEPT_VALIDATION_DRY_RUN_BATCH_VALIDATION=PASS"
Write-Host "MACHINE_DECISION=$($result.machine_decision)"
Write-Host "NEXT_MACHINE_ACTION=$($result.next_machine_action)"
Write-Host "STAGED_ATOM_COUNT=$($result.staged_atom_count)"
Write-Host "VALIDATION_RESULT=$validationPath"
