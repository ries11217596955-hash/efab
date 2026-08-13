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
# Transport retries must not create a second public School runtime.
$SchoolSingleInstanceMutexName='Global\EFAB_SCHOOL_SINGLE_PUBLIC_LAUNCH_V1'
$script:SchoolSingleInstanceMutex=New-Object System.Threading.Mutex($false,$SchoolSingleInstanceMutexName)
$SchoolSingleInstanceAcquired=$false
try {
  $SchoolSingleInstanceAcquired=$script:SchoolSingleInstanceMutex.WaitOne(0,$false)
} catch [System.Threading.AbandonedMutexException] {
  $SchoolSingleInstanceAcquired=$true
}
if(-not $SchoolSingleInstanceAcquired){
  Write-Error 'SCHOOL_SINGLE_INSTANCE_BLOCKED_ACTIVE_RUN'
  exit 73
}
try {function Invoke-SchoolWarehouseConsumer {
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
    $selected=@($ready | Sort-Object sequence | Select-Object -First $MaxConsumeBatches)
    $prepared=New-Object System.Collections.ArrayList
    foreach($mb in $selected){
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
      [void]$prepared.Add([pscustomobject]@{mb=$mb; norm=$norm})
    }
    $absorbStatus='NOT_RUN'; $absorbProof=$null; $digestWindowAtoms=0; $digestWindowInput=$null
    if($Absorb){
      $windowLines=New-Object System.Collections.ArrayList
      foreach($item in @($prepared)){
        $digestWindowAtoms += [int]$item.norm.accepted_count
        foreach($line in Get-Content -LiteralPath ([string]$item.mb.normalized_atoms_jsonl)){ if(-not [string]::IsNullOrWhiteSpace($line)){ [void]$windowLines.Add($line) } }
      }
      if($windowLines.Count -ne $digestWindowAtoms){ throw ("DIGEST_WINDOW_LINE_COUNT_MISMATCH:{0}/{1}" -f $windowLines.Count,$digestWindowAtoms) }
      $digestWindowInput=Join-Path $warehouseRoot ("digest_window_{0}_{1:D6}.normalized_atoms.jsonl" -f (Get-Date -Format 'yyyyMMdd_HHmmssfff'),$digestWindowAtoms)
      ($windowLines -join "`n") | Set-Content -LiteralPath $digestWindowInput -Encoding UTF8
      $absorbOut=@(& powershell -NoProfile -ExecutionPolicy Bypass -File operations/school/digestion/absorb_atom_file_via_digest_pipeline_v1.ps1 -InputPath $digestWindowInput -SizeBudgetBytes 26214400 *>&1 | ForEach-Object{[string]$_})
      $absorbStatus=(($absorbOut|Where-Object{$_ -match '^FILE_ATOM_ABSORPTION_STATUS='}|Select-Object -Last 1) -replace '^FILE_ATOM_ABSORPTION_STATUS=','')
      $absorbProof=(($absorbOut|Where-Object{$_ -match '^PROOF_PATH='}|Select-Object -Last 1) -replace '^PROOF_PATH=','')
      if($absorbStatus -ne 'PASS_FILE_ATOM_ABSORPTION_PIPELINE_V1'){ throw "DIGEST_WINDOW_ABSORPTION_FAILED:$absorbStatus" }
      foreach($item in @($prepared)){
        $mb=$item.mb; $norm=$item.norm
        WriteJson ([string]$mb.absorbed_marker) ([ordered]@{status='ABSORBED'; micro_batch_id=$mb.micro_batch_id; absorbed_at=(Get-Date).ToString('o'); proof=$absorbProof; digest_window_atoms=$digestWindowAtoms; digest_window_batch_count=$prepared.Count}) 30
        AddLedger $ledgerPath ([ordered]@{ts=(Get-Date).ToString('o'); micro_batch_id=$mb.micro_batch_id; sequence=$mb.sequence; state='ABSORBED'; candidate_count=[int]$mb.candidate_count; normalization_report=[string]$mb.normalization_report; normalized_atoms_jsonl=[string]$mb.normalized_atoms_jsonl; absorption_status=$absorbStatus; absorption_proof=$absorbProof; digest_window_atoms=$digestWindowAtoms; digest_window_batch_count=$prepared.Count})
        [void]$consumed.Add([pscustomobject]@{micro_batch_id=$mb.micro_batch_id; state='ABSORBED'; candidate_count=[int]$mb.candidate_count; accepted_count=[int]$norm.accepted_count; absorption_status=$absorbStatus; digest_window_atoms=$digestWindowAtoms; digest_window_batch_count=$prepared.Count})
      }
      if(Test-Path -LiteralPath $digestWindowInput){ Remove-Item -LiteralPath $digestWindowInput -Force }
    } else {
      foreach($item in @($prepared)){
        $mb=$item.mb; $norm=$item.norm
        AddLedger $ledgerPath ([ordered]@{ts=(Get-Date).ToString('o'); micro_batch_id=$mb.micro_batch_id; sequence=$mb.sequence; state='VALIDATED_NORMALIZED'; candidate_count=[int]$mb.candidate_count; normalization_report=[string]$mb.normalization_report; normalized_atoms_jsonl=[string]$mb.normalized_atoms_jsonl; absorption_status='NOT_RUN'; absorption_proof=$null})
        [void]$consumed.Add([pscustomobject]@{micro_batch_id=$mb.micro_batch_id; state='VALIDATED_NORMALIZED'; candidate_count=[int]$mb.candidate_count; accepted_count=[int]$norm.accepted_count; absorption_status='NOT_RUN'})
      }
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
  [ValidateRange(1,10000)][int]$DigestWindowAtoms = 1000,
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
function Resolve-SchoolCodexCli {
  $explicitExe=[string]$env:EFAB_CODEX_EXE
  $explicitHome=[string]$env:EFAB_CODEX_HOME
  $candidates=New-Object System.Collections.Generic.List[object]
  function Add-Candidate([string]$Exe,[string]$CodexHome,[string]$Source){
    if([string]::IsNullOrWhiteSpace($Exe) -or -not(Test-Path -LiteralPath $Exe)){ return }
    if([string]::IsNullOrWhiteSpace($CodexHome)){ $CodexHome=[string]$env:CODEX_HOME }
    if([string]::IsNullOrWhiteSpace($CodexHome)){ return }
    if(-not(Test-Path -LiteralPath $CodexHome)){ return }
    $resolved=(Resolve-Path -LiteralPath $Exe).Path
    if(@($candidates | Where-Object { $_.exe -eq $resolved -and $_.home -eq $CodexHome }).Count -eq 0){
      $candidates.Add([pscustomobject][ordered]@{exe=$resolved;home=$CodexHome;source=$Source})|Out-Null
    }
  }
  if(-not [string]::IsNullOrWhiteSpace($explicitExe)){
    Add-Candidate $explicitExe $explicitHome 'EFAB_EXPLICIT'
  }
  foreach($name in @('codex.cmd','codex.exe','codex')){
    $g=Get-Command $name -ErrorAction SilentlyContinue
    if($g){ Add-Candidate ([string]$g.Source) $explicitHome 'PATH' }
  }
  foreach($u in @(Get-ChildItem 'C:\Users' -Directory -Force -ErrorAction SilentlyContinue)){
    $codexHome=Join-Path $u.FullName '.codex'
    $exe=Join-Path $codexHome '.sandbox-bin\codex.exe'
    $auth=Join-Path $codexHome 'auth.json'
    if((Test-Path -LiteralPath $exe) -and (Test-Path -LiteralPath $auth)){ Add-Candidate $exe $codexHome 'PROFILE_SANDBOX_BIN' }
  }
  if($candidates.Count -eq 0){ throw 'SCHOOL_CODEX_RESOLUTION_FAILED:NO_AUTHENTICATED_CANDIDATE' }
  $healthy=New-Object System.Collections.Generic.List[object]
  foreach($c in $candidates){
    $old=$env:CODEX_HOME
    $oldEap=$ErrorActionPreference
    try{
      $env:CODEX_HOME=[string]$c.home
      $ErrorActionPreference='Continue'
      $ver=@(& ([string]$c.exe) --version 2>&1 | ForEach-Object{[string]$_})
      $verExit=$LASTEXITCODE
      $login=@(& ([string]$c.exe) login status 2>&1 | ForEach-Object{[string]$_})
      $loginExit=$LASTEXITCODE
      if($verExit -eq 0 -and $loginExit -eq 0 -and (($login -join "`n") -match '(?i)logged in')){
        $healthy.Add([pscustomobject][ordered]@{exe=[string]$c.exe;home=[string]$c.home;source=[string]$c.source;version=($ver -join ' ').Trim();login_status=($login -join ' ').Trim()})|Out-Null
      }
    } finally {
      $ErrorActionPreference=$oldEap
      if($null -eq $old){ Remove-Item Env:CODEX_HOME -ErrorAction SilentlyContinue }else{ $env:CODEX_HOME=$old }
    }
  }
  $uniq=@($healthy | Sort-Object exe,home -Unique)
  if($uniq.Count -eq 0){ throw 'SCHOOL_CODEX_RESOLUTION_FAILED:NO_HEALTHY_AUTHENTICATED_CANDIDATE' }
  if($uniq.Count -gt 1){ throw ('SCHOOL_CODEX_RESOLUTION_FAILED:AMBIGUOUS_HEALTHY_CANDIDATES:'+($uniq.Count)) }
  return [ordered]@{status='PASS_SCHOOL_CODEX_CLI_RESOLUTION_V1';exe=$uniq[0].exe;home=$uniq[0].home;source=$uniq[0].source;version=$uniq[0].version;login_status=$uniq[0].login_status}
}

function Resolve-SchoolPythonRuntime {
  $explicit=[string]$env:EFAB_PYTHON_EXE
  $candidates=New-Object System.Collections.Generic.List[object]
  function Add-PythonCandidate([string]$Exe,[string]$Source){
    if([string]::IsNullOrWhiteSpace($Exe) -or -not(Test-Path -LiteralPath $Exe)){ return }
    $resolved=(Resolve-Path -LiteralPath $Exe).Path
    if(@($candidates|Where-Object{$_.exe -eq $resolved}).Count -eq 0){ $candidates.Add([pscustomobject][ordered]@{exe=$resolved;source=$Source})|Out-Null }
  }
  if(-not[string]::IsNullOrWhiteSpace($explicit)){ Add-PythonCandidate $explicit 'EFAB_EXPLICIT' }
  foreach($name in @('python.exe','python3.exe','python')){ $g=Get-Command $name -ErrorAction SilentlyContinue; if($g){ Add-PythonCandidate ([string]$g.Source) 'PATH' } }
  foreach($u in @(Get-ChildItem 'C:\Users' -Directory -Force -ErrorAction SilentlyContinue)){
    foreach($py in @(Get-ChildItem (Join-Path $u.FullName 'AppData\Local\Programs\Python') -Directory -Filter 'Python*' -ErrorAction SilentlyContinue | ForEach-Object{Join-Path $_.FullName 'python.exe'})){ Add-PythonCandidate $py 'PROFILE_LOCAL_PROGRAMS' }
  }
  $healthy=New-Object System.Collections.Generic.List[object]
  foreach($c in $candidates){
    $oldEap=$ErrorActionPreference
    try{
      $ErrorActionPreference='Continue'
      $ver=@(& ([string]$c.exe) --version 2>&1|ForEach-Object{[string]$_}); $verExit=$LASTEXITCODE
      $smoke=@(& ([string]$c.exe) -c 'import sys; print(sys.executable)' 2>&1|ForEach-Object{[string]$_}); $smokeExit=$LASTEXITCODE
      if($verExit -eq 0 -and $smokeExit -eq 0 -and (($ver -join ' ') -match 'Python\s+(\d+\.\d+\.\d+)')){ $healthy.Add([pscustomobject][ordered]@{exe=[string]$c.exe;source=[string]$c.source;version=$Matches[1];smoke=($smoke -join ' ').Trim()})|Out-Null }
    } finally { $ErrorActionPreference=$oldEap }
  }
  if($healthy.Count -eq 0){ throw 'SCHOOL_PYTHON_RESOLUTION_FAILED:NO_HEALTHY_RUNTIME' }
  $chosen=$null
  if(-not[string]::IsNullOrWhiteSpace($explicit) -and (Test-Path -LiteralPath $explicit)){ $explicitResolved=(Resolve-Path -LiteralPath $explicit).Path; $chosen=@($healthy|Where-Object{$_.exe -eq $explicitResolved}|Select-Object -First 1) }
  if($null -eq $chosen -or @($chosen).Count -eq 0){ $chosen=@($healthy|Sort-Object @{Expression={[version]$_.version};Descending=$true},exe|Select-Object -First 1) }
  $chosen=@($chosen)[0]
  return [ordered]@{status='PASS_SCHOOL_PYTHON_RUNTIME_RESOLUTION_V1';exe=[string]$chosen.exe;source=[string]$chosen.source;version=[string]$chosen.version;smoke=[string]$chosen.smoke}
}
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
AddEvent 'EXACT_COUNT_CYCLE_STARTED' @{producer_mode=$ProducerMode; count=$Count; micro_batch_size=$MicroBatchSize; digest_window_atoms=$DigestWindowAtoms; absorb=[bool]$Absorb}
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
$streamingEnabled=$true
$producerCompletedAt=$null
$producerCompletedAtValue=$null
$orderedMicroBatches=@($task.micro_batches | Sort-Object sequence)
$streamBatches=New-Object System.Collections.ArrayList
$consumerReports=New-Object System.Collections.ArrayList
$consumerStatuses=New-Object System.Collections.ArrayList
$streamState=[ordered]@{next_ordinal=1; consumed=0; accepted=0; first_consume_started_at=$null; first_consume_started_at_value=$null; consumer_failed=$false}
function Test-ExpectedBatchReady([int]$Ordinal){
  if($Ordinal -lt 1 -or $Ordinal -gt $orderedMicroBatches.Count){ return $false }
  $mb=$orderedMicroBatches[$Ordinal-1]
  if(-not (Test-Path -LiteralPath ([string]$mb.ready_marker))){ return $false }
  if(-not (Test-Path -LiteralPath ([string]$mb.ready_jsonl))){ return $false }
  return $true
}
function Get-ReadyBatchTotals {
  $batchTotal=0
  $candidateTotal=0
  foreach($mb in @($orderedMicroBatches)){
    if((Test-Path -LiteralPath ([string]$mb.ready_marker)) -and (Test-Path -LiteralPath ([string]$mb.ready_jsonl))){
      $batchTotal++
      $candidateTotal += (Get-Content -LiteralPath ([string]$mb.ready_jsonl) | Measure-Object).Count
    }
  }
  return [pscustomobject]@{ready_batch_count=$batchTotal; ready_candidate_count=$candidateTotal}
}
function Invoke-ExpectedStreamConsume([string]$Reason){
  if([bool]$streamState['consumer_failed']){ return $false }
  $ordinal=[int]$streamState['next_ordinal']
  if($ordinal -lt 1 -or $ordinal -gt $orderedMicroBatches.Count){ return $false }
  $windowBatches=New-Object System.Collections.ArrayList
  $windowAtoms=0
  for($i=$ordinal-1; $i -lt $orderedMicroBatches.Count; $i++){
    $candidate=$orderedMicroBatches[$i]
    if(-not (Test-Path -LiteralPath ([string]$candidate.ready_marker))){ break }
    if(-not (Test-Path -LiteralPath ([string]$candidate.ready_jsonl))){ break }
    [void]$windowBatches.Add($candidate)
    $windowAtoms += [int]$candidate.candidate_count
    if(-not $Absorb -or $windowAtoms -ge $DigestWindowAtoms){ break }
  }
  if($windowBatches.Count -eq 0){ return $false }
  if($Absorb -and $windowAtoms -lt $DigestWindowAtoms -and -not (Test-Path -LiteralPath ([string]$task.producer_done_marker))){
    AddEvent 'STREAM_DIGEST_WINDOW_WAIT' @{next_ordinal=$ordinal; ready_window_batches=$windowBatches.Count; ready_window_atoms=$windowAtoms; digest_window_atoms=$DigestWindowAtoms; reason=$Reason}
    return $false
  }
  $readyDetectedAt=Get-Date
  AddEvent 'STREAM_READY_WINDOW_DETECTED' @{ordinal=$ordinal; batch_count=$windowBatches.Count; atom_count=$windowAtoms; digest_window_atoms=$DigestWindowAtoms; reason=$Reason}
  $consumeStartedAt=Get-Date
  if($null -eq $streamState['first_consume_started_at_value']){
    $streamState['first_consume_started_at_value']=$consumeStartedAt
    $streamState['first_consume_started_at']=$consumeStartedAt.ToString('o')
  }
  $maxConsume=[int]$windowBatches.Count
  if($Absorb){ $out=@(& { Invoke-SchoolWarehouseConsumer -MacroTaskJsonPath $taskJson -MaxConsumeBatches $maxConsume -MaxWaitSeconds 0 -Absorb } *>&1 | ForEach-Object{[string]$_}) }
  else { $out=@(& { Invoke-SchoolWarehouseConsumer -MacroTaskJsonPath $taskJson -MaxConsumeBatches $maxConsume -MaxWaitSeconds 0 } *>&1 | ForEach-Object{[string]$_}) }
  $consumeCompletedAt=Get-Date
  $outPath=("{0}/consumer_{1:D3}_stdout.txt" -f $OutputRoot,$ordinal)
  $out | Set-Content -LiteralPath $outPath -Encoding UTF8
  $cr=(($out|Where-Object{$_ -match '^CODEX_WAREHOUSE_CONSUMER_REPORT='}|Select-Object -Last 1) -replace '^CODEX_WAREHOUSE_CONSUMER_REPORT=','')
  $consumerStatus='MISSING_REPORT'; $snapshotReport=$null; $acceptedCount=0; $windowAccepted=0; $windowConsumedOk=$false
  if(-not [string]::IsNullOrWhiteSpace($cr) -and (Test-Path -LiteralPath $cr)){
    $c=Get-Content -LiteralPath $cr -Raw | ConvertFrom-Json
    $consumerStatus=[string]$c.status
    $snapshotReport=("{0}/consumer_{1:D3}_report.json" -f $OutputRoot,$ordinal)
    Copy-Item -LiteralPath $cr -Destination $snapshotReport -Force
    [void]$consumerReports.Add($snapshotReport)
    [void]$consumerStatuses.Add($consumerStatus)
    $consumedBatch=@($c.consumed_batches)
    if($consumedBatch.Count -eq $windowBatches.Count){
      $windowConsumedOk=$true
      for($j=0; $j -lt $windowBatches.Count; $j++){
        $expectedId=[string]$windowBatches[$j].micro_batch_id
        $actualId=[string]$consumedBatch[$j].micro_batch_id
        if($actualId -ne $expectedId){ throw ("STREAM_CONSUMED_OUT_OF_ORDER:expected:{0}:actual:{1}" -f $expectedId,$actualId) }
        $windowAccepted += [int]$consumedBatch[$j].accepted_count
      }
      $streamState['consumed']=[int]$streamState['consumed'] + $consumedBatch.Count
      $streamState['accepted']=[int]$streamState['accepted'] + $windowAccepted
      $streamState['next_ordinal']=$ordinal + $consumedBatch.Count
    } else { $streamState['consumer_failed']=$true }
  } else { $streamState['consumer_failed']=$true }
  for($j=0; $j -lt $windowBatches.Count; $j++){
    $mb=$windowBatches[$j]
    $acceptedCount=if($windowConsumedOk){[int](@($c.consumed_batches)[$j].accepted_count)}else{0}
    [void]$streamBatches.Add([ordered]@{ordinal=($ordinal+$j);id=[string]$mb.micro_batch_id;count=[int]$mb.candidate_count;ready_detected_at=$readyDetectedAt.ToString('o');consume_started_at=$consumeStartedAt.ToString('o');consume_completed_at=$consumeCompletedAt.ToString('o');consumer_status=$consumerStatus;accepted_count=$acceptedCount;consumer_report=$snapshotReport;digest_window_atoms=$windowAtoms;digest_window_batch_count=$windowBatches.Count})
    if($windowConsumedOk){ AddEvent 'STREAM_BATCH_CONSUMED' @{ordinal=($ordinal+$j); id=[string]$mb.micro_batch_id; count=[int]$mb.candidate_count; accepted_count=$acceptedCount; digest_window_atoms=$windowAtoms; digest_window_batch_count=$windowBatches.Count; consume_started_at=$consumeStartedAt.ToString('o'); consume_completed_at=$consumeCompletedAt.ToString('o'); reason=$Reason} }
  }
  return [bool]$windowConsumedOk
}
function Drain-ReadyExpectedStreamBatches([string]$Reason){
  while($true){
    $ordinal=[int]$streamState['next_ordinal']
    if($ordinal -gt $orderedMicroBatches.Count){ break }
    if(-not (Test-ExpectedBatchReady -Ordinal $ordinal)){ break }
    if(-not (Invoke-ExpectedStreamConsume -Reason $Reason)){ break }
  }
}
if($ProducerMode -eq 'MockProducer'){
  $mockProducerCompleted=$true
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
    if(-not (Invoke-ExpectedStreamConsume -Reason 'mock_after_marker')){
      $mockProducerCompleted=$false
      $producerFailureClass=("MOCK_STREAM_CONSUME_FAILED_AT_ORDINAL_{0}" -f $streamState['next_ordinal'])
      break
    }
  }
  if($mockProducerCompleted){
    WriteJson ([string]$task.heartbeat_path) ([ordered]@{status='PRODUCER_DONE'; request_id=$task.request_id; last_written_batch=[int]$task.micro_batch_count; updated_at=(Get-Date).ToString('o'); mode='MockProducer'}) 20
    WriteJson ([string]$task.producer_done_marker) ([ordered]@{status='PRODUCER_DONE'; micro_batch_count=[int]$task.micro_batch_count; candidate_count=[int]$task.total_candidate_count; updated_at=(Get-Date).ToString('o'); mode='MockProducer'}) 20
    $producerCompletedAtValue=Get-Date
    $producerCompletedAt=$producerCompletedAtValue.ToString('o')
    $producerStatus='MOCK_PRODUCER_ALL_READY_CREATED'
  } else {
    $producerStatus='MOCK_FAILED'
  }
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
  [void]$promptLines.Add('- After writing each READY.marker.json, immediately continue producing the next batch without waiting for School consumption.')
  [void]$promptLines.Add('- Produce exactly one micro-batch per shell/tool command invocation. Never create or write READY files for more than one micro-batch in the same command, script, or process.')
  [void]$promptLines.Add('- Before writing each READY.marker.json, validate only that current batch: exact candidate_count, unique candidate_id values, correct topic/depth/source fields, and every required quality field non-empty.')
  [void]$promptLines.Add('- For every candidate, expected_behavior, validator, proof_requirements, negative_case, return_to_parent, and digest_hint must each be non-empty strings regardless of depth_level.')
  [void]$promptLines.Add('- After a batch READY.marker.json is written, return control to Codex before starting a separate command invocation for the next micro-batch.')
  [void]$promptLines.Add('- Write exactly TARGET_COUNT JSONL candidate lines total across all batches.')
  [void]$promptLines.Add('- Write heartbeat and DONE marker after all batches are READY.')
  [void]$promptLines.Add('- Do not mutate active memory. Do not edit tracked repo files.')
  [void]$promptLines.Add('')
  [void]$promptLines.Add('Each JSONL line must be a JSON object with fields: schema,candidate_id,topic_key,topic_label,depth_level,prerequisite_depth,target_depth,source_basis,source_missing,claim,expected_behavior,failure_contrast,validator,proof_requirements,negative_case,return_to_parent,digest_hint,quality_flags.')
  [void]$promptLines.Add('Use schema=codex_school_patch_candidate_v1, topic_key exactly TOPIC_KEY, source_basis as a non-empty array or source_missing=true, and depth_level between START_DEPTH and TARGET_DEPTH.')
  [void]$promptLines.Add('After all READY markers and DONE marker are written, stop.')
  $promptLines | Set-Content -LiteralPath $promptPath -Encoding UTF8
  $pythonResolution=Resolve-SchoolPythonRuntime
  $env:EFAB_PYTHON_EXE=[string]$pythonResolution.exe
  $pythonDir=Split-Path -Parent ([string]$pythonResolution.exe)
  $pathParts=@([string]$env:PATH -split ';' | Where-Object{-not[string]::IsNullOrWhiteSpace($_)})
  if($pathParts -notcontains $pythonDir){ $env:PATH=($pythonDir+';'+[string]$env:PATH) }
  $codexResolution=Resolve-SchoolCodexCli
  $codexCmd=[string]$codexResolution.exe
  $env:CODEX_HOME=[string]$codexResolution.home
  $cmdLine='""{0}" exec -C "{1}" --dangerously-bypass-approvals-and-sandbox --ephemeral - < "{2}" > "{3}" 2> "{4}""' -f $codexCmd,$repoRoot,$promptPath,$stdoutPath,$stderrPath
  AddEvent 'PYTHON_RUNTIME_RESOLUTION' @{status=$pythonResolution.status; exe=$pythonResolution.exe; source=$pythonResolution.source; version=$pythonResolution.version}
  AddEvent 'CODEX_RESOLUTION' @{status=$codexResolution.status; exe=$codexCmd; home=$codexResolution.home; source=$codexResolution.source; version=$codexResolution.version}
  AddEvent 'CODEX_LAUNCH' @{prompt_path=$promptPath; timeout_seconds=$CodexTimeoutSeconds; exe=$codexCmd; codex_home=$codexResolution.home; execution_mode='BOUNDED_BYPASS_WINDOWS_SYSTEM'; output_contract='WAREHOUSE_ONLY_NO_ACTIVE_MEMORY_NO_TRACKED_WRITES'}
  $p=Start-Process -FilePath $env:ComSpec -ArgumentList @('/d','/c',$cmdLine) -NoNewWindow -PassThru
  $deadline=(Get-Date).AddSeconds($CodexTimeoutSeconds)
  $completed=$false
  while($true){
    $p.Refresh()
    if($p.HasExited){
      $completed=$true
      $producerCompletedAtValue=Get-Date
      try{ $exitTime=$p.ExitTime; if($null -ne $exitTime){ $producerCompletedAtValue=$exitTime } }catch{}
      $producerCompletedAt=$producerCompletedAtValue.ToString('o')
      break
    }
    if((Get-Date) -ge $deadline){
      Stop-ProcessTreeByRootPid -RootPid ([int]$p.Id)
      break
    }
    Drain-ReadyExpectedStreamBatches -Reason 'producer_alive'
    Start-Sleep -Seconds 2
  }
  Drain-ReadyExpectedStreamBatches -Reason 'producer_stopped'
  $readyTotals=Get-ReadyBatchTotals
  $readyBatchCount=[int]$readyTotals.ready_batch_count
  $readyCandidateCount=[int]$readyTotals.ready_candidate_count
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
$readyTotalsFinal=Get-ReadyBatchTotals
$readyBatchCount=[int]$readyTotalsFinal.ready_batch_count
$readyCandidateCount=[int]$readyTotalsFinal.ready_candidate_count
$consumed=[int]$streamState['consumed']
$accepted=[int]$streamState['accepted']
$firstConsumeStartedAt=$streamState['first_consume_started_at']
$overlapProven=$false
if($ProducerMode -eq 'RunCodex' -and [int]$task.micro_batch_count -gt 1 -and $null -ne $streamState['first_consume_started_at_value'] -and $null -ne $producerCompletedAtValue){
  $overlapProven=([datetime]$streamState['first_consume_started_at_value'] -lt [datetime]$producerCompletedAtValue)
}
$memoryAfter=[ordered]@{manifest=Sha "$mem/manifest.json"; index=Sha "$mem/index.json"; cells=Sha "$mem/cells.jsonl"}
$memoryChanged=($memoryBefore.cells -ne $memoryAfter.cells -or $memoryBefore.index -ne $memoryAfter.index -or $memoryBefore.manifest -ne $memoryAfter.manifest)
$status=if($producerStatus -eq 'CODEX_PRODUCER_ALL_READY_CREATED' -and $accepted -eq $Count -and -not $Absorb -and -not $memoryChanged){'PASS_REAL_CODEX_EXACT_COUNT_CYCLE_NO_ABSORB_V1'}elseif($producerStatus -eq 'MOCK_PRODUCER_ALL_READY_CREATED' -and $accepted -eq $Count -and -not $Absorb -and -not $memoryChanged){'PASS_MOCK_EXACT_COUNT_CYCLE_NO_ABSORB_V1'}elseif($producerStatus -eq 'CODEX_PRODUCER_ALL_READY_CREATED' -and $accepted -eq $Count -and $Absorb -and $memoryChanged){'PASS_REAL_CODEX_EXACT_COUNT_CYCLE_WITH_ABSORB_V1'}else{'CHECK_EXACT_COUNT_CYCLE_V1'}
$report=[ordered]@{
  schema='generic_exact_count_warehouse_cycle_v1'
  status=$status
  created_at=(Get-Date).ToString('o')
  run_id=$runId
  producer_mode=$ProducerMode
  count=$Count
  micro_batch_size=$MicroBatchSize
  micro_batch_count=[int]$task.micro_batch_count
  digest_window_atoms=$DigestWindowAtoms
  batch_counts=$batchCounts
  streaming_enabled=[bool]$streamingEnabled
  producer_completed_at=$producerCompletedAt
  first_consume_started_at=$firstConsumeStartedAt
  stream_batches=@($streamBatches)
  overlap_proven=[bool]$overlapProven
  producer_status=$producerStatus
  producer_failure_class=$producerFailureClass
  producer_exit_anomaly=[bool]$producerExitAnomaly
  producer_exit_class=$producerExitClass
  producer_exit_code=$producerExitCode
  ready_batch_count=$readyBatchCount
  ready_candidate_count=$readyCandidateCount
  consumed_batches=$consumed
  accepted_count=$accepted
  absorb=[bool]$Absorb
  consumer_statuses=@($consumerStatuses)
  consumer_reports=@($consumerReports)
  memory_before=$memoryBefore
  memory_after=$memoryAfter
  memory_changed=$memoryChanged
  task_json=$taskJson
  output_root=$OutputRoot
  boundary='Generic exact Count cycle. Absorption only if -Absorb is passed. Complete valid READY/DONE output with nonzero/timeout external exit is reported as producer_exit_anomaly, not producer_failure_class.'
}
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
$AllowedSelectionStatuses=@('PASS_DYNAMIC_THEME_CELL_SELECTION_V1','PASS_DEVELOPMENT_VECTOR_THEME_SELECTION_V1','PASS_DEVELOPMENT_VECTOR_THEME_SELECTION_V2')
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
  $ExactCycleArgs=[ordered]@{ ProducerMode=$ExactCycleProducerMode; Count=$TargetAccepted; MicroBatchSize=100; DigestWindowAtoms=1000; Topics=$RequestedTopics; OutputRoot=$ExactCycleRoot; CodexTimeoutSeconds=300 }
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
} finally {
  if($SchoolSingleInstanceAcquired -and $script:SchoolSingleInstanceMutex){ try { $script:SchoolSingleInstanceMutex.ReleaseMutex() } catch {} }
  if($script:SchoolSingleInstanceMutex){ $script:SchoolSingleInstanceMutex.Dispose() }
}
