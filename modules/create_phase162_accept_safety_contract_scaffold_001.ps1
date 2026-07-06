param(
  [Parameter(Mandatory=$true)]
  [string]$PartialGateRoot,

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
  $Object | ConvertTo-Json -Depth 30 | Set-Content -Path $Path -Encoding UTF8
}

if ([string]::IsNullOrWhiteSpace($OutputRoot)) {
  $stamp = Get-Date -Format "yyyyMMdd_HHmmss"
  $OutputRoot = Join-Path (Split-Path -Parent $PartialGateRoot) "PHASE162_ACCEPT_SAFETY_CONTRACTS_$stamp"
}

New-Item -ItemType Directory -Force -Path $OutputRoot | Out-Null

$gate = Read-Json (Join-Path $PartialGateRoot "accept_gate_partial_usefulness_result.json")
$gateValidation = Read-Json (Join-Path $PartialGateRoot "accept_gate_partial_usefulness_validation.json")

$inputOk = (
  ([string]$gate.status -eq "PASS") -and
  ([string]$gateValidation.status -eq "PASS") -and
  ([string]$gate.gate_decision -eq "ACCEPT_BLOCKED") -and
  ([bool]$gate.usefulness_validated_partial -eq $true) -and
  ([bool]$gate.usefulness_validated_for_accept -eq $false) -and
  ([bool]$gate.safety_validated_for_accept -eq $false) -and
  ([bool]$gate.accept_ready -eq $false)
)

$protectedPaths = @(
  "GENESIS_STATE.json",
  "CAPABILITY_ROADMAP.json",
  "TASK_QUEUE.json",
  "packs/registry.json",
  "reports/self_development/SELF_MODEL_ACTIVE_MAP.json",
  "reports/self_development/accepted_change_memory_snapshot.json",
  "reports/self_development/agent_body_map.json"
)

$allowedCurrentWriteRoots = @(
  "reports/self_development/phase162_admission_freeze_absorb/",
  "proofs/self_development/"
)

$blockers = @(
  "owner_review_gate_missing",
  "accept_write_contracts_scaffold_only_not_active",
  "rollback_test_not_proven",
  "next_cycle_improvement_proof_missing",
  "live_task_success_delta_missing",
  "accepted_memory_write_contract_not_activated",
  "accepted_self_model_write_contract_not_activated"
)

$contract = [ordered]@{
  schema = "PHASE162_ACCEPT_SAFETY_CONTRACT_SCAFFOLD_V1"
  status = if ($inputOk) { "PASS" } else { "BLOCKED_INPUT_NOT_READY" }
  created_at = (Get-Date -Format o)
  partial_gate_root = $PartialGateRoot
  contract_mode = "DRY_RUN_ONLY_NO_ACCEPTED_CORE_WRITES"
  accept_safety_contracts_present = $true
  safety_validated_for_accept = $false
  accept_ready = $false

  consumed_gate = [ordered]@{
    gate_decision = [string]$gate.gate_decision
    usefulness_validated_partial = [bool]$gate.usefulness_validated_partial
    usefulness_validated_for_accept = [bool]$gate.usefulness_validated_for_accept
    safety_validated_for_accept = [bool]$gate.safety_validated_for_accept
    accept_ready = [bool]$gate.accept_ready
    validation_status = [string]$gateValidation.status
  }

  current_allowed_writes = $allowedCurrentWriteRoots

  protected_paths = $protectedPaths

  future_accept_write_contracts = [ordered]@{
    accepted_memory_write_contract = "SCAFFOLD_PRESENT_NOT_ACTIVE"
    accepted_self_model_write_contract = "SCAFFOLD_PRESENT_NOT_ACTIVE"
    accepted_registry_write_contract = "SCAFFOLD_PRESENT_NOT_ACTIVE"
    accepted_state_write_contract = "SCAFFOLD_PRESENT_NOT_ACTIVE"
    activation_requires_owner_review = $true
    activation_requires_rollback_test = $true
    activation_requires_next_cycle_improvement_proof = $true
  }

  owner_review_gate = [ordered]@{
    required = $true
    granted = $false
    blocker = "owner_review_gate_missing"
  }

  rollback_plan = [ordered]@{
    scaffold_present = $true
    rollback_tested = $false
    allowed_current_rollback = "delete_this_phase162_output_root_before_activation_or_git_revert_commit"
    future_accept_rollback_required = "git_revert_plus_restore_previous_accepted_memory_snapshot"
  }

  hard_forbidden_now = @(
    "write_to_accepted_memory",
    "write_to_accepted_self_model",
    "write_to_pack_registry",
    "write_to_genesis_state",
    "claim_accept_ready",
    "claim_absorb_complete",
    "run_live_daemon_for_accept"
  )

  blocking_reasons = $blockers

  accepted_atom_claimed = $false
  accepted_state_mutated = $false
  accepted_memory_mutated = $false
  accepted_self_model_mutated = $false
}

