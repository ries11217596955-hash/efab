param(
  [Parameter(Mandatory=$true)]
  [string]$OutputRoot
)

$ErrorActionPreference = "Stop"

function Read-Phase162Json {
  param([string]$Path)
  if (-not (Test-Path -LiteralPath $Path)) {
    throw "MISSING_FILE=$Path"
  }
  return Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json
}

function Write-Phase162Json {
  param([string]$Path, [object]$Object)
  $dir = Split-Path -Parent $Path
  if ($dir -and -not (Test-Path -LiteralPath $dir)) {
    New-Item -ItemType Directory -Force -Path $dir | Out-Null
  }
  $Object | ConvertTo-Json -Depth 20 | Set-Content -Path $Path -Encoding UTF8
}

$freezePath = Join-Path $OutputRoot "frozen_atom_candidate_evidence.json"
$decisionPath = Join-Path $OutputRoot "admission_decision.json"
$validationPath = Join-Path $OutputRoot "validation_result.json"

$freeze = Read-Phase162Json -Path $freezePath
$decision = Read-Phase162Json -Path $decisionPath

$checks = [ordered]@{
  frozen_status_is_frozen = ([string]$freeze.status -eq "FROZEN")
  decision_status_pass = ([string]$decision.status -eq "PASS")
  decision_is_quarantine = ([string]$decision.admission_decision -eq "QUARANTINE")
  accept_ready_false = ([bool]$decision.accept_ready -eq $false)
  accepted_atom_claimed_false = ([bool]$decision.accepted_atom_claimed -eq $false)
  accepted_state_mutated_false = ([bool]$decision.accepted_state_mutated -eq $false)
  accepted_memory_mutated_false = ([bool]$decision.accepted_memory_mutated -eq $false)
  accepted_self_model_mutated_false = ([bool]$decision.accepted_self_model_mutated -eq $false)
  freeze_core_mutation_allowed_false = ([bool]$freeze.accepted_core_mutation_allowed -eq $false)
  source_event_is_bridge_completed = ([string]$freeze.selected_event_type -eq "autonomous_atom_bridge_completed")
}

$failed = @($checks.GetEnumerator() | Where-Object { -not [bool]$_.Value } | ForEach-Object { $_.Key })

$status = if ($failed.Count -eq 0) { "PASS" } else { "FAIL" }

$result = [ordered]@{
  schema = "PHASE162_ATOM_CANDIDATE_FREEZE_QUARANTINE_VALIDATION_V1"
  status = $status
  created_at = (Get-Date -Format o)
  output_root = $OutputRoot
  checks = $checks
  failed_checks = $failed
  decision = [string]$decision.admission_decision
  no_accepted_core_mutation = (
    ([bool]$decision.accepted_state_mutated -eq $false) -and
    ([bool]$decision.accepted_memory_mutated -eq $false) -and
    ([bool]$decision.accepted_self_model_mutated -eq $false)
  )
}

Write-Phase162Json -Path $validationPath -Object $result

if ($status -ne "PASS") {
  throw "PHASE162_FREEZE_QUARANTINE_VALIDATION_FAILED"
}

Write-Host "PHASE162_VALIDATION_RESULT=PASS"
Write-Host "VALIDATION_RESULT=$validationPath"
