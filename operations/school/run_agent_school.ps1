param(
  [Parameter(Mandatory=$true)][ValidateRange(1,1000000)][int]$Count,
  [Parameter(Mandatory=$true)][ValidateSet('Test','Live')][string]$Mode,
  [Parameter(Mandatory=$true)][ValidateNotNullOrEmpty()][string]$Topics
)

# Internal implementation is embedded here intentionally.
# ONE BIKE LAW: operations/school/run_agent_school.ps1 is the only public School launcher.
# Former warehouse .ps1 launchers were physically removed to prevent alternate School starts.
function Invoke-SchoolWarehouseConsumer {
param(
  [Parameter(Mandatory=$true)][string]$MacroTaskJsonPath,
  [ValidateRange(1,100)][int]$MaxConsumeBatches = 1,
  [ValidateRange(0,3600)][int]$MaxWaitSeconds = 0,
  [ValidateRange(1,60)][int]$PollSeconds = 5,
  [ValidateRange(1,86400)][int]$StaleWritingSeconds = 900,
  [switch]$Absorb
)
$ErrorActionPreference='Stop'
$repoRoot=(git rev-parse --show-toplevel).Trim(); Set-Location $repoRoot
function EnsureDir($Path){ if($Path -and -not (Test-Path $Path)){ New-Item -ItemType Directory -Force -Path $Path | Out-Null } }
function WriteJson($Path,$Obj,$Depth=100){ $d=Split-Path -Parent $Path; if($d){ EnsureDir $d }; $Obj|ConvertTo-Json -Depth $Depth|Set-Content -LiteralPath $Path -Encoding UTF8 }
function Sha($p){ if(Test-Path $p){ (Get-FileHash $p -Algorithm SHA256).Hash } else { 'MISSING' } }
function AddLedger($Path,$Row){ EnsureDir (Split-Path -Parent $Path); ($Row|ConvertTo-Json -Depth 80 -Compress)|Add-Content -LiteralPath $Path -Encoding UTF8 }
$mem='.runtime/active_compact_semantic_memory_v1'
$memoryBefore=[ordered]@{manifest=Sha "$mem/manifest.json"; index=Sha "$mem/index.json"; cells=Sha "$mem/cells.jsonl"}
if(-not (Test-Path $MacroTaskJsonPath)){ throw "MACRO_TASK_MISSING:$MacroTaskJsonPath" }
$task=Get-Content $MacroTaskJsonPath -Raw | ConvertFrom-Json
$acceptedTaskStatuses=@('CODEX_WAREHOUSE_MACRO_TASK_BUILT','CODEX_WAREHOUSE_DYNAMIC_REQUEST_TASK_BUILT')
if($task.status -notin $acceptedTaskStatuses){ throw "BAD_MACRO_TASK_STATUS:$($task.status)" }
$warehouseRoot=[string]$task.warehouse_root
$ledgerPath=[string]$task.warehouse_ledger_path
EnsureDir $warehouseRoot
$start=Get-Date
$consumed=New-Object System.Collections.ArrayList
$waitEvents=New-Object System.Collections.ArrayList
$status='UNKNOWN'
while($true){
  $ready=@()
  foreach($mb in @($task.micro_batches)){
    if((Test-Path ([string]$mb.ready_marker)) -and (Test-Path ([string]$mb.ready_jsonl)) -and -not (Test-Path ([string]$mb.absorbed_marker)) -and -not (Test-Path ([string]$mb.cleaned_marker)) -and -not (Test-Path ([string]$mb.consuming_marker))){ $ready += $mb }
  }
  if($ready.Count -gt 0){
    foreach($mb in @($ready | Sort-Object sequence | Select-Object -First $MaxConsumeBatches)){
      $consumeMarker=[string]$mb.consuming_marker
      WriteJson $consumeMarker ([ordered]@{status='CONSUMING'; micro_batch_id=$mb.micro_batch_id; started_at=(Get-Date).ToString('o')}) 20
      $microTaskPath=(Join-Path $warehouseRoot ("$($mb.micro_batch_id).micro_task.json"))
      $microTask=[ordered]@{
        schema='codex_school_patch_task_v1'
        status='CODEX_TASK_BUILT'
        run_id=$task.run_id
        patch_id=$task.patch_id
        micro_batch_id=$mb.micro_batch_id
        topic_key=$task.topic_key
        topic_label=$task.topic_label
        current_depth=$task.current_depth
        start_depth=$task.start_depth
        target_depth=$task.target_depth
        candidate_limit=[int]$mb.candidate_count
        required_candidate_fields=@($task.required_candidate_fields)
        output_candidates_jsonl=[string]$mb.ready_jsonl
      }
      WriteJson $microTaskPath $microTask 80
      & powershell -NoProfile -ExecutionPolicy Bypass -File operations/school/codex/validate_and_normalize_codex_school_patch_candidates_v1.ps1 -TaskJsonPath $microTaskPath -CandidatesJsonlPath ([string]$mb.ready_jsonl) -OutputAtomsJsonlPath ([string]$mb.normalized_atoms_jsonl) -ReportPath ([string]$mb.normalization_report) | Out-Host
      $norm=Get-Content ([string]$mb.normalization_report) -Raw | ConvertFrom-Json
      $state='VALIDATED_NORMALIZED'
      $absorbStatus='NOT_RUN'
      $absorbProof=$null
      if($Absorb){
        $absorbOut=@(& powershell -NoProfile -ExecutionPolicy Bypass -File operations/school/digestion/absorb_atom_file_via_digest_pipeline_v1.ps1 -InputPath ([string]$mb.normalized_atoms_jsonl) -SizeBudgetBytes 26214400 *>&1 | ForEach-Object{[string]$_})
        $absorbStatus=(($absorbOut|Where-Object{$_ -match '^FILE_ATOM_ABSORPTION_STATUS='}|Select-Object -Last 1) -replace '^FILE_ATOM_ABSORPTION_STATUS=','')
        $absorbProof=(($absorbOut|Where-Object{$_ -match '^PROOF_PATH='}|Select-Object -Last 1) -replace '^PROOF_PATH=','')
        if($absorbStatus -ne 'PASS_FILE_ATOM_ABSORPTION_PIPELINE_V1'){ throw "MICRO_ABSORPTION_FAILED:$absorbStatus" }
        WriteJson ([string]$mb.absorbed_marker) ([ordered]@{status='ABSORBED'; micro_batch_id=$mb.micro_batch_id; absorbed_at=(Get-Date).ToString('o'); proof=$absorbProof}) 30
        $state='ABSORBED'
      }
      AddLedger $ledgerPath ([ordered]@{ts=(Get-Date).ToString('o'); micro_batch_id=$mb.micro_batch_id; sequence=$mb.sequence; state=$state; candidate_count=[int]$mb.candidate_count; normalization_report=[string]$mb.normalization_report; normalized_atoms_jsonl=[string]$mb.normalized_atoms_jsonl; absorption_status=$absorbStatus; absorption_proof=$absorbProof})
      [void]$consumed.Add([pscustomobject]@{micro_batch_id=$mb.micro_batch_id; state=$state; candidate_count=[int]$mb.candidate_count; accepted_count=[int]$norm.accepted_count; absorption_status=$absorbStatus})
    }
    $status=if($Absorb){'PASS_WAREHOUSE_CONSUMED_READY_BATCHES_WITH_ABSORB_V1'}else{'PASS_WAREHOUSE_CONSUMED_READY_BATCHES_NO_ABSORB_V1'}
    break
  }
  $writing=@()
  foreach($mb in @($task.micro_batches)){
    if((Test-Path ([string]$mb.writing_marker)) -and -not (Test-Path ([string]$mb.ready_marker))){
      $age=[int]((Get-Date)-(Get-Item ([string]$mb.writing_marker)).LastWriteTime).TotalSeconds
      $writing += [pscustomobject]@{micro_batch_id=$mb.micro_batch_id; age_seconds=$age; stale=($age -gt $StaleWritingSeconds)}
    }
  }
  $heartbeat=$null; $heartbeatFresh=$false
  if(Test-Path ([string]$task.heartbeat_path)){
    try{ $heartbeat=Get-Content ([string]$task.heartbeat_path) -Raw | ConvertFrom-Json }catch{}
    if($heartbeat -and $heartbeat.PSObject.Properties['updated_at']){
      try{ $heartbeatFresh=(((Get-Date)-([datetime]$heartbeat.updated_at)).TotalSeconds -le $StaleWritingSeconds) }catch{}
    }
  }
  $done=Test-Path ([string]$task.producer_done_marker)
  $failed=Test-Path ([string]$task.producer_failed_marker)
  [void]$waitEvents.Add([pscustomobject]@{ts=(Get-Date).ToString('o'); ready_count=0; writing_count=$writing.Count; stale_writing_count=@($writing|Where-Object{$_.stale}).Count; heartbeat_fresh=$heartbeatFresh; producer_done=$done; producer_failed=$failed})
  if(@($writing|Where-Object{$_.stale}).Count -gt 0){ $status='PASS_WAREHOUSE_CONSUMER_STALE_WRITING_DETECTED_V1'; break }
  if($failed){ $status='PASS_WAREHOUSE_CONSUMER_PRODUCER_FAILED_DETECTED_V1'; break }
  if($done){ $status='PASS_WAREHOUSE_CONSUMER_NO_READY_PRODUCER_DONE_V1'; break }
  if(((Get-Date)-$start).TotalSeconds -ge $MaxWaitSeconds){ $status='PASS_WAREHOUSE_CONSUMER_WAIT_TIMEOUT_NO_READY_V1'; break }
  Start-Sleep -Seconds $PollSeconds
}
$memoryAfter=[ordered]@{manifest=Sha "$mem/manifest.json"; index=Sha "$mem/index.json"; cells=Sha "$mem/cells.jsonl"}
$report=[ordered]@{
  schema='codex_warehouse_consumer_report_v1'
  status=$status
  created_at=(Get-Date).ToString('o')
  macro_task=$MacroTaskJsonPath
  warehouse_root=$warehouseRoot
  ledger_path=$ledgerPath
  max_consume_batches=$MaxConsumeBatches
  consumed_batches=@($consumed)
  wait_events=@($waitEvents)
  absorb_requested=[bool]$Absorb
  memory_before=$memoryBefore
  memory_after=$memoryAfter
  memory_changed=($memoryBefore.cells -ne $memoryAfter.cells -or $memoryBefore.index -ne $memoryAfter.index -or $memoryBefore.manifest -ne $memoryAfter.manifest)
  counted_memory_state='ABSORBED only'
}
$reportPath=Join-Path $warehouseRoot 'warehouse_consumer_report.json'
WriteJson $reportPath $report 100
Write-Host "CODEX_WAREHOUSE_CONSUMER_STATUS=$status"
Write-Host "CODEX_WAREHOUSE_CONSUMER_REPORT=$reportPath"
Write-Host "CODEX_WAREHOUSE_CONSUMED_COUNT=$($consumed.Count)"
Write-Host "CODEX_WAREHOUSE_MEMORY_CHANGED=$($report.memory_changed)"
}

