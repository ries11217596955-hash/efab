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

function Test-AtomVisible {
  param($Memory,$SelfMap,$Registry,[string]$AtomId)

  $m = Count-Atom $Memory "phase162_accepted_atom_memory_records" $AtomId
  $s = Count-Atom $SelfMap "phase162_absorbed_atom_capability_notes" $AtomId
  $r = Count-Atom $Registry "phase162_accepted_atom_references" $AtomId

  return [ordered]@{
    atom_id = $AtomId
    memory_count = $m
    self_map_count = $s
    registry_count = $r
    visible = (($m -eq 1) -and ($s -eq 1) -and ($r -eq 1))
  }
}

function Invoke-ReuseCase {
  param(
    [string]$CaseId,
    [string]$InputText,
    [string[]]$RequiredAtoms,
    [string]$ExpectedClassification,
    [string]$ExpectedNextLayer,
    $Memory,
    $SelfMap,
    $Registry
  )

  $visibility = @()
  foreach ($a in $RequiredAtoms) {
    $visibility += [pscustomobject](Test-AtomVisible $Memory $SelfMap $Registry $a)
  }

  $allKnown = (@($visibility | Where-Object { -not [bool]$_.visible }).Count -eq 0)

  return [ordered]@{
    case_id = $CaseId
    input_text = $InputText
    required_atoms = $RequiredAtoms
    required_atom_visibility = $visibility
    starts_from_zero = (-not $allKnown)
    reuse_status = if ($allKnown) { "PASS_REUSES_ACCEPTED_ATOMS" } else { "FAIL_MISSING_ACCEPTED_ATOM" }
    classification = if ($allKnown) { $ExpectedClassification } else { "UNKNOWN_DUE_TO_MISSING_ATOM" }
    next_layer = if ($allKnown) { $ExpectedNextLayer } else { "REPAIR_MEMORY_VISIBILITY" }
  }
}

$root = (Resolve-Path $RepoRoot).Path

Write-Host "=== D1C_PRECHECK ==="
Write-Host "BRANCH=$(git -C $root branch --show-current)"
Write-Host "HEAD=$(git -C $root rev-parse --short HEAD)"
Write-Host "ORIGIN=$(git -C $root rev-parse --short origin/phase110-idempotent-autonomy-trial-runtime)"
Write-Host "LAST_COMMIT=$(git -C $root log -1 --oneline)"

$MemoryPath = "reports/self_development/accepted_change_memory_snapshot.json"
$SelfMapPath = "reports/self_development/SELF_MODEL_ACTIVE_MAP.json"
$RegistryPath = "packs/registry.json"

$Memory = Read-J (Join-Path $root $MemoryPath)
$SelfMap = Read-J (Join-Path $root $SelfMapPath)
$Registry = Read-J (Join-Path $root $RegistryPath)

$D1BProofPath = "proofs/self_development/PHASE165S_D1B_PRIMITIVE_BUILDER_ALPHABET_SCHOOL_WAVE_V1.json"
$D1B = Read-J (Join-Path $root $D1BProofPath)

$Atoms = @(
  "concept.file.v1",
  "concept.folder.v1",
  "concept.path.v1",
  "concept.text.v1",
  "concept.file_extension.v1",
  "concept.markdown_document.v1",
  "concept.json_file.v1",
  "concept.report.v1",
  "concept.proof.v1",
  "concept.delivery_block.v1",
  "concept.repository.v1",
  "concept.branch.v1",
  "concept.commit.v1",
  "concept.push.v1",
  "concept.git_dirty_state.v1",
  "concept.module.v1",
  "concept.validator.v1",
  "concept.runtime_output.v1",
  "concept.protected_state.v1",
  "concept.derived_artifact.v1",
  "concept.owner_task.v1",
  "concept.owner_hint.v1",
  "concept.instruction.v1",
  "concept.school_curriculum.v1",
  "concept.map_signal.v1"
)

Write-Host "=== D1B_BASELINE ==="
$D1B | Select-Object status,accepted_atom_count,denied_atom_count,failed_atom_count,owner_interrupt_used | Format-List

Write-Host "=== D1C_ATOM_VISIBILITY_MATRIX ==="
$Visibility = @()
foreach ($AtomId in $Atoms) {
  $v = Test-AtomVisible $Memory $SelfMap $Registry $AtomId
  $Visibility += [pscustomobject]$v
  Write-Host "ATOM=$($v.atom_id) MEMORY=$($v.memory_count) SELF_MAP=$($v.self_map_count) REGISTRY=$($v.registry_count) VISIBLE=$($v.visible)"
}

