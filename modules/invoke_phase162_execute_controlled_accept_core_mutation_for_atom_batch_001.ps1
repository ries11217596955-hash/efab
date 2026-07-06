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

function Set-Prop {
  param([object]$Obj, [string]$Name, [object]$Value)

  $p = $Obj.PSObject.Properties[$Name]
  if ($null -eq $p) {
    $Obj | Add-Member -MemberType NoteProperty -Name $Name -Value $Value
  } else {
    $Obj.$Name = $Value
  }
}

function Get-ArrayProp {
  param([object]$Obj, [string]$Name)

  $p = $Obj.PSObject.Properties[$Name]
  if ($null -eq $p -or $null -eq $p.Value) { return @() }
  return @($p.Value)
}

function Get-Phase162RecordsFromRoot {
  param($Root, [string]$ArrayProperty)
  if ($Root -is [array]) { return @($Root) }
  return @(Get-ArrayProp -Obj $Root -Name $ArrayProperty)
}

function Add-Phase162RecordsToRoot {
  param($Root, [string]$ArrayProperty, [object[]]$Records)
  if ($root -is [array]) {
    return @(@($Root) + @($Records))
  }
  $existing = @(Get-ArrayProp -Obj $Root -Name $ArrayProperty)
  $updated = @(@($existing) + @($Records))
  Set-Prop -Obj $Root -Name $ArrayProperty -Value ([object[]]$updated)
  return $Root
}

function Count-AtomInRoot {
  param($Root, [string]$ArrayProperty, [string]$AtomId)
  $records = Get-Phase162RecordsFromRoot -Root $Root -ArrayProperty $ArrayProperty
  return @($records | Where-Object { [string]$_.atom_id -eq $AtomId }).Count
}

function Get-DuplicateValues {
  param([string[]]$Values)
  return @($Values | Group-Object | Where-Object { $_.Count -gt 1 } | ForEach-Object { [string]$_.Name })
}

if ([string]::IsNullOrWhiteSpace($OutputRoot)) {
  $stamp = Get-Date -Format "yyyyMMdd_HHmmss"
  $OutputRoot = Join-Path (Split-Path -Parent $ControllerRoot) "PHASE162_EXECUTED_CONTROLLED_ACCEPT_CORE_MUTATION_FOR_ATOM_BATCH_$stamp"
}

New-Item -ItemType Directory -Force -Path $OutputRoot | Out-Null

$controller = Read-Json (Join-Path $ControllerRoot "controller_consume_controlled_accept_core_mutation_dry_run_batch_result.json")
$controllerValidation = Read-Json (Join-Path $ControllerRoot "controller_consume_controlled_accept_core_mutation_dry_run_batch_validation.json")
$authorization = Read-Json (Join-Path $ControllerRoot "one_shot_controlled_accept_core_mutation_execution_authorization_for_atom_batch.json")

$candidateRoot = [string]$authorization.candidate_root
if (-not (Test-Path -LiteralPath $candidateRoot)) { throw "MISSING_CANDIDATE_ROOT=$candidateRoot" }

$candidate = Read-Json (Join-Path $candidateRoot "controlled_accept_core_mutation_candidate_result.json")
$mutationSet = Read-Json (Join-Path $candidateRoot "controlled_accept_core_mutation_set.json")
$writePlan = Read-Json (Join-Path $candidateRoot "atomic_accept_write_plan.json")
$rollbackPlan = Read-Json (Join-Path $candidateRoot "controlled_accept_core_mutation_rollback_plan.json")
$postBinding = Read-Json (Join-Path $candidateRoot "post_mutation_validation_binding.json")

$memoryOps = @($mutationSet.accepted_memory_operations)
$selfModelOps = @($mutationSet.accepted_self_model_operations)
$registryOps = @($mutationSet.registry_operations)

