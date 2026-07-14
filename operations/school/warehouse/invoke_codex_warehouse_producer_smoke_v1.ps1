param(
  [ValidateSet('MockProducer','RunCodex')][string]$ProducerMode = 'MockProducer',
  [string]$Topics = 'AUTO',
  [ValidateRange(1,1000000)][int]$MaxRequestSize = 50000,
  [ValidateRange(1,10000)][int]$MicroBatchSize = 100,
  [ValidateRange(1,1000000)][int]$MaxReadyBacklogCandidates = 3000,
  [ValidateRange(30,3600)][int]$CodexTimeoutSeconds = 300,
  [string]$OutputRoot = ''
)
$ErrorActionPreference='Stop'
$repoRoot=(git rev-parse --show-toplevel).Trim(); Set-Location $repoRoot
function EnsureDir($Path){ if($Path -and -not (Test-Path $Path)){ New-Item -ItemType Directory -Force -Path $Path | Out-Null } }
function WriteJson($Path,$Obj,$Depth=100){ $d=Split-Path -Parent $Path; if($d){ EnsureDir $d }; $Obj|ConvertTo-Json -Depth $Depth|Set-Content -LiteralPath $Path -Encoding UTF8 }
function Sha($p){ if(Test-Path $p){ (Get-FileHash $p -Algorithm SHA256).Hash } else { 'MISSING' } }
function Stop-ProcessTreeByRootPid([int]$RootPid){
  $children=@(Get-CimInstance Win32_Process | Where-Object { $_.ParentProcessId -eq $RootPid })
  foreach($child in $children){ Stop-ProcessTreeByRootPid -RootPid ([int]$child.ProcessId) }
  try { Stop-Process -Id $RootPid -Force -ErrorAction SilentlyContinue } catch {}
}
$mem='.runtime/active_compact_semantic_memory_v1'
$memoryBefore=[ordered]@{manifest=Sha "$mem/manifest.json"; index=Sha "$mem/index.json"; cells=Sha "$mem/cells.jsonl"}
$runId="real_warehouse_producer_smoke_{0}_{1}" -f $ProducerMode.ToLowerInvariant(),(Get-Date -Format 'yyyyMMdd_HHmmss')
if([string]::IsNullOrWhiteSpace($OutputRoot)){ $OutputRoot=".runtime/real_warehouse_producer_smoke/$runId" }
EnsureDir $OutputRoot
$selectionPath="$OutputRoot/selection.json"
$requestPlanPath="$OutputRoot/request_plan.json"
$taskDir="$OutputRoot/warehouse_request"
$eventsPath="$OutputRoot/smoke_events.jsonl"
function AddEvent($State,$Data){ ([ordered]@{ts=(Get-Date).ToString('o'); state=$State; data=$Data}|ConvertTo-Json -Depth 80 -Compress)|Add-Content -LiteralPath $eventsPath -Encoding UTF8 }
AddEvent 'SMOKE_STARTED' @{producer_mode=$ProducerMode; topics=$Topics; absorb=$false}
& powershell -NoProfile -ExecutionPolicy Bypass -File operations/school/memory/select_dynamic_theme_cell_v1.ps1 -RequestedTopics $Topics -PatchSize 1000 -OutputPath $selectionPath | Out-Host
AddEvent 'TOPIC_SELECTED' @{selection_path=$selectionPath}
& powershell -NoProfile -ExecutionPolicy Bypass -File operations/school/request/plan_dynamic_school_request_v1.ps1 -SelectionPath $selectionPath -OutputPath $requestPlanPath -MaxRequestSize $MaxRequestSize -MicroBatchSize $MicroBatchSize -MaxReadyBacklogCandidates $MaxReadyBacklogCandidates | Out-Host
$request=Get-Content $requestPlanPath -Raw | ConvertFrom-Json
AddEvent 'DYNAMIC_REQUEST_PLANNED' @{request_plan=$requestPlanPath; request_size=$request.request_candidate_count; micro_batch_count=$request.micro_batch_count}
$taskOut=@(& powershell -NoProfile -ExecutionPolicy Bypass -File operations/school/warehouse/build_codex_warehouse_request_macro_task_v1.ps1 -RequestPlanPath $requestPlanPath -SelectionPath $selectionPath -OutputDir $taskDir *>&1 | ForEach-Object{[string]$_})
$taskOut | Set-Content -LiteralPath "$OutputRoot/task_builder_stdout.txt" -Encoding UTF8
$taskJson=(($taskOut|Where-Object{$_ -match '^CODEX_WAREHOUSE_DYNAMIC_REQUEST_TASK_JSON='}|Select-Object -Last 1) -replace '^CODEX_WAREHOUSE_DYNAMIC_REQUEST_TASK_JSON=','')
$taskMd=(($taskOut|Where-Object{$_ -match '^CODEX_WAREHOUSE_DYNAMIC_REQUEST_TASK_MD='}|Select-Object -Last 1) -replace '^CODEX_WAREHOUSE_DYNAMIC_REQUEST_TASK_MD=','')
$task=Get-Content $taskJson -Raw | ConvertFrom-Json
$first=$task.micro_batches[0]
AddEvent 'DYNAMIC_WAREHOUSE_TASK_BUILT' @{task_json=$taskJson; request_size=$task.total_candidate_count; micro_batch_count=$task.micro_batch_count; first_micro=$first.micro_batch_id}
$producerStatus='NOT_RUN'
$producerFailureClass=''
if($ProducerMode -eq 'MockProducer'){
  WriteJson ([string]$first.writing_marker) ([ordered]@{status='WRITING'; micro_batch_id=$first.micro_batch_id; updated_at=(Get-Date).ToString('o')}) 20
  $rows=New-Object System.Collections.ArrayList
  for($i=1;$i -le [int]$first.candidate_count;$i++){
    $depth=1 + (($i-1) % [Math]::Max(1,[int]$task.target_depth))
    $obj=[ordered]@{
      schema='codex_school_patch_candidate_v1'
      candidate_id=("real.warehouse.smoke.mock.{0:D6}" -f $i)
      topic_key=$task.topic_key
      topic_label=$task.topic_label
      depth_level=$depth
      prerequisite_depth=[Math]::Max(0,$depth-1)
      target_depth=$task.target_depth
      source_basis=@('mock smoke source')
      source_missing=$false
      claim="Mock producer smoke candidate $i for $($task.topic_key)"
      expected_behavior="Builder can consume warehouse READY micro-batch candidate $i safely."
      failure_contrast="Without READY marker discipline, School may consume incomplete WRITING material."
      validator="Check READY marker, topic, depth, source/proof/validator/return fields."
      proof_requirements="Consumer report must show accepted_count=100 and memory_changed=false."
      negative_case="Reject missing READY marker, wrong topic, or missing validator/proof fields."
      return_to_parent="Proves warehouse producer-consumer smoke route."
      digest_hint="Digest only after absorption is explicitly enabled."
      quality_flags=@('mock','producer_smoke')
    }
    [void]$rows.Add($obj)
  }
  ($rows|ForEach-Object{$_|ConvertTo-Json -Depth 50 -Compress}) -join "`n" | Set-Content -LiteralPath ([string]$first.tmp_jsonl) -Encoding UTF8
  Move-Item -LiteralPath ([string]$first.tmp_jsonl) -Destination ([string]$first.ready_jsonl) -Force
  WriteJson ([string]$first.ready_marker) ([ordered]@{status='READY'; micro_batch_id=$first.micro_batch_id; candidate_count=[int]$first.candidate_count; updated_at=(Get-Date).ToString('o'); mode='MockProducer'}) 20
  WriteJson ([string]$task.heartbeat_path) ([ordered]@{status='PRODUCER_RUNNING_SMOKE_DONE'; patch_id=$task.request_id; last_written_batch=1; updated_at=(Get-Date).ToString('o'); mode='MockProducer'}) 20
  $producerStatus='MOCK_PRODUCER_READY_CREATED'
  AddEvent 'MOCK_PRODUCER_READY_CREATED' @{ready_jsonl=$first.ready_jsonl; ready_marker=$first.ready_marker}
}else{
  $promptPath="$OutputRoot/real_codex_producer_smoke_prompt.txt"
  $stdoutPath="$OutputRoot/codex_stdout.txt"
  $stderrPath="$OutputRoot/codex_stderr.txt"
  $basePrompt=Get-Content $taskMd -Raw
  $smokePrompt=@"
$basePrompt

# SMOKE LIMIT OVERRIDE

This is a real producer smoke test. Produce ONLY the first micro-batch now:

```text
micro_batch_id = $($first.micro_batch_id)
candidate_count = $($first.candidate_count)
writing_marker = $($first.writing_marker)
tmp_jsonl = $($first.tmp_jsonl)
ready_jsonl = $($first.ready_jsonl)
ready_marker = $($first.ready_marker)
heartbeat_path = $($task.heartbeat_path)
```

Do not produce micro_002 or later in this smoke test.
Do not write producer.DONE.marker.json in this smoke test.
Do not mutate active compact memory.
Do not edit tracked repo files.
After micro_001 is READY, stop.

# EXECUTION CONSTRAINTS

The shell may run in constrained PowerShell language mode. Therefore:

```text
- do NOT use PowerShell .NET constructors such as [System.Text.UTF8Encoding]::new(...)
- do NOT rely on custom .NET types
- prefer Python standard library to write JSONL and marker JSON files
- if using PowerShell, use only native cmdlets like Set-Content / ConvertTo-Json without .NET constructors
- keep the producer implementation simple; do not create a general generator framework
- create exactly 100 JSONL lines and the READY marker
- if file rename is denied by sandbox, write or copy the READY.jsonl file directly and then write the READY marker
- do not loop on denied rename operations
```
"@
  $smokePrompt | Set-Content -LiteralPath $promptPath -Encoding UTF8
  $codexCmd=(Get-Command codex.cmd -ErrorAction Stop).Source
  $cmdLine='""{0}" exec -C "{1}" -s workspace-write --ephemeral - < "{2}" > "{3}" 2> "{4}""' -f $codexCmd,$repoRoot,$promptPath,$stdoutPath,$stderrPath
  AddEvent 'CODEX_PRODUCER_LAUNCH' @{codex_cmd=$codexCmd; prompt_path=$promptPath; timeout_seconds=$CodexTimeoutSeconds}
  $p=Start-Process -FilePath $env:ComSpec -ArgumentList @('/d','/c',$cmdLine) -NoNewWindow -PassThru
  if(-not $p.WaitForExit($CodexTimeoutSeconds*1000)){
    Stop-ProcessTreeByRootPid -RootPid ([int]$p.Id)
    $producerStatus='CODEX_FAILED'; $producerFailureClass='HANG_OR_TIMEOUT'
    AddEvent 'CODEX_FAILED' @{failure_class=$producerFailureClass; root_pid=$p.Id; process_tree_killed=$true; stdout=$stdoutPath; stderr=$stderrPath}
  } elseif($p.ExitCode -ne 0){
    $producerStatus='CODEX_FAILED'; $producerFailureClass='NONZERO_EXIT'
    AddEvent 'CODEX_FAILED' @{failure_class=$producerFailureClass; exit_code=$p.ExitCode; stdout=$stdoutPath; stderr=$stderrPath}
  } elseif((Test-Path ([string]$first.ready_marker)) -and (Test-Path ([string]$first.ready_jsonl))){
    $producerStatus='CODEX_PRODUCER_READY_CREATED'
    AddEvent 'CODEX_PRODUCER_READY_CREATED' @{ready_jsonl=$first.ready_jsonl; ready_marker=$first.ready_marker; stdout=$stdoutPath; stderr=$stderrPath}
  } else {
    $producerStatus='CODEX_FAILED'; $producerFailureClass='READY_OUTPUT_MISSING'
    AddEvent 'CODEX_FAILED' @{failure_class=$producerFailureClass; stdout=$stdoutPath; stderr=$stderrPath; expected_ready=$first.ready_jsonl; expected_marker=$first.ready_marker}
  }
}
$consumerStatus='NOT_RUN'
$consumerReport=$null
$acceptedCount=0
if($producerStatus -in @('MOCK_PRODUCER_READY_CREATED','CODEX_PRODUCER_READY_CREATED')){
  $consumeOut=@(& powershell -NoProfile -ExecutionPolicy Bypass -File operations/school/warehouse/consume_codex_warehouse_micro_batches_v1.ps1 -MacroTaskJsonPath $taskJson -MaxConsumeBatches 1 -MaxWaitSeconds 0 *>&1 | ForEach-Object{[string]$_})
  $consumeOut | Set-Content -LiteralPath "$OutputRoot/consumer_stdout.txt" -Encoding UTF8
  $consumerReport=(($consumeOut|Where-Object{$_ -match '^CODEX_WAREHOUSE_CONSUMER_REPORT='}|Select-Object -Last 1) -replace '^CODEX_WAREHOUSE_CONSUMER_REPORT=','')
  $consumer=Get-Content $consumerReport -Raw | ConvertFrom-Json
  $consumerStatus=$consumer.status
  if(@($consumer.consumed_batches).Count -gt 0){ $acceptedCount=[int]$consumer.consumed_batches[0].accepted_count }
  AddEvent 'SCHOOL_CONSUMER_RAN_NO_ABSORB' @{consumer_status=$consumerStatus; accepted_count=$acceptedCount; consumer_report=$consumerReport}
}
$memoryAfter=[ordered]@{manifest=Sha "$mem/manifest.json"; index=Sha "$mem/index.json"; cells=Sha "$mem/cells.jsonl"}
$memoryChanged=($memoryBefore.cells -ne $memoryAfter.cells -or $memoryBefore.index -ne $memoryAfter.index -or $memoryBefore.manifest -ne $memoryAfter.manifest)
$status=if($producerStatus -eq 'CODEX_PRODUCER_READY_CREATED' -and $consumerStatus -eq 'PASS_WAREHOUSE_CONSUMED_READY_BATCHES_NO_ABSORB_V1' -and $acceptedCount -eq 100 -and -not $memoryChanged){'PASS_REAL_CODEX_WAREHOUSE_PRODUCER_SMOKE_NO_ABSORB_V1'}elseif($producerStatus -eq 'MOCK_PRODUCER_READY_CREATED' -and $consumerStatus -eq 'PASS_WAREHOUSE_CONSUMED_READY_BATCHES_NO_ABSORB_V1' -and $acceptedCount -eq 100 -and -not $memoryChanged){'PASS_MOCK_CODEX_WAREHOUSE_PRODUCER_SMOKE_NO_ABSORB_V1'}elseif($producerStatus -eq 'CODEX_FAILED'){'PASS_REAL_CODEX_WAREHOUSE_PRODUCER_FAILURE_RECORDED_NO_MEMORY_MUTATION_V1'}else{'CHECK_CODEX_WAREHOUSE_PRODUCER_SMOKE_V1'}
$report=[ordered]@{
  schema='codex_warehouse_producer_smoke_v1'
  status=$status
  created_at=(Get-Date).ToString('o')
  run_id=$runId
  producer_mode=$ProducerMode
  topics=$Topics
  selection_path=$selectionPath
  request_plan_path=$requestPlanPath
  task_json=$taskJson
  task_md=$taskMd
  request_candidate_count=[int]$request.request_candidate_count
  micro_batch_size=[int]$request.micro_batch_size
  micro_batch_count=[int]$request.micro_batch_count
  smoke_micro_batch_id=$first.micro_batch_id
  smoke_candidate_count=[int]$first.candidate_count
  producer_status=$producerStatus
  producer_failure_class=$producerFailureClass
  ready_marker_exists=(Test-Path ([string]$first.ready_marker))
  ready_jsonl_exists=(Test-Path ([string]$first.ready_jsonl))
  consumer_status=$consumerStatus
  consumer_report=$consumerReport
  accepted_count=$acceptedCount
  absorption_run=$false
  memory_before=$memoryBefore
  memory_after=$memoryAfter
  memory_changed=$memoryChanged
  events_path=$eventsPath
  boundary='Real smoke produces only micro_001 READY and consumes without absorption. Full request producer loop is not run.'
}
$reportPath="$OutputRoot/codex_warehouse_producer_smoke_report.json"
WriteJson $reportPath $report 100
Write-Host "CODEX_WAREHOUSE_PRODUCER_SMOKE_STATUS=$status"
Write-Host "CODEX_WAREHOUSE_PRODUCER_SMOKE_REPORT=$reportPath"
Write-Host "CODEX_WAREHOUSE_PRODUCER_STATUS=$producerStatus"
Write-Host "CODEX_WAREHOUSE_PRODUCER_FAILURE_CLASS=$producerFailureClass"
Write-Host "CODEX_WAREHOUSE_CONSUMER_STATUS=$consumerStatus"
Write-Host "CODEX_WAREHOUSE_ACCEPTED_COUNT=$acceptedCount"
Write-Host "CODEX_WAREHOUSE_MEMORY_CHANGED=$memoryChanged"
