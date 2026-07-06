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

$result = Read-Json (Join-Path $OutputRoot "controller_with_bounded_absorb_trial_result.json")
$request = Read-Json (Join-Path $OutputRoot "controlled_accept_candidate_dry_run_request.json")

$checks = [ordered]@{
  status_pass = ([string]$result.status -eq "PASS")
  machine_decision_blocked = ([string]$result.machine_decision -eq "ACCEPT_BLOCKED_AUTONOMOUS_CYCLE")
  next_action_accept_candidate = ([string]$result.next_machine_action -eq "BUILD_CONTROLLED_ACCEPT_CANDIDATE_DRY_RUN")
  bounded_absorb_passed_true = ([bool]$result.preconditions.bounded_absorb_trial_passed -eq $true)
  next_cycle_stronger_true = ([bool]$result.preconditions.next_cycle_stronger_after_sandbox_absorb -eq $true)
  denial_explanation_true = ([bool]$result.preconditions.denial_explanation_available -eq $true)
  measured_delta_positive = ([bool]$result.preconditions.measured_strength_delta_positive -eq $true)
  accepted_core_not_mutated_true = ([bool]$result.preconditions.accepted_core_not_mutated -eq $true)
  request_ready = ([string]$request.status -eq "READY_TO_BUILD")
  request_module_named = ([string]$request.next_module_to_build -eq "invoke_phase162_controlled_accept_candidate_dry_run_001.ps1")
  no_accepted_atom_claim = ([bool]$result.accepted_atom_claimed -eq $false)
  accepted_state_mutated_false = ([bool]$result.accepted_state_mutated -eq $false)
  accepted_memory_mutated_false = ([bool]$result.accepted_memory_mutated -eq $false)
  accepted_self_model_mutated_false = ([bool]$result.accepted_self_model_mutated -eq $false)
}

$failed = @($checks.GetEnumerator() | Where-Object { -not [bool]$_.Value } | ForEach-Object { $_.Key })
$status = if ($failed.Count -eq 0) { "PASS" } else { "FAIL" }

$validation = [ordered]@{
  schema = "PHASE162_CONTROLLER_CONSUME_BOUNDED_ABSORB_TRIAL_VALIDATION_V1"
  status = $status
  created_at = (Get-Date -Format o)
  output_root = $OutputRoot
  checks = $checks
  failed_checks = $failed
  machine_decision = [string]$result.machine_decision
  next_machine_action = [string]$result.next_machine_action
}

$validationPath = Join-Path $OutputRoot "controller_with_bounded_absorb_trial_validation.json"
$validation | ConvertTo-Json -Depth 90 | Set-Content -Path $validationPath -Encoding UTF8

if ($status -ne "PASS") {
  throw "PHASE162_CONTROLLER_CONSUME_BOUNDED_ABSORB_TRIAL_VALIDATION_FAILED"
}

Write-Host "PHASE162_CONTROLLER_CONSUME_BOUNDED_ABSORB_TRIAL_VALIDATION=PASS"
Write-Host "MACHINE_DECISION=$($result.machine_decision)"
Write-Host "NEXT_MACHINE_ACTION=$($result.next_machine_action)"
Write-Host "BOUNDED_ABSORB_TRIAL_PASSED=$($result.preconditions.bounded_absorb_trial_passed)"
Write-Host "VALIDATION_RESULT=$validationPath"
