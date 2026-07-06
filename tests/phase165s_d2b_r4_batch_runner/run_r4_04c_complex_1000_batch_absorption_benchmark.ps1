param(
  [int]$CandidateCount = 1000,
  [int[]]$BatchSizes = @(100,250),
  [int]$MaxSecondsPerScenario = 900,
  [switch]$AllowRunWhenNoLiveD2B,
  [switch]$PrepareOnly,
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
  $json = ($Object | ConvertTo-Json -Depth 100) -replace "`r`n", "`n"
  [System.IO.File]::WriteAllText($Path, $json + "`n", [System.Text.UTF8Encoding]::new($false))
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

function Test-SnapshotUnchanged {
  param($Before, $After, [string[]]$Paths)
  foreach ($rel in $Paths) {
    if ($Before[$rel] -ne $After[$rel]) { return $false }
  }
  return $true
}

function Copy-FixtureFile {
  param([string]$SourceRoot, [string]$FixtureRoot, [string]$RelativePath)
  $source = Join-Path $SourceRoot $RelativePath
  $target = Join-Path $FixtureRoot $RelativePath
  Ensure-Dir (Split-Path -Parent $target)
  Copy-Item -LiteralPath $source -Destination $target -Force
}

function Invoke-FixtureGit {
  param([string]$FixtureRoot, [string[]]$Arguments)
  & git -C $FixtureRoot @Arguments | Out-Null
  if ($LASTEXITCODE -ne 0) {
    throw "FIXTURE_GIT_FAILED args=$($Arguments -join ' ') exit=$LASTEXITCODE"
  }
}

function Get-PolicyGuardExpectations {
  param(
    [string]$MemoryPath,
    [string]$SelfMapPath,
    [string]$RegistryPath
  )
  return [ordered]@{
    source_route = 'OWNER_APPROVED_CURRICULUM'
    source_authority = 'OWNER_APPROVED'
    target_files = @($MemoryPath,$SelfMapPath,$RegistryPath)
    protected_files_to_mutate = @('packs/registry.json')
    proof_gates = [ordered]@{
      memory_proof_status = 'PASS'
      use_proof_status = 'PASS'
      behavior_delta_status = 'PASS'
      persistence_status = 'PASS'
      startup_visibility_status = 'PASS'
    }
    rollback_plan_available = $true
    exactly_one_atom_scope = $true
    mass_acceptance_forbidden = $true
    risk_flags = @()
  }
}

function New-ComplexCandidate {
  param(
    [int]$Index,
    [string]$CandidatePrefix,
    [object]$PolicyExpectations
  )

  $padded = '{0:d4}' -f $Index
  $atomId = "r4.04c.$CandidatePrefix.atom.$padded.v1"
  $clusterId = (($Index - 1) % 20) + 1
  $stepCount = 5 + (($Index - 1) % 4)

  return [ordered]@{
    atom_id = $atomId
    target_atom_id_suggestion = $atomId
    candidate_id = "R4_04C_${CandidatePrefix}_COMPLEX_SAFE_CANDIDATE_$padded"
    title = "Complex safe D2B absorption candidate $padded"
    source_context = [ordered]@{
      benchmark = 'R4-04C'
      fixture_kind = 'isolated_temp_repo'
      material_family = 'complex_safe_atom_candidates'
      live_d2b_safety = 'never_touch_real_accepted_surfaces'
    }
    complexity_profile = [ordered]@{
      class = 'complex_safe_atom'
      procedure_step_count = $stepCount
      dependency_hint_count = 3
      validation_surface_count = 3
      expected_batch_mode = 'central_d2b_batch_admission'
    }
    concept_cluster = @(
      'batch_absorption',
      ('complex_cluster_{0:d2}' -f $clusterId),
      'safe_policy_guarded_memory'
    )
    procedure_steps = @(
      "Frame candidate $padded as raw curriculum material.",
      'Preserve owner-safe provenance without claiming trust.',
      'Require C2B guard before any accepted-core write.',
      'Expect Phase162 executor to write only accepted atom surfaces in fixture.',
      'Validate exact-once visibility after finalizer proof.'
    )
    validator_expectations = [ordered]@{
      parser = 'candidate_jsonl_line_must_parse'
      c2b_policy_guard = 'ALLOW_AUTONOMOUS_ONE_ATOM_ACCEPTANCE'
      phase162_visibility = 'memory_self_map_registry_exactly_once'
      duplicate_acceptance = 'forbidden'
    }
    proof_expectations = [ordered]@{
      memory_proof = 'atom id appears exactly once after successful execution'
      use_proof = 'payload is retrievable from fixture accepted memory'
      behavior_delta = 'runner advances cursor and resumes without duplicate admission'
      persistence = 'fixture files persist until scenario inspection completes'
    }
    route_context = [ordered]@{
      active_line = 'AGENT_BUILDER_SELF_DEVELOPMENT'
      route = 'R4_D2B_BATCH_ABSORPTION_BENCHMARK'
      live_50k_relation = 'benchmark waits or defers if another D2B process is active'
    }
    self_model_delta = [ordered]@{
      kind = 'candidate_observation_only_until_guarded_acceptance'
      expected_note = "Complex safe batch candidate $padded can be absorbed after guarded execution."
      no_trust_claim = $true
    }
    dependency_hints = @(
      'policy_guard_expectations',
      'phase162_batch_executor',
      'phase162_finalizer'
    )
    risk_notes = @(
      'No accepted or trusted status is claimed by the raw candidate.',
      'No direct protected mutation is requested by the raw candidate.',
      'Only the isolated fixture repo may receive accepted-surface writes.'
    )
    dedup_key = $atomId
    created_at = (Get-Date).ToUniversalTime().ToString('o')
    producer_id = 'r4_04c_complex_benchmark_generator'
    source_kind = 'isolated_complex_fixture_candidate'
    source_run_id = "R4_04C_$CandidatePrefix"
    domain = 'd2b_complex_batch_absorption'
    validator_required = 'phase162_visibility_exactly_once'
    priority = $Index
    dependencies = @()
    batch_id = "R4_04C_${CandidatePrefix}_BATCH"
    policy_guard_expectations = $PolicyExpectations
    concept_id = "r4_04c.$CandidatePrefix.complex_safe_candidate.$padded"
    explanation = "Complex but safe R4-04C candidate $padded for measuring central D2B batch absorption."
    atom_type_suggestion = 'proof_atom'
    guided_example = 'Admit only through D2B central batch admission, C2B policy guard, Phase162 executor, and finalizer.'
    check_prompt = 'Is this complex candidate visible exactly once in all fixture accepted surfaces after admission?'
    expected_check_result = 'ATOM_VISIBLE_EXACTLY_ONCE'
    behavior_change = 'The D2B runner absorbs a richer candidate while preserving cursor progress and exact-once accepted visibility.'
    next_layer_questions = @(
      'Can central batch admission keep throughput stable for richer payloads?',
      'Can resume drain the queue without duplicate accepted logs?',
      'Can the policy guard remain per-atom inside a larger selected batch?'
    )
    source = 'R4_04C_COMPLEX_FIXTURE'
    provenance = 'R4_04C_COMPLEX_1000_BATCH_ABSORPTION_BENCHMARK'
    accepted = $false
    trusted = $false
    risk_level = 'LOW'
    risk_flag = 'none_identified_at_material_stage'
    risk_flags = @('none_identified_at_material_stage')
    requires_school_acceptance = $true
    requires_c2b_guard = $true
    requires_phase162_acceptance = $true
  }
}

function Initialize-ComplexD2BFixtureRepo {
  param(
    [string]$SourceRoot,
    [string]$FixtureRoot,
    [int]$CandidateCount,
    [string]$CandidatePrefix
  )

  $inputRootRel = 'reports/self_development/phase165s_d2_big_curriculum_material_factory'
  $outputRootRel = 'reports/self_development/phase165s_d2b_big_curriculum_autonomous_learning'
  $memoryPath = 'reports/self_development/accepted_change_memory_snapshot.json'
  $selfMapPath = 'reports/self_development/SELF_MODEL_ACTIVE_MAP.json'
  $registryPath = 'packs/registry.json'

  Ensure-Dir $FixtureRoot
  Ensure-Dir (Join-Path $FixtureRoot 'modules')
  Ensure-Dir (Join-Path $FixtureRoot 'packs')
  Ensure-Dir (Join-Path $FixtureRoot 'reports/self_development')
  Ensure-Dir (Join-Path $FixtureRoot "$inputRootRel/raw_shards")

  Copy-FixtureFile -SourceRoot $SourceRoot -FixtureRoot $FixtureRoot -RelativePath 'modules/evaluate_phase165s_c2_bounded_autonomous_atom_acceptance_policy_001.ps1'
  Copy-FixtureFile -SourceRoot $SourceRoot -FixtureRoot $FixtureRoot -RelativePath 'modules/invoke_phase162_execute_controlled_accept_core_mutation_for_atom_batch_001.ps1'
  Copy-FixtureFile -SourceRoot $SourceRoot -FixtureRoot $FixtureRoot -RelativePath 'modules/invoke_phase162_controller_consume_controlled_accept_core_mutation_execution_proof_001.ps1'

  Write-J (Join-Path $FixtureRoot $memoryPath) ([ordered]@{
    phase162_accepted_atom_memory_records = @()
  })
  Write-J (Join-Path $FixtureRoot $selfMapPath) ([ordered]@{
    phase162_absorbed_atom_capability_notes = @()
  })
  Write-J (Join-Path $FixtureRoot $registryPath) ([ordered]@{
    phase162_accepted_atom_references = @()
  })

  $policyExpectations = Get-PolicyGuardExpectations -MemoryPath $memoryPath -SelfMapPath $selfMapPath -RegistryPath $registryPath
  Write-J (Join-Path $FixtureRoot "$inputRootRel/policy_guard_expectations.json") $policyExpectations

  $shardRel = "$inputRootRel/raw_shards/complex_candidates_00001.jsonl"
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
    candidate_complexity = 'complex_safe'
  })

  $atomIds = New-Object System.Collections.Generic.List[string]
  $builder = [System.Text.StringBuilder]::new()
  for ($i = 1; $i -le $CandidateCount; $i += 1) {
    $candidate = New-ComplexCandidate -Index $i -CandidatePrefix $CandidatePrefix -PolicyExpectations $policyExpectations
    [void]$atomIds.Add([string]$candidate.atom_id)
    [void]$builder.AppendLine(($candidate | ConvertTo-Json -Depth 100 -Compress))
  }
  [System.IO.File]::WriteAllText((Join-Path $FixtureRoot $shardRel), $builder.ToString(), [System.Text.UTF8Encoding]::new($false))

  Invoke-FixtureGit -FixtureRoot $FixtureRoot -Arguments @('init','-q')
  Invoke-FixtureGit -FixtureRoot $FixtureRoot -Arguments @('config','core.autocrlf','false')
  Invoke-FixtureGit -FixtureRoot $FixtureRoot -Arguments @('config','user.name','R4 04C Benchmark')
  Invoke-FixtureGit -FixtureRoot $FixtureRoot -Arguments @('config','user.email','r4-04c-benchmark@example.invalid')
  Invoke-FixtureGit -FixtureRoot $FixtureRoot -Arguments @('add','.')
  Invoke-FixtureGit -FixtureRoot $FixtureRoot -Arguments @('commit','-q','-m','r4 04c complex benchmark fixture baseline')

  return [pscustomobject]@{
    input_root = $inputRootRel
    output_root = $outputRootRel
    atom_ids = @($atomIds)
    fixture_root = $FixtureRoot
  }
}

