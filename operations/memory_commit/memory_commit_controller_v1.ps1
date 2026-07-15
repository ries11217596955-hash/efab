param(
  [ValidateSet('Status','DrainAgentLife','PostSchoolComplete','AuditSchoolQuality','PruneProcessedAgentLife','BatchDrainAgentLife','SelfTestRejectDelete')][string]$Action='Status',
  [int]$MaxPackets=0,
  [string]$QueueRoot='.runtime/compact_memory_intake_v1/queue',
  [string]$RunRoot='.runtime/memory_commit_organ_v1',
  [switch]$DeleteRejected,
  [switch]$SummarizeProcessed,
  [switch]$BatchMerge,
  [string]$SchoolRunDir='.runtime/canonical_exact_count_cycle/canonical_exact_count_cycle_real_2000_20260715_211515'
)
$ErrorActionPreference='Stop'
function Write-CleanJson([string]$Path,$Obj,[int]$Depth=30){
  $dir=Split-Path $Path -Parent
  if($dir){ New-Item -ItemType Directory -Force -Path $dir | Out-Null }
  $json=$Obj | ConvertTo-Json -Depth $Depth
  $lines=@($json -split "`r?`n" | ForEach-Object { $_.TrimEnd() })
  while($lines.Count -gt 0 -and $lines[$lines.Count-1] -eq ''){ if($lines.Count -eq 1){$lines=@();break}; $lines=@($lines[0..($lines.Count-2)]) }
  $utf8NoBom=New-Object System.Text.UTF8Encoding($false)
  $full=if([System.IO.Path]::IsPathRooted($Path)){ $Path } else { Join-Path (Get-Location).Path $Path }
  [System.IO.File]::WriteAllText($full,(($lines -join "`n") + "`n"),$utf8NoBom)
}
function Append-CleanJsonLine([string]$Path,$Obj){
  $dir=Split-Path $Path -Parent
  if($dir){ New-Item -ItemType Directory -Force -Path $dir | Out-Null }
  $json=$Obj | ConvertTo-Json -Depth 30 -Compress
  $utf8NoBom=New-Object System.Text.UTF8Encoding($false)
  $full=if([System.IO.Path]::IsPathRooted($Path)){ $Path } else { Join-Path (Get-Location).Path $Path }
  [System.IO.File]::AppendAllText($full,$json + "`n",$utf8NoBom)
}
function Read-JsonSafe([string]$Path){
  if(-not(Test-Path -LiteralPath $Path)){ return $null }
  try { return (Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json) } catch { return $null }
}
function Get-ActiveMemoryState {
  $root='.runtime/active_compact_semantic_memory_v1'
  $files=[ordered]@{}
  foreach($name in @('manifest.json','index.json','cells.jsonl')){
    $p=Join-Path $root $name
    if(Test-Path -LiteralPath $p){
      $item=Get-Item -LiteralPath $p
      $hash=(Get-FileHash -LiteralPath $p -Algorithm SHA256).Hash.ToLower()
      $files[$name]=[ordered]@{ bytes=$item.Length; sha256=$hash; last_write=$item.LastWriteTime.ToString('o') }
    } else { $files[$name]=[ordered]@{ missing=$true } }
  }
  return [ordered]@{ root=$root; files=$files }
}
function Get-CurrentProcessAncestryIds {
  $ids=New-Object System.Collections.Generic.HashSet[int]
  $cur=$PID
  while($cur -and -not $ids.Contains([int]$cur)){
    [void]$ids.Add([int]$cur)
    $proc=Get-CimInstance Win32_Process -Filter "ProcessId=$cur" -ErrorAction SilentlyContinue
    if(-not $proc){ break }
    $cur=[int]$proc.ParentProcessId
  }
  return $ids
}
function Test-MemoryPathBusy {
  $busy=@()
  if(Test-Path '.runtime/compact_memory_intake_v1/MERGE_QUEUE.lock.json'){ $busy += 'MERGE_QUEUE_LOCK_EXISTS' }
  $ignoreIds=Get-CurrentProcessAncestryIds
  $terms=@('run_agent_school','exact_count_cycle','codex_warehouse','consume_codex_warehouse','absorb_atom_file_via_digest_pipeline','invoke_compact_semantic_digestion','merge_compact_memory_intake_queue')
  foreach($p in @(Get-CimInstance Win32_Process -ErrorAction SilentlyContinue)){
    if($ignoreIds.Contains([int]$p.ProcessId)){ continue }
    $cmd=[string]$p.CommandLine
    if([string]::IsNullOrWhiteSpace($cmd)){ $cmd='' }
    foreach($t in $terms){ if($p.Name -like "*$t*" -or $cmd -like "*$t*"){ $busy += "PROCESS:$($p.ProcessId):$t"; break } }
  }
  return [ordered]@{ busy=(@($busy).Count -gt 0); reasons=@($busy); ignored_process_ids=@($ignoreIds) }
}
function Get-QueuePackets([string]$Root,[int]$Limit){
  if(-not(Test-Path -LiteralPath $Root)){ return @() }
  $items=@(Get-ChildItem -LiteralPath $Root -File -Filter '*.json' | Sort-Object LastWriteTime,Name)
  if($Limit -gt 0){ return @($items | Select-Object -First $Limit) }
  return $items
}
function Validate-Packet([string]$Path){
  $previousPreference=$ErrorActionPreference
  $ErrorActionPreference='Continue'
  $out=@()
  $exitCode=$null
  try {
    $out=@(& powershell -NoProfile -ExecutionPolicy Bypass -File 'operations/compact_memory_intake/validate_compact_memory_packet_v1.ps1' -PacketPath $Path *>&1 | ForEach-Object { [string]$_ })
    $exitCode=$LASTEXITCODE
  } catch {
    $out += [string]$_.Exception.Message
    $exitCode=1
  } finally {
    $ErrorActionPreference=$previousPreference
  }
  $status=($out | Where-Object { $_ -match '^PACKET_VALIDATION_STATUS=' } | Select-Object -Last 1) -replace '^PACKET_VALIDATION_STATUS=',''
  if([string]::IsNullOrWhiteSpace($status)){
    if($exitCode -ne 0){ $status='FAIL_PACKET_VALIDATION_EXCEPTION' } else { $status='UNKNOWN' }
  }
  return [ordered]@{ status=$status; exit_code=$exitCode; output=@($out) }
}
function Packet-Summary([string]$Path,[string]$Decision,[string]$Reason){
  $packet=Read-JsonSafe $Path
  $atoms=@()
  if($packet -and $packet.atoms){ foreach($a in @($packet.atoms)){ $atoms += [ordered]@{ id=$a.id; topic=$a.topic; quality_score=$a.quality_score; novelty_score=$a.novelty_score; source_ref=$a.source_ref } } }
  return [ordered]@{ packet=(Split-Path $Path -Leaf); source_kind=if($packet){$packet.source_kind}else{$null}; source_id=if($packet){$packet.source_id}else{$null}; atom_count=@($atoms).Count; atoms=@($atoms); decision=$Decision; reason=$Reason; deleted=$false; timestamp=(Get-Date).ToString('o') }
}

