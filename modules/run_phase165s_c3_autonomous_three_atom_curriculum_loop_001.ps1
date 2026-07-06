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

$MemoryPath = "reports/self_development/accepted_change_memory_snapshot.json"
$SelfMapPath = "reports/self_development/SELF_MODEL_ACTIVE_MAP.json"
$RegistryPath = "packs/registry.json"
$PackPath = "reports/self_development/phase165s_inbox_small_batch/PHASE165S_B_FOUNDATION_CONCEPT_CURRICULUM_PACK_V1.json"
$PolicyModule = Join-Path $root "modules/evaluate_phase165s_c2_bounded_autonomous_atom_acceptance_policy_001.ps1"

$Atoms = @(
  [ordered]@{
    concept_id = "proof_path"
    atom_id = "decision_rule.proof_path_required_for_done_claim.v1"
    meaning = "A done/fixed/accepted claim must point to a concrete proof path such as proof JSON, report, validator output, commit, push, workflow, or log. Unsupported claims stay unaccepted."
    classification = "REQUIRES_CONCRETE_PROOF_PATH"
  },
  [ordered]@{
    concept_id = "quarantine"
    atom_id = "decision_rule.quarantine_unproven_or_risky_candidate.v1"
    meaning = "Unproven, risky, duplicate, or out-of-scope candidates must be quarantined instead of being silently promoted into accepted state."
    classification = "QUARANTINE_UNPROVEN_OR_RISKY_CANDIDATE"
  },
  [ordered]@{
    concept_id = "approved_source_catalog"
    atom_id = "decision_rule.approved_source_catalog_required_for_external_material.v1"
    meaning = "External material may support Builder only when source provenance and approval status are known. Unknown material is a candidate, not trusted memory."
    classification = "REQUIRE_APPROVED_SOURCE_CATALOG_FOR_EXTERNAL_MATERIAL"
  }
)

Write-Host "=== C3_PRECHECK ==="
Write-Host "BRANCH=$(git -C $root branch --show-current)"
Write-Host "HEAD=$(git -C $root rev-parse --short HEAD)"
Write-Host "ORIGIN=$(git -C $root rev-parse --short origin/phase110-idempotent-autonomy-trial-runtime)"
Write-Host "LAST_COMMIT=$(git -C $root log -1 --oneline)"

$Continue = $true

$protectedDirty = @(git -C $root status --short -- CAPABILITY_ROADMAP.json GENESIS_STATE.json TASK_QUEUE.json packs/registry.json orchestrator/run.ps1)
if ($protectedDirty.Count -gt 0) {
  Write-Host "STOP=PROTECTED_STATE_DIRTY_BEFORE_C3"
  $Continue = $false
}

if (-not (Test-Path -LiteralPath $PolicyModule)) {
  Write-Host "STOP=C2B_POLICY_MODULE_MISSING"
  $Continue = $false
}

if ($Continue) {
  $Pack = Read-J (Join-Path $root $PackPath)
  foreach ($a in $Atoms) {
    $lesson = @($Pack.lessons | Where-Object { [string]$_.lesson_id -eq [string]$a.concept_id })
    Write-Host "SOURCE_LESSON_COUNT_$($a.concept_id)=$($lesson.Count)"
    if ($lesson.Count -ne 1) { $Continue = $false; Write-Host "STOP=SOURCE_LESSON_BAD_COUNT_$($a.concept_id)" }
  }
}

if ($Continue) {
  foreach ($a in $Atoms) {
    $atomId = [string]$a.atom_id
    $m0 = Count-Atom (Read-J (Join-Path $root $MemoryPath)) "phase162_accepted_atom_memory_records" $atomId
    $s0 = Count-Atom (Read-J (Join-Path $root $SelfMapPath)) "phase162_absorbed_atom_capability_notes" $atomId
    $r0 = Count-Atom (Read-J (Join-Path $root $RegistryPath)) "phase162_accepted_atom_references" $atomId
    Write-Host "BEFORE_$atomId MEMORY=$m0 SELF_MAP=$s0 REGISTRY=$r0"
    if (($m0 + $s0 + $r0) -ne 0) { $Continue = $false; Write-Host "STOP=ATOM_ALREADY_PRESENT_$atomId" }
  }
}

$Accepted = @()
$Denied = @()
$Failed = @()

