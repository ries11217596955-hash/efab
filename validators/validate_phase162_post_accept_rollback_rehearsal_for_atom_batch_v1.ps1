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

$result = Read-Json (Join-Path $OutputRoot "post_accept_rollback_rehearsal_result.json")
$overlay = Read-Json (Join-Path $OutputRoot "overlay_apply_state.json")
$rollback = Read-Json (Join-Path $OutputRoot "rollback_rehearsal_result.json")

$eventsPath = Join-Path $OutputRoot "post_accept_rollback_rehearsal_events.jsonl"
$eventCount = 0
if (Test-Path -LiteralPath $eventsPath) {
  $eventCount = @((Get-Content -LiteralPath $eventsPath)).Count
}

$checks = [ordered]@{
  status_pass = ([string]$result.status -eq "PASS")
  rollback_passed_true = ([bool]$result.rollback_rehearsal_passed -eq $true)
  overlay_apply_passed_true = ([bool]$result.overlay_apply_passed -eq $true)
  overlay_file_count_at_least_four = ([int]$result.overlay_file_count_before_rollback -ge 4)
  overlay_removed_true = ([bool]$result.overlay_removed_after_rollback -eq $true)
  protected_targets_unchanged_true = ([bool]$result.protected_targets_unchanged -eq $true)
  rollback_result_pass = ([string]$rollback.status -eq "PASS")
  overlay_state_pass = ([string]$overlay.status -eq "PASS")
  staged_atom_count_positive = ([int]$result.staged_atom_count -gt 0)
  event_log_present = ($eventCount -ge 3)
  final_accept_ready_false = ([bool]$result.final_accept_ready -eq $false)
  decision_blocked = ([string]$result.machine_decision -eq "ACCEPT_BLOCKED_AUTONOMOUS_CYCLE")
  next_action_feed_controller = ([string]$result.next_machine_action -eq "FEED_POST_ACCEPT_ROLLBACK_REHEARSAL_BACK_INTO_CONTROLLER")
  no_accepted_atom_claim = ([bool]$result.accepted_atom_claimed -eq $false)
  accepted_state_mutated_false = ([bool]$result.accepted_state_mutated -eq $false)
  accepted_memory_mutated_false = ([bool]$result.accepted_memory_mutated -eq $false)
  accepted_self_model_mutated_false = ([bool]$result.accepted_self_model_mutated -eq $false)
}

$failed = @($checks.GetEnumerator() | Where-Object { -not [bool]$_.Value } | ForEach-Object { $_.Key })
$status = if ($failed.Count -eq 0) { "PASS" } else { "FAIL" }

$validation = [ordered]@{
  schema = "PHASE162_POST_ACCEPT_ROLLBACK_REHEARSAL_FOR_ATOM_BATCH_VALIDATION_V1"
  status = $status
  created_at = (Get-Date -Format o)
  output_root = $OutputRoot
  checks = $checks
  failed_checks = $failed
  next_machine_action = [string]$result.next_machine_action
}

$validationPath = Join-Path $OutputRoot "post_accept_rollback_rehearsal_validation.json"
$validation | ConvertTo-Json -Depth 100 | Set-Content -Path $validationPath -Encoding UTF8

if ($status -ne "PASS") {
  throw "PHASE162_POST_ACCEPT_ROLLBACK_REHEARSAL_FOR_ATOM_BATCH_VALIDATION_FAILED"
}

Write-Host "PHASE162_POST_ACCEPT_ROLLBACK_REHEARSAL_FOR_ATOM_BATCH_VALIDATION=PASS"
Write-Host "ROLLBACK_REHEARSAL_PASSED=$($result.rollback_rehearsal_passed)"
Write-Host "OVERLAY_FILE_COUNT_BEFORE_ROLLBACK=$($result.overlay_file_count_before_rollback)"
Write-Host "OVERLAY_REMOVED_AFTER_ROLLBACK=$($result.overlay_removed_after_rollback)"
Write-Host "PROTECTED_TARGETS_UNCHANGED=$($result.protected_targets_unchanged)"
Write-Host "NEXT_MACHINE_ACTION=$($result.next_machine_action)"
Write-Host "VALIDATION_RESULT=$validationPath"
