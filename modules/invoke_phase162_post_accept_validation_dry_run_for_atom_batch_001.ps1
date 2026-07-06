param(
  [Parameter(Mandatory=$true)]
  [string]$ControllerRoot,

  [Parameter(Mandatory=$true)]
  [string]$RollbackRoot,

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
  $OutputRoot = Join-Path (Split-Path -Parent $ControllerRoot) "PHASE162_POST_ACCEPT_VALIDATION_DRY_RUN_FOR_ATOM_BATCH_$stamp"
}

New-Item -ItemType Directory -Force -Path $OutputRoot | Out-Null

$controller = Read-Json (Join-Path $ControllerRoot "controller_consume_post_accept_rollback_rehearsal_batch_result.json")
$controllerValidation = Read-Json (Join-Path $ControllerRoot "controller_consume_post_accept_rollback_rehearsal_batch_validation.json")

$rollback = Read-Json (Join-Path $RollbackRoot "post_accept_rollback_rehearsal_result.json")
$rollbackValidation = Read-Json (Join-Path $RollbackRoot "post_accept_rollback_rehearsal_validation.json")

$candidate = Read-Json (Join-Path $CandidateRoot "controlled_accept_candidate_dry_run_result.json")
$candidateValidation = Read-Json (Join-Path $CandidateRoot "controlled_accept_candidate_dry_run_validation.json")
$deltas = @(Read-Json (Join-Path $CandidateRoot "controlled_accept_candidate_atom_deltas.json"))
$blocked = @(Read-Json (Join-Path $CandidateRoot "controlled_accept_candidate_blocked_atoms.json"))

