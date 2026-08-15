[CmdletBinding()]
param(
  [ValidateSet('List','Plan','Run')][string]$Mode='List',
  [string[]]$Action=@(),
  [switch]$Json,
  [switch]$ConfirmMutation,
  [ValidateRange(1,1000000)][int]$SchoolCount=1,
  [ValidateSet('Test','Live')][string]$SchoolMode='Test',
  [string]$SchoolTopics='codex_school_task_template_strength',
  [ValidateRange(1,10080)][int]$AgentDurationMinutes=1
)
$ErrorActionPreference='Stop'
$repo=(git rev-parse --show-toplevel).Trim()
if(-not $repo){throw 'CONTROL_CENTER_REPO_ROOT_NOT_FOUND'}
Set-Location $repo
$registryPath='operations/control_center/BUILDER_CONTROL_CENTER_REGISTRY_V1.json'
$registry=Get-Content $registryPath -Raw|ConvertFrom-Json
$actions=@($registry.actions)
function Get-Reg([string]$Id){@($actions|Where-Object{$_.id -eq $Id})|Select-Object -First 1}
function Get-RepoStatus{$d=@(git status --porcelain=v1 -uall);[ordered]@{id='repo.status';status=if($d.Count){'DIRTY'}else{'CLEAN'};head=(git rev-parse HEAD).Trim();branch=(git branch --show-current).Trim();dirty_count=$d.Count}}
function Get-SchoolStatus{
 $p=@(Get-CimInstance Win32_Process|Where-Object{$_.ProcessId-ne$PID -and $_.CommandLine -and $_.CommandLine -notmatch 'invoke_builder_control_center_v1.ps1' -and $_.CommandLine -match '(?i)run_agent_school\.ps1|canonical_exact_count_cycle_real_|Invoke-SchoolWarehouseConsumer|codex_school_task_template_strength'})
 $pending='.runtime/school_resume_v1/pending_request.json';$queue='.runtime/school_resume_v1/queue';$qc=0;if(Test-Path $queue){$qc=@(Get-ChildItem $queue -File -Filter 'request_*.json').Count}
 [ordered]@{id='school.status';status=if($p.Count){'RUNNING'}elseif((Test-Path $pending)-or$qc){'RECOVERY_OR_QUEUED'}else{'STOPPED'};process_count=$p.Count;pending=(Test-Path $pending);queue_count=$qc;canonical_entrypoint='operations/school/run_agent_school.ps1'}
}
function Get-AgentStatus{$p=@(Get-CimInstance Win32_Process|Where-Object{$_.ProcessId-ne$PID -and $_.CommandLine -and $_.CommandLine -notmatch 'invoke_builder_control_center_v1.ps1' -and $_.CommandLine -match '(?i)start_agent_life_v1\.ps1|run_autonomous_inner_motor\.ps1|continuous_agent_runtime_v1'});[ordered]@{id='agent.status';status=if($p.Count){'RUNNING'}else{'STOPPED'};process_count=$p.Count;canonical_entrypoint='operations/autonomous_inner_motor/start_agent_life_v1.ps1'}}
function Get-InventoryStatus{$p='reports/self_development/agent_body_map.json';if(-not(Test-Path $p)){return [ordered]@{id='inventory.status';status='MISSING';artifact=$p}};$j=Get-Content $p -Raw|ConvertFrom-Json;[ordered]@{id='inventory.status';status='PRESENT';artifact=$p;component_count=@($j.components).Count;fingerprint=$j.body_source_fingerprint.sha256}}
function Get-CapabilityStatus{$a='reports/self_development/CAPABILITY_INVOCATION_MAP_V1.json';$c='self_model/CAPABILITY_INVOCATION_MAP_V1_CONTRACT.json';$cs=$null;if(Test-Path $c){$cs=(Get-Content $c -Raw|ConvertFrom-Json).status};[ordered]@{id='capability.status';status=if(Test-Path $a){'PRESENT'}else{'MISSING_NOT_WIRED'};artifact=$a;contract=$c;contract_status=$cs}}
function Get-MemoryStatus{$root='.runtime/active_compact_semantic_memory_v1';$m=@('manifest.json','index.json','cells.jsonl')|Where-Object{-not(Test-Path(Join-Path $root $_))};$n=$null;if(-not$m.Count){$n=@(Get-Content(Join-Path $root 'cells.jsonl')).Count};[ordered]@{id='memory.status';status=if($m.Count){'INCOMPLETE'}else{'PRESENT'};root=$root;cell_count=$n;missing=@($m)}}
function Get-StartReadiness([string]$Id){
 $repoState=Get-RepoStatus;$school=Get-SchoolStatus;$agent=Get-AgentStatus;$memory=Get-MemoryStatus
 if($Id -eq 'school.start'){
   if($school.status -eq 'RUNNING'){return [ordered]@{id=$Id;status='ALREADY_RUNNING';reason='School process already active';canonical_entrypoint='operations/school/run_agent_school.ps1'}}
   if($school.status -eq 'RECOVERY_OR_QUEUED'){return [ordered]@{id=$Id;status='BLOCKED';reason='School recovery/pending/queue state exists';canonical_entrypoint='operations/school/run_agent_school.ps1'}}
   if($agent.status -eq 'RUNNING'){return [ordered]@{id=$Id;status='BLOCKED';reason='Agent runtime active';canonical_entrypoint='operations/school/run_agent_school.ps1'}}
   if($repoState.status -ne 'CLEAN'){return [ordered]@{id=$Id;status='BLOCKED';reason='Repository not clean';canonical_entrypoint='operations/school/run_agent_school.ps1'}}
   if($memory.status -ne 'PRESENT'){return [ordered]@{id=$Id;status='BLOCKED';reason='Active compact memory incomplete';canonical_entrypoint='operations/school/run_agent_school.ps1'}}
   return [ordered]@{id=$Id;status='READY';canonical_entrypoint='operations/school/run_agent_school.ps1';parameters=[ordered]@{Count=$SchoolCount;Mode=$SchoolMode;Topics=$SchoolTopics}}
 }
 if($Id -eq 'agent.start'){
   if($agent.status -eq 'RUNNING'){return [ordered]@{id=$Id;status='ALREADY_RUNNING';reason='Agent runtime already active';canonical_entrypoint='operations/autonomous_inner_motor/start_agent_life_v1.ps1'}}
   if($school.status -ne 'STOPPED'){return [ordered]@{id=$Id;status='BLOCKED';reason='School runtime/recovery state active';canonical_entrypoint='operations/autonomous_inner_motor/start_agent_life_v1.ps1'}}
   if($repoState.status -ne 'CLEAN'){return [ordered]@{id=$Id;status='BLOCKED';reason='Repository not clean';canonical_entrypoint='operations/autonomous_inner_motor/start_agent_life_v1.ps1'}}
   if($memory.status -ne 'PRESENT'){return [ordered]@{id=$Id;status='BLOCKED';reason='Active compact memory incomplete';canonical_entrypoint='operations/autonomous_inner_motor/start_agent_life_v1.ps1'}}
   return [ordered]@{id=$Id;status='READY';canonical_entrypoint='operations/autonomous_inner_motor/start_agent_life_v1.ps1';parameters=[ordered]@{DurationMinutes=$AgentDurationMinutes}}
 }
 throw "CONTROL_CENTER_START_READINESS_UNKNOWN:$Id"
}
function Invoke-Diagnostic([string]$Id){
 if($Id -eq 'runtime.diagnose'){
   $school=Get-SchoolStatus;$agent=Get-AgentStatus
   $status=if($school.status -eq 'RUNNING' -or $agent.status -eq 'RUNNING'){'DIAGNOSTIC_RUNNING'}elseif($school.status -eq 'RECOVERY_OR_QUEUED'){'DIAGNOSTIC_ATTENTION'}else{'DIAGNOSTIC_PASS'}
   return [ordered]@{id=$Id;status=$status;school=$school;agent=$agent}
 }
 if($Id -eq 'memory.diagnose'){
   $m=Get-MemoryStatus;$root='.runtime/active_compact_semantic_memory_v1';$errors=@();$hashes=[ordered]@{}
   if($m.status -eq 'PRESENT'){
     foreach($n in @('manifest.json','index.json','cells.jsonl')){$fp=Join-Path $root $n;$hashes[$n]=(Get-FileHash -Algorithm SHA256 $fp).Hash}
     try{$null=Get-Content (Join-Path $root 'manifest.json') -Raw|ConvertFrom-Json}catch{$errors+='manifest_json_invalid'}
     try{$null=Get-Content (Join-Path $root 'index.json') -Raw|ConvertFrom-Json}catch{$errors+='index_json_invalid'}
     try{foreach($line in Get-Content (Join-Path $root 'cells.jsonl')){if($line.Trim()){$null=$line|ConvertFrom-Json}}}catch{$errors+='cells_jsonl_invalid'}
   } else {$errors+='memory_incomplete'}
   return [ordered]@{id=$Id;status=if($errors.Count){'DIAGNOSTIC_FAIL'}else{'DIAGNOSTIC_PASS'};memory=$m;hashes=$hashes;errors=@($errors)}
 }
 if($Id -eq 'inventory.diagnose'){
   $before=@(git status --porcelain=v1 -uall);$mr='.runtime/active_compact_semantic_memory_v1';$mh=@{}
   foreach($n in @('manifest.json','index.json','cells.jsonl')){$x=Join-Path $mr $n;if(Test-Path $x){$mh[$n]=(Get-FileHash -Algorithm SHA256 $x).Hash}}
   $validator='validators/validate_body_inventory_map_current_v1.ps1';$artifact='.runtime/map_control/validations/body_inventory_map_current_validation.json'
   $output=& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $validator 2>&1|Out-String;$exit=$LASTEXITCODE
   $after=@(git status --porcelain=v1 -uall);if(($before -join "`n") -ne ($after -join "`n")){throw 'INVENTORY_DIAGNOSTIC_TRACKED_MUTATION'}
   foreach($n in $mh.Keys){if((Get-FileHash -Algorithm SHA256 (Join-Path $mr $n)).Hash -ne $mh[$n]){throw "INVENTORY_DIAGNOSTIC_MEMORY_MUTATION:$n"}}
   if($exit -ne 0){return [ordered]@{id=$Id;status='DIAGNOSTIC_FAIL';validator=$validator;validator_exit=$exit;output=$output.Trim()}}
   if(-not(Test-Path $artifact)){return [ordered]@{id=$Id;status='DIAGNOSTIC_FAIL';validator=$validator;reason='runtime_artifact_missing'}}
   $a=Get-Content $artifact -Raw|ConvertFrom-Json
   return [ordered]@{id=$Id;status=if($a.status -eq 'PASS_BODY_INVENTORY_MAP_CURRENT_V1'){'DIAGNOSTIC_PASS'}else{'DIAGNOSTIC_FAIL'};validator=$validator;artifact=$artifact;validator_status=$a.status}
 }
 if($Id -eq 'capability.diagnose'){
   $cap=Get-CapabilityStatus
   if($cap.status -eq 'MISSING_NOT_WIRED'){
     return [ordered]@{id=$Id;status='DIAGNOSTIC_COMPLETE_WITH_BLOCKER';capability=$cap;blocker='CAPABILITY_MAP_MISSING_NOT_WIRED';unsafe_validator='operations/self_model/validate_capability_invocation_map_v1_contract.ps1';unsafe_validator_invoked=$false;reason='Default diagnose will not run a validator that writes tracked proof.'}
   }
   return [ordered]@{id=$Id;status='DIAGNOSTIC_PRESENT_NOT_SEMANTICALLY_VALIDATED';capability=$cap;unsafe_validator_invoked=$false}
 }
 if($Id -eq 'control_center.diagnose'){
   $errors=@();$regPath='operations/control_center/BUILDER_CONTROL_CENTER_REGISTRY_V1.json';$ctlPath='operations/control_center/invoke_builder_control_center_v1.ps1'
   try{$rr=Get-Content $regPath -Raw|ConvertFrom-Json}catch{$errors+='registry_json_invalid';$rr=$null}
   if($rr){$ids=@($rr.actions.id);if($ids.Count -ne @($ids|Sort-Object -Unique).Count){$errors+='duplicate_action_id'};foreach($a in @($rr.actions)){if(-not$a.id -or -not$a.group -or -not$a.handler){$errors+='action_contract_incomplete'}}}
   $tok=$null;$err=$null;[void][System.Management.Automation.Language.Parser]::ParseFile((Resolve-Path $ctlPath),[ref]$tok,[ref]$err);if($err.Count){$errors+='control_script_parse_error'}
   foreach($ep in @('operations/school/run_agent_school.ps1','operations/autonomous_inner_motor/start_agent_life_v1.ps1')){if(-not(Test-Path $ep)){$errors+=("entrypoint_missing:"+$ep)}}
   return [ordered]@{id=$Id;status=if($errors.Count){'DIAGNOSTIC_FAIL'}else{'DIAGNOSTIC_PASS'};action_count=if($rr){@($rr.actions).Count}else{0};errors=@($errors)}
 }
 throw "CONTROL_CENTER_DIAGNOSTIC_UNKNOWN:$Id"
}
function Invoke-Observed([string]$Id){switch($Id){'repo.status'{Get-RepoStatus}'school.status'{Get-SchoolStatus}'agent.status'{Get-AgentStatus}'inventory.status'{Get-InventoryStatus}'capability.status'{Get-CapabilityStatus}'memory.status'{Get-MemoryStatus}'builder.status'{[ordered]@{id='builder.status';status='OBSERVED';repo=(Get-RepoStatus);school=(Get-SchoolStatus);agent=(Get-AgentStatus);inventory=(Get-InventoryStatus);capability=(Get-CapabilityStatus);memory=(Get-MemoryStatus)}}'school.start'{Get-StartReadiness 'school.start'}'agent.start'{Get-StartReadiness 'agent.start'}default{throw"CONTROL_CENTER_HANDLER_NOT_IMPLEMENTED:$Id"}}}
function Invoke-Start([string]$Id){
 $ready=Get-StartReadiness $Id
 if($ready.status -ne 'READY'){return $ready}
 if(-not $ConfirmMutation){return [ordered]@{id=$Id;status='BLOCKED_CONFIRMATION_REQUIRED';reason='ConfirmMutation required';canonical_entrypoint=$ready.canonical_entrypoint}}
 if($Id -eq 'school.start'){
   $args=@('-NoProfile','-ExecutionPolicy','Bypass','-File','operations/school/run_agent_school.ps1','-Count',[string]$SchoolCount,'-Mode',$SchoolMode,'-Topics',$SchoolTopics)
   $proc=Start-Process -FilePath 'powershell.exe' -ArgumentList $args -WorkingDirectory $repo -PassThru
   return [ordered]@{id=$Id;status='STARTED';pid=$proc.Id;canonical_entrypoint='operations/school/run_agent_school.ps1';parameters=$ready.parameters}
 }
 if($Id -eq 'agent.start'){
   $args=@('-NoProfile','-ExecutionPolicy','Bypass','-File','operations/autonomous_inner_motor/start_agent_life_v1.ps1','-DurationMinutes',[string]$AgentDurationMinutes)
   $proc=Start-Process -FilePath 'powershell.exe' -ArgumentList $args -WorkingDirectory $repo -PassThru
   return [ordered]@{id=$Id;status='STARTED';pid=$proc.Id;canonical_entrypoint='operations/autonomous_inner_motor/start_agent_life_v1.ps1';parameters=$ready.parameters}
 }
 throw "CONTROL_CENTER_START_UNKNOWN:$Id"
}
if($Mode -eq 'List'){$out=@($actions|ForEach-Object{[ordered]@{id=$_.id;title=$_.title;group=$_.group;kind=$_.kind;read_only=[bool]$_.read_only;parallel_safe=[bool]$_.parallel_safe}})}
elseif($Mode -eq 'Plan'){
 if(-not$Action.Count){throw'CONTROL_CENTER_ACTION_REQUIRED'}
 $selected=@();foreach($id in $Action){$a=Get-Reg $id;if(-not$a){throw"CONTROL_CENTER_UNKNOWN_ACTION:$id"};$selected+=$a}
 $conflicts=@();foreach($a in $selected){foreach($c in @($a.conflicts)){if($c -ne $a.id -and $Action -contains $c){$conflicts+="$($a.id)<->$c"}}}
 $readiness=@();foreach($a in $selected){if($a.group -eq 'DIAGNOSE'){$readiness+=,[ordered]@{id=$a.id;status='READY_DIAGNOSTIC'}}elseif([bool]$a.read_only){$readiness+=,[ordered]@{id=$a.id;status='READY_READ_ONLY'}}else{$readiness+=,(Get-StartReadiness $a.id)}}
 $blocked=@($readiness|Where-Object{$_.status -notin @('READY','READY_READ_ONLY','READY_DIAGNOSTIC')})
 $out=[ordered]@{status=if($conflicts.Count){'BLOCKED_CONFLICT'}elseif($blocked.Count){'BLOCKED'}else{'READY'};selected=@($selected.id);count=$selected.Count;mutation_count=@($selected|Where-Object{-not[bool]$_.read_only}).Count;diagnostic_count=@($selected|Where-Object{$_.group -eq 'DIAGNOSE'}).Count;live_mutation_count=@($selected|Where-Object{$_.group -in @('START','MAINTAIN','REPAIR')}).Count;parallel_safe=(@($selected|Where-Object{-not[bool]$_.parallel_safe}).Count -eq 0);execution_mode=if(@($selected|Where-Object{-not[bool]$_.parallel_safe}).Count){'SEQUENTIAL'}else{'PARALLEL_SAFE'};conflicts=@($conflicts);readiness=@($readiness)}
}
else{
 if(-not$Action.Count){throw'CONTROL_CENTER_ACTION_REQUIRED'}
 $plan=& $PSCommandPath -Mode Plan -Action $Action -Json -SchoolCount $SchoolCount -SchoolMode $SchoolMode -SchoolTopics $SchoolTopics -AgentDurationMinutes $AgentDurationMinutes|ConvertFrom-Json
 if($plan.status -ne 'READY'){ $out=[ordered]@{status='NOT_STARTED';plan=$plan} }
 else{
   $results=@();foreach($id in $Action){$a=Get-Reg $id;if($a.group -eq 'DIAGNOSE'){$results+=,(Invoke-Diagnostic $id)}elseif([bool]$a.read_only){$results+=,(Invoke-Observed $id)}else{$results+=,(Invoke-Start $id)}}
   $out=[ordered]@{status=if(@($results|Where-Object{$_.status -eq 'STARTED'}).Count){'START_DISPATCHED'}elseif(@($results|Where-Object{$_.status -eq 'BLOCKED_CONFIRMATION_REQUIRED'}).Count){'BLOCKED_CONFIRMATION_REQUIRED'}elseif(@($Action|Where-Object{(Get-Reg $_).group -eq 'DIAGNOSE'}).Count){'PASS_DIAGNOSTIC_RUN'}else{'PASS_READ_ONLY_RUN'};selected=@($Action);results=@($results)}
 }
}
if($Json){$out|ConvertTo-Json -Depth 14 -Compress}else{$out|ConvertTo-Json -Depth 14}