$inputReady = (
  ([string]$controllerValidation.status -eq "PASS") -and
  ([string]$controller.next_machine_action -eq "EXECUTE_CONTROLLED_ACCEPT_CORE_MUTATION_FOR_ATOM_BATCH") -and
  ([string]$controller.execution_authorization_status -eq "AUTHORIZED_ONE_SHOT_CONTROLLED_ACCEPT_CORE_MUTATION") -and
  ([string]$authorization.status -eq "AUTHORIZED") -and
  ([string]$authorization.authorization_scope -eq "ONE_SHOT_ACCEPTED_CORE_WRITE_WITH_ATOMIC_PLAN_AND_ROLLBACK") -and
  ([string]$mutationSet.status -eq "PASS") -and
  ([string]$writePlan.status -eq "PASS") -and
  ([string]$rollbackPlan.status -eq "PASS") -and
  ([string]$postBinding.status -eq "PASS") -and
  ([string]$writePlan.atomicity_rule -eq "all_operations_pass_or_rollback") -and
  ([int]$candidate.staged_atom_count -gt 0) -and
  ($memoryOps.Count -eq [int]$candidate.staged_atom_count) -and
  ($selfModelOps.Count -eq [int]$candidate.staged_atom_count) -and
  ($registryOps.Count -eq [int]$candidate.staged_atom_count)
)

if (-not $inputReady) {
  throw "CONTROLLED_ACCEPT_EXECUTION_INPUT_NOT_READY"
}

$targetFiles = @(
  "reports/self_development/accepted_change_memory_snapshot.json",
  "reports/self_development/SELF_MODEL_ACTIVE_MAP.json",
  "packs/registry.json"
)

$SnapshotRoot = Join-Path $OutputRoot "pre_execution_snapshots"
New-Item -ItemType Directory -Force -Path $SnapshotRoot | Out-Null

$eventsPath = Join-Path $OutputRoot "controlled_accept_core_mutation_execution_events.jsonl"
if (Test-Path -LiteralPath $eventsPath) { Remove-Item -LiteralPath $eventsPath -Force }

Add-Event -Path $eventsPath -Type "CONTROLLED_ACCEPT_EXECUTION_STARTED" -Data ([ordered]@{
  staged_atom_count = [int]$candidate.staged_atom_count
  authorization_scope = [string]$authorization.authorization_scope
  accepted_core_write_allowed = $true
})

$before = [ordered]@{}
foreach ($rel in $targetFiles) {
  $source = Join-Path $RepoRoot $rel
  $safe = ($rel -replace "[\\/]", "__")
  $snapshot = Join-Path $SnapshotRoot $safe

  if (Test-Path -LiteralPath $source) {
    Copy-Item -LiteralPath $source -Destination $snapshot -Force
  } else {
    "" | Set-Content -Path $snapshot -Encoding UTF8
  }

  $before[$rel] = Get-PathFingerprint -Path $source
}

Write-Json -Path (Join-Path $OutputRoot "pre_execution_fingerprints.json") -Object $before

$rollbackExecuted = $false
$postValidationPassed = $false
$executionPassed = $false
$failureMessage = ""
$atomValidation = @()
$duplicateAtomIds = @()
$withinBatchDuplicateAtomIds = @()
$optimizedBatchWrite = $false
$rollbackRequiredForFailure = $true

