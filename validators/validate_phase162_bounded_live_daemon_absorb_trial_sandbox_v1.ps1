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

$result = Read-Json (Join-Path $OutputRoot "bounded_absorb_trial_result.json")
$overlay = Read-Json (Join-Path $OutputRoot "sandbox_absorb_overlay.json")
$baseline = Read-Json (Join-Path $OutputRoot "baseline_cycle_measurement.json")
$after = Read-Json (Join-Path $OutputRoot "after_absorb_cycle_measurement.json")

$eventsPath = [string]$result.events_path
$eventCount = 0
if (Test-Path -LiteralPath $eventsPath) {
  $eventCount = @((Get-Content -LiteralPath $eventsPath)).Count
}

$checks = [ordered]@{
  status_pass = ([string]$result.status -eq "PASS")
  overlay_status_pass = ([string]$overlay.status -eq "PASS")
  baseline_status_pass = ([string]$baseline.status -eq "PASS")
  after_status_pass = ([string]$after.status -eq "PASS")
  trial_passed_true = ([bool]$result.sandbox_absorb_trial_passed -eq $true)
  next_cycle_stronger_true = ([bool]$result.next_cycle_stronger_after_sandbox_absorb -eq $true)
  denial_explanation_available_true = ([bool]$result.denial_explanation_available -eq $true)
  score_delta_positive = ([int]$result.measured_strength_delta -gt 0)
  final_accept_denied_true = ([bool]$result.final_accept_denied -eq $true)
  final_accept_ready_false = ([bool]$result.final_accept_ready -eq $false)
  event_log_present = ($eventCount -ge 4)
  overlay_sandbox_only = ([string]$overlay.absorbed_into -eq "sandbox_overlay_only")
  no_accepted_atom_claim = ([bool]$result.accepted_atom_claimed -eq $false)
  accepted_state_mutated_false = ([bool]$result.accepted_state_mutated -eq $false)
  accepted_memory_mutated_false = ([bool]$result.accepted_memory_mutated -eq $false)
  accepted_self_model_mutated_false = ([bool]$result.accepted_self_model_mutated -eq $false)
}

$failed = @($checks.GetEnumerator() | Where-Object { -not [bool]$_.Value } | ForEach-Object { $_.Key })
$status = if ($failed.Count -eq 0) { "PASS" } else { "FAIL" }

$validation = [ordered]@{
  schema = "PHASE162_BOUNDED_LIVE_DAEMON_ABSORB_TRIAL_SANDBOX_VALIDATION_V1"
  status = $status
  created_at = (Get-Date -Format o)
  output_root = $OutputRoot
  checks = $checks
  failed_checks = $failed
  measured_strength_delta = [int]$result.measured_strength_delta
  next_machine_action = [string]$result.next_machine_action
}

$validationPath = Join-Path $OutputRoot "bounded_absorb_trial_validation.json"
$validation | ConvertTo-Json -Depth 90 | Set-Content -Path $validationPath -Encoding UTF8

if ($status -ne "PASS") {
  throw "PHASE162_BOUNDED_ABSORB_TRIAL_SANDBOX_VALIDATION_FAILED"
}

Write-Host "PHASE162_BOUNDED_ABSORB_TRIAL_SANDBOX_VALIDATION=PASS"
Write-Host "SANDBOX_ABSORB_TRIAL_PASSED=$($result.sandbox_absorb_trial_passed)"
Write-Host "NEXT_CYCLE_STRONGER_AFTER_SANDBOX_ABSORB=$($result.next_cycle_stronger_after_sandbox_absorb)"
Write-Host "DENIAL_EXPLANATION_AVAILABLE=$($result.denial_explanation_available)"
Write-Host "MEASURED_STRENGTH_DELTA=$($result.measured_strength_delta)"
Write-Host "VALIDATION_RESULT=$validationPath"
