param(
  [Parameter(Mandatory=$true)]
  [string]$FreezeRoot,

  [Parameter(Mandatory=$true)]
  [string]$PartialBlockersRoot,

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
  $OutputRoot = Join-Path (Split-Path -Parent $FreezeRoot) "PHASE162_ACCEPT_GATE_PARTIAL_USEFULNESS_$stamp"
}

New-Item -ItemType Directory -Force -Path $OutputRoot | Out-Null

$freeze = Read-Json (Join-Path $FreezeRoot "frozen_atom_candidate_evidence.json")
$freezeDecision = Read-Json (Join-Path $FreezeRoot "admission_decision.json")
$freezeValidation = Read-Json (Join-Path $FreezeRoot "validation_result.json")

$usefulness = Read-Json (Join-Path $PartialBlockersRoot "usefulness_validation_result.json")
$safety = Read-Json (Join-Path $PartialBlockersRoot "safety_validation_result.json")
$combined = Read-Json (Join-Path $PartialBlockersRoot "usefulness_safety_blockers_result.json")
$combinedValidation = Read-Json (Join-Path $PartialBlockersRoot "usefulness_safety_blockers_validation.json")

$blocking = @()

if ([string]$freeze.status -ne "FROZEN") { $blocking += "freeze_not_frozen" }
if ([string]$freezeValidation.status -ne "PASS") { $blocking += "freeze_validation_not_pass" }
if ([bool]$freeze.atom_candidate_summary_present_on_this_pc -ne $true) { $blocking += "source_atom_artifact_not_present" }
if ([int]$freeze.selected_skill_candidate_count -lt 1) { $blocking += "no_skill_candidates" }

if ([string]$combinedValidation.status -ne "PASS") { $blocking += "partial_blockers_validation_not_pass" }

if ([bool]$combined.usefulness_validated_partial -ne $true) {
  $blocking += "partial_usefulness_not_proven"
}

if ([bool]$combined.usefulness_validated_for_accept -ne $true) {
  $blocking += "usefulness_not_validated_for_accept"
}

if ([bool]$safety.safety_validated_for_accept -ne $true) {
  $blocking += "safety_not_validated_for_accept"
}

if ([bool]$combined.accept_ready -ne $true) {
  $blocking += "accept_ready_false"
}

foreach ($r in @($combined.blocking_reasons)) {
  if (-not [string]::IsNullOrWhiteSpace([string]$r)) {
    $blocking += [string]$r
  }
}

$noAcceptedMutation = (
  ([bool]$freezeDecision.accepted_state_mutated -eq $false) -and
  ([bool]$freezeDecision.accepted_memory_mutated -eq $false) -and
  ([bool]$freezeDecision.accepted_self_model_mutated -eq $false) -and
  ([bool]$combined.accepted_state_mutated -eq $false) -and
  ([bool]$combined.accepted_memory_mutated -eq $false) -and
  ([bool]$combined.accepted_self_model_mutated -eq $false)
)

if (-not $noAcceptedMutation) {
  $blocking += "accepted_core_mutation_detected"
}

$blocking = @($blocking | Select-Object -Unique)

$gateDecision = if ($blocking.Count -eq 0) { "ACCEPT_READY" } else { "ACCEPT_BLOCKED" }

$result = [ordered]@{
  schema = "PHASE162_ACCEPT_GATE_WITH_PARTIAL_USEFULNESS_V1"
  status = "PASS"
  created_at = (Get-Date -Format o)
  freeze_root = $FreezeRoot
  partial_blockers_root = $PartialBlockersRoot
  consumed_freeze_validation = [string]$freezeValidation.status
  consumed_partial_blockers_validation = [string]$combinedValidation.status
  usefulness_validated_partial = [bool]$combined.usefulness_validated_partial
  usefulness_validated_for_accept = [bool]$combined.usefulness_validated_for_accept
  safety_validated_for_accept = [bool]$safety.safety_validated_for_accept
  accept_ready = ([bool]$combined.accept_ready -and $blocking.Count -eq 0)
  gate_decision = $gateDecision
  blocking_reasons = $blocking
  diagnostic_summary = "partial_usefulness_exists_but_accept_blocked_by_next_cycle_and_safety_requirements"
  accepted_atom_claimed = $false
  accepted_state_mutated = $false
  accepted_memory_mutated = $false
  accepted_self_model_mutated = $false
  next_action = if ($gateDecision -eq "ACCEPT_READY") { "OWNER_REVIEW_BEFORE_CONTROLLED_ACCEPT" } else { "BUILD_NEXT_CYCLE_IMPROVEMENT_PROOF_AND_ACCEPT_SAFETY_CONTRACTS" }
}

$resultPath = Join-Path $OutputRoot "accept_gate_partial_usefulness_result.json"
$reportPath = Join-Path $OutputRoot "PHASE162_ACCEPT_GATE_PARTIAL_USEFULNESS_REPORT.md"

Write-Json -Path $resultPath -Object $result

@"
# PHASE162 Accept Gate With Partial Usefulness Report

## Result

- status: PASS
- gate_decision: $gateDecision
- usefulness_validated_partial: $($result.usefulness_validated_partial)
- usefulness_validated_for_accept: $($result.usefulness_validated_for_accept)
- safety_validated_for_accept: $($result.safety_validated_for_accept)
- accept_ready: $($result.accept_ready)
- accepted_atom_claimed: false
- accepted_state_mutated: false
- accepted_memory_mutated: false
- accepted_self_model_mutated: false

## Meaning

The gate now reports partial usefulness. The atom candidate has evidence that it can be consumed by the admission pipeline, but it is still not acceptable for absorb.

## Blocking Reasons

$($blocking | ForEach-Object { "- $_" } | Out-String)

## Next Action

$($result.next_action)
"@ | Set-Content -Path $reportPath -Encoding UTF8

[pscustomobject]@{
  status = "PASS"
  gate_decision = $gateDecision
  output_root = $OutputRoot
  usefulness_validated_partial = [bool]$result.usefulness_validated_partial
  usefulness_validated_for_accept = [bool]$result.usefulness_validated_for_accept
  safety_validated_for_accept = [bool]$result.safety_validated_for_accept
  accept_ready = [bool]$result.accept_ready
  blocking_count = $blocking.Count
  accepted_state_mutated = $false
  accepted_memory_mutated = $false
  accepted_self_model_mutated = $false
}
