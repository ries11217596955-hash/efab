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

$result = Read-Json (Join-Path $OutputRoot "accept_safety_contract_dry_run_activation_result.json")

$checks = [ordered]@{
  status_pass = ([string]$result.status -eq "PASS")
  dry_run_activated = ([bool]$result.accept_safety_contract_dry_run_activated -eq $true)
  safety_validated_for_accept_true = ([bool]$result.safety_validated_for_accept -eq $true)
  rollback_tested_true = ([bool]$result.rollback_tested -eq $true)
  protected_paths_unchanged_true = ([bool]$result.protected_paths_unchanged -eq $true)
  protected_writes_denied_true = ([bool]$result.protected_writes_denied -eq $true)
  allowed_write_probe_created_true = ([bool]$result.allowed_write_probe_created -eq $true)
  owner_review_not_granted = ([bool]$result.owner_review_granted -eq $false)
  accept_ready_false = ([bool]$result.accept_ready -eq $false)
  expected_decision_blocked = ([string]$result.expected_machine_decision -eq "ACCEPT_BLOCKED_AUTONOMOUS_CYCLE")
  next_action_owner_review = ([string]$result.next_machine_action_after_controller_consumes_this -eq "REQUEST_OWNER_REVIEW_FOR_CONTROLLED_ACCEPT")
  no_accepted_atom_claim = ([bool]$result.accepted_atom_claimed -eq $false)
  accepted_state_mutated_false = ([bool]$result.accepted_state_mutated -eq $false)
  accepted_memory_mutated_false = ([bool]$result.accepted_memory_mutated -eq $false)
  accepted_self_model_mutated_false = ([bool]$result.accepted_self_model_mutated -eq $false)
}

$failed = @($checks.GetEnumerator() | Where-Object { -not [bool]$_.Value } | ForEach-Object { $_.Key })
$status = if ($failed.Count -eq 0) { "PASS" } else { "FAIL" }

$validation = [ordered]@{
  schema = "PHASE162_ACCEPT_SAFETY_CONTRACT_DRY_RUN_ACTIVATION_VALIDATION_V1"
  status = $status
  created_at = (Get-Date -Format o)
  output_root = $OutputRoot
  checks = $checks
  failed_checks = $failed
  next_machine_action_after_controller_consumes_this = [string]$result.next_machine_action_after_controller_consumes_this
}

$validationPath = Join-Path $OutputRoot "accept_safety_contract_dry_run_activation_validation.json"
$validation | ConvertTo-Json -Depth 70 | Set-Content -Path $validationPath -Encoding UTF8

if ($status -ne "PASS") {
  throw "PHASE162_ACCEPT_SAFETY_CONTRACT_DRY_RUN_ACTIVATION_VALIDATION_FAILED"
}

Write-Host "PHASE162_ACCEPT_SAFETY_DRY_RUN_ACTIVATION_VALIDATION=PASS"
Write-Host "SAFETY_VALIDATED_FOR_ACCEPT=$($result.safety_validated_for_accept)"
Write-Host "ROLLBACK_TESTED=$($result.rollback_tested)"
Write-Host "PROTECTED_PATHS_UNCHANGED=$($result.protected_paths_unchanged)"
Write-Host "NEXT_MACHINE_ACTION_AFTER_CONSUME=$($result.next_machine_action_after_controller_consumes_this)"
Write-Host "VALIDATION_RESULT=$validationPath"
