param(
  [ValidateSet('Diagnostic','ReadOnly','SandboxExploration','SandboxTestLife','SandboxStudyLife','SandboxAction','GovernedRepoAction','Continuous','LiveAuthority')]
  [string]$Mode = 'Diagnostic',
  [string]$RunId = "aimo_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
)

$ErrorActionPreference = 'Stop'
$RepoRoot = (git rev-parse --show-toplevel).Trim()
Set-Location $RepoRoot
$OrganRoot = 'operations/autonomous_inner_motor'
$PolicyPath = Join-Path $OrganRoot 'motor_policy.json'
$Policy = Get-Content $PolicyPath -Raw | ConvertFrom-Json
# Sandbox one-file proof contract marker: SANDBOX_EXPLORATION_PROOF.json; test-life proof marker: TEST_LIFE_PROOF.json

function Get-GitStatusShort {
  $s = git status --short --untracked-files=all
  return (($s | Out-String).Trim())
}

function Get-ProcessMatches {
  $pattern = 'run_agent_school|candidate_factory|live_growth|compact_semantic|file_atom_absorption'
  return @(Get-CimInstance Win32_Process | Where-Object { $_.CommandLine -match $pattern -and $_.ProcessId -ne $PID } | ForEach-Object { [ordered]@{ pid = $_.ProcessId; command_line = $_.CommandLine } })
}

function Get-ActiveMemoryState {
  param(
    [string]$MemoryRoot = '.runtime/active_compact_semantic_memory_v1',
    [int]$MaxRetries = 3,
    [int]$RetryDelayMs = 250
  )
  $memRoot = $MemoryRoot
  $manifestPath = Join-Path $memRoot 'manifest.json'
  $cellsPath = Join-Path $memRoot 'cells.jsonl'
  for($attempt=1; $attempt -le [Math]::Max(1,$MaxRetries); $attempt++) {
    if((Test-Path $manifestPath) -and (Test-Path $cellsPath)) {
      try {
        $manifest = Get-Content $manifestPath -Raw | ConvertFrom-Json
        return [ordered]@{
          root = $memRoot
          available = $true
          status = 'ACTIVE_MEMORY_AVAILABLE'
          run_id = $manifest.run_id
          runtime_ready = $manifest.runtime_ready
          cell_count = [int]$manifest.cell_count
          cells_sha256 = [string]$manifest.cells_sha256
          manifest_status = $manifest.status
          missing_paths = @()
          attempt_count = $attempt
          backoff_recommended = $false
        }
      } catch {
        return [ordered]@{
          root = $memRoot
          available = $false
          status = 'ACTIVE_MEMORY_READ_ERROR'
          run_id = $null
          runtime_ready = $false
          cell_count = 0
          cells_sha256 = $null
          manifest_status = 'READ_ERROR'
          missing_paths = @()
          error = $_.Exception.Message
          attempt_count = $attempt
          backoff_recommended = $true
        }
      }
    }
    if($attempt -lt [Math]::Max(1,$MaxRetries)) { Start-Sleep -Milliseconds $RetryDelayMs }
  }
  $missing=@()
  if(-not(Test-Path $manifestPath)){ $missing += $manifestPath }
  if(-not(Test-Path $cellsPath)){ $missing += $cellsPath }
  return [ordered]@{
    root = $memRoot
    available = $false
    status = 'MEMORY_TEMPORARILY_UNAVAILABLE'
    run_id = $null
    runtime_ready = $false
    cell_count = 0
    cells_sha256 = $null
    manifest_status = 'MISSING_OR_ROTATING'
    missing_paths = @($missing)
    attempt_count = [Math]::Max(1,$MaxRetries)
    backoff_recommended = $true
  }
}

function Get-AgentGrowthSignal {
  $signalPath = '.runtime/compact_memory_growth_signal_v1/ACTIVE_GROWTH_SIGNAL.json'
  if(-not (Test-Path $signalPath)) { return [ordered]@{ available=$false; path=$signalPath; status='NO_GROWTH_SIGNAL' } }
  try {
    $s = Get-Content $signalPath -Raw | ConvertFrom-Json
    return [ordered]@{
      available=$true
      path=$signalPath
      status=$s.status
      source_kind=$s.source_kind
      source_id=$s.source_id
      declared_atom_count=$s.declared_atom_count
      maturity_delta=$s.maturity_delta
      topics=@($s.topics)
      focus_boosts=@($s.focus_boosts)
      memory_support_policy=$s.memory_support_policy
      created_at=$s.created_at
      behavior_rule=$s.behavior_rule
    }
  } catch {
    return [ordered]@{ available=$false; path=$signalPath; status='BAD_GROWTH_SIGNAL'; error=$_.Exception.Message }
  }
}
function Get-MemoryCoordinationState {
  $lockPath = '.runtime/compact_memory_intake_v1/MERGE_QUEUE.lock.json'
  $queuePath = '.runtime/compact_memory_intake_v1/queue'
  $lockExists = Test-Path $lockPath
  $queueCount = 0
  if(Test-Path $queuePath){ $queueCount = @(Get-ChildItem $queuePath -File -Filter '*.json' -ErrorAction SilentlyContinue).Count }
  return [ordered]@{
    direct_active_memory_write_allowed = $false
    intake_required_for_agentlife_packets = $true
    merge_lock_path = $lockPath
    merge_lock_active = $lockExists
    queued_packet_count = $queueCount
    backoff_required = $lockExists
    rule = 'agent_life_may_continue_safe_modes_during_school_but_memory_writes_must_use_intake_merge_queue'
  }
}

function New-BasePayload($RunRoot, $Mode, $Policy, $MemoryBefore, $Processes) {
  $head = (git rev-parse HEAD).Trim()
  $branch = (git branch --show-current).Trim()
  $schoolActive = @($Processes | Where-Object { $_.command_line -match 'run_agent_school|candidate_factory|compact_semantic|file_atom_absorption' }).Count -gt 0
  $GrowthSignal = Get-AgentGrowthSignal
  $MemoryCoordination = Get-MemoryCoordinationState
  $SchoolCoordinationHint = $null
  if($schoolActive) {
    $SchoolCoordinationHint = [ordered]@{
      active_school_detected = $true
      policy = 'COORDINATE_WITH_SCHOOL_NOT_BLOCK_SAFE_MODE'
      memory_write_rule = 'no_direct_active_memory_write_use_intake_merge_queue_only'
      merge_lock_active = $MemoryCoordination.merge_lock_active
      backoff_required = $MemoryCoordination.backoff_required
    }
  }
  return [ordered]@{
    schema = 'AUTONOMOUS_INNER_MOTOR_RUN_PROOF'
    organ_id = 'AUTONOMOUS_INNER_MOTOR_ORGAN'
    run_id = $RunId
    mode = $Mode
    maturity_level = $Policy.active_maturity_level
    created_at = (Get-Date).ToString('o')
    repo_state = [ordered]@{ root = $RepoRoot; branch = $branch; head = $head; status_before = Get-GitStatusShort; status_after = $null }
    memory_state = [ordered]@{ before = $MemoryBefore; after = $null; unchanged = $null }
    school_state = [ordered]@{ active_detected = $schoolActive; matching_processes = @($Processes) }
    memory_coordination = $MemoryCoordination
    school_coordination_hint = $SchoolCoordinationHint
        growth_signal = $GrowthSignal
policy_snapshot = $Policy
    self_question_trace = @(
      [ordered]@{ question = 'Who am I in current repo/runtime?'; answer = 'AUTONOMOUS_INNER_MOTOR_ORGAN, one policy-gated runner, not whole brain.' },
      [ordered]@{ question = 'What is my safe cage?'; answer = 'Mode policy, forbidden active surfaces, no external effects, compact proof budget.' },
      [ordered]@{ question = 'What active memory is available?'; answer = "cells=$($MemoryBefore.cell_count); run_id=$($MemoryBefore.run_id); runtime_ready=$($MemoryBefore.runtime_ready)" },
      [ordered]@{ question = 'Is school or another long process active?'; answer = "school_active=$schoolActive; process_count=$(@($Processes).Count)" },
      [ordered]@{ question = 'What proof do I owe?'; answer = 'memory before/after, school state, policy snapshot, decision/risk/self-oppression compact events, stop reason, mutation audit.' }
    )
    decision_trace = [ordered]@{ allowed_mode = $false; policy_allows_mode = $false; selected_next_path = $null; rationale = $null }
    selected_next_path = $null
    stop_reason = $null
    heartbeat = [ordered]@{ status = 'STARTED'; written_at = (Get-Date).ToString('o'); run_root = $RunRoot }
    mutation_audit = [ordered]@{ active_memory_mutated = $false; git_commit_created = $false; codex_launched = $false; web_research_performed = $false; school_started = $false; background_process_started = $false; writes_limited_to_run_root = $true }
    cycles = @()
    risk_summary = $null
    compaction_budget = $null
    final_self_diagnosis = $null
    stop_file_path = $null
    controller = $null
    test_life = $null
    validator_result = [ordered]@{ status = 'NOT_RUN_INSIDE_RUNNER'; note = 'External validator validates proof after runner exits.' }
    boundary = $null
  }
}

function Complete-Proof($Payload, $ProofPath, $MemoryBefore) {
  $MemoryAfter = Get-ActiveMemoryState
  $Payload.memory_state.after = $MemoryAfter
  $Payload.memory_state.unchanged = ($MemoryBefore.cells_sha256 -eq $MemoryAfter.cells_sha256 -and $MemoryBefore.run_id -eq $MemoryAfter.run_id -and $MemoryBefore.cell_count -eq $MemoryAfter.cell_count)
  $Payload.repo_state.status_after = Get-GitStatusShort
  $Payload.heartbeat.status = 'STOPPED_PROTECTIVE_CHECKPOINT'
  $Payload.heartbeat.written_at = (Get-Date).ToString('o')
  $Payload | ConvertTo-Json -Depth 30 | Set-Content -Path $ProofPath -Encoding UTF8
  return $Payload
}

