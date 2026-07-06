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

$before = Read-Json (Join-Path $OutputRoot "before_cycle_measurement.json")
$overlay = Read-Json (Join-Path $OutputRoot "sandbox_atom_overlay.json")
$after = Read-Json (Join-Path $OutputRoot "after_cycle_measurement.json")
$result = Read-Json (Join-Path $OutputRoot "next_cycle_improvement_trial_result.json")

$checks = [ordered]@{
  result_status_pass = ([string]$result.status -eq "PASS")
  before_status_pass = ([string]$before.status -eq "PASS")
  overlay_status_pass = ([string]$overlay.status -eq "PASS")
  after_status_pass = ([string]$after.status -eq "PASS")
  before_score_zero = ([int]$result.measured_capability_score_before -eq 0)
  after_score_positive = ([int]$result.measured_capability_score_after -gt 0)
  score_delta_positive = ([int]$result.measured_capability_score_delta -gt 0)
  trial_passed_true = ([bool]$result.next_cycle_improvement_trial_passed -eq $true)
  partial_next_cycle_true = ([bool]$result.next_cycle_improvement_proven_partial -eq $true)
  next_cycle_for_accept_false = ([bool]$result.next_cycle_improvement_proven_for_accept -eq $false)
  expected_decision_blocked = ([string]$result.expected_machine_decision -eq "ACCEPT_BLOCKED_AUTONOMOUS_CYCLE")
  overlay_sandbox_only = ([string]$overlay.overlay_mode -eq "SANDBOX_ONLY_NOT_ACCEPTED_CORE")
  next_cycle_can_select_action = ([bool]$after.next_cycle_can_select_atom_specific_action -eq $true)
  no_accepted_atom_claim = ([bool]$result.accepted_atom_claimed -eq $false)
  accepted_state_mutated_false = ([bool]$result.accepted_state_mutated -eq $false)
  accepted_memory_mutated_false = ([bool]$result.accepted_memory_mutated -eq $false)
  accepted_self_model_mutated_false = ([bool]$result.accepted_self_model_mutated -eq $false)
}

$failed = @($checks.GetEnumerator() | Where-Object { -not [bool]$_.Value } | ForEach-Object { $_.Key })
$status = if ($failed.Count -eq 0) { "PASS" } else { "FAIL" }

$validation = [ordered]@{
  schema = "PHASE162_NEXT_CYCLE_IMPROVEMENT_TRIAL_SANDBOX_VALIDATION_V1"
  status = $status
  created_at = (Get-Date -Format o)
  output_root = $OutputRoot
  checks = $checks
  failed_checks = $failed
  expected_machine_decision = [string]$result.expected_machine_decision
}

$validationPath = Join-Path $OutputRoot "next_cycle_improvement_trial_validation.json"
$validation | ConvertTo-Json -Depth 50 | Set-Content -Path $validationPath -Encoding UTF8

if ($status -ne "PASS") {
  throw "PHASE162_NEXT_CYCLE_IMPROVEMENT_TRIAL_SANDBOX_VALIDATION_FAILED"
}

Write-Host "PHASE162_NEXT_CYCLE_IMPROVEMENT_TRIAL_SANDBOX_VALIDATION=PASS"
Write-Host "NEXT_CYCLE_IMPROVEMENT_TRIAL_PASSED=$($result.next_cycle_improvement_trial_passed)"
Write-Host "SCORE_DELTA=$($result.measured_capability_score_delta)"
Write-Host "EXPECTED_MACHINE_DECISION=$($result.expected_machine_decision)"
Write-Host "VALIDATION_RESULT=$validationPath"