function Invoke-SchoolExactCountWarehouseCycle {
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
    if($Absorb){ $out=@(& { Invoke-SchoolWarehouseConsumer -MacroTaskJsonPath $taskJson -MaxConsumeBatches 1 -MaxWaitSeconds 0 -Absorb } *>&1 | ForEach-Object{[string]$_}) }
    else { $out=@(& { Invoke-SchoolWarehouseConsumer -MacroTaskJsonPath $taskJson -MaxConsumeBatches 1 -MaxWaitSeconds 0 } *>&1 | ForEach-Object{[string]$_}) }
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
}

$TargetAccepted=$Count
$RunKind=if($Mode -eq 'Live'){'Real'}else{'Test'}
$RequestedTopics=$Topics
$PatchSize=1000
$TopicsPlan='operations/school/curriculum/topics/builder_night_school_topics_v1.json'
$runId="school_factory_digest_use_{0}_{1}_{2}" -f $RunKind.ToLowerInvariant(),$TargetAccepted,(Get-Date -Format 'yyyyMMdd_HHmmss')
$ResumeOrdinalOffset=0
$ResumeCompletedChunks=0
$ResumePlannedTotalAccepted=0
if(-not (Test-Path $TopicsPlan)){ throw "CANONICAL_TOPICS_PLAN_MISSING:$TopicsPlan" }

# Generic Exact Count Warehouse Cycle canonical route.
# Owner-facing fields remain only Count, Mode, Topics.
# Test = mock producer/no absorption. Live = real Codex producer/absorption.
if($env:EF_SCHOOL_DISABLE_EXACT_COUNT_CYCLE_V1 -ne '1'){
  $ExactCycleRunId="canonical_exact_count_cycle_{0}_{1}_{2}" -f $RunKind.ToLowerInvariant(),$TargetAccepted,(Get-Date -Format 'yyyyMMdd_HHmmss')
  $ExactCycleRoot=".runtime/canonical_exact_count_cycle/$ExactCycleRunId"
  $ExactCycleProducerMode=if($RunKind -eq 'Real'){'RunCodex'}else{'MockProducer'}
  $ExactCycleArgs=[ordered]@{ ProducerMode=$ExactCycleProducerMode; Count=$TargetAccepted; MicroBatchSize=100; Topics=$RequestedTopics; OutputRoot=$ExactCycleRoot; CodexTimeoutSeconds=300 }
  if($RunKind -eq 'Real'){
    $ExactCycleArgs['CodexTimeoutSeconds']=900
    $ExactCycleArgs['Absorb']=$true
  }
  $ExactCycleOut=@(& { Invoke-SchoolExactCountWarehouseCycle @ExactCycleArgs } *>&1 | ForEach-Object{[string]$_})
  New-Item -ItemType Directory -Force -Path $ExactCycleRoot | Out-Null
  $ExactCycleOut | Set-Content -LiteralPath (Join-Path $ExactCycleRoot 'canonical_exact_cycle_stdout.txt') -Encoding UTF8
  $ExactCycleReportPath=(($ExactCycleOut|Where-Object{$_ -match '^EXACT_COUNT_CYCLE_REPORT='}|Select-Object -Last 1) -replace '^EXACT_COUNT_CYCLE_REPORT=','')
  if([string]::IsNullOrWhiteSpace($ExactCycleReportPath) -or -not (Test-Path $ExactCycleReportPath)){ throw "CANONICAL_EXACT_COUNT_CYCLE_REPORT_MISSING" }
  $ExactCycleReport=Get-Content $ExactCycleReportPath -Raw | ConvertFrom-Json
  $ExpectedExactStatus=if($RunKind -eq 'Real'){'PASS_REAL_CODEX_EXACT_COUNT_CYCLE_WITH_ABSORB_V1'}else{'PASS_MOCK_EXACT_COUNT_CYCLE_NO_ABSORB_V1'}
  if($ExactCycleReport.status -ne $ExpectedExactStatus){ throw ("CANONICAL_EXACT_COUNT_CYCLE_STATUS_BAD:{0}:expected:{1}" -f $ExactCycleReport.status,$ExpectedExactStatus) }
  if([int]$ExactCycleReport.accepted_count -ne [int]$TargetAccepted){ throw ("CANONICAL_EXACT_COUNT_CYCLE_ACCEPTED_MISMATCH:{0}/{1}" -f $ExactCycleReport.accepted_count,$TargetAccepted) }
  $proofPath="operations/reports/CANONICAL_EXACT_COUNT_CYCLE_RUN_{0}.json" -f (Get-Date -Format 'yyyyMMdd_HHmmss')
  $base=[ordered]@{
    schema='agent_school_canonical_exact_count_cycle_v1'
    status=if($RunKind -eq 'Real'){'PASS_CANONICAL_EXACT_COUNT_CYCLE_LIVE_V1'}else{'PASS_CANONICAL_EXACT_COUNT_CYCLE_TEST_V1'}
    run_id=$ExactCycleRunId
    run_kind=$RunKind
    public_mode=$Mode
    target_accepted=[int]$TargetAccepted
    requested_topics=$RequestedTopics
    owner_fields='Count,Mode,Topics'
    route='ONE_PUBLIC_SCHOOL_LAUNCHER_EMBEDDED_ENGINE_V1'
    producer_mode=$ExactCycleProducerMode
    cycle_status=$ExactCycleReport.status
    cycle_report=$ExactCycleReportPath
    count=[int]$ExactCycleReport.count
    micro_batch_size=[int]$ExactCycleReport.micro_batch_size
    micro_batch_count=[int]$ExactCycleReport.micro_batch_count
    batch_counts=@($ExactCycleReport.batch_counts)
    ready_batch_count=[int]$ExactCycleReport.ready_batch_count
    ready_candidate_count=[int]$ExactCycleReport.ready_candidate_count
    consumed_batches=[int]$ExactCycleReport.consumed_batches
    accepted_count=[int]$ExactCycleReport.accepted_count
    absorb=[bool]$ExactCycleReport.absorb
    memory_changed=[bool]$ExactCycleReport.memory_changed
    codex_cli_invoked=($ExactCycleProducerMode -eq 'RunCodex')
    api_invoked=$false
    runtime_ready=$false
    boundary=if($RunKind -eq 'Real'){'Canonical Live uses the single public School launcher with embedded real Codex warehouse engine and absorption.'}else{'Canonical Test uses the single public School launcher with embedded mock warehouse engine and no absorption.'}
    no_fake_pass=$true
    no_hidden_failures=$true
    law='Owner launch uses one public School launcher with Count + Mode + Topics. Count is exact and may be non-rounded. Embedded engine splits Count into micro-batches of 100 with partial final batch.'
  }
  $base | ConvertTo-Json -Depth 100 | Set-Content -LiteralPath $proofPath -Encoding UTF8
  Write-Host 'FINALIZER_STATUS=SKIPPED_EXACT_COUNT_CYCLE_CANONICAL_ROUTE'
  Write-Host 'FINALIZER_INTAKE_STATUS=SKIPPED_EXACT_COUNT_CYCLE_CANONICAL_ROUTE'
  Write-Host 'FINALIZER_MERGE_QUEUE_STATUS=SKIPPED_EXACT_COUNT_CYCLE_CANONICAL_ROUTE'
  Write-Host 'FINALIZER_MERGE_QUEUE_PROOF=SKIPPED_EXACT_COUNT_CYCLE_CANONICAL_ROUTE'
  Write-Host "SCHOOL_RUN_STATUS=$($base.status)"
  Write-Host "PROOF_PATH=$proofPath"
Write-Host "SCHOOL_RUN_REPORT=$proofPath"
  Write-Host "TARGET_ACCEPTED=$TargetAccepted"
  Write-Host "RUN_KIND=$RunKind"
  Write-Host "REQUESTED_TOPICS=$RequestedTopics"
  Write-Host 'PATCH_SIZE=100'
  Write-Host "EXACT_COUNT_CYCLE_STATUS=$($base.cycle_status)"
  Write-Host "EXACT_COUNT_CYCLE_REPORT=$ExactCycleReportPath"
  Write-Host "EXACT_COUNT_CYCLE_BATCH_COUNTS=$(@($base.batch_counts) -join ',')"
  Write-Host "EXACT_COUNT_CYCLE_ACCEPTED_COUNT=$($base.accepted_count)"
  Write-Host "EXACT_COUNT_CYCLE_ABSORB=$($base.absorb)"
  Write-Host "EXACT_COUNT_CYCLE_MEMORY_CHANGED=$($base.memory_changed)"
  Write-Host 'RUNTIME_READY=false'
  return
}