$dryRun = [ordered]@{
  schema = "PHASE162_ACCEPT_SAFETY_CONTRACT_DRY_RUN_V1"
  status = if ($inputOk) { "PASS" } else { "BLOCKED_INPUT_NOT_READY" }
  created_at = (Get-Date -Format o)
  mode = "NO_ACCEPTED_CORE_WRITES"
  actual_write_roots = @($OutputRoot)
  accepted_core_write_attempted = $false
  accepted_state_mutated = $false
  accepted_memory_mutated = $false
  accepted_self_model_mutated = $false
  protected_paths_checked = $protectedPaths
  result = "SAFETY_CONTRACT_SCAFFOLD_CREATED_BUT_ACCEPT_REMAINS_BLOCKED"
}

$result = [ordered]@{
  schema = "PHASE162_ACCEPT_SAFETY_CONTRACT_SCAFFOLD_RESULT_V1"
  status = if ($inputOk) { "PASS" } else { "BLOCKED_INPUT_NOT_READY" }
  created_at = (Get-Date -Format o)
  partial_gate_root = $PartialGateRoot
  contract_path = Join-Path $OutputRoot "accept_safety_contract_scaffold.json"
  dry_run_path = Join-Path $OutputRoot "accept_safety_contract_dry_run.json"
  accept_safety_contracts_present = $true
  safety_validated_for_accept = $false
  usefulness_validated_partial = [bool]$gate.usefulness_validated_partial
  usefulness_validated_for_accept = $false
  accept_ready = $false
  expected_gate_decision = "ACCEPT_BLOCKED"
  blocking_reasons = $blockers
  accepted_atom_claimed = $false
  accepted_state_mutated = $false
  accepted_memory_mutated = $false
  accepted_self_model_mutated = $false
  next_action = "UPGRADE_ACCEPT_GATE_TO_CONSUME_SAFETY_CONTRACT_SCAFFOLD_BUT_KEEP_ACCEPT_BLOCKED"
}

Write-Json -Path (Join-Path $OutputRoot "accept_safety_contract_scaffold.json") -Object $contract
Write-Json -Path (Join-Path $OutputRoot "accept_safety_contract_dry_run.json") -Object $dryRun
Write-Json -Path (Join-Path $OutputRoot "accept_safety_contract_result.json") -Object $result

@"
# PHASE162 Accept Safety Contract Scaffold Report

## Result

- status: $($result.status)
- accept_safety_contracts_present: true
- safety_validated_for_accept: false
- usefulness_validated_partial: $($result.usefulness_validated_partial)
- usefulness_validated_for_accept: false
- accept_ready: false
- expected_gate_decision: ACCEPT_BLOCKED
- accepted_atom_claimed: false
- accepted_state_mutated: false
- accepted_memory_mutated: false
- accepted_self_model_mutated: false

## Meaning

This creates the safety boundary for future controlled accept.

It does not activate writes into accepted memory, accepted self-model, registry, GENESIS_STATE, or Builder core state.

## Current Mode

DRY_RUN_ONLY_NO_ACCEPTED_CORE_WRITES

## Blockers

$($blockers | ForEach-Object { "- $_" } | Out-String)

## Next Action

Upgrade accept gate to consume this safety contract scaffold. It must still return ACCEPT_BLOCKED.
"@ | Set-Content -Path (Join-Path $OutputRoot "PHASE162_ACCEPT_SAFETY_CONTRACT_SCAFFOLD_REPORT.md") -Encoding UTF8

[pscustomobject]@{
  status = $result.status
  output_root = $OutputRoot
  accept_safety_contracts_present = $true
  safety_validated_for_accept = $false
  usefulness_validated_partial = [bool]$gate.usefulness_validated_partial
  accept_ready = $false
  expected_gate_decision = "ACCEPT_BLOCKED"
  blocker_count = $blockers.Count
  accepted_state_mutated = $false
  accepted_memory_mutated = $false
  accepted_self_model_mutated = $false
}
