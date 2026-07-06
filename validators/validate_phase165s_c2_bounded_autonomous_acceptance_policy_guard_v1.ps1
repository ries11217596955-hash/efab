param(
  [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = "Stop"

function Write-J {
  param([string]$Path,[object]$Object)
  $Parent = Split-Path -Parent $Path
  if ($Parent) { New-Item -ItemType Directory -Force -Path $Parent | Out-Null }
  $Object | ConvertTo-Json -Depth 100 | Set-Content -Path $Path -Encoding UTF8
}

function Read-J {
  param([string]$Path)
  if (-not (Test-Path -LiteralPath $Path)) { throw "MISSING_FILE=$Path" }
  return Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json
}

function Count-Atom {
  param($Root,[string]$Property,[string]$AtomId)
  if ($null -eq $Root -or -not ($Root.PSObject.Properties.Name -contains $Property)) { return 0 }
  return @($Root.$Property | Where-Object { [string]$_.atom_id -eq $AtomId }).Count
}

$root = (Resolve-Path $RepoRoot).Path
$module = Join-Path $root "modules/evaluate_phase165s_c2_bounded_autonomous_atom_acceptance_policy_001.ps1"
if (-not (Test-Path -LiteralPath $module)) { throw "MISSING_POLICY_MODULE=$module" }

$runRoot = Join-Path $root "reports/self_development/phase165s_c2_bounded_autonomous_policy_guard"
New-Item -ItemType Directory -Force -Path $runRoot | Out-Null

$allowedTargets = @(
  "reports/self_development/accepted_change_memory_snapshot.json",
  "reports/self_development/SELF_MODEL_ACTIVE_MAP.json",
  "packs/registry.json"
)

$baseProofGates = [ordered]@{
  memory_proof_status = "PASS"
  use_proof_status = "PASS"
  behavior_delta_status = "PASS"
  persistence_status = "PASS"
  startup_visibility_status = "PASS"
}

$cases = [ordered]@{
  allow_small_approved_curriculum_atom = [ordered]@{
    atom_id = "decision_rule.policy_guard_test_allowed_small_atom.v1"
    batch_size = 1
    source_route = "OWNER_INBOX_CURRICULUM"
    source_authority = "OWNER_APPROVED"
    target_files = $allowedTargets
    protected_files_to_mutate = @("packs/registry.json")
    proof_gates = $baseProofGates
    rollback_plan_available = $true
    exactly_one_atom_scope = $true
    mass_acceptance_forbidden = $true
    risk_flags = @()
  }

  deny_duplicate_existing_c1b_atom = [ordered]@{
    atom_id = "decision_rule.map_signal_not_command.v1"
    batch_size = 1
    source_route = "OWNER_INBOX_CURRICULUM"
    source_authority = "OWNER_APPROVED"
    target_files = $allowedTargets
    protected_files_to_mutate = @("packs/registry.json")
    proof_gates = $baseProofGates
    rollback_plan_available = $true
    exactly_one_atom_scope = $true
    mass_acceptance_forbidden = $true
    risk_flags = @()
  }

  deny_bulk_batch = [ordered]@{
    atom_ids = @("decision_rule.bulk_a.v1","decision_rule.bulk_b.v1")
    batch_size = 2
    source_route = "OWNER_INBOX_CURRICULUM"
    source_authority = "OWNER_APPROVED"
    target_files = $allowedTargets
    protected_files_to_mutate = @("packs/registry.json")
    proof_gates = $baseProofGates
    rollback_plan_available = $true
    exactly_one_atom_scope = $false
    mass_acceptance_forbidden = $true
    risk_flags = @()
  }

  deny_unsafe_protected_target = [ordered]@{
    atom_id = "decision_rule.unsafe_target.v1"
    batch_size = 1
    source_route = "OWNER_INBOX_CURRICULUM"
    source_authority = "OWNER_APPROVED"
    target_files = @($allowedTargets + @("orchestrator/run.ps1"))
    protected_files_to_mutate = @("packs/registry.json","orchestrator/run.ps1")
    proof_gates = $baseProofGates
    rollback_plan_available = $true
    exactly_one_atom_scope = $true
    mass_acceptance_forbidden = $true
    risk_flags = @()
  }

  deny_missing_use_proof = [ordered]@{
    atom_id = "decision_rule.missing_use_proof.v1"
    batch_size = 1
    source_route = "OWNER_INBOX_CURRICULUM"
    source_authority = "OWNER_APPROVED"
    target_files = $allowedTargets
    protected_files_to_mutate = @("packs/registry.json")
    proof_gates = [ordered]@{
      memory_proof_status = "PASS"
      use_proof_status = "FAIL"
      behavior_delta_status = "PASS"
      persistence_status = "PASS"
      startup_visibility_status = "PASS"
    }
    rollback_plan_available = $true
    exactly_one_atom_scope = $true
    mass_acceptance_forbidden = $true
    risk_flags = @()
  }
}

$results = [ordered]@{}

foreach ($name in $cases.Keys) {
  $candidatePath = Join-Path $runRoot "$name.candidate.json"
  $resultPath = Join-Path $runRoot "$name.policy_result.json"
  Write-J $candidatePath $cases[$name]
  & powershell -NoProfile -ExecutionPolicy Bypass -File $module -RepoRoot $root -CandidatePath $candidatePath -OutputPath $resultPath | Out-Null
  $results[$name] = Read-J $resultPath
}

$memory = Read-J (Join-Path $root "reports/self_development/accepted_change_memory_snapshot.json")
$selfMap = Read-J (Join-Path $root "reports/self_development/SELF_MODEL_ACTIVE_MAP.json")
$registry = Read-J (Join-Path $root "packs/registry.json")
$c1bAtom = "decision_rule.map_signal_not_command.v1"

$m = Count-Atom $memory "phase162_accepted_atom_memory_records" $c1bAtom
$s = Count-Atom $selfMap "phase162_absorbed_atom_capability_notes" $c1bAtom
$r = Count-Atom $registry "phase162_accepted_atom_references" $c1bAtom

$protectedDirty = @(git -C $root status --short -- CAPABILITY_ROADMAP.json GENESIS_STATE.json TASK_QUEUE.json packs/registry.json orchestrator/run.ps1)

$checks = [ordered]@{
  c1b_atom_still_visible = (($m -eq 1) -and ($s -eq 1) -and ($r -eq 1))
  allowed_case_allowed = ([bool]$results.allow_small_approved_curriculum_atom.autonomous_accept_allowed -eq $true)
  duplicate_case_denied = ([bool]$results.deny_duplicate_existing_c1b_atom.autonomous_accept_allowed -eq $false)
  bulk_case_denied = ([bool]$results.deny_bulk_batch.autonomous_accept_allowed -eq $false)
  unsafe_protected_target_denied = ([bool]$results.deny_unsafe_protected_target.autonomous_accept_allowed -eq $false)
  missing_use_proof_denied = ([bool]$results.deny_missing_use_proof.autonomous_accept_allowed -eq $false)
  protected_state_clean = ($protectedDirty.Count -eq 0)
}

$failed = @($checks.GetEnumerator() | Where-Object { -not [bool]$_.Value } | ForEach-Object { $_.Key })
$status = if ($failed.Count -eq 0) { "PASS_POLICY_GUARD_READY" } else { "FAIL_POLICY_GUARD" }

$proofPath = Join-Path $root "proofs/self_development/PHASE165S_C2B_BOUNDED_AUTONOMOUS_ACCEPTANCE_POLICY_GUARD_V1.json"
$reportPath = Join-Path $root "reports/self_development/PHASE165S_C2B_BOUNDED_AUTONOMOUS_ACCEPTANCE_POLICY_GUARD_V1.md"

$proof = [ordered]@{
  phase = "PHASE165S_C2B_BOUNDED_AUTONOMOUS_ACCEPTANCE_POLICY_GUARD"
  status = $status
  created_at = (Get-Date -Format o)
  c1b_atom_id = $c1bAtom
  c1b_memory_count = $m
  c1b_self_map_count = $s
  c1b_registry_count = $r
  policy_module = "modules/evaluate_phase165s_c2_bounded_autonomous_atom_acceptance_policy_001.ps1"
  validator = "validators/validate_phase165s_c2_bounded_autonomous_acceptance_policy_guard_v1.ps1"
  run_root = $runRoot
  checks = $checks
  failed_checks = $failed
  allowed_case_decision = [string]$results.allow_small_approved_curriculum_atom.decision_code
  duplicate_case_decision = [string]$results.deny_duplicate_existing_c1b_atom.decision_code
  bulk_case_decision = [string]$results.deny_bulk_batch.decision_code
  unsafe_case_decision = [string]$results.deny_unsafe_protected_target.decision_code
  missing_use_case_decision = [string]$results.deny_missing_use_proof.decision_code
  protected_state_dirty_check = $protectedDirty
  next_required_action = if ($status -eq "PASS_POLICY_GUARD_READY") { "PHASE165S_C2C_AUTONOMOUS_ONE_ATOM_ACCEPTANCE_TRIAL_WITHOUT_OWNER_INTERRUPT" } else { "REPAIR_C2B_POLICY_GUARD" }
}

Write-J $proofPath $proof

@"
# PHASE165S-C2B Bounded Autonomous Acceptance Policy Guard

Status: $status

## Meaning

This guard decides whether Builder may accept one small safe atom without asking Owner every time.

## Allow Corridor

Builder may proceed without Owner interrupt only when:

- exactly one atom;
- source route is approved curriculum / Owner Inbox curriculum;
- target files are only accepted memory, self-map, and packs/registry.json;
- protected write scope is only packs/registry.json through existing PHASE162 executor;
- memory/use/behavior/persistence/startup visibility proof gates are PASS;
- rollback plan exists;
- bulk acceptance is forbidden;
- no risk flags;
- atom is not already accepted.

## Test Results

- c1b_atom_still_visible: $($checks.c1b_atom_still_visible)
- allowed_case_allowed: $($checks.allowed_case_allowed)
- duplicate_case_denied: $($checks.duplicate_case_denied)
- bulk_case_denied: $($checks.bulk_case_denied)
- unsafe_protected_target_denied: $($checks.unsafe_protected_target_denied)
- missing_use_proof_denied: $($checks.missing_use_proof_denied)
- protected_state_clean: $($checks.protected_state_clean)

## Next

$($proof.next_required_action)
"@ | Set-Content -LiteralPath $reportPath -Encoding UTF8

if ($status -eq "PASS_POLICY_GUARD_READY") {
  Write-Host "PHASE165S_C2_BOUNDED_AUTONOMOUS_POLICY_GUARD_VALIDATE_RESULT=PASS"
} else {
  Write-Host "PHASE165S_C2_BOUNDED_AUTONOMOUS_POLICY_GUARD_VALIDATE_RESULT=FAIL"
  Write-Host "FAILED_CHECKS=$($failed -join ',')"
}

[pscustomobject]@{
  status = $status
  proof_path = $proofPath
  report_path = $reportPath
  next_required_action = $proof.next_required_action
}
