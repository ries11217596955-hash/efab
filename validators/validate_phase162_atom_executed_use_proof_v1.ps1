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

$card = Read-Json (Join-Path $OutputRoot "executed_use_card.json")
$result = Read-Json (Join-Path $OutputRoot "executed_use_proof_result.json")

$checks = [ordered]@{
  result_status_pass = ([string]$result.status -eq "PASS")
  use_card_status_pass = ([string]$card.status -eq "PASS")
  executed_use_passed = ([bool]$result.executed_use_proof_passed -eq $true)
  partial_usefulness_true = ([bool]$result.usefulness_validated_partial -eq $true)
  usefulness_for_accept_false = ([bool]$result.usefulness_validated_for_accept -eq $false)
  safety_for_accept_false = ([bool]$result.safety_validated_for_accept -eq $false)
  accept_ready_false = ([bool]$result.accept_ready -eq $false)
  expected_gate_accept_blocked = ([string]$result.expected_gate_decision -eq "ACCEPT_BLOCKED")
  selected_skill_count_positive = ([int]$card.selected_skill_candidate_count -gt 0)
  owner_visible_value_present = (-not [string]::IsNullOrWhiteSpace([string]$card.owner_visible_value))
  no_accepted_atom_claim = ([bool]$result.accepted_atom_claimed -eq $false)
  accepted_state_mutated_false = ([bool]$result.accepted_state_mutated -eq $false)
  accepted_memory_mutated_false = ([bool]$result.accepted_memory_mutated -eq $false)
  accepted_self_model_mutated_false = ([bool]$result.accepted_self_model_mutated -eq $false)
}

$failed = @($checks.GetEnumerator() | Where-Object { -not [bool]$_.Value } | ForEach-Object { $_.Key })
$status = if ($failed.Count -eq 0) { "PASS" } else { "FAIL" }

$validation = [ordered]@{
  schema = "PHASE162_ATOM_EXECUTED_USE_PROOF_VALIDATION_V1"
  status = $status
  created_at = (Get-Date -Format o)
  output_root = $OutputRoot
  checks = $checks
  failed_checks = $failed
  expected_gate_decision = [string]$result.expected_gate_decision
}

$validationPath = Join-Path $OutputRoot "executed_use_proof_validation.json"
$validation | ConvertTo-Json -Depth 20 | Set-Content -Path $validationPath -Encoding UTF8

if ($status -ne "PASS") {
  throw "PHASE162_EXECUTED_USE_PROOF_VALIDATION_FAILED"
}

Write-Host "PHASE162_EXECUTED_USE_PROOF_VALIDATION=PASS"
Write-Host "EXECUTED_USE_PROOF_PASSED=$($result.executed_use_proof_passed)"
Write-Host "EXPECTED_GATE_DECISION=$($result.expected_gate_decision)"
Write-Host "VALIDATION_RESULT=$validationPath"
