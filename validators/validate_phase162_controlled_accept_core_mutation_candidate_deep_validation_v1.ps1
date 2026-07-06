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

$result = Read-Json (Join-Path $OutputRoot "controlled_accept_core_mutation_candidate_deep_validation_result.json")
$checks = Read-Json (Join-Path $OutputRoot "controlled_accept_core_mutation_candidate_deep_validation_checks.json")

$validationChecks = [ordered]@{
  status_pass = ([string]$result.status -eq "PASS")
  deep_validated_true = ([bool]$result.controlled_accept_core_mutation_candidate_deep_validated -eq $true)
  upstream_ok = ([bool]$checks.upstream_ok -eq $true)
  ops_counts_valid = ([bool]$checks.ops_counts_valid -eq $true)
  operation_ids_unique = ([bool]$checks.operation_ids_unique -eq $true)
  atom_ids_aligned = ([bool]$checks.atom_ids_aligned -eq $true)
  targets_allowed = ([bool]$checks.targets_allowed -eq $true)
  no_write_modes = ([bool]$checks.no_write_modes -eq $true)
  final_write_denied_everywhere = ([bool]$checks.final_write_denied_everywhere -eq $true)
  write_plan_valid = ([bool]$checks.write_plan_valid -eq $true)
  rollback_plan_valid = ([bool]$checks.rollback_plan_valid -eq $true)
  post_binding_valid = ([bool]$checks.post_mutation_validation_binding_valid -eq $true)
  fingerprints_present = ([bool]$checks.fingerprint_targets_present -eq $true)
  fingerprints_match = ([bool]$checks.pre_after_fingerprints_match -eq $true)
  accepted_core_safe = ([bool]$checks.accepted_core_safe -eq $true)
  final_accept_ready_false = ([bool]$result.final_accept_ready -eq $false)
  decision_blocked = ([string]$result.machine_decision -eq "ACCEPT_BLOCKED_AUTONOMOUS_CYCLE")
  next_action_feed_controller = ([string]$result.next_machine_action -eq "FEED_VALIDATED_CONTROLLED_ACCEPT_CORE_MUTATION_CANDIDATE_BACK_INTO_CONTROLLER")
  no_accepted_atom_claim = ([bool]$result.accepted_atom_claimed -eq $false)
  accepted_state_mutated_false = ([bool]$result.accepted_state_mutated -eq $false)
  accepted_memory_mutated_false = ([bool]$result.accepted_memory_mutated -eq $false)
  accepted_self_model_mutated_false = ([bool]$result.accepted_self_model_mutated -eq $false)
}

$failed = @($validationChecks.GetEnumerator() | Where-Object { -not [bool]$_.Value } | ForEach-Object { $_.Key })
$status = if ($failed.Count -eq 0) { "PASS" } else { "FAIL" }

$validation = [ordered]@{
  schema = "PHASE162_CONTROLLED_ACCEPT_CORE_MUTATION_CANDIDATE_DEEP_VALIDATION_FOR_ATOM_BATCH_VALIDATION_V1"
  status = $status
  created_at = (Get-Date -Format o)
  output_root = $OutputRoot
  checks = $validationChecks
  failed_checks = $failed
  next_machine_action = [string]$result.next_machine_action
}

$validationPath = Join-Path $OutputRoot "controlled_accept_core_mutation_candidate_deep_validation_validation.json"
$validation | ConvertTo-Json -Depth 100 | Set-Content -Path $validationPath -Encoding UTF8

if ($status -ne "PASS") {
  throw "PHASE162_CONTROLLED_ACCEPT_CORE_MUTATION_CANDIDATE_DEEP_VALIDATION_FOR_ATOM_BATCH_VALIDATION_FAILED"
}

Write-Host "PHASE162_CONTROLLED_ACCEPT_CORE_MUTATION_CANDIDATE_DEEP_VALIDATION_FOR_ATOM_BATCH_VALIDATION=PASS"
Write-Host "CANDIDATE_DEEP_VALIDATED=$($result.controlled_accept_core_mutation_candidate_deep_validated)"
Write-Host "STAGED_ATOM_COUNT=$($result.staged_atom_count)"
Write-Host "NEXT_MACHINE_ACTION=$($result.next_machine_action)"
Write-Host "VALIDATION_RESULT=$validationPath"