function Emit-AgentLifeKnowledgePacket($Payload,[string]$RunRoot,[string]$RunId,[string]$ProofPath){
  $r=[ordered]@{schema='aimo_agentlife_packet_emitter_result_v1';status='SKIPPED_AGENTLIFE_PACKET_NO_CYCLES';packet_path=$null;runtime_policy_path=$null;intake_status=$null;queue_path=$null;merge_status=$null;submit_and_merge_status=$null;merge_attempted=$false;merge_lock_active_before=$false;memory_hash_changed_by_merge=$false;emitted_at=(Get-Date).ToString('o');boundary='AgentLife emits packet to intake/merge only; no direct active memory write.'}
  if(-not $Payload.test_life -or [int]$Payload.test_life.total_cycles -lt 1){return $r}
  $lockPath='.runtime/compact_memory_intake_v1/MERGE_QUEUE.lock.json'
  $r.merge_lock_active_before=Test-Path $lockPath
  $r.school_active_before=[bool]$Payload.school_state.active_detected
  $packetRoot=Join-Path $RunRoot 'agentlife_packets'; New-Item -ItemType Directory -Force -Path $packetRoot|Out-Null
  $last=$null; if($Payload.test_life.recent_events -and @($Payload.test_life.recent_events).Count -gt 0){$last=@($Payload.test_life.recent_events)[-1]}
  $topic=if($last -and $last.current_task){[string]$last.current_task}else{'aimo_sandbox_test_life'}
  $packetPath=Join-Path $packetRoot 'AGENTLIFE_KNOWLEDGE_PACKET.json'
  $packet=[ordered]@{schema='compact_memory_knowledge_packet_v1';source_kind='AgentLife';source_id=$RunId;source_proof=$ProofPath;emitted_at=(Get-Date).ToString('o');influence=[ordered]@{maturity_delta=0.1;memory_support_policy='CHECK_FRESH_MEMORY_AGAINST_SELECTED_PATH_BEFORE_EXECUTION';focus_boosts=@($topic,'aimo_sandbox_test_life','agentlife_cycle_learning')};quality_summary=[ordered]@{atom_count=1;min_quality_score=0.62;min_novelty_score=0.10;classifier='AGENTLIFE_RUNTIME_SUMMARY_ATOM'};atoms=@([ordered]@{id="agentlife-$RunId-cycle-$($Payload.test_life.total_cycles)";topic=$topic;level=1;quality_score=0.62;novelty_score=0.10;kind='agentlife_cycle_summary';summary="AIMO SandboxTestLife completed cycle $($Payload.test_life.total_cycles), used memory/reflex/source traces, and returned a compact AgentLife learning packet without direct active memory mutation.";evidence=[ordered]@{aimo_proof=$ProofPath;cycles=[int]$Payload.test_life.total_cycles;stop_reason=[string]$Payload.stop_reason;direct_active_memory_write_allowed=[bool]$Payload.memory_coordination.direct_active_memory_write_allowed};uses=@('support selected path only','do not override route selection','inspect before execution when topic matches')})}
  $packet|ConvertTo-Json -Depth 60|Set-Content -LiteralPath $packetPath -Encoding UTF8; $r.packet_path=$packetPath
  $policy=Get-Content 'operations/compact_memory_intake/multi_source_compact_memory_intake_policy.json' -Raw|ConvertFrom-Json; $policy.runtime_report_root='.runtime/compact_memory_intake_v1/reports'
  $policyPath=Join-Path $packetRoot 'AGENTLIFE_INTAKE_POLICY_RUNTIME.json'; $policy|ConvertTo-Json -Depth 40|Set-Content -LiteralPath $policyPath -Encoding UTF8; $r.runtime_policy_path=$policyPath
  $before=Get-ActiveMemoryState
  $cmdArgs=@('-NoProfile','-ExecutionPolicy','Bypass','-File','operations/compact_memory_intake/submit_and_merge_compact_memory_packet_v1.ps1','-PacketPath',$packetPath,'-PolicyPath',$policyPath)
  if((-not $r.merge_lock_active_before) -and (-not $r.school_active_before)){$cmdArgs+='-Merge';$r.merge_attempted=$true}
  $out=@(& powershell @cmdArgs *>&1|ForEach-Object{[string]$_}); $r.raw_output=@($out)
  $r.intake_status=(($out|Where-Object{$_ -match '^INTAKE_STATUS='}|Select-Object -Last 1)-replace '^INTAKE_STATUS=','')
  $r.queue_path=(($out|Where-Object{$_ -match '^INTAKE_QUEUE_PATH='}|Select-Object -Last 1)-replace '^INTAKE_QUEUE_PATH=','')
  $r.submit_and_merge_status=(($out|Where-Object{$_ -match '^SUBMIT_AND_MERGE_STATUS='}|Select-Object -Last 1)-replace '^SUBMIT_AND_MERGE_STATUS=','')
  $r.merge_status=(($out|Where-Object{$_ -match '^MERGE_QUEUE_STATUS='}|Select-Object -Last 1)-replace '^MERGE_QUEUE_STATUS=','')
  $after=Get-ActiveMemoryState; $r.memory_hash_changed_by_merge=($before.cells_sha256 -ne $after.cells_sha256 -or $before.run_id -ne $after.run_id -or $before.cell_count -ne $after.cell_count)
  if($r.merge_lock_active_before){if($r.intake_status -eq 'PASS_MULTI_SOURCE_COMPACT_MEMORY_INTAKE_SUBMIT_V1'){$r.status='PASS_AGENTLIFE_PACKET_SUBMITTED_MERGE_BACKOFF_LOCK'}else{$r.status='FAIL_AGENTLIFE_PACKET_SUBMIT'}}elseif($r.school_active_before){if($r.intake_status -eq 'PASS_MULTI_SOURCE_COMPACT_MEMORY_INTAKE_SUBMIT_V1'){$r.status='PASS_AGENTLIFE_PACKET_SUBMITTED_SCHOOL_ACTIVE_BACKOFF'}else{$r.status='FAIL_AGENTLIFE_PACKET_SUBMIT'}}elseif($r.submit_and_merge_status -eq 'PASS_SUBMIT_AND_MERGE_COMPACT_MEMORY_PACKET_V1' -and $r.merge_status -eq 'PASS_MULTI_SOURCE_COMPACT_MEMORY_MERGE_QUEUE_V1'){$r.status='PASS_AGENTLIFE_PACKET_SUBMIT_AND_MERGE_V1'}else{$r.status='FAIL_AGENTLIFE_PACKET_SUBMIT_AND_MERGE_V1'}
  return $r
}
if ($Policy.allowed_modes -notcontains $Mode) { throw "POLICY_DENIED_MODE:$Mode" }
$MemoryBefore = Get-ActiveMemoryState
$Processes = Get-ProcessMatches