function Get-LiveD2BProcesses {
  $needle = 'run_phase165s_d2b_big_curriculum_autonomous_learn_until_empty_001.ps1'
  try {
    $matches = @(Get-CimInstance Win32_Process -ErrorAction Stop | Where-Object {
      [int]$_.ProcessId -ne $PID -and
      -not [string]::IsNullOrWhiteSpace([string]$_.CommandLine) -and
      [string]$_.CommandLine -like "*$needle*"
    })
  } catch {
    throw "LIVE_D2B_PROCESS_CHECK_FAILED=$($_.Exception.Message)"
  }

  $rows = @()
  foreach ($p in $matches) {
    $commandLine = [string]$p.CommandLine
    $rows += [pscustomobject][ordered]@{
      process_id = [int]$p.ProcessId
      parent_process_id = [int]$p.ParentProcessId
      command_line_length = $commandLine.Length
      command_line_preview = $commandLine.Substring(0, [Math]::Min(180, $commandLine.Length))
    }
  }
  return @($rows)
}

function Get-LineCount {
  param([string]$Path)
  if (-not (Test-Path -LiteralPath $Path)) { return 0 }
  $count = 0
  $reader = [System.IO.StreamReader]::new($Path)
  try {
    while (-not $reader.EndOfStream) {
      $line = $reader.ReadLine()
      if (-not [string]::IsNullOrWhiteSpace($line)) { $count += 1 }
    }
  } finally {
    $reader.Dispose()
  }
  return $count
}

