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

$result = Read-Json (Join-Path $OutputRoot "controller_consume_controlled_accept_candidate_batch_result.json")
$request = Read-Json (Join-Path $OutputRoot "post_accept_rollback_rehearsal_for_atom_batch_request.json")

$checks = [ordered]@{
  status_pass = ([string]$result.status -eq "PASS")
  decision_blocked = ([string]$result.machine_decision -eq "ACCEPT_BLOCKED_AUTONOMOUS_CYCLE")
  next_action_rollback = ([string]$result.next_machine_action -eq "REHEARSE_POST_ACCEPT_ROLLBACK_FOR_ATOM_BATCH")
  candidate_validation_passed = ([bool]$result.preconditions.candidate_validation_passed -eq $true)
  candidate_batch_aware = ([bool]$result.preconditions.candidate_batch_aware -eq $true)
  staged_atom_count_positive = ([bool]$result.preconditions.staged_atom_count_positive -eq $true)
  per_atom_deltas_match = ([bool]$result.preconditions.per_atom_deltas_match -eq $true)
  commit_plan_staged = ([bool]$result.preconditions.commit_plan_staged -eq $true)
  rollback_plan_staged = ([bool]$result.preconditions.rollback_plan_staged -eq $true)
  rollback_not_rehearsed_yet = ([bool]$result.preconditions.rollback_rehearsed -eq $false)
  accepted_core_not_mutated = ([bool]$result.preconditions.accepted_core_not_mutated -eq $true)
  request_ready = ([string]$request.status -eq "READY_TO_BUILD")
  request_module_named = ([string]$request.next_module_to_build -eq "invoke_phase162_post_accept_rollback_rehearsal_for_atom_batch_001.ps1")
  no_accepted_atom_claim = ([bool]$result.accepted_atom_claimed -eq $false)
  accepted_state_mutated_false = ([bool]$result.accepted_state_mutated -eq $false)
  accepted_memory_mutated_false = ([bool]$result.accepted_memory_mutated -eq $false)
  accepted_self_model_mutated_false = ([bool]$result.accepted_self_model_mutated -eq $false)
}

$failed = @($checks.GetEnumerator() | Where-Object { -not [bool]$_.Value } | ForEach-Object { $_.Key })
$status = if ($failed.Count -eq 0) { "PASS" } else { "FAIL" }

$validation = [ordered]@{
  schema = "PHASE162_CONTROLLER_CONSUME_CONTROLLED_ACCEPT_CANDIDATE_BATCH_VALIDATION_V1"
  status = $status
  created_at = (Get-Date -Format o)
  output_root = $OutputRoot
  checks = $checks
  failed_checks = $failed
  machine_decision = [string]$result.machine_decision
  next_machine_action = [string]$result.next_machine_action
}

$validationPath = Join-Path $OutputRoot "controller_consume_controlled_accept_candidate_batch_validation.json"
$validation | ConvertTo-Json -Depth 100 | Set-Content -Path $validationPath -Encoding UTF8

if ($status -ne "PASS") {
  throw "PHASE162_CONTROLLER_CONSUME_CONTROLLED_ACCEPT_CANDIDATE_BATCH_VALIDATION_FAILED"
}

Write-Host "PHASE162_CONTROLLER_CONSUME_CONTROLLED_ACCEPT_CANDIDATE_BATCH_VALIDATION=PASS"
Write-Host "MACHINE_DECISION=$($result.machine_decision)"
Write-Host "NEXT_MACHINE_ACTION=$($result.next_machine_action)"
Write-Host "STAGED_ATOM_COUNT=$($result.staged_atom_count)"
Write-Host "VALIDATION_RESULT=$validationPath"
