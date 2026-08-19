param(
  [string[]]$AllowedSourceKinds = @('AgentLife'),
  [int]$ProcessLimit = 5,
  [string]$PolicyPath = 'operations/compact_memory_intake/multi_source_compact_memory_intake_policy.json',
  [int]$MergeTimeoutSeconds = 300,
  [string]$MemoryRoot = '.runtime/active_compact_semantic_memory_v1'
)
$ErrorActionPreference='Stop'
$repoRoot=(git rev-parse --show-toplevel).Trim(); Set-Location $repoRoot
function EnsureDir($Path){ if(-not (Test-Path $Path)){ New-Item -ItemType Directory -Force -Path $Path | Out-Null } }
function WriteJson($Path,$Obj,$Depth=80){ $d=Split-Path $Path -Parent; if($d){ EnsureDir $d }; $Obj|ConvertTo-Json -Depth $Depth|Set-Content -LiteralPath $Path -Encoding UTF8 }
function ReadPacketKind($Path){ try { $p=Get-Content $Path -Raw|ConvertFrom-Json; return [string]$p.source_kind } catch { return $null } }
function ReadPacketAdmissionState($Path){ try { $p=Get-Content $Path -Raw|ConvertFrom-Json; return [string]$p.admission_state } catch { return $null } }
function WriteJsonNoBom([string]$Path,$Obj,[int]$Depth=60){
  $dir=Split-Path $Path -Parent;if($dir){New-Item -ItemType Directory -Force -Path $dir|Out-Null}
  $json=$Obj|ConvertTo-Json -Depth $Depth;$lines=@($json -split "`r?`n"|ForEach-Object{$_.TrimEnd()});$clean=($lines -join "`n")+"`n";[IO.File]::WriteAllText([IO.Path]::GetFullPath($Path),$clean,[Text.UTF8Encoding]::new($false))
}
function Get-AgentLifeRejectReasonCode($Decision){
  $txt=(([string]$Decision.reason+' '+[string]$Decision.explanation+' '+[string]$Decision.rejection_explanation).ToLowerInvariant())
  if($txt -match 'duplicate|already'){return 'DUPLICATE'}
  if($txt -match 'novel'){return 'LOW_NOVELTY'}
  if($txt -match 'contradict'){return 'CONTRADICTION'}
  if($txt -match 'evidence|proof|source|unsupported'){return 'UNSUPPORTED'}
  if($txt -match 'stale'){return 'STALE'}
  if($txt -match 'malform|schema|invalid'){return 'MALFORMED'}
  return 'REJECTED_BY_MEMORY_GATE'
}
function Write-AgentLifeRejectFeedback([string]$ContextPath,$Packet,$Decision){
  if([string]::IsNullOrWhiteSpace($ContextPath)){return [ordered]@{status='NO_FEEDBACK_TARGET'}}
  $full=[IO.Path]::GetFullPath($ContextPath);$repo=[IO.Path]::GetFullPath((Get-Location).Path).TrimEnd('\\');$runtime=(Join-Path $repo '.runtime').TrimEnd('\\')
  if(-not $full.StartsWith($runtime,[StringComparison]::OrdinalIgnoreCase) -or [IO.Path]::GetFileName($full) -ne 'life_working_memory_context.json'){return [ordered]@{status='REFUSED_FEEDBACK_TARGET_OUTSIDE_LIFE_CONTEXT'}}
  if(-not(Test-Path -LiteralPath $full -PathType Leaf)){return [ordered]@{status='FEEDBACK_TARGET_ABSENT'}}
  try{$ctx=Get-Content -Raw -LiteralPath $full|ConvertFrom-Json}catch{return [ordered]@{status='FEEDBACK_TARGET_PARSE_FAILED'}}
  if($ctx.status -ne 'PASS_LIFE_WORKING_MEMORY_V1'){return [ordered]@{status='FEEDBACK_TARGET_STATUS_MISMATCH'}}
  $code=Get-AgentLifeRejectReasonCode $Decision
  $retry=if($code -eq 'DUPLICATE'){'only_with_new_delta_or_evidence'}elseif($code -in @('UNSUPPORTED','CONTRADICTION')){'only_after_new_evidence_or_resolved_contradiction'}elseif($code -eq 'LOW_NOVELTY'){'only_if_material_novelty_is_added'}else{'only_after_material_change'}
  $cand=$Packet.agentlife_candidate;$fingerprint=([string]$cand.candidate_id+'|'+[string]$cand.concept_key+'|'+[string]$cand.label)
  $item=[ordered]@{fingerprint=$fingerprint;reason_code=$code;reason=([string]$Decision.reason);explanation=([string]$Decision.explanation);retry_condition=$retry;created_at=(Get-Date).ToUniversalTime().ToString('o')}
  if(-not $ctx.compact_context){$ctx|Add-Member -NotePropertyName compact_context -NotePropertyValue ([pscustomobject]@{}) -Force}
  $old=@($ctx.compact_context.rejection_feedback_digest);$digest=@($old+$item);if($digest.Count -gt 20){$digest=@($digest[($digest.Count-20)..($digest.Count-1)])}
  $ctx.compact_context|Add-Member -NotePropertyName rejection_feedback_digest -NotePropertyValue $digest -Force
  $ctx.compact_context|Add-Member -NotePropertyName last_rejection_feedback -NotePropertyValue $item -Force
  WriteJsonNoBom $full $ctx 100
  return [ordered]@{status='PASS_AGENTLIFE_REJECT_FEEDBACK_V1';reason_code=$code;retry_condition=$retry;digest_count=$digest.Count}
}
function Invoke-AgentLifePendingAcceptance([string]$PacketPath,[string]$MaintenanceRunRoot){
  $packet=Get-Content -Raw -LiteralPath $PacketPath|ConvertFrom-Json
  $work=Join-Path $MaintenanceRunRoot ('agentlife_gate_'+([guid]::NewGuid().ToString('N')));New-Item -ItemType Directory -Force -Path $work|Out-Null
  $candidatePath=Join-Path $work 'candidate.json';$decisionPath=Join-Path $work 'decision.json';$finalPath=Join-Path $work 'accepted.jsonl'
  WriteJsonNoBom $candidatePath $packet.agentlife_candidate 80
  $out=@(& powershell -NoProfile -ExecutionPolicy Bypass -File 'operations/autonomous_inner_motor/invoke_memory_atom_acceptance_gate_v1.ps1' -CandidateAtomPath $candidatePath -OutputPath $decisionPath -FinalAtomPath $finalPath *>&1|ForEach-Object{[string]$_});$exit=$LASTEXITCODE
  $decision=if(Test-Path $decisionPath){Get-Content -Raw $decisionPath|ConvertFrom-Json}else{$null}
  if($decision -and [bool]$decision.absorption_allowed -and $exit -eq 0){
    $packet.admission_state='READY_AFTER_MEMORY_ATOM_GATE';$packet.boundary.merge_ready=$true;$packet.boundary.full_memory_atom_gate_required=$false
    foreach($a in @($packet.atoms)){$a.gate_decision='READY_AFTER_MEMORY_ATOM_GATE';$a.gate_reason=[string]$decision.explanation}
    $packet|Add-Member -NotePropertyName memory_atom_gate_decision -NotePropertyValue ([pscustomobject]@{decision=$decision.decision;reason=$decision.reason;explanation=$decision.explanation;absorption_allowed=$true}) -Force
    WriteJsonNoBom $PacketPath $packet 100
    Remove-Item $work -Recurse -Force -ErrorAction SilentlyContinue
    return [ordered]@{status='READY_AFTER_MEMORY_ATOM_GATE';exit_code=$exit;decision=$decision;feedback=$null;deleted=$false}
  }
  $feedback=if($decision){Write-AgentLifeRejectFeedback ([string]$packet.producer_feedback_context_path) $packet $decision}else{[ordered]@{status='NO_GATE_DECISION_FOR_FEEDBACK'}}
  Remove-Item -LiteralPath $PacketPath -Force -ErrorAction Stop
  Remove-Item $work -Recurse -Force -ErrorAction SilentlyContinue
  return [ordered]@{status='REJECTED_MEMORY_ATOM_GATE';exit_code=$exit;decision=$decision;feedback=$feedback;deleted=$true}
}
function Slug($s){ (([string]$s) -replace '[^A-Za-z0-9_.-]','_') }
function AppendJsonLine($Path,$Obj){ $d=Split-Path $Path -Parent; if($d){ EnsureDir $d }; Add-Content -LiteralPath $Path -Value ($Obj|ConvertTo-Json -Depth 40 -Compress) -Encoding UTF8 }
function InvokePacketValidation($PacketPath,$PolicyPath){
  $previousErrorActionPreference=$ErrorActionPreference
  $ErrorActionPreference='Continue'
  try {
    $out=@(& powershell -NoProfile -ExecutionPolicy Bypass -File 'operations/compact_memory_intake/validate_compact_memory_packet_v1.ps1' -PacketPath $PacketPath -PolicyPath $PolicyPath *>&1 | ForEach-Object{[string]$_})
    $exitCode=$LASTEXITCODE
  } finally {
    $ErrorActionPreference=$previousErrorActionPreference
  }
  $status=(($out|Where-Object{$_ -match '^PACKET_VALIDATION_STATUS='}|Select-Object -Last 1) -replace '^PACKET_VALIDATION_STATUS=','')
  $failureClass=(($out|Where-Object{$_ -match '^PACKET_VALIDATION_FAILURE_CLASS='}|Select-Object -Last 1) -replace '^PACKET_VALIDATION_FAILURE_CLASS=','')
  $errorCode=(($out|Where-Object{$_ -match '^PACKET_VALIDATION_ERROR_CODE='}|Select-Object -Last 1) -replace '^PACKET_VALIDATION_ERROR_CODE=','')
  if([string]::IsNullOrWhiteSpace($errorCode)){ $errorCode=(($out|Where-Object{$_ -match '^PACKET_VALIDATION_ERROR='}|Select-Object -Last 1) -replace '^PACKET_VALIDATION_ERROR=','') }
  if([string]::IsNullOrWhiteSpace($status)){ $status=if($exitCode -eq 0){'UNKNOWN'}else{'FAIL_PACKET_VALIDATION_EXCEPTION'} }
  if($status -eq 'PASS_COMPACT_MEMORY_KNOWLEDGE_PACKET_V1'){ $failureClass='NONE' } elseif([string]::IsNullOrWhiteSpace($failureClass)){ $failureClass='UNKNOWN' }
  if([string]::IsNullOrWhiteSpace($errorCode) -and $failureClass -ne 'NONE'){ $errorCode='VALIDATOR_EXECUTION_FAILED' }
  return [ordered]@{status=$status;failure_class=$failureClass;error_code=$errorCode;exit_code=$exitCode;output_tail=@($out|Select-Object -Last 20)}
}
function StopProcessTree([int]$ProcessId){
  foreach($child in @(Get-CimInstance Win32_Process -ErrorAction SilentlyContinue | Where-Object { $_.ParentProcessId -eq $ProcessId })){
    StopProcessTree ([int]$child.ProcessId)
  }
  $p=Get-Process -Id $ProcessId -ErrorAction SilentlyContinue
  if($p){ Stop-Process -Id $ProcessId -Force -ErrorAction SilentlyContinue }
}
function InvokeMergeQueueChild($PacketPath,$PolicyPath,$RunRoot,[int]$TimeoutSeconds,[string]$MemoryRoot){
  $slug=Slug (Split-Path $PacketPath -Leaf)
  $stdout=Join-Path $RunRoot ("merge_child_${slug}.stdout.txt")
  $stderr=Join-Path $RunRoot ("merge_child_${slug}.stderr.txt")
  $ownedRoots=@('.runtime/compact_memory_intake_v1/merge_runs','.runtime/compact_memory_intake_v1/checkpoints','.runtime/file_atom_absorption')
  $beforeOwned=@{}
  foreach($root in $ownedRoots){$beforeOwned[$root]=@();if(Test-Path $root){$beforeOwned[$root]=@(Get-ChildItem $root -Directory -ErrorAction SilentlyContinue|Select-Object -ExpandProperty FullName)}}
  $args=@('-NoProfile','-ExecutionPolicy','Bypass','-File','operations/compact_memory_intake/merge_compact_memory_intake_queue_v1.ps1','-PacketPath',[string]$PacketPath,'-ProcessLimit','1','-PolicyPath',[string]$PolicyPath,'-MemoryRoot',[string]$MemoryRoot)
  $proc=Start-Process -FilePath 'powershell.exe' -ArgumentList $args -WorkingDirectory (Get-Location).Path -RedirectStandardOutput $stdout -RedirectStandardError $stderr -PassThru -WindowStyle Hidden
  $done=$proc.WaitForExit([Math]::Max(1,$TimeoutSeconds)*1000)
  if(-not $done){
    StopProcessTree ([int]$proc.Id);Start-Sleep -Milliseconds 250
    $cleanup=@();$lockPath='.runtime/compact_memory_intake_v1/MERGE_QUEUE.lock.json'
    if(Test-Path $lockPath){
      try{$lock=Get-Content $lockPath -Raw|ConvertFrom-Json;if([int]$lock.pid -eq [int]$proc.Id -and -not(Get-Process -Id $proc.Id -ErrorAction SilentlyContinue)){Remove-Item -LiteralPath $lockPath -Force;$cleanup += 'REMOVED_OWNED_STALE_MERGE_LOCK'}}catch{}
    }
    foreach($root in $ownedRoots){
      if(-not(Test-Path $root)){continue}
      $after=@(Get-ChildItem $root -Directory -ErrorAction SilentlyContinue|Select-Object -ExpandProperty FullName)
      foreach($d in @($after|Where-Object{$_ -notin @($beforeOwned[$root])})){if(Test-Path $d){Remove-Item -LiteralPath $d -Recurse -Force;$cleanup += ('REMOVED_OWNED_TIMEOUT_DIR:'+ $d)}}
    }
    $out=@()
    if(Test-Path $stdout){ $out += @(Get-Content $stdout -ErrorAction SilentlyContinue) }
    if(Test-Path $stderr){ $out += @(Get-Content $stderr -ErrorAction SilentlyContinue) }
    return [ordered]@{ timed_out=$true; exit_code=$null; stdout_path=$stdout; stderr_path=$stderr; output_tail=@($out|Select-Object -Last 60); timeout_cleanup=@($cleanup); stale_lock_present_after=(Test-Path $lockPath) }
  }
  $out=@()
  if(Test-Path $stdout){ $out += @(Get-Content $stdout -ErrorAction SilentlyContinue) }
  if(Test-Path $stderr){ $out += @(Get-Content $stderr -ErrorAction SilentlyContinue) }
  return [ordered]@{ timed_out=$false; exit_code=$proc.ExitCode; stdout_path=$stdout; stderr_path=$stderr; output_tail=@($out|Select-Object -Last 60); timeout_cleanup=@(); stale_lock_present_after=(Test-Path '.runtime/compact_memory_intake_v1/MERGE_QUEUE.lock.json') }
}
if($ProcessLimit -lt 1){ throw 'QUEUE_MAINTENANCE_PROCESS_LIMIT_MUST_BE_POSITIVE' }
if($MergeTimeoutSeconds -lt 1){ throw 'QUEUE_MAINTENANCE_MERGE_TIMEOUT_MUST_BE_POSITIVE' }
if(-not (Test-Path $PolicyPath)){ throw "POLICY_MISSING:$PolicyPath" }
$policy=Get-Content $PolicyPath -Raw|ConvertFrom-Json
$runId="queue_maintenance_$(Get-Date -Format yyyyMMdd_HHmmss)"
$runRoot=".runtime/compact_memory_intake_v1/maintenance_runs/$runId"
$rejectedMetricsPath=Join-Path $runRoot 'rejected_metrics.jsonl'
EnsureDir $runRoot
$lockPath='.runtime/compact_memory_intake_v1/MERGE_QUEUE.lock.json'
$queueRoot=[string]$policy.runtime_queue_root
$actions=@(); $processed=@(); $skipped=@(); $rejected=@(); $pending=@(); $blockers=@()
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
    if(@($AllowedSourceKinds) -contains $kind){ $candidates += [ordered]@{ path=$f.FullName; source_kind=$kind; admission_state=(ReadPacketAdmissionState $f.FullName) } }
    else { $skipped += [ordered]@{ path=$f.FullName; source_kind=$kind; reason='SOURCE_KIND_NOT_ALLOWED_FOR_MAINTENANCE' } }
    if($candidates.Count -ge $ProcessLimit){ break }
  }
  if($candidates.Count -lt 1){
    $status='SKIPPED_QUEUE_MAINTENANCE_NO_MATCHING_PACKETS'
  } else {
    foreach($c in $candidates){
      if(Test-Path $lockPath){ $blockers += 'MERGE_QUEUE_LOCK_APPEARED_DURING_MAINTENANCE'; break }
      if($c.source_kind -eq 'AgentLife' -and $c.admission_state -eq 'PENDING_MEMORY_ATOM_GATE'){
        $gate=Invoke-AgentLifePendingAcceptance $c.path $runRoot
        if($gate.status -eq 'REJECTED_MEMORY_ATOM_GATE'){
          $event=[ordered]@{packet_path=$c.path;source_kind=$c.source_kind;decision='REJECTED_MEMORY_ATOM_GATE';deleted=$true;gate_reason=if($gate.decision){$gate.decision.reason}else{$null};feedback=$gate.feedback;created_at=(Get-Date).ToString('o')}
          $rejected += $event;$actions += "REJECT_AND_DELETE_MEMORY_ATOM_GATE:$($c.source_kind)";continue
        }
        if($gate.status -ne 'READY_AFTER_MEMORY_ATOM_GATE'){$blockers += "AGENTLIFE_GATE_NOT_READY:$($gate.status)";break}
        $c.admission_state='READY_AFTER_MEMORY_ATOM_GATE';$actions += "READY_AFTER_MEMORY_ATOM_GATE:$($c.source_kind)"
      }
      $validation=InvokePacketValidation $c.path $PolicyPath
      if($validation.status -ne 'PASS_COMPACT_MEMORY_KNOWLEDGE_PACKET_V1'){
        $isContent=([string]$validation.failure_class -eq 'CONTENT')
        $decision=if($isContent){'REJECT_DELETE'}else{'PENDING_RETAIN_VALIDATION_INFRASTRUCTURE'}
        $event=[ordered]@{packet_path=$c.path;source_kind=$c.source_kind;decision=$decision;deleted=$false;validation=$validation;created_at=(Get-Date).ToString('o')}
        if($isContent -and (Test-Path -LiteralPath $c.path)){ Remove-Item -LiteralPath $c.path -Force; $event.deleted=$true; $rejected += $event; $actions += "REJECT_DELETE:$($c.source_kind):$($validation.error_code)" }
        else { $pending += $event; $actions += "PENDING_RETAIN:$($c.source_kind):$($validation.failure_class):$($validation.error_code)" }
        AppendJsonLine $rejectedMetricsPath $event
        continue
      }
      $child=InvokeMergeQueueChild $c.path $PolicyPath $runRoot $MergeTimeoutSeconds $MemoryRoot
      $out=@($child.output_tail | ForEach-Object{[string]$_})
      $mergeStatus=($out|Where-Object{$_ -match '^MERGE_QUEUE_STATUS='}|Select-Object -Last 1) -replace '^MERGE_QUEUE_STATUS=',''
      $mergeProof=($out|Where-Object{$_ -match '^MERGE_QUEUE_PROOF='}|Select-Object -Last 1) -replace '^MERGE_QUEUE_PROOF=',''
      if($child.timed_out){ $mergeStatus='TIMEOUT_COMPACT_MEMORY_MERGE_QUEUE_CHILD' }
      elseif([int]$child.exit_code -ne 0 -and [string]::IsNullOrWhiteSpace($mergeStatus)){ $mergeStatus="EXIT_$($child.exit_code)" }
      $processed += [ordered]@{ packet_path=$c.path; source_kind=$c.source_kind; merge_status=$mergeStatus; merge_proof=$mergeProof; timed_out=$child.timed_out; exit_code=$child.exit_code; stdout_path=$child.stdout_path; stderr_path=$child.stderr_path; output_tail=@($out); timeout_cleanup=@($child.timeout_cleanup); stale_lock_present_after=$child.stale_lock_present_after }
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
  memory_root=$MemoryRoot
  queue_root=$queueRoot
  processed_count=@($processed).Count
  rejected_count=@($rejected).Count
  pending_count=@($pending).Count
  rejected=@($rejected)
  pending=@($pending)
  rejected_metrics_path=$rejectedMetricsPath
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