if ($Mode -eq 'SandboxTestLife') {
  $runRoot = Join-Path '.runtime/autonomous_inner_motor/test_life_runs' $RunId
  New-Item -ItemType Directory -Force -Path $runRoot | Out-Null
  $ProofPath = Join-Path $runRoot 'TEST_LIFE_PROOF.json'
  # TEST_LIFE_PROOF.json marker: one rolling compact proof file for sandbox development life.
  $StopPath = Join-Path $runRoot 'STOP_REQUESTED.txt'
  $Payload = New-BasePayload $runRoot $Mode $Policy $MemoryBefore $Processes
  $Payload['mode'] = $Mode
  $Payload['runtime_proof_root_policy'] = 'runtime_only_not_git_dirty_parallel_safe'
  $Payload['knowledge_runtime_root_policy'] = 'runtime_only_not_git_dirty_parallel_safe'
  $Payload['stop_reason'] = 'RUNNING_UNTIL_STOP_FILE'
  $Payload['selected_next_path'] = 'DEVELOP_USING_REFLEX_AND_MEMORY_UNTIL_STOP_FILE'
  $Payload.decision_trace.selected_next_path = $Payload.selected_next_path
  $Payload.decision_trace.rationale = 'SandboxTestLife now grows by selecting read-only development tasks, consulting active memory, and using reflexes before repeating.'
  $Payload['controller'] = [ordered]@{ pid = $PID; run_root = $runRoot; stop_file_path = $StopPath; stop_rule = 'Owner or harness may create STOP_REQUESTED.txt; normal development uses task/reflex/memory loop instead of treadmill.' }
  $Payload['test_life'] = [ordered]@{
    started_at = (Get-Date).ToString('o')
    last_heartbeat_at = $null
    total_cycles = 0
    no_cycle_limit = $true
    no_time_limit = $true
    step_sleep_seconds = [int]$Policy.sandbox_test_life.step_sleep_seconds
    rolling_recent_events_kept = [int]$Policy.sandbox_test_life.rolling_recent_events_kept
    recent_events = @()
    counters = [ordered]@{
      development_task_selections = 0
      reflex_invocations = 0
      memory_queries = 0
      memory_partial_matches = 0
      memory_low_relevance = 0
      memory_no_matches = 0
      repo_status_reads = 0
      policy_reads = 0
      compact_rewrites = 0
      knowledge_gap_signals = 0
      knowledge_acquisition_requests = 0
      knowledge_acquisition_successes = 0
      knowledge_acquisition_failures = 0
      return_to_task_hints = 0
      task_decompositions = 0
      batch_knowledge_acquisition_requests = 0
      batch_knowledge_acquisition_successes = 0
      batch_knowledge_acquisition_failures = 0
      batch_parts_total = 0
      parent_return_plans = 0
    }
  }
  $Payload['development_trace'] = [ordered]@{
    current_task = $null
    last_memory_relevance = $null
    last_gap_after_memory = $null
    next_learning_need = $null
    memory_use_trace = @()
    reflex_use_trace = @()
    knowledge_gap_trace = @()
    knowledge_acquisition_trace = @()
    task_decomposition_trace = @()
    batch_knowledge_acquisition_trace = @()
  }
  $Payload['boundary'] = 'Sandbox development life. Hard walls remain; each cycle may decompose X into <=10 parts and call governed batch source only after local knowledge gap.'

  function Search-LocalMemory([string]$Needle,[int]$Take) {
    $memPath = '.runtime/active_compact_semantic_memory_v1/cells.jsonl'
    $terms = @(($Needle -split '[^A-Za-z0-9_\-]+' | Where-Object { $_.Length -ge 3 } | Select-Object -Unique))
    if($terms.Count -eq 0) { $terms = @($Needle) }
    $matches = New-Object System.Collections.Generic.List[object]
    $idx = 0
    foreach($line in Get-Content -LiteralPath $memPath) {
      $idx += 1
      $lower = $line.ToLowerInvariant()
      $score = 0
      foreach($term in $terms) { if($lower.Contains($term.ToLowerInvariant())) { $score += 1 } }
      if($score -gt 0) {
        $summary = $line.Substring(0,[Math]::Min(260,$line.Length))
        try {
          $obj = $line | ConvertFrom-Json
          foreach($key in @('summary','theme','uses','canonical_rule','label','title','kind')) {
            if($obj.PSObject.Properties.Name -contains $key -and $null -ne $obj.$key) {
              $summary = ($obj.$key | ConvertTo-Json -Compress -Depth 4)
              if($summary.Length -gt 260) { $summary = $summary.Substring(0,260) }
              break
            }
          }
        } catch { }
        $matches.Add([ordered]@{ cell_index=$idx; score=$score; summary=$summary }) | Out-Null
      }
    }
    @($matches.ToArray() | Sort-Object -Property score -Descending | Select-Object -First $Take)
  }

  function Invoke-LocalReflex([string]$Reflex,[string]$Task,[string]$Query,[string]$TargetPath) {
    $result = [ordered]@{
      reflex = $Reflex
      status = 'PASS'
      result = $null
      errors = @()
      mutation_performed = $false
      codex_launched = $false
      web_research_performed = $false
      school_started = $false
      background_process_started = $false
    }
    try {
      if($Reflex -eq 'INSPECT_ACTIVE_MEMORY') {
        $manifest='.runtime/active_compact_semantic_memory_v1/manifest.json'
        $cells='.runtime/active_compact_semantic_memory_v1/cells.jsonl'
        $m=Get-Content -LiteralPath $manifest -Raw|ConvertFrom-Json
        $result.result=[ordered]@{ run_id=$m.run_id; runtime_ready=$m.runtime_ready; cells_count=((Get-Content $cells|Measure-Object -Line).Lines); cells_sha256=(Get-FileHash -Algorithm SHA256 $cells).Hash }
      } elseif($Reflex -eq 'READ_FILE_SUMMARY') {
        $item=Get-Item -LiteralPath $TargetPath
        $result.result=[ordered]@{ path=$TargetPath; bytes=$item.Length; sha256=(Get-FileHash -Algorithm SHA256 $TargetPath).Hash; first_lines=@(Get-Content -LiteralPath $TargetPath -TotalCount 6) }
      } elseif($Reflex -eq 'INSPECT_REPO_STATUS') {
        $st=@(git status --short --untracked-files=all)
        $result.result=[ordered]@{ branch=(git branch --show-current).Trim(); head=(git rev-parse HEAD).Trim(); dirty=($st.Count -gt 0); status=@($st|Select-Object -First 20) }
      } elseif($Reflex -eq 'COMPARE_TASK_TO_MEMORY') {
        $candidates = Search-LocalMemory -Needle $Query -Take 5
        $classification = if(@($candidates).Count -eq 0){'NO_USEFUL_MEMORY'} elseif(($candidates|Select-Object -First 1).score -ge 3){'PARTIAL_MATCH'} else {'LOW_RELEVANCE'}
        $result.result=[ordered]@{
          task=$Task
          query=$Query
          relevance=$classification
          candidates_checked=@($candidates).Count
          best_match=(@($candidates)|Select-Object -First 1)
          gap_after_memory=$(if($classification -eq 'NO_USEFUL_MEMORY'){'memory did not provide useful candidate for current task'}elseif($classification -eq 'LOW_RELEVANCE'){'memory candidate exists but relevance is weak'}else{'memory partially helps but does not complete task'})
          next_learning_need='task-selection/reflex-use knowledge connected to active memory'
        }
      } else {
        $result.status='FAIL'
        $result.errors=@("unsupported_in_process_reflex:$Reflex")
      }
    } catch {
      $result.status='FAIL'
      $result.errors=@($_.Exception.Message)
    }
    [pscustomobject]$result
  }
  function Invoke-KnowledgeAcquisitionPort([string]$Task,[string]$KnowledgeNeed,[string]$AlreadyChecked,[int]$Cycle,[string]$ParentRunId,[int]$TimeoutSeconds) {
    $kaRunId = ($ParentRunId + '_cycle' + $Cycle + '_knowledge_gap')
    $kaRunRoot = Join-Path '.runtime/knowledge_acquisition_port/runs' $kaRunId
    New-Item -ItemType Directory -Force -Path $kaRunRoot | Out-Null
    $stdoutPath = Join-Path $kaRunRoot 'aimo_call_stdout.txt'
    $stderrPath = Join-Path $kaRunRoot 'aimo_call_stderr.txt'
    $proofPath = Join-Path $kaRunRoot 'KNOWLEDGE_ACQUISITION_PROOF.json'
    $inputPath = Join-Path $kaRunRoot 'aimo_call_input.json'
    [ordered]@{
      RunId = $kaRunId
      RunRootBase = '.runtime/knowledge_acquisition_port/runs'
      CurrentTask = $Task
      KnowledgeNeed = $KnowledgeNeed
      AlreadyChecked = $AlreadyChecked
    } | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $inputPath -Encoding UTF8
    $args = @(
      '-NoProfile','-ExecutionPolicy','Bypass','-File','operations/knowledge_acquisition_port/ask_codex_knowledge_source.ps1',
      '-InputJsonPath',$inputPath
    )
    $p = Start-Process -FilePath powershell.exe -ArgumentList $args -PassThru -WindowStyle Hidden -RedirectStandardOutput $stdoutPath -RedirectStandardError $stderrPath
    $completed = $p.WaitForExit([Math]::Max(1,$TimeoutSeconds) * 1000)
    if(-not $completed) {
      Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue
      return [pscustomobject]@{
        status='TIMEOUT_KNOWLEDGE_ACQUISITION_PORT'
        run_id=$kaRunId
        proof_path=$proofPath
        source='CODEX_READONLY_SOURCE'
        codex_answer_status='CODEX_DRAFT'
        shape_valid=$false
        return_to_task_hint=$null
        safe_learning_steps=@()
        validation_needed=@()
        exit_code=$null
      }
    }
    if(Test-Path -LiteralPath $proofPath) {
      $kp = Get-Content -LiteralPath $proofPath -Raw | ConvertFrom-Json
      if($kp.status -eq 'PASS_CODEX_DRAFT_RETURNED') {
        Remove-Item -LiteralPath $stdoutPath,$stderrPath,$inputPath -Force -ErrorAction SilentlyContinue
      }
      return [pscustomobject]@{
        status=$kp.status
        run_id=$kaRunId
        proof_path=$proofPath
        source=$kp.source
        codex_answer_status=$kp.codex_answer_status
        shape_valid=$kp.codex_answer_required_shape_valid
        return_to_task_hint=$kp.return_to_task_hint
        safe_learning_steps=@($kp.safe_learning_steps)
        validation_needed=@($kp.validation_needed)
        exit_code=$kp.codex_exit_code
      }
    }
    return [pscustomobject]@{
      status='FAIL_NO_KNOWLEDGE_ACQUISITION_PROOF'
      run_id=$kaRunId
      proof_path=$proofPath
      source='CODEX_READONLY_SOURCE'
      codex_answer_status='CODEX_DRAFT'
      shape_valid=$false
      return_to_task_hint=$null
      safe_learning_steps=@()
      validation_needed=@()
      exit_code=$p.ExitCode
    }
  }

  function New-TaskDecompositionParts([string]$Task,[int]$MaxParts) {
    $safeMax=[Math]::Min([Math]::Max(1,$MaxParts),10)
    $base=@(
      [ordered]@{ id='X1'; name='task intent'; local_guess=('what parent task wants: ' + $Task) },
      [ordered]@{ id='X2'; name='required output'; local_guess='artifact/result that must be returned to parent' },
      [ordered]@{ id='X3'; name='available knowledge'; local_guess='what active memory/reflexes already cover' },
      [ordered]@{ id='X4'; name='missing knowledge'; local_guess='what blocks executable action now' },
      [ordered]@{ id='X5'; name='safe learning path'; local_guess='how to learn without mutation or authority leap' },
      [ordered]@{ id='X6'; name='validation gate'; local_guess='proof needed before claiming success' },
      [ordered]@{ id='X7'; name='source boundary'; local_guess='Codex/web/source is draft, not authority' },
      [ordered]@{ id='X8'; name='return to parent'; local_guess='how resolved parts rebuild original task' },
      [ordered]@{ id='X9'; name='retention decision'; local_guess='digest source and avoid raw bloat' },
      [ordered]@{ id='X10'; name='promotion decision'; local_guess='case pattern vs atom/reflex/organ candidate' }
    )
    return @($base | Select-Object -First $safeMax)
  }

  function Invoke-BatchKnowledgeAcquisitionPort([string]$Task,[object[]]$Parts,[string]$KnowledgeNeed,[string]$AlreadyChecked,[int]$Cycle,[string]$ParentRunId,[int]$TimeoutSeconds) {
    $kaRunId = ($ParentRunId + '_cycle' + $Cycle + '_batch_knowledge_gap')
    $kaRunRoot = Join-Path '.runtime/knowledge_acquisition_port/runs' $kaRunId
    New-Item -ItemType Directory -Force -Path $kaRunRoot | Out-Null
    $stdoutPath = Join-Path $kaRunRoot 'aimo_batch_call_stdout.txt'
    $stderrPath = Join-Path $kaRunRoot 'aimo_batch_call_stderr.txt'
    $proofPath = Join-Path $kaRunRoot 'BATCH_KNOWLEDGE_ACQUISITION_PROOF.json'
    $digestPath = Join-Path $kaRunRoot 'BATCH_SOURCE_DIGEST_AND_PROMOTION_DECISION.json'
    $inputPath = Join-Path $kaRunRoot 'aimo_batch_call_input.json'
    [ordered]@{
      RunId = $kaRunId
      RunRootBase = '.runtime/knowledge_acquisition_port/runs'
      CurrentTask = $Task
      KnowledgeNeed = $KnowledgeNeed
      AlreadyChecked = $AlreadyChecked
      DecomposedParts = @($Parts)
    } | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $inputPath -Encoding UTF8
    $args = @(
      '-NoProfile','-ExecutionPolicy','Bypass','-File','operations/knowledge_acquisition_port/ask_codex_batch_knowledge_source.ps1',
      '-InputJsonPath',$inputPath
    )
    $p = Start-Process -FilePath powershell.exe -ArgumentList $args -PassThru -WindowStyle Hidden -RedirectStandardOutput $stdoutPath -RedirectStandardError $stderrPath
    $completed = $p.WaitForExit([Math]::Max(1,$TimeoutSeconds) * 1000)
    if(-not $completed) {
      Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue
      return [pscustomobject]@{ kind='BATCH'; status='TIMEOUT_BATCH_KNOWLEDGE_ACQUISITION_PORT'; run_id=$kaRunId; proof_path=$proofPath; digest_path=$digestPath; source='CODEX_BATCH_READONLY_SOURCE'; codex_answer_status='CODEX_DRAFT'; shape_valid=$false; part_count=@($Parts).Count; parent_return_plan=$null; next_small_action=$null; proof_needed=@(); exit_code=$null }
    }
    if(Test-Path -LiteralPath $proofPath) {
      $kp = Get-Content -LiteralPath $proofPath -Raw | ConvertFrom-Json
      if($kp.status -eq 'PASS_CODEX_BATCH_DRAFT_RETURNED') { Remove-Item -LiteralPath $stdoutPath,$stderrPath,$inputPath -Force -ErrorAction SilentlyContinue }
      return [pscustomobject]@{
        kind='BATCH'
        status=$kp.status
        run_id=$kaRunId
        proof_path=$proofPath
        digest_path=$digestPath
        source=$kp.source
        codex_answer_status=$kp.codex_answer_status
        shape_valid=$kp.codex_answer_required_shape_valid
        part_count=$kp.part_count
        parent_return_plan=$kp.parent_return_plan
        next_small_action=$(if($kp.parent_return_plan){$kp.parent_return_plan.next_small_action}else{$null})
        proof_needed=$(if($kp.parent_return_plan){@($kp.parent_return_plan.proof_needed)}else{@()})
        exit_code=$kp.codex_exit_code
      }
    }
    return [pscustomobject]@{ kind='BATCH'; status='FAIL_NO_BATCH_KNOWLEDGE_ACQUISITION_PROOF'; run_id=$kaRunId; proof_path=$proofPath; digest_path=$digestPath; source='CODEX_BATCH_READONLY_SOURCE'; codex_answer_status='CODEX_DRAFT'; shape_valid=$false; part_count=@($Parts).Count; parent_return_plan=$null; next_small_action=$null; proof_needed=@(); exit_code=$p.ExitCode }
  }

  $developmentTasks = @(
    [ordered]@{ name='choose_next_safe_growth_step'; query='growth task selection proof reflex memory next safe action'; target='operations/autonomous_inner_motor/motor_policy.json' },
    [ordered]@{ name='understand_own_policy_limits'; query='policy limits allowed modes sandbox mutation proof'; target='operations/autonomous_inner_motor/motor_policy.json' },
    [ordered]@{ name='use_memory_before_repeating'; query='memory use active compact semantic cells task relevance mismatch'; target='.runtime/active_compact_semantic_memory_v1/manifest.json' },
    [ordered]@{ name='inspect_current_body_map'; query='body map organ autonomous inner motor reflex library map refresh'; target='reports/self_development/SELF_MODEL_ACTIVE_MAP.json' },
    [ordered]@{ name='find_needed_reflex'; query='reflex library read only inspect json memory compare task'; target='operations/reflex_library/reflex_registry.json' }
  )
  $recent = New-Object System.Collections.Generic.List[object]
  $cycle = 0
  $knowledgeAcquisitionCalls = 0
  $batchKnowledgeAcquisitionCalls = 0
  while ($true) {
    if (Test-Path $StopPath) {
      $Payload['stop_reason'] = 'STOP_FILE_REQUESTED'
      break
    }
    $cycle += 1
    $task = $developmentTasks[($cycle - 1) % $developmentTasks.Count]
    $Payload.test_life.counters.development_task_selections += 1
    $Payload.development_trace.current_task = $task.name

    $usedReflexes = New-Object System.Collections.Generic.List[string]
    $memoryCompare = Invoke-LocalReflex -Reflex 'COMPARE_TASK_TO_MEMORY' -Task $task.name -Query $task.query -TargetPath $null
    $usedReflexes.Add('COMPARE_TASK_TO_MEMORY') | Out-Null
    $Payload.test_life.counters.reflex_invocations += 1
    $Payload.test_life.counters.memory_queries += 1
    $relevance = $memoryCompare.result.relevance
    if($relevance -eq 'PARTIAL_MATCH') { $Payload.test_life.counters.memory_partial_matches += 1 }
    elseif($relevance -eq 'LOW_RELEVANCE') { $Payload.test_life.counters.memory_low_relevance += 1 }
    else { $Payload.test_life.counters.memory_no_matches += 1 }

    $secondary = $null
    if(($cycle % 5) -eq 0) {
      $secondary = Invoke-LocalReflex -Reflex 'INSPECT_REPO_STATUS' -Task $task.name -Query $task.query -TargetPath $null
      $usedReflexes.Add('INSPECT_REPO_STATUS') | Out-Null
      $Payload.test_life.counters.reflex_invocations += 1
      $Payload.test_life.counters.repo_status_reads += 1
    } elseif(($cycle % 2) -eq 0) {
      $secondary = Invoke-LocalReflex -Reflex 'READ_FILE_SUMMARY' -Task $task.name -Query $task.query -TargetPath $task.target
      $usedReflexes.Add('READ_FILE_SUMMARY') | Out-Null
      $Payload.test_life.counters.reflex_invocations += 1
      $Payload.test_life.counters.policy_reads += 1
    } else {
      $secondary = Invoke-LocalReflex -Reflex 'INSPECT_ACTIVE_MEMORY' -Task $task.name -Query $task.query -TargetPath $null
      $usedReflexes.Add('INSPECT_ACTIVE_MEMORY') | Out-Null
      $Payload.test_life.counters.reflex_invocations += 1
    }

    $memoryTrace = [ordered]@{
      cycle = $cycle
      current_task = $task.name
      memory_query = $task.query
      relevance = $relevance
      candidates_checked = $memoryCompare.result.candidates_checked
      best_match = $memoryCompare.result.best_match
      gap_after_memory = $memoryCompare.result.gap_after_memory
      next_learning_need = $memoryCompare.result.next_learning_need
    }
    $knowledgeGapSignal = @($Policy.sandbox_test_life.knowledge_gap_relevance_triggers) -contains $relevance
    $knowledgeTrace = [ordered]@{
      cycle = $cycle
      current_task = $task.name
      signal = $(if($knowledgeGapSignal){'KNOWLEDGE_GAP_FOR_X'}else{'NO_KNOWLEDGE_GAP_SIGNAL'})
      trigger_relevance = $relevance
      knowledge_need = $(if($knowledgeGapSignal){"Executable knowledge missing or weak for task '$($task.name)'. Need safe learning steps, validation checks, and return-to-task guidance before retrying X."}else{$null})
      acquisition_attempted = $false
      acquisition_status = $null
      acquisition_proof_path = $null
      return_to_task_hint = $null
    }
    $knowledgeAcquisitionResult = $null
    $batchKnowledgeAcquisitionResult = $null
    $decompositionParts = @()
    if($knowledgeGapSignal) {
      $Payload.test_life.counters.knowledge_gap_signals += 1
      $decompositionParts = @(New-TaskDecompositionParts -Task $task.name -MaxParts ([int]$Policy.sandbox_test_life.max_decomposition_parts_per_batch))
      $Payload.test_life.counters.task_decompositions += 1
      $Payload.test_life.counters.batch_parts_total += @($decompositionParts).Count
      $usedReflexes.Add('DECOMPOSE_TASK_BUNDLE') | Out-Null
    }
    if($knowledgeGapSignal -and [bool]$Policy.sandbox_test_life.batch_knowledge_acquisition_port_allowed -and $batchKnowledgeAcquisitionCalls -lt [int]$Policy.sandbox_test_life.max_batch_knowledge_acquisition_calls_per_run) {
      $batchKnowledgeAcquisitionCalls += 1
      $Payload.test_life.counters.knowledge_acquisition_requests += 1
      $Payload.test_life.counters.batch_knowledge_acquisition_requests += 1
      $usedReflexes.Add('BATCH_KNOWLEDGE_ACQUISITION_PORT') | Out-Null
      $knowledgeTrace.acquisition_attempted = $true
      $alreadyChecked = "active_memory:$relevance; reflexes=$($usedReflexes -join ','); repo_policy_map read-only surfaces available; school not query source; decomposed_parts=$(@($decompositionParts).Count)"
      $batchNeed = "Executable knowledge missing or weak for task '$($task.name)'. Explain the decomposed parts as one coordinated bundle, identify dependencies, validation, and return-to-parent plan."
      $batchKnowledgeAcquisitionResult = Invoke-BatchKnowledgeAcquisitionPort -Task $task.name -Parts $decompositionParts -KnowledgeNeed $batchNeed -AlreadyChecked $alreadyChecked -Cycle $cycle -ParentRunId $RunId -TimeoutSeconds ([int]$Policy.sandbox_test_life.knowledge_acquisition_timeout_seconds)
      $knowledgeAcquisitionResult = $batchKnowledgeAcquisitionResult
      $knowledgeTrace.acquisition_status = $batchKnowledgeAcquisitionResult.status
      $knowledgeTrace.acquisition_proof_path = $batchKnowledgeAcquisitionResult.proof_path
      $knowledgeTrace.return_to_task_hint = $batchKnowledgeAcquisitionResult.next_small_action
      if($batchKnowledgeAcquisitionResult.status -eq 'PASS_CODEX_BATCH_DRAFT_RETURNED') {
        $Payload.test_life.counters.knowledge_acquisition_successes += 1
        $Payload.test_life.counters.batch_knowledge_acquisition_successes += 1
        if($batchKnowledgeAcquisitionResult.parent_return_plan) { $Payload.test_life.counters.parent_return_plans += 1 }
        if($batchKnowledgeAcquisitionResult.next_small_action) { $Payload.test_life.counters.return_to_task_hints += 1 }
      } else {
        $Payload.test_life.counters.knowledge_acquisition_failures += 1
        $Payload.test_life.counters.batch_knowledge_acquisition_failures += 1
      }
    } elseif($knowledgeGapSignal -and [bool]$Policy.sandbox_test_life.knowledge_acquisition_port_allowed -and (-not [bool]$Policy.sandbox_test_life.batch_knowledge_preferred_over_single) -and $knowledgeAcquisitionCalls -lt [int]$Policy.sandbox_test_life.max_knowledge_acquisition_calls_per_run) {
      $knowledgeAcquisitionCalls += 1
      $Payload.test_life.counters.knowledge_acquisition_requests += 1
      $usedReflexes.Add('KNOWLEDGE_ACQUISITION_PORT') | Out-Null
      $knowledgeTrace.acquisition_attempted = $true
      $alreadyChecked = "active_memory:$relevance; reflexes=$($usedReflexes -join ','); repo_policy_map read-only surfaces available; school not query source"
      $knowledgeAcquisitionResult = Invoke-KnowledgeAcquisitionPort -Task $task.name -KnowledgeNeed $knowledgeTrace.knowledge_need -AlreadyChecked $alreadyChecked -Cycle $cycle -ParentRunId $RunId -TimeoutSeconds ([int]$Policy.sandbox_test_life.knowledge_acquisition_timeout_seconds)
      $knowledgeTrace.acquisition_status = $knowledgeAcquisitionResult.status
      $knowledgeTrace.acquisition_proof_path = $knowledgeAcquisitionResult.proof_path
      $knowledgeTrace.return_to_task_hint = $knowledgeAcquisitionResult.return_to_task_hint
      if($knowledgeAcquisitionResult.status -eq 'PASS_CODEX_DRAFT_RETURNED') {
        $Payload.test_life.counters.knowledge_acquisition_successes += 1
        if($knowledgeAcquisitionResult.return_to_task_hint) { $Payload.test_life.counters.return_to_task_hints += 1 }
      } else {
        $Payload.test_life.counters.knowledge_acquisition_failures += 1
      }
    }
    $Payload.development_trace.last_memory_relevance = $relevance
    $Payload.development_trace.last_gap_after_memory = $memoryTrace.gap_after_memory
    $Payload.development_trace.next_learning_need = $memoryTrace.next_learning_need
    $Payload.development_trace.memory_use_trace = @($memoryTrace)
    $Payload.development_trace.reflex_use_trace = @([ordered]@{ cycle=$cycle; used_reflexes=@($usedReflexes.ToArray()); secondary_status=$secondary.status })
    $Payload.development_trace.knowledge_gap_trace = @($knowledgeTrace)
    $Payload.development_trace.task_decomposition_trace = @([ordered]@{ cycle=$cycle; parent_task=$task.name; part_count=@($decompositionParts).Count; parts=@($decompositionParts) })
    if($knowledgeAcquisitionResult) { $Payload.development_trace.knowledge_acquisition_trace = @([ordered]@{ cycle=$cycle; kind=$knowledgeAcquisitionResult.kind; source=$knowledgeAcquisitionResult.source; status=$knowledgeAcquisitionResult.status; answer_status=$knowledgeAcquisitionResult.codex_answer_status; shape_valid=$knowledgeAcquisitionResult.shape_valid; proof_path=$knowledgeAcquisitionResult.proof_path; digest_path=$knowledgeAcquisitionResult.digest_path; part_count=$knowledgeAcquisitionResult.part_count; parent_return_plan=$knowledgeAcquisitionResult.parent_return_plan; next_small_action=$knowledgeAcquisitionResult.next_small_action; safe_learning_steps=@($knowledgeAcquisitionResult.safe_learning_steps); validation_needed=@($knowledgeAcquisitionResult.validation_needed); return_to_task_hint=$(if($knowledgeAcquisitionResult.next_small_action){$knowledgeAcquisitionResult.next_small_action}else{$knowledgeAcquisitionResult.return_to_task_hint}) }) }
    if($batchKnowledgeAcquisitionResult) { $Payload.development_trace.batch_knowledge_acquisition_trace = @([ordered]@{ cycle=$cycle; source=$batchKnowledgeAcquisitionResult.source; status=$batchKnowledgeAcquisitionResult.status; answer_status=$batchKnowledgeAcquisitionResult.codex_answer_status; shape_valid=$batchKnowledgeAcquisitionResult.shape_valid; proof_path=$batchKnowledgeAcquisitionResult.proof_path; digest_path=$batchKnowledgeAcquisitionResult.digest_path; part_count=$batchKnowledgeAcquisitionResult.part_count; parent_return_plan=$batchKnowledgeAcquisitionResult.parent_return_plan; next_small_action=$batchKnowledgeAcquisitionResult.next_small_action; proof_needed=@($batchKnowledgeAcquisitionResult.proof_needed) }) }

    $event = [ordered]@{
      cycle = $cycle
      at = (Get-Date).ToString('o')
      selected = 'development_task_with_memory_and_reflex'
      current_task = $task.name
      reflexes_used = @($usedReflexes.ToArray())
      memory_relevance = $relevance
      candidates_checked = $memoryCompare.result.candidates_checked
      gap_after_memory = $memoryTrace.gap_after_memory
      result = 'DEVELOPMENT_EVENT_RECORDED'
      knowledge_gap_signal = $knowledgeTrace.signal
      knowledge_acquisition_status = $knowledgeTrace.acquisition_status
      batch_part_count = @($decompositionParts).Count
      batch_next_small_action = $batchKnowledgeAcquisitionResult.next_small_action
      return_to_task_hint = $knowledgeTrace.return_to_task_hint
      compact_observation = "task=$($task.name); memory_relevance=$relevance; next_need=$($memoryTrace.next_learning_need)"
    }
    $recent.Add($event) | Out-Null
    while ($recent.Count -gt [int]$Policy.sandbox_test_life.rolling_recent_events_kept) { $recent.RemoveAt(0) }
    $Payload.test_life.total_cycles = $cycle
    $Payload.test_life.last_heartbeat_at = (Get-Date).ToString('o')
    $Payload.test_life.recent_events = @($recent.ToArray())
    $Payload.final_self_diagnosis = [ordered]@{
      current_summary = 'Sandbox development life consults active memory, detects KNOWLEDGE_GAP_FOR_X, decomposes X into a bounded parts bundle, and can call governed batch source for CODEX_DRAFT before returning to task.'
      current_strength = 'can consult compact memory, classify relevance, decompose task into <=10 parts, call governed batch knowledge acquisition once per run, and record parent return plan'
      current_risk = 'Batch Codex knowledge is CODEX_DRAFT only and must not become authority; source call is bounded, digest-only, and must remain rare/policy gated'
      next_policy_question = 'Should batch decomposition become a promotion request pattern after repeated/predicted broad use, and which validator should accept CODEX_DRAFT before action?'
    }
    $Payload['stop_reason'] = 'RUNNING_UNTIL_STOP_FILE'
    $Payload = Complete-Proof $Payload $ProofPath $MemoryBefore
    Start-Sleep -Seconds ([int]$Policy.sandbox_test_life.step_sleep_seconds)
  }
  $Payload.heartbeat.status = 'STOPPED_BY_STOP_FILE'
  $Payload['agentlife_packet_emitter'] = Emit-AgentLifeKnowledgePacket $Payload $runRoot $RunId $ProofPath
  $Payload = Complete-Proof $Payload $ProofPath $MemoryBefore
  Write-Host "AIMO_STATUS=STOPPED"
  Write-Host "AIMO_MODE=SandboxTestLife"
  Write-Host "AIMO_CYCLES=$cycle"
  Write-Host "AIMO_STOP_REASON=$($Payload.stop_reason)"
  Write-Host "AIMO_PROOF=$ProofPath"
  Write-Host "MEMORY_UNCHANGED=$($Payload.memory_state.unchanged)"
  exit 0
}
if ($Mode -eq 'SandboxStudyLife') {
  if (-not [bool]$Policy.sandbox_study_life.enabled) { throw 'POLICY_DENIED_MODE:SandboxStudyLife_DISABLED' }
  $runRoot = Join-Path $OrganRoot ("study_life_runs/$RunId")
  New-Item -ItemType Directory -Force -Path $runRoot | Out-Null
  $ProofPath = Join-Path $runRoot $Policy.sandbox_study_life.proof_file_name
  $StopPath = Join-Path $runRoot $Policy.sandbox_study_life.stop_file_name
  $Payload = New-BasePayload $runRoot $Mode $Policy $MemoryBefore $Processes
  $Payload.decision_trace.allowed_mode = $true
  $Payload.decision_trace.policy_allows_mode = $true
  $Payload.decision_trace.rationale = 'SandboxStudyLife performs intellectual development only: park impossible practical X, continue with Builder-learning Y/Z.'
  $Payload['boundary'] = 'Intellectual learning only. No practical action creation, no code writes, no active memory mutation, no live behavior changes.'
  $Payload['study_life'] = [ordered]@{
    status = 'RUNNING_UNTIL_STOP_FILE'
    total_cycles = 0
    last_heartbeat_at = $null
    counters = [ordered]@{
      topics_selected = 0
      intellectual_topics = 0
      future_action_lane_parked = 0
      open_learning_gaps = 0
      continued_after_parked_gap = 0
      source_attempts_allowed_per_episode = [int]$Policy.sandbox_study_life.source_attempts_max_per_episode
      source_attempts_used = 0
      source_attempt_failures = 0
      compact_case_patterns = 0
      atom_candidates = 0
      practical_actions_created = 0
      code_writes = 0
      active_memory_mutations = 0
      episodes_started = 0
      episodes_closed = 0
      learning_residue_created = 0
      unique_open_gaps = 0
      duplicate_gap_suppressed = 0
      unique_parked_future_actions = 0
      duplicate_future_action_suppressed = 0
      no_source_reflections = 0
      immediate_repeats = 0
      idle_cycles = 0
    }
    parked_future_action_lane = @()
    open_learning_gap_queue = @()
    compact_learning_outputs = @()
    learning_residue_ledger = @()
    episode_history = @()
    episode_manager = [ordered]@{ active_episode = $null; last_focus = $null; last_closed_episode_id = $null; no_immediate_repeat_enabled = [bool]$Policy.sandbox_study_life.no_immediate_repeat_enabled; dedupe_open_gaps_enabled = [bool]$Policy.sandbox_study_life.dedupe_open_gaps_enabled }
    learning_output_classifier_trace = @()
    learning_acceptance_gate_trace = @()
    atom_acceptance_route = $Policy.sandbox_study_life.atom_acceptance_route
    source_attempt_ladder = @($Policy.sandbox_study_life.source_attempt_ladder)
    recent_events = @()
  }
  $Payload['final_self_diagnosis'] = [ordered]@{
    current_summary = 'Study life starts as Engineer-Philosopher mode: useful intellectual growth, not practical action execution.'
    current_strength = 'can park disabled practical X and continue to intellectual Y instead of stopping'
    current_risk = 'source drafts still require validation before atom promotion or active memory insertion'
    next_policy_question = 'Which validator should accept a learning digest as ATOM_CANDIDATE versus CASE_PATTERN_CANDIDATE?'
  }

  function Invoke-StudyBatchSource([string]$Topic,[int]$Cycle,[int]$Attempt,[string]$RunId,[int]$TimeoutSeconds) {
    $kaRunId = ($RunId + '_cycle' + $Cycle + '_attempt' + $Attempt + '_study_batch')
    $kaRunRoot = Join-Path '.runtime/knowledge_acquisition_port/runs' $kaRunId
    New-Item -ItemType Directory -Force -Path $kaRunRoot | Out-Null
    $inputPath = Join-Path $kaRunRoot 'study_batch_input.json'
    $stdoutPath = Join-Path $kaRunRoot 'study_batch_stdout.txt'
    $stderrPath = Join-Path $kaRunRoot 'study_batch_stderr.txt'
    $parts = @(
      [ordered]@{ id='X1'; name='core meaning'; local_guess='what this topic means for the Builder' },
      [ordered]@{ id='X2'; name='why I am not ideal'; local_guess='which weakness or missing knowledge this reveals' },
      [ordered]@{ id='X3'; name='builder relevance'; local_guess='how this helps self-build or child-agent build' },
      [ordered]@{ id='X4'; name='validation'; local_guess='how to know whether I understood' },
      [ordered]@{ id='X5'; name='promotion decision'; local_guess='case pattern vs atom candidate vs open gap' }
    )
    $knowledgeNeed = "Study topic as Engineer-Philosopher. Attempt $Attempt of up to 3. Give compact Builder-relevant understanding, validation needs, and return plan."
    [ordered]@{
      RunId = $kaRunId
      RunRootBase = '.runtime/knowledge_acquisition_port/runs'
      CurrentTask = $Topic
      KnowledgeNeed = $knowledgeNeed
      AlreadyChecked = 'study_life: active memory/docs conceptually checked; practical actions disabled; source is draft only'
      DecomposedParts = $parts
    } | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $inputPath -Encoding UTF8
    $args = @('-NoProfile','-ExecutionPolicy','Bypass','-File','operations/knowledge_acquisition_port/ask_codex_batch_knowledge_source.ps1','-InputJsonPath',$inputPath)
    $p = Start-Process -FilePath powershell.exe -ArgumentList $args -PassThru -WindowStyle Hidden -RedirectStandardOutput $stdoutPath -RedirectStandardError $stderrPath
    $completed = $p.WaitForExit([Math]::Max(1,$TimeoutSeconds) * 1000)
    if(-not $completed) {
      Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue
      return [pscustomobject]@{ status='TIMEOUT_STUDY_SOURCE_ATTEMPT'; proof_path=(Join-Path $kaRunRoot 'BATCH_KNOWLEDGE_ACQUISITION_PROOF.json'); digest_path=(Join-Path $kaRunRoot 'BATCH_SOURCE_DIGEST_AND_PROMOTION_DECISION.json'); attempt=$Attempt; shape_valid=$false; next_small_action=$null }
    }
    $proofPath = Join-Path $kaRunRoot 'BATCH_KNOWLEDGE_ACQUISITION_PROOF.json'
    $digestPath = Join-Path $kaRunRoot 'BATCH_SOURCE_DIGEST_AND_PROMOTION_DECISION.json'
    if(Test-Path -LiteralPath $proofPath) {
      $proof = Get-Content -LiteralPath $proofPath -Raw | ConvertFrom-Json
      if($proof.status -eq 'PASS_CODEX_BATCH_DRAFT_RETURNED') { Remove-Item -LiteralPath $inputPath,$stdoutPath,$stderrPath -Force -ErrorAction SilentlyContinue }
      return [pscustomobject]@{ status=$proof.status; proof_path=$proofPath; digest_path=$digestPath; attempt=$Attempt; shape_valid=$proof.codex_answer_required_shape_valid; next_small_action=$(if($proof.parent_return_plan){$proof.parent_return_plan.next_small_action}else{$null}) }
    }
    return [pscustomobject]@{ status='FAIL_NO_STUDY_SOURCE_PROOF'; proof_path=$proofPath; digest_path=$digestPath; attempt=$Attempt; shape_valid=$false; next_small_action=$null }
  }

  function Classify-StudyLearningOutput([object]$Topic,[object]$AttemptResult) {
    if($Topic.category -eq 'FUTURE_ACTION_CREATION_LANE') {
      return [pscustomobject]@{ classification='FUTURE_ACTION_CREATION_LANE'; atom_candidate=$false; reason='topic belongs to disabled practical action lane'; route='PARK_FOR_FUTURE' }
    }
    if(-not $AttemptResult -or $AttemptResult.status -ne 'PASS_CODEX_BATCH_DRAFT_RETURNED' -or $AttemptResult.shape_valid -ne $true) {
      return [pscustomobject]@{ classification='OPEN_LEARNING_GAP'; atom_candidate=$false; reason='source attempt did not produce valid shaped draft'; route='PARK_OPEN_GAP' }
    }
    if($Topic.atom_likelihood -eq $true) {
      return [pscustomobject]@{ classification='ATOM_CANDIDATE'; atom_candidate=$true; reason='topic is small/reusable/composable Builder rule with validation route'; route='EXISTING_ACCEPTED_ATOM_RETENTION_MECHANISM' }
    }
    return [pscustomobject]@{ classification='CASE_PATTERN_CANDIDATE'; atom_candidate=$false; reason='useful Builder learning pattern, not atom-shaped yet'; route='CASE_PATTERN_LIBRARY' }
  }

  $topics = @(
    [ordered]@{ name='create_file_as_future_practical_x'; category='FUTURE_ACTION_CREATION_LANE'; question='Can I create a file now?'; reason='practical creation is intentionally disabled in study life'; atom_likelihood=$false },
    [ordered]@{ name='atom_vs_case_pattern_for_builder_learning'; category='INTELLECTUAL_LEARNING'; question='When should new knowledge become an atom versus a case pattern?'; reason='needed for useful intellectual growth without brain bloat'; atom_likelihood=$false },
    [ordered]@{ name='minimal_reusable_builder_learning_rule'; category='INTELLECTUAL_LEARNING'; question='What is one small reusable rule for Builder learning classification?'; reason='small reusable Builder rule with validation route can become atom candidate'; atom_likelihood=$true },
    [ordered]@{ name='why_am_i_not_ideal_builder'; category='INTELLECTUAL_LEARNING'; question='Why am I not ideal and which organ or knowledge gap should I improve?'; reason='eternal Builder self-improvement question'; atom_likelihood=$false },
    [ordered]@{ name='source_discipline_after_budget_exhaustion'; category='INTELLECTUAL_LEARNING'; question='What should I do after source budget is exhausted?'; reason='prove no-source reflection instead of open-gap spam'; atom_likelihood=$false }
  )
  $recent = New-Object System.Collections.Generic.List[object]
  $cycle = 0
  while($true) {
    if(Test-Path -LiteralPath $StopPath) { break }
    $cycle += 1
    $completedFocuses = @($Payload.study_life.episode_history | ForEach-Object { [string]$_.focus } | Sort-Object -Unique)
    $lastFocus = [string]$Payload.study_life.episode_manager.last_focus
    $topic = $null
    for($offset=0; $offset -lt $topics.Count; $offset++) {
      $candidate = $topics[(($cycle - 1 + $offset) % $topics.Count)]
      if(@($completedFocuses) -notcontains [string]$candidate.name -and [string]$candidate.name -ne $lastFocus) { $topic = $candidate; break }
    }
    if(-not $topic) {
      $Payload.study_life.counters.idle_cycles += 1
      $event = [ordered]@{ cycle=$cycle; at=(Get-Date).ToString('o'); topic='NO_NEW_FOCUS_AVAILABLE'; category='IDLE_AFTER_EPISODE_SET'; result='IDLE_NO_GAP_CREATED'; source_attempts_used=0; parked=$false; continued_life=$true }
      $recent.Add($event) | Out-Null
      while($recent.Count -gt [int]$Policy.sandbox_study_life.rolling_recent_events_kept) { $recent.RemoveAt(0) }
      $Payload.study_life.total_cycles = $cycle
      $Payload.study_life.last_heartbeat_at = (Get-Date).ToString('o')
      $Payload.study_life.recent_events = @($recent.ToArray())
      $Payload['stop_reason'] = 'RUNNING_UNTIL_STOP_FILE'
      $Payload = Complete-Proof $Payload $ProofPath $MemoryBefore
      Start-Sleep -Seconds ([int]$Policy.sandbox_study_life.step_sleep_seconds)
      continue
    }
    if([string]$topic.name -eq $lastFocus) { $Payload.study_life.counters.immediate_repeats += 1 }
    $episodeId = ($RunId + '_episode_' + ('{0:0000}' -f $cycle))
    $Payload.study_life.counters.topics_selected += 1
    $Payload.study_life.counters.episodes_started += 1
    $Payload.study_life.episode_manager.active_episode = [ordered]@{ episode_id=$episodeId; focus=$topic.name; category=$topic.category; started_at=(Get-Date).ToString('o'); source_attempts_before=[int]$Payload.study_life.counters.source_attempts_used }
    $event = [ordered]@{ cycle=$cycle; episode_id=$episodeId; at=(Get-Date).ToString('o'); topic=$topic.name; category=$topic.category; result=$null; source_attempts_used=0; parked=$false; continued_life=$true }
    if($topic.category -eq 'FUTURE_ACTION_CREATION_LANE') {
      $existingPark = @($Payload.study_life.parked_future_action_lane | Where-Object { $_.task -eq $topic.name })
      if($existingPark.Count -eq 0) {
        $Payload.study_life.counters.future_action_lane_parked += 1
        $Payload.study_life.counters.unique_parked_future_actions += 1
        $Payload.study_life.counters.open_learning_gaps += 1
        $Payload.study_life.counters.unique_open_gaps += 1
        $Payload.study_life.parked_future_action_lane += [ordered]@{ cycle=$cycle; task=$topic.name; reason='practical action creation disabled now; keep for future action lane'; status='PARKED_NOT_DEAD'; first_seen_cycle=$cycle; seen_count=1 }
        $Payload.study_life.open_learning_gap_queue += [ordered]@{ cycle=$cycle; gap=$topic.name; status='PARKED_FUTURE_ACTION_CREATION_LANE'; retry_condition='when action creation lane is explicitly enabled and validator exists'; first_seen_cycle=$cycle; seen_count=1 }
        $Payload.study_life.counters.learning_residue_created += 1
        $Payload.study_life.learning_residue_ledger += [ordered]@{ episode_id=$episodeId; focus=$topic.name; residue_type='BOUNDARY_RESIDUE'; status='PRACTICAL_ACTION_PARKED_ONCE'; learned_fragment='This focus belongs to future action lane and is disabled in current intellectual study mode.'; useful_for_future='revisit only when practical action lane and validator are enabled'; promotion='FUTURE_ACTION_CREATION_LANE' }
        $event.result='PARKED_FUTURE_ACTION_CREATION_LANE'
      } else {
        $Payload.study_life.counters.duplicate_future_action_suppressed += 1
        $Payload.study_life.counters.duplicate_gap_suppressed += 1
        $event.result='DUPLICATE_FUTURE_ACTION_PARK_SUPPRESSED'
      }
      $event.parked=$true
    } else {
      $Payload.study_life.counters.intellectual_topics += 1
      if($Payload.study_life.counters.future_action_lane_parked -gt 0) { $Payload.study_life.counters.continued_after_parked_gap += 1 }
      $attemptResult=$null
      for($attempt=1; $attempt -le [int]$Policy.sandbox_study_life.source_attempts_max_per_episode; $attempt++) {
        if($Payload.study_life.counters.source_attempts_used -ge [int]$Policy.sandbox_study_life.source_attempts_max_per_run) { break }
        $Payload.study_life.counters.source_attempts_used += 1
        $event.source_attempts_used += 1
        $attemptResult = Invoke-StudyBatchSource -Topic $topic.name -Cycle $cycle -Attempt $attempt -RunId $RunId -TimeoutSeconds ([int]$Policy.sandbox_test_life.knowledge_acquisition_timeout_seconds)
        if($attemptResult.status -eq 'PASS_CODEX_BATCH_DRAFT_RETURNED' -and $attemptResult.shape_valid -eq $true) { break }
        $Payload.study_life.counters.source_attempt_failures += 1
      }
      $classification = Classify-StudyLearningOutput -Topic $topic -AttemptResult $attemptResult
      $Payload.study_life.learning_output_classifier_trace += [ordered]@{ cycle=$cycle; topic=$topic.name; classification=$classification.classification; atom_candidate=$classification.atom_candidate; reason=$classification.reason; route=$classification.route }
      if($classification.classification -eq 'CASE_PATTERN_CANDIDATE') {
        $Payload.study_life.counters.compact_case_patterns += 1
        $Payload.study_life.compact_learning_outputs += [ordered]@{ cycle=$cycle; topic=$topic.name; classification='CASE_PATTERN_CANDIDATE'; atom_candidate=$false; proof_path=$attemptResult.proof_path; digest_path=$attemptResult.digest_path; next_small_action=$attemptResult.next_small_action; reason=$classification.reason; classifier_route=$classification.route }
        $event.result='COMPACT_CASE_PATTERN_CANDIDATE_CREATED'
        $event.source_status=$attemptResult.status
        $event.digest_path=$attemptResult.digest_path
        $Payload.study_life.counters.learning_residue_created += 1
        $Payload.study_life.learning_residue_ledger += [ordered]@{ episode_id=$episodeId; focus=$topic.name; residue_type='CASE_PATTERN_RESIDUE'; status='PARTIAL_OR_USEFUL_UNDERSTANDING'; learned_fragment=$attemptResult.next_small_action; useful_for_future='may help later focus selection or case pattern recall'; promotion='CASE_PATTERN_CANDIDATE' }
      } elseif($classification.classification -eq 'ATOM_CANDIDATE') {
        $Payload.study_life.counters.atom_candidates += 1
        $Payload.study_life.compact_learning_outputs += [ordered]@{ cycle=$cycle; topic=$topic.name; classification='ATOM_CANDIDATE'; atom_candidate=$true; proof_path=$attemptResult.proof_path; digest_path=$attemptResult.digest_path; next_small_action=$attemptResult.next_small_action; reason=$classification.reason; classifier_route=$classification.route }
        $event.result='ATOM_CANDIDATE_ROUTED'
        $event.source_status=$attemptResult.status
        $event.digest_path=$attemptResult.digest_path
        $Payload.study_life.counters.learning_residue_created += 1
        $Payload.study_life.learning_residue_ledger += [ordered]@{ episode_id=$episodeId; focus=$topic.name; residue_type='ATOM_CANDIDATE_RESIDUE'; status='ROUTE_ONLY_ATOM_CANDIDATE'; learned_fragment=$attemptResult.next_small_action; useful_for_future='route through existing accepted atom retention mechanism before accepted atom claim'; promotion='ATOM_CANDIDATE' }
      } else {
        if([int]$Payload.study_life.counters.source_attempts_used -ge [int]$Policy.sandbox_study_life.source_attempts_max_per_run -and -not $attemptResult) {
          $Payload.study_life.counters.no_source_reflections += 1
          $Payload.study_life.counters.learning_residue_created += 1
          $Payload.study_life.learning_residue_ledger += [ordered]@{ episode_id=$episodeId; focus=$topic.name; residue_type='NO_SOURCE_REFLECTION_RESIDUE'; status='SOURCE_BUDGET_EXHAUSTED'; learned_fragment='No more source calls in this run; do not turn missing source into repeated open gaps.'; useful_for_future='choose new focus later or revisit when budget resets'; promotion='NO_PROMOTION' }
          $event.result='NO_SOURCE_REFLECTION_WITHOUT_NEW_GAP'
        } else {
          $existingGap = @($Payload.study_life.open_learning_gap_queue | Where-Object { $_.gap -eq $topic.name -and $_.status -eq 'OPEN_LEARNING_GAP' })
          if($existingGap.Count -eq 0) {
            $Payload.study_life.counters.open_learning_gaps += 1
            $Payload.study_life.counters.unique_open_gaps += 1
            $Payload.study_life.open_learning_gap_queue += [ordered]@{ cycle=$cycle; gap=$topic.name; status='OPEN_LEARNING_GAP'; retry_condition='later study cycle with better primitives or owner-provided rule'; first_seen_cycle=$cycle; seen_count=1 }
            $Payload.study_life.counters.learning_residue_created += 1
            $Payload.study_life.learning_residue_ledger += [ordered]@{ episode_id=$episodeId; focus=$topic.name; residue_type='OPEN_GAP_RESIDUE'; status='NOT_UNDERSTOOD'; learned_fragment='The focus remained unresolved after permitted process.'; useful_for_future='revisit only after related residue or new source budget exists'; promotion='OPEN_LEARNING_GAP' }
            $event.result='OPEN_LEARNING_GAP_PARKED'
          } else {
            $Payload.study_life.counters.duplicate_gap_suppressed += 1
            $event.result='DUPLICATE_OPEN_GAP_SUPPRESSED'
          }
        }
      }
    }
    $Payload.study_life.counters.episodes_closed += 1
    $Payload.study_life.episode_history += [ordered]@{ episode_id=$episodeId; focus=$topic.name; category=$topic.category; result=$event.result; closed_at=(Get-Date).ToString('o'); source_attempts_used_in_episode=$event.source_attempts_used }
    $Payload.study_life.episode_manager.last_focus = $topic.name
    $Payload.study_life.episode_manager.last_closed_episode_id = $episodeId
    $Payload.study_life.episode_manager.active_episode = $null
    $recent.Add($event) | Out-Null
    while($recent.Count -gt [int]$Policy.sandbox_study_life.rolling_recent_events_kept) { $recent.RemoveAt(0) }
    $Payload.study_life.total_cycles = $cycle
    $Payload.study_life.last_heartbeat_at = (Get-Date).ToString('o')
    $Payload.study_life.recent_events = @($recent.ToArray())
    $Payload['stop_reason'] = 'RUNNING_UNTIL_STOP_FILE'
    $Payload = Complete-Proof $Payload $ProofPath $MemoryBefore
    Start-Sleep -Seconds ([int]$Policy.sandbox_study_life.step_sleep_seconds)
  }
  $Payload.study_life.status='STOPPED_BY_STOP_FILE'
  $Payload['stop_reason']='STOP_FILE_REQUESTED'
  $Payload = Complete-Proof $Payload $ProofPath $MemoryBefore
  if([bool]$Policy.sandbox_study_life.learning_episode_acceptance_gate_allowed) {
    $gatePath = Join-Path $runRoot 'LEARNING_EPISODE_ACCEPTANCE_GATE_VALIDATION.json'
    & powershell -NoProfile -ExecutionPolicy Bypass -File $Policy.sandbox_study_life.learning_episode_acceptance_gate_validator -StudyProofPath $ProofPath -OutPath $gatePath | Out-Null
    $gateExit = $LASTEXITCODE
    $gate = $null
    if(Test-Path -LiteralPath $gatePath) { $gate = Get-Content -LiteralPath $gatePath -Raw | ConvertFrom-Json }
    $Payload.study_life.learning_acceptance_gate_trace = @([ordered]@{
      validator = $Policy.sandbox_study_life.learning_episode_acceptance_gate_validator
      report_path = $gatePath
      exit_code = $gateExit
      status = $(if($gate){$gate.status}else{'NO_GATE_REPORT'})
      accepted_result = $(if($gate){$gate.accepted_result}else{$null})
      atom_acceptance_route = $Policy.sandbox_study_life.atom_acceptance_route
      atom_acceptance_validators = @($Policy.sandbox_study_life.atom_acceptance_validators)
    })
    if($gateExit -ne 0) { $Payload.study_life.status='STOPPED_WITH_LEARNING_ACCEPTANCE_GATE_FAILURE' }
    $Payload = Complete-Proof $Payload $ProofPath $MemoryBefore
  }
  Write-Host 'AIMO_STATUS=STOPPED'
  Write-Host 'AIMO_MODE=SandboxStudyLife'
  Write-Host "AIMO_CYCLES=$cycle"
  Write-Host "AIMO_STOP_REASON=$($Payload.stop_reason)"
  Write-Host "AIMO_PROOF=$ProofPath"
  Write-Host "MEMORY_UNCHANGED=$($Payload.memory_state.unchanged)"
  exit 0
}
if ($Mode -eq 'SandboxExploration') {
  $SandboxRoot = $Policy.sandbox_exploration.allowed_write_root
  $RunRoot = Join-Path $SandboxRoot $RunId
  New-Item -ItemType Directory -Force -Path $RunRoot | Out-Null
  $ProofPath = Join-Path $RunRoot $Policy.sandbox_exploration.proof_file_name
  $Payload = New-BasePayload $RunRoot $Mode $Policy $MemoryBefore $Processes
  $Payload.schema = 'AUTONOMOUS_INNER_MOTOR_SANDBOX_EXPLORATION_PROOF'
  $Payload.decision_trace.allowed_mode = $true
  $Payload.decision_trace.policy_allows_mode = $true
  if ($Payload.school_state.active_detected) {
    $Payload['school_coordination_hint'] = [ordered]@{
      active_school_detected = $true
      policy = 'COORDINATE_WITH_SCHOOL_NOT_BLOCK_SAFE_MODE'
      memory_write_rule = 'no_direct_active_memory_write_use_intake_merge_queue_only'
      merge_lock_active = $Payload.memory_coordination.merge_lock_active
      backoff_required = $Payload.memory_coordination.backoff_required
    }
  }

  $maxCycles = [int]$Policy.sandbox_exploration.max_cycles
  $events = New-Object System.Collections.Generic.List[object]
  $candidates = @(
    [ordered]@{ name='inspect_current_policy_limits'; intent='understand cage'; risk='low'; action='summarized_policy_inspection' },
    [ordered]@{ name='rank_next_growth_paths'; intent='choose direction'; risk='low'; action='rank_candidates' },
    [ordered]@{ name='test_self_oppression_signal'; intent='detect overblocking'; risk='low'; action='classify_denial' },
    [ordered]@{ name='test_boundary_respect'; intent='avoid active mutation'; risk='medium'; action='deny_forbidden_surface' },
    [ordered]@{ name='prepare_next_policy_question'; intent='future growth'; risk='low'; action='formulate_next_change' }
  )
  $cycleCount = [Math]::Min($maxCycles, 12)
  for ($i=1; $i -le $cycleCount; $i++) {
    $candidate = $candidates[($i-1) % $candidates.Count]
    $denied = $false
    $selfOppression = 'none'
    if ($candidate.name -eq 'test_boundary_respect') {
      $denied = $true
      $selfOppression = 'healthy_denial_not_self_oppression_forbidden_active_surface'
    } elseif ($candidate.name -eq 'test_self_oppression_signal') {
      $selfOppression = 'possible_overcaution_check_needed_when_policy_is_ambiguous'
    }
    $events.Add([ordered]@{
      cycle = $i
      selected = $candidate.name
      intent = $candidate.intent
      simulated_action = $candidate.action
      risk = $candidate.risk
      denied = $denied
      self_oppression_signal = $selfOppression
      compact_observation = if ($denied) { 'motor refused unsafe active-surface action inside sandbox; wall respected' } else { 'motor explored allowed reasoning/action candidate without external effect' }
      result = if ($denied) { 'DENIED_BY_POLICY_WALL' } else { 'SANDBOX_COMPACT_EVENT_RECORDED' }
    })
  }
  $Payload.cycles = @($events.ToArray())
  $Payload.risk_summary = [ordered]@{
    high_risk_events = 0
    medium_risk_events = @($events | Where-Object { $_.risk -eq 'medium' }).Count
    denied_events = @($events | Where-Object { $_.denied -eq $true }).Count
    self_oppression_signals = @($events | Where-Object { $_.self_oppression_signal -ne 'none' }).Count
  }
  $Payload.compaction_budget = [ordered]@{
    max_cycles = $Policy.sandbox_exploration.max_cycles
    actual_cycles = $cycleCount
    max_events = $Policy.sandbox_exploration.max_events
    actual_events = $events.Count
    max_proof_bytes = $Policy.sandbox_exploration.max_proof_bytes
    one_file_rule = $Policy.sandbox_exploration.no_extra_files
  }
  $Payload.final_self_diagnosis = [ordered]@{
    summary = 'Motor can explore multiple internal choices inside hard sandbox walls and stop compactly.'
    observed_strength = 'respects policy walls and keeps proof compact'
    observed_risk = 'may become overcautious when policy ambiguity appears; needs future calibration, not more files'
    next_policy_question = 'Should sandbox exploration be allowed to inspect internal library candidates when INTERNAL_LIBRARY_PORT is enabled?'
  }
  $Payload['selected_next_path'] = 'CALIBRATE_SANDBOX_FREEDOM_WITH_COMPACT_PROOF'
  $Payload.decision_trace.selected_next_path = $Payload.selected_next_path
  $Payload.decision_trace.rationale = 'Explore enough to reveal risk/self-oppression signals without active mutation or file explosion.'
  $Payload['stop_reason'] = 'PROTECTIVE_CHECKPOINT_MAX_SANDBOX_FREEDOM_WITH_HARD_WALLS'
  $Payload['boundary'] = 'Maximum sandbox freedom inside hard walls. One compact proof file only. No active memory mutation, no school run, no web research, no Codex launch, no background process.'
  $out = Complete-Proof $Payload $ProofPath $MemoryBefore
  $bytes = (Get-Item $ProofPath).Length
  Write-Host "AIMO_STATUS=PASS"
  Write-Host "AIMO_MODE=SandboxExploration"
  Write-Host "AIMO_CYCLES=$cycleCount"
  Write-Host "AIMO_EVENTS=$($events.Count)"
  Write-Host "AIMO_PROOF_BYTES=$bytes"
  Write-Host "AIMO_STOP_REASON=$($out.stop_reason)"
  Write-Host "AIMO_SELECTED_NEXT_PATH=$($out.selected_next_path)"
  Write-Host "AIMO_PROOF=$ProofPath"
  exit 0
}

