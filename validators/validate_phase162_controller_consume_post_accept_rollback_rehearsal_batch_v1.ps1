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

$result = Read-Json (Join-Path $OutputRoot "controller_consume_post_accept_rollback_rehearsal_batch_result.json")
$request = Read-Json (Join-Path $OutputRoot "post_accept_validation_dry_run_for_atom_batch_request.json")

$checks = [ordered]@{
  status_pass = ([string]$result.status -eq "PASS")
  decision_blocked = ([string]$result.machine_decision -eq "ACCEPT_BLOCKED_AUTONOMOUS_CYCLE")
  next_action_post_accept_validation = ([string]$result.next_machine_action -eq "BUILD_POST_ACCEPT_VALIDATION_DRY_RUN_FOR_ATOM_BATCH")
  rollback_passed_true = ([bool]$result.preconditions.rollback_rehearsal_passed -eq $true)
  overlay_apply_passed_true = ([bool]$result.preconditions.overlay_apply_passed -eq $true)
  overlay_count_at_least_four = ([int]$result.preconditions.overlay_file_count_before_rollback -ge 4)
  protected_targets_unchanged_true = ([bool]$result.preconditions.protected_targets_unchanged -eq $true)
  accepted_core_not_mutated_true = ([bool]$result.preconditions.accepted_core_not_mutated -eq $true)
  staged_atom_count_positive = ([bool]$result.preconditions.staged_atom_count_positive -eq $true)
  request_ready = ([string]$request.status -eq "READY_TO_BUILD")
  request_module_named = ([string]$request.next_module_to_build -eq "invoke_phase162_post_accept_validation_dry_run_for_atom_batch_001.ps1")
  no_accepted_atom_claim = ([bool]$result.accepted_atom_claimed -eq $false)
  accepted_state_mutated_false = ([bool]$result.accepted_state_mutated -eq $false)
  accepted_memory_mutated_false = ([bool]$result.accepted_memory_mutated -eq $false)
  accepted_self_model_mutated_false = ([bool]$result.accepted_self_model_mutated -eq $false)
}

$failed = @($checks.GetEnumerator() | Where-Object { -not [bool]$_.Value } | ForEach-Object { $_.Key })
$status = if ($failed.Count -eq 0) { "PASS" } else { "FAIL" }

$validation = [ordered]@{
  schema = "PHASE162_CONTROLLER_CONSUME_POST_ACCEPT_ROLLBACK_REHEARSAL_BATCH_VALIDATION_V1"
  status = $status
  created_at = (Get-Date -Format o)
  output_root = $OutputRoot
  checks = $checks
  failed_checks = $failed
  machine_decision = [string]$result.machine_decision
  next_machine_action = [string]$result.next_machine_action
}

$validationPath = Join-Path $OutputRoot "controller_consume_post_accept_rollback_rehearsal_batch_validation.json"
$validation | ConvertTo-Json -Depth 100 | Set-Content -Path $validationPath -Encoding UTF8

if ($status -ne "PASS") {
  throw "PHASE162_CONTROLLER_CONSUME_POST_ACCEPT_ROLLBACK_REHEARSAL_BATCH_VALIDATION_FAILED"
}

Write-Host "PHASE162_CONTROLLER_CONSUME_POST_ACCEPT_ROLLBACK_REHEARSAL_BATCH_VALIDATION=PASS"
Write-Host "MACHINE_DECISION=$($result.machine_decision)"
Write-Host "NEXT_MACHINE_ACTION=$($result.next_machine_action)"
Write-Host "STAGED_ATOM_COUNT=$($result.staged_atom_count)"
Write-Host "VALIDATION_RESULT=$validationPath"
