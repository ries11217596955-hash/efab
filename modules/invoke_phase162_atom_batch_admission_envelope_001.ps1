param(
  [Parameter(Mandatory=$true)]
  [string]$ControllerRoot,

  [Parameter(Mandatory=$true)]
  [string]$PolicyRoot,

  [Parameter(Mandatory=$true)]
  [string]$ExplanationRoot,

  [Parameter(Mandatory=$true)]
  [string[]]$FreezeRoots,

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
  $Object | ConvertTo-Json -Depth 100 | Set-Content -Path $Path -Encoding UTF8
}

function New-Reason {
  param(
    [string]$Code,
    [string]$Category,
    [string]$Meaning,
    [string]$Repair
  )

  return [ordered]@{
    code = $Code
    category = $Category
    meaning = $Meaning
    repair_action = $Repair
  }
}

if ([string]::IsNullOrWhiteSpace($OutputRoot)) {
  $stamp = Get-Date -Format "yyyyMMdd_HHmmss"
  $OutputRoot = Join-Path (Split-Path -Parent $ControllerRoot) "PHASE162_ATOM_BATCH_ADMISSION_ENVELOPE_$stamp"
}

New-Item -ItemType Directory -Force -Path $OutputRoot | Out-Null

$controller = Read-Json (Join-Path $ControllerRoot "controller_with_bounded_absorb_trial_result.json")
$controllerValidation = Read-Json (Join-Path $ControllerRoot "controller_with_bounded_absorb_trial_validation.json")

$policy = Read-Json (Join-Path $PolicyRoot "autonomous_accept_policy_gate_result.json")
$policyValidation = Read-Json (Join-Path $PolicyRoot "autonomous_accept_policy_gate_validation.json")

$explanation = Read-Json (Join-Path $ExplanationRoot "policy_gate_decision_explanation.json")
$explanationValidation = Read-Json (Join-Path $ExplanationRoot "policy_gate_decision_explanation_validation.json")

$upstreamOk = (
  ([string]$controllerValidation.status -eq "PASS") -and
  ([string]$controller.next_machine_action -eq "BUILD_CONTROLLED_ACCEPT_CANDIDATE_DRY_RUN") -and
  ([string]$policyValidation.status -eq "PASS") -and
  ([bool]$policy.policy_gate_present -eq $true) -and
  ([string]$explanationValidation.status -eq "PASS") -and
  (-not [string]::IsNullOrWhiteSpace([string]$explanation.decision_code))
)

$batchRecords = @()
$index = 0