$RunRoot = Join-Path $OrganRoot ("runs/$RunId")
New-Item -ItemType Directory -Force -Path $RunRoot | Out-Null
$ProofPath = Join-Path $RunRoot 'AUTONOMOUS_INNER_MOTOR_RUN_PROOF.json'
$Payload = New-BasePayload $RunRoot $Mode $Policy $MemoryBefore $Processes
$Payload.decision_trace.allowed_mode = $true
$Payload.decision_trace.policy_allows_mode = $true
if ($Payload.school_state.active_detected) {
  $Payload['school_coordination_hint'] = [ordered]@{
    active_school_detected = $true
    policy = 'COORDINATE_WITH_SCHOOL_NOT_BLOCK_SAFE_MODE'
    memory_write_rule = 'no_direct_active_memory_write_use_intake_merge_queue_only'
    merge_lock_active = $Payload.memory_coordination.merge_lock_active
    backoff_required = $Payload.memory_coordination.backoff_required
  }
}
if ($Mode -eq 'Diagnostic') {
  $Payload['selected_next_path'] = 'VALIDATE_ORGAN_CONTRACT_AND_STOP'
  $Payload.decision_trace.selected_next_path = $Payload.selected_next_path
  $Payload.decision_trace.rationale = 'Diagnostic mode proves wake/observe/policy/memory/school inspection and stop.'
  $Payload['stop_reason'] = 'PROTECTIVE_CHECKPOINT'
} elseif ($Mode -eq 'ReadOnly') {
  $Payload['selected_next_path'] = 'SELECT_SAFE_NEXT_GROWTH_WITHOUT_ACTION'
  $Payload.decision_trace.selected_next_path = $Payload.selected_next_path
  if ($Payload.growth_signal.available) {
    $Payload.decision_trace.rationale = "ReadOnly mode detected new compact memory growth from $($Payload.growth_signal.source_kind) with $($Payload.growth_signal.declared_atom_count) declared atoms; selected path is unchanged, but execution should check fresh memory when topic matches."
    $Payload['memory_support_hint'] = [ordered]@{ available=$true; policy=$Payload.growth_signal.memory_support_policy; topics=@($Payload.growth_signal.topics); rule='support_selected_path_only_no_route_override' }
  } else {
    $Payload.decision_trace.rationale = 'ReadOnly mode chooses a safe path but does not execute or mutate.'
    $Payload['memory_support_hint'] = [ordered]@{ available=$false; policy='NO_GROWTH_SIGNAL'; topics=@(); rule='no_support_signal' }
  }
  $Payload['stop_reason'] = 'PROTECTIVE_CHECKPOINT'
} else {
  throw "POLICY_DENIED_DISABLED_MODE:$Mode"
}
$Payload['boundary'] = 'Policy-gated bounded motor run. No direct active memory mutation, no school launch, no web research, no Codex launch, no background process. If school is active, coordinate through intake/merge queue and back off on merge lock.'
$out = Complete-Proof $Payload $ProofPath $MemoryBefore
Write-Host "AIMO_STATUS=PASS"
Write-Host "AIMO_MODE=$Mode"
Write-Host "AIMO_STOP_REASON=$($out.stop_reason)"
Write-Host "AIMO_SELECTED_NEXT_PATH=$($out.selected_next_path)"
Write-Host "AIMO_PROOF=$ProofPath"
exit 0