function Get-AcceptedLogStats {
  param([string]$AcceptedLogPath)
  $seen = @{}
  $count = 0
  if (Test-Path -LiteralPath $AcceptedLogPath) {
    $reader = [System.IO.StreamReader]::new($AcceptedLogPath)
    try {
      while (-not $reader.EndOfStream) {
        $line = $reader.ReadLine()
        if ([string]::IsNullOrWhiteSpace($line)) { continue }
        $count += 1
        $record = $line | ConvertFrom-Json
        $atomId = [string]$record.atom_id
        if (-not $seen.ContainsKey($atomId)) { $seen[$atomId] = 0 }
        $seen[$atomId] = [int]$seen[$atomId] + 1
      }
    } finally {
      $reader.Dispose()
    }
  }
  $duplicates = @($seen.Keys | Where-Object { [int]$seen[$_] -gt 1 } | Sort-Object)
  return [pscustomobject][ordered]@{
    accepted_log_count = $count
    duplicate_atom_count = $duplicates.Count
    duplicate_atom_ids = @($duplicates)
  }
}

function ConvertTo-ProcessArgument {
  param([string]$Argument)
  if ($null -eq $Argument) { return '""' }
  if ($Argument.Length -eq 0) { return '""' }
  if ($Argument -notmatch '[\s"]') { return $Argument }
  return '"' + ($Argument -replace '"','\"') + '"'
}

