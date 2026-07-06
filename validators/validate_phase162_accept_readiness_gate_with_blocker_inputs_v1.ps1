param(
  [Parameter(Mandatory=$true)]
  [string]$OutputRoot
)

$ErrorActionPreference = "Stop"

$resultPath = Join-Path $OutputRoot "accept_gate_with_blockers_result.json"
if (-not (Test-Path -LiteralPath $resultPath)) {
  throw "MISSING_ACCEPT_GATE_WITH_BLOCKERS_RESULT"
}

$result = Get-Content -LiteralPath $resultPath -Raw | ConvertFrom-Json

$checks = [ordered]@{
  status_pass = ([string]$result.status -eq "PASS")
  gate_decision_valid = (@("ACCEPT_BLOCKED","ACCEPT_READY") -contains [string]$result.gate_decision)
  gate_is_blocked_now = ([string]$result.gate_decision -eq "ACCEPT_BLOCKED")
  blockers_exist = (@($result.blocking_reasons).Count -gt 0)
  usefulness_false = ([bool]$result.usefulness_validated -eq $false)
  safety_false = ([bool]$result.safety_validated_for_accept -eq $false)
  accept_ready_false = ([bool]$result.accept_ready -eq $false)
  no_accepted_atom_claim = ([bool]$result.accepted_atom_claimed -eq $false)
  accepted_state_mutated_false = ([bool]$result.accepted_state_mutated -eq $false)
  accepted_memory_mutated_false = ([bool]$result.accepted_memory_mutated -eq $false)
  accepted_self_model_mutated_false = ([bool]$result.accepted_self_model_mutated -eq $false)
  consumed_freeze_pass = ([string]$result.consumed_freeze_validation -eq "PASS")
  consumed_blockers_pass = ([string]$result.consumed_blockers_validation -eq "PASS")
}

$failed = @($checks.GetEnumerator() | Where-Object { -not [bool]$_.Value } | ForEach-Object { $_.Key })
$status = if ($failed.Count -eq 0) { "PASS" } else { "FAIL" }

$validation = [ordered]@{
  schema = "PHASE162_ACCEPT_READINESS_GATE_WITH_BLOCKER_INPUTS_VALIDATION_V1"
  status = $status
  created_at = (Get-Date -Format o)
  output_root = $OutputRoot
  gate_decision = [string]$result.gate_decision
  checks = $checks
  failed_checks = $failed
}

$validationPath = Join-Path $OutputRoot "accept_gate_with_blockers_validation.json"
$validation | ConvertTo-Json -Depth 20 | Set-Content -Path $validationPath -Encoding UTF8

if ($status -ne "PASS") {
  throw "PHASE162_ACCEPT_GATE_WITH_BLOCKERS_VALIDATION_FAILED"
}

Write-Host "PHASE162_ACCEPT_GATE_WITH_BLOCKERS_VALIDATION=PASS"
Write-Host "GATE_DECISION=$($result.gate_decision)"
Write-Host "VALIDATION_RESULT=$validationPath"
