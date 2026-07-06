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

$result = Read-Json (Join-Path $OutputRoot "controller_consume_validated_controlled_accept_candidate_batch_result.json")
$request = Read-Json (Join-Path $OutputRoot "controlled_accept_core_mutation_dry_run_authorization_for_atom_batch.json")

$checks = [ordered]@{
  status_pass = ([string]$result.status -eq "PASS")
  decision_blocked = ([string]$result.machine_decision -eq "ACCEPT_BLOCKED_AUTONOMOUS_CYCLE")
  next_action_authorize_dry_run = ([string]$result.next_machine_action -eq "AUTHORIZE_CONTROLLED_ACCEPT_CORE_MUTATION_DRY_RUN_FOR_ATOM_BATCH")
  deep_validation_passed = ([bool]$result.preconditions.deep_validation_passed -eq $true)
  candidate_deep_validated = ([bool]$result.preconditions.candidate_deep_validated -eq $true)
  candidate_prepared = ([bool]$result.preconditions.candidate_prepared -eq $true)
  no_write_modes = ([bool]$result.preconditions.no_write_modes -eq $true)
  final_write_denied_everywhere = ([bool]$result.preconditions.final_write_denied_everywhere -eq $true)
  rollback_plan_valid = ([bool]$result.preconditions.rollback_plan_valid -eq $true)
  post_binding_valid = ([bool]$result.preconditions.post_mutation_validation_binding_valid -eq $true)
  accepted_core_safe = ([bool]$result.preconditions.accepted_core_safe -eq $true)
  request_authorized_dry_run_only = ([string]$request.status -eq "AUTHORIZED_DRY_RUN_ONLY")
  request_scope_dry_run_only = ([string]$request.authorization_scope -eq "DRY_RUN_ONLY_NO_ACCEPTED_CORE_WRITES")
  request_module_named = ([string]$request.next_module_to_build -eq "invoke_phase162_controlled_accept_core_mutation_dry_run_for_atom_batch_001.ps1")
  no_accepted_atom_claim = ([bool]$result.accepted_atom_claimed -eq $false)
  accepted_state_mutated_false = ([bool]$result.accepted_state_mutated -eq $false)
  accepted_memory_mutated_false = ([bool]$result.accepted_memory_mutated -eq $false)
  accepted_self_model_mutated_false = ([bool]$result.accepted_self_model_mutated -eq $false)
}

$failed = @($checks.GetEnumerator() | Where-Object { -not [bool]$_.Value } | ForEach-Object { $_.Key })
$status = if ($failed.Count -eq 0) { "PASS" } else { "FAIL" }

$validation = [ordered]@{
  schema = "PHASE162_CONTROLLER_CONSUME_VALIDATED_CONTROLLED_ACCEPT_CANDIDATE_BATCH_VALIDATION_V1"
  status = $status
  created_at = (Get-Date -Format o)
  output_root = $OutputRoot
  checks = $checks
  failed_checks = $failed
  machine_decision = [string]$result.machine_decision
  next_machine_action = [string]$result.next_machine_action
}

$validationPath = Join-Path $OutputRoot "controller_consume_validated_controlled_accept_candidate_batch_validation.json"
$validation | ConvertTo-Json -Depth 100 | Set-Content -Path $validationPath -Encoding UTF8

if ($status -ne "PASS") {
  throw "PHASE162_CONTROLLER_CONSUME_VALIDATED_CONTROLLED_ACCEPT_CANDIDATE_BATCH_VALIDATION_FAILED"
}

Write-Host "PHASE162_CONTROLLER_CONSUME_VALIDATED_CONTROLLED_ACCEPT_CANDIDATE_BATCH_VALIDATION=PASS"
Write-Host "MACHINE_DECISION=$($result.machine_decision)"
Write-Host "NEXT_MACHINE_ACTION=$($result.next_machine_action)"
Write-Host "STAGED_ATOM_COUNT=$($result.staged_atom_count)"
Write-Host "VALIDATION_RESULT=$validationPath"