foreach ($freezeRoot in $FreezeRoots) {
  $index += 1

  $freeze = Read-Json (Join-Path $freezeRoot "frozen_atom_candidate_evidence.json")
  $freezeValidation = Read-Json (Join-Path $freezeRoot "validation_result.json")

  $atomIdSeed = @(
    [string]$freeze.selected_run_id,
    [string]$freeze.selected_duty_id,
    (Split-Path -Leaf $freezeRoot)
  ) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }

  $atomId = ($atomIdSeed -join "::")

  $atomFreezeOk = (
    ([string]$freezeValidation.status -eq "PASS") -and
    ([string]$freeze.status -eq "FROZEN") -and
    ([bool]$freeze.atom_candidate_summary_present_on_this_pc -eq $true) -and
    ([int]$freeze.selected_skill_candidate_count -gt 0)
  )

  $eligible = (
    $upstreamOk -and
    $atomFreezeOk -and
    ([bool]$policy.policy_granted_for_bounded_absorb_trial -eq $true) -and
    ([bool]$policy.policy_granted_for_final_accept -eq $false)
  )

  $reasons = @()

  if (-not $upstreamOk) {
    $reasons += New-Reason -Code "upstream_controller_or_policy_not_ready" -Category "upstream" -Meaning "Controller, policy gate, or explanation input is not ready." -Repair "repair upstream admission chain before staging atom batch"
  }

  if (-not $atomFreezeOk) {
    $reasons += New-Reason -Code "atom_freeze_evidence_not_ready" -Category "freeze" -Meaning "This atom does not have complete frozen evidence on this PC." -Repair "freeze this atom candidate before batch admission"
  }

  foreach ($r in @($controller.blocking_for_final_accept)) {
    if (-not [string]::IsNullOrWhiteSpace([string]$r)) {
      $reasons += New-Reason -Code ([string]$r) -Category "final_accept_blocker" -Meaning "This condition still blocks final accept." -Repair "resolve this blocker before final absorb"
    }
  }

  $record = [ordered]@{
    schema = "PHASE162_ATOM_BATCH_MEMBER_ADMISSION_RECORD_V1"
    batch_index = $index
    atom_id = $atomId
    source_freeze_root = $freezeRoot
    freeze_status = [string]$freeze.status
    freeze_validation_status = [string]$freezeValidation.status
    skill_candidate_count = [int]$freeze.selected_skill_candidate_count
    atom_admission_state = if ($eligible) { "CONTROLLED_ACCEPT_CANDIDATE_DRY_RUN_READY" } else { "BLOCKED_OR_QUARANTINE_REQUIRED" }
    decision_code = if ($eligible) { "ALLOW_STAGING_DENY_FINAL_ACCEPT" } else { "DENY_STAGING" }
    decision_summary = if ($eligible) {
      "Atom is eligible for controlled accept candidate dry-run, but final accept is denied."
    } else {
      "Atom is not eligible for controlled accept candidate dry-run."
    }
    eligible_for_controlled_accept_candidate_dry_run = [bool]$eligible
    allow_final_accept = $false
    next_atom_action = if ($eligible) { "STAGE_DRY_RUN_DELTA_FOR_THIS_ATOM" } else { "REPAIR_OR_QUARANTINE_THIS_ATOM" }
    reason_codes = $reasons
    accepted_atom_claimed = $false
    accepted_state_mutated = $false
    accepted_memory_mutated = $false
    accepted_self_model_mutated = $false
  }

  $batchRecords += $record
}

$batchSize = @($batchRecords).Count
$eligibleCount = @($batchRecords | Where-Object { [bool]$_.eligible_for_controlled_accept_candidate_dry_run -eq $true }).Count
$blockedCount = $batchSize - $eligibleCount

$batchDecision = if ($eligibleCount -eq $batchSize) {
  "ALL_ATOMS_READY_FOR_CONTROLLED_ACCEPT_CANDIDATE_DRY_RUN"
} elseif ($eligibleCount -gt 0) {
  "PARTIAL_BATCH_READY_STAGE_ELIGIBLE_ONLY"
} else {
  "NO_ATOMS_READY_REPAIR_OR_QUARANTINE_BATCH"
}

$nextMachineAction = if ($eligibleCount -gt 0) {
  "BUILD_CONTROLLED_ACCEPT_CANDIDATE_DRY_RUN_FOR_ATOM_BATCH"
} else {
  "REPAIR_OR_QUARANTINE_ATOM_BATCH"
}

$envelope = [ordered]@{
  schema = "PHASE162_ATOM_BATCH_ADMISSION_ENVELOPE_V1"
  status = if ($upstreamOk -and $batchSize -gt 0) { "PASS" } else { "BLOCKED_INPUT_NOT_READY" }
  created_at = (Get-Date -Format o)
  loop_target = "builder_lives_creates_atom_or_batch_absorbs_safe_atoms_next_cycle_stronger"
  batch_policy_mode = "PER_ATOM_DECISION_NO_BATCH_BLIND_ACCEPT"
  single_atom_normalized_as_batch = [bool]($batchSize -eq 1)
  batch_size = [int]$batchSize
  eligible_atom_count = [int]$eligibleCount
  blocked_atom_count = [int]$blockedCount
  batch_decision = $batchDecision
  machine_decision = "ACCEPT_BLOCKED_AUTONOMOUS_CYCLE"
  next_machine_action = $nextMachineAction
  controller_root = $ControllerRoot
  policy_root = $PolicyRoot
  explanation_root = $ExplanationRoot
  atom_records = $batchRecords
  batch_decision_summary = "Each atom is evaluated independently. Eligible atoms may be staged in dry-run; blocked atoms keep reason codes. Final accept remains denied."
  allow_final_accept = $false
  accepted_atom_claimed = $false
  accepted_state_mutated = $false
  accepted_memory_mutated = $false
  accepted_self_model_mutated = $false
}

