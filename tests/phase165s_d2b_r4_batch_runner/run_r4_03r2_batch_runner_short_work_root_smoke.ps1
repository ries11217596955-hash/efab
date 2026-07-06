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

function Assert-True {
  param([bool]$Condition, [string]$Message)
  if (-not $Condition) { throw $Message }
}

function Assert-ParserPass {
  param([string]$Path, [string]$Label)
  $tokens = $null
  $errors = $null
  [System.Management.Automation.Language.Parser]::ParseFile((Resolve-Path $Path).Path, [ref]$tokens, [ref]$errors) | Out-Null
  if ($errors.Count -gt 0) {
    throw "PARSER_FAIL_$Label=$((@($errors | ForEach-Object { $_.Message })) -join '; ')"
  }
}

function Get-ProtectedHashSnapshot {
  param([string]$Root, [string[]]$Paths)
  $snapshot = [ordered]@{}
  foreach ($rel in $Paths) {
    $full = Join-Path $Root $rel
    if (Test-Path -LiteralPath $full) {
      $snapshot[$rel] = (Get-FileHash -LiteralPath $full -Algorithm SHA256).Hash
    } else {
      $snapshot[$rel] = 'ABSENT'
    }
  }
  return $snapshot
}

function Assert-SnapshotUnchanged {
  param($Before, $After, [string[]]$Paths)
  foreach ($rel in $Paths) {
    Assert-True ($Before[$rel] -eq $After[$rel]) "PROTECTED_SURFACE_CHANGED=$rel"
  }
}

function Copy-FixtureFile {
  param([string]$SourceRoot, [string]$FixtureRoot, [string]$RelativePath)
  $source = Join-Path $SourceRoot $RelativePath
  $target = Join-Path $FixtureRoot $RelativePath
  Ensure-Dir (Split-Path -Parent $target)
  Copy-Item -LiteralPath $source -Destination $target -Force
}

function Count-Atom {
  param($Root, [string]$Property, [string]$AtomId)
  if ($null -eq $Root -or -not ($Root.PSObject.Properties.Name -contains $Property)) { return 0 }
  return @($Root.$Property | Where-Object { [string]$_.atom_id -eq $AtomId }).Count
}

function Get-FixtureVisibility {
  param([string]$FixtureRoot, [string[]]$AtomIds)
  $memory = Read-J (Join-Path $FixtureRoot 'reports/self_development/accepted_change_memory_snapshot.json')
  $selfMap = Read-J (Join-Path $FixtureRoot 'reports/self_development/SELF_MODEL_ACTIVE_MAP.json')
  $registry = Read-J (Join-Path $FixtureRoot 'packs/registry.json')
  $rows = @()
  foreach ($atomId in $AtomIds) {
    $rows += [pscustomobject][ordered]@{
      atom_id = $atomId
      memory_count = Count-Atom $memory 'phase162_accepted_atom_memory_records' $atomId
      self_map_count = Count-Atom $selfMap 'phase162_absorbed_atom_capability_notes' $atomId
      registry_count = Count-Atom $registry 'phase162_accepted_atom_references' $atomId
    }
  }
  return @($rows)
}

