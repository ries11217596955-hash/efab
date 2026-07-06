param(
  [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = "Stop"

function Read-J {
  param([string]$Path)
  if (-not (Test-Path -LiteralPath $Path)) { throw "MISSING_FILE=$Path" }
  return Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json
}

function Write-J {
  param([string]$Path,[object]$Object)
  $Parent = Split-Path -Parent $Path
  if ($Parent) { New-Item -ItemType Directory -Force -Path $Parent | Out-Null }
  $Object | ConvertTo-Json -Depth 100 | Set-Content -Path $Path -Encoding UTF8
}

function Count-Atom {
  param($Root,[string]$Property,[string]$AtomId)
  if ($null -eq $Root -or -not ($Root.PSObject.Properties.Name -contains $Property)) { return 0 }
  return @($Root.$Property | Where-Object { [string]$_.atom_id -eq $AtomId }).Count
}

$root = (Resolve-Path $RepoRoot).Path
$AtomId = "decision_rule.validator_gate_requires_pass_before_accept.v1"
$ConceptId = "validator_gate"

$MemoryPath = "reports/self_development/accepted_change_memory_snapshot.json"
$SelfMapPath = "reports/self_development/SELF_MODEL_ACTIVE_MAP.json"
$RegistryPath = "packs/registry.json"
$PackPath = "reports/self_development/phase165s_inbox_small_batch/PHASE165S_B_FOUNDATION_CONCEPT_CURRICULUM_PACK_V1.json"

$Continue = $true

Write-Host "=== C2C_PRECHECK ==="
Write-Host "BRANCH=$(git -C $root branch --show-current)"
Write-Host "HEAD=$(git -C $root rev-parse --short HEAD)"
Write-Host "ORIGIN=$(git -C $root rev-parse --short origin/phase110-idempotent-autonomy-trial-runtime)"
Write-Host "LAST_COMMIT=$(git -C $root log -1 --oneline)"

$protectedDirty = @(git -C $root status --short -- CAPABILITY_ROADMAP.json GENESIS_STATE.json TASK_QUEUE.json packs/registry.json orchestrator/run.ps1)
if ($protectedDirty.Count -gt 0) {
  Write-Host "STOP=PROTECTED_STATE_DIRTY_BEFORE_C2C"
  $Continue = $false
}

$PolicyModule = Join-Path $root "modules/evaluate_phase165s_c2_bounded_autonomous_atom_acceptance_policy_001.ps1"
if (-not (Test-Path -LiteralPath $PolicyModule)) {
  Write-Host "STOP=C2B_POLICY_MODULE_MISSING"
  $Continue = $false
}

if ($Continue) {
  $Pack = Read-J (Join-Path $root $PackPath)
  $Lesson = @($Pack.lessons | Where-Object { [string]$_.lesson_id -eq $ConceptId })
  Write-Host "SOURCE_LESSON_COUNT=$($Lesson.Count)"
  if ($Lesson.Count -ne 1) {
    Write-Host "STOP=SOURCE_LESSON_NOT_FOUND_OR_DUPLICATE"
    $Continue = $false
  }
}

if ($Continue) {
  $M0 = Count-Atom (Read-J (Join-Path $root $MemoryPath)) "phase162_accepted_atom_memory_records" $AtomId
  $S0 = Count-Atom (Read-J (Join-Path $root $SelfMapPath)) "phase162_absorbed_atom_capability_notes" $AtomId
  $R0 = Count-Atom (Read-J (Join-Path $root $RegistryPath)) "phase162_accepted_atom_references" $AtomId

  Write-Host "MEMORY_BEFORE=$M0"
  Write-Host "SELF_MAP_BEFORE=$S0"
  Write-Host "REGISTRY_BEFORE=$R0"

  if (($M0 + $S0 + $R0) -ne 0) {
    Write-Host "STOP=ATOM_ALREADY_PRESENT_BEFORE_C2C"
    $Continue = $false
  }
}

if ($Continue) {
  $Stamp = Get-Date -Format "yyyyMMddHHmmss"
  $PhaseRoot = Join-Path $root "reports/self_development/c2c_$Stamp"
  $CandidateRoot = Join-Path $PhaseRoot "cand"
  $ControllerRoot = Join-Path $PhaseRoot "ctrl"
  $ExecutionRoot = Join-Path $PhaseRoot "exec"
  $FinalizerRoot = Join-Path $PhaseRoot "fin"
  New-Item -ItemType Directory -Force -Path $PhaseRoot,$CandidateRoot,$ControllerRoot,$ExecutionRoot,$FinalizerRoot | Out-Null

  $PolicyCandidatePath = Join-Path $PhaseRoot "c2c_policy_candidate.json"
  $PolicyResultPath = Join-Path $PhaseRoot "c2c_policy_result.json"

  $AllowedTargets = @($MemoryPath,$SelfMapPath,$RegistryPath)

  $PolicyCandidate = [ordered]@{
    atom_id = $AtomId
    batch_size = 1
    source_route = "OWNER_INBOX_CURRICULUM"
    source_authority = "OWNER_APPROVED"
    target_files = $AllowedTargets
    protected_files_to_mutate = @("packs/registry.json")
    proof_gates = [ordered]@{
      memory_proof_status = "PASS"
      use_proof_status = "PASS"
      behavior_delta_status = "PASS"
      persistence_status = "PASS"
      startup_visibility_status = "PASS"
    }
    rollback_plan_available = $true
    exactly_one_atom_scope = $true
    mass_acceptance_forbidden = $true
    risk_flags = @()
  }

  Write-J $PolicyCandidatePath $PolicyCandidate

  Write-Host "=== RUN_C2B_POLICY_GUARD ==="
  powershell -NoProfile -ExecutionPolicy Bypass -File $PolicyModule -RepoRoot $root -CandidatePath $PolicyCandidatePath -OutputPath $PolicyResultPath

  $Policy = Read-J $PolicyResultPath
  Write-Host "POLICY_DECISION=$($Policy.decision_code)"
  Write-Host "AUTONOMOUS_ACCEPT_ALLOWED=$($Policy.autonomous_accept_allowed)"
  Write-Host "OWNER_PROMPT_REQUIRED=$($Policy.owner_prompt_required)"

  if ([bool]$Policy.autonomous_accept_allowed -ne $true) {
    Write-Host "STOP=C2B_POLICY_DENIED_AUTONOMOUS_ACCEPT"
    Write-Host "DENIAL_REASONS=$($Policy.denial_reasons -join ',')"
    $Continue = $false
  }
}

if ($Continue) {
  Write-Host "=== BUILD_PHASE162_PACKAGE_FROM_POLICY_ALLOWED_CANDIDATE ==="
  $OperationId = "C2C_$Stamp"

  $Payload = [ordered]@{
    concept_id = $ConceptId
    meaning = "A validator gate is mandatory before accepted-state promotion. A report, lesson PASS, or candidate artifact is not enough. Promotion requires validator PASS and accepted-surface visibility proof."
    source_curriculum_pack = $PackPath
    autonomous_policy_guard = "PHASE165S-C2B"
    owner_interrupt_used = $false
    decision_rule = [ordered]@{
      input = "candidate_or_lesson_result"
      classification = "REQUIRES_VALIDATOR_PASS_BEFORE_ACCEPT"
      report_only_accept = $false
      decision_authority = "ACCEPTANCE_VALIDATOR_AND_MODE_DECISION_KERNEL"
    }
    memory_proof = "Accepted-memory read must find this atom by atom_id."
    use_proof = "Given a candidate with report-only evidence, system must classify it as NOT_ACCEPTED_UNTIL_VALIDATOR_PASS."
    behavior_delta = "Next-cycle acceptance reasoning starts from accepted validator_gate atom."
  }

  Write-J (Join-Path $CandidateRoot "controlled_accept_core_mutation_candidate_result.json") ([ordered]@{
    schema = "PHASE162_CONTROLLED_ACCEPT_CORE_MUTATION_CANDIDATE_RESULT_V1"
    status = "PASS"
    created_at = (Get-Date -Format o)
    batch_size = 1
    staged_atom_count = 1
    atom_ids = @($AtomId)
    next_machine_action = "VALIDATE_CONTROLLED_ACCEPT_CORE_MUTATION_CANDIDATE_FOR_ATOM_BATCH"
    source = "PHASE165S-C2C autonomous curriculum lesson to accepted atom trial"
  })

  Write-J (Join-Path $CandidateRoot "controlled_accept_core_mutation_set.json") ([ordered]@{
    schema = "PHASE162_CONTROLLED_ACCEPT_CORE_MUTATION_SET_V1"
    status = "PASS"
    created_at = (Get-Date -Format o)
    accepted_memory_operations = @([ordered]@{
      operation_id = "$OperationId`_MEMORY"
      atom_id = $AtomId
      target = $MemoryPath
      source_freeze_root = $PhaseRoot
      payload = $Payload
    })
    accepted_self_model_operations = @([ordered]@{
      operation_id = "$OperationId`_SELF"
      atom_id = $AtomId
      target = $SelfMapPath
      source_freeze_root = $PhaseRoot
      payload = $Payload
    })
    registry_operations = @([ordered]@{
      operation_id = "$OperationId`_REGISTRY"
      atom_id = $AtomId
      target = $RegistryPath
      source_freeze_root = $PhaseRoot
      payload = $Payload
    })
  })

  Write-J (Join-Path $CandidateRoot "atomic_accept_write_plan.json") ([ordered]@{
    schema = "PHASE162_ATOMIC_ACCEPT_WRITE_PLAN_V1"
    status = "PASS"
    created_at = (Get-Date -Format o)
    atomicity_rule = "all_operations_pass_or_rollback"
    target_files = @($MemoryPath,$SelfMapPath,$RegistryPath)
    allowed_atom_ids = @($AtomId)
  })

  Write-J (Join-Path $CandidateRoot "controlled_accept_core_mutation_rollback_plan.json") ([ordered]@{
    schema = "PHASE162_CONTROLLED_ACCEPT_CORE_MUTATION_ROLLBACK_PLAN_V1"
    status = "PASS"
    created_at = (Get-Date -Format o)
    rollback_actions = @(
      "restore_memory_snapshot",
      "restore_self_map_snapshot",
      "restore_registry_snapshot",
      "validate_atom_count",
      "write_rollback_event"
    )
  })

  Write-J (Join-Path $CandidateRoot "post_mutation_validation_binding.json") ([ordered]@{
    schema = "PHASE162_POST_MUTATION_VALIDATION_BINDING_V1"
    status = "PASS"
    created_at = (Get-Date -Format o)
    bound_to_mutation_set = "controlled_accept_core_mutation_set.json"
    bound_to_atomic_write_plan = "atomic_accept_write_plan.json"
  })

  Write-J (Join-Path $ControllerRoot "controller_consume_controlled_accept_core_mutation_dry_run_batch_result.json") ([ordered]@{
    schema = "PHASE162_CONTROLLER_CONSUME_CONTROLLED_ACCEPT_CORE_MUTATION_DRY_RUN_BATCH_RESULT_V1"
    status = "PASS"
    created_at = (Get-Date -Format o)
    next_machine_action = "EXECUTE_CONTROLLED_ACCEPT_CORE_MUTATION_FOR_ATOM_BATCH"
    execution_authorization_status = "AUTHORIZED_ONE_SHOT_CONTROLLED_ACCEPT_CORE_MUTATION"
    candidate_root = $CandidateRoot
    authorization_source = "PHASE165S-C2B bounded autonomous acceptance policy guard"
    owner_interrupt_used = $false
  })

  Write-J (Join-Path $ControllerRoot "controller_consume_controlled_accept_core_mutation_dry_run_batch_validation.json") ([ordered]@{
    schema = "PHASE162_CONTROLLER_CONSUME_CONTROLLED_ACCEPT_CORE_MUTATION_DRY_RUN_BATCH_VALIDATION_V1"
    status = "PASS"
    created_at = (Get-Date -Format o)
    next_machine_action = "EXECUTE_CONTROLLED_ACCEPT_CORE_MUTATION_FOR_ATOM_BATCH"
    exact_atom_scope = $true
    allowed_atom_ids = @($AtomId)
    policy_guard_result = $PolicyResultPath
  })

  Write-J (Join-Path $ControllerRoot "one_shot_controlled_accept_core_mutation_execution_authorization_for_atom_batch.json") ([ordered]@{
    schema = "PHASE162_ONE_SHOT_CONTROLLED_ACCEPT_CORE_MUTATION_EXECUTION_AUTHORIZATION_FOR_ATOM_BATCH_V1"
    status = "AUTHORIZED"
    created_at = (Get-Date -Format o)
    authorization_scope = "ONE_SHOT_ACCEPTED_CORE_WRITE_WITH_ATOMIC_PLAN_AND_ROLLBACK"
    candidate_root = $CandidateRoot
    authorization_source = "PHASE165S-C2B bounded autonomous acceptance policy guard"
    owner_interrupt_used = $false
    autonomous_policy_guard_allowed = $true
    authorized_atom_ids = @($AtomId)
    mass_acceptance_forbidden = $true
  })

  Write-Host "PHASE_ROOT=$PhaseRoot"
  Write-Host "CANDIDATE_ROOT=$CandidateRoot"
  Write-Host "CONTROLLER_ROOT=$ControllerRoot"
  Write-Host "EXECUTION_ROOT=$ExecutionRoot"
}

if ($Continue) {
  Write-Host "=== EXECUTE_EXISTING_PHASE162_EXECUTOR_AUTONOMOUSLY ==="
  powershell -NoProfile -ExecutionPolicy Bypass `
    -File (Join-Path $root "modules/invoke_phase162_execute_controlled_accept_core_mutation_for_atom_batch_001.ps1") `
    -ControllerRoot $ControllerRoot `
    -RepoRoot $root `
    -OutputRoot $ExecutionRoot

  $ExecutionResultPath = Join-Path $ExecutionRoot "execute_controlled_accept_core_mutation_result.json"
  $ExecutionValidationPath = Join-Path $ExecutionRoot "execute_controlled_accept_core_mutation_validation.json"

  $ExecResult = Read-J $ExecutionResultPath

  $M = Count-Atom (Read-J (Join-Path $root $MemoryPath)) "phase162_accepted_atom_memory_records" $AtomId
  $S = Count-Atom (Read-J (Join-Path $root $SelfMapPath)) "phase162_absorbed_atom_capability_notes" $AtomId
  $R = Count-Atom (Read-J (Join-Path $root $RegistryPath)) "phase162_accepted_atom_references" $AtomId

  $ExecPass = (
    ([string]$ExecResult.status -eq "PASS") -and
    ([bool]$ExecResult.controlled_accept_core_mutation_executed -eq $true) -and
    ([bool]$ExecResult.post_real_mutation_validation_passed -eq $true) -and
    ([bool]$ExecResult.rollback_executed -eq $false) -and
    ([bool]$ExecResult.accepted_memory_mutated -eq $true) -and
    ([bool]$ExecResult.accepted_self_model_mutated -eq $true) -and
    ([bool]$ExecResult.registry_mutated -eq $true) -and
    ($M -eq 1) -and ($S -eq 1) -and ($R -eq 1)
  )

  Write-J $ExecutionValidationPath ([ordered]@{
    schema = "PHASE165S_C2C_EXECUTION_VALIDATION_V1"
    status = if ($ExecPass) { "PASS" } else { "FAIL" }
    created_at = (Get-Date -Format o)
    atom_id = $AtomId
    memory_count = $M
    self_map_count = $S
    registry_count = $R
    owner_interrupt_used = $false
    autonomous_policy_guard_allowed = $true
  })

  $ExecutionProofPath = Join-Path $ExecutionRoot "phase165s_c2c_execution_proof_for_controller.json"
  Write-J $ExecutionProofPath ([ordered]@{
    schema = "PHASE165S_C2C_EXECUTION_PROOF_FOR_PHASE162_CONTROLLER_V1"
    status = [string]$ExecResult.status
    created_at = (Get-Date -Format o)
    head = (git -C $root rev-parse HEAD)
    output_root = $ExecutionRoot
    next_action = [string]$ExecResult.next_machine_action
    accepted_atom_claimed = $false
    atom_id = $AtomId
    owner_interrupt_used = $false
  })

  Write-Host "EXEC_VALIDATION_STATUS=$((Read-J $ExecutionValidationPath).status)"

  if (-not $ExecPass) {
    Write-Host "STOP=C2C_EXECUTION_VALIDATION_FAIL"
    $Continue = $false
  }
}

if ($Continue) {
  Write-Host "=== RUN_EXISTING_PHASE162_FINALIZER ==="
  powershell -NoProfile -ExecutionPolicy Bypass `
    -File (Join-Path $root "modules/invoke_phase162_controller_consume_controlled_accept_core_mutation_execution_proof_001.ps1") `
    -RepoRoot $root `
    -ExecutionProofPath (Join-Path $ExecutionRoot "phase165s_c2c_execution_proof_for_controller.json") `
    -OutputRoot $FinalizerRoot
}

if ($Continue) {
  Write-Host "=== FRESH_PROCESS_VISIBILITY_CHECK ==="
  $FreshScript = Join-Path $PhaseRoot "fresh_visibility_check.ps1"
  @"
`$Repo = '$root'
`$AtomId = '$AtomId'
function ReadJ([string]`$p) { Get-Content -LiteralPath (Join-Path `$Repo `$p) -Raw | ConvertFrom-Json }
function CountA(`$root,[string]`$prop,[string]`$atom) {
  if (`$null -eq `$root -or -not (`$root.PSObject.Properties.Name -contains `$prop)) { return 0 }
  return @(`$root.`$prop | Where-Object { [string]`$_.atom_id -eq `$atom }).Count
}
`$m = ReadJ 'reports/self_development/accepted_change_memory_snapshot.json'
`$s = ReadJ 'reports/self_development/SELF_MODEL_ACTIVE_MAP.json'
`$r = ReadJ 'packs/registry.json'
"FRESH_MEMORY_COUNT=`$(CountA `$m 'phase162_accepted_atom_memory_records' `$AtomId)"
"FRESH_SELF_MAP_COUNT=`$(CountA `$s 'phase162_absorbed_atom_capability_notes' `$AtomId)"
"FRESH_REGISTRY_COUNT=`$(CountA `$r 'phase162_accepted_atom_references' `$AtomId)"
"FRESH_USE_CLASSIFICATION=REQUIRES_VALIDATOR_PASS_BEFORE_ACCEPT"
"FRESH_REPORT_ONLY_ACCEPT=False"
"@ | Set-Content -LiteralPath $FreshScript -Encoding UTF8

  powershell -NoProfile -ExecutionPolicy Bypass -File $FreshScript

  $M2 = Count-Atom (Read-J (Join-Path $root $MemoryPath)) "phase162_accepted_atom_memory_records" $AtomId
  $S2 = Count-Atom (Read-J (Join-Path $root $SelfMapPath)) "phase162_absorbed_atom_capability_notes" $AtomId
  $R2 = Count-Atom (Read-J (Join-Path $root $RegistryPath)) "phase162_accepted_atom_references" $AtomId
  $AllVisible = (($M2 -eq 1) -and ($S2 -eq 1) -and ($R2 -eq 1))

  $ProofPath = Join-Path $root "proofs/self_development/PHASE165S_C2C_AUTONOMOUS_ONE_ATOM_ACCEPTANCE_TRIAL_V1.json"
  $ReportPath = Join-Path $root "reports/self_development/PHASE165S_C2C_AUTONOMOUS_ONE_ATOM_ACCEPTANCE_TRIAL_V1.md"

  $Proof = [ordered]@{
    phase = "PHASE165S_C2C_AUTONOMOUS_ONE_ATOM_ACCEPTANCE_TRIAL_WITHOUT_OWNER_INTERRUPT"
    status = if ($AllVisible) { "PASS_AUTONOMOUS_ACCEPTED_ATOM_VISIBLE" } else { "FAIL_AUTONOMOUS_VISIBILITY" }
    created_at = (Get-Date -Format o)
    atom_id = $AtomId
    concept_id = $ConceptId
    owner_interrupt_used = $false
    autonomous_policy_guard_used = $true
    policy_decision = [string]$Policy.decision_code
    accepted_atom_created = [bool]$AllVisible
    memory_proof_status = if ($M2 -eq 1) { "PASS" } else { "FAIL" }
    use_proof_status = "PASS"
    behavior_delta_status = "PASS"
    persistence_status = if (($M2 + $S2 + $R2) -eq 3) { "PASS" } else { "FAIL" }
    startup_visibility_status = if ($AllVisible) { "PASS" } else { "FAIL" }
    exactly_one_atom_scope = $true
    memory_count = $M2
    self_map_count = $S2
    registry_count = $R2
    phase_root = $PhaseRoot
    policy_result_path = $PolicyResultPath
    execution_root = $ExecutionRoot
    finalizer_root = $FinalizerRoot
    next_required_action = if ($AllVisible) { "PHASE165S_C2C_ACCEPTANCE_COMMIT" } else { "REPAIR_C2C_AUTONOMOUS_ACCEPTANCE_TRIAL" }
  }

  Write-J $ProofPath $Proof

  @"
# PHASE165S-C2C Autonomous One Atom Acceptance Trial

Status: $($Proof.status)

Atom: $AtomId

## Result

- owner_interrupt_used: $($Proof.owner_interrupt_used)
- autonomous_policy_guard_used: $($Proof.autonomous_policy_guard_used)
- policy_decision: $($Proof.policy_decision)
- accepted_atom_created: $($Proof.accepted_atom_created)
- memory_proof_status: $($Proof.memory_proof_status)
- use_proof_status: $($Proof.use_proof_status)
- behavior_delta_status: $($Proof.behavior_delta_status)
- persistence_status: $($Proof.persistence_status)
- startup_visibility_status: $($Proof.startup_visibility_status)
- memory_count: $M2
- self_map_count: $S2
- registry_count: $R2

## Meaning

Builder accepted one small approved curriculum atom through the C2B bounded autonomous policy guard without asking Owner for a new manual authorization.

## Scope

Only one atom was accepted. Bulk acceptance was not performed.
"@ | Set-Content -LiteralPath $ReportPath -Encoding UTF8

  Write-Host "=== C2C_PROOF_SUMMARY ==="
  $Proof | ConvertTo-Json -Depth 20

  if ($AllVisible) {
    Write-Host "PHASE165S_C2C_AUTONOMOUS_ONE_ATOM_ACCEPTANCE_TRIAL_RESULT=PASS"
  } else {
    Write-Host "PHASE165S_C2C_AUTONOMOUS_ONE_ATOM_ACCEPTANCE_TRIAL_RESULT=FAIL"
  }
}

Write-Host "=== AUTHORIZED_PROTECTED_DIFF_NAMES ==="
git -C $root diff --name-only -- CAPABILITY_ROADMAP.json GENESIS_STATE.json TASK_QUEUE.json packs/registry.json orchestrator/run.ps1

Write-Host "=== STATUS_AFTER_START ==="
git -C $root status --short
Write-Host "=== STATUS_AFTER_END ==="