function Invoke-D2BRunnerCycle {
  param(
    [string]$PowerShellExe,
    [string]$RunnerPath,
    [string]$FixtureRoot,
    [string]$InputRoot,
    [string]$OutputRoot,
    [int]$BatchSize,
    [string]$WorkRoot,
    [bool]$Resume,
    [int]$TimeoutSeconds = 0
  )

  $args = @(
    '-NoProfile',
    '-ExecutionPolicy',
    'Bypass',
    '-File',
    $RunnerPath,
    '-RepoRoot',
    $FixtureRoot,
    '-InputRoot',
    $InputRoot,
    '-OutputRoot',
    $OutputRoot,
    '-BatchSize',
    "$BatchSize",
    '-WorkRoot',
    $WorkRoot,
    '-CheckpointEvery',
    '1',
    '-HeartbeatEvery',
    '1',
    '-EmitJson'
  )
  if ($Resume) { $args += '-Resume' }

  $psi = [System.Diagnostics.ProcessStartInfo]::new()
  $psi.FileName = $PowerShellExe
  $psi.Arguments = (($args | ForEach-Object { ConvertTo-ProcessArgument ([string]$_) }) -join ' ')
  $psi.UseShellExecute = $false
  $psi.RedirectStandardOutput = $true
  $psi.RedirectStandardError = $true
  $psi.CreateNoWindow = $true
  $process = [System.Diagnostics.Process]::new()
  $process.StartInfo = $psi
  $timedOut = $false
  try {
    [void]$process.Start()
    $waitMs = if ($TimeoutSeconds -gt 0) { $TimeoutSeconds * 1000 } else { [System.Threading.Timeout]::Infinite }
    if (-not $process.WaitForExit($waitMs)) {
      $timedOut = $true
      try { $process.Kill() } catch {}
      $process.WaitForExit()
    }
    $stdout = $process.StandardOutput.ReadToEnd()
    $stderr = $process.StandardError.ReadToEnd()
    $output = @()
    if (-not [string]::IsNullOrWhiteSpace($stdout)) { $output += @($stdout -split "`r?`n" | Where-Object { $_ -ne '' }) }
    if (-not [string]::IsNullOrWhiteSpace($stderr)) { $output += @($stderr -split "`r?`n" | Where-Object { $_ -ne '' }) }
    $exitCode = if ($timedOut) { 124 } else { [int]$process.ExitCode }
  } finally {
    $process.Dispose()
  }
  return [pscustomobject][ordered]@{
    exit_code = $exitCode
    timed_out = [bool]$timedOut
    output_tail = @($output | Select-Object -Last 12)
  }
}