try {
  $batchAtomIds = @($memoryOps | ForEach-Object { [string]$_.atom_id })
  $withinBatchDuplicateAtomIds = @(Get-DuplicateValues -Values $batchAtomIds)
  if ($withinBatchDuplicateAtomIds.Count -gt 0) {
    $rollbackRequiredForFailure = $false
    throw "WITHIN_BATCH_DUPLICATE_ATOM_ID=$($withinBatchDuplicateAtomIds -join ',')"
  }

  for ($i = 0; $i -lt $batchAtomIds.Count; $i += 1) {
    if ([string]$selfModelOps[$i].atom_id -ne $batchAtomIds[$i] -or [string]$registryOps[$i].atom_id -ne $batchAtomIds[$i]) {
      throw "BATCH_OPERATION_ATOM_ID_MISMATCH_INDEX=$i"
    }
  }

  $authorizedAtomIds = @($authorization.authorized_atom_ids | ForEach-Object { [string]$_ })
  $candidateAtomIds = @($candidate.atom_ids | ForEach-Object { [string]$_ })
  $unauthorizedBatchAtoms = @($batchAtomIds | Where-Object { $authorizedAtomIds -notcontains $_ -or $candidateAtomIds -notcontains $_ })
  if ($unauthorizedBatchAtoms.Count -gt 0 -or $authorizedAtomIds.Count -ne $batchAtomIds.Count -or $candidateAtomIds.Count -ne $batchAtomIds.Count) {
    throw "BATCH_ATOM_SCOPE_MISMATCH=$($unauthorizedBatchAtoms -join ',')"
  }

  $memoryTargetRel = [string]$memoryOps[0].target
  $selfTargetRel = [string]$selfModelOps[0].target
  $registryTargetRel = [string]$registryOps[0].target
  if (@($memoryOps | Where-Object { [string]$_.target -ne $memoryTargetRel }).Count -gt 0 -or
      @($selfModelOps | Where-Object { [string]$_.target -ne $selfTargetRel }).Count -gt 0 -or
      @($registryOps | Where-Object { [string]$_.target -ne $registryTargetRel }).Count -gt 0) {
    throw "BATCH_TARGET_FILE_MISMATCH"
  }

  $memoryTarget = Join-Path $RepoRoot $memoryTargetRel
  $selfTarget = Join-Path $RepoRoot $selfTargetRel
  $registryTarget = Join-Path $RepoRoot $registryTargetRel

  $memoryRoot = Read-Json $memoryTarget
  $selfRoot = Read-Json $selfTarget
  $registryRoot = Read-Json $registryTarget

  $memoryExisting = Get-Phase162RecordsFromRoot -Root $memoryRoot -ArrayProperty "phase162_accepted_atom_memory_records"
  $selfExisting = Get-Phase162RecordsFromRoot -Root $selfRoot -ArrayProperty "phase162_absorbed_atom_capability_notes"
  $registryExisting = Get-Phase162RecordsFromRoot -Root $registryRoot -ArrayProperty "phase162_accepted_atom_references"
  $duplicateAtomIds = @($batchAtomIds | Where-Object {
    $atomId = $_
    @($memoryExisting | Where-Object { [string]$_.atom_id -eq $atomId }).Count -gt 0 -or
    @($selfExisting | Where-Object { [string]$_.atom_id -eq $atomId }).Count -gt 0 -or
    @($registryExisting | Where-Object { [string]$_.atom_id -eq $atomId }).Count -gt 0
  } | Select-Object -Unique)
  if ($duplicateAtomIds.Count -gt 0) {
    throw "DUPLICATE_ATOM_IN_ACCEPTED_SURFACE=$($duplicateAtomIds -join ',')"
  }

  $acceptedAt = Get-Date -Format o
  $memoryRecords = foreach ($op in $memoryOps) {
    [ordered]@{
      schema = "PHASE162_ACCEPTED_ATOM_MEMORY_RECORD_V1"
      atom_id = [string]$op.atom_id
      accepted_at = $acceptedAt
      operation_id = [string]$op.operation_id
      source_freeze_root = [string]$op.source_freeze_root
      payload = $op.payload
      execution_authorization_root = $ControllerRoot
      candidate_root = $candidateRoot
      accepted_core_write = $true
    }
  }

  $selfModelRecords = foreach ($op in $selfModelOps) {
    [ordered]@{
      schema = "PHASE162_ABSORBED_ATOM_SELF_MODEL_NOTE_V1"
      atom_id = [string]$op.atom_id
      accepted_at = $acceptedAt
      operation_id = [string]$op.operation_id
      payload = $op.payload
      execution_authorization_root = $ControllerRoot
      candidate_root = $candidateRoot
      visible_to_next_cycle = $true
      accepted_core_write = $true
    }
  }

  $registryRecords = foreach ($op in $registryOps) {
    [ordered]@{
      schema = "PHASE162_ACCEPTED_ATOM_REGISTRY_REFERENCE_V1"
      atom_id = [string]$op.atom_id
      accepted_at = $acceptedAt
      operation_id = [string]$op.operation_id
      payload = $op.payload
      execution_authorization_root = $ControllerRoot
      candidate_root = $candidateRoot
      accepted_core_write = $true
    }
  }

  $memoryRoot = Add-Phase162RecordsToRoot -Root $memoryRoot -ArrayProperty "phase162_accepted_atom_memory_records" -Records $memoryRecords
  $selfRoot = Add-Phase162RecordsToRoot -Root $selfRoot -ArrayProperty "phase162_absorbed_atom_capability_notes" -Records $selfModelRecords
  $registryRoot = Add-Phase162RecordsToRoot -Root $registryRoot -ArrayProperty "phase162_accepted_atom_references" -Records $registryRecords

  Write-Json -Path $memoryTarget -Object $memoryRoot
  Write-Json -Path $selfTarget -Object $selfRoot
  Write-Json -Path $registryTarget -Object $registryRoot
  $optimizedBatchWrite = $true

  Add-Event -Path $eventsPath -Type "CONTROLLED_ACCEPT_MUTATION_WRITTEN_TO_ACCEPTED_CORE" -Data ([ordered]@{
    memory_operation_count = $memoryOps.Count
    self_model_operation_count = $selfModelOps.Count
    registry_operation_count = $registryOps.Count
    accepted_core_write = $true
    optimized_batch_write = $true
    accepted_surface_write_count = 3
  })

  $postMemoryRoot = Read-Json $memoryTarget
  $postSelfRoot = Read-Json $selfTarget
  $postRegistryRoot = Read-Json $registryTarget

  foreach ($atomId in $batchAtomIds) {
    $atomValidation += [ordered]@{
      atom_id = $atomId
      memory_count = Count-AtomInRoot -Root $postMemoryRoot -ArrayProperty "phase162_accepted_atom_memory_records" -AtomId $atomId
      self_model_count = Count-AtomInRoot -Root $postSelfRoot -ArrayProperty "phase162_absorbed_atom_capability_notes" -AtomId $atomId
      registry_count = Count-AtomInRoot -Root $postRegistryRoot -ArrayProperty "phase162_accepted_atom_references" -AtomId $atomId
    }
  }

  $allAtomsOnce = (
    @($atomValidation | Where-Object {
      ([int]$_.memory_count -eq 1) -and
      ([int]$_.self_model_count -eq 1) -and
      ([int]$_.registry_count -eq 1)
    }).Count -eq $memoryOps.Count
  )

  $postValidationResult = [ordered]@{
    schema = "PHASE162_POST_REAL_MUTATION_VALIDATION_FOR_ATOM_BATCH_V1"
    status = if ($allAtomsOnce) { "PASS" } else { "FAIL" }
    created_at = (Get-Date -Format o)
    expected_atom_count = [int]$candidate.staged_atom_count
    atom_validation = $atomValidation
    accepted_memory_contains_each_atom_once = [bool]$allAtomsOnce
    self_model_contains_each_atom_once = [bool]$allAtomsOnce
    registry_contains_each_atom_once = [bool]$allAtomsOnce
    rollback_plan_available = ($null -ne $rollbackPlan.rollback_actions -and @($rollbackPlan.rollback_actions).Count -ge 5)
    bound_to_mutation_set = ([string]$postBinding.bound_to_mutation_set -eq "controlled_accept_core_mutation_set.json")
    bound_to_atomic_write_plan = ([string]$postBinding.bound_to_atomic_write_plan -eq "atomic_accept_write_plan.json")
    accepted_core_write = $true
    optimized_batch_write = [bool]$optimizedBatchWrite
  }

  $postValidationPassed = (
    ([string]$postValidationResult.status -eq "PASS") -and
    ([bool]$postValidationResult.rollback_plan_available -eq $true) -and
    ([bool]$postValidationResult.bound_to_mutation_set -eq $true) -and
    ([bool]$postValidationResult.bound_to_atomic_write_plan -eq $true)
  )

  Write-Json -Path (Join-Path $OutputRoot "post_real_mutation_validation_result.json") -Object $postValidationResult

  Add-Event -Path $eventsPath -Type "POST_REAL_MUTATION_VALIDATION_COMPLETED" -Data ([ordered]@{
    status = [string]$postValidationResult.status
    post_real_mutation_validation_passed = [bool]$postValidationPassed
  })

  if (-not $postValidationPassed) {
    throw "POST_REAL_MUTATION_VALIDATION_FAILED"
  }

  $executionPassed = $true
}
catch {
  $failureMessage = $_.Exception.Message

  if ($rollbackRequiredForFailure) {
    foreach ($rel in $targetFiles) {
      $safe = ($rel -replace "[\\/]", "__")
      $snapshot = Join-Path $SnapshotRoot $safe
      $target = Join-Path $RepoRoot $rel

      if (Test-Path -LiteralPath $snapshot) {
        Copy-Item -LiteralPath $snapshot -Destination $target -Force
      }
    }

    $rollbackExecuted = $true
  }

  Add-Event -Path $eventsPath -Type "CONTROLLED_ACCEPT_EXECUTION_ROLLED_BACK" -Data ([ordered]@{
    failure = $failureMessage
    rollback_executed = [bool]$rollbackExecuted
    rollback_required = [bool]$rollbackRequiredForFailure
    duplicate_atom_ids = @($duplicateAtomIds)
    within_batch_duplicate_atom_ids = @($withinBatchDuplicateAtomIds)
  })

  $postValidationResult = [ordered]@{
    schema = "PHASE162_POST_REAL_MUTATION_VALIDATION_FOR_ATOM_BATCH_V1"
    status = "FAIL"
    created_at = (Get-Date -Format o)
    expected_atom_count = [int]$candidate.staged_atom_count
    atom_validation = $atomValidation
    accepted_memory_contains_each_atom_once = $false
    self_model_contains_each_atom_once = $false
    registry_contains_each_atom_once = $false
    rollback_plan_available = ($null -ne $rollbackPlan.rollback_actions -and @($rollbackPlan.rollback_actions).Count -ge 5)
    bound_to_mutation_set = ([string]$postBinding.bound_to_mutation_set -eq "controlled_accept_core_mutation_set.json")
    bound_to_atomic_write_plan = ([string]$postBinding.bound_to_atomic_write_plan -eq "atomic_accept_write_plan.json")
    accepted_core_write = $false
    optimized_batch_write = [bool]$optimizedBatchWrite
    failure_message = $failureMessage
    duplicate_atom_ids = @($duplicateAtomIds)
    within_batch_duplicate_atom_ids = @($withinBatchDuplicateAtomIds)
  }
  Write-Json -Path (Join-Path $OutputRoot "post_real_mutation_validation_result.json") -Object $postValidationResult
}

