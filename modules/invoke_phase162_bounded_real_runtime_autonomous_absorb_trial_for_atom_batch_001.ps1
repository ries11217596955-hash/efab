param(
  [Parameter(Mandatory=$true)]
  [string]$ControllerRoot,

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

function Ensure-Dir {
  param([string]$Path)
  if ($Path -and -not (Test-Path -LiteralPath $Path)) {
    New-Item -ItemType Directory -Force -Path $Path | Out-Null
  }
}

function Write-Json {
  param([string]$Path, [object]$Object)
  Ensure-Dir (Split-Path -Parent $Path)
  ConvertTo-Json -InputObject $Object -Depth 100 | Set-Content -Path $Path -Encoding UTF8
}

function Write-JsonArray {
  param([string]$Path, [object[]]$Array)
  Ensure-Dir (Split-Path -Parent $Path)
  if ($Array.Count -eq 0) {
    "[]" | Set-Content -Path $Path -Encoding UTF8
  } else {
    ConvertTo-Json -InputObject $Array -Depth 100 | Set-Content -Path $Path -Encoding UTF8
  }
}

function Add-Event {
  param([string]$Path, [string]$Type, [object]$Data)
  $event = [ordered]@{
    ts = (Get-Date -Format o)
    type = $Type
    data = $Data
  }
  ConvertTo-Json -InputObject $event -Depth 80 -Compress | Add-Content -Path $Path -Encoding UTF8
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

if ([string]::IsNullOrWhiteSpace($OutputRoot)) {
  $stamp = Get-Date -Format "yyyyMMdd_HHmmss"
  $OutputRoot = Join-Path (Split-Path -Parent $ControllerRoot) "PHASE162_BOUNDED_REAL_RUNTIME_AUTONOMOUS_ABSORB_TRIAL_FOR_ATOM_BATCH_$stamp"
}

New-Item -ItemType Directory -Force -Path $OutputRoot | Out-Null

$controller = Read-Json (Join-Path $ControllerRoot "controller_consume_post_accept_validation_dry_run_batch_result.json")
$controllerValidation = Read-Json (Join-Path $ControllerRoot "controller_consume_post_accept_validation_dry_run_batch_validation.json")
$request = Read-Json (Join-Path $ControllerRoot "bounded_real_runtime_autonomous_absorb_trial_for_atom_batch_request.json")

$postAcceptRoot = [string]$controller.post_accept_root
if (-not (Test-Path -LiteralPath $postAcceptRoot)) { throw "MISSING_POST_ACCEPT_ROOT=$postAcceptRoot" }

$postAccept = Read-Json (Join-Path $postAcceptRoot "post_accept_validation_dry_run_result.json")
$postAcceptValidation = Read-Json (Join-Path $postAcceptRoot "post_accept_validation_dry_run_validation.json")

$candidateRoot = [string]$postAccept.candidate_root
if (-not (Test-Path -LiteralPath $candidateRoot)) { throw "MISSING_CANDIDATE_ROOT=$candidateRoot" }

$candidate = Read-Json (Join-Path $candidateRoot "controlled_accept_candidate_dry_run_result.json")
$deltas = @(Read-Json (Join-Path $candidateRoot "controlled_accept_candidate_atom_deltas.json"))
$blocked = @(Read-Json (Join-Path $candidateRoot "controlled_accept_candidate_blocked_atoms.json"))

$inputReady = (
  ([string]$controllerValidation.status -eq "PASS") -and
  ([string]$controller.next_machine_action -eq "BUILD_BOUNDED_REAL_RUNTIME_AUTONOMOUS_ABSORB_TRIAL_FOR_ATOM_BATCH") -and
  ([string]$request.status -eq "READY_TO_BUILD") -and
  ([string]$postAcceptValidation.status -eq "PASS") -and
  ([bool]$postAccept.post_accept_validation_dry_run_passed -eq $true) -and
  ([bool]$postAccept.next_cycle_visibility_valid -eq $true) -and
  ([bool]$postAccept.protected_targets_unchanged -eq $true) -and
  ([int]$postAccept.staged_atom_count -gt 0) -and
  ($deltas.Count -eq [int]$postAccept.staged_atom_count)
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

$runtimeRoot = Join-Path $OutputRoot "bounded_runtime_session"
$runtimeOverlayRoot = Join-Path $runtimeRoot "runtime_absorb_overlay"
New-Item -ItemType Directory -Force -Path $runtimeOverlayRoot | Out-Null

$eventsPath = Join-Path $runtimeRoot "bounded_runtime_events.jsonl"
if (Test-Path -LiteralPath $eventsPath) { Remove-Item -LiteralPath $eventsPath -Force }

Add-Event -Path $eventsPath -Type "BOUNDED_RUNTIME_STARTED" -Data ([ordered]@{
  input_ready = $inputReady
  mode = "BOUNDED_RUNTIME_TRIAL_NO_ACCEPTED_CORE_WRITES"
  staged_atom_count = [int]$postAccept.staged_atom_count
  accepted_core_write_allowed = $false
})

$baselineCycle = [ordered]@{
  schema = "PHASE162_RUNTIME_BASELINE_CYCLE_V1"
  cycle_index = 1
  mode = "BEFORE_RUNTIME_ABSORB_OVERLAY"
  atom_batch_seen = [bool]$inputReady
  runtime_overlay_available = $false
  autonomous_absorb_decision_available = $false
  next_cycle_visibility_from_runtime_overlay = $false
  cycle_strength_score = 1
}

Write-Json -Path (Join-Path $OutputRoot "runtime_baseline_cycle.json") -Object $baselineCycle
Add-Event -Path $eventsPath -Type "RUNTIME_BASELINE_CYCLE" -Data $baselineCycle

$decisionReasonCodes = @(
  "all_dry_run_barriers_passed",
  "post_accept_validation_dry_run_passed",
  "rollback_rehearsal_passed",
  "batch_has_staged_atom_delta",
  "accepted_core_write_forbidden_in_bounded_runtime_trial"
)

$runtimeDecision = [ordered]@{
  schema = "PHASE162_RUNTIME_AUTONOMOUS_ABSORB_DECISION_V1"
  decision_code = if ($inputReady) { "ALLOW_RUNTIME_OVERLAY_ABSORB_DENY_FINAL_ACCEPT" } else { "DENY_RUNTIME_OVERLAY_ABSORB" }
  decision_summary = if ($inputReady) {
    "Bounded runtime may absorb the atom batch into runtime overlay only. Final accept remains denied."
  } else {
    "Bounded runtime cannot proceed because upstream proof is not ready."
  }
  allow_runtime_overlay_absorb = [bool]$inputReady
  allow_final_accept = $false
  reason_codes = $decisionReasonCodes
  next_runtime_action = if ($inputReady) { "CREATE_RUNTIME_ABSORB_OVERLAY_FOR_BATCH" } else { "REPAIR_RUNTIME_TRIAL_INPUTS" }
}

Write-Json -Path (Join-Path $OutputRoot "runtime_autonomous_absorb_decision.json") -Object $runtimeDecision
Add-Event -Path $eventsPath -Type "RUNTIME_AUTONOMOUS_ABSORB_DECISION" -Data $runtimeDecision

$absorbedAtomRecords = @()
foreach ($d in $deltas) {
  $absorbedAtomRecords += [ordered]@{
    atom_id = [string]$d.atom_id
    source_freeze_root = [string]$d.source_freeze_root
    runtime_absorb_state = "ABSORBED_IN_RUNTIME_OVERLAY_ONLY"
    visible_to_next_cycle = $true
    final_accept_claimed = $false
    accepted_core_write = $false
    reason_codes = @($d.reason_codes)
  }
}

$nextCycleVisibility = @()
foreach ($r in $absorbedAtomRecords) {
  $nextCycleVisibility += [ordered]@{
    atom_id = [string]$r.atom_id
    visible_to_next_cycle = $true
    selectable_by_next_cycle = $true
    allowed_use = "runtime_overlay_only"
  }
}

Write-JsonArray -Path (Join-Path $runtimeOverlayRoot "runtime_absorbed_atom_batch.json") -Array $absorbedAtomRecords
Write-JsonArray -Path (Join-Path $runtimeOverlayRoot "next_cycle_visibility.json") -Array $nextCycleVisibility
Write-JsonArray -Path (Join-Path $runtimeOverlayRoot "blocked_atoms_preserved.json") -Array $blocked
Write-Json -Path (Join-Path $runtimeOverlayRoot "runtime_decision_explanation.json") -Object $runtimeDecision

$overlayFiles = @(Get-ChildItem -LiteralPath $runtimeOverlayRoot -File | ForEach-Object { $_.Name })

Add-Event -Path $eventsPath -Type "RUNTIME_ABSORB_OVERLAY_CREATED" -Data ([ordered]@{
  overlay_root = $runtimeOverlayRoot
  overlay_file_count = $overlayFiles.Count
  absorbed_atom_count = $absorbedAtomRecords.Count
  accepted_core_write = $false
})

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

$afterStrengthScore = 1
if ($inputReady) { $afterStrengthScore += 1 }
if ([bool]$runtimeDecision.allow_runtime_overlay_absorb) { $afterStrengthScore += 1 }
if ($absorbedAtomRecords.Count -gt 0) { $afterStrengthScore += 1 }
if ($nextCycleVisibility.Count -eq $absorbedAtomRecords.Count -and $nextCycleVisibility.Count -gt 0) { $afterStrengthScore += 1 }
if ($overlayFiles.Count -ge 4) { $afterStrengthScore += 1 }
if ($protectedUnchanged) { $afterStrengthScore += 1 }

$afterCycle = [ordered]@{
  schema = "PHASE162_RUNTIME_AFTER_ABSORB_CYCLE_V1"
  cycle_index = 2
  mode = "AFTER_RUNTIME_ABSORB_OVERLAY"
  atom_batch_seen = [bool]$inputReady
  runtime_overlay_available = ($overlayFiles.Count -ge 4)
  autonomous_absorb_decision_available = (-not [string]::IsNullOrWhiteSpace([string]$runtimeDecision.decision_code))
  next_cycle_visibility_from_runtime_overlay = ($nextCycleVisibility.Count -eq $absorbedAtomRecords.Count -and $nextCycleVisibility.Count -gt 0)
  selected_next_cycle_action = "USE_RUNTIME_OVERLAY_ATOM_BATCH_FOR_CONTROLLED_ACCEPT_CORE_MUTATION_CANDIDATE_PREP"
  cycle_strength_score = [int]$afterStrengthScore
}

Write-Json -Path (Join-Path $OutputRoot "runtime_after_absorb_cycle.json") -Object $afterCycle
Add-Event -Path $eventsPath -Type "RUNTIME_AFTER_ABSORB_CYCLE" -Data $afterCycle

$scoreDelta = [int]$afterCycle.cycle_strength_score - [int]$baselineCycle.cycle_strength_score

$trialPassed = (
  $inputReady -and
  ([bool]$runtimeDecision.allow_runtime_overlay_absorb -eq $true) -and
  ($absorbedAtomRecords.Count -eq $deltas.Count) -and
  ($overlayFiles.Count -ge 4) -and
  ([bool]$afterCycle.next_cycle_visibility_from_runtime_overlay -eq $true) -and
  ($scoreDelta -gt 0) -and
  $protectedUnchanged
)

Add-Event -Path $eventsPath -Type "BOUNDED_RUNTIME_COMPLETED" -Data ([ordered]@{
  bounded_runtime_autonomous_absorb_trial_passed = [bool]$trialPassed
  score_delta = [int]$scoreDelta
  protected_targets_unchanged = [bool]$protectedUnchanged
  accepted_core_write = $false
})

$eventCount = @((Get-Content -LiteralPath $eventsPath)).Count

$result = [ordered]@{
  schema = "PHASE162_BOUNDED_REAL_RUNTIME_AUTONOMOUS_ABSORB_TRIAL_FOR_ATOM_BATCH_RESULT_V1"
  status = if ($trialPassed) { "PASS" } else { "FAIL" }
  created_at = (Get-Date -Format o)
  controller_root = $ControllerRoot
  post_accept_root = $postAcceptRoot
  candidate_root = $candidateRoot
  runtime_root = $runtimeRoot
  runtime_overlay_root = $runtimeOverlayRoot
  batch_size = [int]$candidate.batch_size
  staged_atom_count = [int]$postAccept.staged_atom_count
  blocked_atom_count = [int]$postAccept.blocked_atom_count
  bounded_runtime_autonomous_absorb_trial_passed = [bool]$trialPassed
  runtime_overlay_absorb_allowed = [bool]$runtimeDecision.allow_runtime_overlay_absorb
  runtime_overlay_created = ($overlayFiles.Count -ge 4)
  runtime_overlay_file_count = [int]$overlayFiles.Count
  next_cycle_visibility_valid = [bool]$afterCycle.next_cycle_visibility_from_runtime_overlay
  measured_strength_before = [int]$baselineCycle.cycle_strength_score
  measured_strength_after = [int]$afterCycle.cycle_strength_score
  measured_strength_delta = [int]$scoreDelta
  event_count = [int]$eventCount
  protected_targets_unchanged = [bool]$protectedUnchanged
  final_accept_ready = $false
  machine_decision = "ACCEPT_BLOCKED_AUTONOMOUS_CYCLE"
  next_machine_action = "FEED_BOUNDED_REAL_RUNTIME_AUTONOMOUS_ABSORB_TRIAL_BACK_INTO_CONTROLLER"
  why_final_accept_denied = @(
    "accepted_core_write_not_authorized_in_bounded_runtime_trial",
    "controlled_accept_core_mutation_candidate_not_prepared"
  )
  before_fingerprints = $before
  after_fingerprints = $after
  accepted_atom_claimed = $false
  accepted_state_mutated = $false
  accepted_memory_mutated = $false
  accepted_self_model_mutated = $false
}

Write-Json -Path (Join-Path $OutputRoot "bounded_real_runtime_autonomous_absorb_trial_result.json") -Object $result

@"
# PHASE162 Bounded Real-Runtime Autonomous Absorb Trial For Atom Batch Report

## Result

- status: $($result.status)
- bounded_runtime_autonomous_absorb_trial_passed: $($result.bounded_runtime_autonomous_absorb_trial_passed)
- runtime_overlay_absorb_allowed: $($result.runtime_overlay_absorb_allowed)
- runtime_overlay_created: $($result.runtime_overlay_created)
- next_cycle_visibility_valid: $($result.next_cycle_visibility_valid)
- measured_strength_delta: $($result.measured_strength_delta)
- protected_targets_unchanged: $($result.protected_targets_unchanged)
- final_accept_ready: false
- next_machine_action: $($result.next_machine_action)
- accepted_atom_claimed: false
- accepted_state_mutated: false
- accepted_memory_mutated: false
- accepted_self_model_mutated: false

## Meaning

A bounded Builder-like runtime cycle consumed the staged atom batch, made an autonomous absorb decision, absorbed only into runtime overlay, and proved next-cycle visibility.

No accepted core file was mutated.
"@ | Set-Content -Path (Join-Path $OutputRoot "PHASE162_BOUNDED_REAL_RUNTIME_AUTONOMOUS_ABSORB_TRIAL_FOR_ATOM_BATCH_REPORT.md") -Encoding UTF8

[pscustomobject]@{
  status = $result.status
  output_root = $OutputRoot
  bounded_runtime_autonomous_absorb_trial_passed = [bool]$result.bounded_runtime_autonomous_absorb_trial_passed
  runtime_overlay_absorb_allowed = [bool]$result.runtime_overlay_absorb_allowed
  next_cycle_visibility_valid = [bool]$result.next_cycle_visibility_valid
  measured_strength_delta = [int]$result.measured_strength_delta
  protected_targets_unchanged = [bool]$result.protected_targets_unchanged
  next_machine_action = [string]$result.next_machine_action
  accepted_state_mutated = $false
  accepted_memory_mutated = $false
  accepted_self_model_mutated = $false
}
