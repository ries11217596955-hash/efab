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

$usefulness = Read-Json (Join-Path $OutputRoot "usefulness_validation_result.json")
$safety = Read-Json (Join-Path $OutputRoot "safety_validation_result.json")
$combined = Read-Json (Join-Path $OutputRoot "usefulness_safety_blockers_result.json")

$blockers = @($combined.blocking_reasons | ForEach-Object { [string]$_ })

$checks = [ordered]@{
  usefulness_status_pass = ([string]$usefulness.status -eq "PASS")
  safety_status_pass = ([string]$safety.status -eq "PASS")
  combined_status_pass = ([string]$combined.status -eq "PASS")
  executed_use_passed = ([bool]$combined.usefulness_validated_partial -eq $true)
  usefulness_for_accept_false = ([bool]$combined.usefulness_validated_for_accept -eq $false)
  safety_for_accept_false = ([bool]$combined.safety_validated_for_accept -eq $false)
  accept_ready_false = ([bool]$combined.accept_ready -eq $false)
  expected_accept_blocked = ([string]$combined.gate_expected_decision -eq "ACCEPT_BLOCKED")
  old_owner_value_blocker_removed = (-not ($blockers -contains "no_owner_visible_value_proof"))
  old_executed_use_blocker_replaced = (-not ($blockers -contains "no_executed_use_proof_against_live_builder_task"))
  partial_marker_present = ($blockers -contains "partial_executed_use_proof_exists_but_not_live_builder_task_success_delta")
  safety_still_blocked = ([bool]$safety.safety_validated_for_accept -eq $false)
  no_accepted_atom_claim = ([bool]$combined.accepted_atom_claimed -eq $false)
  accepted_state_mutated_false = ([bool]$combined.accepted_state_mutated -eq $false)
  accepted_memory_mutated_false = ([bool]$combined.accepted_memory_mutated -eq $false)
  accepted_self_model_mutated_false = ([bool]$combined.accepted_self_model_mutated -eq $false)
}

$failed = @($checks.GetEnumerator() | Where-Object { -not [bool]$_.Value } | ForEach-Object { $_.Key })
$status = if ($failed.Count -eq 0) { "PASS" } else { "FAIL" }

$validation = [ordered]@{
  schema = "PHASE162_USEFULNESS_BLOCKERS_WITH_EXECUTED_USE_VALIDATION_V1"
  status = $status
  created_at = (Get-Date -Format o)
  output_root = $OutputRoot
  checks = $checks
  failed_checks = $failed
  expected_gate_decision = [string]$combined.gate_expected_decision
}

$validationPath = Join-Path $OutputRoot "usefulness_safety_blockers_validation.json"
$validation | ConvertTo-Json -Depth 20 | Set-Content -Path $validationPath -Encoding UTF8

if ($status -ne "PASS") {
  throw "PHASE162_USEFULNESS_BLOCKERS_WITH_EXECUTED_USE_VALIDATION_FAILED"
}

Write-Host "PHASE162_USEFULNESS_BLOCKERS_WITH_EXECUTED_USE_VALIDATION=PASS"
Write-Host "USEFULNESS_VALIDATED_PARTIAL=$($combined.usefulness_validated_partial)"
Write-Host "EXPECTED_GATE_DECISION=$($combined.gate_expected_decision)"
Write-Host "VALIDATION_RESULT=$validationPath"
