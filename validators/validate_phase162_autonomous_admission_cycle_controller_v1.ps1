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

$cycle = Read-Json (Join-Path $OutputRoot "autonomous_admission_cycle_result.json")
$trial = Read-Json (Join-Path $OutputRoot "next_cycle_improvement_trial_request.json")

$checks = [ordered]@{
  cycle_status_pass = ([string]$cycle.status -eq "PASS")
  controller_mode_dry_run = ([string]$cycle.controller_mode -eq "AUTONOMOUS_DRY_RUN_NO_ACCEPTED_CORE_WRITES")
  atom_generated_true = ([bool]$cycle.preconditions.atom_generated -eq $true)
  freeze_evidence_true = ([bool]$cycle.preconditions.freeze_evidence_proven -eq $true)
  partial_usefulness_true = ([bool]$cycle.preconditions.partial_usefulness_proven -eq $true)
  safety_contracts_present_true = ([bool]$cycle.preconditions.safety_contracts_present -eq $true)
  next_cycle_improvement_false = ([bool]$cycle.preconditions.next_cycle_improvement_proven -eq $false)
  decision_blocked_now = ([string]$cycle.machine_decision -eq "ACCEPT_BLOCKED_AUTONOMOUS_CYCLE")
  next_action_is_trial = ([string]$cycle.next_machine_action -eq "RUN_NEXT_CYCLE_IMPROVEMENT_TRIAL_SANDBOX")
  trial_request_ready = ([string]$trial.status -eq "READY_TO_BUILD_TRIAL")
  no_accepted_atom_claim = ([bool]$cycle.accepted_atom_claimed -eq $false)
  accepted_state_mutated_false = ([bool]$cycle.accepted_state_mutated -eq $false)
  accepted_memory_mutated_false = ([bool]$cycle.accepted_memory_mutated -eq $false)
  accepted_self_model_mutated_false = ([bool]$cycle.accepted_self_model_mutated -eq $false)
}

$failed = @($checks.GetEnumerator() | Where-Object { -not [bool]$_.Value } | ForEach-Object { $_.Key })
$status = if ($failed.Count -eq 0) { "PASS" } else { "FAIL" }

$validation = [ordered]@{
  schema = "PHASE162_AUTONOMOUS_ADMISSION_CYCLE_CONTROLLER_VALIDATION_V1"
  status = $status
  created_at = (Get-Date -Format o)
  output_root = $OutputRoot
  checks = $checks
  failed_checks = $failed
  machine_decision = [string]$cycle.machine_decision
  next_machine_action = [string]$cycle.next_machine_action
}

$validationPath = Join-Path $OutputRoot "autonomous_admission_cycle_validation.json"
$validation | ConvertTo-Json -Depth 40 | Set-Content -Path $validationPath -Encoding UTF8

if ($status -ne "PASS") {
  throw "PHASE162_AUTONOMOUS_ADMISSION_CYCLE_CONTROLLER_VALIDATION_FAILED"
}

Write-Host "PHASE162_AUTONOMOUS_ADMISSION_CYCLE_CONTROLLER_VALIDATION=PASS"
Write-Host "MACHINE_DECISION=$($cycle.machine_decision)"
Write-Host "NEXT_MACHINE_ACTION=$($cycle.next_machine_action)"
Write-Host "VALIDATION_RESULT=$validationPath"