$after = [ordered]@{}
foreach ($rel in $targetFiles) {
  $after[$rel] = Get-PathFingerprint -Path (Join-Path $RepoRoot $rel)
}

$eventCount = @((Get-Content -LiteralPath $eventsPath)).Count

$result = [ordered]@{
  schema = "PHASE162_EXECUTE_CONTROLLED_ACCEPT_CORE_MUTATION_FOR_ATOM_BATCH_RESULT_V1"
  status = if ($executionPassed) { "PASS" } elseif ($rollbackExecuted) { "ROLLED_BACK" } else { "FAIL" }
  created_at = (Get-Date -Format o)
  controller_root = $ControllerRoot
  candidate_root = $candidateRoot
  batch_size = [int]$candidate.batch_size
  staged_atom_count = [int]$candidate.staged_atom_count
  controlled_accept_core_mutation_executed = [bool]$executionPassed
  post_real_mutation_validation_passed = [bool]$postValidationPassed
  rollback_executed = [bool]$rollbackExecuted
  rollback_required = (-not $executionPassed)
  failure_message = $failureMessage
  event_count = [int]$eventCount
  before_fingerprints = $before
  after_fingerprints = $after
  atom_validation = $atomValidation
  duplicate_atom_ids = @($duplicateAtomIds)
  within_batch_duplicate_atom_ids = @($withinBatchDuplicateAtomIds)
  optimized_batch_write = [bool]$optimizedBatchWrite
  accepted_surface_write_count = if ($executionPassed) { 3 } else { 0 }
  accepted_core_write_executed = [bool]$executionPassed
  accepted_atom_claimed = $false
  accepted_memory_mutated = [bool]$executionPassed
  accepted_self_model_mutated = [bool]$executionPassed
  registry_mutated = [bool]$executionPassed
  final_accept_ready = [bool]$executionPassed
  machine_decision = if ($executionPassed) { "CONTROLLED_ACCEPT_CORE_MUTATION_EXECUTED_PENDING_CONTROLLER_FINALIZATION" } else { "ACCEPT_ROLLED_BACK_PENDING_REPAIR" }
  next_machine_action = if ($executionPassed) { "FEED_CONTROLLED_ACCEPT_CORE_MUTATION_EXECUTION_BACK_INTO_CONTROLLER" } else { "REPAIR_CONTROLLED_ACCEPT_CORE_MUTATION_EXECUTION" }
}

