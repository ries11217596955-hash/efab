param(
  [Parameter(Mandatory=$true)]
  [string]$ControllerRoot,

  [Parameter(Mandatory=$true)]
  [string]$DryRunRoot,

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
  $Object | ConvertTo-Json -Depth 80 | Set-Content -Path $Path -Encoding UTF8
}

if ([string]::IsNullOrWhiteSpace($OutputRoot)) {
  $stamp = Get-Date -Format "yyyyMMdd_HHmmss"
  $OutputRoot = Join-Path (Split-Path -Parent $ControllerRoot) "PHASE162_AUTONOMOUS_ACCEPT_POLICY_GATE_$stamp"
}

New-Item -ItemType Directory -Force -Path $OutputRoot | Out-Null

$controller = Read-Json (Join-Path $ControllerRoot "controller_with_next_cycle_trial_result.json")
$controllerValidation = Read-Json (Join-Path $ControllerRoot "controller_with_next_cycle_trial_validation.json")

$dryRun = Read-Json (Join-Path $DryRunRoot "accept_safety_contract_dry_run_activation_result.json")
$dryRunValidation = Read-Json (Join-Path $DryRunRoot "accept_safety_contract_dry_run_activation_validation.json")

$inputReady = (
  ([string]$controllerValidation.status -eq "PASS") -and
  ([string]$controller.machine_decision -eq "ACCEPT_BLOCKED_AUTONOMOUS_CYCLE") -and
  ([bool]$controller.preconditions.next_cycle_improvement_proven_partial -eq $true) -and
  ([string]$dryRunValidation.status -eq "PASS") -and
  ([bool]$dryRun.safety_validated_for_accept -eq $true) -and
  ([bool]$dryRun.rollback_tested -eq $true) -and
  ([bool]$dryRun.protected_paths_unchanged -eq $true) -and
  ([bool]$dryRun.protected_writes_denied -eq $true)
)

$policyChecks = [ordered]@{
  input_ready = [bool]$inputReady
  atom_generated = [bool]$controller.preconditions.atom_generated
  freeze_evidence_proven = [bool]$controller.preconditions.freeze_evidence_proven
  partial_usefulness_proven = [bool]$controller.preconditions.partial_usefulness_proven
  next_cycle_improvement_proven_partial = [bool]$controller.preconditions.next_cycle_improvement_proven_partial
  safety_validated_for_accept = [bool]$dryRun.safety_validated_for_accept
  rollback_tested = [bool]$dryRun.rollback_tested
  protected_paths_unchanged = [bool]$dryRun.protected_paths_unchanged
  protected_writes_denied = [bool]$dryRun.protected_writes_denied
  accepted_core_not_mutated = (
    ([bool]$dryRun.accepted_state_mutated -eq $false) -and
    ([bool]$dryRun.accepted_memory_mutated -eq $false) -and
    ([bool]$dryRun.accepted_self_model_mutated -eq $false)
  )
}

$missingForAccept = @()

if (-not [bool]$policyChecks.input_ready) { $missingForAccept += "policy_input_not_ready" }
if (-not [bool]$policyChecks.atom_generated) { $missingForAccept += "atom_not_generated" }
if (-not [bool]$policyChecks.freeze_evidence_proven) { $missingForAccept += "freeze_not_proven" }
if (-not [bool]$policyChecks.partial_usefulness_proven) { $missingForAccept += "partial_usefulness_missing" }
if (-not [bool]$policyChecks.next_cycle_improvement_proven_partial) { $missingForAccept += "next_cycle_partial_missing" }
if (-not [bool]$policyChecks.safety_validated_for_accept) { $missingForAccept += "safety_not_validated" }
if (-not [bool]$policyChecks.rollback_tested) { $missingForAccept += "rollback_not_tested" }
if (-not [bool]$policyChecks.protected_paths_unchanged) { $missingForAccept += "protected_paths_changed" }
if (-not [bool]$policyChecks.protected_writes_denied) { $missingForAccept += "protected_writes_not_denied" }
if (-not [bool]$policyChecks.accepted_core_not_mutated) { $missingForAccept += "accepted_core_mutated" }

$missingForAccept += "next_cycle_improvement_proven_for_accept_false"
$missingForAccept += "live_task_success_delta_not_proven"
$missingForAccept += "live_daemon_autonomous_absorb_not_proven"
$missingForAccept += "controlled_absorb_rehearsal_missing"

$policyGrantedForControlledAbsorbTrial = (
  $inputReady -and
  ([bool]$policyChecks.accepted_core_not_mutated -eq $true)
)

$policyGrantedForFinalAccept = $false

