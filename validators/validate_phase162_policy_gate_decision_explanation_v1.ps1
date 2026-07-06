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

$explanation = Read-Json (Join-Path $OutputRoot "policy_gate_decision_explanation.json")
$reasons = @($explanation.why_not_final_accept | ForEach-Object { [string]$_ })
$reasonObjects = @($explanation.reason_codes)

$checks = [ordered]@{
  status_pass = ([string]$explanation.status -eq "PASS")
  decision_code_present = (-not [string]::IsNullOrWhiteSpace([string]$explanation.decision_code))
  summary_present = (-not [string]::IsNullOrWhiteSpace([string]$explanation.decision_summary))
  bounded_trial_allowed = ([bool]$explanation.allow_bounded_absorb_trial -eq $true)
  final_accept_denied = ([bool]$explanation.allow_final_accept -eq $false)
  accept_ready_false = ([bool]$explanation.accept_ready -eq $false)
  next_action_bounded_trial = ([string]$explanation.next_machine_action -eq "RUN_BOUNDED_LIVE_DAEMON_ABSORB_TRIAL_SANDBOX")
  reasons_present = ($reasons.Count -gt 0)
  reason_objects_present = ($reasonObjects.Count -gt 0)
  next_repair_action_present = (-not [string]::IsNullOrWhiteSpace([string]$explanation.next_repair_action))
  no_accepted_atom_claim = ([bool]$explanation.accepted_atom_claimed -eq $false)
  accepted_state_mutated_false = ([bool]$explanation.accepted_state_mutated -eq $false)
  accepted_memory_mutated_false = ([bool]$explanation.accepted_memory_mutated -eq $false)
  accepted_self_model_mutated_false = ([bool]$explanation.accepted_self_model_mutated -eq $false)
}

$failed = @($checks.GetEnumerator() | Where-Object { -not [bool]$_.Value } | ForEach-Object { $_.Key })
$status = if ($failed.Count -eq 0) { "PASS" } else { "FAIL" }

$validation = [ordered]@{
  schema = "PHASE162_POLICY_GATE_DECISION_EXPLANATION_VALIDATION_V1"
  status = $status
  created_at = (Get-Date -Format o)
  output_root = $OutputRoot
  checks = $checks
  failed_checks = $failed
  decision_code = [string]$explanation.decision_code
  next_machine_action = [string]$explanation.next_machine_action
}

$validationPath = Join-Path $OutputRoot "policy_gate_decision_explanation_validation.json"
$validation | ConvertTo-Json -Depth 80 | Set-Content -Path $validationPath -Encoding UTF8

if ($status -ne "PASS") {
  throw "PHASE162_POLICY_GATE_DECISION_EXPLANATION_VALIDATION_FAILED"
}

Write-Host "PHASE162_POLICY_GATE_DECISION_EXPLANATION_VALIDATION=PASS"
Write-Host "DECISION_CODE=$($explanation.decision_code)"
Write-Host "NEXT_MACHINE_ACTION=$($explanation.next_machine_action)"
Write-Host "REASON_COUNT=$($reasons.Count)"
Write-Host "VALIDATION_RESULT=$validationPath"