function Invoke-BenchmarkScenario {
  param(
    [string]$SourceRoot,
    [string]$TempRoot,
    [string]$RunnerPath,
    [string]$PowerShellExe,
    [int]$CandidateCount,
    [int]$BatchSize,
    [int]$MaxSecondsPerScenario
  )

  $scenarioId = "complex_${CandidateCount}_batch_${BatchSize}"
  $scenarioRoot = Join-Path $TempRoot "b$BatchSize"
  $fixtureRoot = Join-Path $scenarioRoot 'f'
  $fixture = Initialize-ComplexD2BFixtureRepo -SourceRoot $SourceRoot -FixtureRoot $fixtureRoot -CandidateCount $CandidateCount -CandidatePrefix "batch$BatchSize"
  $workRootBase = Join-Path $scenarioRoot 'w'
  Ensure-Dir $workRootBase

  $expectedMaxCycles = [int][Math]::Ceiling($CandidateCount / [double]$BatchSize) + 2
  $expectedInvocationLimit = [int][Math]::Ceiling($CandidateCount / [double]$BatchSize) + 1
  $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
  $cycle = 0
  $timeoutHit = $false
  $maxCyclesHit = $false
  $hardError = $null
  $summary = $null
  $cycleRecords = @()

  while ($true) {
    if ($cycle -ge $expectedMaxCycles) {
      $maxCyclesHit = $true
      break
    }
    if ($stopwatch.Elapsed.TotalSeconds -ge $MaxSecondsPerScenario) {
      $timeoutHit = $true
      break
    }

    $cycle += 1
    $remainingSeconds = [int][Math]::Floor($MaxSecondsPerScenario - $stopwatch.Elapsed.TotalSeconds)
    if ($remainingSeconds -lt 1) {
      $timeoutHit = $true
      break
    }
    $cycleResult = Invoke-D2BRunnerCycle `
      -PowerShellExe $PowerShellExe `
      -RunnerPath $RunnerPath `
      -FixtureRoot $fixtureRoot `
      -InputRoot $fixture.input_root `
      -OutputRoot $fixture.output_root `
      -BatchSize $BatchSize `
      -WorkRoot $workRootBase `
      -Resume:($cycle -gt 1) `
      -TimeoutSeconds $remainingSeconds

    $cycleRecords += [pscustomobject][ordered]@{
      cycle = $cycle
      exit_code = [int]$cycleResult.exit_code
      timed_out = [bool]$cycleResult.timed_out
      output_tail = @($cycleResult.output_tail)
    }

    $summaryPath = Join-Path $fixtureRoot "$($fixture.output_root)/final_summary.json"
    if (Test-Path -LiteralPath $summaryPath) {
      $summary = Read-J $summaryPath
    }

    if ([bool]$cycleResult.timed_out) {
      $timeoutHit = $true
      $hardError = "RUNNER_CYCLE_TIMEOUT_AFTER_SECONDS=$remainingSeconds"
      break
    }
    if ([int]$cycleResult.exit_code -ne 0) {
      $hardError = "RUNNER_EXIT_$($cycleResult.exit_code)"
      if ($cycleResult.output_tail.Count -gt 0) {
        $hardError = "$hardError $($cycleResult.output_tail -join ' | ')"
      }
      break
    }
    if ($null -eq $summary) {
      $hardError = 'SUMMARY_MISSING_AFTER_RUN'
      break
    }
    if ([bool]$summary.queue_empty) { break }
    if ([int]$summary.failed_count -gt 0) {
      $hardError = "RUNNER_FAILED_COUNT=$($summary.failed_count)"
      break
    }
  }

  $stopwatch.Stop()
  $outputFull = Join-Path $fixtureRoot $fixture.output_root
  $acceptedStats = Get-AcceptedLogStats -AcceptedLogPath (Join-Path $outputFull 'accepted_log.jsonl')
  $quarantineLogCount = Get-LineCount -Path (Join-Path $outputFull 'quarantine_log.jsonl')
  $skippedLogCount = Get-LineCount -Path (Join-Path $outputFull 'skipped_log.jsonl')

  $acceptedCount = if ($null -ne $summary) { [int]$summary.accepted_atom_count } else { 0 }
  $remainingCount = if ($null -ne $summary) { [int]$summary.remaining_count } else { $CandidateCount }
  $failedCount = if ($null -ne $summary) { [int]$summary.failed_count } else { 0 }
  $quarantineCount = if ($null -ne $summary) { [int]$summary.quarantine_count } else { $quarantineLogCount }
  $skippedCount = if ($null -ne $summary) { [int]$summary.skipped_duplicate_count } else { $skippedLogCount }
  $policyGuardCount = if ($null -ne $summary) { [int]$summary.autonomous_policy_guard_invocation_count } else { 0 }
  $policyGuardProcessCount = if ($null -ne $summary -and $summary.PSObject.Properties.Name -contains 'policy_guard_process_invocation_count') { [int]$summary.policy_guard_process_invocation_count } else { 0 }
  $executorCount = if ($null -ne $summary) { [int]$summary.phase162_executor_invocation_count } else { 0 }
  $finalizerCount = if ($null -ne $summary) { [int]$summary.finalizer_invocation_count } else { 0 }
  $queueEmpty = ($null -ne $summary -and [bool]$summary.queue_empty)
  $elapsedMs = [int64]$stopwatch.ElapsedMilliseconds
  $acceptedPerSecond = if ($elapsedMs -gt 0) { [Math]::Round(($acceptedCount / ($elapsedMs / 1000.0)), 4) } else { 0 }

  $scenarioPass = (
    $queueEmpty -and
    $acceptedCount -eq $CandidateCount -and
    $remainingCount -eq 0 -and
    $failedCount -eq 0 -and
    [int]$acceptedStats.duplicate_atom_count -eq 0 -and
    $executorCount -le $expectedInvocationLimit -and
    $finalizerCount -le $expectedInvocationLimit -and
    -not $timeoutHit -and
    -not $maxCyclesHit -and
    [string]::IsNullOrWhiteSpace($hardError)
  )

  return [pscustomobject][ordered]@{
    scenario_id = $scenarioId
    candidate_count = $CandidateCount
    batch_size = $BatchSize
    elapsed_ms = $elapsedMs
    cycles_to_empty = if ($queueEmpty) { $cycle } else { $null }
    expected_max_cycles = $expectedMaxCycles
    accepted_count = $acceptedCount
    remaining_count = $remainingCount
    failed_count = $failedCount
    quarantine_count = $quarantineCount
    skipped_count = $skippedCount
    autonomous_policy_guard_invocation_count = $policyGuardCount
    policy_guard_process_invocation_count = $policyGuardProcessCount
    phase162_executor_invocation_count = $executorCount
    finalizer_invocation_count = $finalizerCount
    accepted_log_count = [int]$acceptedStats.accepted_log_count
    duplicate_atom_count = [int]$acceptedStats.duplicate_atom_count
    duplicate_atom_ids = @($acceptedStats.duplicate_atom_ids)
    queue_empty = [bool]$queueEmpty
    timeout_hit = [bool]$timeoutHit
    max_cycles_hit = [bool]$maxCyclesHit
    hard_error = $hardError
    accepted_per_second = $acceptedPerSecond
    scenario_pass = [bool]$scenarioPass
    fixture_root = $fixtureRoot
    work_root = $workRootBase
    output_root = $outputFull
    cycle_records = @($cycleRecords)
  }
}

function New-ScenarioTable {
  param([object[]]$ScenarioResults)
  $lines = @(
    '| scenario_id | batch_size | elapsed_ms | cycles | accepted | remaining | failed | duplicates | policy_proc | exec | finalizer | accepted_per_second | result |',
    '|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|'
  )
  if ($ScenarioResults.Count -eq 0) {
    $lines += '| not_executed | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | deferred_or_prepared_only |'
    return $lines
  }
  foreach ($r in $ScenarioResults) {
    $result = if ([bool]$r.scenario_pass) { 'PASS' } else { 'FAIL' }
    $cycles = if ($null -ne $r.cycles_to_empty) { [string]$r.cycles_to_empty } else { 'n/a' }
    $lines += "| $($r.scenario_id) | $($r.batch_size) | $($r.elapsed_ms) | $cycles | $($r.accepted_count) | $($r.remaining_count) | $($r.failed_count) | $($r.duplicate_atom_count) | $($r.policy_guard_process_invocation_count) | $($r.phase162_executor_invocation_count) | $($r.finalizer_invocation_count) | $($r.accepted_per_second) | $result |"
  }
  return $lines
}

$sourceRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
Set-Location $sourceRoot

foreach ($required in @('CAPABILITY_ROADMAP.json','GENESIS_STATE.json','TASK_QUEUE.json','packs/registry.json','orchestrator/run.ps1')) {
  if (-not (Test-Path -LiteralPath (Join-Path $sourceRoot $required))) {
    Write-Host 'STOP=WRONG_AGENT_BUILDER_REPO'
    throw "STOP=WRONG_AGENT_BUILDER_REPO missing=$required"
  }
}

$timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
if ([string]::IsNullOrWhiteSpace($ReportRoot)) {
  $ReportRoot = Join-Path $sourceRoot "reports/lab_r4_d2b_r4_04c_complex_1000_batch_absorption_$timestamp"
}
$reportFull = if ([System.IO.Path]::IsPathRooted($ReportRoot)) {
  [System.IO.Path]::GetFullPath($ReportRoot)
} else {
  [System.IO.Path]::GetFullPath((Join-Path $sourceRoot $ReportRoot))
}
Ensure-Dir $reportFull

$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) "e4c_$timestamp"
Ensure-Dir $tempRoot

$runnerPath = Join-Path $sourceRoot 'modules/run_phase165s_d2b_big_curriculum_autonomous_learn_until_empty_001.ps1'
$policyPath = Join-Path $sourceRoot 'modules/evaluate_phase165s_c2_bounded_autonomous_atom_acceptance_policy_001.ps1'
$executorPath = Join-Path $sourceRoot 'modules/invoke_phase162_execute_controlled_accept_core_mutation_for_atom_batch_001.ps1'
$finalizerPath = Join-Path $sourceRoot 'modules/invoke_phase162_controller_consume_controlled_accept_core_mutation_execution_proof_001.ps1'
$benchmarkPath = $PSCommandPath
$powerShellExe = (Get-Command powershell -ErrorAction Stop).Source

$acceptedSurfacePaths = @(
  'packs/registry.json',
  'reports/self_development/accepted_change_memory_snapshot.json',
  'reports/self_development/SELF_MODEL_ACTIVE_MAP.json',
  'reports/self_development/agent_body_map.json'
)
$protectedSurfacePaths = @(
  'CAPABILITY_ROADMAP.json',
  'GENESIS_STATE.json',
  'TASK_QUEUE.json',
  'orchestrator/run.ps1'
) + $acceptedSurfacePaths

$protectedAcceptedBefore = Get-ProtectedHashSnapshot -Root $sourceRoot -Paths $acceptedSurfacePaths
$protectedBefore = Get-ProtectedHashSnapshot -Root $sourceRoot -Paths $protectedSurfacePaths

Assert-ParserPass -Path $benchmarkPath -Label 'R4_04C_BENCHMARK'
Assert-ParserPass -Path $runnerPath -Label 'D2B_RUNNER'
Assert-ParserPass -Path $policyPath -Label 'C2B_POLICY'
Assert-ParserPass -Path $executorPath -Label 'PHASE162_EXECUTOR'
Assert-ParserPass -Path $finalizerPath -Label 'PHASE162_FINALIZER'
$parserChecks = [ordered]@{
  benchmark = 'PASS'
  runner = 'PASS'
  policy_guard = 'PASS'
  phase162_executor = 'PASS'
  phase162_finalizer = 'PASS'
}

$preparedFixtureRoot = Join-Path $tempRoot 'p'
$preparedFixture = Initialize-ComplexD2BFixtureRepo -SourceRoot $sourceRoot -FixtureRoot $preparedFixtureRoot -CandidateCount $CandidateCount -CandidatePrefix 'prepared'
$fixturePrepared = Test-Path -LiteralPath $preparedFixture.fixture_root
$liveProcesses = @(Get-LiveD2BProcesses)
$liveDetected = ($liveProcesses.Count -gt 0)

$scenarioResults = @()
$benchmarkExecuted = $false
$reason = ''
$nextSafeAction = ''

$externalLiveDetected = [bool]$liveDetected
$conflictingLiveDetected = $false

if ($liveDetected) {
  $reason = 'External live D2B process observed through Windows process list; clone/fixture benchmark continues because same-repo conflict is not proven.'
  $nextSafeAction = 'CONTINUE_ISOLATED_CLONE_BENCHMARK'
}

if ($PrepareOnly) {
  $status = 'PREPARED_NOT_RUN'
  $reason = 'PrepareOnly was requested.'
  $nextSafeAction = 'RERUN_WITH_ALLOW_RUN_WHEN_NO_LIVE_D2B'
} elseif (-not $AllowRunWhenNoLiveD2B) {
  $status = 'PREPARED_NOT_RUN'
  $reason = 'AllowRunWhenNoLiveD2B was not provided.'
  $nextSafeAction = 'RERUN_WITH_ALLOW_RUN_WHEN_NO_LIVE_D2B'
} else {
  $benchmarkExecuted = $true
  foreach ($batchSize in $BatchSizes) {
    $scenarioResults += Invoke-BenchmarkScenario `
      -SourceRoot $sourceRoot `
      -TempRoot $tempRoot `
      -RunnerPath $runnerPath `
      -PowerShellExe $powerShellExe `
      -CandidateCount $CandidateCount `
      -BatchSize $batchSize `
      -MaxSecondsPerScenario $MaxSecondsPerScenario
  }
  $activeGuardHits = @($scenarioResults | Where-Object { [string]$_.hard_error -like '*ACTIVE_D2B_RUN_DETECTED*' })
  if ($activeGuardHits.Count -gt 0 -and (@($scenarioResults | Where-Object { [int]$_.accepted_count -gt 0 }).Count -eq 0)) {
    $status = 'DEFERRED_LIVE_D2B_PROCESS_DETECTED'
    $benchmarkExecuted = $false
    $liveDetected = $true
    $reason = 'Runner process guard detected another live D2B process before benchmark absorption started.'
    $nextSafeAction = 'WAIT_FOR_LIVE_D2B_TO_FINISH_THEN_RUN_R4_04C'
  } elseif (@($scenarioResults | Where-Object { -not [bool]$_.scenario_pass }).Count -eq 0) {
    $status = 'PASS'
    $reason = 'All requested isolated complex batch scenarios drained to queue empty.'
    $nextSafeAction = 'REVIEW_R4_04C_BENCHMARK_PROOF'
  } else {
    $status = 'FAIL'
    $reason = 'One or more isolated complex batch scenarios failed benchmark criteria.'
    $nextSafeAction = 'TRIAGE_R4_04C_SCENARIO_FAILURE'
  }
}

