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

$result = Read-Json (Join-Path $OutputRoot "autonomous_accept_policy_gate_result.json")
$request = Read-Json (Join-Path $OutputRoot "bounded_live_daemon_absorb_trial_request.json")

$checks = [ordered]@{
  status_pass = ([string]$result.status -eq "PASS")
  policy_gate_present_true = ([bool]$result.policy_gate_present -eq $true)
  human_owner_review_replaced_true = ([bool]$result.human_owner_review_replaced_by_policy_gate -eq $true)
  bounded_absorb_trial_granted_true = ([bool]$result.policy_granted_for_bounded_absorb_trial -eq $true)
  final_accept_false = ([bool]$result.policy_granted_for_final_accept -eq $false)
  accept_ready_false = ([bool]$result.accept_ready -eq $false)
  decision_blocked = ([string]$result.machine_decision -eq "ACCEPT_BLOCKED_AUTONOMOUS_CYCLE")
  next_action_bounded_absorb = ([string]$result.next_machine_action -eq "RUN_BOUNDED_LIVE_DAEMON_ABSORB_TRIAL_SANDBOX")
  request_ready = ([string]$request.status -eq "READY_TO_BUILD")
  request_module_named = ([string]$request.next_module_to_build -eq "invoke_phase162_bounded_live_daemon_absorb_trial_sandbox_001.ps1")
  safety_true = ([bool]$result.policy_checks.safety_validated_for_accept -eq $true)
  rollback_true = ([bool]$result.policy_checks.rollback_tested -eq $true)
  protected_paths_true = ([bool]$result.policy_checks.protected_paths_unchanged -eq $true)
  no_accepted_atom_claim = ([bool]$result.accepted_atom_claimed -eq $false)
  accepted_state_mutated_false = ([bool]$result.accepted_state_mutated -eq $false)
  accepted_memory_mutated_false = ([bool]$result.accepted_memory_mutated -eq $false)
  accepted_self_model_mutated_false = ([bool]$result.accepted_self_model_mutated -eq $false)
}

$failed = @($checks.GetEnumerator() | Where-Object { -not [bool]$_.Value } | ForEach-Object { $_.Key })
$status = if ($failed.Count -eq 0) { "PASS" } else { "FAIL" }

$validation = [ordered]@{
  schema = "PHASE162_AUTONOMOUS_ACCEPT_POLICY_GATE_VALIDATION_V1"
  status = $status
  created_at = (Get-Date -Format o)
  output_root = $OutputRoot
  checks = $checks
  failed_checks = $failed
  machine_decision = [string]$result.machine_decision
  next_machine_action = [string]$result.next_machine_action
}

$validationPath = Join-Path $OutputRoot "autonomous_accept_policy_gate_validation.json"
$validation | ConvertTo-Json -Depth 80 | Set-Content -Path $validationPath -Encoding UTF8

if ($status -ne "PASS") {
  throw "PHASE162_AUTONOMOUS_ACCEPT_POLICY_GATE_VALIDATION_FAILED"
}

Write-Host "PHASE162_AUTONOMOUS_ACCEPT_POLICY_GATE_VALIDATION=PASS"
Write-Host "POLICY_GATE_PRESENT=$($result.policy_gate_present)"
Write-Host "HUMAN_OWNER_REVIEW_REPLACED=$($result.human_owner_review_replaced_by_policy_gate)"
Write-Host "POLICY_GRANTED_FOR_BOUNDED_ABSORB_TRIAL=$($result.policy_granted_for_bounded_absorb_trial)"
Write-Host "NEXT_MACHINE_ACTION=$($result.next_machine_action)"
Write-Host "VALIDATION_RESULT=$validationPath"