function Initialize-D2BFixtureRepo {
  param(
    [string]$SourceRoot,
    [string]$FixtureRoot,
    [int]$CandidateCount,
    [string]$CandidatePrefix
  )

  $inputRootRel = 'reports/self_development/phase165s_d2_big_curriculum_material_factory'
  $outputRootRel = 'reports/self_development/phase165s_d2b_big_curriculum_autonomous_learning'
  Ensure-Dir $FixtureRoot
  Ensure-Dir (Join-Path $FixtureRoot 'modules')
  Ensure-Dir (Join-Path $FixtureRoot 'packs')
  Ensure-Dir (Join-Path $FixtureRoot 'reports/self_development')
  Ensure-Dir (Join-Path $FixtureRoot "$inputRootRel/raw_shards")

  Copy-FixtureFile -SourceRoot $SourceRoot -FixtureRoot $FixtureRoot -RelativePath 'modules/evaluate_phase165s_c2_bounded_autonomous_atom_acceptance_policy_001.ps1'
  Copy-FixtureFile -SourceRoot $SourceRoot -FixtureRoot $FixtureRoot -RelativePath 'modules/invoke_phase162_execute_controlled_accept_core_mutation_for_atom_batch_001.ps1'
  Copy-FixtureFile -SourceRoot $SourceRoot -FixtureRoot $FixtureRoot -RelativePath 'modules/invoke_phase162_controller_consume_controlled_accept_core_mutation_execution_proof_001.ps1'

  Write-J (Join-Path $FixtureRoot 'reports/self_development/accepted_change_memory_snapshot.json') ([ordered]@{
    phase162_accepted_atom_memory_records = @()
  })
  Write-J (Join-Path $FixtureRoot 'reports/self_development/SELF_MODEL_ACTIVE_MAP.json') ([ordered]@{
    phase162_absorbed_atom_capability_notes = @()
  })
  Write-J (Join-Path $FixtureRoot 'packs/registry.json') ([ordered]@{
    phase162_accepted_atom_references = @()
  })

  $shardRel = "$inputRootRel/raw_shards/curriculum_candidates_00001.jsonl"
  Write-J (Join-Path $FixtureRoot "$inputRootRel/school_ready_manifest.json") ([ordered]@{
    schema = 'PHASE165S_D2A_BIG_CURRICULUM_SCHOOL_READY_MANIFEST_V1'
    total_candidate_count = $CandidateCount
    safe_candidate_count = $CandidateCount
    quarantine_candidate_count = 0
    shard_paths = @($shardRel)
  })
  Write-J (Join-Path $FixtureRoot "$inputRootRel/material_bank_index.json") ([ordered]@{
    schema = 'PHASE165S_D2A_BIG_CURRICULUM_MATERIAL_BANK_INDEX_V1'
    total_candidate_count = $CandidateCount
    shard_count = 1
  })

  $lines = @()
  $atomIds = @()
  for ($i = 1; $i -le $CandidateCount; $i += 1) {
    $atomId = "r4.03r2.$CandidatePrefix.atom.$i.v1"
    $atomIds += $atomId
    $candidate = [ordered]@{
      producer_id = "fixture_producer_$CandidatePrefix"
      source_kind = 'fixture_atom_candidate'
      source_run_id = "fixture_run_$CandidatePrefix"
      candidate_id = "R4_03R2_${CandidatePrefix}_SAFE_CANDIDATE_$('{0:d2}' -f $i)"
      dedup_key = $atomId
      domain = 'r4_batch_admission'
      risk_flag = 'none_identified_at_material_stage'
      validator_required = 'phase162_visibility'
      priority = $i
      dependencies = @()
      batch_id = "R4_03R2_${CandidatePrefix}_BATCH"
      concept_id = "r4_03r2.$CandidatePrefix.safe_candidate.$i"
      target_atom_id_suggestion = $atomId
      explanation = "R4-03R2 fixture candidate $i for central batch admission."
      atom_type_suggestion = 'proof_atom'
      guided_example = 'Admit through the central D2B batch runner and Phase162 batch executor.'
      check_prompt = 'Is the atom accepted exactly once through central batch admission?'
      expected_check_result = 'ATOM_VISIBLE_EXACTLY_ONCE'
      behavior_change = 'D2B can admit a bounded batch through one central admission protocol.'
      next_layer_questions = @('Can the next batch resume from the remaining cursor?', 'Can future producers use the same admission path?')
      source = 'R4_03R2_FIXTURE'
      provenance = 'R4_03R2_BATCH_RUNNER_SHORT_WORK_ROOT_SMOKE'
      accepted = $false
      trusted = $false
      risk_level = 'LOW'
      risk_flags = @('none_identified_at_material_stage')
      requires_school_acceptance = $true
      requires_c2b_guard = $true
      requires_phase162_acceptance = $true
    }
    $lines += ($candidate | ConvertTo-Json -Depth 80 -Compress)
  }
  [System.IO.File]::WriteAllText((Join-Path $FixtureRoot $shardRel), (($lines -join "`n") + "`n"), [System.Text.UTF8Encoding]::new($false))

  if (Get-Command git -ErrorAction SilentlyContinue) {
    & git -C $FixtureRoot init | Out-Null
    & git -C $FixtureRoot -c user.name='R4 03R2 Smoke' -c user.email='r4-03r2-smoke@example.invalid' add . | Out-Null
    & git -C $FixtureRoot -c user.name='R4 03R2 Smoke' -c user.email='r4-03r2-smoke@example.invalid' commit -m 'r4 03r2 fixture baseline' | Out-Null
  }

  return [pscustomobject]@{
    input_root = $inputRootRel
    output_root = $outputRootRel
    atom_ids = $atomIds
  }
}