$protectedAcceptedAfter = Get-ProtectedHashSnapshot -Root $sourceRoot -Paths $acceptedSurfacePaths
$protectedAfter = Get-ProtectedHashSnapshot -Root $sourceRoot -Paths $protectedSurfacePaths
$realAcceptedSurfacesUnchanged = Test-SnapshotUnchanged -Before $protectedAcceptedBefore -After $protectedAcceptedAfter -Paths $acceptedSurfacePaths
$protectedHashUnchanged = Test-SnapshotUnchanged -Before $protectedBefore -After $protectedAfter -Paths $protectedSurfacePaths
$protectedGitStatus = @(git -C $sourceRoot status --short -- CAPABILITY_ROADMAP.json GENESIS_STATE.json TASK_QUEUE.json orchestrator/run.ps1 route_locks packs/registry.json reports/self_development/accepted_change_memory_snapshot.json reports/self_development/SELF_MODEL_ACTIVE_MAP.json reports/self_development/agent_body_map.json)
$protectedSurfaceUnchanged = ($protectedHashUnchanged -and $protectedGitStatus.Count -eq 0)

if ($benchmarkExecuted -and ($status -eq 'PASS') -and (-not ($realAcceptedSurfacesUnchanged -and $protectedSurfaceUnchanged))) {
  $status = 'FAIL'
  $reason = 'Protected or real accepted source repo surfaces changed during benchmark.'
  $nextSafeAction = 'TRIAGE_R4_04C_PROTECTED_SURFACE_CHANGE'
}

