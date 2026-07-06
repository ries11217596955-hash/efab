param(
  [Parameter(Mandatory=$true)]
  [string]$ControllerRoot,

  [Parameter(Mandatory=$true)]
  [string]$CandidateRoot,

  [Parameter(Mandatory=$true)]
  [string]$RepoRoot,

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

function Get-PathFingerprint {
  param([string]$Path)

  if (-not (Test-Path -LiteralPath $Path)) {
    return [ordered]@{ exists = $false; length = 0; sha256 = "ABSENT" }
  }

  $item = Get-Item -LiteralPath $Path

  if ($item.PSIsContainer) {
    return [ordered]@{ exists = $true; length = -1; sha256 = "DIRECTORY" }
  }

  return [ordered]@{
    exists = $true
    length = $item.Length
    sha256 = (Get-FileHash -Algorithm SHA256 -LiteralPath $Path).Hash
  }
}

function Add-Event {
  param([string]$Path, [string]$Type, [object]$Data)

  $event = [ordered]@{
    ts = (Get-Date -Format o)
    type = $Type
    data = $Data
  }

  ConvertTo-Json -InputObject $event -Depth 60 -Compress | Add-Content -Path $Path -Encoding UTF8
}

if ([string]::IsNullOrWhiteSpace($OutputRoot)) {
  $stamp = Get-Date -Format "yyyyMMdd_HHmmss"
  $OutputRoot = Join-Path (Split-Path -Parent $ControllerRoot) "PHASE162_POST_ACCEPT_ROLLBACK_REHEARSAL_FOR_ATOM_BATCH_$stamp"
}

New-Item -ItemType Directory -Force -Path $OutputRoot | Out-Null

$controller = Read-Json (Join-Path $ControllerRoot "controller_consume_controlled_accept_candidate_batch_result.json")
$controllerValidation = Read-Json (Join-Path $ControllerRoot "controller_consume_controlled_accept_candidate_batch_validation.json")

$candidate = Read-Json (Join-Path $CandidateRoot "controlled_accept_candidate_dry_run_result.json")
$candidateValidation = Read-Json (Join-Path $CandidateRoot "controlled_accept_candidate_dry_run_validation.json")
$deltas = @(Read-Json (Join-Path $CandidateRoot "controlled_accept_candidate_atom_deltas.json"))
$blocked = @(Read-Json (Join-Path $CandidateRoot "controlled_accept_candidate_blocked_atoms.json"))

$inputReady = (
  ([string]$controllerValidation.status -eq "PASS") -and
  ([string]$controller.next_machine_action -eq "REHEARSE_POST_ACCEPT_ROLLBACK_FOR_ATOM_BATCH") -and
  ([string]$candidateValidation.status -eq "PASS") -and
  ([bool]$candidate.batch_aware -eq $true) -and
  ([int]$candidate.staged_atom_count -gt 0) -and
  ($deltas.Count -eq [int]$candidate.staged_atom_count)
)

$protectedTargets = @(
  "reports/self_development/accepted_change_memory_snapshot.json",
  "reports/self_development/SELF_MODEL_ACTIVE_MAP.json",
  "packs/registry.json"
)

$before = [ordered]@{}
foreach ($rel in $protectedTargets) {
  $before[$rel] = Get-PathFingerprint -Path (Join-Path $RepoRoot $rel)
}

$eventsPath = Join-Path $OutputRoot "post_accept_rollback_rehearsal_events.jsonl"
if (Test-Path -LiteralPath $eventsPath) { Remove-Item -LiteralPath $eventsPath -Force }

Add-Event -Path $eventsPath -Type "ROLLBACK_REHEARSAL_STARTED" -Data ([ordered]@{
  input_ready = $inputReady
  batch_size = [int]$candidate.batch_size
  staged_atom_count = [int]$candidate.staged_atom_count
  blocked_atom_count = [int]$candidate.blocked_atom_count
  accepted_core_write_allowed = $false
})

$OverlayRoot = Join-Path $OutputRoot "temporary_accept_overlay"
New-Item -ItemType Directory -Force -Path $OverlayRoot | Out-Null

$overlayMemory = @()
$overlaySelfModel = @()
$overlayRegistry = @()

foreach ($d in $deltas) {
  $overlayMemory += [ordered]@{
    atom_id = [string]$d.atom_id
    source_freeze_root = [string]$d.source_freeze_root
    operation = [string]$d.planned_accepted_memory_delta.operation
    target = [string]$d.planned_accepted_memory_delta.target
    dry_run_only = $true
    reason_codes = @($d.reason_codes)
  }

  $overlaySelfModel += [ordered]@{
    atom_id = [string]$d.atom_id
    source_freeze_root = [string]$d.source_freeze_root
    operation = [string]$d.planned_self_model_delta.operation
    target = [string]$d.planned_self_model_delta.target
    dry_run_only = $true
  }

  $overlayRegistry += [ordered]@{
    atom_id = [string]$d.atom_id
    operation = [string]$d.planned_registry_delta.operation
    target = [string]$d.planned_registry_delta.target
    dry_run_only = $true
  }
}

Write-Json -Path (Join-Path $OverlayRoot "accepted_memory_overlay.json") -Object $overlayMemory
Write-Json -Path (Join-Path $OverlayRoot "self_model_overlay.json") -Object $overlaySelfModel
Write-Json -Path (Join-Path $OverlayRoot "registry_overlay.json") -Object $overlayRegistry
Write-Json -Path (Join-Path $OverlayRoot "blocked_atoms_preserved.json") -Object $blocked

$overlayFilesBeforeRollback = @(Get-ChildItem -LiteralPath $OverlayRoot -File | ForEach-Object { $_.Name })

$overlayApplyState = [ordered]@{
  schema = "PHASE162_POST_ACCEPT_ROLLBACK_REHEARSAL_OVERLAY_APPLY_STATE_V1"
  status = if ($inputReady -and $overlayFilesBeforeRollback.Count -ge 4) { "PASS" } else { "FAIL" }
  overlay_root = $OverlayRoot
  staged_atom_count = $deltas.Count
  blocked_atom_count = $blocked.Count
  overlay_file_count = $overlayFilesBeforeRollback.Count
  overlay_files_created = $overlayFilesBeforeRollback
  accepted_core_mutation = $false
}

Write-Json -Path (Join-Path $OutputRoot "overlay_apply_state.json") -Object $overlayApplyState

Add-Event -Path $eventsPath -Type "OVERLAY_APPLIED" -Data ([ordered]@{
  overlay_root = $OverlayRoot
  overlay_file_count = $overlayFilesBeforeRollback.Count
  staged_atom_count = $deltas.Count
  accepted_core_mutation = $false
})

Remove-Item -LiteralPath $OverlayRoot -Recurse -Force
$overlayRemoved = -not (Test-Path -LiteralPath $OverlayRoot)

$after = [ordered]@{}
foreach ($rel in $protectedTargets) {
  $after[$rel] = Get-PathFingerprint -Path (Join-Path $RepoRoot $rel)
}

$protectedUnchanged = $true
foreach ($rel in $protectedTargets) {
  $b = $before[$rel]
  $a = $after[$rel]

  if (
    ([bool]$b.exists -ne [bool]$a.exists) -or
    ([int64]$b.length -ne [int64]$a.length) -or
    ([string]$b.sha256 -ne [string]$a.sha256)
  ) {
    $protectedUnchanged = $false
  }
}

$rollbackPassed = (
  $inputReady -and
  ([string]$overlayApplyState.status -eq "PASS") -and
  ($overlayFilesBeforeRollback.Count -ge 4) -and
  $overlayRemoved -and
  $protectedUnchanged
)

$rollbackResult = [ordered]@{
  schema = "PHASE162_POST_ACCEPT_ROLLBACK_REHEARSAL_RESULT_V1"
  status = if ($rollbackPassed) { "PASS" } else { "FAIL" }
  rollback_rehearsal_passed = [bool]$rollbackPassed
  overlay_files_before_rollback = $overlayFilesBeforeRollback
  overlay_removed_after_rollback = [bool]$overlayRemoved
  protected_targets_unchanged = [bool]$protectedUnchanged
  before_fingerprints = $before
  after_fingerprints = $after
  accepted_core_mutation = $false
}

Write-Json -Path (Join-Path $OutputRoot "rollback_rehearsal_result.json") -Object $rollbackResult

Add-Event -Path $eventsPath -Type "ROLLBACK_REHEARSAL_COMPLETED" -Data ([ordered]@{
  rollback_rehearsal_passed = $rollbackPassed
  overlay_removed_after_rollback = $overlayRemoved
  protected_targets_unchanged = $protectedUnchanged
  accepted_core_mutation = $false
})

$result = [ordered]@{
  schema = "PHASE162_POST_ACCEPT_ROLLBACK_REHEARSAL_FOR_ATOM_BATCH_RESULT_V1"
  status = if ($rollbackPassed) { "PASS" } else { "FAIL" }
  created_at = (Get-Date -Format o)
  controller_root = $ControllerRoot
  candidate_root = $CandidateRoot
  batch_size = [int]$candidate.batch_size
  staged_atom_count = [int]$candidate.staged_atom_count
  blocked_atom_count = [int]$candidate.blocked_atom_count
  rollback_rehearsal_passed = [bool]$rollbackPassed
  overlay_apply_passed = ([string]$overlayApplyState.status -eq "PASS")
  overlay_file_count_before_rollback = $overlayFilesBeforeRollback.Count
  overlay_removed_after_rollback = [bool]$overlayRemoved
  protected_targets_unchanged = [bool]$protectedUnchanged
  blocked_atoms_preserved_with_reasons = ($blocked.Count -eq 0 -or @($blocked | Where-Object { @($_.reason_codes).Count -gt 0 }).Count -eq $blocked.Count)
  final_accept_ready = $false
  machine_decision = "ACCEPT_BLOCKED_AUTONOMOUS_CYCLE"
  next_machine_action = "FEED_POST_ACCEPT_ROLLBACK_REHEARSAL_BACK_INTO_CONTROLLER"
  why_final_accept_denied = @(
    "post_accept_validation_not_run",
    "real_runtime_autonomous_absorb_not_proven",
    "accepted_core_write_not_authorized_in_rollback_rehearsal_step"
  )
  accepted_atom_claimed = $false
  accepted_state_mutated = $false
  accepted_memory_mutated = $false
  accepted_self_model_mutated = $false
}

Write-Json -Path (Join-Path $OutputRoot "post_accept_rollback_rehearsal_result.json") -Object $result

@"
# PHASE162 Post-Accept Rollback Rehearsal For Atom Batch Report

## Result

- status: $($result.status)
- batch_size: $($result.batch_size)
- staged_atom_count: $($result.staged_atom_count)
- blocked_atom_count: $($result.blocked_atom_count)
- rollback_rehearsal_passed: $($result.rollback_rehearsal_passed)
- overlay_apply_passed: $($result.overlay_apply_passed)
- overlay_file_count_before_rollback: $($result.overlay_file_count_before_rollback)
- overlay_removed_after_rollback: $($result.overlay_removed_after_rollback)
- protected_targets_unchanged: $($result.protected_targets_unchanged)
- final_accept_ready: false
- next_machine_action: $($result.next_machine_action)
- accepted_atom_claimed: false
- accepted_state_mutated: false
- accepted_memory_mutated: false
- accepted_self_model_mutated: false

## Meaning

Staged per-atom accept deltas were applied only to a temporary overlay, then the overlay was removed.

Accepted core files were fingerprinted before and after. They remained unchanged.
"@ | Set-Content -Path (Join-Path $OutputRoot "PHASE162_POST_ACCEPT_ROLLBACK_REHEARSAL_FOR_ATOM_BATCH_REPORT.md") -Encoding UTF8

[pscustomobject]@{
  status = $result.status
  output_root = $OutputRoot
  rollback_rehearsal_passed = [bool]$result.rollback_rehearsal_passed
  overlay_apply_passed = [bool]$result.overlay_apply_passed
  overlay_file_count_before_rollback = [int]$result.overlay_file_count_before_rollback
  overlay_removed_after_rollback = [bool]$result.overlay_removed_after_rollback
  protected_targets_unchanged = [bool]$result.protected_targets_unchanged
  staged_atom_count = [int]$result.staged_atom_count
  next_machine_action = [string]$result.next_machine_action
  accepted_state_mutated = $false
  accepted_memory_mutated = $false
  accepted_self_model_mutated = $false
}