# Dynamic theme cell selection: school looks at compact memory before choosing material direction.
$DynamicThemeSelectionPath=".runtime/school_dynamic_theme_selection/${runId}_selection.json"
$DynamicThemeSelectionOut=@(& powershell -NoProfile -ExecutionPolicy Bypass -File operations/school/memory/select_dynamic_theme_cell_v1.ps1 -RequestedTopics $RequestedTopics -PatchSize $PatchSize -OutputPath $DynamicThemeSelectionPath *>&1 | ForEach-Object{[string]$_})
$DynamicThemeSelectionOut | Set-Content -LiteralPath ".runtime/school_dynamic_theme_selection/${runId}_selection_stdout.txt" -Encoding UTF8
$DynamicThemeSelectionStatus=(($DynamicThemeSelectionOut|Where-Object{$_ -match '^DYNAMIC_THEME_SELECTION_STATUS='}|Select-Object -Last 1) -replace '^DYNAMIC_THEME_SELECTION_STATUS=','')
$AllowedDynamicThemeSelectionStatuses=@('PASS_DYNAMIC_THEME_CELL_SELECTION_V1','PASS_DEVELOPMENT_VECTOR_THEME_SELECTION_V1')
if($AllowedDynamicThemeSelectionStatuses -notcontains $DynamicThemeSelectionStatus){ throw "DYNAMIC_THEME_SELECTION_FAILED:$DynamicThemeSelectionStatus" }
Write-Host "SCHOOL_DYNAMIC_THEME_SELECTION_STATUS=$DynamicThemeSelectionStatus"
Write-Host "SCHOOL_DYNAMIC_THEME_SELECTION_PROOF=$DynamicThemeSelectionPath"
$TopicPatchPlanPath=".runtime/school_patch_runs/${runId}/topic_patch_plan.json"
$TopicPatchLedgerPath=".runtime/school_patch_runs/${runId}/patch_ledger.jsonl"
$TopicPatchPlanOut=@(& powershell -NoProfile -ExecutionPolicy Bypass -File operations/school/plan_topic_patch_cycle_v1.ps1 -Count $TargetAccepted -Mode $Mode -Topics $RequestedTopics -RunId $runId -PatchSize $PatchSize -DynamicSelectionPath $DynamicThemeSelectionPath -OutputPath $TopicPatchPlanPath -LedgerPath $TopicPatchLedgerPath *>&1 | ForEach-Object{[string]$_})
$TopicPatchPlanOut | Set-Content -LiteralPath ".runtime/school_patch_runs/${runId}/topic_patch_plan_stdout.txt" -Encoding UTF8
$TopicPatchPlanStatus=(($TopicPatchPlanOut|Where-Object{$_ -match '^TOPIC_PATCH_PLAN_STATUS='}|Select-Object -Last 1) -replace '^TOPIC_PATCH_PLAN_STATUS=','')
if($TopicPatchPlanStatus -notin @('PASS_TOPIC_PATCH_PLAN_READY','PASS_TOPIC_PATCH_PLAN_ALREADY_ABSORBED')){ throw "TOPIC_PATCH_PLAN_FAILED:$TopicPatchPlanStatus" }
Write-Host "SCHOOL_TOPIC_PATCH_PLAN_STATUS=$TopicPatchPlanStatus"
Write-Host "SCHOOL_TOPIC_PATCH_PLAN_PROOF=$TopicPatchPlanPath"
Write-Host "SCHOOL_TOPIC_PATCH_LEDGER=$TopicPatchLedgerPath"
$ErrorActionPreference='Stop'
$repoRoot=(git rev-parse --show-toplevel).Trim(); Set-Location $repoRoot
$utf8=New-Object System.Text.UTF8Encoding($false)
function EnsureDir($Path){ if(-not (Test-Path $Path)){ New-Item -ItemType Directory -Force $Path | Out-Null } }
function WriteJson($Path,$Obj,$Depth=100){ $d=Split-Path $Path -Parent; if($d){ EnsureDir $d }; [IO.File]::WriteAllText((Join-Path (Get-Location).Path $Path),($Obj|ConvertTo-Json -Depth $Depth),$utf8) }
function FileSha256($Path){
  $sha=[System.Security.Cryptography.SHA256]::Create()
  $fs=[IO.File]::OpenRead((Resolve-Path $Path).Path)
  try { (($sha.ComputeHash($fs)|ForEach-Object{$_.ToString('x2')}) -join '') } finally { $fs.Dispose() }
}
function ReadJsonRequired($Path,$ExpectedStatus,$Label){
  if(-not (Test-Path $Path)){ throw ("RECOVERY_CONTRACT_MISSING:{0}:{1}" -f $Label,$Path) }
  $obj=Get-Content $Path -Raw|ConvertFrom-Json
  if($ExpectedStatus -and [string]$obj.status -ne $ExpectedStatus){ throw ("RECOVERY_CONTRACT_STATUS_BAD:{0}:{1}" -f $Label,$obj.status) }
  return $obj
}
function IsTrackedPath($Path){
  if([string]::IsNullOrWhiteSpace([string]$Path)){ return $false }
  $rel=([string]$Path).Replace('\\','/').Replace('\','/')
  $tracked=@(git ls-files -- $rel 2>$null)
  return ($tracked.Count -gt 0)
}
function RemoveTrash($Items){
  $removed=@()
  $safeRuntimeTrash=@('.runtime/codex_curriculum_candidate_factory_runs','.runtime/file_atom_absorption','.runtime/memory_use_probes','.runtime/digestion_policy','.runtime/digestion_reports')
  foreach($target in @($Items + $safeRuntimeTrash)){
    if([string]::IsNullOrWhiteSpace([string]$target)){ continue }
    $removeTarget=[string]$target
    if($removeTarget -eq 'operations/reports'){ continue }
    if((Test-Path $removeTarget) -and -not (Get-Item $removeTarget).PSIsContainer){
      if(IsTrackedPath $removeTarget){ continue }
      $removeTarget=Split-Path $removeTarget -Parent
    }
    if($removeTarget -and (Test-Path $removeTarget)){
      if(IsTrackedPath $removeTarget){ continue }
      Remove-Item $removeTarget -Recurse -Force
      $removed += $removeTarget
    }
  }
  return @($removed | Select-Object -Unique)
}
$continueContractPath='self_build_batch/runtime/CONTINUE_ON_FAILURE_RUNTIME_V1.json'
$quarantineContractPath='self_build_batch/quarantine/QUARANTINE_AND_BLOCKER_REGISTRY_V1.json'
$proofAggregatorPath='self_build_batch/proof_aggregation/BATCH_PROOF_AGGREGATOR_V1.json'
$continueContract=ReadJsonRequired $continueContractPath 'ACTIVE_RUNTIME_CONTRACT' 'continue_on_failure_runtime'
$quarantineContract=ReadJsonRequired $quarantineContractPath 'ACTIVE_REGISTRY_CONTRACT' 'quarantine_blocker_registry'
$proofAggregator=ReadJsonRequired $proofAggregatorPath 'ACTIVE_AGGREGATOR_CONTRACT' 'batch_proof_aggregator'
$recoveryContracts=[ordered]@{
  wiring_status='SCHOOL_CHUNK_RECOVERY_CONTRACTS_WIRED_V1'
  continue_on_failure_runtime=[ordered]@{path=$continueContractPath; status=$continueContract.status; runtime_id=$continueContract.runtime_id; sha256=FileSha256 $continueContractPath}
  quarantine_blocker_registry=[ordered]@{path=$quarantineContractPath; status=$quarantineContract.status; registry_id=$quarantineContract.registry_id; sha256=FileSha256 $quarantineContractPath}
  batch_proof_aggregator=[ordered]@{path=$proofAggregatorPath; status=$proofAggregator.status; aggregator_id=$proofAggregator.aggregator_id; sha256=FileSha256 $proofAggregatorPath}
  no_fake_pass_policy=$proofAggregator.aggregation_policy.no_fake_pass
  no_hidden_failures_policy=$proofAggregator.aggregation_policy.no_hidden_failures
  record_failure_before_continuing=$continueContract.continue_rules.record_failure_before_continuing
  record_quarantine_before_continuing=$continueContract.continue_rules.record_quarantine_before_continuing
  stop_on_systemic_failure=$continueContract.stop_rules.stop_on_systemic_failure
  no_blind_retry=$quarantineContract.registry_policy.no_blind_retry
  proof_boundary='Contracts are wired into school proof. Controlled chunk failure/resume remains NOT_PROVEN until a deliberate negative test.'
  memory_rollback_capability='SCHOOL_REAL_CHUNK_MEMORY_CHECKPOINT_ROLLBACK_V1'
  failure_test_hook='GUARDED_BY_OWNER_APPROVED_FAILURE_TEST_TOKEN'
}
function GetMemoryState($Root){
  $manifestPath=Join-Path $Root 'manifest.json'
  $cellsPath=Join-Path $Root 'cells.jsonl'
  if(-not (Test-Path $manifestPath)){ return [ordered]@{exists=$false; root=$Root; run_id=$null; cells=0; cells_sha256='MISSING'; manifest_sha256='MISSING'} }
  $manifest=Get-Content $manifestPath -Raw|ConvertFrom-Json
  $cells=0
  if(Test-Path $cellsPath){ $cells=(Get-Content $cellsPath|Measure-Object -Line).Lines }
  return [ordered]@{
    exists=$true
    root=$Root
    run_id=$manifest.run_id
    status=$manifest.status
    cells=$cells
    manifest_cell_count=[int]$manifest.cell_count
    cells_sha256=(Get-FileHash -Algorithm SHA256 $cellsPath).Hash
    manifest_sha256=(Get-FileHash -Algorithm SHA256 $manifestPath).Hash
  }
}
function NewMemoryCheckpoint($Root,$RunId,$ChunkIndex,$OrdinalOffset){
  if(-not (Test-Path $Root)){ throw "MEMORY_ROOT_MISSING_FOR_CHECKPOINT:$Root" }
  $checkpointRoot=".runtime/school_runs/$RunId/memory_checkpoints/chunk_${ChunkIndex}_offset_${OrdinalOffset}"
  EnsureDir $checkpointRoot
  $snapshotPath=Join-Path $checkpointRoot 'active_compact_semantic_memory_v1'
  if(Test-Path $snapshotPath){ Remove-Item $snapshotPath -Recurse -Force }
  $before=GetMemoryState $Root
  Copy-Item -Path $Root -Destination $snapshotPath -Recurse -Force
  $snapshot=GetMemoryState $snapshotPath
  if($before.cells_sha256 -ne $snapshot.cells_sha256 -or $before.manifest_sha256 -ne $snapshot.manifest_sha256 -or $before.run_id -ne $snapshot.run_id){ throw 'MEMORY_CHECKPOINT_COPY_MISMATCH' }
  return [ordered]@{
    schema='school_real_chunk_memory_checkpoint_v1'
    status='CHECKPOINT_READY'
    checkpoint_kind='ACTIVE_COMPACT_MEMORY_BEFORE_REAL_CHUNK'
    run_id=$RunId
    chunk_index=[int]$ChunkIndex
    ordinal_offset=[int]$OrdinalOffset
    checkpoint_root=$checkpointRoot
    snapshot_path=$snapshotPath
    before_state=$before
    snapshot_state=$snapshot
  }
}
function PruneMemoryCheckpoints($RunId,[int]$KeepLatest=3){
  $removed=@()
  if([string]::IsNullOrWhiteSpace([string]$RunId)){ return @() }
  if($KeepLatest -lt 1){ $KeepLatest=1 }
  $root=".runtime/school_runs/$RunId/memory_checkpoints"
  if(-not(Test-Path $root)){ return @() }
  $dirs=@(Get-ChildItem $root -Directory -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending)
  if($dirs.Count -le $KeepLatest){ return @() }
  foreach($d in @($dirs | Select-Object -Skip $KeepLatest)){
    Remove-Item $d.FullName -Recurse -Force
    $removed += $d.FullName
  }
  return @($removed)
}
function RestoreMemoryCheckpoint($Checkpoint,$Root){
  if($null -eq $Checkpoint){ return [ordered]@{status='NO_CHECKPOINT_AVAILABLE'; restored=$false; reason='checkpoint_missing'} }
  $snapshotPath=[string]$Checkpoint.snapshot_path
  if([string]::IsNullOrWhiteSpace($snapshotPath) -or -not (Test-Path $snapshotPath)){ return [ordered]@{status='CHECKPOINT_SNAPSHOT_MISSING'; restored=$false; checkpoint=$Checkpoint} }
  $beforeFailure=GetMemoryState $Root
  if(Test-Path $Root){ Remove-Item $Root -Recurse -Force }
  $parent=Split-Path $Root -Parent
  if($parent){ EnsureDir $parent }
  Copy-Item -Path $snapshotPath -Destination $Root -Recurse -Force
  $afterRestore=GetMemoryState $Root
  $expected=$Checkpoint.before_state
  $matched=($afterRestore.cells_sha256 -eq $expected.cells_sha256 -and $afterRestore.manifest_sha256 -eq $expected.manifest_sha256 -and $afterRestore.run_id -eq $expected.run_id)
  return [ordered]@{
    schema='school_real_chunk_memory_rollback_v1'
    status=if($matched){'ROLLBACK_RESTORED_ACTIVE_MEMORY_V1'}else{'ROLLBACK_RESTORE_MISMATCH_V1'}
    restored=$matched
    root=$Root
    checkpoint_root=$Checkpoint.checkpoint_root
    snapshot_path=$snapshotPath
    chunk_index=[int]$Checkpoint.chunk_index
    ordinal_offset=[int]$Checkpoint.ordinal_offset
    before_failure_state=$beforeFailure
    restored_state=$afterRestore
    expected_state=$expected
  }
}
function BuildResumeState($Status,$FailureState,$CompletedChunks,$CurrentChunkIndex,$CurrentOffset,$NextChunkIndex,$NextOffset,$ErrorMessage){
  return [ordered]@{
    status=$Status
    failure_state=$FailureState
    completed_chunk_count=[int]$CompletedChunks
    current_chunk_index=[int]$CurrentChunkIndex
    current_ordinal_offset=[int]$CurrentOffset
    next_chunk_index=[int]$NextChunkIndex
    resume_ordinal_offset=[int]$NextOffset
    last_good_chunk_index=[int]$CompletedChunks
    error=$ErrorMessage
    resume_requires='OWNER_OR_REPAIR_DECISION_AFTER_FAILURE_CLASSIFICATION'
  }
}
function BuildAggregationSummary($Status,$Chunks,$FailedCount,$QuarantinedCount,$BlockedCount,$AssistanceCount){
  return [ordered]@{
    status=$Status
    planned_chunk_count=$null
    pass_count=[int]@($Chunks).Count
    failed_count=[int]$FailedCount
    quarantined_count=[int]$QuarantinedCount
    blocked_count=[int]$BlockedCount
    assistance_required_count=[int]$AssistanceCount
    unresolved_record_count=([int]$FailedCount+[int]$QuarantinedCount+[int]$BlockedCount+[int]$AssistanceCount)
    no_fake_pass=$true
    no_hidden_failures=$true
    source_contract=$proofAggregatorPath
  }
}
function TestSchoolStopRequested($RunId,$ChunkIndex,$OrdinalOffset,$ProcessedInThisRun,$TargetAccepted,$Reason){
  $stopPath=if($env:EF_SCHOOL_STOP_REQUEST_PATH){[string]$env:EF_SCHOOL_STOP_REQUEST_PATH}else{'.runtime/control/school_stop_requested.json'}
  if(-not (Test-Path $stopPath)){ return $false }
  $request=$null
  try { $request=Get-Content $stopPath -Raw | ConvertFrom-Json } catch { $request=[ordered]@{ parse_error=$_.Exception.Message } }
  $ackPath=(".runtime/control/school_stop_ack_{0}_chunk_{1}.json" -f $RunId,$ChunkIndex)
  $ack=[ordered]@{
    schema='school_controlled_stop_ack_v1'
    status='CONTROLLED_STOP_REQUEST_ACKNOWLEDGED'
    run_id=$RunId
    chunk_index=[int]$ChunkIndex
    ordinal_offset=[int]$OrdinalOffset
    processed_in_this_run=[int]$ProcessedInThisRun
    target_accepted=[int]$TargetAccepted
    remaining_target=[int]([Math]::Max(0,$TargetAccepted-$ProcessedInThisRun))
    reason=$Reason
    stop_request_path=$stopPath
    stop_request=$request
    resume_hint=[ordered]@{ resume_completed_chunks=[int]($ChunkIndex-1); resume_ordinal_offset=[int]$OrdinalOffset; resume_remaining_target=[int]([Math]::Max(0,$TargetAccepted-$ProcessedInThisRun)) }
    active_memory_root='.runtime/active_compact_semantic_memory_v1'
    runtime_ready=$false
    created_at=(Get-Date).ToString('o')
  }
  WriteJson $ackPath $ack 100
  Write-Host "SCHOOL_CONTROLLED_STOP_ACK=$ackPath"
  Write-Host 'SCHOOL_RUN_STATUS=CONTROLLED_STOP_REQUEST_ACKNOWLEDGED'
  return $true
}
$proofDir=".runtime/school_runs/$runId"
$proofPath="$proofDir/AGENT_SCHOOL_CANONICAL_ENTRYPOINT_V1.json"
$routePath='operations/school/curriculum/incremental_active_store/ACTIVE_REPO_BODY_ROUTE_POINTER_V1.json'
$ledgerPath='operations/school/curriculum/incremental_active_store/ACTIVE_REPO_BODY_ROUTE_REPLAY_LEDGER_V1.json'
$routeBefore=Get-Content $routePath -Raw|ConvertFrom-Json
$ledgerBefore=Get-Content $ledgerPath -Raw|ConvertFrom-Json
$outerChunkSize=$PatchSize
$resumeMode=($ResumeOrdinalOffset -gt 0 -or $ResumeCompletedChunks -gt 0 -or $ResumePlannedTotalAccepted -gt 0)
if($ResumeOrdinalOffset -lt 0 -or $ResumeCompletedChunks -lt 0 -or $ResumePlannedTotalAccepted -lt 0){ throw 'RESUME_PARAMS_NEGATIVE' }
if($resumeMode -and $ResumePlannedTotalAccepted -lt ($ResumeOrdinalOffset + $TargetAccepted)){ throw 'RESUME_PLANNED_TOTAL_LT_OFFSET_PLUS_TARGET' }
$plannedTotalAccepted=if($ResumePlannedTotalAccepted -gt 0){$ResumePlannedTotalAccepted}else{$ResumeOrdinalOffset + $TargetAccepted}
if($env:EF_SCHOOL_OUTER_CHUNK_SIZE){ $outerChunkSize=[int]$env:EF_SCHOOL_OUTER_CHUNK_SIZE }
if($outerChunkSize -lt 1){ throw 'BAD_OUTER_CHUNK_SIZE' }
$innerBatchSizeMax=100
$failureTestEnabled=$false
$failureTestChunk=0
$failureTestStage=''
if($env:EF_SCHOOL_FORCE_FAIL_CHUNK_INDEX -or $env:EF_SCHOOL_FORCE_FAIL_STAGE -or $env:EF_SCHOOL_FAILURE_TEST_TOKEN){
  if($env:EF_SCHOOL_FAILURE_TEST_TOKEN -ne 'OWNER_APPROVED_FAILURE_TEST'){ throw 'FAILURE_TEST_TOKEN_REQUIRED' }
  if(-not $env:EF_SCHOOL_FORCE_FAIL_CHUNK_INDEX){ throw 'FAILURE_TEST_CHUNK_REQUIRED' }
  if(-not $env:EF_SCHOOL_FORCE_FAIL_STAGE){ throw 'FAILURE_TEST_STAGE_REQUIRED' }
  $failureTestChunk=[int]$env:EF_SCHOOL_FORCE_FAIL_CHUNK_INDEX
  $failureTestStage=[string]$env:EF_SCHOOL_FORCE_FAIL_STAGE
  if($failureTestChunk -lt 1){ throw 'FAILURE_TEST_CHUNK_BAD' }
  if($failureTestStage -notin @('before_factory','after_streaming_before_digest','after_digest_before_recall_use')){ throw 'FAILURE_TEST_STAGE_BAD' }
  if($failureTestStage -eq 'after_digest_before_recall_use' -and $RunKind -ne 'Real'){ throw 'FAILURE_TEST_DIGEST_STAGE_REQUIRES_REAL' }
  $failureTestEnabled=$true
}
$cleanupRemoved=@(); $chunks=@(); $totalFactoryCandidates=0; $totalReadyAtoms=0; $totalStreamQuarantined=0; $lastProof=$null; $lastUseProof=$null; $lastSourceRouterReport=$null; $activeMemoryRoot='.runtime/active_compact_semantic_memory_v1'; $lastChunkMemoryCheckpoint=$null; $memoryRollbackEvents=@(); $chunkTimingRows=@()
$chunkIndex=$ResumeCompletedChunks; $remaining=$TargetAccepted; $processedInThisRun=0; $ordinalOffset=$ResumeOrdinalOffset; $totalChunks=$ResumeCompletedChunks + [int][Math]::Ceiling($TargetAccepted / $outerChunkSize)
try {
  while($remaining -gt 0){
    $chunkIndex++
    $ordinalOffset=$ResumeOrdinalOffset + $processedInThisRun
    $chunkTarget=[Math]::Min($outerChunkSize,$remaining)
    $batchSize=[Math]::Min($innerBatchSizeMax,[Math]::Max(1,$chunkTarget))
    $chunkStart=Get-Date
    if(TestSchoolStopRequested $runId $chunkIndex $ordinalOffset $processedInThisRun $TargetAccepted 'before_chunk_start'){ return }
    if($failureTestEnabled -and $chunkIndex -eq $failureTestChunk -and $failureTestStage -eq 'before_factory'){ throw ("FORCED_SCHOOL_CHUNK_FAILURE:chunk={0}:stage=before_factory" -f $chunkIndex) }
    $chunkRunId="${runId}_chunk_${chunkIndex}_of_$totalChunks"
    $factoryOut=@(& powershell -NoProfile -ExecutionPolicy Bypass -File operations/school/curriculum/source_router/run_school_source_router_v1.ps1 -TargetAccepted $chunkTarget -RunKind Test -BatchSize $batchSize -RunId $chunkRunId -OrdinalOffset $ordinalOffset -TopicsPlan $TopicsPlan -SourceMode Auto *>&1 | ForEach-Object {[string]$_})
    $factoryStatus=($factoryOut|Where-Object{$_ -match '^FACTORY_STATUS='}|Select-Object -Last 1) -replace '^FACTORY_STATUS=',''
    if($factoryStatus -ne 'PASS_CODEX_CANDIDATE_FACTORY_GENERATION_V1'){ throw "FACTORY_NOT_PASS:$factoryStatus" }
    $factoryReport=Get-Content operations/reports/CODEX_CANDIDATE_FACTORY_RUN_V1.json -Raw|ConvertFrom-Json
    $sourceRouterReport=$null
    if(Test-Path 'operations/reports/SCHOOL_SOURCE_ROUTER_SELECTION_V1.json'){ $sourceRouterReport=Get-Content 'operations/reports/SCHOOL_SOURCE_ROUTER_SELECTION_V1.json' -Raw|ConvertFrom-Json; $lastSourceRouterReport=$sourceRouterReport }
    & operations/school/curriculum/codex_contract/validate_codex_curriculum_contract_consistency_v1.ps1 -RunDir $factoryReport.run_dir | Out-Host
    $consistency=Get-Content operations/reports/CODEX_CURRICULUM_CONTRACT_CONSISTENCY_V1.json -Raw|ConvertFrom-Json
    if($consistency.status -ne 'PASS_CODEX_CURRICULUM_CONTRACT_CONSISTENCY_V1'){ throw "CONTRACT_NOT_PASS:$($consistency.status)" }
    & operations/school/curriculum/streaming_absorption/validate_codex_curriculum_streaming_absorption_v1.ps1 -RunDir $factoryReport.run_dir | Out-Host
    $stream=Get-Content operations/reports/STREAMING_SCHOOL_TO_ABSORPTION_PIPELINE_V1.json -Raw|ConvertFrom-Json
    if($stream.status -ne 'PASS_STREAMING_SCHOOL_TO_ABSORPTION_PIPELINE_V1'){ throw "STREAMING_NOT_PASS:$($stream.status)" }
    if([int]$stream.ready_atoms_total -ne $chunkTarget){ throw "READY_ATOMS_COUNT_BAD:$($stream.ready_atoms_total)" }
    $totalFactoryCandidates += [int]$factoryReport.candidates_created
    $totalReadyAtoms += [int]$stream.ready_atoms_total
    $totalStreamQuarantined += [int]$stream.stream_quarantined_total
    if($failureTestEnabled -and $chunkIndex -eq $failureTestChunk -and $failureTestStage -eq 'after_streaming_before_digest'){ throw ("FORCED_SCHOOL_CHUNK_FAILURE:chunk={0}:stage=after_streaming_before_digest" -f $chunkIndex) }
    if($RunKind -eq 'Test'){
      $cleanupRemoved += RemoveTrash @($factoryReport.run_dir,'operations/reports')
      $chunks += [ordered]@{chunk_index=$chunkIndex; chunk_target=$chunkTarget; ordinal_offset=$ordinalOffset; inner_batch_size=$batchSize; factory_candidates=[int]$factoryReport.candidates_created; ready_atoms=[int]$stream.ready_atoms_total; source_router_selected=if($sourceRouterReport){$sourceRouterReport.selected_source}else{'UNKNOWN'}; record_status='PASS'; digested=$false; recall_use=$false; cleanup_after_chunk=$true}
      $partial=[ordered]@{schema='agent_school_canonical_run_v7_chunked_cumulative_recovery_wired'; status='RUNNING_CHUNKED_SCHOOL_PARTIAL_PROOF_V1'; run_id=$runId; run_kind=$RunKind; public_mode=$Mode; target_accepted=$TargetAccepted; requested_topics=$RequestedTopics; patch_size=$PatchSize; topic_patch_plan_path=$TopicPatchPlanPath; topic_patch_ledger_path=$TopicPatchLedgerPath; topics_plan=$TopicsPlan; resume_execution=[ordered]@{mode=[bool]$resumeMode; resume_ordinal_offset=[int]$ResumeOrdinalOffset; resume_completed_chunks=[int]$ResumeCompletedChunks; resume_remaining_target=[int]$TargetAccepted; planned_total_accepted=[int]$plannedTotalAccepted}; outer_chunk_size=$outerChunkSize; inner_batch_size_max=$innerBatchSizeMax; chunk_count=@($chunks).Count; chunks=@($chunks); ready_atoms=$totalReadyAtoms; recovery_contracts=$recoveryContracts; resume_state=(BuildResumeState 'RUNNING' 'NONE' @($chunks).Count ($chunkIndex+1) ($ordinalOffset+$chunkTarget) ($chunkIndex+1) ($ordinalOffset+$chunkTarget) $null); aggregation_summary=(BuildAggregationSummary 'RUNNING' $chunks 0 0 0 0); cleanup_after_each_chunk=$true; cleanup_removed=@($cleanupRemoved|Select-Object -Unique); runtime_ready=$false}
      $partial.aggregation_summary.planned_chunk_count=$totalChunks
      WriteJson $proofPath $partial 100
      $remaining -= $chunkTarget
      $processedInThisRun += $chunkTarget
      continue
    }
    $lastChunkMemoryCheckpoint=NewMemoryCheckpoint $activeMemoryRoot $runId $chunkIndex $ordinalOffset
    $checkpointPruneRemoved=PruneMemoryCheckpoints $runId 3
    if($checkpointPruneRemoved){ $cleanupRemoved += $checkpointPruneRemoved }
    $activeMemoryBytes=0
    if(Test-Path $activeMemoryRoot){ $activeMemoryBytes=[int64]((Get-ChildItem $activeMemoryRoot -Recurse -File -ErrorAction SilentlyContinue | Measure-Object Length -Sum).Sum) }
    $budget=[int64][Math]::Max([double]1600000,[Math]::Max(([double]([Math]::Max($plannedTotalAccepted,1000) * 1600)),([double]($activeMemoryBytes + ($chunkTarget * 2000) + 2000000))))
    $digestOrdinalForPolicy=[int]($ResumeCompletedChunks + $processedInThisRun / [Math]::Max(1,$outerChunkSize) + 1)
    $digestsSinceStable=if(($digestOrdinalForPolicy % 10) -eq 0){10}else{[int]($digestOrdinalForPolicy % 10)}
    $digestsSinceFull=if(($digestOrdinalForPolicy % 50) -eq 0){50}else{[int]($digestOrdinalForPolicy % 50)}
    $pipeOut=@(& powershell -NoProfile -ExecutionPolicy Bypass -File operations/school/digestion/absorb_atom_file_via_digest_pipeline_v1.ps1 -InputPath $stream.ready_lane_path -MemoryRoot $activeMemoryRoot -ValidationTier Auto -SizeBudgetBytes $budget -DigestsSinceStable $digestsSinceStable -DigestsSinceFull $digestsSinceFull *>&1 | ForEach-Object {[string]$_})
    $pipeStatus=($pipeOut|Where-Object{$_ -match '^FILE_ATOM_ABSORPTION_STATUS='}|Select-Object -Last 1) -replace '^FILE_ATOM_ABSORPTION_STATUS=',''
    $pipeProofPath=($pipeOut|Where-Object{$_ -match '^PROOF_PATH='}|Select-Object -Last 1) -replace '^PROOF_PATH=',''
    if($pipeStatus -ne 'PASS_FILE_ATOM_ABSORPTION_PIPELINE_V1'){ throw "PIPELINE_NOT_PASS:$pipeStatus" }
    $pipeProof=Get-Content $pipeProofPath -Raw|ConvertFrom-Json
    if($pipeProof.cumulative_memory_merge -ne $true){ throw 'PIPELINE_CUMULATIVE_MEMORY_MERGE_NOT_PROVEN' }
    if($failureTestEnabled -and $chunkIndex -eq $failureTestChunk -and $failureTestStage -eq 'after_digest_before_recall_use'){ throw ("FORCED_SCHOOL_CHUNK_FAILURE:chunk={0}:stage=after_digest_before_recall_use" -f $chunkIndex) }
    $routeMid=Get-Content $routePath -Raw|ConvertFrom-Json
    $ledgerMid=Get-Content $ledgerPath -Raw|ConvertFrom-Json
    if([int]$routeMid.routed_active_count -ne [int]$routeBefore.routed_active_count){ throw 'ROUTE_MUTATED_BY_REAL_FACTORY_DIGEST' }
    if([int]$ledgerMid.replayed_active_count -ne [int]$ledgerBefore.replayed_active_count){ throw 'LEDGER_MUTATED_BY_REAL_FACTORY_DIGEST' }
    $useTask="Chunk $chunkIndex of cumulative night school must prove compact memory is recalled and used before continuing."
    $useOut=@(& powershell -NoProfile -ExecutionPolicy Bypass -File operations/school/memory/validate_compact_memory_recall_use_probe_v1.ps1 -MemoryRoot $pipeProof.memory_root -Task $useTask *>&1 | ForEach-Object {[string]$_})
    $useStatus=($useOut|Where-Object{$_ -match '^VALIDATION_PASS=COMPACT_MEMORY_RECALL_USE_PROBE_V1_VALID$'}|Select-Object -Last 1)
    $useProofPath=($useOut|Where-Object{$_ -match '^PROOF_PATH='}|Select-Object -Last 1) -replace '^PROOF_PATH=',''
    if($useStatus -ne 'VALIDATION_PASS=COMPACT_MEMORY_RECALL_USE_PROBE_V1_VALID'){ throw 'RECALL_USE_GATE_NOT_PASS' }
    if([string]::IsNullOrWhiteSpace($useProofPath) -or -not (Test-Path $useProofPath)){ throw 'RECALL_USE_PROOF_MISSING' }
    $useProof=Get-Content $useProofPath -Raw|ConvertFrom-Json
    if($useProof.behavior_delta -ne $true){ throw 'BEHAVIOR_DELTA_NOT_PROVEN' }
    $chunkElapsedMs=[int][Math]::Round(((Get-Date)-$chunkStart).TotalMilliseconds)
    $chunkTimingRows += [ordered]@{chunk_index=[int]$chunkIndex; elapsed_ms=$chunkElapsedMs; validation_tier=$pipeProof.selected_validation_tier; absorption_total_elapsed_ms=$pipeProof.total_elapsed_ms; absorption_stage_timings=$pipeProof.stage_timings}
    $chunks += [ordered]@{chunk_index=$chunkIndex; chunk_target=$chunkTarget; ordinal_offset=$ordinalOffset; inner_batch_size=$batchSize; factory_candidates=[int]$factoryReport.candidates_created; ready_atoms=[int]$stream.ready_atoms_total; source_router_selected=if($sourceRouterReport){$sourceRouterReport.selected_source}else{'UNKNOWN'}; record_status='PASS'; digested=$true; validation_tier=$pipeProof.selected_validation_tier; absorption_total_elapsed_ms=$pipeProof.total_elapsed_ms; digested_cells=[int]$pipeProof.digested_cells; merged_count=[int]$pipeProof.merged_count; cumulative_memory_merge=$pipeProof.cumulative_memory_merge; existing_memory_seeded=$pipeProof.existing_memory_seeded; existing_memory_cells_before=[int]$pipeProof.existing_memory_cells_before; total_memory_bytes=[int]$pipeProof.total_memory_bytes; recall_use_status=$useProof.status; behavior_delta=$useProof.behavior_delta; used_memory_cells_count=@($useProof.used_labels).Count; cleanup_after_chunk=$true}
    if(TestSchoolStopRequested $runId ($chunkIndex+1) ($ordinalOffset+$chunkTarget) $processedInThisRun $TargetAccepted 'after_chunk_complete'){ return }
    $lastProof=$pipeProof; $lastUseProof=$useProof
    $cleanupRemoved += RemoveTrash @($factoryReport.run_dir,$pipeProofPath,$pipeProof.candidate_memory_root,$useProofPath,'operations/reports')
    $partial=[ordered]@{schema='agent_school_canonical_run_v7_chunked_cumulative_recovery_wired'; status='RUNNING_CHUNKED_SCHOOL_PARTIAL_PROOF_V1'; run_id=$runId; run_kind=$RunKind; public_mode=$Mode; target_accepted=$TargetAccepted; requested_topics=$RequestedTopics; patch_size=$PatchSize; topic_patch_plan_path=$TopicPatchPlanPath; topic_patch_ledger_path=$TopicPatchLedgerPath; topics_plan=$TopicsPlan; resume_execution=[ordered]@{mode=[bool]$resumeMode; resume_ordinal_offset=[int]$ResumeOrdinalOffset; resume_completed_chunks=[int]$ResumeCompletedChunks; resume_remaining_target=[int]$TargetAccepted; planned_total_accepted=[int]$plannedTotalAccepted}; outer_chunk_size=$outerChunkSize; inner_batch_size_max=$innerBatchSizeMax; chunk_count=@($chunks).Count; chunks=@($chunks); ready_atoms=$totalReadyAtoms; recovery_contracts=$recoveryContracts; resume_state=(BuildResumeState 'RUNNING' 'NONE' @($chunks).Count ($chunkIndex+1) ($ordinalOffset+$chunkTarget) ($chunkIndex+1) ($ordinalOffset+$chunkTarget) $null); aggregation_summary=(BuildAggregationSummary 'RUNNING' $chunks 0 0 0 0); cleanup_after_each_chunk=$true; cleanup_removed=@($cleanupRemoved|Select-Object -Unique); runtime_ready=$false}
    $partial.aggregation_summary.planned_chunk_count=$totalChunks
    WriteJson $proofPath $partial 100
    $remaining -= $chunkTarget
    $processedInThisRun += $chunkTarget
  }
} catch {
  $memoryRollbackResult=RestoreMemoryCheckpoint $lastChunkMemoryCheckpoint $activeMemoryRoot
  $memoryRollbackEvents += $memoryRollbackResult
  $cleanupRemoved += RemoveTrash @('.runtime/codex_curriculum_candidate_factory_runs','.runtime/file_atom_absorption','.runtime/memory_use_probes','.runtime/digestion_policy','.runtime/digestion_reports')
  $routeFailure=Get-Content $routePath -Raw|ConvertFrom-Json
  $ledgerFailure=Get-Content $ledgerPath -Raw|ConvertFrom-Json
  $failedChunkIndex=[Math]::Max(1,$chunkIndex)
  $resumeOffset=[Math]::Max(0,$ordinalOffset)
  $failureRecord=[ordered]@{record_type='FAILED'; status='FAILED_REQUIRES_OWNER_OR_REPAIR_DECISION'; failed_chunk_index=$failedChunkIndex; resume_ordinal_offset=$resumeOffset; reason=$_.Exception.Message; source_contract=$quarantineContractPath; no_blind_retry=$true}
  $failAgg=BuildAggregationSummary 'FAILURE_AGGREGATED' $chunks 1 0 0 1
  $failAgg.planned_chunk_count=$totalChunks
  $fail=[ordered]@{schema='agent_school_canonical_run_v7_chunked_cumulative_recovery_wired'; status='FAIL_CHUNKED_SCHOOL_CLEANED_TRANSIENTS_V1'; run_id=$runId; run_kind=$RunKind; public_mode=$Mode; target_accepted=$TargetAccepted; requested_topics=$RequestedTopics; patch_size=$PatchSize; topic_patch_plan_path=$TopicPatchPlanPath; topic_patch_ledger_path=$TopicPatchLedgerPath; topics_plan=$TopicsPlan; resume_execution=[ordered]@{mode=[bool]$resumeMode; resume_ordinal_offset=[int]$ResumeOrdinalOffset; resume_completed_chunks=[int]$ResumeCompletedChunks; resume_remaining_target=[int]$TargetAccepted; planned_total_accepted=[int]$plannedTotalAccepted}; outer_chunk_size=$outerChunkSize; inner_batch_size_max=$innerBatchSizeMax; chunk_count=@($chunks).Count; chunks=@($chunks); recovery_contracts=$recoveryContracts; resume_state=(BuildResumeState 'FAILURE_RECORDED' 'FAILED_CHUNK_REQUIRES_DECISION' @($chunks).Count $failedChunkIndex $resumeOffset $failedChunkIndex $resumeOffset $_.Exception.Message); quarantine_record=$failureRecord; aggregation_summary=$failAgg; memory_checkpoint=$lastChunkMemoryCheckpoint; memory_rollback=$memoryRollbackResult; memory_rollback_events=@($memoryRollbackEvents); memory_rollback_capability='SCHOOL_REAL_CHUNK_MEMORY_CHECKPOINT_ROLLBACK_V1'; failure_test_enabled=$failureTestEnabled; forced_failure_chunk=$failureTestChunk; forced_failure_stage=$failureTestStage; route_before=[int]$routeBefore.routed_active_count; ledger_before=[int]$ledgerBefore.replayed_active_count; route_after=[int]$routeFailure.routed_active_count; ledger_after=[int]$ledgerFailure.replayed_active_count; route_unchanged=([int]$routeBefore.routed_active_count -eq [int]$routeFailure.routed_active_count); ledger_unchanged=([int]$ledgerBefore.replayed_active_count -eq [int]$ledgerFailure.replayed_active_count); error=$_.Exception.Message; cleanup_removed=@($cleanupRemoved|Select-Object -Unique); runtime_ready=$false; no_fake_pass=$true; no_hidden_failures=$true}
  WriteJson $proofPath $fail 100
  throw
}
$routeAfter=Get-Content $routePath -Raw|ConvertFrom-Json
$ledgerAfter=Get-Content $ledgerPath -Raw|ConvertFrom-Json
if([int]$routeAfter.routed_active_count -ne [int]$routeBefore.routed_active_count){ throw 'ROUTE_MUTATED_BY_RUN' }
if([int]$ledgerAfter.replayed_active_count -ne [int]$ledgerBefore.replayed_active_count){ throw 'LEDGER_MUTATED_BY_RUN' }
$base=[ordered]@{schema='agent_school_canonical_run_v7_chunked_cumulative_recovery_wired'; run_id=$runId; run_kind=$RunKind; public_mode=$Mode; target_accepted=$TargetAccepted; requested_topics=$RequestedTopics; patch_size=$PatchSize; topic_patch_plan_path=$TopicPatchPlanPath; topic_patch_ledger_path=$TopicPatchLedgerPath; topics_plan=$TopicsPlan; resume_execution=[ordered]@{mode=[bool]$resumeMode; resume_ordinal_offset=[int]$ResumeOrdinalOffset; resume_completed_chunks=[int]$ResumeCompletedChunks; resume_remaining_target=[int]$TargetAccepted; planned_total_accepted=[int]$plannedTotalAccepted}; outer_chunk_size=$outerChunkSize; inner_batch_size_max=$innerBatchSizeMax; chunk_count=@($chunks).Count; chunks=@($chunks); recovery_contracts=$recoveryContracts; school_recovery_wiring_status='PASS_SCHOOL_CHUNK_RECOVERY_CONTRACTS_WIRED_V1'; resume_state=(BuildResumeState 'COMPLETE' 'NONE' (@($chunks).Count + $ResumeCompletedChunks) ($chunkIndex+1) ($ResumeOrdinalOffset + $TargetAccepted) ($chunkIndex+1) ($ResumeOrdinalOffset + $TargetAccepted) $null); aggregation_summary=(BuildAggregationSummary 'PASS_AGGREGATED' $chunks 0 0 0 0); memory_rollback_capability='SCHOOL_REAL_CHUNK_MEMORY_CHECKPOINT_ROLLBACK_V1'; memory_rollback_events=@($memoryRollbackEvents); runtime_ready=$false; raw_route_absorption_allowed=$false; factory_candidates_created=$totalFactoryCandidates; ready_atoms=$totalReadyAtoms; stream_quarantined=$totalStreamQuarantined; codex_cli_invoked=$false; api_invoked=$false; school_source_router_status=if($lastSourceRouterReport){$lastSourceRouterReport.status}else{'UNKNOWN'}; school_source_selected=if($lastSourceRouterReport){$lastSourceRouterReport.selected_source}else{'UNKNOWN'}; dynamic_theme_selection_status=$DynamicThemeSelectionStatus; dynamic_theme_selection_path=$DynamicThemeSelectionPath; route_before=[int]$routeBefore.routed_active_count; ledger_before=[int]$ledgerBefore.replayed_active_count; route_after=[int]$routeAfter.routed_active_count; ledger_after=[int]$ledgerAfter.replayed_active_count; retention_policy='KEEP_ACTIVE_COMPACT_MEMORY_AND_LATEST_3_MEMORY_CHECKPOINTS_V2'; cleanup_removed=@($cleanupRemoved|Select-Object -Unique); cleanup_after_each_chunk=$true; no_fake_pass=$true; no_hidden_failures=$true; failure_resume_boundary='Recovery contracts are wired into canonical proof. Controlled chunk failure/resume remains NOT_PROVEN until negative test.'; law='Owner launch uses Count + Mode + Topics. PatchSize is internally fixed at 1000. Topics are not equal-budgeted; school assigns budget patch-by-patch and only ABSORBED patches count after restart. Internal topics plan and dynamic theme-cell selection guide material direction. Real uses cumulative compact semantic memory and cannot continue past a chunk without recall/use behavior_delta proof; failure records must expose resume_state and quarantine_record before any continuation.'}
$base.aggregation_summary.planned_chunk_count=$totalChunks
$base.resume_execution.processed_in_this_run=[int]$processedInThisRun
$base.chunk_timing_rows=@($chunkTimingRows)
if($RunKind -eq 'Test'){
  $base.status='PASS_TEST_FACTORY_STREAMING_READY_V1'; $base.digested_knowledge_mutated=$false; $base.recall_use_required=$false; $base.behavior_delta=$false; $base.boundary='Test validates existing factory and streaming ready lane only. It does not digest or mutate compact memory.'
} else {
  if($null -eq $lastProof -or $null -eq $lastUseProof){ throw 'REAL_FINAL_PROOF_MISSING' }
  $base.status='PASS_REAL_FACTORY_DIGEST_RECALL_USE_V1'; $base.digested_knowledge_mutated=$true; $base.pipeline_status=$lastProof.status; $base.validation_tier=$lastProof.selected_validation_tier; $base.digested_cells=[int]$lastProof.digested_cells; $base.merged_count=[int]$lastProof.merged_count; $base.raw_source_dependency_removed=$lastProof.raw_source_dependency_removed; $base.total_memory_bytes=[int]$lastProof.total_memory_bytes; $base.memory_root=$lastProof.memory_root; $base.cumulative_memory_merge=$lastProof.cumulative_memory_merge; $base.existing_memory_seeded=$lastProof.existing_memory_seeded; $base.existing_memory_cells_before=[int]$lastProof.existing_memory_cells_before; $base.recall_use_status=$lastUseProof.status; $base.used_memory_cells=@($lastUseProof.used_labels); $base.baseline_decision=$lastUseProof.baseline_decision; $base.active_decision=$lastUseProof.active_decision; $base.behavior_delta=$lastUseProof.behavior_delta; $base.boundary='Real uses chunked factory output, streaming ready_atoms, cumulative compact semantic memory, recall/use proof after every chunk, in-run transient cleanup, and recovery contract wiring.'
}
WriteJson $proofPath $base 100
$schoolFinalizerPath = 'operations/school/finalize_agent_school_run_v1.ps1'
if (Test-Path $schoolFinalizerPath) {
  try {
    & powershell -NoProfile -ExecutionPolicy Bypass -File $schoolFinalizerPath -ProofPath $proofPath | Out-Host
  } catch {
    Write-Host ("FINALIZER_STATUS=FAILED:{0}" -f $_.Exception.Message)
  }
} else {
  Write-Host 'FINALIZER_STATUS=SKIPPED_FINALIZER_MISSING'
}
Write-Host "SCHOOL_RUN_STATUS=$($base.status)"
Write-Host "PROOF_PATH=$proofPath"
Write-Host "SCHOOL_RUN_REPORT=$proofPath"
Write-Host "TARGET_ACCEPTED=$TargetAccepted"
Write-Host "RUN_KIND=$RunKind"
Write-Host "REQUESTED_TOPICS=$RequestedTopics"
Write-Host "PATCH_SIZE=$PatchSize"
Write-Host "TOPIC_PATCH_PLAN=$TopicPatchPlanPath"
Write-Host "OUTER_CHUNK_SIZE=$outerChunkSize"
Write-Host "INNER_BATCH_SIZE_MAX=$innerBatchSizeMax"
Write-Host "CHUNK_COUNT=$($base.chunk_count)"
Write-Host "RECOVERY_WIRING_STATUS=$($base.school_recovery_wiring_status)"
Write-Host "FACTORY_CANDIDATES=$totalFactoryCandidates"
Write-Host "READY_ATOMS=$totalReadyAtoms"
Write-Host "CUMULATIVE_MEMORY_MERGE=$($base.cumulative_memory_merge)"
Write-Host "DIGESTED_CELLS=$($base.digested_cells)"
Write-Host "MERGED_COUNT=$($base.merged_count)"
Write-Host "TOTAL_MEMORY_BYTES=$($base.total_memory_bytes)"
Write-Host "RECALL_USE_STATUS=$($base.recall_use_status)"
Write-Host "BEHAVIOR_DELTA=$($base.behavior_delta)"
Write-Host "ROUTE_AFTER=$($base.route_after)"
Write-Host "LEDGER_AFTER=$($base.ledger_after)"
Write-Host 'RUNTIME_READY=false'
