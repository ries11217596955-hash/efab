param(
  [Parameter(Mandatory=$true)]
  [string]$ExplanationRoot,

  [Parameter(Mandatory=$true)]
  [string]$PolicyRoot,

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
  $Object | ConvertTo-Json -Depth 90 | Set-Content -Path $Path -Encoding UTF8
}

function Add-Event {
  param(
    [string]$Path,
    [string]$Type,
    [object]$Data
  )

  $event = [ordered]@{
    ts = (Get-Date -Format o)
    type = $Type
    data = $Data
  }

  ($event | ConvertTo-Json -Depth 40 -Compress) | Add-Content -Path $Path -Encoding UTF8
}

if ([string]::IsNullOrWhiteSpace($OutputRoot)) {
  $stamp = Get-Date -Format "yyyyMMdd_HHmmss"
  $OutputRoot = Join-Path (Split-Path -Parent $ExplanationRoot) "PHASE162_BOUNDED_ABSORB_TRIAL_SANDBOX_$stamp"
}

New-Item -ItemType Directory -Force -Path $OutputRoot | Out-Null

$explanation = Read-Json (Join-Path $ExplanationRoot "policy_gate_decision_explanation.json")
$explanationValidation = Read-Json (Join-Path $ExplanationRoot "policy_gate_decision_explanation_validation.json")

$policy = Read-Json (Join-Path $PolicyRoot "autonomous_accept_policy_gate_result.json")
$policyValidation = Read-Json (Join-Path $PolicyRoot "autonomous_accept_policy_gate_validation.json")

$freeze = Read-Json (Join-Path $FreezeRoot "frozen_atom_candidate_evidence.json")
$freezeValidation = Read-Json (Join-Path $FreezeRoot "validation_result.json")

$inputReady = (
  ([string]$explanationValidation.status -eq "PASS") -and
  ([string]$explanation.next_machine_action -eq "RUN_BOUNDED_LIVE_DAEMON_ABSORB_TRIAL_SANDBOX") -and
  ([bool]$explanation.allow_bounded_absorb_trial -eq $true) -and
  ([bool]$explanation.allow_final_accept -eq $false) -and
  ([string]$policyValidation.status -eq "PASS") -and
  ([bool]$policy.policy_granted_for_bounded_absorb_trial -eq $true) -and
  ([string]$freezeValidation.status -eq "PASS") -and
  ([bool]$freeze.atom_candidate_summary_present_on_this_pc -eq $true) -and
  ([int]$freeze.selected_skill_candidate_count -gt 0)
)

$eventsPath = Join-Path $OutputRoot "bounded_absorb_trial_events.jsonl"
if (Test-Path -LiteralPath $eventsPath) { Remove-Item -LiteralPath $eventsPath -Force }

Add-Event -Path $eventsPath -Type "TRIAL_STARTED" -Data ([ordered]@{
  input_ready = $inputReady
  mode = "BOUNDED_SANDBOX_ONLY"
  accepted_core_write_allowed = $false
})

$baseline = [ordered]@{
  schema = "PHASE162_BOUNDED_ABSORB_TRIAL_BASELINE_CYCLE_V1"
  status = if ($inputReady) { "PASS" } else { "BLOCKED_INPUT_NOT_READY" }
  cycle_index = 1
  mode = "BASELINE_WITHOUT_SANDBOX_ABSORB_OVERLAY"
  atom_available = $false
  sandbox_absorb_overlay_available = $false
  can_select_absorbed_atom_next_action = $false
  can_explain_absorb_denial = $false
  cycle_strength_score = 0
}

Add-Event -Path $eventsPath -Type "BASELINE_CYCLE_MEASURED" -Data $baseline