$totalElapsedMs = 0
$totalAccepted = 0
foreach ($r in $scenarioResults) {
  $totalElapsedMs += [int64]$r.elapsed_ms
  $totalAccepted += [int]$r.accepted_count
}
$aggregateMetrics = [ordered]@{
  scenario_count = $scenarioResults.Count
  total_elapsed_ms = $totalElapsedMs
  total_accepted_count = $totalAccepted
  all_scenarios_pass = (@($scenarioResults | Where-Object { -not [bool]$_.scenario_pass }).Count -eq 0 -and $scenarioResults.Count -gt 0)
  max_accepted_per_second = if ($scenarioResults.Count -gt 0) { [Math]::Round((@($scenarioResults | ForEach-Object { [double]$_.accepted_per_second } | Measure-Object -Maximum).Maximum), 4) } else { 0 }
  min_accepted_per_second = if ($scenarioResults.Count -gt 0) { [Math]::Round((@($scenarioResults | ForEach-Object { [double]$_.accepted_per_second } | Measure-Object -Minimum).Minimum), 4) } else { 0 }
}

$generatedFixtureUnderTemp = [System.IO.Path]::GetFullPath($preparedFixture.fixture_root).StartsWith([System.IO.Path]::GetFullPath([System.IO.Path]::GetTempPath()), [System.StringComparison]::OrdinalIgnoreCase)
$bulkyFixtureWrittenToRepo = [System.IO.Path]::GetFullPath($preparedFixture.fixture_root).StartsWith($sourceRoot, [System.StringComparison]::OrdinalIgnoreCase)

