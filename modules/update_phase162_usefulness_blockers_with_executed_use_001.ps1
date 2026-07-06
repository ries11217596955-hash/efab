param(
  [Parameter(Mandatory=$true)]
  [string]$BlockersRoot,

  [Parameter(Mandatory=$true)]
  [string]$ExecutedUseRoot,

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
  $OutputRoot = Join-Path (Split-Path -Parent $BlockersRoot) "PHASE162_USEFULNESS_SAFETY_BLOCKERS_EXECUTED_USE_$stamp"
}

New-Item -ItemType Directory -Force -Path $OutputRoot | Out-Null

$oldUsefulness = Read-Json (Join-Path $BlockersRoot "usefulness_validation_result.json")
$oldSafety = Read-Json (Join-Path $BlockersRoot "safety_validation_result.json")
$oldCombined = Read-Json (Join-Path $BlockersRoot "usefulness_safety_blockers_result.json")
$oldValidation = Read-Json (Join-Path $BlockersRoot "usefulness_safety_blockers_validation.json")

$useProof = Read-Json (Join-Path $ExecutedUseRoot "executed_use_proof_result.json")
$useValidation = Read-Json (Join-Path $ExecutedUseRoot "executed_use_proof_validation.json")

$executedUsePassed = (
  ([string]$useValidation.status -eq "PASS") -and
  ([bool]$useProof.executed_use_proof_passed -eq $true) -and
  ([bool]$useProof.usefulness_validated_partial -eq $true)
)

$oldUsefulnessBlockers = @($oldUsefulness.blocking_reasons | ForEach-Object { [string]$_ })
$oldSafetyBlockers = @($oldSafety.blocking_reasons | ForEach-Object { [string]$_ })

$newUsefulnessBlockers = @()

foreach ($b in $oldUsefulnessBlockers) {
  if ($executedUsePassed -and $b -eq "no_owner_visible_value_proof") {
    continue
  }

  if ($executedUsePassed -and $b -eq "no_executed_use_proof_against_live_builder_task") {
    continue
  }

  $newUsefulnessBlockers += $b
}

if ($executedUsePassed) {
  $newUsefulnessBlockers += "partial_executed_use_proof_exists_but_not_live_builder_task_success_delta"
  $newUsefulnessBlockers += "owner_visible_admission_review_card_exists"
} else {
  $newUsefulnessBlockers += "executed_use_proof_not_passed"
}

$newUsefulnessBlockers = @($newUsefulnessBlockers | Select-Object -Unique)

$updatedUsefulness = [ordered]@{
  schema = "PHASE162_ATOM_USEFULNESS_VALIDATION_WITH_EXECUTED_USE_V1"
  status = "PASS"
  created_at = (Get-Date -Format o)
  previous_blockers_root = $BlockersRoot
  executed_use_root = $ExecutedUseRoot
  executed_use_proof_passed = [bool]$executedUsePassed
  usefulness_validated_partial = [bool]$executedUsePassed
  usefulness_validated_for_accept = $false
  usefulness_validated = $false
  decision = "USEFULNESS_PARTIAL_BUT_ACCEPT_BLOCKED"
  removed_blockers = @(
    "no_owner_visible_value_proof",
    "no_executed_use_proof_against_live_builder_task"
  )
  remaining_blocking_reasons = $newUsefulnessBlockers
  accepted_atom_claimed = $false
  accepted_state_mutated = $false
  accepted_memory_mutated = $false
  accepted_self_model_mutated = $false
}

$updatedSafety = [ordered]@{
  schema = "PHASE162_ATOM_ACCEPT_SAFETY_VALIDATION_CARRIED_FORWARD_V1"
  status = "PASS"
  created_at = (Get-Date -Format o)
  previous_blockers_root = $BlockersRoot
  safety_validated_for_accept = $false
  decision = "SAFETY_BLOCKED"
  blocking_reasons = $oldSafetyBlockers
  accepted_atom_claimed = $false
  accepted_state_mutated = $false
  accepted_memory_mutated = $false
  accepted_self_model_mutated = $false
}

$combinedBlockers = @($newUsefulnessBlockers + $oldSafetyBlockers | Select-Object -Unique)

$combined = [ordered]@{
  schema = "PHASE162_ATOM_USEFULNESS_SAFETY_BLOCKERS_WITH_EXECUTED_USE_V1"
  status = "PASS"
  created_at = (Get-Date -Format o)
  previous_blockers_root = $BlockersRoot
  executed_use_root = $ExecutedUseRoot
  previous_blockers_validation_status = [string]$oldValidation.status
  executed_use_validation_status = [string]$useValidation.status
  usefulness_validated_partial = [bool]$executedUsePassed
  usefulness_validated = $false
  usefulness_validated_for_accept = $false
  safety_validated_for_accept = $false
  accept_ready = $false
  gate_expected_decision = "ACCEPT_BLOCKED"
  blocking_reasons = $combinedBlockers
  accepted_atom_claimed = $false
  accepted_state_mutated = $false
  accepted_memory_mutated = $false
  accepted_self_model_mutated = $false
  next_action = "UPGRADE_ACCEPT_GATE_TO_REPORT_PARTIAL_USEFULNESS_BUT_KEEP_ACCEPT_BLOCKED"
}

Write-Json -Path (Join-Path $OutputRoot "usefulness_validation_result.json") -Object $updatedUsefulness
Write-Json -Path (Join-Path $OutputRoot "safety_validation_result.json") -Object $updatedSafety
Write-Json -Path (Join-Path $OutputRoot "usefulness_safety_blockers_result.json") -Object $combined

@"
# PHASE162 Usefulness Blockers With Executed Use Report

## Result

- status: PASS
- executed_use_proof_passed: $executedUsePassed
- usefulness_validated_partial: $executedUsePassed
- usefulness_validated_for_accept: false
- safety_validated_for_accept: false
- accept_ready: false
- expected_gate_decision: ACCEPT_BLOCKED
- accepted_atom_claimed: false
- accepted_state_mutated: false
- accepted_memory_mutated: false
- accepted_self_model_mutated: false

## Meaning

The candidate now has partial usefulness evidence because it was consumed by the admission pipeline and normalized into an owner-visible review card.

This still does not prove live task improvement, behavior delta, next-cycle improvement, or accept safety.

## Remaining Blockers

$($combinedBlockers | ForEach-Object { "- $_" } | Out-String)

## Next Action

Upgrade the accept gate to report partial usefulness while keeping ACCEPT blocked.
"@ | Set-Content -Path (Join-Path $OutputRoot "PHASE162_USEFULNESS_BLOCKERS_WITH_EXECUTED_USE_REPORT.md") -Encoding UTF8

[pscustomobject]@{
  status = "PASS"
  output_root = $OutputRoot
  executed_use_proof_passed = [bool]$executedUsePassed
  usefulness_validated_partial = [bool]$executedUsePassed
  usefulness_validated_for_accept = $false
  safety_validated_for_accept = $false
  accept_ready = $false
  expected_gate_decision = "ACCEPT_BLOCKED"
  blocker_count = $combinedBlockers.Count
  accepted_state_mutated = $false
  accepted_memory_mutated = $false
  accepted_self_model_mutated = $false
}
