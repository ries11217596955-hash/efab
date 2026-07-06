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

$result = Read-Json (Join-Path $OutputRoot "bounded_real_runtime_autonomous_absorb_trial_result.json")
$decision = Read-Json (Join-Path $OutputRoot "runtime_autonomous_absorb_decision.json")
$baseline = Read-Json (Join-Path $OutputRoot "runtime_baseline_cycle.json")
$after = Read-Json (Join-Path $OutputRoot "runtime_after_absorb_cycle.json")

$checks = [ordered]@{
  status_pass = ([string]$result.status -eq "PASS")
  runtime_trial_passed_true = ([bool]$result.bounded_runtime_autonomous_absorb_trial_passed -eq $true)
  overlay_absorb_allowed_true = ([bool]$result.runtime_overlay_absorb_allowed -eq $true)
  decision_code_expected = ([string]$decision.decision_code -eq "ALLOW_RUNTIME_OVERLAY_ABSORB_DENY_FINAL_ACCEPT")
  runtime_overlay_created_true = ([bool]$result.runtime_overlay_created -eq $true)
  overlay_file_count_at_least_four = ([int]$result.runtime_overlay_file_count -ge 4)
  next_cycle_visibility_valid_true = ([bool]$result.next_cycle_visibility_valid -eq $true)
  strength_delta_positive = ([int]$result.measured_strength_delta -gt 0)
  protected_targets_unchanged_true = ([bool]$result.protected_targets_unchanged -eq $true)
  baseline_score_lower = ([int]$after.cycle_strength_score -gt [int]$baseline.cycle_strength_score)
  event_count_at_least_five = ([int]$result.event_count -ge 5)
  final_accept_ready_false = ([bool]$result.final_accept_ready -eq $false)
  machine_decision_blocked = ([string]$result.machine_decision -eq "ACCEPT_BLOCKED_AUTONOMOUS_CYCLE")
  next_action_feed_controller = ([string]$result.next_machine_action -eq "FEED_BOUNDED_REAL_RUNTIME_AUTONOMOUS_ABSORB_TRIAL_BACK_INTO_CONTROLLER")
  no_accepted_atom_claim = ([bool]$result.accepted_atom_claimed -eq $false)
  accepted_state_mutated_false = ([bool]$result.accepted_state_mutated -eq $false)
  accepted_memory_mutated_false = ([bool]$result.accepted_memory_mutated -eq $false)
  accepted_self_model_mutated_false = ([bool]$result.accepted_self_model_mutated -eq $false)
}

$failed = @($checks.GetEnumerator() | Where-Object { -not [bool]$_.Value } | ForEach-Object { $_.Key })
$status = if ($failed.Count -eq 0) { "PASS" } else { "FAIL" }

$validation = [ordered]@{
  schema = "PHASE162_BOUNDED_REAL_RUNTIME_AUTONOMOUS_ABSORB_TRIAL_FOR_ATOM_BATCH_VALIDATION_V1"
  status = $status
  created_at = (Get-Date -Format o)
  output_root = $OutputRoot
  checks = $checks
  failed_checks = $failed
  next_machine_action = [string]$result.next_machine_action
}

$validationPath = Join-Path $OutputRoot "bounded_real_runtime_autonomous_absorb_trial_validation.json"
$validation | ConvertTo-Json -Depth 100 | Set-Content -Path $validationPath -Encoding UTF8

if ($status -ne "PASS") {
  throw "PHASE162_BOUNDED_REAL_RUNTIME_AUTONOMOUS_ABSORB_TRIAL_FOR_ATOM_BATCH_VALIDATION_FAILED"
}

Write-Host "PHASE162_BOUNDED_REAL_RUNTIME_AUTONOMOUS_ABSORB_TRIAL_FOR_ATOM_BATCH_VALIDATION=PASS"
Write-Host "BOUNDED_RUNTIME_AUTONOMOUS_ABSORB_TRIAL_PASSED=$($result.bounded_runtime_autonomous_absorb_trial_passed)"
Write-Host "NEXT_CYCLE_VISIBILITY_VALID=$($result.next_cycle_visibility_valid)"
Write-Host "MEASURED_STRENGTH_DELTA=$($result.measured_strength_delta)"
Write-Host "PROTECTED_TARGETS_UNCHANGED=$($result.protected_targets_unchanged)"
Write-Host "NEXT_MACHINE_ACTION=$($result.next_machine_action)"
Write-Host "VALIDATION_RESULT=$validationPath"