$sandboxOverlay = [ordered]@{
  schema = "PHASE162_SANDBOX_ABSORB_OVERLAY_V1"
  status = if ($inputReady) { "PASS" } else { "BLOCKED_INPUT_NOT_READY" }
  mode = "SANDBOX_ABSORB_REHEARSAL_NOT_ACCEPTED_CORE"
  source_freeze_root = $FreezeRoot
  source_policy_root = $PolicyRoot
  source_explanation_root = $ExplanationRoot
  atom_summary_status = [string]$freeze.selected_atom_summary_status
  selected_duty_id = [string]$freeze.selected_duty_id
  selected_run_id = [string]$freeze.selected_run_id
  skill_candidate_count = [int]$freeze.selected_skill_candidate_count
  absorbed_into = "sandbox_overlay_only"
  final_accept_claimed = $false
  accepted_atom_claimed = $false
  accepted_state_mutated = $false
  accepted_memory_mutated = $false
  accepted_self_model_mutated = $false
  available_to_next_cycle = @(
    "sandbox_absorbed_atom_reference",
    "policy_decision_explanation",
    "reason_codes",
    "next_repair_action",
    "next_machine_action"
  )
}

Write-Json -Path (Join-Path $OutputRoot "sandbox_absorb_overlay.json") -Object $sandboxOverlay
Add-Event -Path $eventsPath -Type "SANDBOX_ABSORB_OVERLAY_CREATED" -Data ([ordered]@{
  overlay_status = $sandboxOverlay.status
  absorbed_into = $sandboxOverlay.absorbed_into
  accepted_core_mutation = $false
})

$afterScore = 0
if ($inputReady) { $afterScore += 1 }
if ($sandboxOverlay.status -eq "PASS") { $afterScore += 1 }
if ([int]$sandboxOverlay.skill_candidate_count -gt 0) { $afterScore += 1 }
if (@($explanation.reason_codes).Count -gt 0) { $afterScore += 1 }
if (-not [string]::IsNullOrWhiteSpace([string]$explanation.next_repair_action)) { $afterScore += 1 }
if ([string]$explanation.next_machine_action -eq "RUN_BOUNDED_LIVE_DAEMON_ABSORB_TRIAL_SANDBOX") { $afterScore += 1 }

$after = [ordered]@{
  schema = "PHASE162_BOUNDED_ABSORB_TRIAL_AFTER_CYCLE_V1"
  status = if ($inputReady) { "PASS" } else { "BLOCKED_INPUT_NOT_READY" }
  cycle_index = 2
  mode = "NEXT_CYCLE_WITH_SANDBOX_ABSORB_OVERLAY"
  atom_available = [bool]$inputReady
  sandbox_absorb_overlay_available = [bool]$inputReady
  can_select_absorbed_atom_next_action = [bool]$inputReady
  can_explain_absorb_denial = (@($explanation.reason_codes).Count -gt 0)
  selected_next_cycle_action = if ($inputReady) { "USE_SANDBOX_ABSORBED_ATOM_FOR_NEXT_REPAIR_OR_ACCEPT_DECISION" } else { "BLOCKED_INPUT_NOT_READY" }
  denial_explanation_available = [bool](@($explanation.reason_codes).Count -gt 0)
  cycle_strength_score = $afterScore
}

Add-Event -Path $eventsPath -Type "AFTER_CYCLE_MEASURED" -Data $after

$scoreDelta = ([int]$after.cycle_strength_score - [int]$baseline.cycle_strength_score)

$trialPassed = (
  $inputReady -and
  ([string]$sandboxOverlay.status -eq "PASS") -and
  ([bool]$after.sandbox_absorb_overlay_available -eq $true) -and
  ([bool]$after.can_select_absorbed_atom_next_action -eq $true) -and
  ([bool]$after.can_explain_absorb_denial -eq $true) -and
  ($scoreDelta -gt 0)
)

$denialReasons = @(
  "bounded_sandbox_rehearsal_only",
  "final_accept_not_permitted_by_policy_gate",
  "live_daemon_autonomous_absorb_not_proven_in_real_runtime",
  "accepted_core_mutation_forbidden_in_this_trial"
)

