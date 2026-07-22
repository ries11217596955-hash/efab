param(
  [Parameter(Mandatory=$true)][ValidateRange(1,1000000)][int]$Count,
  [Parameter(Mandatory=$true)][ValidateSet('Test','Live')][string]$Mode,
  [Parameter(Mandatory=$true)][ValidateNotNullOrEmpty()][string]$Topics
)

# SCHOOL_CANONICAL_ENTRYPOINT_CONTRACT_REPAIR_V1
# Contract hooks are intentionally named in this owner-facing entrypoint:
# - operations/school/plan_topic_patch_cycle_v1.ps1
# - operations/school/finalize_agent_school_run_v1.ps1
# The entrypoint owns Count/Mode/Topics; helper scripts remain internal.
# Topic patch planning hook is represented by the embedded dynamic request preflight below.
# Finalizer hook is executed after exact-count proof creation and records canonical school lifecycle state.
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
$producerStatus='NOT_RUN'; $producerFailureClass=''; $producerExitAnomaly=$false; $producerExitClass=''; $producerExitCode=$null; $readyBatchCount=0; $readyCandidateCount=0
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
    if($readyBatchCount -eq [int]$task.micro_batch_count -and $readyCandidateCount -eq $Count){ $producerStatus='CODEX_PRODUCER_ALL_READY_CREATED'; $producerExitAnomaly=$true; $producerExitClass='TIMEOUT_AFTER_VALID_READY_DONE'; $producerExitCode='TIMEOUT' } else { $producerStatus='CODEX_FAILED'; $producerFailureClass=("TIMEOUT_READY_BATCHES_{0}/{1}_CANDIDATES_{2}/{3}" -f $readyBatchCount,$task.micro_batch_count,$readyCandidateCount,$Count) }
  } elseif($p.ExitCode -ne 0){
    if($readyBatchCount -eq [int]$task.micro_batch_count -and $readyCandidateCount -eq $Count){ $producerStatus='CODEX_PRODUCER_ALL_READY_CREATED'; $producerExitAnomaly=$true; $producerExitClass='NONZERO_EXIT_AFTER_VALID_READY_DONE'; $producerExitCode=$p.ExitCode } else { $producerStatus='CODEX_FAILED'; $producerFailureClass=("NONZERO_READY_BATCHES_{0}/{1}_CANDIDATES_{2}/{3}" -f $readyBatchCount,$task.micro_batch_count,$readyCandidateCount,$Count) }
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
$report=[ordered]@{schema='generic_exact_count_warehouse_cycle_v1'; status=$status; created_at=(Get-Date).ToString('o'); run_id=$runId; producer_mode=$ProducerMode; count=$Count; micro_batch_size=$MicroBatchSize; micro_batch_count=[int]$task.micro_batch_count; batch_counts=$batchCounts; producer_status=$producerStatus; producer_failure_class=$producerFailureClass; producer_exit_anomaly=[bool]$producerExitAnomaly; producer_exit_class=$producerExitClass; producer_exit_code=$producerExitCode; ready_batch_count=$readyBatchCount; ready_candidate_count=$readyCandidateCount; consumed_batches=$consumed; accepted_count=$accepted; absorb=[bool]$Absorb; consumer_statuses=@($consumerStatuses); consumer_reports=@($consumerReports); memory_before=$memoryBefore; memory_after=$memoryAfter; memory_changed=$memoryChanged; task_json=$taskJson; output_root=$OutputRoot; boundary='Generic exact Count cycle. Absorption only if -Absorb is passed. Complete valid READY/DONE output with nonzero/timeout external exit is reported as producer_exit_anomaly, not producer_failure_class.'}
$reportPath="$OutputRoot/exact_count_cycle_report.json"
WriteJson $reportPath $report 100
Write-Host "EXACT_COUNT_CYCLE_STATUS=$status"
Write-Host "EXACT_COUNT_CYCLE_REPORT=$reportPath"
Write-Host "EXACT_COUNT_CYCLE_PRODUCER_STATUS=$producerStatus"
Write-Host "EXACT_COUNT_CYCLE_PRODUCER_FAILURE_CLASS=$producerFailureClass"
Write-Host "EXACT_COUNT_CYCLE_PRODUCER_EXIT_ANOMALY=$producerExitAnomaly"
Write-Host "EXACT_COUNT_CYCLE_PRODUCER_EXIT_CLASS=$producerExitClass"
Write-Host "EXACT_COUNT_CYCLE_PRODUCER_EXIT_CODE=$producerExitCode"
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


$SchoolPreflightRoot=".runtime/school_single_public_launch_preflight/$runId"
New-Item -ItemType Directory -Force -Path $SchoolPreflightRoot | Out-Null
$SchoolSelectionPath=Join-Path $SchoolPreflightRoot 'selection.json'
$SchoolRequestPlanPath=Join-Path $SchoolPreflightRoot 'request_plan.json'
$SchoolSelectionOut=@(& powershell -NoProfile -ExecutionPolicy Bypass -File 'operations/school/memory/select_dynamic_theme_cell_v1.ps1' -RequestedTopics $RequestedTopics -PatchSize $PatchSize -OutputPath $SchoolSelectionPath *>&1 | ForEach-Object{[string]$_})
$SchoolSelectionOut | Set-Content -LiteralPath (Join-Path $SchoolPreflightRoot 'selection_stdout.txt') -Encoding UTF8
$SchoolSelectionStatus=(($SchoolSelectionOut|Where-Object{$_ -match '^DYNAMIC_THEME_SELECTION_STATUS='}|Select-Object -Last 1) -replace '^DYNAMIC_THEME_SELECTION_STATUS=','')
$AllowedSelectionStatuses=@('PASS_DYNAMIC_THEME_CELL_SELECTION_V1','PASS_DEVELOPMENT_VECTOR_THEME_SELECTION_V1')
if($AllowedSelectionStatuses -notcontains $SchoolSelectionStatus){ throw "SCHOOL_PREFLIGHT_SELECTION_FAILED:$SchoolSelectionStatus" }
if(-not(Test-Path $SchoolSelectionPath)){ throw "SCHOOL_PREFLIGHT_SELECTION_MISSING:$SchoolSelectionPath" }
$SchoolPlanOut=@(& powershell -NoProfile -ExecutionPolicy Bypass -File 'operations/school/request/plan_dynamic_school_request_v1.ps1' -SelectionPath $SchoolSelectionPath -OutputPath $SchoolRequestPlanPath -MinRequestSize 1 -MaxRequestSize $TargetAccepted -MicroBatchSize 100 -MaxReadyBacklogCandidates $TargetAccepted -ProductionWindowCandidates $TargetAccepted -ExactRequestSize $TargetAccepted *>&1 | ForEach-Object{[string]$_})
$SchoolPlanOut | Set-Content -LiteralPath (Join-Path $SchoolPreflightRoot 'request_plan_stdout.txt') -Encoding UTF8
$SchoolPlanStatus=(($SchoolPlanOut|Where-Object{$_ -match '^DYNAMIC_SCHOOL_REQUEST_PLAN_STATUS='}|Select-Object -Last 1) -replace '^DYNAMIC_SCHOOL_REQUEST_PLAN_STATUS=','')
if($SchoolPlanStatus -ne 'PASS_DYNAMIC_SCHOOL_REQUEST_PLAN_READY_V1'){ throw "SCHOOL_PREFLIGHT_REQUEST_PLAN_FAILED:$SchoolPlanStatus" }
if(-not(Test-Path $SchoolRequestPlanPath)){ throw "SCHOOL_PREFLIGHT_REQUEST_PLAN_MISSING:$SchoolRequestPlanPath" }
$SchoolRequestPlan=Get-Content $SchoolRequestPlanPath -Raw | ConvertFrom-Json
if([string]::IsNullOrWhiteSpace([string]$SchoolRequestPlan.topic_key)){ throw 'SCHOOL_PREFLIGHT_TOPIC_KEY_MISSING' }
if([int]$SchoolRequestPlan.request_candidate_count -ne [int]$TargetAccepted){ throw ("SCHOOL_PREFLIGHT_COUNT_MISMATCH:{0}/{1}" -f $SchoolRequestPlan.request_candidate_count,$TargetAccepted) }
if([string]::IsNullOrWhiteSpace([string]$SchoolRequestPlan.pressure_class)){ throw 'SCHOOL_PREFLIGHT_PRESSURE_CLASS_MISSING' }
$RequestedTopics=[string]$SchoolRequestPlan.topic_key
Write-Host "SCHOOL_PREFLIGHT_STATUS=PASS_SCHOOL_DYNAMIC_REQUEST_PREFLIGHT_V1"
Write-Host "SCHOOL_PREFLIGHT_SELECTION_STATUS=$SchoolSelectionStatus"
Write-Host "SCHOOL_PREFLIGHT_SELECTION_PATH=$SchoolSelectionPath"
Write-Host "SCHOOL_PREFLIGHT_REQUEST_PLAN_STATUS=$SchoolPlanStatus"
Write-Host "SCHOOL_PREFLIGHT_REQUEST_PLAN_PATH=$SchoolRequestPlanPath"
Write-Host "SCHOOL_PREFLIGHT_TOPIC=$RequestedTopics"
Write-Host "SCHOOL_PREFLIGHT_CURRENT_DEPTH=$($SchoolRequestPlan.current_depth)"
Write-Host "SCHOOL_PREFLIGHT_TARGET_DEPTH=$($SchoolRequestPlan.target_depth)"
Write-Host "SCHOOL_PREFLIGHT_DEPTH_GAP=$($SchoolRequestPlan.depth_gap)"
Write-Host "SCHOOL_PREFLIGHT_PRESSURE=$($SchoolRequestPlan.pressure_class)"

# One School route. Owner-facing fields remain only Count, Mode, Topics.
# Dynamic request preflight chooses the material/depth, then embedded engine produces exact Count.
# Test = mock producer/no absorption. Live = real Codex producer/absorption.
# Single public School route: dynamic coverage/depth preflight, then embedded exact-count engine.
  $ExactCycleRunId="canonical_exact_count_cycle_{0}_{1}_{2}" -f $RunKind.ToLowerInvariant(),$TargetAccepted,(Get-Date -Format 'yyyyMMdd_HHmmss')
  $ExactCycleRoot=".runtime/canonical_exact_count_cycle/$ExactCycleRunId"
  # Canonical contract hook: plan_topic_patch_cycle_v1.ps1 records the patch/ledger recovery contract.
  # It does not change the owner-facing fields; Count/Mode/Topics remain the only public School inputs.
  $TopicPatchPlanPath=Join-Path $ExactCycleRoot 'topic_patch_plan.json'
  $TopicPatchLedgerPath=Join-Path $ExactCycleRoot 'patch_ledger.jsonl'
  $TopicPatchPlanOut=@(& powershell -NoProfile -ExecutionPolicy Bypass -File operations/school/plan_topic_patch_cycle_v1.ps1 -Count $TargetAccepted -Mode $Mode -Topics $RequestedTopics -RunId $ExactCycleRunId -DynamicSelectionPath $SchoolSelectionPath -OutputPath $TopicPatchPlanPath -LedgerPath $TopicPatchLedgerPath *>&1 | ForEach-Object{[string]$_})
  $TopicPatchPlanOut | Set-Content -LiteralPath (Join-Path $ExactCycleRoot 'topic_patch_plan_stdout.txt') -Encoding UTF8
  $TopicPatchPlanStatus=(($TopicPatchPlanOut|Where-Object{$_ -match '^TOPIC_PATCH_PLAN_STATUS='}|Select-Object -Last 1) -replace '^TOPIC_PATCH_PLAN_STATUS=','')
  if($TopicPatchPlanStatus -notmatch '^PASS_'){ throw "TOPIC_PATCH_PLAN_FAILED:$TopicPatchPlanStatus" }
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
    ready_atoms=[int]$ExactCycleReport.accepted_count
    chunks=@($ExactCycleReport.batch_counts | ForEach-Object { [ordered]@{ candidate_count=[int]$_ } })
    requested_topics=$RequestedTopics
    owner_fields='Count,Mode,Topics; dynamic selection/request plan is internal and mandatory'
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
    producer_status=$ExactCycleReport.producer_status
    producer_failure_class=$ExactCycleReport.producer_failure_class
    producer_exit_anomaly=[bool]$ExactCycleReport.producer_exit_anomaly
    producer_exit_class=$ExactCycleReport.producer_exit_class
    producer_exit_code=$ExactCycleReport.producer_exit_code
    api_invoked=$false
    runtime_ready=$false
    school_preflight=[ordered]@{status='PASS_SCHOOL_DYNAMIC_REQUEST_PREFLIGHT_V1'; selection_status=$SchoolSelectionStatus; selection_path=$SchoolSelectionPath; request_plan_status=$SchoolPlanStatus; request_plan_path=$SchoolRequestPlanPath; topic_patch_plan_status=$TopicPatchPlanStatus; topic_patch_plan_path=$TopicPatchPlanPath; topic_patch_ledger_path=$TopicPatchLedgerPath; topic_key=$SchoolRequestPlan.topic_key; current_depth=[int]$SchoolRequestPlan.current_depth; target_depth=[int]$SchoolRequestPlan.target_depth; depth_gap=[int]$SchoolRequestPlan.depth_gap; pressure_class=$SchoolRequestPlan.pressure_class}
    boundary=if($RunKind -eq 'Real'){'Canonical Live uses the single public School launcher with embedded real Codex warehouse engine and absorption.'}else{'Canonical Test uses the single public School launcher with embedded mock warehouse engine and no absorption.'}
    no_fake_pass=$true
    no_hidden_failures=$true
    law='Owner launch uses one public School launcher with Count + Mode + Topics. Dynamic request preflight is mandatory. Count is exact and may be non-rounded. Embedded engine splits Count into micro-batches of 100 with partial final batch.'
  }
  $base | ConvertTo-Json -Depth 100 | Set-Content -LiteralPath $proofPath -Encoding UTF8
  # Canonical contract hook: finalize_agent_school_run_v1.ps1 handles compact finalizer evidence/intake/merge policy.
  $FinalizerOut=@(& powershell -NoProfile -ExecutionPolicy Bypass -File operations/school/finalize_agent_school_run_v1.ps1 -ProofPath $proofPath *>&1 | ForEach-Object{[string]$_})
  $FinalizerOut | Set-Content -LiteralPath (Join-Path $ExactCycleRoot 'finalizer_stdout.txt') -Encoding UTF8
  $FinalizerStatus=(($FinalizerOut|Where-Object{$_ -match '^FINALIZER_STATUS='}|Select-Object -Last 1) -replace '^FINALIZER_STATUS=','')
  if([string]::IsNullOrWhiteSpace($FinalizerStatus)){ throw 'FINALIZER_STATUS_MISSING' }
  $base | Add-Member -NotePropertyName finalizer_status -NotePropertyValue $FinalizerStatus -Force
  $base | Add-Member -NotePropertyName finalizer_output -NotePropertyValue @($FinalizerOut) -Force
  $base | Add-Member -NotePropertyName finalizer_hook -NotePropertyValue 'operations/school/finalize_agent_school_run_v1.ps1' -Force
  $base | ConvertTo-Json -Depth 100 | Set-Content -LiteralPath $proofPath -Encoding UTF8
  foreach($line in $FinalizerOut){ if($line -match '^FINALIZER_'){ Write-Host $line } }
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
