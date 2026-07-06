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

$result = Read-Json (Join-Path $OutputRoot "controlled_accept_core_mutation_dry_run_result.json")
$post = Read-Json (Join-Path $OutputRoot "bound_post_mutation_validation_dry_run_result.json")
$applied = Read-Json (Join-Path $OutputRoot "controlled_accept_core_mutation_dry_run_applied_state.json")

$eventsPath = Join-Path $OutputRoot "controlled_accept_core_mutation_dry_run_events.jsonl"
$eventCount = 0
if (Test-Path -LiteralPath $eventsPath) {
  $eventCount = @((Get-Content -LiteralPath $eventsPath)).Count
}

$checks = [ordered]@{
  status_pass = ([string]$result.status -eq "PASS")
  dry_run_passed_true = ([bool]$result.controlled_accept_core_mutation_dry_run_passed -eq $true)
  temporary_mutation_applied_true = ([bool]$result.temporary_mutation_applied -eq $true)
  post_validation_passed_true = ([bool]$result.bound_post_mutation_validation_passed -eq $true)
  post_validation_status_pass = ([string]$post.status -eq "PASS")
  rollback_restored_temp_state_true = ([bool]$result.rollback_restored_temp_state -eq $true)
  protected_targets_unchanged_true = ([bool]$result.protected_targets_unchanged -eq $true)
  staged_atom_count_positive = ([int]$result.staged_atom_count -gt 0)
  applied_state_no_write = ([bool]$applied.accepted_core_write -eq $false)
  post_validation_no_write = ([bool]$post.accepted_core_write -eq $false)
  event_count_at_least_four = ($eventCount -ge 4)
  final_accept_ready_false = ([bool]$result.final_accept_ready -eq $false)
  decision_blocked = ([string]$result.machine_decision -eq "ACCEPT_BLOCKED_AUTONOMOUS_CYCLE")
  next_action_feed_controller = ([string]$result.next_machine_action -eq "FEED_CONTROLLED_ACCEPT_CORE_MUTATION_DRY_RUN_BACK_INTO_CONTROLLER")
  no_accepted_atom_claim = ([bool]$result.accepted_atom_claimed -eq $false)
  accepted_state_mutated_false = ([bool]$result.accepted_state_mutated -eq $false)
  accepted_memory_mutated_false = ([bool]$result.accepted_memory_mutated -eq $false)
  accepted_self_model_mutated_false = ([bool]$result.accepted_self_model_mutated -eq $false)
}

$failed = @($checks.GetEnumerator() | Where-Object { -not [bool]$_.Value } | ForEach-Object { $_.Key })
$status = if ($failed.Count -eq 0) { "PASS" } else { "FAIL" }

$validation = [ordered]@{
  schema = "PHASE162_CONTROLLED_ACCEPT_CORE_MUTATION_DRY_RUN_FOR_ATOM_BATCH_VALIDATION_V1"
  status = $status
  created_at = (Get-Date -Format o)
  output_root = $OutputRoot
  checks = $checks
  failed_checks = $failed
  next_machine_action = [string]$result.next_machine_action
}

$validationPath = Join-Path $OutputRoot "controlled_accept_core_mutation_dry_run_validation.json"
$validation | ConvertTo-Json -Depth 100 | Set-Content -Path $validationPath -Encoding UTF8

if ($status -ne "PASS") {
  throw "PHASE162_CONTROLLED_ACCEPT_CORE_MUTATION_DRY_RUN_FOR_ATOM_BATCH_VALIDATION_FAILED"
}

Write-Host "PHASE162_CONTROLLED_ACCEPT_CORE_MUTATION_DRY_RUN_FOR_ATOM_BATCH_VALIDATION=PASS"
Write-Host "CONTROLLED_ACCEPT_CORE_MUTATION_DRY_RUN_PASSED=$($result.controlled_accept_core_mutation_dry_run_passed)"
Write-Host "BOUND_POST_MUTATION_VALIDATION_PASSED=$($result.bound_post_mutation_validation_passed)"
Write-Host "ROLLBACK_RESTORED_TEMP_STATE=$($result.rollback_restored_temp_state)"
Write-Host "PROTECTED_TARGETS_UNCHANGED=$($result.protected_targets_unchanged)"
Write-Host "NEXT_MACHINE_ACTION=$($result.next_machine_action)"
Write-Host "VALIDATION_RESULT=$validationPath"