$sourceRoot = (Resolve-Path $RepoRoot).Path
if ([string]::IsNullOrWhiteSpace($ReportRoot)) {
  $ReportRoot = Join-Path $sourceRoot ("reports/lab_r4_d2b_r4_03r2_batch_runner_{0}" -f (Get-Date -Format 'yyyyMMdd_HHmmss'))
}
$reportFull = if ([System.IO.Path]::IsPathRooted($ReportRoot)) {
  [System.IO.Path]::GetFullPath($ReportRoot)
} else {
  [System.IO.Path]::GetFullPath((Join-Path $sourceRoot $ReportRoot))
}

$fixtureRoot = Join-Path $reportFull 'fixture_repo'
$singleFixtureRoot = Join-Path $reportFull 'fixture_repo_batchsize1_regression'
$runnerPath = Join-Path $sourceRoot 'modules/run_phase165s_d2b_big_curriculum_autonomous_learn_until_empty_001.ps1'
$executorPath = Join-Path $sourceRoot 'modules/invoke_phase162_execute_controlled_accept_core_mutation_for_atom_batch_001.ps1'
$finalizerPath = Join-Path $sourceRoot 'modules/invoke_phase162_controller_consume_controlled_accept_core_mutation_execution_proof_001.ps1'
$smokePath = $PSCommandPath

$protectedAcceptedSurfaces = @(
  'packs/registry.json',
  'reports/self_development/accepted_change_memory_snapshot.json',
  'reports/self_development/SELF_MODEL_ACTIVE_MAP.json',
  'reports/self_development/agent_body_map.json'
)
$protectedBefore = Get-ProtectedHashSnapshot -Root $sourceRoot -Paths $protectedAcceptedSurfaces

Assert-ParserPass -Path $runnerPath -Label 'RUNNER'
Assert-ParserPass -Path $executorPath -Label 'EXECUTOR'
Assert-ParserPass -Path $finalizerPath -Label 'FINALIZER'
Assert-ParserPass -Path $smokePath -Label 'SMOKE'
$parserChecks = [ordered]@{
  runner = 'PASS'
  executor = 'PASS'
  finalizer = 'PASS'
  smoke = 'PASS'
}

$fixture = Initialize-D2BFixtureRepo -SourceRoot $sourceRoot -FixtureRoot $fixtureRoot -CandidateCount 8 -CandidatePrefix 'batch'
$workRootBase = Join-Path ([System.IO.Path]::GetTempPath()) ("efab_r4_03r2_batch_runner_{0}" -f (Get-Date -Format 'yyyyMMdd_HHmmss'))
$effectiveWorkRoot = Join-Path $workRootBase 'phase165s_d2b_work_current'
Ensure-Dir $workRootBase

$batchRunnerOutput = @(& $runnerPath `
  -RepoRoot $fixtureRoot `
  -InputRoot $fixture.input_root `
  -OutputRoot $fixture.output_root `
  -BatchSize 5 `
  -WorkRoot $workRootBase `
  -CheckpointEvery 1 `
  -HeartbeatEvery 1 `
  -EmitJson)

$outputFull = Join-Path $fixtureRoot $fixture.output_root
$summaryPath = Join-Path $outputFull 'final_summary.json'
$summary = Read-J $summaryPath
$failedLogPath = Join-Path $outputFull 'failed_log.jsonl'
$failedLogText = if (Test-Path -LiteralPath $failedLogPath) { Get-Content -LiteralPath $failedLogPath -Raw } else { '' }

Assert-True ([int]$summary.batch_size -eq 5) "BATCH_SIZE_NOT_5=$($summary.batch_size)"
Assert-True ([bool]$summary.batch_execution_implemented -eq $true) 'BATCH_EXECUTION_NOT_IMPLEMENTED_IN_SUMMARY'
Assert-True ([bool]$summary.batch_mode_scaffold_only -eq $false) 'BATCH_MODE_STILL_SCAFFOLD'
Assert-True ([int]$summary.accepted_atom_count -eq 5) "ACCEPTED_COUNT_NOT_5=$($summary.accepted_atom_count)"
Assert-True ([int]$summary.remaining_count -eq 3) "REMAINING_COUNT_NOT_3=$($summary.remaining_count)"
Assert-True ([int]$summary.failed_count -eq 0) "FAILED_COUNT_NOT_0=$($summary.failed_count)"
Assert-True ([int]$summary.phase162_executor_invocation_count -ge 1) 'EXECUTOR_NOT_INVOKED'
Assert-True ([int]$summary.finalizer_invocation_count -ge 1) 'FINALIZER_NOT_INVOKED'
Assert-True ([string]$summary.work_root_mode -eq 'explicit') "WORK_ROOT_MODE_NOT_EXPLICIT=$($summary.work_root_mode)"
Assert-True ([bool]$summary.work_root_short_path_enabled -eq $true) 'SHORT_WORK_ROOT_NOT_ENABLED'
Assert-True ([System.IO.Path]::GetFullPath([string]$summary.work_root).Equals([System.IO.Path]::GetFullPath($effectiveWorkRoot), [System.StringComparison]::OrdinalIgnoreCase)) "WORK_ROOT_MISMATCH=$($summary.work_root)"