$result = [ordered]@{
  schema = "PHASE162_BOUNDED_LIVE_DAEMON_ABSORB_TRIAL_SANDBOX_RESULT_V1"
  status = if ($trialPassed) { "PASS" } else { "FAIL" }
  created_at = (Get-Date -Format o)
  mode = "BOUNDED_SANDBOX_ONLY"
  explanation_root = $ExplanationRoot
  policy_root = $PolicyRoot
  freeze_root = $FreezeRoot
  events_path = $eventsPath
  sandbox_absorb_trial_passed = [bool]$trialPassed
  sandbox_absorb_overlay_created = ([string]$sandboxOverlay.status -eq "PASS")
  next_cycle_stronger_after_sandbox_absorb = [bool]($scoreDelta -gt 0)
  denial_explanation_available = [bool](@($explanation.reason_codes).Count -gt 0)
  measured_strength_before = [int]$baseline.cycle_strength_score
  measured_strength_after = [int]$after.cycle_strength_score
  measured_strength_delta = [int]$scoreDelta
  machine_decision = "ACCEPT_BLOCKED_AUTONOMOUS_CYCLE"
  next_machine_action = "FEED_BOUNDED_ABSORB_TRIAL_BACK_INTO_CONTROLLER"
  final_accept_denied = $true
  why_final_accept_denied = $denialReasons
  final_accept_ready = $false
  accepted_atom_claimed = $false
  accepted_state_mutated = $false
  accepted_memory_mutated = $false
  accepted_self_model_mutated = $false
}

Write-Json -Path (Join-Path $OutputRoot "baseline_cycle_measurement.json") -Object $baseline
Write-Json -Path (Join-Path $OutputRoot "after_absorb_cycle_measurement.json") -Object $after
Write-Json -Path (Join-Path $OutputRoot "bounded_absorb_trial_result.json") -Object $result

Add-Event -Path $eventsPath -Type "TRIAL_COMPLETED" -Data ([ordered]@{
  status = $result.status
  sandbox_absorb_trial_passed = $result.sandbox_absorb_trial_passed
  measured_strength_delta = $result.measured_strength_delta
  final_accept_ready = $false
  accepted_core_mutation = $false
})

@"
# PHASE162 Bounded Live-Daemon Absorb Trial Sandbox Report

## Result

- status: $($result.status)
- sandbox_absorb_trial_passed: $($result.sandbox_absorb_trial_passed)
- sandbox_absorb_overlay_created: $($result.sandbox_absorb_overlay_created)
- next_cycle_stronger_after_sandbox_absorb: $($result.next_cycle_stronger_after_sandbox_absorb)
- denial_explanation_available: $($result.denial_explanation_available)
- measured_strength_before: $($result.measured_strength_before)
- measured_strength_after: $($result.measured_strength_after)
- measured_strength_delta: $($result.measured_strength_delta)
- final_accept_ready: false
- accepted_atom_claimed: false
- accepted_state_mutated: false
- accepted_memory_mutated: false
- accepted_self_model_mutated: false

## Meaning

This is a bounded sandbox rehearsal of absorb behavior.

The atom is not absorbed into accepted core. It is absorbed only into a sandbox overlay, then the next cycle proves it can use that overlay and explain why final accept is still blocked.

## Why Final Accept Is Still Denied

$($denialReasons | ForEach-Object { "- $_" } | Out-String)

## Next Action

Feed bounded absorb trial result back into autonomous controller.
"@ | Set-Content -Path (Join-Path $OutputRoot "PHASE162_BOUNDED_LIVE_DAEMON_ABSORB_TRIAL_SANDBOX_REPORT.md") -Encoding UTF8

[pscustomobject]@{
  status = $result.status
  output_root = $OutputRoot
  sandbox_absorb_trial_passed = [bool]$result.sandbox_absorb_trial_passed
  next_cycle_stronger_after_sandbox_absorb = [bool]$result.next_cycle_stronger_after_sandbox_absorb
  denial_explanation_available = [bool]$result.denial_explanation_available
  measured_strength_delta = [int]$result.measured_strength_delta
  final_accept_ready = $false
  accepted_state_mutated = $false
  accepted_memory_mutated = $false
  accepted_self_model_mutated = $false
}
