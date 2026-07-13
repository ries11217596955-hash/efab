param(
  [string[]]$AllowedSourceKinds = @('AgentLife'),
  [int]$ProcessLimit = 5,
  [string]$PolicyPath = 'operations/compact_memory_intake/multi_source_compact_memory_intake_policy.json',
  [int]$MergeTimeoutSeconds = 300
)
$ErrorActionPreference='Stop'
$repoRoot=(git rev-parse --show-toplevel).Trim(); Set-Location $repoRoot
function EnsureDir($Path){ if(-not (Test-Path $Path)){ New-Item -ItemType Directory -Force -Path $Path | Out-Null } }
function WriteJson($Path,$Obj,$Depth=80){ $d=Split-Path $Path -Parent; if($d){ EnsureDir $d }; $Obj|ConvertTo-Json -Depth $Depth|Set-Content -LiteralPath $Path -Encoding UTF8 }
function ReadPacketKind($Path){ try { $p=Get-Content $Path -Raw|ConvertFrom-Json; return [string]$p.source_kind } catch { return $null } }
function StopProcessTree([int]$ProcessId){
  foreach($child in @(Get-CimInstance Win32_Process -ErrorAction SilentlyContinue | Where-Object { $_.ParentProcessId -eq $ProcessId })){
    StopProcessTree ([int]$child.ProcessId)
  }
  $p=Get-Process -Id $ProcessId -ErrorAction SilentlyContinue
  if($p){ Stop-Process -Id $ProcessId -Force -ErrorAction SilentlyContinue }
}
function InvokeMergeQueueChild($PacketPath,$PolicyPath,$RunRoot,[int]$TimeoutSeconds){
  $slug=Slug (Split-Path $PacketPath -Leaf)
  $stdout=Join-Path $RunRoot ("merge_child_${slug}.stdout.txt")
  $stderr=Join-Path $RunRoot ("merge_child_${slug}.stderr.txt")
  $args=@('-NoProfile','-ExecutionPolicy','Bypass','-File','operations/compact_memory_intake/merge_compact_memory_intake_queue_v1.ps1','-PacketPath',[string]$PacketPath,'-ProcessLimit','1','-PolicyPath',[string]$PolicyPath)
  $proc=Start-Process -FilePath 'powershell.exe' -ArgumentList $args -WorkingDirectory (Get-Location).Path -RedirectStandardOutput $stdout -RedirectStandardError $stderr -PassThru -WindowStyle Hidden
  $done=$proc.WaitForExit([Math]::Max(1,$TimeoutSeconds)*1000)
  if(-not $done){
    StopProcessTree ([int]$proc.Id)
    $out=@()
    if(Test-Path $stdout){ $out += @(Get-Content $stdout -ErrorAction SilentlyContinue) }
    if(Test-Path $stderr){ $out += @(Get-Content $stderr -ErrorAction SilentlyContinue) }
    return [ordered]@{ timed_out=$true; exit_code=$null; stdout_path=$stdout; stderr_path=$stderr; output_tail=@($out|Select-Object -Last 60) }
  }
  $out=@()
  if(Test-Path $stdout){ $out += @(Get-Content $stdout -ErrorAction SilentlyContinue) }
  if(Test-Path $stderr){ $out += @(Get-Content $stderr -ErrorAction SilentlyContinue) }
  return [ordered]@{ timed_out=$false; exit_code=$proc.ExitCode; stdout_path=$stdout; stderr_path=$stderr; output_tail=@($out|Select-Object -Last 60) }
}
if($ProcessLimit -lt 1){ throw 'QUEUE_MAINTENANCE_PROCESS_LIMIT_MUST_BE_POSITIVE' }
if($MergeTimeoutSeconds -lt 1){ throw 'QUEUE_MAINTENANCE_MERGE_TIMEOUT_MUST_BE_POSITIVE' }
if(-not (Test-Path $PolicyPath)){ throw "POLICY_MISSING:$PolicyPath" }
$policy=Get-Content $PolicyPath -Raw|ConvertFrom-Json
$runId="queue_maintenance_$(Get-Date -Format yyyyMMdd_HHmmss)"
$runRoot=".runtime/compact_memory_intake_v1/maintenance_runs/$runId"
EnsureDir $runRoot
$lockPath='.runtime/compact_memory_intake_v1/MERGE_QUEUE.lock.json'
$queueRoot=[string]$policy.runtime_queue_root
$actions=@(); $processed=@(); $skipped=@(); $blockers=@()
$status='STARTED'
if(Test-Path $lockPath){
  $status='SKIPPED_QUEUE_MAINTENANCE_MERGE_LOCK_EXISTS'
  $blockers += 'MERGE_QUEUE_LOCK_EXISTS'
} elseif(-not (Test-Path $queueRoot)){
  $status='SKIPPED_QUEUE_MAINTENANCE_QUEUE_MISSING'
  $blockers += 'QUEUE_ROOT_MISSING'
} else {
  $candidates=@()
  foreach($f in @(Get-ChildItem $queueRoot -File -Filter *.json | Sort-Object LastWriteTime -Descending)){
    $kind=ReadPacketKind $f.FullName
    if(@($AllowedSourceKinds) -contains $kind){ $candidates += [ordered]@{ path=$f.FullName; source_kind=$kind } }
    else { $skipped += [ordered]@{ path=$f.FullName; source_kind=$kind; reason='SOURCE_KIND_NOT_ALLOWED_FOR_MAINTENANCE' } }
    if($candidates.Count -ge $ProcessLimit){ break }
  }
  if($candidates.Count -lt 1){
    $status='SKIPPED_QUEUE_MAINTENANCE_NO_MATCHING_PACKETS'
  } else {
    foreach($c in $candidates){
      if(Test-Path $lockPath){ $blockers += 'MERGE_QUEUE_LOCK_APPEARED_DURING_MAINTENANCE'; break }
      $child=InvokeMergeQueueChild $c.path $PolicyPath $runRoot $MergeTimeoutSeconds
      $out=@($child.output_tail | ForEach-Object{[string]$_})
      $mergeStatus=($out|Where-Object{$_ -match '^MERGE_QUEUE_STATUS='}|Select-Object -Last 1) -replace '^MERGE_QUEUE_STATUS=',''
      $mergeProof=($out|Where-Object{$_ -match '^MERGE_QUEUE_PROOF='}|Select-Object -Last 1) -replace '^MERGE_QUEUE_PROOF=',''
      if($child.timed_out){ $mergeStatus='TIMEOUT_COMPACT_MEMORY_MERGE_QUEUE_CHILD' }
      elseif([int]$child.exit_code -ne 0 -and [string]::IsNullOrWhiteSpace($mergeStatus)){ $mergeStatus="EXIT_$($child.exit_code)" }
      $processed += [ordered]@{ packet_path=$c.path; source_kind=$c.source_kind; merge_status=$mergeStatus; merge_proof=$mergeProof; timed_out=$child.timed_out; exit_code=$child.exit_code; stdout_path=$child.stdout_path; stderr_path=$child.stderr_path; output_tail=@($out) }
      $actions += "MERGE:$($c.source_kind):$mergeStatus"
      if($mergeStatus -ne 'PASS_MULTI_SOURCE_COMPACT_MEMORY_MERGE_QUEUE_V1'){
        $blockers += "MERGE_NOT_PASS:$mergeStatus"
        break
      }
    }
    if($blockers.Count -gt 0){ $status='FAIL_COMPACT_MEMORY_QUEUE_MAINTENANCE_V1' }
    else { $status='PASS_COMPACT_MEMORY_QUEUE_MAINTENANCE_V1' }
  }
}
$result=[ordered]@{
  schema='compact_memory_queue_maintenance_result_v1'
  status=$status
  run_id=$runId
  allowed_source_kinds=@($AllowedSourceKinds)
  process_limit=$ProcessLimit
  merge_timeout_seconds=$MergeTimeoutSeconds
  queue_root=$queueRoot
  processed_count=@($processed).Count
  processed=@($processed)
  skipped=@($skipped)
  actions=@($actions)
  blockers=@($blockers)
  boundary='Queue maintenance is synchronous, bounded, and uses merge queue only. It does not run as a daemon and does not mutate active memory outside merge queue.'
  created_at=(Get-Date).ToString('o')
}
$proofPath=Join-Path $runRoot 'COMPACT_MEMORY_QUEUE_MAINTENANCE_RESULT_V1.json'
WriteJson $proofPath $result 100
Write-Host "QUEUE_MAINTENANCE_STATUS=$($result.status)"
Write-Host "QUEUE_MAINTENANCE_PROOF=$proofPath"
Write-Host "QUEUE_MAINTENANCE_PROCESSED=$($result.processed_count)"
Write-Host "QUEUE_MAINTENANCE_ALLOWED_SOURCES=$($AllowedSourceKinds -join ',')"
if($result.blockers.Count -gt 0){ Write-Host "QUEUE_MAINTENANCE_BLOCKERS=$($result.blockers -join ',')" }
if($status -like 'FAIL_*'){ exit 1 }