$acceptedAtomIds = @($fixture.atom_ids | Select-Object -First 5)
$remainingAtomIds = @($fixture.atom_ids | Select-Object -Skip 5)
$acceptedVisibility = @(Get-FixtureVisibility -FixtureRoot $fixtureRoot -AtomIds $acceptedAtomIds)
$remainingVisibility = @(Get-FixtureVisibility -FixtureRoot $fixtureRoot -AtomIds $remainingAtomIds)
$badAcceptedVisibility = @($acceptedVisibility | Where-Object {
  [int]$_.memory_count -ne 1 -or [int]$_.self_map_count -ne 1 -or [int]$_.registry_count -ne 1
})
$badRemainingVisibility = @($remainingVisibility | Where-Object {
  [int]$_.memory_count -ne 0 -or [int]$_.self_map_count -ne 0 -or [int]$_.registry_count -ne 0
})
Assert-True ($badAcceptedVisibility.Count -eq 0) "ACCEPTED_VISIBILITY_BAD=$($badAcceptedVisibility.Count)"
Assert-True ($badRemainingVisibility.Count -eq 0) "REMAINING_VISIBILITY_BAD=$($badRemainingVisibility.Count)"

$legacyWorkCurrent = Join-Path $outputFull 'work/current'
$legacyOutputWorkCurrentAbsent = (-not (Test-Path -LiteralPath $legacyWorkCurrent))
Assert-True $legacyOutputWorkCurrentAbsent 'LEGACY_OUTPUT_WORK_CURRENT_USED'
foreach ($requiredTransient in @(
  '.efab_d2b_workroot',
  'cand/controlled_accept_core_mutation_candidate_result.json',
  'ctrl/one_shot_controlled_accept_core_mutation_execution_authorization_for_atom_batch.json',
  'exec/execute_controlled_accept_core_mutation_result.json',
  'fin/controller_consume_controlled_accept_core_mutation_execution_proof_result.json'
)) {
  Assert-True (Test-Path -LiteralPath (Join-Path $effectiveWorkRoot $requiredTransient)) "MISSING_TRANSIENT=$requiredTransient"
}

$failedLogScalar = [string]$failedLogText
$noAtomVisibilityCountFailed = -not ($failedLogScalar -match 'ATOM_VISIBILITY_COUNT_FAILED')
$noControllerValidationWriteFailure = -not ($failedLogScalar -match 'MISSING_CANDIDATE_ROOT|controller validation|CONTROLLER.*WRITE|path failure')
Assert-True $noAtomVisibilityCountFailed 'ATOM_VISIBILITY_COUNT_FAILED_FOUND'
Assert-True $noControllerValidationWriteFailure 'CONTROLLER_VALIDATION_OR_PATH_FAILURE_FOUND'

$singleFixture = Initialize-D2BFixtureRepo -SourceRoot $sourceRoot -FixtureRoot $singleFixtureRoot -CandidateCount 1 -CandidatePrefix 'single'
$singleWorkRootBase = Join-Path ([System.IO.Path]::GetTempPath()) ("efab_r4_03r2_batchsize1_regression_{0}" -f (Get-Date -Format 'yyyyMMdd_HHmmss'))
Ensure-Dir $singleWorkRootBase
$singleRunnerOutput = @(& $runnerPath `
  -RepoRoot $singleFixtureRoot `
  -InputRoot $singleFixture.input_root `
  -OutputRoot $singleFixture.output_root `
  -BatchSize 1 `
  -WorkRoot $singleWorkRootBase `
  -CheckpointEvery 1 `
  -HeartbeatEvery 1 `
  -EmitJson)
