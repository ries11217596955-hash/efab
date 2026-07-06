param(
  [Parameter(Mandatory=$true)]
  [string]$FreezeRoot,

  [Parameter(Mandatory=$true)]
  [string]$BlockersRoot,

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
  $OutputRoot = Join-Path (Split-Path -Parent $FreezeRoot) "PHASE162_ACCEPT_GATE_WITH_BLOCKERS_$stamp"
}

New-Item -ItemType Directory -Force -Path $OutputRoot | Out-Null

$freeze = Read-Json (Join-Path $FreezeRoot "frozen_atom_candidate_evidence.json")
$freezeDecision = Read-Json (Join-Path $FreezeRoot "admission_decision.json")
$freezeValidation = Read-Json (Join-Path $FreezeRoot "validation_result.json")

$usefulness = Read-Json (Join-Path $BlockersRoot "usefulness_validation_result.json")
$safety = Read-Json (Join-Path $BlockersRoot "safety_validation_result.json")
$blockers = Read-Json (Join-Path $BlockersRoot "usefulness_safety_blockers_result.json")
$blockersValidation = Read-Json (Join-Path $BlockersRoot "usefulness_safety_blockers_validation.json")

$blocking = @()

if ([string]$freeze.status -ne "FROZEN") { $blocking += "freeze_not_frozen" }
if ([string]$freezeValidation.status -ne "PASS") { $blocking += "freeze_validation_not_pass" }
if ([bool]$freeze.atom_candidate_summary_present_on_this_pc -ne $true) { $blocking += "source_atom_artifact_not_present" }
if ([int]$freeze.selected_skill_candidate_count -lt 1) { $blocking += "no_skill_candidates" }

if ([string]$blockersValidation.status -ne "PASS") { $blocking += "blockers_validation_not_pass" }

if ([bool]$usefulness.usefulness_validated -ne $true) {
  $blocking += "usefulness_not_validated"
}

if ([bool]$safety.safety_validated_for_accept -ne $true) {
  $blocking += "safety_not_validated_for_accept"
}

if ([bool]$blockers.accept_ready -ne $true) {
  $blocking += "accept_ready_false"
}

foreach ($r in @($blockers.blocking_reasons)) {
  if (-not [string]::IsNullOrWhiteSpace([string]$r)) {
    $blocking += [string]$r
  }
}

$blocking = @($blocking | Select-Object -Unique)

$noAcceptedMutation = (
  ([bool]$freezeDecision.accepted_state_mutated -eq $false) -and
  ([bool]$freezeDecision.accepted_memory_mutated -eq $false) -and
  ([bool]$freezeDecision.accepted_self_model_mutated -eq $false) -and
  ([bool]$blockers.accepted_state_mutated -eq $false) -and
  ([bool]$blockers.accepted_memory_mutated -eq $false) -and
  ([bool]$blockers.accepted_self_model_mutated -eq $false)
)

if (-not $noAcceptedMutation) {
  $blocking += "accepted_core_mutation_detected"
}

$gateDecision = if ($blocking.Count -eq 0) { "ACCEPT_READY" } else { "ACCEPT_BLOCKED" }

$result = [ordered]@{
  schema = "PHASE162_ACCEPT_READINESS_GATE_WITH_BLOCKER_INPUTS_V1"
  status = "PASS"
  created_at = (Get-Date -Format o)
  freeze_root = $FreezeRoot
  blockers_root = $BlockersRoot
  consumed_freeze_validation = [string]$freezeValidation.status
  consumed_blockers_validation = [string]$blockersValidation.status
  usefulness_validated = [bool]$usefulness.usefulness_validated
  safety_validated_for_accept = [bool]$safety.safety_validated_for_accept
  accept_ready = ([bool]$blockers.accept_ready -and $blocking.Count -eq 0)
  gate_decision = $gateDecision
  blocking_reasons = $blocking
  accepted_atom_claimed = $false
  accepted_state_mutated = $false
  accepted_memory_mutated = $false
  accepted_self_model_mutated = $false
  next_action = if ($gateDecision -eq "ACCEPT_READY") { "OWNER_REVIEW_BEFORE_CONTROLLED_ACCEPT" } else { "BUILD_EXECUTED_USE_PROOF_AND_ACCEPT_SAFETY_CONTRACTS" }
}

$resultPath = Join-Path $OutputRoot "accept_gate_with_blockers_result.json"
$reportPath = Join-Path $OutputRoot "PHASE162_ACCEPT_GATE_WITH_BLOCKERS_REPORT.md"

Write-Json -Path $resultPath -Object $result

@"
# PHASE162 Accept Gate With Blocker Inputs Report

## Result

- status: PASS
- gate_decision: $gateDecision
- usefulness_validated: $($result.usefulness_validated)
- safety_validated_for_accept: $($result.safety_validated_for_accept)
- accept_ready: $($result.accept_ready)
- accepted_atom_claimed: false
- accepted_state_mutated: false
- accepted_memory_mutated: false
- accepted_self_model_mutated: false

## Consumed Inputs

- freeze_root: `$FreezeRoot`
- blockers_root: `$BlockersRoot`
- freeze_validation: `$($result.consumed_freeze_validation)`
- blockers_validation: `$($result.consumed_blockers_validation)`

## Blocking Reasons

$($blocking | ForEach-Object { "- $_" } | Out-String)

## Meaning

The gate now consumes frozen evidence plus usefulness/safety blocker outputs. It still blocks ACCEPT because usefulness and accept-safety are not proven.

## Next Action

$($result.next_action)
"@ | Set-Content -Path $reportPath -Encoding UTF8

[pscustomobject]@{
  status = "PASS"
  gate_decision = $gateDecision
  output_root = $OutputRoot
  blocking_count = $blocking.Count
  usefulness_validated = [bool]$result.usefulness_validated
  safety_validated_for_accept = [bool]$result.safety_validated_for_accept
  accept_ready = [bool]$result.accept_ready
  accepted_state_mutated = $false
  accepted_memory_mutated = $false
  accepted_self_model_mutated = $false
}
