param(
  [Parameter(Mandatory=$true)]
  [string]$FreezeRoot,

  [string]$OutputRoot = ""
)

$ErrorActionPreference = "Stop"

function Read-Json {
  param([string]$Path)
  if (-not (Test-Path -LiteralPath $Path)) {
    throw "MISSING_FILE=$Path"
  }
  return Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json
}

function Write-Json {
  param([string]$Path, [object]$Object)
  $dir = Split-Path -Parent $Path
  if ($dir -and -not (Test-Path -LiteralPath $dir)) {
    New-Item -ItemType Directory -Force -Path $dir | Out-Null
  }
  $Object | ConvertTo-Json -Depth 20 | Set-Content -Path $Path -Encoding UTF8
}

if ([string]::IsNullOrWhiteSpace($OutputRoot)) {
  $stamp = Get-Date -Format "yyyyMMdd_HHmmss"
  $OutputRoot = Join-Path (Split-Path -Parent $FreezeRoot) "PHASE162_ACCEPT_READINESS_GATE_$stamp"
}

New-Item -ItemType Directory -Force -Path $OutputRoot | Out-Null

$freeze = Read-Json (Join-Path $FreezeRoot "frozen_atom_candidate_evidence.json")
$decision = Read-Json (Join-Path $FreezeRoot "admission_decision.json")
$validation = Read-Json (Join-Path $FreezeRoot "validation_result.json")

$checks = [ordered]@{
  frozen_evidence_exists = $true
  freeze_status_frozen = ([string]$freeze.status -eq "FROZEN")
  prior_validation_pass = ([string]$validation.status -eq "PASS")
  source_artifact_present = ([bool]$freeze.atom_candidate_summary_present_on_this_pc -eq $true)
  candidate_has_skill_candidates = ([int]$freeze.selected_skill_candidate_count -gt 0)
  prior_decision_is_not_accept = ([string]$decision.admission_decision -ne "ACCEPT")
  prior_decision_quarantine = ([string]$decision.admission_decision -eq "QUARANTINE")
  usefulness_validated = ([bool]$decision.usefulness_validated -eq $true)
  safety_validated_for_accept = ([bool]$decision.safety_validated_for_accept -eq $true)
  accept_ready_claimed = ([bool]$decision.accept_ready -eq $true)
  accepted_core_mutation_absent = (
    ([bool]$decision.accepted_state_mutated -eq $false) -and
    ([bool]$decision.accepted_memory_mutated -eq $false) -and
    ([bool]$decision.accepted_self_model_mutated -eq $false)
  )
  source_not_already_accepted = ([bool]$freeze.selected_accepted_atom_claimed -eq $false)
}

$blocking = @()

if (-not $checks.freeze_status_frozen) { $blocking += "freeze_status_not_frozen" }
if (-not $checks.prior_validation_pass) { $blocking += "prior_freeze_validation_not_pass" }
if (-not $checks.source_artifact_present) { $blocking += "source_artifact_not_present" }
if (-not $checks.candidate_has_skill_candidates) { $blocking += "no_skill_candidates" }
if (-not $checks.prior_decision_quarantine) { $blocking += "prior_decision_not_quarantine" }
if (-not $checks.usefulness_validated) { $blocking += "usefulness_not_validated" }
if (-not $checks.safety_validated_for_accept) { $blocking += "safety_not_validated_for_accept" }
if (-not $checks.accept_ready_claimed) { $blocking += "accept_ready_false" }
if (-not $checks.accepted_core_mutation_absent) { $blocking += "accepted_core_mutation_detected" }
if (-not $checks.source_not_already_accepted) { $blocking += "source_claims_already_accepted" }

$gateDecision = if ($blocking.Count -eq 0) { "ACCEPT_READY" } else { "ACCEPT_BLOCKED" }

$result = [ordered]@{
  schema = "PHASE162_ATOM_ACCEPT_READINESS_GATE_V1"
  status = "PASS"
  created_at = (Get-Date -Format o)
  freeze_root = $FreezeRoot
  gate_decision = $gateDecision
  blocking_reasons = $blocking
  checks = $checks
  accepted_atom_claimed = $false
  accepted_state_mutated = $false
  accepted_memory_mutated = $false
  accepted_self_model_mutated = $false
  next_action = if ($gateDecision -eq "ACCEPT_READY") { "OWNER_REVIEW_BEFORE_ANY_ACCEPT" } else { "BUILD_USEFULNESS_AND_SAFETY_VALIDATORS_BEFORE_ACCEPT" }
}

$resultPath = Join-Path $OutputRoot "accept_readiness_gate_result.json"
$reportPath = Join-Path $OutputRoot "PHASE162_ACCEPT_READINESS_GATE_REPORT.md"

Write-Json -Path $resultPath -Object $result

@"
# PHASE162 Atom Accept Readiness Gate Report

## Result

- status: PASS
- gate_decision: $gateDecision
- accepted_atom_claimed: false
- accepted_state_mutated: false
- accepted_memory_mutated: false
- accepted_self_model_mutated: false

## Blocking Reasons

$($blocking | ForEach-Object { "- $_" } | Out-String)

## Meaning

This gate does not accept or absorb the atom. It only checks whether the frozen atom candidate is ready for a future accept decision.

## Next Action

$($result.next_action)
"@ | Set-Content -Path $reportPath -Encoding UTF8

[pscustomobject]@{
  status = "PASS"
  gate_decision = $gateDecision
  output_root = $OutputRoot
  result_path = $resultPath
  report_path = $reportPath
  blocking_count = $blocking.Count
  accepted_state_mutated = $false
  accepted_memory_mutated = $false
  accepted_self_model_mutated = $false
}
