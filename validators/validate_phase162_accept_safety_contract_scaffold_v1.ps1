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

$contract = Read-Json (Join-Path $OutputRoot "accept_safety_contract_scaffold.json")
$dryRun = Read-Json (Join-Path $OutputRoot "accept_safety_contract_dry_run.json")
$result = Read-Json (Join-Path $OutputRoot "accept_safety_contract_result.json")

$blockers = @($result.blocking_reasons | ForEach-Object { [string]$_ })

$checks = [ordered]@{
  result_status_pass = ([string]$result.status -eq "PASS")
  contract_status_pass = ([string]$contract.status -eq "PASS")
  dry_run_status_pass = ([string]$dryRun.status -eq "PASS")
  contract_mode_dry_run = ([string]$contract.contract_mode -eq "DRY_RUN_ONLY_NO_ACCEPTED_CORE_WRITES")
  safety_contracts_present_true = ([bool]$result.accept_safety_contracts_present -eq $true)
  safety_for_accept_false = ([bool]$result.safety_validated_for_accept -eq $false)
  usefulness_partial_true = ([bool]$result.usefulness_validated_partial -eq $true)
  accept_ready_false = ([bool]$result.accept_ready -eq $false)
  expected_accept_blocked = ([string]$result.expected_gate_decision -eq "ACCEPT_BLOCKED")
  owner_review_required = ([bool]$contract.owner_review_gate.required -eq $true)
  owner_review_not_granted = ([bool]$contract.owner_review_gate.granted -eq $false)
  rollback_scaffold_present = ([bool]$contract.rollback_plan.scaffold_present -eq $true)
  rollback_not_tested = ([bool]$contract.rollback_plan.rollback_tested -eq $false)
  owner_blocker_present = ($blockers -contains "owner_review_gate_missing")
  rollback_blocker_present = ($blockers -contains "rollback_test_not_proven")
  next_cycle_blocker_present = ($blockers -contains "next_cycle_improvement_proof_missing")
  accepted_core_write_not_attempted = ([bool]$dryRun.accepted_core_write_attempted -eq $false)
  no_accepted_atom_claim = ([bool]$result.accepted_atom_claimed -eq $false)
  accepted_state_mutated_false = ([bool]$result.accepted_state_mutated -eq $false)
  accepted_memory_mutated_false = ([bool]$result.accepted_memory_mutated -eq $false)
  accepted_self_model_mutated_false = ([bool]$result.accepted_self_model_mutated -eq $false)
}

$failed = @($checks.GetEnumerator() | Where-Object { -not [bool]$_.Value } | ForEach-Object { $_.Key })
$status = if ($failed.Count -eq 0) { "PASS" } else { "FAIL" }

$validation = [ordered]@{
  schema = "PHASE162_ACCEPT_SAFETY_CONTRACT_SCAFFOLD_VALIDATION_V1"
  status = $status
  created_at = (Get-Date -Format o)
  output_root = $OutputRoot
  checks = $checks
  failed_checks = $failed
  expected_gate_decision = [string]$result.expected_gate_decision
}

$validationPath = Join-Path $OutputRoot "accept_safety_contract_validation.json"
$validation | ConvertTo-Json -Depth 30 | Set-Content -Path $validationPath -Encoding UTF8

if ($status -ne "PASS") {
  throw "PHASE162_ACCEPT_SAFETY_CONTRACT_SCAFFOLD_VALIDATION_FAILED"
}

Write-Host "PHASE162_ACCEPT_SAFETY_CONTRACT_SCAFFOLD_VALIDATION=PASS"
Write-Host "ACCEPT_SAFETY_CONTRACTS_PRESENT=$($result.accept_safety_contracts_present)"
Write-Host "SAFETY_VALIDATED_FOR_ACCEPT=$($result.safety_validated_for_accept)"
Write-Host "EXPECTED_GATE_DECISION=$($result.expected_gate_decision)"
Write-Host "VALIDATION_RESULT=$validationPath"
