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

$result = Read-Json (Join-Path $OutputRoot "execute_controlled_accept_core_mutation_result.json")
$post = Read-Json (Join-Path $OutputRoot "post_real_mutation_validation_result.json")

$eventsPath = Join-Path $OutputRoot "controlled_accept_core_mutation_execution_events.jsonl"
$eventCount = 0
if (Test-Path -LiteralPath $eventsPath) {
  $eventCount = @((Get-Content -LiteralPath $eventsPath)).Count
}

$checks = [ordered]@{
  status_pass = ([string]$result.status -eq "PASS")
  core_mutation_executed_true = ([bool]$result.controlled_accept_core_mutation_executed -eq $true)
  post_real_validation_passed_true = ([bool]$result.post_real_mutation_validation_passed -eq $true)
  post_real_validation_status_pass = ([string]$post.status -eq "PASS")
  rollback_not_executed = ([bool]$result.rollback_executed -eq $false)
  staged_atom_count_positive = ([int]$result.staged_atom_count -gt 0)
  accepted_core_write_executed_true = ([bool]$result.accepted_core_write_executed -eq $true)
  accepted_memory_mutated_true = ([bool]$result.accepted_memory_mutated -eq $true)
  accepted_self_model_mutated_true = ([bool]$result.accepted_self_model_mutated -eq $true)
  registry_mutated_true = ([bool]$result.registry_mutated -eq $true)
  final_accept_ready_true = ([bool]$result.final_accept_ready -eq $true)
  event_count_at_least_three = ($eventCount -ge 3)
  machine_decision_pending_finalization = ([string]$result.machine_decision -eq "CONTROLLED_ACCEPT_CORE_MUTATION_EXECUTED_PENDING_CONTROLLER_FINALIZATION")
  next_action_feed_controller = ([string]$result.next_machine_action -eq "FEED_CONTROLLED_ACCEPT_CORE_MUTATION_EXECUTION_BACK_INTO_CONTROLLER")
  accepted_atom_not_final_claimed_yet = ([bool]$result.accepted_atom_claimed -eq $false)
}

$failed = @($checks.GetEnumerator() | Where-Object { -not [bool]$_.Value } | ForEach-Object { $_.Key })
$status = if ($failed.Count -eq 0) { "PASS" } else { "FAIL" }

$validation = [ordered]@{
  schema = "PHASE162_EXECUTE_CONTROLLED_ACCEPT_CORE_MUTATION_FOR_ATOM_BATCH_VALIDATION_V1"
  status = $status
  created_at = (Get-Date -Format o)
  output_root = $OutputRoot
  checks = $checks
  failed_checks = $failed
  next_machine_action = [string]$result.next_machine_action
}

$validationPath = Join-Path $OutputRoot "execute_controlled_accept_core_mutation_validation.json"
$validation | ConvertTo-Json -Depth 100 | Set-Content -Path $validationPath -Encoding UTF8

if ($status -ne "PASS") {
  throw "PHASE162_EXECUTE_CONTROLLED_ACCEPT_CORE_MUTATION_FOR_ATOM_BATCH_VALIDATION_FAILED"
}

Write-Host "PHASE162_EXECUTE_CONTROLLED_ACCEPT_CORE_MUTATION_FOR_ATOM_BATCH_VALIDATION=PASS"
Write-Host "CONTROLLED_ACCEPT_CORE_MUTATION_EXECUTED=$($result.controlled_accept_core_mutation_executed)"
Write-Host "POST_REAL_MUTATION_VALIDATION_PASSED=$($result.post_real_mutation_validation_passed)"
Write-Host "ACCEPTED_CORE_WRITE_EXECUTED=$($result.accepted_core_write_executed)"
Write-Host "FINAL_ACCEPT_READY=$($result.final_accept_ready)"
Write-Host "NEXT_MACHINE_ACTION=$($result.next_machine_action)"
Write-Host "VALIDATION_RESULT=$validationPath"