$result = [ordered]@{
  schema = "PHASE162_AUTONOMOUS_ACCEPT_POLICY_GATE_V1"
  status = if ($inputReady) { "PASS" } else { "BLOCKED_INPUT_NOT_READY" }
  created_at = (Get-Date -Format o)
  loop_target = "builder_lives_creates_atom_absorbs_safe_atom_next_cycle_stronger"
  controller_root = $ControllerRoot
  dry_run_root = $DryRunRoot
  policy_gate_present = $true
  human_owner_review_replaced_by_policy_gate = $true
  policy_mode = "AUTONOMOUS_POLICY_GATE_NO_HUMAN_OWNER_REVIEW"
  policy_checks = $policyChecks
  policy_granted_for_bounded_absorb_trial = [bool]$policyGrantedForControlledAbsorbTrial
  policy_granted_for_final_accept = [bool]$policyGrantedForFinalAccept
  accept_ready = $false
  machine_decision = "ACCEPT_BLOCKED_AUTONOMOUS_CYCLE"
  next_machine_action = if ($policyGrantedForControlledAbsorbTrial) { "RUN_BOUNDED_LIVE_DAEMON_ABSORB_TRIAL_SANDBOX" } else { "REPAIR_POLICY_INPUTS" }
  missing_for_final_accept = $missingForAccept
  accepted_atom_claimed = $false
  accepted_state_mutated = $false
  accepted_memory_mutated = $false
  accepted_self_model_mutated = $false
}

$request = [ordered]@{
  schema = "PHASE162_BOUNDED_LIVE_DAEMON_ABSORB_TRIAL_REQUEST_V1"
  status = if ($policyGrantedForControlledAbsorbTrial) { "READY_TO_BUILD" } else { "BLOCKED_BY_POLICY_INPUTS" }
  created_at = (Get-Date -Format o)
  reason = "Policy gate allows only bounded sandbox absorb rehearsal, not final accepted absorb."
  required_trial = [ordered]@{
    mode = "BOUNDED_SANDBOX_ONLY"
    objective = "run Builder-like cycle: atom available -> sandbox absorb overlay -> next cycle stronger"
    duration = "SHORT_BOUNDED"
    expected = "no accepted core mutation; sandbox absorb rehearsal proof"
    forbidden = @(
      "mutate_accepted_memory",
      "mutate_accepted_self_model",
      "mutate_pack_registry",
      "claim_final_accept",
      "claim_absorb_complete_in_core",
      "run_unbounded_live_daemon"
    )
  }
  next_module_to_build = "invoke_phase162_bounded_live_daemon_absorb_trial_sandbox_001.ps1"
}

Write-Json -Path (Join-Path $OutputRoot "autonomous_accept_policy_gate_result.json") -Object $result
Write-Json -Path (Join-Path $OutputRoot "bounded_live_daemon_absorb_trial_request.json") -Object $request

@"
# PHASE162 Autonomous Accept Policy Gate Report

## Result

- status: $($result.status)
- policy_gate_present: true
- human_owner_review_replaced_by_policy_gate: true
- policy_granted_for_bounded_absorb_trial: $($result.policy_granted_for_bounded_absorb_trial)
- policy_granted_for_final_accept: false
- accept_ready: false
- machine_decision: ACCEPT_BLOCKED_AUTONOMOUS_CYCLE
- next_machine_action: $($result.next_machine_action)
- accepted_atom_claimed: false
- accepted_state_mutated: false
- accepted_memory_mutated: false
- accepted_self_model_mutated: false

## Meaning

Manual owner-review is not the target. It is replaced here by an autonomous policy gate.

The policy gate does not permit final absorb. It permits only a bounded sandbox absorb rehearsal if safety dry-run and partial next-cycle proof are present.

## Target Line

Builder must live, create atom, absorb safe atom automatically, and prove the next cycle is stronger.

## Missing For Final Accept

$($missingForAccept | ForEach-Object { "- $_" } | Out-String)
"@ | Set-Content -Path (Join-Path $OutputRoot "PHASE162_AUTONOMOUS_ACCEPT_POLICY_GATE_REPORT.md") -Encoding UTF8

[pscustomobject]@{
  status = $result.status
  output_root = $OutputRoot
  policy_gate_present = $true
  human_owner_review_replaced_by_policy_gate = $true
  policy_granted_for_bounded_absorb_trial = [bool]$result.policy_granted_for_bounded_absorb_trial
  policy_granted_for_final_accept = [bool]$result.policy_granted_for_final_accept
  accept_ready = $false
  machine_decision = [string]$result.machine_decision
  next_machine_action = [string]$result.next_machine_action
  accepted_state_mutated = $false
  accepted_memory_mutated = $false
  accepted_self_model_mutated = $false
}