function New-CombinedAgentLifePacket([array]$ValidItems,[string]$RunId,[string]$OutputDir){
  New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null
  $atoms=@(); $sourceFiles=@(); $minQuality=1.0; $minNovelty=1.0
  foreach($item in $ValidItems){
    $packet=$item.packet
    $sourceFiles += [string]$item.path
    foreach($a in @($packet.atoms)){
      $atom=[ordered]@{}
      foreach($prop in $a.PSObject.Properties){ $atom[$prop.Name]=$prop.Value }
      if([string]::IsNullOrWhiteSpace([string]$atom.id)){ $atom.id='agentlife_atom_'+([guid]::NewGuid().ToString('n')) }
      if($null -eq $atom.quality_score){ $atom.quality_score=0.95 }
      if($null -eq $atom.novelty_score){ $atom.novelty_score=0.60 }
      $minQuality=[Math]::Min($minQuality,[double]$atom.quality_score)
      $minNovelty=[Math]::Min($minNovelty,[double]$atom.novelty_score)
      $atoms += $atom
    }
  }
  $combined=[ordered]@{
    schema='compact_memory_knowledge_packet_v1'
    source_kind='AgentLife'
    source_id=('MemoryCommitBatchDrain:'+$RunId)
    created_at=(Get-Date).ToString('o')
    atoms=@($atoms)
    quality_summary=[ordered]@{ atom_count=@($atoms).Count; min_quality_score=$minQuality; min_novelty_score=$minNovelty; combined_from_packets=@($ValidItems).Count }
    boundary=[ordered]@{ source='MEMORY_COMMIT_BATCH_DRAIN'; direct_active_memory_write=$false; combined_agentlife_packets=@($ValidItems).Count; original_packet_paths=@($sourceFiles) }
  }
  $path=Join-Path $OutputDir ('agentlife_batch_'+$RunId+'.json')
  Write-CleanJson $path $combined 80
  return [ordered]@{ path=$path; packet=$combined; source_files=@($sourceFiles) }
}
function Invoke-BatchDrainAgentLife([int]$Limit,[string]$Reason){
  New-Item -ItemType Directory -Force -Path $RunRoot | Out-Null
  $runId='memory_commit_batch_'+(Get-Date -Format 'yyyyMMdd_HHmmss')
  $proofPath=Join-Path $RunRoot ($runId + '_proof.json')
  $rejectedPath=Join-Path $RunRoot 'rejected_metrics.jsonl'
  $processedSummaryPath=Join-Path $RunRoot 'processed_summaries.jsonl'
  $before=Get-ActiveMemoryState
  $busy=Test-MemoryPathBusy
  $allPackets=@(Get-QueuePackets $QueueRoot $Limit)
  if($busy.busy){
    $out=[ordered]@{ schema='memory_commit_batch_drain_proof_v1'; status='BLOCKED_MEMORY_PATH_BUSY'; action='BatchDrainAgentLife'; reason=$Reason; busy=$busy; queue_root=$QueueRoot; queue_before=@($allPackets).Count; queue_after=@(Get-QueuePackets $QueueRoot 0).Count; active_memory_before=$before; active_memory_after=$before; created_at=(Get-Date).ToString('o') }
    Write-CleanJson $proofPath $out 40
    Write-Host "MEMORY_COMMIT_BATCH_STATUS=BLOCKED_MEMORY_PATH_BUSY"
    Write-Host "MEMORY_COMMIT_BATCH_PROOF=$proofPath"
    return $out
  }
  $valid=@(); $events=@(); $rejected=0; $deletedRejected=0; $skipped=0
  foreach($file in $allPackets){
    $packet=Read-JsonSafe $file.FullName
    $sourceKind=if($packet){ [string]$packet.source_kind } else { '<bad_json>' }
    if($sourceKind -ne 'AgentLife'){
      $skipped++
      $events += [ordered]@{ packet=$file.Name; decision='SKIP_NON_AGENTLIFE'; source_kind=$sourceKind }
      continue
    }
    $validation=Validate-Packet $file.FullName
    if($validation.status -ne 'PASS_COMPACT_MEMORY_KNOWLEDGE_PACKET_V1'){
      $rejected++
      $summary=Packet-Summary $file.FullName 'REJECT_DELETE' ('validation_status='+$validation.status)
      $summary.validation=$validation
      $deleteRequired=($DeleteRejected.IsPresent -or $Reason -eq 'SelfTestRejectDelete')
      if($deleteRequired){ Remove-Item -LiteralPath $file.FullName -Force; $summary.deleted=$true; $deletedRejected++ }
      Append-CleanJsonLine $rejectedPath $summary
      $events += $summary
      continue
    }
    $valid += [ordered]@{ file=$file; path=$file.FullName; packet=$packet; validation=$validation }
  }
  $accepted=0; $processed=0; $mergeProof=$null; $mergeStatus=$null; $mergeExit=$null; $combinedPath=$null
  if(@($valid).Count -gt 0){
    $combined=New-CombinedAgentLifePacket $valid $runId (Join-Path $RunRoot 'batch_packets')
    $combinedPath=$combined.path
    $combinedValidation=Validate-Packet $combinedPath
    if($combinedValidation.status -ne 'PASS_COMPACT_MEMORY_KNOWLEDGE_PACKET_V1'){
      $rejected += @($valid).Count
      foreach($item in $valid){
        $summary=Packet-Summary $item.path 'REJECT_DELETE' ('combined_validation_status='+$combinedValidation.status)
        $deleteRequired=($DeleteRejected.IsPresent -or $Reason -eq 'SelfTestRejectDelete')
        if($deleteRequired){ Remove-Item -LiteralPath $item.path -Force; $summary.deleted=$true; $deletedRejected++ }
        Append-CleanJsonLine $rejectedPath $summary
        $events += $summary
      }
    } else {
      $mergeOut=@(& powershell -NoProfile -ExecutionPolicy Bypass -File 'operations/compact_memory_intake/merge_compact_memory_intake_queue_v1.ps1' -PacketPath $combinedPath -ProcessLimit 1 *>&1 | ForEach-Object { [string]$_ })
      $mergeExit=$LASTEXITCODE
      $mergeStatus=($mergeOut | Where-Object { $_ -match '^MERGE_QUEUE_STATUS=' } | Select-Object -Last 1) -replace '^MERGE_QUEUE_STATUS=',''
      $mergeProof=($mergeOut | Where-Object { $_ -match '^MERGE_QUEUE_PROOF=' } | Select-Object -Last 1) -replace '^MERGE_QUEUE_PROOF=',''
      if($mergeExit -eq 0 -and $mergeStatus -eq 'PASS_MULTI_SOURCE_COMPACT_MEMORY_MERGE_QUEUE_V1'){
        foreach($item in $valid){
          if(Test-Path -LiteralPath $item.path){ Remove-Item -LiteralPath $item.path -Force }
          $event=Packet-Summary $item.path 'ACCEPT_BATCH_MERGE' ('merge_status='+$mergeStatus)
          $event.deleted=$true; $event.combined_packet_path=$combinedPath; $event.merge_proof=$mergeProof
          Append-CleanJsonLine $processedSummaryPath $event
          $events += $event
        }
        $accepted=@($valid).Count; $processed=@($valid).Count
      } else {
        foreach($item in $valid){
          $event=Packet-Summary $item.path 'MERGE_FAILED_KEEP_PENDING' ('merge_status='+$mergeStatus)
          $event.deleted=$false; $event.merge_output_tail=@($mergeOut | Select-Object -Last 8)
          Append-CleanJsonLine $rejectedPath $event
          $events += $event
        }
      }
    }
  }
  $after=Get-ActiveMemoryState
  $out=[ordered]@{
    schema='memory_commit_batch_drain_proof_v1'
    status='PASS_MEMORY_COMMIT_BATCH_DRAIN_AGENTLIFE_V1'
    action='BatchDrainAgentLife'
    reason=$Reason
    run_id=$runId
    queue_root=$QueueRoot
    queue_before=@($allPackets).Count
    queue_after=@(Get-QueuePackets $QueueRoot 0).Count
    valid_packet_count=@($valid).Count
    accepted_count=$accepted
    rejected_count=$rejected
    deleted_rejected_count=$deletedRejected
    skipped_count=$skipped
    processed_count=$processed
    combined_packet_path=$combinedPath
    merge_exit=$mergeExit
    merge_status=$mergeStatus
    merge_proof=$mergeProof
    active_memory_before=$before
    active_memory_after=$after
    active_memory_changed=($($before.files | ConvertTo-Json -Depth 20) -ne $($after.files | ConvertTo-Json -Depth 20))
    events=@($events)
    created_at=(Get-Date).ToString('o')
    retention=[ordered]@{ rejected_full_packets_deleted=($DeleteRejected.IsPresent -or $Reason -eq 'SelfTestRejectDelete'); processed_summaries_path=$processedSummaryPath; rejected_metrics_path=$rejectedPath; accepted_source_packets_deleted=($accepted -gt 0) }
  }
  Write-CleanJson $proofPath $out 80
  Write-Host "MEMORY_COMMIT_BATCH_STATUS=$($out.status)"
  Write-Host "VALID_PACKET_COUNT=$($out.valid_packet_count)"
  Write-Host "ACCEPTED_COUNT=$accepted"
  Write-Host "REJECTED_COUNT=$rejected"
  Write-Host "QUEUE_AFTER=$($out.queue_after)"
  Write-Host "ACTIVE_MEMORY_CHANGED=$($out.active_memory_changed)"
  Write-Host "MEMORY_COMMIT_BATCH_PROOF=$proofPath"
  return $out
}
function Invoke-SelfTestRejectDelete {
  New-Item -ItemType Directory -Force -Path $QueueRoot | Out-Null
  $testId='reject_delete_'+(Get-Date -Format 'yyyyMMdd_HHmmss')
  $badPath=Join-Path $QueueRoot ($testId+'.json')
  $bad=[ordered]@{
    schema='compact_memory_knowledge_packet_v1'
    source_kind='AgentLife'
    source_id=('NegativeTest:'+$testId)
    created_at=(Get-Date).ToString('o')
    atoms=@([ordered]@{ id=$testId; topic='negative.reject.delete'; level=1; quality_score=0.10; novelty_score=0.10; summary='bad packet intentionally below quality threshold'; behavior_use_hint='must be rejected and deleted' })
    quality_summary=[ordered]@{ atom_count=1; min_quality_score=0.10; min_novelty_score=0.10 }
    boundary=[ordered]@{ source='MEMORY_COMMIT_NEGATIVE_TEST'; direct_active_memory_write=$false }
  }
  Write-CleanJson $badPath $bad 30
  $proof=Invoke-BatchDrainAgentLife 1 'SelfTestRejectDelete'
  $deleted=(-not(Test-Path -LiteralPath $badPath))
  $status=if($proof.rejected_count -ge 1 -and $deleted){'PASS_MEMORY_COMMIT_REJECT_DELETE_V1'}else{'FAIL_MEMORY_COMMIT_REJECT_DELETE_V1'}
  $out=[ordered]@{ schema='memory_commit_reject_delete_selftest_v1'; status=$status; bad_packet_path=$badPath; packet_deleted=$deleted; drain_proof=$proof; created_at=(Get-Date).ToString('o') }
  $path=Join-Path $RunRoot ('reject_delete_selftest_'+(Get-Date -Format 'yyyyMMdd_HHmmss')+'.json')
  Write-CleanJson $path $out 80
  Write-Host "REJECT_DELETE_STATUS=$status"
  Write-Host "PACKET_DELETED=$deleted"
  Write-Host "REJECT_DELETE_PROOF=$path"
  return $out
}

