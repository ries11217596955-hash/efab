param(
  [string[]]$PacketPath = @(),
  [int]$ProcessLimit = 10,
  [string]$PolicyPath = "operations/compact_memory_intake/multi_source_compact_memory_intake_policy.json",
  [string]$MemoryRoot = ".runtime/active_compact_semantic_memory_v1"
)
$ErrorActionPreference='Stop'
$repoRoot=(git rev-parse --show-toplevel).Trim(); Set-Location $repoRoot
function EnsureDir($Path){ if(-not (Test-Path $Path)){ New-Item -ItemType Directory -Force -Path $Path | Out-Null } }
function WriteJson($Path,$Obj,$Depth=60){ $d=Split-Path $Path -Parent; if($d){ EnsureDir $d }; $Obj|ConvertTo-Json -Depth $Depth|Set-Content -LiteralPath $Path -Encoding UTF8 }
function ShaFile($Path){ if(-not (Test-Path $Path)){ return $null }; (Get-FileHash -Algorithm SHA256 $Path).Hash }
function MemState($Root){
  $manifestPath=Join-Path $Root 'manifest.json'
  $cellsPath=Join-Path $Root 'cells.jsonl'
  $indexPath=Join-Path $Root 'index.json'
  if(-not (Test-Path $manifestPath)){ throw "MEMORY_MANIFEST_MISSING:$Root" }
  $m=Get-Content $manifestPath -Raw|ConvertFrom-Json
  return [ordered]@{
    root=$Root
    run_id=$m.run_id
    status=$m.status
    cell_count=[int]$m.cell_count
    merged_count=[int]$m.merged_count
    total_memory_bytes=[int64]$m.total_memory_bytes
    cells_sha256=ShaFile $cellsPath
    index_sha256=ShaFile $indexPath
    runtime_ready=$m.runtime_ready
  }
}
function Slug($s){ (([string]$s) -replace '[^A-Za-z0-9_.-]','_') }
function QueuePackets($Policy,$Limit){
  $queueRoot=[string]$Policy.runtime_queue_root
  if(-not (Test-Path $queueRoot)){ return @() }
  return @(Get-ChildItem $queueRoot -File -Filter *.json | Sort-Object LastWriteTime | Select-Object -First $Limit | ForEach-Object{ $_.FullName })
}
function PacketToAtoms($Packet,$PacketFile){
  $out=@()
  $sourceKind=[string]$Packet.source_kind
  $sourceId=[string]$Packet.source_id
  $sourcePrefix="${sourceKind}:${sourceId}"
  foreach($a in @($Packet.atoms)){
    $topic=[string]$a.topic
    $id=[string]$a.id
    $summary=[string]$a.behavior_use_hint
    if([string]::IsNullOrWhiteSpace($summary)){ $summary=[string]$a.summary }
    if([string]::IsNullOrWhiteSpace($summary)){ $summary="Knowledge packet atom from $sourcePrefix for topic $topic." }
    $out += [ordered]@{
      concept_key=("intake-$($sourceKind.ToLowerInvariant())-$topic-$id")
      label=$topic
      definition=$summary
      kind='multi_source_intake_atom'
      properties=@("source_kind=$sourceKind","source_id=$sourceId","packet_file=$PacketFile","quality_score=$($a.quality_score)","novelty_score=$($a.novelty_score)","level=$($a.level)")
      relations=@("source_packet:$sourcePrefix","topic:$topic")
      uses=@("Use this knowledge only when selected path/task topic matches $topic.","This atom supports execution; it must not override route/path selection.")
      source_fingerprint=("${sourcePrefix}:${id}")
    }
  }
  return @($out)
}
if($PacketPath.Count -eq 1 -and ([string]$PacketPath[0]).Contains(',')){
  $PacketPath = @(([string]$PacketPath[0]).Split(',') | ForEach-Object { $_.Trim() } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
}
if($ProcessLimit -lt 1){ throw 'PROCESS_LIMIT_MUST_BE_POSITIVE' }
if(-not (Test-Path $PolicyPath)){ throw "POLICY_MISSING:$PolicyPath" }
$policy=Get-Content $PolicyPath -Raw|ConvertFrom-Json
$runId="merge_queue_$(Get-Date -Format yyyyMMdd_HHmmss)"
$root='.runtime/compact_memory_intake_v1'
$runRoot=Join-Path $root "merge_runs/$runId"
$checkpointRoot=Join-Path $root "checkpoints/$runId"
$processedRoot=Join-Path $root 'processed'
$failedRoot=Join-Path $root 'failed'
EnsureDir $runRoot; EnsureDir $checkpointRoot; EnsureDir $processedRoot; EnsureDir $failedRoot
$lockPath=Join-Path $root 'MERGE_QUEUE.lock.json'
if(Test-Path $lockPath){ throw "MERGE_QUEUE_LOCK_EXISTS:$lockPath" }
$lock=[ordered]@{ schema='compact_memory_merge_queue_lock_v1'; run_id=$runId; pid=$PID; created_at=(Get-Date).ToString('o'); memory_root=$MemoryRoot }
WriteJson $lockPath $lock 20
$status='STARTED'
$blockers=@()
$actions=@()
try {
  $before=MemState $MemoryRoot
  $checkpointMemory=Join-Path $checkpointRoot 'active_memory_before'
  Copy-Item -Path $MemoryRoot -Destination $checkpointMemory -Recurse -Force
  $actions += "CHECKPOINT_CREATED:$checkpointMemory"
  $packetFiles=@()
  $queueRootFull=$null
  if(Test-Path ([string]$policy.runtime_queue_root)){ $queueRootFull=(Resolve-Path ([string]$policy.runtime_queue_root)).Path }
  if($PacketPath.Count -gt 0){ $packetFiles=@($PacketPath | ForEach-Object { (Resolve-Path $_).Path }) } else { $packetFiles=QueuePackets $policy $ProcessLimit }
  if($packetFiles.Count -lt 1){
    $status='PASS_MERGE_QUEUE_NO_PACKETS_V1'
    $result=[ordered]@{ schema='compact_memory_merge_queue_result_v1'; status=$status; run_id=$runId; memory_before=$before; memory_after=$before; packet_count=0; digest_atom_count=0; actions=$actions; blockers=$blockers; lock_removed=$false; created_at=(Get-Date).ToString('o') }
    WriteJson (Join-Path $runRoot 'COMPACT_MEMORY_MERGE_QUEUE_RESULT_V1.json') $result 80
    return
  }
  $digestAtoms=@()
  $packetSummaries=@()
  foreach($pf in $packetFiles){
    $validationOut=@(& powershell -NoProfile -ExecutionPolicy Bypass -File operations/compact_memory_intake/validate_compact_memory_packet_v1.ps1 -PacketPath $pf -PolicyPath $PolicyPath *>&1 | ForEach-Object{[string]$_})
    $v=($validationOut|Where-Object{$_ -match '^PACKET_VALIDATION_STATUS='}|Select-Object -Last 1) -replace '^PACKET_VALIDATION_STATUS=',''
    if($v -ne 'PASS_COMPACT_MEMORY_KNOWLEDGE_PACKET_V1'){ throw "PACKET_VALIDATION_NOT_PASS:${pf}:${v}" }
    $packet=Get-Content $pf -Raw|ConvertFrom-Json
    $atoms=PacketToAtoms $packet $pf
    $digestAtoms += $atoms
    $packetSummaries += [ordered]@{ path=$pf; source_kind=$packet.source_kind; source_id=$packet.source_id; packet_atoms=@($packet.atoms).Count; digest_atoms=@($atoms).Count }
  }
  if($digestAtoms.Count -lt 1){ throw 'NO_DIGEST_ATOMS_FROM_PACKETS' }
  $digestInput=Join-Path $runRoot 'digest_atoms.jsonl'
  ($digestAtoms|ForEach-Object{ $_|ConvertTo-Json -Depth 30 -Compress }) -join "`n" | Set-Content -LiteralPath $digestInput -Encoding UTF8
  $budget=[int64]([Math]::Max([double]($before.total_memory_bytes + 5000000),[double]50000000))
  $absorbOut=@(& powershell -NoProfile -ExecutionPolicy Bypass -File operations/school/digestion/absorb_atom_file_via_digest_pipeline_v1.ps1 -InputPath $digestInput -MemoryRoot $MemoryRoot -ValidationTier Fast -SizeBudgetBytes $budget -DeleteOriginalRaw *>&1 | ForEach-Object{[string]$_})
  $absorbStatus=($absorbOut|Where-Object{$_ -match '^FILE_ATOM_ABSORPTION_STATUS='}|Select-Object -Last 1) -replace '^FILE_ATOM_ABSORPTION_STATUS=',''
  $absorbProof=($absorbOut|Where-Object{$_ -match '^PROOF_PATH='}|Select-Object -Last 1) -replace '^PROOF_PATH=',''
  if($absorbStatus -ne 'PASS_FILE_ATOM_ABSORPTION_PIPELINE_V1'){ throw "ABSORPTION_NOT_PASS:$absorbStatus" }
  $after=MemState $MemoryRoot
  if($after.cells_sha256 -eq $before.cells_sha256){ throw 'MEMORY_HASH_UNCHANGED_AFTER_MERGE' }
  foreach($pf in $packetFiles){
    $dest=Join-Path $processedRoot ((Split-Path $pf -Leaf) + ".$runId.processed")
    Copy-Item -LiteralPath $pf -Destination $dest -Force
      $removeQueuePacket=$false
      if($queueRootFull){
        $packetFull=(Resolve-Path $pf).Path
        if($packetFull.StartsWith($queueRootFull,[System.StringComparison]::OrdinalIgnoreCase)){ $removeQueuePacket=$true }
      } elseif($pf -like (Join-Path ([string]$policy.runtime_queue_root) '*')){
        $removeQueuePacket=$true
      }
      if($removeQueuePacket){ Remove-Item -LiteralPath $pf -Force }
  }
  $status='PASS_MULTI_SOURCE_COMPACT_MEMORY_MERGE_QUEUE_V1'
  $result=[ordered]@{
    schema='compact_memory_merge_queue_result_v1'
    status=$status
    run_id=$runId
    memory_before=$before
    memory_after=$after
    packet_count=$packetFiles.Count
    digest_atom_count=$digestAtoms.Count
    packet_summaries=@($packetSummaries)
    checkpoint_path=$checkpointMemory
    absorption_status=$absorbStatus
    absorption_proof=$absorbProof
    processed_root=$processedRoot
    rollback_performed=$false
    actions=@($actions)
    blockers=@($blockers)
    boundary='Multi-source packets merge through lock, checkpoint, existing file atom absorption pipeline, and proof. Sources do not mutate active memory directly.'
    created_at=(Get-Date).ToString('o')
  }
  WriteJson (Join-Path $runRoot 'COMPACT_MEMORY_MERGE_QUEUE_RESULT_V1.json') $result 100
  Write-Host "MERGE_QUEUE_STATUS=$status"
  Write-Host "MERGE_QUEUE_PROOF=$(Join-Path $runRoot 'COMPACT_MEMORY_MERGE_QUEUE_RESULT_V1.json')"
  Write-Host "MERGED_PACKETS=$($packetFiles.Count)"
  Write-Host "DIGEST_ATOMS=$($digestAtoms.Count)"
  Write-Host "MEMORY_CELLS_BEFORE=$($before.cell_count)"
  Write-Host "MEMORY_CELLS_AFTER=$($after.cell_count)"
  Write-Host "MEMORY_HASH_CHANGED=$($after.cells_sha256 -ne $before.cells_sha256)"
} catch {
  $err=$_.Exception.Message
  $blockers += $err
  if(Test-Path $checkpointMemory){
    if(Test-Path $MemoryRoot){ Remove-Item $MemoryRoot -Recurse -Force }
    Copy-Item -Path $checkpointMemory -Destination $MemoryRoot -Recurse -Force
    $actions += 'ROLLBACK_RESTORED_CHECKPOINT'
  }
  $afterRollback=MemState $MemoryRoot
  $result=[ordered]@{ schema='compact_memory_merge_queue_result_v1'; status='FAIL_MULTI_SOURCE_COMPACT_MEMORY_MERGE_QUEUE_ROLLED_BACK_V1'; run_id=$runId; memory_before=$before; memory_after=$afterRollback; blockers=@($blockers); actions=@($actions); rollback_performed=$true; checkpoint_path=$checkpointMemory; created_at=(Get-Date).ToString('o') }
  WriteJson (Join-Path $runRoot 'COMPACT_MEMORY_MERGE_QUEUE_RESULT_V1.json') $result 100
  Write-Host "MERGE_QUEUE_STATUS=$($result.status)"
  Write-Host "MERGE_QUEUE_PROOF=$(Join-Path $runRoot 'COMPACT_MEMORY_MERGE_QUEUE_RESULT_V1.json')"
  Write-Host "MERGE_QUEUE_ERROR=$err"
  exit 1
} finally {
  if(Test-Path $lockPath){ Remove-Item $lockPath -Force }
}