Write-Json -Path (Join-Path $OutputRoot "execute_controlled_accept_core_mutation_result.json") -Object $result

@"
# PHASE162 Execute Controlled Accept Core Mutation For Atom Batch Report

## Result

- status: $($result.status)
- controlled_accept_core_mutation_executed: $($result.controlled_accept_core_mutation_executed)
- post_real_mutation_validation_passed: $($result.post_real_mutation_validation_passed)
- rollback_executed: $($result.rollback_executed)
- staged_atom_count: $($result.staged_atom_count)
- accepted_core_write_executed: $($result.accepted_core_write_executed)
- accepted_memory_mutated: $($result.accepted_memory_mutated)
- accepted_self_model_mutated: $($result.accepted_self_model_mutated)
- registry_mutated: $($result.registry_mutated)
- final_accept_ready: $($result.final_accept_ready)
- next_machine_action: $($result.next_machine_action)

## Meaning

The one-shot controlled accepted-core mutation was executed only after dry-run authorization.

If validation failed, snapshots were restored. If status is PASS, the mutation is written and awaits controller finalization.
"@ | Set-Content -Path (Join-Path $OutputRoot "PHASE162_EXECUTE_CONTROLLED_ACCEPT_CORE_MUTATION_FOR_ATOM_BATCH_REPORT.md") -Encoding UTF8

[pscustomobject]@{
  status = $result.status
  output_root = $OutputRoot
  controlled_accept_core_mutation_executed = [bool]$result.controlled_accept_core_mutation_executed
  post_real_mutation_validation_passed = [bool]$result.post_real_mutation_validation_passed
  rollback_executed = [bool]$result.rollback_executed
  staged_atom_count = [int]$result.staged_atom_count
  accepted_core_write_executed = [bool]$result.accepted_core_write_executed
  accepted_memory_mutated = [bool]$result.accepted_memory_mutated
  accepted_self_model_mutated = [bool]$result.accepted_self_model_mutated
  registry_mutated = [bool]$result.registry_mutated
  final_accept_ready = [bool]$result.final_accept_ready
  next_machine_action = [string]$result.next_machine_action
}