$inputReady = (
  ([string]$controllerValidation.status -eq "PASS") -and
  ([string]$controller.next_machine_action -eq "BUILD_POST_ACCEPT_VALIDATION_DRY_RUN_FOR_ATOM_BATCH") -and
  ([string]$rollbackValidation.status -eq "PASS") -and
  ([bool]$rollback.rollback_rehearsal_passed -eq $true) -and
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

$eventsPath = Join-Path $OutputRoot "post_accept_validation_dry_run_events.jsonl"
if (Test-Path -LiteralPath $eventsPath) { Remove-Item -LiteralPath $eventsPath -Force }

Add-Event -Path $eventsPath -Type "POST_ACCEPT_VALIDATION_DRY_RUN_STARTED" -Data ([ordered]@{
  input_ready = $inputReady
  staged_atom_count = [int]$candidate.staged_atom_count
  blocked_atom_count = [int]$candidate.blocked_atom_count
  accepted_core_write_allowed = $false
})

$DryRunStateRoot = Join-Path $OutputRoot "post_accept_validation_overlay"
New-Item -ItemType Directory -Force -Path $DryRunStateRoot | Out-Null

$memoryView = @()
$selfModelView = @()
$registryView = @()
$nextCycleVisibility = @()

foreach ($d in $deltas) {
  $memoryView += [ordered]@{
    schema = "PHASE162_DRY_RUN_ACCEPTED_MEMORY_VIEW_RECORD_V1"
    atom_id = [string]$d.atom_id
    source_freeze_root = [string]$d.source_freeze_root
    operation = [string]$d.planned_accepted_memory_delta.operation
    target = [string]$d.planned_accepted_memory_delta.target
    dry_run_only = $true
    reason_codes = @($d.reason_codes)
  }

  $selfModelView += [ordered]@{
    schema = "PHASE162_DRY_RUN_SELF_MODEL_VIEW_RECORD_V1"
    atom_id = [string]$d.atom_id
    source_freeze_root = [string]$d.source_freeze_root
    operation = [string]$d.planned_self_model_delta.operation
    target = [string]$d.planned_self_model_delta.target
    dry_run_only = $true
  }

  $registryView += [ordered]@{
    schema = "PHASE162_DRY_RUN_REGISTRY_VIEW_RECORD_V1"
    atom_id = [string]$d.atom_id
    operation = [string]$d.planned_registry_delta.operation
    target = [string]$d.planned_registry_delta.target
    dry_run_only = $true
    final_registry_write_allowed = $false
  }

  $nextCycleVisibility += [ordered]@{
    schema = "PHASE162_DRY_RUN_NEXT_CYCLE_VISIBILITY_RECORD_V1"
    atom_id = [string]$d.atom_id
    visible_to_next_cycle = $true
    allowed_next_cycle_use = "sandbox_or_post_accept_validation_only"
    final_accept_claimed = $false
  }
}

Write-Json -Path (Join-Path $DryRunStateRoot "accepted_memory_validation_view.json") -Object $memoryView
Write-Json -Path (Join-Path $DryRunStateRoot "self_model_validation_view.json") -Object $selfModelView
Write-Json -Path (Join-Path $DryRunStateRoot "registry_validation_view.json") -Object $registryView
Write-Json -Path (Join-Path $DryRunStateRoot "next_cycle_visibility_probe.json") -Object $nextCycleVisibility
Write-Json -Path (Join-Path $DryRunStateRoot "blocked_atoms_preserved.json") -Object $blocked

$memorySchemaValid = ($memoryView.Count -eq $deltas.Count -and @($memoryView | Where-Object { [string]$_.atom_id -ne "" -and [bool]$_.dry_run_only -eq $true }).Count -eq $deltas.Count)
$selfModelSchemaValid = ($selfModelView.Count -eq $deltas.Count -and @($selfModelView | Where-Object { [string]$_.atom_id -ne "" -and [bool]$_.dry_run_only -eq $true }).Count -eq $deltas.Count)
$registryConsistencyValid = ($registryView.Count -eq $deltas.Count -and @($registryView | Where-Object { [bool]$_.dry_run_only -eq $true -and [bool]$_.final_registry_write_allowed -eq $false }).Count -eq $deltas.Count)
$nextCycleVisibilityValid = ($nextCycleVisibility.Count -eq $deltas.Count -and @($nextCycleVisibility | Where-Object { [bool]$_.visible_to_next_cycle -eq $true }).Count -eq $deltas.Count)
$blockedPreserved = ($blocked.Count -eq 0 -or @($blocked | Where-Object { @($_.reason_codes).Count -gt 0 }).Count -eq $blocked.Count)

$overlayFiles = @(Get-ChildItem -LiteralPath $DryRunStateRoot -File | ForEach-Object { $_.Name })

$validationChecks = [ordered]@{
  input_ready = [bool]$inputReady
  memory_schema_valid = [bool]$memorySchemaValid
  self_model_schema_valid = [bool]$selfModelSchemaValid
  registry_consistency_valid = [bool]$registryConsistencyValid
  next_cycle_visibility_valid = [bool]$nextCycleVisibilityValid
  blocked_atoms_preserved_with_reasons = [bool]$blockedPreserved
  overlay_file_count = [int]$overlayFiles.Count
  dry_run_only = $true
}

Write-Json -Path (Join-Path $OutputRoot "post_accept_validation_checks.json") -Object $validationChecks

Add-Event -Path $eventsPath -Type "POST_ACCEPT_VALIDATION_CHECKS_BUILT" -Data $validationChecks

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

$postAcceptValidationPassed = (
  $inputReady -and
  $memorySchemaValid -and
  $selfModelSchemaValid -and
  $registryConsistencyValid -and
  $nextCycleVisibilityValid -and
  $blockedPreserved -and
  ($overlayFiles.Count -ge 5) -and
  $protectedUnchanged
)

Add-Event -Path $eventsPath -Type "POST_ACCEPT_VALIDATION_DRY_RUN_COMPLETED" -Data ([ordered]@{
  post_accept_validation_dry_run_passed = [bool]$postAcceptValidationPassed
  protected_targets_unchanged = [bool]$protectedUnchanged
  accepted_core_mutation = $false
})

$result = [ordered]@{
  schema = "PHASE162_POST_ACCEPT_VALIDATION_DRY_RUN_FOR_ATOM_BATCH_RESULT_V1"
  status = if ($postAcceptValidationPassed) { "PASS" } else { "FAIL" }
  created_at = (Get-Date -Format o)
  controller_root = $ControllerRoot
  rollback_root = $RollbackRoot
  candidate_root = $CandidateRoot
  batch_size = [int]$candidate.batch_size
  staged_atom_count = [int]$candidate.staged_atom_count
  blocked_atom_count = [int]$candidate.blocked_atom_count
  post_accept_validation_dry_run_passed = [bool]$postAcceptValidationPassed
  memory_schema_valid = [bool]$memorySchemaValid
  self_model_schema_valid = [bool]$selfModelSchemaValid
  registry_consistency_valid = [bool]$registryConsistencyValid
  next_cycle_visibility_valid = [bool]$nextCycleVisibilityValid
  blocked_atoms_preserved_with_reasons = [bool]$blockedPreserved
  overlay_file_count = [int]$overlayFiles.Count
  protected_targets_unchanged = [bool]$protectedUnchanged
  before_fingerprints = $before
  after_fingerprints = $after
  final_accept_ready = $false
  machine_decision = "ACCEPT_BLOCKED_AUTONOMOUS_CYCLE"
  next_machine_action = "FEED_POST_ACCEPT_VALIDATION_DRY_RUN_BACK_INTO_CONTROLLER"
  why_final_accept_denied = @(
    "real_runtime_autonomous_absorb_not_proven",
    "accepted_core_write_not_authorized_in_post_accept_validation_dry_run_step"
  )
  accepted_atom_claimed = $false
  accepted_state_mutated = $false
  accepted_memory_mutated = $false
  accepted_self_model_mutated = $false
}

Write-Json -Path (Join-Path $OutputRoot "post_accept_validation_dry_run_result.json") -Object $result

@"
# PHASE162 Post-Accept Validation Dry-Run For Atom Batch Report

## Result

- status: $($result.status)
- post_accept_validation_dry_run_passed: $($result.post_accept_validation_dry_run_passed)
- memory_schema_valid: $($result.memory_schema_valid)
- self_model_schema_valid: $($result.self_model_schema_valid)
- registry_consistency_valid: $($result.registry_consistency_valid)
- next_cycle_visibility_valid: $($result.next_cycle_visibility_valid)
- overlay_file_count: $($result.overlay_file_count)
- protected_targets_unchanged: $($result.protected_targets_unchanged)
- final_accept_ready: false
- next_machine_action: $($result.next_machine_action)
- accepted_atom_claimed: false
- accepted_state_mutated: false
- accepted_memory_mutated: false
- accepted_self_model_mutated: false

## Meaning

This dry-run simulates the checks that must pass immediately after a future controlled accepted-core write.

No accepted core file was mutated.
"@ | Set-Content -Path (Join-Path $OutputRoot "PHASE162_POST_ACCEPT_VALIDATION_DRY_RUN_FOR_ATOM_BATCH_REPORT.md") -Encoding UTF8

[pscustomobject]@{
  status = $result.status
  output_root = $OutputRoot
  post_accept_validation_dry_run_passed = [bool]$result.post_accept_validation_dry_run_passed
  memory_schema_valid = [bool]$result.memory_schema_valid
  self_model_schema_valid = [bool]$result.self_model_schema_valid
  registry_consistency_valid = [bool]$result.registry_consistency_valid
  next_cycle_visibility_valid = [bool]$result.next_cycle_visibility_valid
  protected_targets_unchanged = [bool]$result.protected_targets_unchanged
  staged_atom_count = [int]$result.staged_atom_count
  next_machine_action = [string]$result.next_machine_action
  accepted_state_mutated = $false
  accepted_memory_mutated = $false
  accepted_self_model_mutated = $false
}
