param(
  [Parameter(Mandatory=$true)]
  [string]$BatchRoot,

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
  ConvertTo-Json -InputObject $Object -Depth 100 | Set-Content -Path $Path -Encoding UTF8
}

if ([string]::IsNullOrWhiteSpace($OutputRoot)) {
  $stamp = Get-Date -Format "yyyyMMdd_HHmmss"
  $OutputRoot = Join-Path (Split-Path -Parent $BatchRoot) "PHASE162_CONTROLLED_ACCEPT_CANDIDATE_DRY_RUN_FOR_ATOM_BATCH_$stamp"
}

New-Item -ItemType Directory -Force -Path $OutputRoot | Out-Null

$envelope = Read-Json (Join-Path $BatchRoot "atom_batch_admission_envelope.json")
$envelopeValidation = Read-Json (Join-Path $BatchRoot "atom_batch_admission_envelope_validation.json")

$records = @($envelope.atom_records)
$eligible = @($records | Where-Object { [bool]$_.eligible_for_controlled_accept_candidate_dry_run -eq $true })
$blocked = @($records | Where-Object { [bool]$_.eligible_for_controlled_accept_candidate_dry_run -ne $true })

$inputReady = (
  ([string]$envelopeValidation.status -eq "PASS") -and
  ([string]$envelope.next_machine_action -eq "BUILD_CONTROLLED_ACCEPT_CANDIDATE_DRY_RUN_FOR_ATOM_BATCH") -and
  ([int]$envelope.batch_size -gt 0) -and
  ($eligible.Count -gt 0)
)

$deltaRecords = @()
$index = 0

foreach ($atom in $eligible) {
  $index += 1

  $deltaRecords += [ordered]@{
    schema = "PHASE162_CONTROLLED_ACCEPT_CANDIDATE_ATOM_DELTA_DRY_RUN_V1"
    delta_index = $index
    atom_id = [string]$atom.atom_id
    source_freeze_root = [string]$atom.source_freeze_root
    source_batch_index = [int]$atom.batch_index
    planned_accept_state = "STAGED_DRY_RUN_ONLY"
    planned_accepted_memory_delta = [ordered]@{
      operation = "append_candidate_memory_record"
      target = "reports/self_development/accepted_change_memory_snapshot.json"
      dry_run_only = $true
      payload = [ordered]@{
        atom_id = [string]$atom.atom_id
        admission_state = "CONTROLLED_ACCEPT_CANDIDATE_DRY_RUN_READY"
        source_freeze_root = [string]$atom.source_freeze_root
        reason = "eligible atom from batch envelope"
      }
    }
    planned_self_model_delta = [ordered]@{
      operation = "append_candidate_self_model_note"
      target = "reports/self_development/SELF_MODEL_ACTIVE_MAP.json"
      dry_run_only = $true
      payload = [ordered]@{
        atom_id = [string]$atom.atom_id
        capability_hint = "sandbox_absorb_rehearsal_passed"
        source_freeze_root = [string]$atom.source_freeze_root
      }
    }
    planned_registry_delta = [ordered]@{
      operation = "no_registry_write_until_final_accept"
      target = "packs/registry.json"
      dry_run_only = $true
      payload = $null
    }
    accept_decision = "STAGE_ONLY_DENY_FINAL_ACCEPT"
    final_accept_allowed = $false
    reason_codes = @($atom.reason_codes)
    accepted_state_mutated = $false
    accepted_memory_mutated = $false
    accepted_self_model_mutated = $false
  }
}

$blockedRecords = @()
foreach ($atom in $blocked) {
  $blockedRecords += [ordered]@{
    atom_id = [string]$atom.atom_id
    source_freeze_root = [string]$atom.source_freeze_root
    atom_admission_state = [string]$atom.atom_admission_state
    decision_code = [string]$atom.decision_code
    next_atom_action = [string]$atom.next_atom_action
    reason_codes = @($atom.reason_codes)
  }
}

$rollbackPlan = [ordered]@{
  schema = "PHASE162_CONTROLLED_ACCEPT_CANDIDATE_ROLLBACK_PLAN_V1"
  status = if ($inputReady) { "PASS" } else { "BLOCKED_INPUT_NOT_READY" }
  rollback_mode = "DRY_RUN_ONLY"
  rollback_tested = $false
  rollback_actions = @(
    "delete_this_output_root",
    "discard_staged_delta_files",
    "no_accepted_core_restore_needed_because_no_core_write_happened"
  )
  future_final_accept_requires = @(
    "pre_accept_snapshot",
    "post_accept_validation",
    "git_revert_plan",
    "accepted_memory_restore_plan",
    "accepted_self_model_restore_plan"
  )
}