$singleSummary = Read-J (Join-Path $singleFixtureRoot "$($singleFixture.output_root)/final_summary.json")
Assert-True ([string]$singleSummary.status -eq 'PASS_QUEUE_EMPTY') "BATCHSIZE1_STATUS_NOT_PASS=$($singleSummary.status)"
Assert-True ([int]$singleSummary.accepted_atom_count -eq 1) "BATCHSIZE1_ACCEPTED_NOT_1=$($singleSummary.accepted_atom_count)"
Assert-True ([int]$singleSummary.failed_count -eq 0) "BATCHSIZE1_FAILED_NOT_0=$($singleSummary.failed_count)"
Assert-True ([string]$singleSummary.work_root_mode -eq 'explicit') "BATCHSIZE1_WORK_ROOT_MODE_NOT_EXPLICIT=$($singleSummary.work_root_mode)"

$protectedAfter = Get-ProtectedHashSnapshot -Root $sourceRoot -Paths $protectedAcceptedSurfaces
Assert-SnapshotUnchanged -Before $protectedBefore -After $protectedAfter -Paths $protectedAcceptedSurfaces

$proofPath = Join-Path $reportFull 'R4_03R2_BATCH_RUNNER_SHORT_WORK_ROOT_PROOF.json'
$reportPath = Join-Path $reportFull 'R4_03R2_BATCH_RUNNER_SHORT_WORK_ROOT_REPORT.md'
$proof = [ordered]@{
  status = 'PASS'
  task = 'R4-03R2'
  created_at = (Get-Date -Format o)
  fixture_root = $fixtureRoot
  report_root = $reportFull
  runner_path = $runnerPath
  batch_size = 5
  accepted_atom_count = [int]$summary.accepted_atom_count
  remaining_count = [int]$summary.remaining_count
  failed_count = [int]$summary.failed_count
  phase162_executor_invocation_count = [int]$summary.phase162_executor_invocation_count
  finalizer_invocation_count = [int]$summary.finalizer_invocation_count
  work_root = [string]$summary.work_root
  work_root_mode = [string]$summary.work_root_mode
  work_root_short_path_enabled = [bool]$summary.work_root_short_path_enabled
  legacy_output_work_current_absent = [bool]$legacyOutputWorkCurrentAbsent
  real_accepted_surfaces_unchanged = $true
  parser_checks = $parserChecks
  protected_hashes_before = $protectedBefore
  protected_hashes_after = $protectedAfter
  accepted_visibility_checks = $acceptedVisibility
  remaining_visibility_checks = $remainingVisibility
  no_atom_visibility_count_failed = [bool]$noAtomVisibilityCountFailed
  no_controller_validation_write_failure = [bool]$noControllerValidationWriteFailure
  batch_summary_path = $summaryPath
  batch_runner_output = @($batchRunnerOutput)
  batchsize1_regression = [ordered]@{
    fixture_root = $singleFixtureRoot
    status = [string]$singleSummary.status
    accepted_atom_count = [int]$singleSummary.accepted_atom_count
    failed_count = [int]$singleSummary.failed_count
    work_root_mode = [string]$singleSummary.work_root_mode
    runner_output = @($singleRunnerOutput)
  }
}
Write-J $proofPath $proof

@"
# R4-03R2 Batch Runner Short WorkRoot Smoke

Status: PASS

- fixture_root: $fixtureRoot
- batch_size: 5
- accepted_atom_count: $($summary.accepted_atom_count)
- remaining_count: $($summary.remaining_count)
- failed_count: $($summary.failed_count)
- phase162_executor_invocation_count: $($summary.phase162_executor_invocation_count)
- finalizer_invocation_count: $($summary.finalizer_invocation_count)
- work_root: $($summary.work_root)
- batchsize1_regression_status: $($singleSummary.status)
- proof: $proofPath

The smoke proved central batch admission through the D2B runner with explicit short WorkRoot. The first five fixture atoms were accepted exactly once, three remained unaccepted for resume, legacy OutputRoot/work/current was not used for transient package files, and real accepted surfaces in the source repo were hash-checked unchanged.
"@ | Set-Content -LiteralPath $reportPath -Encoding UTF8

Write-Host 'R4_03R2_BATCH_RUNNER_SHORT_WORK_ROOT_SMOKE_RESULT=PASS'
Write-Host "REPORT_ROOT=$reportFull"
Write-Host "PROOF_PATH=$proofPath"
Write-Host "REPORT_PATH=$reportPath"
Write-Host "BATCH_ACCEPTED_ATOM_COUNT=$($summary.accepted_atom_count)"
Write-Host "BATCH_REMAINING_COUNT=$($summary.remaining_count)"
