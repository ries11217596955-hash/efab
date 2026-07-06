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

$result = Read-Json (Join-Path $OutputRoot "controller_with_next_cycle_trial_result.json")
$request = Read-Json (Join-Path $OutputRoot "accept_safety_contract_dry_run_activation_request.json")

$checks = [ordered]@{
  status_pass = ([string]$result.status -eq "PASS")
  mode_dry_run = ([string]$result.controller_mode -eq "AUTONOMOUS_DRY_RUN_NO_ACCEPTED_CORE_WRITES")
  decision_still_blocked = ([string]$result.machine_decision -eq "ACCEPT_BLOCKED_AUTONOMOUS_CYCLE")
  next_action_safety_dry_run = ([string]$result.next_machine_action -eq "ACTIVATE_AND_TEST_ACCEPT_SAFETY_CONTRACTS_IN_DRY_RUN")
  next_cycle_partial_true = ([bool]$result.preconditions.next_cycle_improvement_proven_partial -eq $true)
  next_cycle_for_accept_false = ([bool]$result.preconditions.next_cycle_improvement_proven_for_accept -eq $false)
  safety_contracts_present_true = ([bool]$result.preconditions.safety_contracts_present -eq $true)
  safety_for_accept_false = ([bool]$result.preconditions.safety_validated_for_accept -eq $false)
  request_ready = ([string]$request.status -eq "READY_TO_BUILD")
  request_module_named = ([string]$request.next_module_to_build -eq "invoke_phase162_accept_safety_contract_dry_run_activation_001.ps1")
  no_accepted_atom_claim = ([bool]$result.accepted_atom_claimed -eq $false)
  accepted_state_mutated_false = ([bool]$result.accepted_state_mutated -eq $false)
  accepted_memory_mutated_false = ([bool]$result.accepted_memory_mutated -eq $false)
  accepted_self_model_mutated_false = ([bool]$result.accepted_self_model_mutated -eq $false)
}

$failed = @($checks.GetEnumerator() | Where-Object { -not [bool]$_.Value } | ForEach-Object { $_.Key })
$status = if ($failed.Count -eq 0) { "PASS" } else { "FAIL" }

$validation = [ordered]@{
  schema = "PHASE162_CONTROLLER_CONSUME_NEXT_CYCLE_TRIAL_VALIDATION_V1"
  status = $status
  created_at = (Get-Date -Format o)
  output_root = $OutputRoot
  checks = $checks
  failed_checks = $failed
  machine_decision = [string]$result.machine_decision
  next_machine_action = [string]$result.next_machine_action
}

$validationPath = Join-Path $OutputRoot "controller_with_next_cycle_trial_validation.json"
$validation | ConvertTo-Json -Depth 60 | Set-Content -Path $validationPath -Encoding UTF8

if ($status -ne "PASS") {
  throw "PHASE162_CONTROLLER_CONSUME_NEXT_CYCLE_TRIAL_VALIDATION_FAILED"
}

Write-Host "PHASE162_CONTROLLER_CONSUME_NEXT_CYCLE_TRIAL_VALIDATION=PASS"
Write-Host "MACHINE_DECISION=$($result.machine_decision)"
Write-Host "NEXT_MACHINE_ACTION=$($result.next_machine_action)"
Write-Host "NEXT_CYCLE_PARTIAL=$($result.preconditions.next_cycle_improvement_proven_partial)"
Write-Host "VALIDATION_RESULT=$validationPath"