$request = [ordered]@{
  schema = "PHASE162_CONTROLLED_ACCEPT_CANDIDATE_DRY_RUN_FOR_ATOM_BATCH_REQUEST_V1"
  status = if ($eligibleCount -gt 0) { "READY_TO_BUILD" } else { "BLOCKED_NO_ELIGIBLE_ATOMS" }
  created_at = (Get-Date -Format o)
  reason = "Admission may receive one atom or many atoms. Controlled accept candidate must consume a batch envelope and stage only eligible atoms."
  required_trial = [ordered]@{
    mode = "DRY_RUN_ONLY_NO_ACCEPTED_CORE_WRITES"
    batch_policy = "stage_eligible_atoms_only_keep_blocked_atoms_with_reasons"
    expected_machine_decision = "ACCEPT_BLOCKED_AUTONOMOUS_CYCLE"
    forbidden = @(
      "mutate_accepted_memory",
      "mutate_accepted_self_model",
      "mutate_pack_registry",
      "claim_final_accept",
      "accept_entire_batch_blindly",
      "drop_blocked_atom_reason_codes"
    )
  }
  next_module_to_build = "invoke_phase162_controlled_accept_candidate_dry_run_for_atom_batch_001.ps1"
}

Write-Json -Path (Join-Path $OutputRoot "atom_batch_admission_envelope.json") -Object $envelope
Write-Json -Path (Join-Path $OutputRoot "controlled_accept_candidate_dry_run_for_atom_batch_request.json") -Object $request

@"
# PHASE162 Atom Batch Admission Envelope Report

## Result

- status: $($envelope.status)
- batch_policy_mode: PER_ATOM_DECISION_NO_BATCH_BLIND_ACCEPT
- single_atom_normalized_as_batch: $($envelope.single_atom_normalized_as_batch)
- batch_size: $batchSize
- eligible_atom_count: $eligibleCount
- blocked_atom_count: $blockedCount
- batch_decision: $batchDecision
- next_machine_action: $nextMachineAction
- allow_final_accept: false
- accepted_atom_claimed: false
- accepted_state_mutated: false
- accepted_memory_mutated: false
- accepted_self_model_mutated: false

## Meaning

Admission now accepts either one atom or a batch of atoms.

A single atom is treated as a batch of size 1. A batch is not accepted blindly. Every atom has its own decision, reason codes, and next action.

## Batch Rule

- eligible atoms may move into controlled accept candidate dry-run
- blocked atoms remain blocked or quarantined with reason codes
- final accept is still denied
"@ | Set-Content -Path (Join-Path $OutputRoot "PHASE162_ATOM_BATCH_ADMISSION_ENVELOPE_REPORT.md") -Encoding UTF8

[pscustomobject]@{
  status = $envelope.status
  output_root = $OutputRoot
  batch_policy_mode = [string]$envelope.batch_policy_mode
  single_atom_normalized_as_batch = [bool]$envelope.single_atom_normalized_as_batch
  batch_size = [int]$batchSize
  eligible_atom_count = [int]$eligibleCount
  blocked_atom_count = [int]$blockedCount
  batch_decision = [string]$batchDecision
  next_machine_action = [string]$nextMachineAction
  accepted_state_mutated = $false
  accepted_memory_mutated = $false
  accepted_self_model_mutated = $false
}
