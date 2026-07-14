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
        $absorbOut=@(& powershell -NoProfile -ExecutionPolicy Bypass -File operations/school/digestion/absorb_atom_file_via_digest_pipeline_v1.ps1 -InputPath ([string]$mb.normalized_atoms_jsonl) -RunId ("$($task.run_id)_$($mb.micro_batch_id)") *>&1 | ForEach-Object{[string]$_})
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
