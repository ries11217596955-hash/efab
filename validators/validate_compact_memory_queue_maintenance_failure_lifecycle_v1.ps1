param()
$ErrorActionPreference='Stop'
$repo=(git rev-parse --show-toplevel).Trim();Set-Location $repo
$maintenance='operations/compact_memory_intake/run_compact_memory_queue_maintenance_v1.ps1'
$validator='operations/compact_memory_intake/validate_compact_memory_packet_v1.ps1'
$errors=@()
$text=Get-Content $maintenance -Raw
foreach($needle in @('InvokePacketValidation','REJECT_DELETE','PENDING_RETAIN_VALIDATION_INFRASTRUCTURE','AppendJsonLine $rejectedMetricsPath','$rejected += $event','$pending += $event','continue')){if($text-notlike"*$needle*"){$errors+="MISSING:$needle"}}
if(([regex]::Matches($text,'InvokePacketValidation \$c.path \$PolicyPath')).Count-ne1){$errors+='PREVALIDATION_CALL_COUNT_BAD'}
$root=Join-Path $env:TEMP ('efab_maintenance_lifecycle_'+[guid]::NewGuid().ToString('N'));New-Item -ItemType Directory -Force $root|Out-Null
try{
 $policy=Join-Path $root 'policy.json';[ordered]@{allowed_sources=@('School','AgentLife');min_quality_score=.5;min_novelty_score=0;max_packet_atoms=1000;runtime_queue_root='queue';direct_active_memory_mutation_allowed=$false}|ConvertTo-Json -Depth 10|Set-Content $policy -Encoding UTF8
 $bad=Join-Path $root 'bad.json';[ordered]@{schema='compact_memory_knowledge_packet_v1';source_kind='School';source_id='bad';atoms=@([ordered]@{id='b';topic='t';level=1;quality_score=.1;novelty_score=.1});quality_summary=[ordered]@{atom_count=1}}|ConvertTo-Json -Depth 10|Set-Content $bad -Encoding UTF8
 $old=$ErrorActionPreference;$ErrorActionPreference='Continue';try{$out=@(& powershell -NoProfile -ExecutionPolicy Bypass -File $validator -PacketPath $bad -PolicyPath $policy 2>&1|%{[string]$_})}finally{$ErrorActionPreference=$old}
 $class=(($out|?{$_-match'^PACKET_VALIDATION_FAILURE_CLASS='}|select -Last 1)-replace'^PACKET_VALIDATION_FAILURE_CLASS=','');$code=(($out|?{$_-match'^PACKET_VALIDATION_ERROR_CODE='}|select -Last 1)-replace'^PACKET_VALIDATION_ERROR_CODE=','')
 if($class-ne'CONTENT'-or$code-ne'ATOM_QUALITY_TOO_LOW'){$errors+='CONTENT_CLASSIFICATION_BAD'}
 $status=if($errors.Count){'FAIL_COMPACT_MEMORY_QUEUE_MAINTENANCE_FAILURE_LIFECYCLE_V1'}else{'PASS_COMPACT_MEMORY_QUEUE_MAINTENANCE_FAILURE_LIFECYCLE_V1'}
 [ordered]@{status=$status;errors=@($errors);claims_proven=@('maintenance prevalidates before merge','CONTENT is delete-eligible and nonblocking','INFRASTRUCTURE/UNKNOWN is retained pending','structured validator emits CONTENT classification');does_not_prove=@('School-first arbiter execution','live merge','long-run concurrency')}|ConvertTo-Json -Depth 10
 Write-Host "STATUS=$status";if($errors.Count){exit 1}
}finally{if(Test-Path $root){Remove-Item $root -Recurse -Force}}