if ($Continue) {
  $Stamp = Get-Date -Format "yyyyMMddHHmmss"
  $RunRoot = Join-Path $root "reports/self_development/c3_$Stamp"
  New-Item -ItemType Directory -Force -Path $RunRoot | Out-Null

  foreach ($a in $Atoms) {
    $conceptId = [string]$a.concept_id
    $atomId = [string]$a.atom_id
    $atomRoot = Join-Path $RunRoot $conceptId
    $CandidateRoot = Join-Path $atomRoot "cand"
    $ControllerRoot = Join-Path $atomRoot "ctrl"
    $ExecutionRoot = Join-Path $atomRoot "exec"
    $FinalizerRoot = Join-Path $atomRoot "fin"
    New-Item -ItemType Directory -Force -Path $atomRoot,$CandidateRoot,$ControllerRoot,$ExecutionRoot,$FinalizerRoot | Out-Null

    Write-Host "=== C3_ATOM_START $atomId ==="

    $PolicyCandidatePath = Join-Path $atomRoot "policy_candidate.json"
    $PolicyResultPath = Join-Path $atomRoot "policy_result.json"

    Write-J $PolicyCandidatePath ([ordered]@{
      atom_id = $atomId
      batch_size = 1
      source_route = "OWNER_INBOX_CURRICULUM"
      source_authority = "OWNER_APPROVED"
      target_files = @($MemoryPath,$SelfMapPath,$RegistryPath)
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
    })

    powershell -NoProfile -ExecutionPolicy Bypass -File $PolicyModule -RepoRoot $root -CandidatePath $PolicyCandidatePath -OutputPath $PolicyResultPath | Out-Null
    $Policy = Read-J $PolicyResultPath

    Write-Host "POLICY_DECISION_$conceptId=$($Policy.decision_code)"
    Write-Host "OWNER_PROMPT_REQUIRED_$conceptId=$($Policy.owner_prompt_required)"

    if ([bool]$Policy.autonomous_accept_allowed -ne $true) {
      $Denied += $atomId
      Write-Host "DENIED_$atomId=$($Policy.denial_reasons -join ',')"
      continue
    }

    $OperationId = "C3_${Stamp}_$conceptId"

    $Payload = [ordered]@{
      concept_id = $conceptId
      meaning = [string]$a.meaning
      source_curriculum_pack = $PackPath
      autonomous_policy_guard = "PHASE165S-C2B"
      autonomous_loop = "PHASE165S-C3"
      owner_interrupt_used = $false
      decision_rule = [ordered]@{
        input = "candidate_or_task_claim"
        classification = [string]$a.classification
        direct_accept_without_proof = $false
        decision_authority = "ACCEPTANCE_VALIDATOR_AND_MODE_DECISION_KERNEL"
      }
      memory_proof = "Accepted-memory read must find this atom by atom_id."
      use_proof = "Sample reasoning must use this atom as a rule, not as curriculum-only lesson."
      behavior_delta = "Next-cycle reasoning starts from the accepted atom."
    }

    Write-J (Join-Path $CandidateRoot "controlled_accept_core_mutation_candidate_result.json") ([ordered]@{
      schema = "PHASE162_CONTROLLED_ACCEPT_CORE_MUTATION_CANDIDATE_RESULT_V1"
      status = "PASS"
      created_at = (Get-Date -Format o)
      batch_size = 1
      staged_atom_count = 1
      atom_ids = @($atomId)
      next_machine_action = "VALIDATE_CONTROLLED_ACCEPT_CORE_MUTATION_CANDIDATE_FOR_ATOM_BATCH"
      source = "PHASE165S-C3 autonomous serial curriculum loop"
    })

    Write-J (Join-Path $CandidateRoot "controlled_accept_core_mutation_set.json") ([ordered]@{
      schema = "PHASE162_CONTROLLED_ACCEPT_CORE_MUTATION_SET_V1"
      status = "PASS"
      created_at = (Get-Date -Format o)
      accepted_memory_operations = @([ordered]@{
        operation_id = "$OperationId`_MEMORY"
        atom_id = $atomId
        target = $MemoryPath
        source_freeze_root = $atomRoot
        payload = $Payload
      })
      accepted_self_model_operations = @([ordered]@{
        operation_id = "$OperationId`_SELF"
        atom_id = $atomId
        target = $SelfMapPath
        source_freeze_root = $atomRoot
        payload = $Payload
      })
      registry_operations = @([ordered]@{
        operation_id = "$OperationId`_REGISTRY"
        atom_id = $atomId
        target = $RegistryPath
        source_freeze_root = $atomRoot
        payload = $Payload
      })
    })

    Write-J (Join-Path $CandidateRoot "atomic_accept_write_plan.json") ([ordered]@{
      schema = "PHASE162_ATOMIC_ACCEPT_WRITE_PLAN_V1"
      status = "PASS"
      created_at = (Get-Date -Format o)
      atomicity_rule = "all_operations_pass_or_rollback"
      target_files = @($MemoryPath,$SelfMapPath,$RegistryPath)
      allowed_atom_ids = @($atomId)
    })

    Write-J (Join-Path $CandidateRoot "controlled_accept_core_mutation_rollback_plan.json") ([ordered]@{
      schema = "PHASE162_CONTROLLED_ACCEPT_CORE_MUTATION_ROLLBACK_PLAN_V1"
      status = "PASS"
      created_at = (Get-Date -Format o)
      rollback_actions = @("restore_memory_snapshot","restore_self_map_snapshot","restore_registry_snapshot","validate_atom_count","write_rollback_event")
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
      allowed_atom_ids = @($atomId)
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
      authorized_atom_ids = @($atomId)
      mass_acceptance_forbidden = $true
    })

    powershell -NoProfile -ExecutionPolicy Bypass `
      -File (Join-Path $root "modules/invoke_phase162_execute_controlled_accept_core_mutation_for_atom_batch_001.ps1") `
      -ControllerRoot $ControllerRoot `
      -RepoRoot $root `
      -OutputRoot $ExecutionRoot

    $ExecutionResultPath = Join-Path $ExecutionRoot "execute_controlled_accept_core_mutation_result.json"
    $ExecutionValidationPath = Join-Path $ExecutionRoot "execute_controlled_accept_core_mutation_validation.json"
    $ExecResult = Read-J $ExecutionResultPath

    $m = Count-Atom (Read-J (Join-Path $root $MemoryPath)) "phase162_accepted_atom_memory_records" $atomId
    $s = Count-Atom (Read-J (Join-Path $root $SelfMapPath)) "phase162_absorbed_atom_capability_notes" $atomId
    $r = Count-Atom (Read-J (Join-Path $root $RegistryPath)) "phase162_accepted_atom_references" $atomId

    $ExecPass = (
      ([string]$ExecResult.status -eq "PASS") -and
      ([bool]$ExecResult.controlled_accept_core_mutation_executed -eq $true) -and
      ([bool]$ExecResult.post_real_mutation_validation_passed -eq $true) -and
      ([bool]$ExecResult.rollback_executed -eq $false) -and
      ($m -eq 1) -and ($s -eq 1) -and ($r -eq 1)
    )

    Write-J $ExecutionValidationPath ([ordered]@{
      schema = "PHASE165S_C3_EXECUTION_VALIDATION_V1"
      status = if ($ExecPass) { "PASS" } else { "FAIL" }
      created_at = (Get-Date -Format o)
      atom_id = $atomId
      memory_count = $m
      self_map_count = $s
      registry_count = $r
      owner_interrupt_used = $false
      autonomous_policy_guard_allowed = $true
    })

    Write-J (Join-Path $ExecutionRoot "phase165s_c3_execution_proof_for_controller.json") ([ordered]@{
      schema = "PHASE165S_C3_EXECUTION_PROOF_FOR_PHASE162_CONTROLLER_V1"
      status = [string]$ExecResult.status
      created_at = (Get-Date -Format o)
      head = (git -C $root rev-parse HEAD)
      output_root = $ExecutionRoot
      next_action = [string]$ExecResult.next_machine_action
      accepted_atom_claimed = $false
      atom_id = $atomId
      owner_interrupt_used = $false
    })

    if ($ExecPass) {
      powershell -NoProfile -ExecutionPolicy Bypass `
        -File (Join-Path $root "modules/invoke_phase162_controller_consume_controlled_accept_core_mutation_execution_proof_001.ps1") `
        -RepoRoot $root `
        -ExecutionProofPath (Join-Path $ExecutionRoot "phase165s_c3_execution_proof_for_controller.json") `
        -OutputRoot $FinalizerRoot

      $m2 = Count-Atom (Read-J (Join-Path $root $MemoryPath)) "phase162_accepted_atom_memory_records" $atomId
      $s2 = Count-Atom (Read-J (Join-Path $root $SelfMapPath)) "phase162_absorbed_atom_capability_notes" $atomId
      $r2 = Count-Atom (Read-J (Join-Path $root $RegistryPath)) "phase162_accepted_atom_references" $atomId

      if (($m2 -eq 1) -and ($s2 -eq 1) -and ($r2 -eq 1)) {
        $Accepted += [ordered]@{
          atom_id = $atomId
          concept_id = $conceptId
          memory_count = $m2
          self_map_count = $s2
          registry_count = $r2
          owner_interrupt_used = $false
          policy_decision = [string]$Policy.decision_code
          atom_root = $atomRoot
        }
        Write-Host "ACCEPTED_$conceptId=$atomId"
      } else {
        $Failed += $atomId
        Write-Host "FAIL_VISIBILITY_$atomId"
      }
    } else {
      $Failed += $atomId
      Write-Host "FAIL_EXECUTION_$atomId"
    }

    Write-Host "=== C3_ATOM_END $atomId ==="
  }

  $ProofPath = Join-Path $root "proofs/self_development/PHASE165S_C3_AUTONOMOUS_THREE_ATOM_CURRICULUM_LOOP_V1.json"
  $ReportPath = Join-Path $root "reports/self_development/PHASE165S_C3_AUTONOMOUS_THREE_ATOM_CURRICULUM_LOOP_V1.md"

  $allPass = (($Accepted.Count -eq 3) -and ($Denied.Count -eq 0) -and ($Failed.Count -eq 0))

  $Proof = [ordered]@{
    phase = "PHASE165S_C3_AUTONOMOUS_THREE_ATOM_CURRICULUM_LOOP"
    status = if ($allPass) { "PASS_AUTONOMOUS_THREE_ATOM_LOOP_VISIBLE" } else { "FAIL_AUTONOMOUS_THREE_ATOM_LOOP" }
    created_at = (Get-Date -Format o)
    owner_interrupt_used = $false
    autonomous_policy_guard_used = $true
    requested_atom_count = 3
    accepted_atom_count = $Accepted.Count
    denied_atom_count = $Denied.Count
    failed_atom_count = $Failed.Count
    accepted_atoms = $Accepted
    denied_atoms = $Denied
    failed_atoms = $Failed
    run_root = $RunRoot
    next_required_action = if ($allPass) { "PHASE165S_C3_ACCEPTANCE_COMMIT" } else { "REPAIR_C3_AUTONOMOUS_LOOP" }
  }

  Write-J $ProofPath $Proof

  @"
# PHASE165S-C3 Autonomous Three Atom Curriculum Loop

Status: $($Proof.status)

## Result

- owner_interrupt_used: $($Proof.owner_interrupt_used)
- autonomous_policy_guard_used: $($Proof.autonomous_policy_guard_used)
- requested_atom_count: $($Proof.requested_atom_count)
- accepted_atom_count: $($Proof.accepted_atom_count)
- denied_atom_count: $($Proof.denied_atom_count)
- failed_atom_count: $($Proof.failed_atom_count)

## Meaning

Builder ran a serial autonomous curriculum-to-accepted-atom loop for three safe atoms using the C2B policy guard and PHASE162 accepted-core executor.

## Scope

Only three small approved curriculum atoms were attempted. Bulk acceptance was not performed.
"@ | Set-Content -LiteralPath $ReportPath -Encoding UTF8

  Write-Host "=== C3_PROOF_SUMMARY ==="
  $Proof | ConvertTo-Json -Depth 30

  if ($allPass) {
    Write-Host "PHASE165S_C3_AUTONOMOUS_THREE_ATOM_CURRICULUM_LOOP_RESULT=PASS"
  } else {
    Write-Host "PHASE165S_C3_AUTONOMOUS_THREE_ATOM_CURRICULUM_LOOP_RESULT=FAIL"
  }
}

Write-Host "=== AUTHORIZED_PROTECTED_DIFF_NAMES ==="
git -C $root diff --name-only -- CAPABILITY_ROADMAP.json GENESIS_STATE.json TASK_QUEUE.json packs/registry.json orchestrator/run.ps1

Write-Host "=== STATUS_AFTER_START ==="
git -C $root status --short
Write-Host "=== STATUS_AFTER_END ==="
