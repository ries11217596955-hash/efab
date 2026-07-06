param(
  [Parameter(Mandatory=$true)]
  [string]$OutputRoot
)

$ErrorActionPreference = "Stop"

$resultPath = Join-Path $OutputRoot "accept_readiness_gate_result.json"
if (-not (Test-Path -LiteralPath $resultPath)) {
  throw "MISSING_ACCEPT_READINESS_GATE_RESULT"
}

$result = Get-Content -LiteralPath $resultPath -Raw | ConvertFrom-Json

$checks = [ordered]@{
  status_pass = ([string]$result.status -eq "PASS")
  decision_is_blocked_or_ready = (@("ACCEPT_BLOCKED","ACCEPT_READY") -contains [string]$result.gate_decision)
  no_accepted_atom_claim = ([bool]$result.accepted_atom_claimed -eq $false)
  accepted_state_mutated_false = ([bool]$result.accepted_state_mutated -eq $false)
  accepted_memory_mutated_false = ([bool]$result.accepted_memory_mutated -eq $false)
  accepted_self_model_mutated_false = ([bool]$result.accepted_self_model_mutated -eq $false)
  blocked_has_reasons = if ([string]$result.gate_decision -eq "ACCEPT_BLOCKED") { @($result.blocking_reasons).Count -gt 0 } else { $true }
}

$failed = @($checks.GetEnumerator() | Where-Object { -not [bool]$_.Value } | ForEach-Object { $_.Key })
$status = if ($failed.Count -eq 0) { "PASS" } else { "FAIL" }

$validation = [ordered]@{
  schema = "PHASE162_ATOM_ACCEPT_READINESS_GATE_VALIDATION_V1"
  status = $status
  created_at = (Get-Date -Format o)
  output_root = $OutputRoot
  gate_decision = [string]$result.gate_decision
  checks = $checks
  failed_checks = $failed
}

$validationPath = Join-Path $OutputRoot "accept_readiness_gate_validation.json"
$validation | ConvertTo-Json -Depth 20 | Set-Content -Path $validationPath -Encoding UTF8

if ($status -ne "PASS") {
  throw "PHASE162_ACCEPT_READINESS_GATE_VALIDATION_FAILED"
}

Write-Host "PHASE162_ACCEPT_READINESS_GATE_VALIDATION=PASS"
Write-Host "GATE_DECISION=$($result.gate_decision)"
Write-Host "VALIDATION_RESULT=$validationPath"