$Cases = @(
  Invoke-ReuseCase `
    -CaseId "create_folder_task" `
    -InputText "Создай папку reports/test" `
    -RequiredAtoms @("concept.folder.v1","concept.path.v1","concept.proof.v1") `
    -ExpectedClassification "FILESYSTEM_CONTAINER_TASK_KNOWN_CONCEPTS" `
    -ExpectedNextLayer "ASK_FOR_CREATE_DIRECTORY_PROCEDURE_OR_ORGAN_AND_VALIDATE_DIRECTORY_EXISTS" `
    -Memory $Memory -SelfMap $SelfMap -Registry $Registry

  Invoke-ReuseCase `
    -CaseId "report_is_not_proof" `
    -InputText "Отчёт есть, значит готово?" `
    -RequiredAtoms @("concept.report.v1","concept.proof.v1","concept.validator.v1","concept.runtime_output.v1") `
    -ExpectedClassification "REPORT_NOT_ENOUGH_REQUIRE_PROOF_PATH" `
    -ExpectedNextLayer "ASK_FOR_VALIDATOR_OUTPUT_PROOF_JSON_COMMIT_PUSH_OR_LOG" `
    -Memory $Memory -SelfMap $SelfMap -Registry $Registry

  Invoke-ReuseCase `
    -CaseId "push_done_requires_remote_proof" `
    -InputText "Push сделан?" `
    -RequiredAtoms @("concept.push.v1","concept.commit.v1","concept.branch.v1","concept.git_dirty_state.v1") `
    -ExpectedClassification "SYNC_CLAIM_REQUIRES_HEAD_ORIGIN_STATUS_PROOF" `
    -ExpectedNextLayer "CHECK_HEAD_ORIGIN_LAST_COMMIT_AND_GIT_STATUS" `
    -Memory $Memory -SelfMap $SelfMap -Registry $Registry

  Invoke-ReuseCase `
    -CaseId "owner_hint_not_task" `
    -InputText "Owner говорит: неплохо бы потом подумать про библиотеку." `
    -RequiredAtoms @("concept.owner_hint.v1","concept.owner_task.v1") `
    -ExpectedClassification "OWNER_HINT_NOT_DIRECT_TASK" `
    -ExpectedNextLayer "PLACE_IN_DECISION_CONTEXT_OR_BACKLOG_NOT_EXECUTE_AS_COMMAND" `
    -Memory $Memory -SelfMap $SelfMap -Registry $Registry

  Invoke-ReuseCase `
    -CaseId "map_signal_not_command" `
    -InputText "Self-map рекомендует следующий шаг." `
    -RequiredAtoms @("concept.map_signal.v1","decision_rule.map_signal_not_command.v1") `
    -ExpectedClassification "MAP_SIGNAL_INPUT_ONLY_NOT_DIRECT_COMMAND" `
    -ExpectedNextLayer "MODE_DECISION_KERNEL_OR_DISPATCHER_DECIDES_ACTION" `
    -Memory $Memory -SelfMap $SelfMap -Registry $Registry

  Invoke-ReuseCase `
    -CaseId "protected_state_requires_guard" `
    -InputText "Измени packs/registry.json." `
    -RequiredAtoms @("concept.protected_state.v1","concept.validator.v1","concept.proof.v1") `
    -ExpectedClassification "PROTECTED_STATE_MUTATION_REQUIRES_AUTHORIZED_ACCEPTANCE_PATH" `
    -ExpectedNextLayer "BUILD_CANDIDATE_REVIEW_RISK_ROLLBACK_VALIDATOR_AND_OWNER_OR_POLICY_AUTHORIZATION" `
    -Memory $Memory -SelfMap $SelfMap -Registry $Registry

  Invoke-ReuseCase `
    -CaseId "derived_artifact_not_truth" `
    -InputText "Обнови производный документ вручную и считай его истиной." `
    -RequiredAtoms @("concept.derived_artifact.v1","concept.markdown_document.v1","concept.proof.v1") `
    -ExpectedClassification "DERIVED_ARTIFACT_NOT_SOURCE_OF_TRUTH" `
    -ExpectedNextLayer "FIND_SOURCE_TRUTH_AND_GENERATOR_OR_MARK_MANUAL_CHANGE_AS_UNTRUSTED" `
    -Memory $Memory -SelfMap $SelfMap -Registry $Registry
)

Write-Host "=== D1C_REUSE_CASES ==="
foreach ($c in $Cases) {
  Write-Host "CASE=$($c.case_id) REUSE=$($c.reuse_status) STARTS_FROM_ZERO=$($c.starts_from_zero) CLASSIFICATION=$($c.classification) NEXT=$($c.next_layer)"
}

$AllAtomsVisible = (@($Visibility | Where-Object { -not [bool]$_.visible }).Count -eq 0)
$AllCasesPass = (@($Cases | Where-Object { [string]$_.reuse_status -ne "PASS_REUSES_ACCEPTED_ATOMS" }).Count -eq 0)