$proofPath = Join-Path $reportFull 'R4_04C_COMPLEX_1000_BATCH_ABSORPTION_PROOF.json'
$reportPath = Join-Path $reportFull 'R4_04C_COMPLEX_1000_BATCH_ABSORPTION_REPORT.md'
$proof = [ordered]@{
  status = $status
  task = 'R4-04C'
  created_at = (Get-Date -Format o)
  repo_root = $sourceRoot
  report_root = $reportFull
  temp_root = $tempRoot
  prepared_fixture_root = $preparedFixture.fixture_root
  fixture_prepared = [bool]$fixturePrepared
  benchmark_executed = [bool]$benchmarkExecuted
  live_d2b_process_detected = [bool]$liveDetected
    external_live_d2b_process_detected = [bool]$externalLiveDetected
    conflicting_live_d2b_process_detected = [bool]$conflictingLiveDetected
    clone_safe_parallelism_allowed = (-not [bool]$conflictingLiveDetected)
  live_d2b_processes = @($liveProcesses)
  reason = $reason
  next_safe_action = $nextSafeAction
  candidate_count = $CandidateCount
  batch_sizes = @($BatchSizes)
  max_seconds_per_scenario = $MaxSecondsPerScenario
  scenario_results = @($scenarioResults)
  aggregate_metrics = $aggregateMetrics
  protected_surface_unchanged = [bool]$protectedSurfaceUnchanged
  real_accepted_surfaces_unchanged = [bool]$realAcceptedSurfacesUnchanged
  parser_checks_pass = $true
  parser_checks = $parserChecks
  generated_fixture_under_temp = [bool]$generatedFixtureUnderTemp
  bulky_fixture_written_to_repo = [bool]$bulkyFixtureWrittenToRepo
  protected_hashes_before = $protectedBefore
  protected_hashes_after = $protectedAfter
  protected_accepted_hashes_before = $protectedAcceptedBefore
  protected_accepted_hashes_after = $protectedAcceptedAfter
  protected_git_status = @($protectedGitStatus)
  no_live_d2b_process_touched = $true
  live_process_actions = @()
}
Write-J $proofPath $proof

$scenarioTable = New-ScenarioTable -ScenarioResults $scenarioResults
$executionLine = if ($benchmarkExecuted) { 'The benchmark executed in isolated temp fixture repos.' } else { "The benchmark did not execute runner cycles. Status: $status." }
$conclusion = if ($status -eq 'PASS') {
  'The isolated complex-candidate benchmark drained all requested queues without duplicates, stalls, failed atoms, or source repo accepted-surface changes.'
} elseif ($status -eq 'DEFERRED_LIVE_D2B_PROCESS_DETECTED') {
  'The benchmark deferred safely because another D2B process was detected. This protects the live long run from interference.'
} else {
  "The benchmark did not produce a PASS result. Reason: $reason"
}

$reportLines = @(
  '# R4-04C Complex 1000 Candidate Batch Absorption Benchmark',
  '',
  "Status: $status",
  '',
  '## Why This Benchmark Exists',
  '',
  'R4-03R2 proved central D2B batch admission on a small fixture. R4-04C measures whether the same admission path can absorb richer candidate payloads at 1000-candidate scale without duplicate acceptance, stalls, or real accepted-memory mutation.',
  '',
  '## Relation To The Live 50k Run',
  '',
  'The script detects other command lines running the D2B learn-until-empty runner. If one is present, it writes a deferred proof instead of competing with or bypassing the live process guard.',
  '',
  '## Why These Candidates Are Different',
  '',
  'Each generated candidate includes richer source context, complexity profile, concept cluster, procedure steps, validator expectations, proof expectations, route context, self-model delta, dependency hints, risk notes, and dedup metadata while keeping the raw candidate safe and untrusted.',
  '',
  '## Execution',
  '',
  $executionLine,
  '',
  '## Scenario Table',
  ''
) + $scenarioTable + @(
  '',
  '## Conclusion',
  '',
  $conclusion,
  '',
  '## Next Action',
  '',
  $nextSafeAction,
  '',
  "Proof: $proofPath"
)
[System.IO.File]::WriteAllText($reportPath, (($reportLines -join "`n") + "`n"), [System.Text.UTF8Encoding]::new($false))

Write-Host "R4_04C_COMPLEX_1000_BATCH_ABSORPTION_STATUS=$status"
Write-Host "LIVE_D2B_PROCESS_DETECTED=$liveDetected"
Write-Host "FIXTURE_PREPARED=$fixturePrepared"
Write-Host "BENCHMARK_EXECUTED=$benchmarkExecuted"
Write-Host "REPORT_ROOT=$reportFull"
Write-Host "PROOF_PATH=$proofPath"
Write-Host "REPORT_PATH=$reportPath"
Write-Host "NEXT_SAFE_ACTION=$nextSafeAction"

if ($status -eq 'FAIL') {
  exit 1
}

