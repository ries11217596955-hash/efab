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
  $OutputRoot = Join-Path (Split-Path -Parent $FreezeRoot) "PHASE162_EXECUTED_USE_PROOF_$stamp"
}

New-Item -ItemType Directory -Force -Path $OutputRoot | Out-Null

$freeze = Read-Json (Join-Path $FreezeRoot "frozen_atom_candidate_evidence.json")
$decision = Read-Json (Join-Path $FreezeRoot "admission_decision.json")
$validation = Read-Json (Join-Path $FreezeRoot "validation_result.json")

$candidateSummary = $freeze.candidate_summary_snapshot
$skillCandidates = @()

if ($null -ne $candidateSummary -and $candidateSummary.PSObject.Properties.Name -contains "skill_candidates") {
  $skillCandidates = @($candidateSummary.skill_candidates)
}

$firstSkill = $null
if ($skillCandidates.Count -gt 0) {
  $firstSkill = $skillCandidates[0]
}

$sourceOk = (
  ([string]$freeze.status -eq "FROZEN") -and
  ([string]$validation.status -eq "PASS") -and
  ([bool]$freeze.atom_candidate_summary_present_on_this_pc -eq $true) -and
  ([int]$freeze.selected_skill_candidate_count -gt 0)
)

$selectedSkillId = "UNKNOWN"
$selectedGoal = "UNKNOWN"
$selectedValidation = "UNKNOWN"
$selectedPath = "UNKNOWN"

if ($null -ne $firstSkill) {
  if ($firstSkill.PSObject.Properties.Name -contains "skill_id") { $selectedSkillId = [string]$firstSkill.skill_id }
  if ($firstSkill.PSObject.Properties.Name -contains "selected_goal") { $selectedGoal = [string]$firstSkill.selected_goal }
  if ($firstSkill.PSObject.Properties.Name -contains "validation_status") { $selectedValidation = [string]$firstSkill.validation_status }
  if ($firstSkill.PSObject.Properties.Name -contains "sandbox_path") { $selectedPath = [string]$firstSkill.sandbox_path }
  if ($firstSkill.PSObject.Properties.Name -contains "path") { $selectedPath = [string]$firstSkill.path }
}

$useCard = [ordered]@{
  schema = "PHASE162_ATOM_EXECUTED_USE_CARD_V1"
  status = if ($sourceOk) { "PASS" } else { "BLOCKED" }
  created_at = (Get-Date -Format o)
  use_task = "NORMALIZE_FROZEN_ATOM_CANDIDATE_FOR_ADMISSION_REVIEW"
  freeze_root = $FreezeRoot
  atom_candidate_summary_path = [string]$freeze.atom_candidate_summary_path
  atom_candidate_summary_present_on_this_pc = [bool]$freeze.atom_candidate_summary_present_on_this_pc
  selected_duty_id = [string]$freeze.selected_duty_id
  selected_run_id = [string]$freeze.selected_run_id
  selected_atom_summary_status = [string]$freeze.selected_atom_summary_status
  selected_skill_candidate_count = [int]$freeze.selected_skill_candidate_count
  selected_skill = [ordered]@{
    skill_id = $selectedSkillId
    selected_goal = $selectedGoal
    validation_status = $selectedValidation
    sandbox_path = $selectedPath
  }
  executed_action = "frozen_candidate_read_and_normalized_into_owner_visible_admission_review_card"
  owner_visible_value = "candidate_is_now_reviewable_as_structured_atom_use_card"
  limitation = "does_not_prove_next_cycle_improvement_or_accept_safety"
}

$blockersRemaining = @(
  "no_next_cycle_improvement_proof",
  "no_behavior_delta_measurement",
  "no_live_builder_task_success_delta",
  "accept_target_not_defined",
  "accepted_memory_write_contract_missing",
  "accepted_self_model_write_contract_missing",
  "rollback_plan_missing",
  "owner_review_gate_missing"
)

$result = [ordered]@{
  schema = "PHASE162_ATOM_EXECUTED_USE_PROOF_RESULT_V1"
  status = if ($sourceOk) { "PASS" } else { "BLOCKED" }
  created_at = (Get-Date -Format o)
  freeze_root = $FreezeRoot
  use_card_path = Join-Path $OutputRoot "executed_use_card.json"
  executed_use_proof_passed = [bool]$sourceOk
  usefulness_validated_partial = [bool]$sourceOk
  usefulness_validated_for_accept = $false
  safety_validated_for_accept = $false
  accept_ready = $false
  expected_gate_decision = "ACCEPT_BLOCKED"
  blockers_remaining = $blockersRemaining
  accepted_atom_claimed = $false
  accepted_state_mutated = $false
  accepted_memory_mutated = $false
  accepted_self_model_mutated = $false
  next_action = "UPGRADE_USEFULNESS_BLOCKERS_TO_CONSUME_EXECUTED_USE_PROOF_BUT_KEEP_ACCEPT_BLOCKED"
}

Write-Json -Path (Join-Path $OutputRoot "executed_use_card.json") -Object $useCard
Write-Json -Path (Join-Path $OutputRoot "executed_use_proof_result.json") -Object $result

@"
# PHASE162 Atom Executed Use Proof Report

## Result

- status: $($result.status)
- executed_use_proof_passed: $($result.executed_use_proof_passed)
- usefulness_validated_partial: $($result.usefulness_validated_partial)
- usefulness_validated_for_accept: false
- safety_validated_for_accept: false
- accept_ready: false
- expected_gate_decision: ACCEPT_BLOCKED
- accepted_atom_claimed: false
- accepted_state_mutated: false
- accepted_memory_mutated: false
- accepted_self_model_mutated: false

## Executed Use

The frozen atom candidate was used for a small admission-review task:

frozen candidate -> structured owner-visible atom use card

## Boundary

This does not accept or absorb the atom. It only proves the candidate can be consumed by the admission pipeline.

## Remaining Blockers

$($blockersRemaining | ForEach-Object { "- $_" } | Out-String)

## Next Action

Upgrade usefulness blockers to consume this executed use proof, while keeping ACCEPT blocked until safety contracts and next-cycle improvement proof exist.
"@ | Set-Content -Path (Join-Path $OutputRoot "PHASE162_EXECUTED_USE_PROOF_REPORT.md") -Encoding UTF8

[pscustomobject]@{
  status = $result.status
  output_root = $OutputRoot
  executed_use_proof_passed = $result.executed_use_proof_passed
  usefulness_validated_partial = $result.usefulness_validated_partial
  usefulness_validated_for_accept = $result.usefulness_validated_for_accept
  safety_validated_for_accept = $result.safety_validated_for_accept
  accept_ready = $result.accept_ready
  expected_gate_decision = $result.expected_gate_decision
  accepted_state_mutated = $false
  accepted_memory_mutated = $false
  accepted_self_model_mutated = $false
}
