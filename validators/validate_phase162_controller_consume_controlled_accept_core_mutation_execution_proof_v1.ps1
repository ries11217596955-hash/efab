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

$result = Read-Json (Join-Path $OutputRoot "controller_consume_controlled_accept_core_mutation_execution_proof_result.json")

$checks = [ordered]@{
  status_pass = ([string]$result.status -eq "PASS")
  controller_finalization_executed_true = ([bool]$result.controller_finalization_executed -eq $true)
  accepted_atom_claimed_true = ([bool]$result.accepted_atom_claimed -eq $true)
  accepted_core_rewrite_not_executed = ([bool]$result.accepted_core_rewrite_executed -eq $false)
  repeated_mutation_not_executed = ([bool]$result.repeated_mutation_execution -eq $false)
  machine_decision_pending_visibility = ([string]$result.machine_decision -eq "CONTROLLED_ACCEPT_CORE_MUTATION_FINALIZED_PENDING_VISIBILITY_TRIAL")
  next_action_visibility_trial = ([string]$result.next_machine_action -eq "VERIFY_ACCEPTED_ATOM_VISIBLE_TO_NEXT_CYCLE")
  no_failed_checks = (@($result.failed_checks).Count -eq 0)
}

$failed = @($checks.GetEnumerator() | Where-Object { -not [bool]$_.Value } | ForEach-Object { $_.Key })
$status = if ($failed.Count -eq 0) { "PASS" } else { "FAIL" }

$validation = [ordered]@{
  schema = "PHASE162_CONTROLLER_CONSUME_CONTROLLED_ACCEPT_CORE_MUTATION_EXECUTION_PROOF_VALIDATION_V1"
  status = $status
  created_at = (Get-Date -Format o)
  output_root = $OutputRoot
  checks = $checks
  failed_checks = $failed
  next_machine_action = [string]$result.next_machine_action
}

$validationPath = Join-Path $OutputRoot "controller_consume_controlled_accept_core_mutation_execution_proof_validation.json"
$validation | ConvertTo-Json -Depth 100 | Set-Content -Path $validationPath -Encoding UTF8

if ($status -ne "PASS") {
  throw "PHASE162_CONTROLLER_CONSUME_CONTROLLED_ACCEPT_CORE_MUTATION_EXECUTION_PROOF_VALIDATION_FAILED"
}

Write-Host "PHASE162_CONTROLLER_CONSUME_CONTROLLED_ACCEPT_CORE_MUTATION_EXECUTION_PROOF_VALIDATION=PASS"
Write-Host "CONTROLLER_FINALIZATION_EXECUTED=$($result.controller_finalization_executed)"
Write-Host "ACCEPTED_ATOM_CLAIMED=$($result.accepted_atom_claimed)"
Write-Host "ACCEPTED_CORE_REWRITE_EXECUTED=$($result.accepted_core_rewrite_executed)"
Write-Host "REPEATED_MUTATION_EXECUTION=$($result.repeated_mutation_execution)"
Write-Host "NEXT_MACHINE_ACTION=$($result.next_machine_action)"
Write-Host "VALIDATION_RESULT=$validationPath"
