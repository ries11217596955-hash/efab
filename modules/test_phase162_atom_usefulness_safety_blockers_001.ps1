param(
  [Parameter(Mandatory=$true)]
  [string]$FreezeRoot,

  [string]$OutputRoot = ""
)

$ErrorActionPreference = "Stop"

function Read-Json {
  param([string]$Path)
  if (-not (Test-Path -LiteralPath $Path)) { throw "MISSING_FILE=$Path" }
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
  $OutputRoot = Join-Path (Split-Path -Parent $FreezeRoot) "PHASE162_USEFULNESS_SAFETY_BLOCKERS_$stamp"
}

New-Item -ItemType Directory -Force -Path $OutputRoot | Out-Null

$freeze = Read-Json (Join-Path $FreezeRoot "frozen_atom_candidate_evidence.json")
$decision = Read-Json (Join-Path $FreezeRoot "admission_decision.json")
$validation = Read-Json (Join-Path $FreezeRoot "validation_result.json")

$usefulnessBlockers = @()
$safetyBlockers = @()

if ([string]$validation.status -ne "PASS") {
  $usefulnessBlockers += "freeze_validation_not_pass"
  $safetyBlockers += "freeze_validation_not_pass"
}

if ([bool]$freeze.atom_candidate_summary_present_on_this_pc -ne $true) {
  $usefulnessBlockers += "source_atom_artifact_not_present"
}

if ([int]$freeze.selected_skill_candidate_count -lt 1) {
  $usefulnessBlockers += "no_skill_candidates"
}

$usefulnessBlockers += "no_executed_use_proof_against_live_builder_task"
$usefulnessBlockers += "no_next_cycle_improvement_proof"
$usefulnessBlockers += "no_behavior_delta_measurement"
$usefulnessBlockers += "no_owner_visible_value_proof"

$safetyBlockers += "accept_target_not_defined"
$safetyBlockers += "accepted_memory_write_contract_missing"
$safetyBlockers += "accepted_self_model_write_contract_missing"
$safetyBlockers += "rollback_plan_missing"
$safetyBlockers += "owner_review_gate_missing"
$safetyBlockers += "source_decision_is_quarantine_not_accept"

$usefulness = [ordered]@{
  schema = "PHASE162_ATOM_USEFULNESS_VALIDATION_V1"
  status = "PASS"
  created_at = (Get-Date -Format o)
  freeze_root = $FreezeRoot
  usefulness_validated = $false
  decision = "USEFULNESS_BLOCKED"
  blocking_reasons = $usefulnessBlockers
  candidate_has_skill_candidates = ([int]$freeze.selected_skill_candidate_count -gt 0)
  source_artifact_present = [bool]$freeze.atom_candidate_summary_present_on_this_pc
  accepted_atom_claimed = $false
  accepted_state_mutated = $false
  accepted_memory_mutated = $false
  accepted_self_model_mutated = $false
}

$safety = [ordered]@{
  schema = "PHASE162_ATOM_ACCEPT_SAFETY_VALIDATION_V1"
  status = "PASS"
  created_at = (Get-Date -Format o)
  freeze_root = $FreezeRoot
  safety_validated_for_accept = $false
  decision = "SAFETY_BLOCKED"
  blocking_reasons = $safetyBlockers
  accepted_atom_claimed = $false
  accepted_state_mutated = $false
  accepted_memory_mutated = $false
  accepted_self_model_mutated = $false
}

$combined = [ordered]@{
  schema = "PHASE162_ATOM_USEFULNESS_SAFETY_BLOCKERS_V1"
  status = "PASS"
  created_at = (Get-Date -Format o)
  freeze_root = $FreezeRoot
  usefulness_result_path = Join-Path $OutputRoot "usefulness_validation_result.json"
  safety_result_path = Join-Path $OutputRoot "safety_validation_result.json"
  usefulness_validated = $false
  safety_validated_for_accept = $false
  accept_ready = $false
  gate_expected_decision = "ACCEPT_BLOCKED"
  blocking_reasons = @($usefulnessBlockers + $safetyBlockers)
  accepted_atom_claimed = $false
  accepted_state_mutated = $false
  accepted_memory_mutated = $false
  accepted_self_model_mutated = $false
  next_action = "UPGRADE_ACCEPT_READINESS_GATE_TO_CONSUME_USEFULNESS_AND_SAFETY_RESULTS"
}

Write-Json -Path (Join-Path $OutputRoot "usefulness_validation_result.json") -Object $usefulness
Write-Json -Path (Join-Path $OutputRoot "safety_validation_result.json") -Object $safety
Write-Json -Path (Join-Path $OutputRoot "usefulness_safety_blockers_result.json") -Object $combined

@"
# PHASE162 Atom Usefulness / Safety Blockers Report

## Result

- status: PASS
- usefulness_validated: false
- safety_validated_for_accept: false
- accept_ready: false
- expected_gate_decision: ACCEPT_BLOCKED
- accepted_atom_claimed: false
- accepted_state_mutated: false
- accepted_memory_mutated: false
- accepted_self_model_mutated: false

## Meaning

The atom candidate exists and was frozen, but it is not ready for accept/absorb.

## Usefulness Blockers

$($usefulnessBlockers | ForEach-Object { "- $_" } | Out-String)

## Safety Blockers

$($safetyBlockers | ForEach-Object { "- $_" } | Out-String)

## Next Action

Upgrade the accept-readiness gate so it consumes these usefulness and safety results instead of relying only on the old quarantine decision.
"@ | Set-Content -Path (Join-Path $OutputRoot "PHASE162_USEFULNESS_SAFETY_BLOCKERS_REPORT.md") -Encoding UTF8

[pscustomobject]@{
  status = "PASS"
  output_root = $OutputRoot
  usefulness_validated = $false
  safety_validated_for_accept = $false
  accept_ready = $false
  expected_gate_decision = "ACCEPT_BLOCKED"
  usefulness_blocker_count = $usefulnessBlockers.Count
  safety_blocker_count = $safetyBlockers.Count
  accepted_state_mutated = $false
  accepted_memory_mutated = $false
  accepted_self_model_mutated = $false
}