function Invoke-DrainAgentLife([int]$Limit,[string]$Reason){
  New-Item -ItemType Directory -Force -Path $RunRoot | Out-Null
  $runId='memory_commit_'+(Get-Date -Format 'yyyyMMdd_HHmmss')
  $proofPath=Join-Path $RunRoot ($runId + '_proof.json')
  $rejectedPath=Join-Path $RunRoot 'rejected_metrics.jsonl'
  $processedSummaryPath=Join-Path $RunRoot 'processed_summaries.jsonl'
  $before=Get-ActiveMemoryState
  $busy=Test-MemoryPathBusy
  if($busy.busy){
    $out=[ordered]@{ schema='memory_commit_controller_v1_proof'; status='BLOCKED_MEMORY_PATH_BUSY'; action='DrainAgentLife'; reason=$Reason; busy=$busy; queue_root=$QueueRoot; active_memory_before=$before; active_memory_after=$before; accepted_count=0; rejected_count=0; deleted_rejected_count=0; processed_count=0; queue_before=@(Get-QueuePackets $QueueRoot 0).Count; queue_after=@(Get-QueuePackets $QueueRoot 0).Count; created_at=(Get-Date).ToString('o') }
    Write-CleanJson $proofPath $out 40
    Write-Host "MEMORY_COMMIT_STATUS=BLOCKED_MEMORY_PATH_BUSY"
    Write-Host "MEMORY_COMMIT_PROOF=$proofPath"
    return $out
  }
  $packets=@(Get-QueuePackets $QueueRoot $Limit)
  $events=@(); $accepted=0; $rejected=0; $deletedRejected=0; $processed=0; $mergeProofs=@()
  foreach($file in $packets){
    $packet=Read-JsonSafe $file.FullName
    $sourceKind=if($packet){ [string]$packet.source_kind } else { '<bad_json>' }
    if($sourceKind -ne 'AgentLife'){
      $events += [ordered]@{ packet=$file.Name; decision='SKIP_NON_AGENTLIFE'; source_kind=$sourceKind }
      continue
    }
    $validation=Validate-Packet $file.FullName
    if($validation.status -ne 'PASS_COMPACT_MEMORY_KNOWLEDGE_PACKET_V1'){
      $rejected++
      $summary=Packet-Summary $file.FullName 'REJECT_DELETE' ('validation_status='+$validation.status)
      $summary.validation=$validation
      $deleteRequired=($DeleteRejected.IsPresent -or $Reason -eq 'SelfTestRejectDelete')
      if($deleteRequired){ Remove-Item -LiteralPath $file.FullName -Force; $summary.deleted=$true; $deletedRejected++ }
      Append-CleanJsonLine $rejectedPath $summary
      $events += $summary
      continue
    }
    $mergeOut=@(& powershell -NoProfile -ExecutionPolicy Bypass -File 'operations/compact_memory_intake/merge_compact_memory_intake_queue_v1.ps1' -PacketPath $file.FullName -ProcessLimit 1 *>&1 | ForEach-Object { [string]$_ })
    $mergeExit=$LASTEXITCODE
    $mergeStatus=($mergeOut | Where-Object { $_ -match '^MERGE_QUEUE_STATUS=' } | Select-Object -Last 1) -replace '^MERGE_QUEUE_STATUS=',''
    $mergeProof=($mergeOut | Where-Object { $_ -match '^MERGE_QUEUE_PROOF=' } | Select-Object -Last 1) -replace '^MERGE_QUEUE_PROOF=',''
    $event=Packet-Summary $file.FullName 'ACCEPT_MERGE' ('merge_status='+$mergeStatus)
    $event.merge_exit=$mergeExit; $event.merge_status=$mergeStatus; $event.merge_proof=$mergeProof; $event.merge_output_tail=@($mergeOut | Select-Object -Last 8)
    if($mergeExit -eq 0 -and $mergeStatus -eq 'PASS_MULTI_SOURCE_COMPACT_MEMORY_MERGE_QUEUE_V1'){
      $accepted++; $processed++; $event.deleted=(-not(Test-Path -LiteralPath $file.FullName)); $mergeProofs += $mergeProof
      Append-CleanJsonLine $processedSummaryPath $event
    } else {
      $rejected++; Append-CleanJsonLine $rejectedPath $event
    }
    $events += $event
  }
  $after=Get-ActiveMemoryState
  $out=[ordered]@{
    schema='memory_commit_controller_v1_proof'
    status='PASS_MEMORY_COMMIT_DRAIN_AGENTLIFE_V1'
    action='DrainAgentLife'
    reason=$Reason
    run_id=$runId
    queue_root=$QueueRoot
    queue_before=@($packets).Count
    queue_after=@(Get-QueuePackets $QueueRoot 0).Count
    accepted_count=$accepted
    rejected_count=$rejected
    deleted_rejected_count=$deletedRejected
    processed_count=$processed
    merge_proofs=@($mergeProofs)
    active_memory_before=$before
    active_memory_after=$after
    active_memory_changed=($($before.files | ConvertTo-Json -Depth 20) -ne $($after.files | ConvertTo-Json -Depth 20))
    events=@($events)
    created_at=(Get-Date).ToString('o')
    retention=[ordered]@{ rejected_full_packets_deleted=($DeleteRejected.IsPresent -or $Reason -eq 'SelfTestRejectDelete'); processed_summaries_path=$processedSummaryPath; rejected_metrics_path=$rejectedPath; full_processed_packet_retention='existing_merge_processed_retention_not_yet_pruned' }
  }
  Write-CleanJson $proofPath $out 60
  Write-Host "MEMORY_COMMIT_STATUS=$($out.status)"
  Write-Host "ACCEPTED_COUNT=$accepted"
  Write-Host "REJECTED_COUNT=$rejected"
  Write-Host "QUEUE_AFTER=$($out.queue_after)"
  Write-Host "ACTIVE_MEMORY_CHANGED=$($out.active_memory_changed)"
  Write-Host "MEMORY_COMMIT_PROOF=$proofPath"
  return $out
}