$acceptCommitPlan = [ordered]@{
  schema = "PHASE162_CONTROLLED_ACCEPT_CANDIDATE_COMMIT_PLAN_DRY_RUN_V1"
  status = if ($inputReady) { "PASS" } else { "BLOCKED_INPUT_NOT_READY" }
  commit_mode = "DRY_RUN_ONLY_NO_COMMIT_TO_ACCEPTED_CORE"
  staged_atom_count = $deltaRecords.Count
  blocked_atom_count = $blockedRecords.Count
  target_files_if_final_accept_later = @(
    "reports/self_development/accepted_change_memory_snapshot.json",
    "reports/self_development/SELF_MODEL_ACTIVE_MAP.json",
    "packs/registry.json"
  )
  forbidden_now = @(
    "mutate_accepted_memory",
    "mutate_accepted_self_model",
    "mutate_pack_registry",
    "claim_final_accept",
    "claim_absorb_complete_in_core"
  )
}

$result = [ordered]@{
  schema = "PHASE162_CONTROLLED_ACCEPT_CANDIDATE_DRY_RUN_FOR_ATOM_BATCH_RESULT_V1"
  status = if ($inputReady) { "PASS" } else { "BLOCKED_INPUT_NOT_READY" }
  created_at = (Get-Date -Format o)
  batch_root = $BatchRoot
  batch_size = [int]$envelope.batch_size
  staged_atom_count = $deltaRecords.Count
  blocked_atom_count = $blockedRecords.Count
  controlled_accept_candidate_created = [bool]$inputReady
  dry_run_only = $true
  batch_aware = $true
  per_atom_deltas_staged = ($deltaRecords.Count -gt 0)
  blocked_atoms_preserved_with_reasons = ($blocked.Count -eq 0 -or $blockedRecords.Count -eq $blocked.Count)
  accepted_memory_delta_staged = ($deltaRecords.Count -gt 0)
  accepted_self_model_delta_staged = ($deltaRecords.Count -gt 0)
  registry_delta_staged = $true
  accept_commit_plan_staged = $true
  rollback_plan_staged = $true
  final_accept_ready = $false
  machine_decision = "ACCEPT_BLOCKED_AUTONOMOUS_CYCLE"
  next_machine_action = "VALIDATE_CONTROLLED_ACCEPT_CANDIDATE_DRY_RUN_FOR_ATOM_BATCH"
  why_final_accept_denied = @(
    "dry_run_candidate_only",
    "rollback_plan_not_rehearsed_after_candidate",
    "post_accept_validation_not_run",
    "real_runtime_autonomous_absorb_not_proven",
    "accepted_core_write_not_authorized_in_this_step"
  )
  atom_delta_records = $deltaRecords
  blocked_atom_records = $blockedRecords
  accepted_atom_claimed = $false
  accepted_state_mutated = $false
  accepted_memory_mutated = $false
  accepted_self_model_mutated = $false
}

Write-Json -Path (Join-Path $OutputRoot "controlled_accept_candidate_atom_deltas.json") -Object $deltaRecords
Write-Json -Path (Join-Path $OutputRoot "controlled_accept_candidate_blocked_atoms.json") -Object $blockedRecords
Write-Json -Path (Join-Path $OutputRoot "controlled_accept_candidate_rollback_plan.json") -Object $rollbackPlan
Write-Json -Path (Join-Path $OutputRoot "controlled_accept_candidate_commit_plan.json") -Object $acceptCommitPlan
Write-Json -Path (Join-Path $OutputRoot "controlled_accept_candidate_dry_run_result.json") -Object $result

@"
# PHASE162 Controlled Accept Candidate Dry-Run For Atom Batch Report

## Result

- status: $($result.status)
- batch_aware: true
- batch_size: $($result.batch_size)
- staged_atom_count: $($result.staged_atom_count)
- blocked_atom_count: $($result.blocked_atom_count)
- controlled_accept_candidate_created: $($result.controlled_accept_candidate_created)
- per_atom_deltas_staged: $($result.per_atom_deltas_staged)
- blocked_atoms_preserved_with_reasons: $($result.blocked_atoms_preserved_with_reasons)
- final_accept_ready: false
- machine_decision: ACCEPT_BLOCKED_AUTONOMOUS_CYCLE
- next_machine_action: $($result.next_machine_action)
- accepted_atom_claimed: false
- accepted_state_mutated: false
- accepted_memory_mutated: false
- accepted_self_model_mutated: false

## Meaning

The candidate is batch-aware.

Eligible atoms are staged as separate dry-run deltas. Blocked atoms are preserved with reason codes. Nothing is written into accepted core.

## Why Final Accept Is Still Denied

$($result.why_final_accept_denied | ForEach-Object { "- $_" } | Out-String)
"@ | Set-Content -Path (Join-Path $OutputRoot "PHASE162_CONTROLLED_ACCEPT_CANDIDATE_DRY_RUN_FOR_ATOM_BATCH_REPORT.md") -Encoding UTF8

[pscustomobject]@{
  status = $result.status
  output_root = $OutputRoot
  batch_aware = [bool]$result.batch_aware
  batch_size = [int]$result.batch_size
  staged_atom_count = [int]$result.staged_atom_count
  blocked_atom_count = [int]$result.blocked_atom_count
  controlled_accept_candidate_created = [bool]$result.controlled_accept_candidate_created
  final_accept_ready = $false
  next_machine_action = [string]$result.next_machine_action
  accepted_state_mutated = $false
  accepted_memory_mutated = $false
  accepted_self_model_mutated = $false
}

