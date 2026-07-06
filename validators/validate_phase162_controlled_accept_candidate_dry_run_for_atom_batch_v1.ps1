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

$result = Read-Json (Join-Path $OutputRoot "controlled_accept_candidate_dry_run_result.json")
$deltas = @(Read-Json (Join-Path $OutputRoot "controlled_accept_candidate_atom_deltas.json"))
$blocked = @(Read-Json (Join-Path $OutputRoot "controlled_accept_candidate_blocked_atoms.json"))
$rollback = Read-Json (Join-Path $OutputRoot "controlled_accept_candidate_rollback_plan.json")
$commitPlan = Read-Json (Join-Path $OutputRoot "controlled_accept_candidate_commit_plan.json")

$deltasWithReasons = @($deltas | Where-Object { @($_.reason_codes).Count -gt 0 })

$checks = [ordered]@{
  status_pass = ([string]$result.status -eq "PASS")
  batch_aware_true = ([bool]$result.batch_aware -eq $true)
  batch_size_positive = ([int]$result.batch_size -gt 0)
  staged_atom_count_positive = ([int]$result.staged_atom_count -gt 0)
  deltas_match_staged_count = ($deltas.Count -eq [int]$result.staged_atom_count)
  blocked_match_blocked_count = ($blocked.Count -eq [int]$result.blocked_atom_count)
  controlled_candidate_created_true = ([bool]$result.controlled_accept_candidate_created -eq $true)
  per_atom_deltas_true = ([bool]$result.per_atom_deltas_staged -eq $true)
  deltas_have_reasons = ($deltasWithReasons.Count -eq $deltas.Count)
  rollback_plan_staged_true = ([bool]$result.rollback_plan_staged -eq $true)
  rollback_mode_dry_run = ([string]$rollback.rollback_mode -eq "DRY_RUN_ONLY")
  commit_plan_staged_true = ([bool]$result.accept_commit_plan_staged -eq $true)
  commit_mode_dry_run = ([string]$commitPlan.commit_mode -eq "DRY_RUN_ONLY_NO_COMMIT_TO_ACCEPTED_CORE")
  final_accept_ready_false = ([bool]$result.final_accept_ready -eq $false)
  machine_decision_blocked = ([string]$result.machine_decision -eq "ACCEPT_BLOCKED_AUTONOMOUS_CYCLE")
  next_action_validate = ([string]$result.next_machine_action -eq "VALIDATE_CONTROLLED_ACCEPT_CANDIDATE_DRY_RUN_FOR_ATOM_BATCH")
  no_accepted_atom_claim = ([bool]$result.accepted_atom_claimed -eq $false)
  accepted_state_mutated_false = ([bool]$result.accepted_state_mutated -eq $false)
  accepted_memory_mutated_false = ([bool]$result.accepted_memory_mutated -eq $false)
  accepted_self_model_mutated_false = ([bool]$result.accepted_self_model_mutated -eq $false)
}

$failed = @($checks.GetEnumerator() | Where-Object { -not [bool]$_.Value } | ForEach-Object { $_.Key })
$status = if ($failed.Count -eq 0) { "PASS" } else { "FAIL" }

$validation = [ordered]@{
  schema = "PHASE162_CONTROLLED_ACCEPT_CANDIDATE_DRY_RUN_FOR_ATOM_BATCH_VALIDATION_V1"
  status = $status
  created_at = (Get-Date -Format o)
  output_root = $OutputRoot
  checks = $checks
  failed_checks = $failed
  batch_size = [int]$result.batch_size
  staged_atom_count = [int]$result.staged_atom_count
  blocked_atom_count = [int]$result.blocked_atom_count
  next_machine_action = [string]$result.next_machine_action
}

$validationPath = Join-Path $OutputRoot "controlled_accept_candidate_dry_run_validation.json"
$validation | ConvertTo-Json -Depth 100 | Set-Content -Path $validationPath -Encoding UTF8

if ($status -ne "PASS") {
  throw "PHASE162_CONTROLLED_ACCEPT_CANDIDATE_DRY_RUN_FOR_ATOM_BATCH_VALIDATION_FAILED"
}

Write-Host "PHASE162_CONTROLLED_ACCEPT_CANDIDATE_DRY_RUN_FOR_ATOM_BATCH_VALIDATION=PASS"
Write-Host "BATCH_AWARE=$($result.batch_aware)"
Write-Host "STAGED_ATOM_COUNT=$($result.staged_atom_count)"
Write-Host "BLOCKED_ATOM_COUNT=$($result.blocked_atom_count)"
Write-Host "NEXT_MACHINE_ACTION=$($result.next_machine_action)"
Write-Host "VALIDATION_RESULT=$validationPath"