function Invoke-PruneProcessedAgentLife {
  New-Item -ItemType Directory -Force -Path $RunRoot | Out-Null
  $summaryPath=Join-Path $RunRoot 'processed_retention_summary.jsonl'
  $processedRoot='.runtime/compact_memory_intake_v1/processed'
  $beforeFiles=@()
  if(Test-Path -LiteralPath $processedRoot){ $beforeFiles=@(Get-ChildItem -LiteralPath $processedRoot -Recurse -File -Filter '*.processed' -ErrorAction SilentlyContinue) }
  $deleted=0; $kept=0; $events=@()
  foreach($f in $beforeFiles){
    $packet=Read-JsonSafe $f.FullName
    $summary=[ordered]@{ file=$f.FullName; name=$f.Name; bytes=$f.Length; deleted=$false; reason='not_agentlife_or_bad_json'; source_kind=$null; source_id=$null; atom_count=0; timestamp=(Get-Date).ToString('o') }
    if($packet -and $packet.source_kind -eq 'AgentLife'){
      $summary.source_kind=$packet.source_kind; $summary.source_id=$packet.source_id; $summary.atom_count=@($packet.atoms).Count; $summary.reason='processed_agentlife_full_packet_replaced_by_compact_summary'
      Append-CleanJsonLine $summaryPath $summary
      Remove-Item -LiteralPath $f.FullName -Force
      $summary.deleted=$true
      $deleted++
    } else {
      $kept++
    }
    $events += $summary
  }
  $afterFiles=@()
  if(Test-Path -LiteralPath $processedRoot){ $afterFiles=@(Get-ChildItem -LiteralPath $processedRoot -Recurse -File -Filter '*.processed' -ErrorAction SilentlyContinue) }
  $batchPacketRoot=Join-Path $RunRoot 'batch_packets'
  $batchBefore=@()
  if(Test-Path -LiteralPath $batchPacketRoot){ $batchBefore=@(Get-ChildItem -LiteralPath $batchPacketRoot -File -Filter 'agentlife_batch_*.json' -ErrorAction SilentlyContinue) }
  $batchDeleted=0
  foreach($bf in $batchBefore){
    $summary=[ordered]@{ file=$bf.FullName; name=$bf.Name; bytes=$bf.Length; deleted=$true; reason='combined_agentlife_batch_packet_replaced_by_merge_proof_and_processed_summary'; timestamp=(Get-Date).ToString('o') }
    Append-CleanJsonLine $summaryPath $summary
    Remove-Item -LiteralPath $bf.FullName -Force
    $batchDeleted++
  }
  $batchAfter=@()
  if(Test-Path -LiteralPath $batchPacketRoot){ $batchAfter=@(Get-ChildItem -LiteralPath $batchPacketRoot -File -Filter 'agentlife_batch_*.json' -ErrorAction SilentlyContinue) }
  $proof=[ordered]@{ schema='memory_commit_processed_retention_prune_v1'; status='PASS_MEMORY_COMMIT_PROCESSED_AGENTLIFE_RETENTION_PRUNE_V1'; processed_root=$processedRoot; before_count=@($beforeFiles).Count; after_count=@($afterFiles).Count; deleted_count=$deleted; kept_count=$kept; batch_packet_root=$batchPacketRoot; batch_packet_before_count=@($batchBefore).Count; batch_packet_after_count=@($batchAfter).Count; batch_packet_deleted_count=$batchDeleted; summary_path=$summaryPath; events=@($events); created_at=(Get-Date).ToString('o') }
  $proofPath=Join-Path $RunRoot ('processed_retention_prune_'+(Get-Date -Format 'yyyyMMdd_HHmmss')+'.json')
  Write-CleanJson $proofPath $proof 60
  Write-Host "MEMORY_COMMIT_RETENTION_STATUS=$($proof.status)"
  Write-Host "PROCESSED_AGENTLIFE_BEFORE=$($proof.before_count)"
  Write-Host "PROCESSED_AGENTLIFE_AFTER=$($proof.after_count)"
  Write-Host "DELETED_COUNT=$deleted"
  Write-Host "RETENTION_PROOF=$proofPath"
  return $proof
}