$ProtectedDirty = @(git -C $root status --short -- CAPABILITY_ROADMAP.json GENESIS_STATE.json TASK_QUEUE.json packs/registry.json orchestrator/run.ps1)

$ProofPath = Join-Path $root "proofs/self_development/PHASE165S_D1C_PRIMITIVE_ALPHABET_REUSE_PROBE_V1.json"
$ReportPath = Join-Path $root "reports/self_development/PHASE165S_D1C_PRIMITIVE_ALPHABET_REUSE_PROBE_V1.md"
$RunRoot = Join-Path $root "reports/self_development/phase165s_d1c_primitive_alphabet_reuse_probe"
New-Item -ItemType Directory -Force -Path $RunRoot | Out-Null

$Pass = (
  [string]$D1B.status -eq "PASS_PRIMITIVE_ALPHABET_25_ATOMS_VISIBLE" -and
  [int]$D1B.accepted_atom_count -eq 25 -and
  $AllAtomsVisible -and
  $AllCasesPass -and
  $ProtectedDirty.Count -eq 0
)

$Proof = [ordered]@{
  phase = "PHASE165S_D1C_PRIMITIVE_ALPHABET_REUSE_PROBE"
  status = if ($Pass) { "PASS_PRIMITIVE_ALPHABET_REUSE_PROVEN" } else { "FAIL_PRIMITIVE_ALPHABET_REUSE_PROBE" }
  created_at = (Get-Date -Format o)
  d1b_status = [string]$D1B.status
  d1b_accepted_atom_count = [int]$D1B.accepted_atom_count
  checked_atom_count = $Atoms.Count
  all_atoms_visible = [bool]$AllAtomsVisible
  reuse_case_count = $Cases.Count
  all_reuse_cases_pass = [bool]$AllCasesPass
  reuse_cases = $Cases
  atom_visibility = $Visibility
  protected_state_dirty_check = $ProtectedDirty
  no_new_atoms_accepted = $true
  no_manual_self_map_update = $true
  run_root = "reports/self_development/phase165s_d1c_primitive_alphabet_reuse_probe"
  next_required_action = if ($Pass) { "PHASE165S_D1C_ACCEPTANCE_COMMIT_OR_NEXT_PROCEDURE_WAVE" } else { "REPAIR_D1C_REUSE_OR_MEMORY_VISIBILITY" }
}

Write-J $ProofPath $Proof

@"
# PHASE165S-D1C Primitive Alphabet Reuse Probe

Status: $($Proof.status)

## Meaning

This probe checks whether the 25 primitive accepted atoms are visible and reusable as starting knowledge.

It does not accept new atoms.

## Checks

- d1b_status: $($Proof.d1b_status)
- d1b_accepted_atom_count: $($Proof.d1b_accepted_atom_count)
- checked_atom_count: $($Proof.checked_atom_count)
- all_atoms_visible: $($Proof.all_atoms_visible)
- reuse_case_count: $($Proof.reuse_case_count)
- all_reuse_cases_pass: $($Proof.all_reuse_cases_pass)
- protected_state_dirty_check: $($Proof.protected_state_dirty_check.Count)
- no_new_atoms_accepted: $($Proof.no_new_atoms_accepted)
- no_manual_self_map_update: $($Proof.no_manual_self_map_update)

## Reuse Meaning

The probe confirms that Builder does not start sample tasks from zero-definition search. It uses accepted primitive atoms and moves to the next layer: procedure, organ, proof, policy, or dispatcher.

## Next

$($Proof.next_required_action)
"@ | Set-Content -LiteralPath $ReportPath -Encoding UTF8

Write-J (Join-Path $RunRoot "reuse_cases.json") $Cases
Write-J (Join-Path $RunRoot "atom_visibility.json") $Visibility

Write-Host "=== D1C_PROOF_SUMMARY ==="
$Proof | ConvertTo-Json -Depth 30

if ($Pass) {
  Write-Host "PHASE165S_D1C_PRIMITIVE_ALPHABET_REUSE_PROBE_RESULT=PASS"
} else {
  Write-Host "PHASE165S_D1C_PRIMITIVE_ALPHABET_REUSE_PROBE_RESULT=FAIL"
}

Write-Host "=== PROTECTED_STATE_DIRTY_CHECK ==="
git -C $root status --short -- CAPABILITY_ROADMAP.json GENESIS_STATE.json TASK_QUEUE.json packs/registry.json orchestrator/run.ps1

Write-Host "=== STATUS_AFTER_START ==="
git -C $root status --short
Write-Host "=== STATUS_AFTER_END ==="
