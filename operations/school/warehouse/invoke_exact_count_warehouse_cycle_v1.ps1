
param(
  [ValidateSet('MockProducer','RunCodex')][string]$ProducerMode = 'MockProducer',
  [ValidateRange(1,50000)][int]$Count = 678,
  [ValidateRange(1,10000)][int]$MicroBatchSize = 100,
  [ValidateRange(30,7200)][int]$CodexTimeoutSeconds = 900,
  [switch]$Absorb,
  [string]$Topics = 'AUTO',
  [string]$OutputRoot = ''
)
$ErrorActionPreference='Stop'
$repoRoot=(git rev-parse --show-toplevel).Trim(); Set-Location $repoRoot
function EnsureDir($Path){ if($Path -and -not (Test-Path $Path)){ New-Item -ItemType Directory -Force -Path $Path | Out-Null } }
function WriteJson($Path,$Obj,$Depth=100){ $d=Split-Path -Parent $Path; if($d){ EnsureDir $d }; $Obj|ConvertTo-Json -Depth $Depth|Set-Content -LiteralPath $Path -Encoding UTF8 }
function Sha($p){ if(Test-Path $p){ (Get-FileHash $p -Algorithm SHA256).Hash } else { 'MISSING' } }
function Stop-ProcessTreeByRootPid([int]$RootPid){ $children=@(Get-CimInstance Win32_Process | Where-Object { $_.ParentProcessId -eq $RootPid }); foreach($child in $children){ Stop-ProcessTreeByRootPid -RootPid ([int]$child.ProcessId) }; try{ Stop-Process -Id $RootPid -Force -ErrorAction SilentlyContinue }catch{} }
$mem='.runtime/active_compact_semantic_memory_v1'
$memoryBefore=[ordered]@{manifest=Sha "$mem/manifest.json"; index=Sha "$mem/index.json"; cells=Sha "$mem/cells.jsonl"}
$runId=("exact_count_cycle_{0}_{1}_{2}" -f $Count,$ProducerMode.ToLowerInvariant(),(Get-Date -Format 'yyyyMMdd_HHmmss'))
if([string]::IsNullOrWhiteSpace($OutputRoot)){ $OutputRoot=".runtime/exact_count_cycle/$runId" }
EnsureDir $OutputRoot
$selectionPath="$OutputRoot/selection.json"
$requestPlanPath="$OutputRoot/request_plan.json"
$taskDir="$OutputRoot/warehouse_request"
$eventsPath="$OutputRoot/events.jsonl"
function AddEvent($State,$Data){ ([ordered]@{ts=(Get-Date).ToString('o'); state=$State; data=$Data}|ConvertTo-Json -Depth 80 -Compress)|Add-Content -LiteralPath $eventsPath -Encoding UTF8 }
AddEvent 'EXACT_COUNT_CYCLE_STARTED' @{producer_mode=$ProducerMode; count=$Count; micro_batch_size=$MicroBatchSize; absorb=[bool]$Absorb}
& powershell -NoProfile -ExecutionPolicy Bypass -File operations/school/memory/select_dynamic_theme_cell_v1.ps1 -RequestedTopics $Topics -PatchSize 1000 -OutputPath $selectionPath | Out-Host
& powershell -NoProfile -ExecutionPolicy Bypass -File operations/school/request/plan_dynamic_school_request_v1.ps1 -SelectionPath $selectionPath -OutputPath $requestPlanPath -ExactRequestSize $Count -MicroBatchSize $MicroBatchSize -MaxRequestSize 50000 -MaxReadyBacklogCandidates 3000 | Out-Host
$request=Get-Content $requestPlanPath -Raw | ConvertFrom-Json
$taskOut=@(& powershell -NoProfile -ExecutionPolicy Bypass -File operations/school/warehouse/build_codex_warehouse_request_macro_task_v1.ps1 -RequestPlanPath $requestPlanPath -SelectionPath $selectionPath -OutputDir $taskDir *>&1 | ForEach-Object{[string]$_})
$taskOut | Set-Content -LiteralPath "$OutputRoot/task_builder_stdout.txt" -Encoding UTF8
$taskJson=(($taskOut|Where-Object{$_ -match '^CODEX_WAREHOUSE_DYNAMIC_REQUEST_TASK_JSON='}|Select-Object -Last 1) -replace '^CODEX_WAREHOUSE_DYNAMIC_REQUEST_TASK_JSON=','')
$taskMd=(($taskOut|Where-Object{$_ -match '^CODEX_WAREHOUSE_DYNAMIC_REQUEST_TASK_MD='}|Select-Object -Last 1) -replace '^CODEX_WAREHOUSE_DYNAMIC_REQUEST_TASK_MD=','')
if([string]::IsNullOrWhiteSpace($taskJson) -or -not (Test-Path $taskJson)){ throw 'TASK_JSON_MISSING' }
$task=Get-Content $taskJson -Raw | ConvertFrom-Json
$batchCounts=@($task.micro_batches | ForEach-Object {[int]$_.candidate_count})
$producerStatus='NOT_RUN'; $producerFailureClass=''; $readyBatchCount=0; $readyCandidateCount=0
if($ProducerMode -eq 'MockProducer'){
  foreach($mb in @($task.micro_batches)){
    $rows=New-Object System.Collections.ArrayList
    for($i=1;$i -le [int]$mb.candidate_count;$i++){
      $globalIndex=((([int]$mb.sequence)-1)*$MicroBatchSize)+$i
      $range=[Math]::Max(1,(([int]$task.target_depth - [int]$task.start_depth)+1))
      $depth=[int]$task.start_depth + (($globalIndex-1) % $range)
      $obj=[ordered]@{
        schema='codex_school_patch_candidate_v1'
        candidate_id=("exact.count.mock.{0}.{1:D6}" -f $Count,$globalIndex)
        topic_key=$task.topic_key
        topic_label=$task.topic_label
        depth_level=$depth
        prerequisite_depth=[Math]::Max(0,$depth-1)
        target_depth=$task.target_depth
        source_basis=@('mock exact count source')
        source_missing=$false
        claim=("Mock exact-count candidate {0} of {1} for {2}" -f $globalIndex,$Count,$task.topic_key)
        expected_behavior='Builder can split, validate, and consume exact request batches including partial final batch.'
        failure_contrast='Without generic exact count support, counts are rounded, truncated, or duplicated.'
        validator='Validate total Count, per-batch candidate_count, topic_key, depth range, required fields, and memory boundary.'
        proof_requirements='Cycle report must show accepted_count equals Count and memory_changed matches Absorb mode.'
        negative_case='Reject if final partial batch is rounded or if accepted_count differs from requested Count.'
        return_to_parent='Proves Generic ExactRequestEngine can feed warehouse consumer for arbitrary Count.'
        digest_hint=("Digest into {0} only when absorption is explicitly enabled." -f $task.topic_key)
        quality_flags=@('mock','exact_count','generic_cycle')
      }
      [void]$rows.Add($obj)
    }
    ($rows|ForEach-Object{$_|ConvertTo-Json -Depth 50 -Compress}) -join "`n" | Set-Content -LiteralPath ([string]$mb.ready_jsonl) -Encoding UTF8
    WriteJson ([string]$mb.ready_marker) ([ordered]@{status='READY'; micro_batch_id=$mb.micro_batch_id; candidate_count=[int]$mb.candidate_count; updated_at=(Get-Date).ToString('o'); mode='MockProducer'}) 20
  }
  WriteJson ([string]$task.heartbeat_path) ([ordered]@{status='PRODUCER_DONE'; request_id=$task.request_id; last_written_batch=[int]$task.micro_batch_count; updated_at=(Get-Date).ToString('o'); mode='MockProducer'}) 20
  WriteJson ([string]$task.producer_done_marker) ([ordered]@{status='PRODUCER_DONE'; micro_batch_count=[int]$task.micro_batch_count; candidate_count=[int]$task.total_candidate_count; updated_at=(Get-Date).ToString('o'); mode='MockProducer'}) 20
  $producerStatus='MOCK_PRODUCER_ALL_READY_CREATED'
} else {
  $promptPath="$OutputRoot/codex_exact_count_cycle_prompt.txt"; $stdoutPath="$OutputRoot/codex_stdout.txt"; $stderrPath="$OutputRoot/codex_stderr.txt"
  $batchTable=@($task.micro_batches | ForEach-Object { ("{0}|count={1}|ready_jsonl={2}|ready_marker={3}" -f $_.micro_batch_id,$_.candidate_count,$_.ready_jsonl,$_.ready_marker) })
  $promptLines=New-Object System.Collections.ArrayList
  [void]$promptLines.Add('You are Codex acting only as producer for one exact-count warehouse cycle. You are not the Builder brain.')
  [void]$promptLines.Add('')
  [void]$promptLines.Add(('TARGET_COUNT={0}' -f $Count))
  [void]$promptLines.Add(('MICRO_BATCH_SIZE={0}' -f $MicroBatchSize))
  [void]$promptLines.Add(('MICRO_BATCH_COUNT={0}' -f $task.micro_batch_count))
  [void]$promptLines.Add(('BATCH_COUNTS={0}' -f ($batchCounts -join ',')))
  [void]$promptLines.Add(('TOPIC_KEY={0}' -f $task.topic_key))
  [void]$promptLines.Add(('TOPIC_LABEL={0}' -f $task.topic_label))
  [void]$promptLines.Add(('START_DEPTH={0}' -f $task.start_depth))
  [void]$promptLines.Add(('TARGET_DEPTH={0}' -f $task.target_depth))
  [void]$promptLines.Add(('HEARTBEAT_PATH={0}' -f $task.heartbeat_path))
  [void]$promptLines.Add(('DONE_MARKER={0}' -f $task.producer_done_marker))
  [void]$promptLines.Add('')
  [void]$promptLines.Add('REQUIRED_BATCHES:')
  foreach($line in $batchTable){ [void]$promptLines.Add($line) }
  [void]$promptLines.Add('')
  [void]$promptLines.Add('OUTPUT RULES:')
  [void]$promptLines.Add('- Use Python standard library if possible. Do not use PowerShell .NET constructors.')
  [void]$promptLines.Add('- Do not use tmp files and do not rename files in this cycle.')
  [void]$promptLines.Add('- For each batch, write READY.jsonl directly, then write READY.marker.json.')
  [void]$promptLines.Add('- Write exactly TARGET_COUNT JSONL candidate lines total across all batches.')
  [void]$promptLines.Add('- Write heartbeat and DONE marker after all batches are READY.')
  [void]$promptLines.Add('- Do not mutate active memory. Do not edit tracked repo files.')
  [void]$promptLines.Add('')
  [void]$promptLines.Add('Each JSONL line must be a JSON object with fields: schema,candidate_id,topic_key,topic_label,depth_level,prerequisite_depth,target_depth,source_basis,source_missing,claim,expected_behavior,failure_contrast,validator,proof_requirements,negative_case,return_to_parent,digest_hint,quality_flags.')
  [void]$promptLines.Add('Use schema=codex_school_patch_candidate_v1, topic_key exactly TOPIC_KEY, source_basis as a non-empty array or source_missing=true, and depth_level between START_DEPTH and TARGET_DEPTH.')
  [void]$promptLines.Add('After all READY markers and DONE marker are written, stop.')
  $promptLines | Set-Content -LiteralPath $promptPath -Encoding UTF8
  $codexCmd=(Get-Command codex.cmd -ErrorAction Stop).Source
  $cmdLine='""{0}" exec -C "{1}" -s workspace-write --ephemeral - < "{2}" > "{3}" 2> "{4}""' -f $codexCmd,$repoRoot,$promptPath,$stdoutPath,$stderrPath
  AddEvent 'CODEX_LAUNCH' @{prompt_path=$promptPath; timeout_seconds=$CodexTimeoutSeconds}
  $p=Start-Process -FilePath $env:ComSpec -ArgumentList @('/d','/c',$cmdLine) -NoNewWindow -PassThru
  $completed=$p.WaitForExit($CodexTimeoutSeconds*1000)
  $readyFiles=@($task.micro_batches | Where-Object { (Test-Path ([string]$_.ready_jsonl)) -and (Test-Path ([string]$_.ready_marker)) })
  $readyBatchCount=$readyFiles.Count
  $readyCandidateCount=0
  foreach($mb in $readyFiles){ $readyCandidateCount += (Get-Content ([string]$mb.ready_jsonl) | Measure-Object).Count }
  if(-not $completed){
    Stop-ProcessTreeByRootPid -RootPid ([int]$p.Id)
    if($readyBatchCount -eq [int]$task.micro_batch_count -and $readyCandidateCount -eq $Count){ $producerStatus='CODEX_PRODUCER_ALL_READY_CREATED'; $producerFailureClass='TIMEOUT_AFTER_ALL_READY_OUTPUT' } else { $producerStatus='CODEX_FAILED'; $producerFailureClass=("TIMEOUT_READY_BATCHES_{0}/{1}_CANDIDATES_{2}/{3}" -f $readyBatchCount,$task.micro_batch_count,$readyCandidateCount,$Count) }
  } elseif($p.ExitCode -ne 0){
    if($readyBatchCount -eq [int]$task.micro_batch_count -and $readyCandidateCount -eq $Count){ $producerStatus='CODEX_PRODUCER_ALL_READY_CREATED'; $producerFailureClass=("NONZERO_AFTER_ALL_READY_OUTPUT:{0}" -f $p.ExitCode) } else { $producerStatus='CODEX_FAILED'; $producerFailureClass=("NONZERO_READY_BATCHES_{0}/{1}_CANDIDATES_{2}/{3}" -f $readyBatchCount,$task.micro_batch_count,$readyCandidateCount,$Count) }
  } else {
    if($readyBatchCount -eq [int]$task.micro_batch_count -and $readyCandidateCount -eq $Count){ $producerStatus='CODEX_PRODUCER_ALL_READY_CREATED' } else { $producerStatus='CODEX_FAILED'; $producerFailureClass=("READY_BATCHES_{0}/{1}_CANDIDATES_{2}/{3}" -f $readyBatchCount,$task.micro_batch_count,$readyCandidateCount,$Count) }
  }
}
# Count ready for mock too.
$readyFilesFinal=@($task.micro_batches | Where-Object { (Test-Path ([string]$_.ready_jsonl)) -and (Test-Path ([string]$_.ready_marker)) })
$readyBatchCount=$readyFilesFinal.Count
$readyCandidateCount=0
foreach($mb in $readyFilesFinal){ $readyCandidateCount += (Get-Content ([string]$mb.ready_jsonl) | Measure-Object).Count }
$consumed=0; $accepted=0; $consumerReports=New-Object System.Collections.ArrayList; $consumerStatuses=New-Object System.Collections.ArrayList
if($producerStatus -in @('MOCK_PRODUCER_ALL_READY_CREATED','CODEX_PRODUCER_ALL_READY_CREATED')){
  for($i=1;$i -le [int]$task.micro_batch_count;$i++){
    if($Absorb){ $out=@(& powershell -NoProfile -ExecutionPolicy Bypass -File operations/school/warehouse/consume_codex_warehouse_micro_batches_v1.ps1 -MacroTaskJsonPath $taskJson -MaxConsumeBatches 1 -MaxWaitSeconds 0 -Absorb *>&1 | ForEach-Object{[string]$_}) }
    else { $out=@(& powershell -NoProfile -ExecutionPolicy Bypass -File operations/school/warehouse/consume_codex_warehouse_micro_batches_v1.ps1 -MacroTaskJsonPath $taskJson -MaxConsumeBatches 1 -MaxWaitSeconds 0 *>&1 | ForEach-Object{[string]$_}) }
    $outPath=("{0}/consumer_{1:D3}_stdout.txt" -f $OutputRoot,$i); $out | Set-Content -LiteralPath $outPath -Encoding UTF8
    $cr=(($out|Where-Object{$_ -match '^CODEX_WAREHOUSE_CONSUMER_REPORT='}|Select-Object -Last 1) -replace '^CODEX_WAREHOUSE_CONSUMER_REPORT=','')
    if([string]::IsNullOrWhiteSpace($cr) -or -not (Test-Path $cr)){ break }
    $c=Get-Content $cr -Raw | ConvertFrom-Json
    $snapshotReport=("{0}/consumer_{1:D3}_report.json" -f $OutputRoot,$i)
    Copy-Item -LiteralPath $cr -Destination $snapshotReport -Force
    [void]$consumerReports.Add($snapshotReport); [void]$consumerStatuses.Add($c.status)
    if(@($c.consumed_batches).Count -gt 0){ $consumed += @($c.consumed_batches).Count; $accepted += [int]$c.consumed_batches[0].accepted_count }
  }
}
$memoryAfter=[ordered]@{manifest=Sha "$mem/manifest.json"; index=Sha "$mem/index.json"; cells=Sha "$mem/cells.jsonl"}
$memoryChanged=($memoryBefore.cells -ne $memoryAfter.cells -or $memoryBefore.index -ne $memoryAfter.index -or $memoryBefore.manifest -ne $memoryAfter.manifest)
$status=if($producerStatus -eq 'CODEX_PRODUCER_ALL_READY_CREATED' -and $accepted -eq $Count -and -not $Absorb -and -not $memoryChanged){'PASS_REAL_CODEX_EXACT_COUNT_CYCLE_NO_ABSORB_V1'}elseif($producerStatus -eq 'MOCK_PRODUCER_ALL_READY_CREATED' -and $accepted -eq $Count -and -not $Absorb -and -not $memoryChanged){'PASS_MOCK_EXACT_COUNT_CYCLE_NO_ABSORB_V1'}elseif($producerStatus -eq 'CODEX_PRODUCER_ALL_READY_CREATED' -and $accepted -eq $Count -and $Absorb -and $memoryChanged){'PASS_REAL_CODEX_EXACT_COUNT_CYCLE_WITH_ABSORB_V1'}else{'CHECK_EXACT_COUNT_CYCLE_V1'}
$report=[ordered]@{schema='generic_exact_count_warehouse_cycle_v1'; status=$status; created_at=(Get-Date).ToString('o'); run_id=$runId; producer_mode=$ProducerMode; count=$Count; micro_batch_size=$MicroBatchSize; micro_batch_count=[int]$task.micro_batch_count; batch_counts=$batchCounts; producer_status=$producerStatus; producer_failure_class=$producerFailureClass; ready_batch_count=$readyBatchCount; ready_candidate_count=$readyCandidateCount; consumed_batches=$consumed; accepted_count=$accepted; absorb=[bool]$Absorb; consumer_statuses=@($consumerStatuses); consumer_reports=@($consumerReports); memory_before=$memoryBefore; memory_after=$memoryAfter; memory_changed=$memoryChanged; task_json=$taskJson; output_root=$OutputRoot; boundary='Generic exact Count cycle. Absorption only if -Absorb is passed.'}
$reportPath="$OutputRoot/exact_count_cycle_report.json"
WriteJson $reportPath $report 100
Write-Host "EXACT_COUNT_CYCLE_STATUS=$status"
Write-Host "EXACT_COUNT_CYCLE_REPORT=$reportPath"
Write-Host "EXACT_COUNT_CYCLE_PRODUCER_STATUS=$producerStatus"
Write-Host "EXACT_COUNT_CYCLE_PRODUCER_FAILURE_CLASS=$producerFailureClass"
Write-Host "EXACT_COUNT_CYCLE_BATCH_COUNTS=$($batchCounts -join ',')"
Write-Host "EXACT_COUNT_CYCLE_READY_BATCHES=$readyBatchCount"
Write-Host "EXACT_COUNT_CYCLE_READY_CANDIDATES=$readyCandidateCount"
Write-Host "EXACT_COUNT_CYCLE_CONSUMED_BATCHES=$consumed"
Write-Host "EXACT_COUNT_CYCLE_ACCEPTED_COUNT=$accepted"
Write-Host "EXACT_COUNT_CYCLE_MEMORY_CHANGED=$memoryChanged"