function Invoke-SchoolQualityAudit([string]$Dir){
  if(-not(Test-Path -LiteralPath $Dir)){ throw "SCHOOL_RUN_DIR_MISSING:$Dir" }
  $readyFiles=@(Get-ChildItem -LiteralPath $Dir -Recurse -File -Filter '*.READY.jsonl' -ErrorAction SilentlyContinue)
  $sample=@(); $topics=@{}; $claims=@{}; $depths=@{}; $sourceMissing=0; $total=0
  foreach($f in $readyFiles){
    foreach($line in @(Get-Content -LiteralPath $f.FullName -ErrorAction SilentlyContinue)){
      if([string]::IsNullOrWhiteSpace($line)){ continue }
      try { $o=$line | ConvertFrom-Json } catch { continue }
      $total++
      $topic=[string]$o.topic_key; if(-not $topics.ContainsKey($topic)){ $topics[$topic]=0 }; $topics[$topic]++
      $depth=[string]$o.depth_level; if(-not $depths.ContainsKey($depth)){ $depths[$depth]=0 }; $depths[$depth]++
      $claim=[string]$o.claim; if(-not $claims.ContainsKey($claim)){ $claims[$claim]=0 }; $claims[$claim]++
      if($o.source_missing -eq $true){ $sourceMissing++ }
      if($sample.Count -lt 20){ $sample += [ordered]@{ file=$f.Name; candidate_id=$o.candidate_id; topic_key=$topic; depth_level=$o.depth_level; target_depth=$o.target_depth; source_missing=$o.source_missing; claim=$claim; expected_behavior=$o.expected_behavior } }
    }
  }
  $dupClaims=0; foreach($v in $claims.Values){ if($v -gt 1){ $dupClaims += $v } }
  $quality='UNKNOWN'
  if($total -gt 0){
    $oneTopic=($topics.Keys.Count -eq 1)
    $allDepth0=($depths.Keys.Count -eq 1 -and $depths.ContainsKey('0'))
    if($oneTopic -and $allDepth0){ $quality='LOW_VARIETY_VALID_SCAFFOLD' }
    elseif($sourceMissing -gt 0){ $quality='MIXED_SOURCE_ISSUES' }
    else { $quality='VALID_WITH_SOME_VARIETY' }
  }
  $proof=[ordered]@{ schema='school_atom_quality_audit_v1'; status='PASS_SCHOOL_ATOM_QUALITY_AUDIT_V1'; quality_classification=$quality; school_run_dir=$Dir; ready_file_count=@($readyFiles).Count; candidate_count=$total; topic_distribution=$topics; depth_distribution=$depths; duplicate_claim_instances=$dupClaims; unique_claims=$claims.Keys.Count; source_missing_count=$sourceMissing; sample=@($sample); conclusion=if($quality -eq 'LOW_VARIETY_VALID_SCAFFOLD'){'School produced schema-valid atoms, but this run is low-variety scaffold/curriculum ladder material, not strong domain learning.'}else{'School produced usable atoms with the classification shown.'}; created_at=(Get-Date).ToString('o') }
  $path=Join-Path $RunRoot ('school_quality_audit_'+(Get-Date -Format 'yyyyMMdd_HHmmss')+'.json')
  Write-CleanJson $path $proof 80
  Write-Host "SCHOOL_QUALITY_STATUS=$($proof.status)"
  Write-Host "QUALITY_CLASSIFICATION=$($proof.quality_classification)"
  Write-Host "CANDIDATE_COUNT=$($proof.candidate_count)"
  Write-Host "TOPICS=$($proof.topic_distribution.Keys.Count)"
  Write-Host "DEPTHS=$($proof.depth_distribution.Keys -join ',')"
  Write-Host "SCHOOL_QUALITY_PROOF=$path"
  return $proof
}
if($Action -eq 'Status'){
  $q=@(Get-QueuePackets $QueueRoot 0)
  $out=[ordered]@{ schema='memory_commit_controller_v1_status'; status='PASS_MEMORY_COMMIT_STATUS_V1'; busy=Test-MemoryPathBusy; queue_root=$QueueRoot; queue_count=$q.Count; queue_bytes=(($q|Measure-Object Length -Sum).Sum); active_memory=Get-ActiveMemoryState; created_at=(Get-Date).ToString('o') }
  Write-CleanJson (Join-Path $RunRoot 'status_latest.json') $out 40
  Write-Host "MEMORY_COMMIT_STATUS=$($out.status)"
  Write-Host "QUEUE_COUNT=$($out.queue_count)"
  Write-Host "QUEUE_BYTES=$($out.queue_bytes)"
  Write-Host "BUSY=$($out.busy.busy)"
  return
}
if($Action -eq 'AuditSchoolQuality'){ Invoke-SchoolQualityAudit $SchoolRunDir | Out-Null; return }
if($Action -eq 'PruneProcessedAgentLife'){ Invoke-PruneProcessedAgentLife | Out-Null; return }
if($Action -eq 'BatchDrainAgentLife'){ Invoke-BatchDrainAgentLife $MaxPackets $Action | Out-Null; return }
if($Action -eq 'SelfTestRejectDelete'){ Invoke-SelfTestRejectDelete | Out-Null; return }
if($Action -eq 'DrainAgentLife' -or $Action -eq 'PostSchoolComplete'){ if($BatchMerge){ Invoke-BatchDrainAgentLife $MaxPackets $Action | Out-Null } else { Invoke-DrainAgentLife $MaxPackets $Action | Out-Null }; return }
