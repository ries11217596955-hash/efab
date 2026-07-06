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

$result = Read-Json (Join-Path $OutputRoot "post_accept_validation_dry_run_result.json")
$checks = Read-Json (Join-Path $OutputRoot "post_accept_validation_checks.json")

$eventsPath = Join-Path $OutputRoot "post_accept_validation_dry_run_events.jsonl"
$eventCount = 0
if (Test-Path -LiteralPath $eventsPath) {
  $eventCount = @((Get-Content -LiteralPath $eventsPath)).Count
}

$validationChecks = [ordered]@{
  status_pass = ([string]$result.status -eq "PASS")
  dry_run_passed_true = ([bool]$result.post_accept_validation_dry_run_passed -eq $true)
  memory_schema_valid_true = ([bool]$result.memory_schema_valid -eq $true)
  self_model_schema_valid_true = ([bool]$result.self_model_schema_valid -eq $true)
  registry_consistency_valid_true = ([bool]$result.registry_consistency_valid -eq $true)
  next_cycle_visibility_valid_true = ([bool]$result.next_cycle_visibility_valid -eq $true)
  protected_targets_unchanged_true = ([bool]$result.protected_targets_unchanged -eq $true)
  overlay_file_count_at_least_five = ([int]$result.overlay_file_count -ge 5)
  staged_atom_count_positive = ([int]$result.staged_atom_count -gt 0)
  event_log_present = ($eventCount -ge 3)
  final_accept_ready_false = ([bool]$result.final_accept_ready -eq $false)
  decision_blocked = ([string]$result.machine_decision -eq "ACCEPT_BLOCKED_AUTONOMOUS_CYCLE")
  next_action_feed_controller = ([string]$result.next_machine_action -eq "FEED_POST_ACCEPT_VALIDATION_DRY_RUN_BACK_INTO_CONTROLLER")
  no_accepted_atom_claim = ([bool]$result.accepted_atom_claimed -eq $false)
  accepted_state_mutated_false = ([bool]$result.accepted_state_mutated -eq $false)
  accepted_memory_mutated_false = ([bool]$result.accepted_memory_mutated -eq $false)
  accepted_self_model_mutated_false = ([bool]$result.accepted_self_model_mutated -eq $false)
}

$failed = @($validationChecks.GetEnumerator() | Where-Object { -not [bool]$_.Value } | ForEach-Object { $_.Key })
$status = if ($failed.Count -eq 0) { "PASS" } else { "FAIL" }

$validation = [ordered]@{
  schema = "PHASE162_POST_ACCEPT_VALIDATION_DRY_RUN_FOR_ATOM_BATCH_VALIDATION_V1"
  status = $status
  created_at = (Get-Date -Format o)
  output_root = $OutputRoot
  checks = $validationChecks
  upstream_checks = $checks
  failed_checks = $failed
  next_machine_action = [string]$result.next_machine_action
}

$validationPath = Join-Path $OutputRoot "post_accept_validation_dry_run_validation.json"
$validation | ConvertTo-Json -Depth 100 | Set-Content -Path $validationPath -Encoding UTF8

if ($status -ne "PASS") {
  throw "PHASE162_POST_ACCEPT_VALIDATION_DRY_RUN_FOR_ATOM_BATCH_VALIDATION_FAILED"
}

Write-Host "PHASE162_POST_ACCEPT_VALIDATION_DRY_RUN_FOR_ATOM_BATCH_VALIDATION=PASS"
Write-Host "POST_ACCEPT_VALIDATION_DRY_RUN_PASSED=$($result.post_accept_validation_dry_run_passed)"
Write-Host "NEXT_CYCLE_VISIBILITY_VALID=$($result.next_cycle_visibility_valid)"
Write-Host "PROTECTED_TARGETS_UNCHANGED=$($result.protected_targets_unchanged)"
Write-Host "NEXT_MACHINE_ACTION=$($result.next_machine_action)"
Write-Host "VALIDATION_RESULT=$validationPath"
