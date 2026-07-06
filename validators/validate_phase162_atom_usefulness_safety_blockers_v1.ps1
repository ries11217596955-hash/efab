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

$checks = [ordered]@{
  usefulness_status_pass = ([string]$usefulness.status -eq "PASS")
  safety_status_pass = ([string]$safety.status -eq "PASS")
  combined_status_pass = ([string]$combined.status -eq "PASS")
  usefulness_false = ([bool]$combined.usefulness_validated -eq $false)
  safety_false = ([bool]$combined.safety_validated_for_accept -eq $false)
  accept_ready_false = ([bool]$combined.accept_ready -eq $false)
  expected_accept_blocked = ([string]$combined.gate_expected_decision -eq "ACCEPT_BLOCKED")
  usefulness_has_blockers = (@($usefulness.blocking_reasons).Count -gt 0)
  safety_has_blockers = (@($safety.blocking_reasons).Count -gt 0)
  no_accepted_atom_claim = ([bool]$combined.accepted_atom_claimed -eq $false)
  accepted_state_mutated_false = ([bool]$combined.accepted_state_mutated -eq $false)
  accepted_memory_mutated_false = ([bool]$combined.accepted_memory_mutated -eq $false)
  accepted_self_model_mutated_false = ([bool]$combined.accepted_self_model_mutated -eq $false)
}

$failed = @($checks.GetEnumerator() | Where-Object { -not [bool]$_.Value } | ForEach-Object { $_.Key })
$status = if ($failed.Count -eq 0) { "PASS" } else { "FAIL" }

$validation = [ordered]@{
  schema = "PHASE162_ATOM_USEFULNESS_SAFETY_BLOCKERS_VALIDATION_V1"
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
  throw "PHASE162_USEFULNESS_SAFETY_BLOCKERS_VALIDATION_FAILED"
}

Write-Host "PHASE162_USEFULNESS_SAFETY_BLOCKERS_VALIDATION=PASS"
Write-Host "EXPECTED_GATE_DECISION=$($combined.gate_expected_decision)"
Write-Host "VALIDATION_RESULT=$validationPath"
