param(
  [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path,
  [string]$ReportRoot = ''
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

function Ensure-Dir {
  param([string]$Path)
  if ($Path -and -not (Test-Path -LiteralPath $Path)) {
    New-Item -ItemType Directory -Force -Path $Path | Out-Null
  }
}

function Write-J {
  param([string]$Path, [object]$Object)
  Ensure-Dir (Split-Path -Parent $Path)
  $Object | ConvertTo-Json -Depth 100 | Set-Content -LiteralPath $Path -Encoding UTF8
}

function Read-J {
  param([string]$Path)
  if (-not (Test-Path -LiteralPath $Path)) { throw "MISSING_FILE=$Path" }
  return Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json
}

function Count-Atom {
  param($Root, [string]$Property, [string]$AtomId)
  if ($null -eq $Root -or -not ($Root.PSObject.Properties.Name -contains $Property)) { return 0 }
  return @($Root.$Property | Where-Object { [string]$_.atom_id -eq $AtomId }).Count
}

function New-R4Package {
  param(
    [string]$PackageRoot,
    [string[]]$AtomIds,
    [string]$FixtureRoot
  )

  $candidateRoot = Join-Path $PackageRoot 'cand'
  $controllerRoot = Join-Path $PackageRoot 'ctrl'
  $executionRoot = Join-Path $PackageRoot 'exec'
  Ensure-Dir $candidateRoot
  Ensure-Dir $controllerRoot
  Ensure-Dir $executionRoot

  $memoryPath = 'reports/self_development/accepted_change_memory_snapshot.json'
  $selfMapPath = 'reports/self_development/SELF_MODEL_ACTIVE_MAP.json'
  $registryPath = 'packs/registry.json'
  $memoryOps = @()
  $selfOps = @()
  $registryOps = @()

  foreach ($atomId in $AtomIds) {
    $safeId = $atomId -replace '[^A-Za-z0-9]', '_'
    $payload = [ordered]@{
      candidate_id = "R4_02_$safeId"
      concept_id = "r4_02.$safeId"
      meaning = "R4-02 fixture atom $atomId"
      atom_type = "fixture_atom"
      source = "R4_02_ISOLATED_FIXTURE"
      autonomous_loop = "PHASE165S-D2B-R4-FIXTURE"
    }
    $memoryOps += [ordered]@{
      operation_id = "R4_02_${safeId}_MEMORY"
      atom_id = $atomId
      target = $memoryPath
      source_freeze_root = $PackageRoot
      payload = $payload
    }
    $selfOps += [ordered]@{
      operation_id = "R4_02_${safeId}_SELF"
      atom_id = $atomId
      target = $selfMapPath
      source_freeze_root = $PackageRoot
      payload = $payload
    }
    $registryOps += [ordered]@{
      operation_id = "R4_02_${safeId}_REGISTRY"
      atom_id = $atomId
      target = $registryPath
      source_freeze_root = $PackageRoot
      payload = $payload
    }
  }

  Write-J (Join-Path $candidateRoot 'controlled_accept_core_mutation_candidate_result.json') ([ordered]@{
    schema = 'PHASE162_CONTROLLED_ACCEPT_CORE_MUTATION_CANDIDATE_RESULT_V1'
    status = 'PASS'
    created_at = (Get-Date -Format o)
    batch_size = $AtomIds.Count
    staged_atom_count = $AtomIds.Count
    atom_ids = $AtomIds
    next_machine_action = 'VALIDATE_CONTROLLED_ACCEPT_CORE_MUTATION_CANDIDATE_FOR_ATOM_BATCH'
    source = 'R4-02 isolated fixture'
  })
  Write-J (Join-Path $candidateRoot 'controlled_accept_core_mutation_set.json') ([ordered]@{
    schema = 'PHASE162_CONTROLLED_ACCEPT_CORE_MUTATION_SET_V1'
    status = 'PASS'
    created_at = (Get-Date -Format o)
    accepted_memory_operations = $memoryOps
    accepted_self_model_operations = $selfOps
    registry_operations = $registryOps
  })
  Write-J (Join-Path $candidateRoot 'atomic_accept_write_plan.json') ([ordered]@{
    schema = 'PHASE162_ATOMIC_ACCEPT_WRITE_PLAN_V1'
    status = 'PASS'
    created_at = (Get-Date -Format o)
    atomicity_rule = 'all_operations_pass_or_rollback'
    target_files = @($memoryPath, $selfMapPath, $registryPath)
    allowed_atom_ids = $AtomIds
  })
  Write-J (Join-Path $candidateRoot 'controlled_accept_core_mutation_rollback_plan.json') ([ordered]@{
    schema = 'PHASE162_CONTROLLED_ACCEPT_CORE_MUTATION_ROLLBACK_PLAN_V1'
    status = 'PASS'
    created_at = (Get-Date -Format o)
    rollback_actions = @('restore_memory_snapshot', 'restore_self_map_snapshot', 'restore_registry_snapshot', 'validate_atom_count', 'write_rollback_event')
  })
  Write-J (Join-Path $candidateRoot 'post_mutation_validation_binding.json') ([ordered]@{
    schema = 'PHASE162_POST_MUTATION_VALIDATION_BINDING_V1'
    status = 'PASS'
    created_at = (Get-Date -Format o)
    bound_to_mutation_set = 'controlled_accept_core_mutation_set.json'
    bound_to_atomic_write_plan = 'atomic_accept_write_plan.json'
  })
  Write-J (Join-Path $controllerRoot 'controller_consume_controlled_accept_core_mutation_dry_run_batch_result.json') ([ordered]@{
    schema = 'PHASE162_CONTROLLER_CONSUME_CONTROLLED_ACCEPT_CORE_MUTATION_DRY_RUN_BATCH_RESULT_V1'
    status = 'PASS'
    created_at = (Get-Date -Format o)
    next_machine_action = 'EXECUTE_CONTROLLED_ACCEPT_CORE_MUTATION_FOR_ATOM_BATCH'
    execution_authorization_status = 'AUTHORIZED_ONE_SHOT_CONTROLLED_ACCEPT_CORE_MUTATION'
    candidate_root = $candidateRoot
    authorization_source = 'R4-02 isolated fixture'
    owner_interrupt_used = $false
  })
  Write-J (Join-Path $controllerRoot 'controller_consume_controlled_accept_core_mutation_dry_run_batch_validation.json') ([ordered]@{
    schema = 'PHASE162_CONTROLLER_CONSUME_CONTROLLED_ACCEPT_CORE_MUTATION_DRY_RUN_BATCH_VALIDATION_V1'
    status = 'PASS'
    created_at = (Get-Date -Format o)
    next_machine_action = 'EXECUTE_CONTROLLED_ACCEPT_CORE_MUTATION_FOR_ATOM_BATCH'
    exact_atom_scope = $true
    allowed_atom_ids = $AtomIds
  })
  Write-J (Join-Path $controllerRoot 'one_shot_controlled_accept_core_mutation_execution_authorization_for_atom_batch.json') ([ordered]@{
    schema = 'PHASE162_ONE_SHOT_CONTROLLED_ACCEPT_CORE_MUTATION_EXECUTION_AUTHORIZATION_FOR_ATOM_BATCH_V1'
    status = 'AUTHORIZED'
    created_at = (Get-Date -Format o)
    authorization_scope = 'ONE_SHOT_ACCEPTED_CORE_WRITE_WITH_ATOMIC_PLAN_AND_ROLLBACK'
    candidate_root = $candidateRoot
    authorization_source = 'R4-02 isolated fixture'
    owner_interrupt_used = $false
    autonomous_policy_guard_allowed = $true
    authorized_atom_ids = $AtomIds
    mass_acceptance_forbidden = $true
  })

  return [pscustomobject]@{
    candidate_root = $candidateRoot
    controller_root = $controllerRoot
    execution_root = $executionRoot
  }
}

function Get-FixtureCounts {
  param([string]$FixtureRoot, [string[]]$AtomIds)
  $memory = Read-J (Join-Path $FixtureRoot 'reports/self_development/accepted_change_memory_snapshot.json')
  $selfMap = Read-J (Join-Path $FixtureRoot 'reports/self_development/SELF_MODEL_ACTIVE_MAP.json')
  $registry = Read-J (Join-Path $FixtureRoot 'packs/registry.json')
  $rows = @()
  foreach ($atomId in $AtomIds) {
    $rows += [ordered]@{
      atom_id = $atomId
      memory_count = Count-Atom $memory 'phase162_accepted_atom_memory_records' $atomId
      self_model_count = Count-Atom $selfMap 'phase162_absorbed_atom_capability_notes' $atomId
      registry_count = Count-Atom $registry 'phase162_accepted_atom_references' $atomId
    }
  }
  return $rows
}

function Assert-AtomsExactlyOnce {
  param([object[]]$Counts, [string]$Label)
  $bad = @($Counts | Where-Object {
    [int]$_.memory_count -ne 1 -or [int]$_.self_model_count -ne 1 -or [int]$_.registry_count -ne 1
  })
  if ($bad.Count -gt 0) {
    throw "$Label counts failed: $($bad.atom_id -join ',')"
  }
}

$sourceRoot = (Resolve-Path $RepoRoot).Path
if ([string]::IsNullOrWhiteSpace($ReportRoot)) {
  $ReportRoot = Join-Path $sourceRoot ("reports/lab_r4_d2b_r4_02_batch_executor_{0}" -f (Get-Date -Format 'yyyyMMdd_HHmmss'))
}
$reportFull = if ([System.IO.Path]::IsPathRooted($ReportRoot)) { [System.IO.Path]::GetFullPath($ReportRoot) } else { [System.IO.Path]::GetFullPath((Join-Path $sourceRoot $ReportRoot)) }
$fixtureRoot = Join-Path $reportFull 'fixture_repo'
Ensure-Dir (Join-Path $fixtureRoot 'reports/self_development')
Ensure-Dir (Join-Path $fixtureRoot 'packs')

Write-J (Join-Path $fixtureRoot 'reports/self_development/accepted_change_memory_snapshot.json') ([ordered]@{
  phase162_accepted_atom_memory_records = @()
})
Write-J (Join-Path $fixtureRoot 'reports/self_development/SELF_MODEL_ACTIVE_MAP.json') ([ordered]@{
  phase162_absorbed_atom_capability_notes = @()
})
Write-J (Join-Path $fixtureRoot 'packs/registry.json') ([ordered]@{
  phase162_accepted_atom_references = @()
})

$executor = Join-Path $sourceRoot 'modules/invoke_phase162_execute_controlled_accept_core_mutation_for_atom_batch_001.ps1'
$executorValidator = Join-Path $sourceRoot 'validators/validate_phase162_execute_controlled_accept_core_mutation_for_atom_batch_v1.ps1'

$batchAtoms = 1..5 | ForEach-Object { "r4.fixture.batch.atom.$_.v1" }
$batchPackage = New-R4Package -PackageRoot (Join-Path $reportFull 'batch_package') -AtomIds $batchAtoms -FixtureRoot $fixtureRoot
& $executor -ControllerRoot $batchPackage.controller_root -RepoRoot $fixtureRoot -OutputRoot $batchPackage.execution_root | Out-Null
& $executorValidator -OutputRoot $batchPackage.execution_root | Out-Null
$batchResult = Read-J (Join-Path $batchPackage.execution_root 'execute_controlled_accept_core_mutation_result.json')
$batchCounts = Get-FixtureCounts -FixtureRoot $fixtureRoot -AtomIds $batchAtoms
Assert-AtomsExactlyOnce -Counts $batchCounts -Label 'batch'

$duplicatePackage = New-R4Package -PackageRoot (Join-Path $reportFull 'duplicate_package') -AtomIds $batchAtoms -FixtureRoot $fixtureRoot
& $executor -ControllerRoot $duplicatePackage.controller_root -RepoRoot $fixtureRoot -OutputRoot $duplicatePackage.execution_root | Out-Null
$duplicateResult = Read-J (Join-Path $duplicatePackage.execution_root 'execute_controlled_accept_core_mutation_result.json')
$duplicateCounts = Get-FixtureCounts -FixtureRoot $fixtureRoot -AtomIds $batchAtoms
Assert-AtomsExactlyOnce -Counts $duplicateCounts -Label 'duplicate rollback'
if ([string]$duplicateResult.status -ne 'ROLLED_BACK' -or @($duplicateResult.duplicate_atom_ids).Count -ne $batchAtoms.Count) {
  throw "DUPLICATE_BATCH_NOT_BLOCKED status=$($duplicateResult.status)"
}

$singleAtom = @('r4.fixture.single.atom.v1')
$singlePackage = New-R4Package -PackageRoot (Join-Path $reportFull 'single_package') -AtomIds $singleAtom -FixtureRoot $fixtureRoot
& $executor -ControllerRoot $singlePackage.controller_root -RepoRoot $fixtureRoot -OutputRoot $singlePackage.execution_root | Out-Null
& $executorValidator -OutputRoot $singlePackage.execution_root | Out-Null
$singleResult = Read-J (Join-Path $singlePackage.execution_root 'execute_controlled_accept_core_mutation_result.json')
$singleCounts = Get-FixtureCounts -FixtureRoot $fixtureRoot -AtomIds $singleAtom
Assert-AtomsExactlyOnce -Counts $singleCounts -Label 'single'

$smokePass = (
  [string]$batchResult.status -eq 'PASS' -and
  [int]$batchResult.staged_atom_count -eq 5 -and
  [bool]$batchResult.optimized_batch_write -eq $true -and
  [string]$duplicateResult.status -eq 'ROLLED_BACK' -and
  [string]$singleResult.status -eq 'PASS'
)
if (-not $smokePass) { throw 'R4_02_SMOKE_ASSERTION_FAILED' }

$proof = [ordered]@{
  status = 'PASS'
  created_at = (Get-Date -Format o)
  fixture_root = $fixtureRoot
  batch_size_tested = 5
  batch_result_status = [string]$batchResult.status
  batch_atom_validation = @($batchResult.atom_validation)
  duplicate_test_result = [ordered]@{
    status = [string]$duplicateResult.status
    rollback_executed = [bool]$duplicateResult.rollback_executed
    duplicate_atom_ids = @($duplicateResult.duplicate_atom_ids)
    fixture_counts_after_duplicate = $duplicateCounts
  }
  single_atom_test_result = [ordered]@{
    status = [string]$singleResult.status
    staged_atom_count = [int]$singleResult.staged_atom_count
    atom_validation = @($singleResult.atom_validation)
  }
  real_accepted_surfaces_used = $false
}
Write-J (Join-Path $reportFull 'R4_02_BATCH_EXECUTOR_SMOKE_PROOF.json') $proof

@"
# R4-02 Batch Executor Smoke

Status: PASS

- fixture_root: $fixtureRoot
- batch_size_tested: 5
- batch_status: $($batchResult.status)
- duplicate_status: $($duplicateResult.status)
- duplicate_rollback_executed: $($duplicateResult.rollback_executed)
- single_atom_status: $($singleResult.status)

The smoke test used only the isolated fixture repo under the R4-02 report directory.
"@ | Set-Content -LiteralPath (Join-Path $reportFull 'R4_02_BATCH_EXECUTOR_SMOKE_REPORT.md') -Encoding UTF8

Write-Host 'R4_02_BATCH_EXECUTOR_SMOKE_RESULT=PASS'
Write-Host "REPORT_ROOT=$reportFull"
Write-Host "FIXTURE_ROOT=$fixtureRoot"
Write-Host 'BATCH_SIZE_TESTED=5'
Write-Host "DUPLICATE_TEST_RESULT=$($duplicateResult.status)"
