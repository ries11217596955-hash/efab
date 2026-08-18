[CmdletBinding()]
param(
  [ValidateSet('List','Plan','Run')][string]$Mode='List',
  [string[]]$Action=@(),
  [switch]$Json,
  [switch]$ConfirmMutation,
  [ValidateRange(1,1000000)][int]$SchoolCount=1,
  [ValidateSet('Test','Live')][string]$SchoolMode='Test',
  [string]$SchoolTopics='codex_school_task_template_strength',
  [ValidateRange(1,10080)][int]$AgentDurationMinutes=1,
  [string[]]$ExpectedPaths=@(),
  [string]$SchoolProofPath='',
  [ValidateSet('telegram')][string]$NotificationChannel='telegram',
  [string]$RunId='',
  [ValidateRange(1,100)][int]$RunTailLines=20,
  [string]$ExpectedHead='',
  [string]$AcceptanceBaseHead='',
  [string]$AcceptanceNewHead='',
  [string]$CommitMessage='',
  [string]$AuthorityPassportJson=''
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
function Get-CapabilityStatus{
 $a='reports/self_development/CAPABILITY_INVOCATION_MAP_V1.json';$c='self_model/CAPABILITY_INVOCATION_MAP_V1_CONTRACT.json';$cs=$null
 if(Test-Path $c){$cs=(Get-Content $c -Raw|ConvertFrom-Json).status}
 if(-not(Test-Path $a)){return [ordered]@{id='capability.status';status='MISSING_NOT_WIRED';artifact=$a;contract=$c;contract_status=$cs}}
 try{$m=Get-Content $a -Raw|ConvertFrom-Json}catch{return [ordered]@{id='capability.status';status='INVALID_MAP_JSON';artifact=$a;contract=$c;contract_status=$cs;map_status='INVALID_JSON'}}
 $caps=@($m.capabilities).Count;$tasks=[int]$m.coverage.current_tasks_seen;$noId=[int]$m.coverage.tasks_without_capability_id
 $owners=@($m.capabilities|Where-Object{$null-ne$_.owning_organ_id -and -not[string]::IsNullOrWhiteSpace([string]$_.owning_organ_id)}).Count
 $invocable=@($m.capabilities|Where-Object{@($_.invocation_modes).Count-gt0}).Count
 $live=@($m.capabilities|Where-Object{$_.live_or_lab_status-eq'PROVEN_LIVE'}).Count
 $ready=($m.status -notmatch 'DRAFT|GAP' -and $noId-eq0 -and $owners-eq$caps -and $invocable-gt0)
 [ordered]@{id='capability.status';status=if($ready){'PRESENT_READY'}else{'PRESENT_DRAFT_NOT_READY'};artifact=$a;contract=$c;contract_status=$cs;map_status=[string]$m.status;capability_count=$caps;current_tasks_seen=$tasks;tasks_without_capability_id=$noId;owners_resolved=$owners;invocable_count=$invocable;live_proven_count=$live;accounted_total=[int]$m.coverage.accounted_total}
}
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
 if($Id -eq 'school.resume'){
   $pendingPath='.runtime/school_resume_v1/pending_request.json'
   if($school.status -eq 'RUNNING'){return [ordered]@{id=$Id;status='ALREADY_RUNNING';reason='School process already active';canonical_entrypoint='operations/school/run_agent_school.ps1'}}
   if($agent.status -eq 'RUNNING'){return [ordered]@{id=$Id;status='BLOCKED';reason='Agent runtime active';canonical_entrypoint='operations/school/run_agent_school.ps1'}}
   if($repoState.status -ne 'CLEAN'){return [ordered]@{id=$Id;status='BLOCKED';reason='Repository not clean';canonical_entrypoint='operations/school/run_agent_school.ps1'}}
   if($memory.status -ne 'PRESENT'){return [ordered]@{id=$Id;status='BLOCKED';reason='Active compact memory incomplete';canonical_entrypoint='operations/school/run_agent_school.ps1'}}
   if(-not(Test-Path -LiteralPath $pendingPath)){return [ordered]@{id=$Id;status='BLOCKED';reason='No pending School request to resume';canonical_entrypoint='operations/school/run_agent_school.ps1';pending_path=$pendingPath}}
   try{$pending=Get-Content -LiteralPath $pendingPath -Raw|ConvertFrom-Json}catch{return [ordered]@{id=$Id;status='BLOCKED';reason='Pending School request JSON invalid';canonical_entrypoint='operations/school/run_agent_school.ps1';pending_path=$pendingPath}}
   if([string]$pending.status -notin @('PENDING','PAUSED_EXTERNAL','RESUMING')){return [ordered]@{id=$Id;status='BLOCKED';reason=('Pending School status not resumable: '+[string]$pending.status);canonical_entrypoint='operations/school/run_agent_school.ps1';pending_path=$pendingPath}}
   [int]$pc=0; if(-not [int]::TryParse([string]$pending.count,[ref]$pc) -or $pc -lt 1 -or $pc -gt 1000000){return [ordered]@{id=$Id;status='BLOCKED';reason='Pending School count invalid';canonical_entrypoint='operations/school/run_agent_school.ps1';pending_path=$pendingPath}}
   $pm=[string]$pending.mode; if($pm -notin @('Test','Live')){return [ordered]@{id=$Id;status='BLOCKED';reason='Pending School mode invalid';canonical_entrypoint='operations/school/run_agent_school.ps1';pending_path=$pendingPath}}
   $pt=[string]$pending.topics; if([string]::IsNullOrWhiteSpace($pt)){return [ordered]@{id=$Id;status='BLOCKED';reason='Pending School topics invalid';canonical_entrypoint='operations/school/run_agent_school.ps1';pending_path=$pendingPath}}
   return [ordered]@{id=$Id;status='READY';canonical_entrypoint='operations/school/run_agent_school.ps1';parameters=[ordered]@{Count=$pc;Mode=$pm;Topics=$pt;PendingPath=$pendingPath;PendingStatus=[string]$pending.status;PendingPhase=[string]$pending.phase};does_not_prove='successful_resumed_school_completion'}
 }
 if($Id -eq 'school.stop'){
   $pendingPath='.runtime/school_resume_v1/pending_request.json';$stopPath='.runtime/school_resume_v1/stop_request.json'
   if($school.status -ne 'RUNNING'){return [ordered]@{id=$Id;status='BLOCKED';reason='School runtime not running';canonical_entrypoint='operations/school/run_agent_school.ps1'}}
   if($repoState.status -ne 'CLEAN'){return [ordered]@{id=$Id;status='BLOCKED';reason='Repository not clean';canonical_entrypoint='operations/school/run_agent_school.ps1'}}
   if($memory.status -ne 'PRESENT'){return [ordered]@{id=$Id;status='BLOCKED';reason='Active compact memory incomplete';canonical_entrypoint='operations/school/run_agent_school.ps1'}}
   if(-not(Test-Path -LiteralPath $pendingPath)){return [ordered]@{id=$Id;status='BLOCKED';reason='Running School has no pending recovery state';canonical_entrypoint='operations/school/run_agent_school.ps1'}}
   if(Test-Path -LiteralPath $stopPath){return [ordered]@{id=$Id;status='ALREADY_REQUESTED';reason='Cooperative stop already requested';canonical_entrypoint='operations/school/run_agent_school.ps1';stop_path=$stopPath}}
   try{$pending=Get-Content -LiteralPath $pendingPath -Raw|ConvertFrom-Json}catch{return [ordered]@{id=$Id;status='BLOCKED';reason='Pending School request JSON invalid';canonical_entrypoint='operations/school/run_agent_school.ps1'}}
   if([string]$pending.status -notin @('PENDING','RESUMING')){return [ordered]@{id=$Id;status='BLOCKED';reason=('Running School pending status not stoppable: '+[string]$pending.status);canonical_entrypoint='operations/school/run_agent_school.ps1'}}
   return [ordered]@{id=$Id;status='READY';canonical_entrypoint='operations/school/run_agent_school.ps1';parameters=[ordered]@{StopPath=$stopPath;PendingPath=$pendingPath;RunId=[string]$pending.exact_cycle_run_id};does_not_prove='pause_acknowledged_or_resume_success'}
 }
 if($Id -eq 'school.notification.send'){
   $plan=Get-SchoolNotificationPlan
   if($plan.status -ne 'NOTIFICATION_PLAN_READY'){return [ordered]@{id=$Id;status='BLOCKED_NOTIFICATION_PLAN';reason=[string]$plan.status;canonical_entrypoint='Telegram Bot API sendMessage'}}
   if($plan.transport_state -ne 'READY_FOR_TRANSPORT'){return [ordered]@{id=$Id;status='BLOCKED_CREDENTIALS_REQUIRED';reason='TELEGRAM_BOT_TOKEN and TELEGRAM_CHAT_ID environment variables required';canonical_entrypoint='Telegram Bot API sendMessage';proof_sha256=[string]$plan.proof_sha256}}
   return [ordered]@{id=$Id;status='READY';canonical_entrypoint='Telegram Bot API sendMessage';parameters=[ordered]@{channel='telegram';proof_sha256=[string]$plan.proof_sha256;credential_source='process_environment'}}
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
function Get-FreshnessEnvelope([int]$TtlSeconds=60){
 $now=Get-Date;$expires=$now.AddSeconds($TtlSeconds)
 [ordered]@{observed_at=$now.ToString('o');ttl_seconds=$TtlSeconds;expires_at=$expires.ToString('o');state='FRESH';proof_scope='LIVE_OBSERVE_THIS_CALL'}
}
function Get-ScheduledTaskProbe([string]$Name){
 try{$t=Get-ScheduledTask -TaskName $Name -ErrorAction Stop;[ordered]@{name=$Name;present=$true;state=[string]$t.State;healthy=([string]$t.State -eq 'Running')}}catch{[ordered]@{name=$Name;present=$false;state='MISSING';healthy=$false}}
}
function Get-RemoteAccessStatus{
 $pc=Get-ScheduledTaskProbe 'EFAB PC Control SYSTEM';$rescue=Get-ScheduledTaskProbe 'EFAB Rescue Control SYSTEM';$recovery=Get-ScheduledTaskProbe 'EFAB Recovery Gateway SYSTEM';$ngrok=Get-ScheduledTaskProbe 'EFAB Ngrok Primary SYSTEM';$oob=Get-ScheduledTaskProbe 'EFAB OOB Gateway SYSTEM';$oobTransport=Get-ScheduledTaskProbe 'EFAB OOB Cloudflare Transport SYSTEM'
 $tailscale=[ordered]@{name='Tailscale';present=$false;state='MISSING';healthy=$false}
 try{$svc=Get-Service -Name 'Tailscale' -ErrorAction Stop;$tailscale=[ordered]@{name='Tailscale';present=$true;state=[string]$svc.Status;start_type=[string]$svc.StartType;healthy=([string]$svc.Status -eq 'Running')}}catch{}
 $pcApi=[ordered]@{endpoint='127.0.0.1:18790';status='NOT_LISTENING';healthy=$false;proof_scope='tcp_listener_only';does_not_prove='authenticated_api_behavior'}
 try{$client=New-Object System.Net.Sockets.TcpClient;$async=$client.BeginConnect('127.0.0.1',18790,$null,$null);if($async.AsyncWaitHandle.WaitOne(1000,$false) -and $client.Connected){$client.EndConnect($async);$pcApi=[ordered]@{endpoint='127.0.0.1:18790';status='LISTENING';healthy=$true;proof_scope='tcp_listener_only';does_not_prove='authenticated_api_behavior'}};$client.Close()}catch{}
 $components=@($pc,$rescue,$recovery,$ngrok,$oob,$oobTransport,$tailscale,$pcApi)
 $bad=@($components|Where-Object{-not[bool]$_.healthy})
 [ordered]@{id='remote_access.status';status=if($bad.Count){'DEGRADED_LOCAL_COMPONENTS'}else{'HEALTHY_LOCAL_COMPONENTS'};components=$components;gpt_connector=[ordered]@{status='UNKNOWN_EXTERNAL_TO_LOCAL_PC';reason='Connector/session reachability cannot be proven from the local PC itself.'};failover_locally_present=($rescue.present -and $recovery.present -and $oob.present);freshness=(Get-FreshnessEnvelope 60)}
}
function Get-BuilderOverview{
 $repo=Get-RepoStatus;$school=Get-SchoolStatus;$agent=Get-AgentStatus;$memory=Get-MemoryStatus;$inventory=Get-InventoryStatus;$capability=Get-CapabilityStatus;$remote=Get-RemoteAccessStatus
 $registryState=[ordered]@{status='HEALTHY';action_count=@($actions).Count;duplicate_ids=$false}
 $ids=@($actions.id);if($ids.Count -ne @($ids|Sort-Object -Unique).Count){$registryState.status='DEGRADED';$registryState.duplicate_ids=$true}
 $blockers=@();$impact=@();$recommended=[ordered]@{id='none';action='NONE';reason='No higher-priority blocker observed.'}
 if($repo.status -ne 'CLEAN'){$blockers+='REPO_DIRTY';$impact+='Mutation/start readiness may be blocked by dirty repository state.'}
 if($memory.status -ne 'PRESENT'){$blockers+='ACTIVE_MEMORY_INCOMPLETE';$impact+='School and memory-dependent operations are unsafe.'}
 if($school.status -eq 'RECOVERY_OR_QUEUED'){$blockers+='SCHOOL_RECOVERY_OR_QUEUE';$impact+='New School launch must not bypass recovery/queue state.'}
 if($remote.status -ne 'HEALTHY_LOCAL_COMPONENTS'){$blockers+='REMOTE_ACCESS_LOCAL_DEGRADED';$impact+='Remote recovery redundancy is reduced.'}
 if($capability.status -eq 'MISSING_NOT_WIRED'){$blockers+='CAPABILITY_MAP_MISSING_NOT_WIRED';$impact+='Canonical capability invocation map is unavailable.';$impact+='Capability-map-dependent routing/currentness cannot be proven.'};if($capability.status -eq 'PRESENT_DRAFT_NOT_READY'){$blockers+='CAPABILITY_MAP_PRESENT_DRAFT_NOT_READY';$impact+='Capability catalog exists but ownership/invocation/maturity wiring is incomplete.'}
 if($repo.status -ne 'CLEAN'){$recommended=[ordered]@{id='repo.status';action='INSPECT_REPO';reason='Repository is not clean.'}}
 elseif($memory.status -ne 'PRESENT'){$recommended=[ordered]@{id='memory.diagnose';action='DIAGNOSE_MEMORY';reason='Active compact memory is incomplete.'}}
 elseif($school.status -eq 'RECOVERY_OR_QUEUED'){if($school.pending){$recommended=[ordered]@{id='school.resume';action='RESUME_SCHOOL';reason='A pending School request exists and can be evaluated for governed resume.'}}else{$recommended=[ordered]@{id='school.status';action='OBSERVE_SCHOOL_RECOVERY';reason='School queue/recovery state exists without a resumable pending request.'}}}
 elseif($remote.status -ne 'HEALTHY_LOCAL_COMPONENTS'){$recommended=[ordered]@{id='remote_access.status';action='DIAGNOSE_REMOTE_ACCESS';reason='One or more locally observable remote-access components are unhealthy.'}}
 elseif($capability.status -eq 'MISSING_NOT_WIRED'){$recommended=[ordered]@{id='capability.diagnose';action='COMPLETE_CAPABILITY_MAP_PIPELINE';reason='Capability contract exists but canonical map/wiring is missing.'}}
 elseif($capability.status -eq 'PRESENT_DRAFT_NOT_READY'){$recommended=[ordered]@{id='capability.diagnose';action='COMPLETE_CAPABILITY_MAP_WIRING';reason='Capability map draft exists but owners/invocation/maturity are not ready.'}}
 $surface=@(
  [ordered]@{id='repo';state=if($repo.status-eq'CLEAN'){'HEALTHY'}else{'DEGRADED'};raw_status=$repo.status},
  [ordered]@{id='school';state=if($school.status-eq'RUNNING'){'ACTIVE'}elseif($school.status-eq'STOPPED'){'IDLE'}else{'DEGRADED'};raw_status=$school.status},
  [ordered]@{id='agent';state=if($agent.status-eq'RUNNING'){'ACTIVE'}else{'IDLE'};raw_status=$agent.status},
  [ordered]@{id='memory';state=if($memory.status-eq'PRESENT'){'HEALTHY'}else{'BLOCKED'};raw_status=$memory.status},
  [ordered]@{id='inventory';state=if($inventory.status-eq'PRESENT'){'PRESENT'}else{'MISSING'};raw_status=$inventory.status;claim_scope='presence_only_use_inventory.diagnose_for_currentness'},
  [ordered]@{id='capability';state=if($capability.status-eq'PRESENT_READY'){'HEALTHY'}else{'DEGRADED'};raw_status=$capability.status;map_status=$capability.map_status;capability_count=$capability.capability_count;tasks_without_capability_id=$capability.tasks_without_capability_id;owners_resolved=$capability.owners_resolved;invocable_count=$capability.invocable_count;live_proven_count=$capability.live_proven_count;maturity=[ordered]@{contract=if($capability.contract_status){'PRESENT'}else{'UNKNOWN'};canonical_map=if($capability.status-eq'MISSING_NOT_WIRED'){'MISSING'}else{'PRESENT'};wiring=if($capability.status-eq'PRESENT_READY'){'READY'}elseif($capability.status-eq'MISSING_NOT_WIRED'){'NOT_WIRED'}else{'INCOMPLETE'}}},
  [ordered]@{id='remote_access';state=if($remote.status-eq'HEALTHY_LOCAL_COMPONENTS'){'HEALTHY_LOCAL'}else{'DEGRADED'};raw_status=$remote.status;connector_status=$remote.gpt_connector.status},
  [ordered]@{id='control_center';state=$registryState.status;raw_status='REGISTRY_OBSERVED';action_count=$registryState.action_count}
 )
 $overall=if(@($surface|Where-Object{$_.state -in @('BLOCKED','DEGRADED')}).Count){'DEGRADED'}else{'HEALTHY'}
 [ordered]@{id='builder.overview';status='OVERVIEW_READY';overall=$overall;surfaces=$surface;blockers=@($blockers);impact=@($impact);recommended_next_action=$recommended;freshness=(Get-FreshnessEnvelope 60);source_actions=@('repo.status','school.status','agent.status','memory.status','inventory.status','capability.status','remote_access.status','control_center registry');does_not_prove=@('inventory semantic currentness unless inventory.diagnose is run','GPT connector/session health','capability readiness beyond the current map validator and attached proof')}
}
function Get-SchoolNotificationPlan{
 if([string]::IsNullOrWhiteSpace($SchoolProofPath)){return [ordered]@{id='school.notification.plan';status='SCHOOL_PROOF_PATH_REQUIRED';delivery_attempted=$false}}
 $full=[IO.Path]::GetFullPath((Join-Path $repo $SchoolProofPath));$repoFull=[IO.Path]::GetFullPath($repo);if(-not$full.StartsWith($repoFull,[StringComparison]::OrdinalIgnoreCase)){return [ordered]@{id='school.notification.plan';status='SCHOOL_PROOF_OUTSIDE_REPO';delivery_attempted=$false}}
 if(-not(Test-Path -LiteralPath $full -PathType Leaf)){return [ordered]@{id='school.notification.plan';status='SCHOOL_PROOF_NOT_FOUND';proof_path=$SchoolProofPath;delivery_attempted=$false}}
 try{$proof=Get-Content -LiteralPath $full -Raw|ConvertFrom-Json}catch{return [ordered]@{id='school.notification.plan';status='SCHOOL_PROOF_INVALID_JSON';proof_path=$SchoolProofPath;delivery_attempted=$false}}
 $required=@('status','run_id','public_mode','target_accepted','ready_atoms','finalizer_status');$missing=@($required|Where-Object{-not($proof.PSObject.Properties.Name -contains $_)-or$null-eq$proof.$_-or[string]::IsNullOrWhiteSpace([string]$proof.$_)});if($missing.Count){return [ordered]@{id='school.notification.plan';status='SCHOOL_PROOF_FIELDS_MISSING';missing_fields=[string[]]$missing;delivery_attempted=$false}}
 $proofPass=([string]$proof.status -like 'PASS_*');$accepted=[int]$proof.target_accepted;$ready=[int]$proof.ready_atoms;$topics=if($proof.PSObject.Properties.Name -contains 'requested_topics'){[string]$proof.requested_topics}else{''};$proofHash=(Get-FileHash -LiteralPath $full -Algorithm SHA256).Hash.ToLowerInvariant()
 $botPresent=![string]::IsNullOrWhiteSpace([Environment]::GetEnvironmentVariable('TELEGRAM_BOT_TOKEN','Process'));$chatPresent=![string]::IsNullOrWhiteSpace([Environment]::GetEnvironmentVariable('TELEGRAM_CHAT_ID','Process'));$transportReady=($botPresent-and$chatPresent)
 $resultLabel=if($proofPass){'PASS'}else{'FAILED'};$message=("School finished: {0} | run={1} | mode={2} | accepted={3}/{4} | topics={5} | finalizer={6}" -f $resultLabel,[string]$proof.run_id,[string]$proof.public_mode,$accepted,$ready,$topics,[string]$proof.finalizer_status)
 [ordered]@{id='school.notification.plan';status='NOTIFICATION_PLAN_READY';channel=$NotificationChannel;proof_path=$SchoolProofPath;proof_sha256=$proofHash;school=[ordered]@{run_id=[string]$proof.run_id;proof_status=[string]$proof.status;pass=$proofPass;mode=[string]$proof.public_mode;target_accepted=$accepted;ready_atoms=$ready;topics=$topics;finalizer_status=[string]$proof.finalizer_status};payload=[ordered]@{text=$message};credential_refs=[string[]]@('TELEGRAM_BOT_TOKEN','TELEGRAM_CHAT_ID');credential_presence=[ordered]@{bot_token=$botPresent;chat_id=$chatPresent};transport_state=if($transportReady){'READY_FOR_TRANSPORT'}else{'MISSING_CREDENTIALS'};delivery_attempted=$false;does_not_prove='notification_delivery_transport_configuration_or_future_school_completion'}
}
function Get-ManagedRunPhaseSummary{
 param([int]$RootPid,[bool]$IsActive)
 if(-not$IsActive-or$RootPid-le0){return [ordered]@{descendant_count=0;active_phase='not_active';phase_evidence=[string[]]@()}}
 $all=@(Get-CimInstance Win32_Process -ErrorAction SilentlyContinue);$ids=New-Object 'System.Collections.Generic.HashSet[int]';[void]$ids.Add($RootPid)
 for($depth=0;$depth-lt6;$depth++){foreach($proc in $all){if($ids.Contains([int]$proc.ParentProcessId)){[void]$ids.Add([int]$proc.ProcessId)}}}
 $desc=@($all|Where-Object{[int]$_.ProcessId-ne$RootPid-and$ids.Contains([int]$_.ProcessId)});$found=New-Object 'System.Collections.Generic.HashSet[string]'
 foreach($proc in $desc){$name=[string]$proc.Name;$cmd=[string]$proc.CommandLine;if($cmd -match '(?i)invoke_branch_agnostic_map_refresh_after_structural_change_001\.ps1'){[void]$found.Add('map_refresh')}elseif($cmd -match '(?i)validate_builder_control_center_v1\.ps1'){[void]$found.Add('control_center_validator')}elseif($cmd -match '(?i)validate_agent_body_composition_map_current_v1\.ps1'){[void]$found.Add('body_map_validator')}elseif($cmd -match '(?i)\.githooks[\\/]+pre-commit'-or($name -match '(?i)^sh\.exe$'-and$cmd -match '(?i)pre-commit')){[void]$found.Add('pre_commit_hook')}elseif($name -match '(?i)^git\.exe$'-and$cmd -match '(?i)\bcommit\b'){[void]$found.Add('git_commit')}elseif($name -match '(?i)^(powershell|pwsh)(\.exe)?$'){[void]$found.Add('powershell_child')}}
 $precedence=@('map_refresh','control_center_validator','body_map_validator','pre_commit_hook','git_commit','powershell_child');$evidence=[string[]]@($precedence|Where-Object{$found.Contains($_)});$phase=if($evidence.Count){$evidence[0]}elseif($desc.Count){'active_unclassified_descendant'}else{'active_no_descendant'}
 [ordered]@{descendant_count=[int]$desc.Count;active_phase=[string]$phase;phase_evidence=[string[]]$evidence}
}
function Get-ManagedRunStatus{
 $root='H:\bridge\runs'
 if([string]::IsNullOrWhiteSpace($RunId)){return [ordered]@{id='builder.run.status';status='RUN_ID_REQUIRED';run_id=$null;freshness=(Get-FreshnessEnvelope);does_not_prove='transport_health_mutation_authority_or_run_semantic_success'}}
 if($RunId -notmatch '^[A-Za-z0-9._-]+$'){return [ordered]@{id='builder.run.status';status='INVALID_RUN_ID';run_id=$RunId;freshness=(Get-FreshnessEnvelope);does_not_prove='transport_health_mutation_authority_or_run_semantic_success'}}
 if(-not(Test-Path $root -PathType Container)){return [ordered]@{id='builder.run.status';status='RUN_STORE_UNAVAILABLE';run_id=$RunId;run_store=$root;freshness=(Get-FreshnessEnvelope);does_not_prove='transport_health_mutation_authority_or_run_semantic_success'}}
 $dir=Join-Path $root $RunId;if(-not(Test-Path $dir -PathType Container)){return [ordered]@{id='builder.run.status';status='RUN_NOT_FOUND';run_id=$RunId;run_store=$root;freshness=(Get-FreshnessEnvelope);does_not_prove='transport_health_mutation_authority_or_run_semantic_success'}}
 $statePath=Join-Path $dir 'result.json';if(-not(Test-Path $statePath -PathType Leaf)){return [ordered]@{id='builder.run.status';status='RUN_STATE_MISSING';run_id=$RunId;run_dir=$dir;freshness=(Get-FreshnessEnvelope);does_not_prove='transport_health_mutation_authority_or_run_semantic_success'}}
 try{$s=Get-Content $statePath -Raw|ConvertFrom-Json}catch{return [ordered]@{id='builder.run.status';status='RUN_STATE_INVALID';run_id=$RunId;run_dir=$dir;error=$_.Exception.Message;freshness=(Get-FreshnessEnvelope);does_not_prove='transport_health_mutation_authority_or_run_semantic_success'}}
 $pidValue=0;if($null-ne$s.pid){$pidValue=[int]$s.pid};$observedAlive=$false;if($pidValue-gt0){$observedAlive=[bool](Get-Process -Id $pidValue -ErrorAction SilentlyContinue)}
 $sourceStatus=[string]$s.status;$exitCode=$s.exit_code;$timedOut=[bool]$s.timed_out
 $liveSourceStatuses=@('running','wait_expired_still_running');$isLiveSource=$liveSourceStatuses -contains $sourceStatus
 $status=if($timedOut){'TIMEOUT'}elseif($isLiveSource-and$observedAlive){'ACTIVE'}elseif($isLiveSource-and-not$observedAlive){'STALE_OR_UNFINALIZED'}elseif($sourceStatus-eq'completed_success'-and($null-eq$exitCode-or[int]$exitCode-eq0)){'PASS'}elseif($sourceStatus-match'fail|error'-or($null-ne$exitCode-and[int]$exitCode-ne0)){'FAILED'}else{'FINAL_OTHER'}
 $phase=Get-ManagedRunPhaseSummary -RootPid $pidValue -IsActive ($status -eq 'ACTIVE')
 $stdout=@();$stderr=@();$outPath=Join-Path $dir 'stdout.txt';$errPath=Join-Path $dir 'stderr.txt';if(Test-Path $outPath){$stdout=@(Get-Content $outPath -Tail $RunTailLines -ErrorAction SilentlyContinue|ForEach-Object{[string]$_})};if(Test-Path $errPath){$stderr=@(Get-Content $errPath -Tail $RunTailLines -ErrorAction SilentlyContinue|ForEach-Object{[string]$_})}
 [ordered]@{id='builder.run.status';status=[string]$status;run_id=[string]$RunId;source_status=[string]$sourceStatus;pid=[int]$pidValue;reported_process_alive=[bool]$s.process_alive;observed_process_alive=[bool]$observedAlive;exit_code=if($null-eq$exitCode){$null}else{[int]$exitCode};timed_out=[bool]$timedOut;started_at=[string]$s.started_at;last_seen_at=[string]$s.last_seen_at;checked_at=[string]$s.checked_at;finished_at=[string]$s.finished_at;elapsed_ms=if($null-eq$s.elapsed_ms){$null}else{[long]$s.elapsed_ms};run_dir=[string]$dir;state_path=[string]$statePath;stdout_tail=[string[]]$stdout;stderr_tail=[string[]]$stderr;tail_lines=[int]$RunTailLines;descendant_count=[int]$phase.descendant_count;active_phase=[string]$phase.active_phase;phase_evidence=[string[]]@($phase.phase_evidence);freshness=(Get-FreshnessEnvelope);does_not_prove='transport_health_mutation_authority_or_run_semantic_success'}
}function Invoke-AcceptanceVerify{
 if([string]::IsNullOrWhiteSpace($AcceptanceBaseHead)){return [ordered]@{id='builder.acceptance.verify';status='BLOCKED_ACCEPTANCE_BASE_HEAD_REQUIRED'}}
 if([string]::IsNullOrWhiteSpace($AcceptanceNewHead)){return [ordered]@{id='builder.acceptance.verify';status='BLOCKED_ACCEPTANCE_NEW_HEAD_REQUIRED'}}
 $ep=@($ExpectedPaths|Where-Object{$_}|ForEach-Object{$_.Replace('\','/')}|Sort-Object -Unique);if(-not$ep.Count){return [ordered]@{id='builder.acceptance.verify';status='BLOCKED_EXPECTED_PATHS_REQUIRED'}}
 $current=(git rev-parse HEAD).Trim();if($current-ne$AcceptanceNewHead){return [ordered]@{id='builder.acceptance.verify';status='BLOCKED_ACCEPTANCE_HEAD_MISMATCH';expected_new_head=$AcceptanceNewHead;actual_head=$current}}
 $parent=(git rev-parse ($AcceptanceNewHead+'^')).Trim();if($parent-ne$AcceptanceBaseHead){return [ordered]@{id='builder.acceptance.verify';status='BLOCKED_ACCEPTANCE_PARENT_MISMATCH';expected_base_head=$AcceptanceBaseHead;actual_parent=$parent}}
 $actual=@(git show --name-only --format= $AcceptanceNewHead|Where-Object{$_}|ForEach-Object{$_.Replace('\','/')}|Sort-Object -Unique);$scopeDiff=@(Compare-Object ($ep|Sort-Object) ($actual|Sort-Object));if($scopeDiff.Count){return [ordered]@{id='builder.acceptance.verify';status='BLOCKED_ACCEPTANCE_COMMIT_SCOPE_MISMATCH';expected_paths=@($ep);actual_commit_paths=@($actual)}}
 $dirtyBefore=@(git status --porcelain=v1 -uall);if($dirtyBefore.Count){return [ordered]@{id='builder.acceptance.verify';status='BLOCKED_ACCEPTANCE_REPO_DIRTY';dirty=@($dirtyBefore)}}
 $ccPath=Join-Path $repo 'validators/validate_builder_control_center_v1.ps1';$bodyPath=Join-Path $repo 'validators/validate_agent_body_composition_map_current_v1.ps1'
 $savedEap=$ErrorActionPreference;$ErrorActionPreference='Continue';try{$ccOut=@(& powershell -NoProfile -ExecutionPolicy Bypass -File $ccPath 2>&1|ForEach-Object{[string]$_});$ccExit=$LASTEXITCODE;$bodyOut=@(& powershell -NoProfile -ExecutionPolicy Bypass -File $bodyPath 2>&1|ForEach-Object{[string]$_});$bodyExit=$LASTEXITCODE}finally{$ErrorActionPreference=$savedEap}
 $ccPass=($ccExit-eq0-and@($ccOut|Where-Object{$_ -match '^PASS_BUILDER_CONTROL_CENTER_V4\|ACTIONS=\d+\|DIAGNOSE_ROUTES=\d+\|OVERVIEW=PASS\|REMOTE_SCOPE=PASS\|MULTI_DIAG=PASS\|LIVE_MUTATION=0\|TRACKED_MUTATION=0\|RUNTIME_STARTED=0$'}).Count-gt0);$bodyPass=($bodyExit-eq0-and@($bodyOut|Where-Object{$_ -like 'STATUS=PASS_AGENT_BODY_COMPOSITION_MAP_CURRENT_V1*'}).Count-gt0)
 $dirtyAfter=@(git status --porcelain=v1 -uall);$pf=Get-BuilderPreflight;$candidate=Get-CandidateStatus;$plan=Get-AcceptancePlan;$cleanChain=($pf.status-eq'PREFLIGHT_PASS'-and$pf.mutation_ready-and$dirtyAfter.Count-eq0-and$plan.status-eq'ACCEPTANCE_PLAN_BLOCKED_CANDIDATE_SCOPE'-and-not$plan.plan_ready)
 $ok=($ccPass-and$bodyPass-and$dirtyAfter.Count-eq0-and$cleanChain);[ordered]@{id='builder.acceptance.verify';status=if($ok){'ACCEPTANCE_VERIFIED'}else{'ACCEPTANCE_VERIFY_FAILED'};base_head=$AcceptanceBaseHead;new_head=$AcceptanceNewHead;expected_paths=@($ep);actual_commit_paths=@($actual);control_center_validator=[ordered]@{path='validators/validate_builder_control_center_v1.ps1';exit_code=$ccExit;pass=$ccPass;tail=@($ccOut|Select-Object -Last 8)};body_map_validator=[ordered]@{path='validators/validate_agent_body_composition_map_current_v1.ps1';exit_code=$bodyExit;pass=$bodyPass;tail=@($bodyOut|Select-Object -Last 8)};repo_clean_after=($dirtyAfter.Count-eq0);clean_chain_pass=$cleanChain;preflight=$pf;candidate=$candidate;acceptance_plan=$plan;freshness=(Get-FreshnessEnvelope);does_not_prove='mutation_authority_remote_push_live_proof_or_future_acceptance'}
}function Get-CheckpointAuthority{
 if([string]::IsNullOrWhiteSpace($AuthorityPassportJson)){return [ordered]@{status='BLOCKED_AUTHORITY';reason='AUTHORITY_PASSPORT_REQUIRED'}}
 try{$p=$AuthorityPassportJson|ConvertFrom-Json}catch{return [ordered]@{status='BLOCKED_AUTHORITY';reason='AUTHORITY_PASSPORT_INVALID_JSON'}}
 $required=@('source','actor','action_class','target_surface','environment','scope','expiry','safety_boundary','checkpoint','rollback','validator')
 $missing=@($required|Where-Object{$prop=$p.PSObject.Properties[$_];$null-eq$prop -or [string]::IsNullOrWhiteSpace([string]$prop.Value)})
 if($missing.Count){return [ordered]@{status='BLOCKED_AUTHORITY';reason='AUTHORITY_PASSPORT_INCOMPLETE';missing=@($missing)}}
 if([string]$p.action_class -ne 'LAB_MUTATE'){return [ordered]@{status='BLOCKED_AUTHORITY';reason='AUTHORITY_ACTION_CLASS_NOT_LAB_MUTATE';action_class=[string]$p.action_class}}
 [ordered]@{status='VALID';passport=$p}
}function Get-CheckpointReadiness{
 $auth=Get-CheckpointAuthority;if($auth.status-ne'VALID'){return [ordered]@{id='builder.checkpoint.create';status=$auth.status;reason=$auth.reason;missing=@($auth.missing)}}
 if([string]::IsNullOrWhiteSpace($ExpectedHead)){return [ordered]@{id='builder.checkpoint.create';status='BLOCKED_EXPECTED_HEAD_REQUIRED'}}
 if([string]::IsNullOrWhiteSpace($CommitMessage)){return [ordered]@{id='builder.checkpoint.create';status='BLOCKED_COMMIT_MESSAGE_REQUIRED'}}
 $ep=@($ExpectedPaths|Where-Object{$_}|ForEach-Object{$_.Replace('\','/')}|Sort-Object -Unique);if(-not$ep.Count){return [ordered]@{id='builder.checkpoint.create';status='BLOCKED_EXPECTED_PATHS_REQUIRED'}}
 $head=(git rev-parse HEAD).Trim();if($head-ne$ExpectedHead){return [ordered]@{id='builder.checkpoint.create';status='BLOCKED_HEAD_MISMATCH';expected_head=$ExpectedHead;actual_head=$head}}
 $staged=@(git diff --cached --name-only|Where-Object{$_}|Sort-Object -Unique);if($staged.Count){return [ordered]@{id='builder.checkpoint.create';status='BLOCKED_PREEXISTING_STAGED';staged_paths=@($staged)}}
 $candidate=Get-CandidateStatus;if($candidate.status-ne'SCOPE_MATCH'){return [ordered]@{id='builder.checkpoint.create';status='BLOCKED_CANDIDATE_SCOPE';candidate=$candidate}}
 $plan=Get-AcceptancePlan;if(-not$plan.plan_ready-or$plan.status -notin @('ACCEPTANCE_PLAN_READY','ACCEPTANCE_PLAN_READY_NO_PRECOMMIT_HOOK')){return [ordered]@{id='builder.checkpoint.create';status='BLOCKED_ACCEPTANCE_PLAN';acceptance_plan=$plan}}
 [ordered]@{id='builder.checkpoint.create';status='READY';base_head=$head;expected_paths=@($ep);authority=$auth.passport;acceptance_plan=$plan;does_not_prove='semantic_acceptance_validator_pass_remote_push_or_future_mutation_authority'}
}function Invoke-CheckpointCreate{
 $ready=Get-CheckpointReadiness;if($ready.status-ne'READY'){return $ready}
 if(-not$ConfirmMutation){return [ordered]@{id='builder.checkpoint.create';status='BLOCKED_CONFIRMATION_REQUIRED';reason='ConfirmMutation required';base_head=$ready.base_head}}
 $base=[string]$ready.base_head;$ep=@($ready.expected_paths);$plan=$ready.acceptance_plan
 & git add -- $ep | Out-Null;$addExit=$LASTEXITCODE;if($addExit-ne0){$now=@(git diff --cached --name-only);if($now.Count){& git restore --staged -- $now|Out-Null};return [ordered]@{id='builder.checkpoint.create';status='CHECKPOINT_STAGE_FAILED';base_head=$base;exit_code=$addExit;expected_paths=@($ep)}}
 $staged=@(git diff --cached --name-only|Where-Object{$_}|Sort-Object -Unique);if(@(Compare-Object ($ep|Sort-Object) $staged).Count){if($staged.Count){& git restore --staged -- $staged|Out-Null};return [ordered]@{id='builder.checkpoint.create';status='CHECKPOINT_STAGE_SCOPE_FAILED';base_head=$base;expected_paths=@($ep);staged_paths=@($staged)}}
 $savedEap=$ErrorActionPreference;$ErrorActionPreference='Continue';try{$commitOut=@(& git commit -m $CommitMessage 2>&1|ForEach-Object{[string]$_});$commitExit=$LASTEXITCODE}finally{$ErrorActionPreference=$savedEap};$new=(git rev-parse HEAD).Trim()
 if($new-eq$base){$now=@(git diff --cached --name-only|Where-Object{$_}|Sort-Object -Unique);if($now.Count){& git restore --staged -- $now|Out-Null};return [ordered]@{id='builder.checkpoint.create';status='CHECKPOINT_COMMIT_FAILED_PRE_HEAD_CHANGE';base_head=$base;head=$new;exit_code=$commitExit;commit_output=@($commitOut);worktree_candidate_preserved=$true;does_not_prove='semantic_acceptance_validator_pass_remote_push_or_future_mutation_authority'}}
 $actual=@(git show --name-only --format= $new|Where-Object{$_}|Sort-Object -Unique);$expectedFinal=@($plan.expected_final_commit_paths|Where-Object{$_}|Sort-Object -Unique);$missing=@($ep|Where-Object{$actual -notcontains $_});$extra=@($actual|Where-Object{$expectedFinal -notcontains $_});$postBad=($commitExit-ne0-or$missing.Count-or$extra.Count)
 [ordered]@{id='builder.checkpoint.create';status=if($postBad){'CHECKPOINT_CREATED_POST_PROOF_FAILED'}else{'CHECKPOINT_CREATED'};base_head=$base;new_head=$new;commit_exit=$commitExit;commit_message=$CommitMessage;explicit_paths=@($ep);actual_commit_paths=@($actual);expected_final_commit_paths=@($expectedFinal);missing_explicit_paths=@($missing);unexpected_commit_paths=@($extra);pre_commit_path=$plan.pre_commit_path;pre_commit_sha256=$plan.pre_commit_sha256;authority=$ready.authority;freshness=(Get-FreshnessEnvelope);does_not_prove='semantic_acceptance_validator_pass_remote_push_or_future_mutation_authority'}
}function Get-AcceptancePlan{
 $candidate=Get-CandidateStatus
 $hooksPath=(git config --get core.hooksPath);if($LASTEXITCODE-ne0){$hooksPath=$null};$hooksPath=([string]$hooksPath).Trim()
 $preCommit=if([string]::IsNullOrWhiteSpace($hooksPath)){'.git/hooks/pre-commit'}else{(Join-Path $hooksPath 'pre-commit').Replace('\','/')}
 $hookExists=Test-Path $preCommit -PathType Leaf;$hookHash=if($hookExists){(Get-FileHash $preCommit -Algorithm SHA256).Hash}else{$null}
 $auto=@();$hookValidators=@()
 if($hookExists){ foreach($line in Get-Content $preCommit){ if($line -match '^\s*git\s+add\s+(.+?)\s*$'){ $tail=$Matches[1];$auto+=@($tail -split '\s+'|Where-Object{$_ -and $_ -notmatch '^-' }|ForEach-Object{$_.Trim('"','''').Replace('\','/')}) }; if($line -match '(?i)-File\s+([^\s|;]+)'){ $ref=$Matches[1].Trim('"','''').Replace('\','/');if($ref -like 'validators/*'){$hookValidators+=$ref} } } }
 $auto=@($auto|Sort-Object -Unique);$hookValidators=@($hookValidators|Sort-Object -Unique);$expectedFinal=@(@($candidate.expected_paths)+@($auto)|Where-Object{$_}|Sort-Object -Unique)
 $status=if($candidate.status-ne'SCOPE_MATCH'){'ACCEPTANCE_PLAN_BLOCKED_CANDIDATE_SCOPE'}elseif(-not$hookExists){'ACCEPTANCE_PLAN_READY_NO_PRECOMMIT_HOOK'}else{'ACCEPTANCE_PLAN_READY'}
 [ordered]@{id='builder.acceptance.plan';status=$status;plan_ready=($candidate.status-eq'SCOPE_MATCH');candidate=$candidate;hooks_path=$hooksPath;pre_commit_path=$preCommit;pre_commit_exists=$hookExists;pre_commit_sha256=$hookHash;hook_auto_staged_paths=@($auto);hook_validator_refs=@($hookValidators);expected_final_commit_paths=@($expectedFinal);freshness=(Get-FreshnessEnvelope);does_not_prove='mutation_authority_validator_pass_commit_success_or_acceptance'}
}function Get-CandidateStatus{
 $staged=@(git diff --cached --name-only --diff-filter=ACDMRTUXB|Where-Object{$_}|Sort-Object -Unique)
 $unstaged=@(git diff --name-only --diff-filter=ACDMRTUXB|Where-Object{$_}|Sort-Object -Unique)
 $untracked=@(git ls-files --others --exclude-standard|Where-Object{$_}|Sort-Object -Unique)
 $actual=@(@($staged)+@($unstaged)+@($untracked)|ForEach-Object{([string]$_).Replace('\','/')}|Sort-Object -Unique)
 $expected=@($ExpectedPaths|Where-Object{$_}|ForEach-Object{([string]$_).Replace('\','/')}|Sort-Object -Unique)
 $unexpected=if($expected.Count){@(Compare-Object $expected $actual|Where-Object SideIndicator -eq '=>'|ForEach-Object InputObject)}else{@()}
 $missing=if($expected.Count){@(Compare-Object $expected $actual|Where-Object SideIndicator -eq '<='|ForEach-Object InputObject)}else{@()}
 $scopeStatus=if(-not$actual.Count){if($expected.Count){'SCOPE_MISMATCH'}else{'NO_CANDIDATE'}}elseif(-not$expected.Count){'CANDIDATE_SCOPE_UNSPECIFIED'}elseif($unexpected.Count-or$missing.Count){'SCOPE_MISMATCH'}else{'SCOPE_MATCH'}
 [ordered]@{id='builder.candidate.status';status=$scopeStatus;scope_ready=($actual.Count-gt0-and$expected.Count-gt0-and-not$unexpected.Count-and-not$missing.Count);head=(git rev-parse HEAD).Trim();branch=(git branch --show-current).Trim();actual_paths=@($actual);staged_paths=@($staged);unstaged_paths=@($unstaged);untracked_paths=@($untracked);expected_paths=@($expected);unexpected_paths=@($unexpected);missing_expected_paths=@($missing);freshness=(Get-FreshnessEnvelope);does_not_prove='mutation_authority_semantic_correctness_or_acceptance'}
}function Get-BuilderPreflight{
 $repoState=Get-RepoStatus;$school=Get-SchoolStatus;$agent=Get-AgentStatus;$memory=Get-MemoryStatus;$blockers=@()
 if($repoState.status -ne 'CLEAN'){$blockers+='REPO_DIRTY'}
 if($school.status -eq 'RUNNING'){$blockers+='SCHOOL_RUNTIME_ACTIVE'}
 if($agent.status -eq 'RUNNING'){$blockers+='AGENT_RUNTIME_ACTIVE'}
 if($memory.status -ne 'PRESENT'){$blockers+='ACTIVE_MEMORY_NOT_READY'}
 $agents=if(Test-Path 'AGENTS.md'){'AGENTS.md'}else{$null};if(-not$agents){$blockers+='APPLICABLE_AGENTS_MISSING'}
 [ordered]@{id='builder.preflight';status=if($blockers.Count){'PREFLIGHT_BLOCKED'}else{'PREFLIGHT_PASS'};mutation_ready=($blockers.Count-eq0);repo=$repoState;runtime=[ordered]@{school=$school;agent=$agent};protected_memory=[ordered]@{status=$memory.status;root=$memory.root;cell_count=$memory.cell_count;protected=$true};applicable_agents=$agents;blockers=@($blockers);freshness=(Get-FreshnessEnvelope);does_not_prove='mutation_authority_or_action_completion'}
}function Invoke-Diagnostic([string]$Id){
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
  if($cap.status -eq 'MISSING_NOT_WIRED'){return [ordered]@{id=$Id;status='DIAGNOSTIC_COMPLETE_WITH_BLOCKER';capability=$cap;blocker='CAPABILITY_MAP_MISSING_NOT_WIRED';validator='operations/self_model/validate_capability_invocation_map_v1.ps1';validator_invoked=$false}}
  $before=@(git status --porcelain=v1 -uall);$validator='operations/self_model/validate_capability_invocation_map_v1.ps1';$output=& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $validator 2>&1|Out-String;$exit=$LASTEXITCODE;$after=@(git status --porcelain=v1 -uall)
  if(($before-join "`n") -ne ($after-join "`n")){throw 'CAPABILITY_DIAGNOSTIC_TRACKED_MUTATION'}
  if($exit-ne0){return [ordered]@{id=$Id;status='DIAGNOSTIC_FAIL';capability=$cap;validator=$validator;validator_exit=$exit;output=$output.Trim()}}
  return [ordered]@{id=$Id;status=if($cap.status-eq'PRESENT_READY'){'DIAGNOSTIC_PASS'}else{'DIAGNOSTIC_PASS_WITH_GAPS'};capability=$cap;validator=$validator;validator_exit=$exit;validator_invoked=$true;output=$output.Trim()}
 }
 if($Id -eq 'builder.acceptance.verify'){return Invoke-AcceptanceVerify}
 if($Id -eq 'school.notification.plan'){return Get-SchoolNotificationPlan}
 if($Id -eq 'builder.run.status'){return Get-ManagedRunStatus}
 if($Id -eq 'builder.acceptance.plan'){return Get-AcceptancePlan}
 if($Id -eq 'builder.candidate.status'){return Get-CandidateStatus}
 if($Id -eq 'builder.preflight'){return Get-BuilderPreflight}
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
function Invoke-Observed([string]$Id){switch($Id){'repo.status'{Get-RepoStatus}'school.status'{Get-SchoolStatus}'agent.status'{Get-AgentStatus}'inventory.status'{Get-InventoryStatus}'capability.status'{Get-CapabilityStatus}'memory.status'{Get-MemoryStatus}'builder.status'{[ordered]@{id='builder.status';status='OBSERVED';repo=(Get-RepoStatus);school=(Get-SchoolStatus);agent=(Get-AgentStatus);inventory=(Get-InventoryStatus);capability=(Get-CapabilityStatus);memory=(Get-MemoryStatus)}}'builder.overview'{Get-BuilderOverview}'remote_access.status'{Get-RemoteAccessStatus}'school.start'{Get-StartReadiness 'school.start'}'agent.start'{Get-StartReadiness 'agent.start'}default{throw"CONTROL_CENTER_HANDLER_NOT_IMPLEMENTED:$Id"}}}
function Invoke-Start([string]$Id){
 $ready=Get-StartReadiness $Id
 if($ready.status -ne 'READY'){return $ready}
 if(-not $ConfirmMutation){return [ordered]@{id=$Id;status='BLOCKED_CONFIRMATION_REQUIRED';reason='ConfirmMutation required';canonical_entrypoint=$ready.canonical_entrypoint}}
 if($Id -eq 'school.notification.send'){
   $plan=Get-SchoolNotificationPlan
   $token=[Environment]::GetEnvironmentVariable('TELEGRAM_BOT_TOKEN','Process');$chat=[Environment]::GetEnvironmentVariable('TELEGRAM_CHAT_ID','Process')
   if([string]::IsNullOrWhiteSpace($token)-or[string]::IsNullOrWhiteSpace($chat)){return [ordered]@{id=$Id;status='BLOCKED_CREDENTIALS_REQUIRED';delivery_attempted=$false}}
   $uri='https://api.telegram.org/bot'+$token+'/sendMessage'
   try{$resp=Invoke-RestMethod -Method Post -Uri $uri -Body @{chat_id=$chat;text=[string]$plan.payload.text} -ContentType 'application/x-www-form-urlencoded' -ErrorAction Stop;if(-not[bool]$resp.ok){return [ordered]@{id=$Id;status='DELIVERY_FAILED';channel='telegram';proof_sha256=[string]$plan.proof_sha256;delivery_attempted=$true;error_class='TELEGRAM_API_REJECTED'}};return [ordered]@{id=$Id;status='DELIVERED';channel='telegram';proof_sha256=[string]$plan.proof_sha256;delivery_attempted=$true;telegram=[ordered]@{message_id=[int64]$resp.result.message_id;date=[int64]$resp.result.date};does_not_prove='future_delivery_or_future_school_completion'}}catch{return [ordered]@{id=$Id;status='DELIVERY_FAILED';channel='telegram';proof_sha256=[string]$plan.proof_sha256;delivery_attempted=$true;error_class='TELEGRAM_API_OR_TRANSPORT_FAILURE'}}
 }
 if($Id -eq 'school.start'){
   $retention='operations/school/cleanup_completed_school_runtime_v1.ps1';if(-not(Test-Path $retention)){throw 'SCHOOL_RUNTIME_RETENTION_MISSING'};& $retention -RepoRoot $repo -KeepLatestCompletedRoot 1 -KeepLatestCheckpoints 3 -ProofPath '.runtime/school_retention_v1/LAST_CLEANUP_PROOF.json'|Out-Null;if($LASTEXITCODE-ne0){throw 'SCHOOL_RUNTIME_RETENTION_FAILED'}
   $args=@('-NoProfile','-ExecutionPolicy','Bypass','-File','operations/school/run_agent_school.ps1','-Count',[string]$SchoolCount,'-Mode',$SchoolMode,'-Topics',$SchoolTopics)
   $proc=Start-Process -FilePath 'powershell.exe' -ArgumentList $args -WorkingDirectory $repo -PassThru
   return [ordered]@{id=$Id;status='STARTED';pid=$proc.Id;canonical_entrypoint='operations/school/run_agent_school.ps1';parameters=$ready.parameters}
 }
 if($Id -eq 'school.stop'){
   $stopPath=[string]$ready.parameters.StopPath;$dir=Split-Path -Parent $stopPath;if(-not(Test-Path $dir)){New-Item -ItemType Directory -Force -Path $dir|Out-Null};$tmp=$stopPath+'.tmp.'+[guid]::NewGuid().ToString('N');[ordered]@{schema='school_stop_request_v1';status='REQUESTED';requested_at=(Get-Date).ToString('o');run_id=[string]$ready.parameters.RunId;actor='BUILDER_CONTROL_CENTER'}|ConvertTo-Json -Depth 8|Set-Content -LiteralPath $tmp -Encoding UTF8;Move-Item -LiteralPath $tmp -Destination $stopPath -Force;return [ordered]@{id=$Id;status='STOP_REQUESTED';canonical_entrypoint='operations/school/run_agent_school.ps1';stop_path=$stopPath;run_id=[string]$ready.parameters.RunId;does_not_prove='pause_acknowledged_or_resume_success'}
 }
 if($Id -eq 'school.resume'){
   $args=@('-NoProfile','-ExecutionPolicy','Bypass','-File','operations/school/run_agent_school.ps1','-Count',[string]$ready.parameters.Count,'-Mode',[string]$ready.parameters.Mode,'-Topics',[string]$ready.parameters.Topics)
   $proc=Start-Process -FilePath 'powershell.exe' -ArgumentList $args -WorkingDirectory $repo -PassThru
   return [ordered]@{id=$Id;status='STARTED';pid=$proc.Id;canonical_entrypoint='operations/school/run_agent_school.ps1';parameters=$ready.parameters;resume_source='pending_request';does_not_prove='successful_resumed_school_completion'}
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
 $readiness=@();foreach($a in $selected){if($a.group -eq 'DIAGNOSE'){$readiness+=,[ordered]@{id=$a.id;status='READY_DIAGNOSTIC'}}elseif([bool]$a.read_only){$readiness+=,[ordered]@{id=$a.id;status='READY_READ_ONLY'}}elseif($a.id -eq 'builder.checkpoint.create'){$readiness+=,(Get-CheckpointReadiness)}else{$readiness+=,(Get-StartReadiness $a.id)}}
 $blocked=@($readiness|Where-Object{$_.status -notin @('READY','READY_READ_ONLY','READY_DIAGNOSTIC')})
 $out=[ordered]@{status=if($conflicts.Count){'BLOCKED_CONFLICT'}elseif($blocked.Count){'BLOCKED'}else{'READY'};selected=@($selected.id);count=$selected.Count;mutation_count=@($selected|Where-Object{-not[bool]$_.read_only}).Count;diagnostic_count=@($selected|Where-Object{$_.group -eq 'DIAGNOSE'}).Count;live_mutation_count=@($selected|Where-Object{$_.kind -eq 'LIVE_MUTATE'}).Count;remote_mutation_count=@($selected|Where-Object{$_.kind -eq 'REMOTE_MUTATE'}).Count;parallel_safe=(@($selected|Where-Object{-not[bool]$_.parallel_safe}).Count -eq 0);execution_mode=if(@($selected|Where-Object{-not[bool]$_.parallel_safe}).Count){'SEQUENTIAL'}else{'PARALLEL_SAFE'};conflicts=@($conflicts);readiness=@($readiness)}
}
else{
 if(-not$Action.Count){throw'CONTROL_CENTER_ACTION_REQUIRED'}
 $plan=& $PSCommandPath -Mode Plan -Action $Action -Json -SchoolCount $SchoolCount -SchoolMode $SchoolMode -SchoolTopics $SchoolTopics -AgentDurationMinutes $AgentDurationMinutes -ExpectedPaths $ExpectedPaths -RunId $RunId -RunTailLines $RunTailLines -ExpectedHead $ExpectedHead -CommitMessage $CommitMessage -AuthorityPassportJson $AuthorityPassportJson -SchoolProofPath $SchoolProofPath|ConvertFrom-Json
 if($plan.status -ne 'READY'){ $out=[ordered]@{status='NOT_STARTED';plan=$plan} }
 else{
    $results=@();foreach($id in $Action){$a=Get-Reg $id;if($a.group -eq 'DIAGNOSE'){$results+=,(Invoke-Diagnostic $id)}elseif([bool]$a.read_only){$results+=,(Invoke-Observed $id)}elseif($id -eq 'builder.checkpoint.create'){$results+=,(Invoke-CheckpointCreate)}else{$results+=,(Invoke-Start $id)}}
    $checkpointResult=@($results|Where-Object{$_.id -eq 'builder.checkpoint.create'})|Select-Object -First 1;$deliveryResult=@($results|Where-Object{$_.id -eq 'school.notification.send'})|Select-Object -First 1;$out=[ordered]@{status=if($checkpointResult){[string]$checkpointResult.status}elseif($deliveryResult){if($deliveryResult.status -eq 'DELIVERED'){'REMOTE_MUTATION_COMPLETED'}elseif($deliveryResult.status -eq 'DELIVERY_FAILED'){'REMOTE_MUTATION_FAILED'}else{[string]$deliveryResult.status}}elseif(@($results|Where-Object{$_.status -eq 'STOP_REQUESTED'}).Count){'LIVE_MUTATION_COMPLETED'}elseif(@($results|Where-Object{$_.status -eq 'STARTED'}).Count){'START_DISPATCHED'}elseif(@($results|Where-Object{$_.status -eq 'BLOCKED_CONFIRMATION_REQUIRED'}).Count){'BLOCKED_CONFIRMATION_REQUIRED'}elseif(@($Action|Where-Object{(Get-Reg $_).group -eq 'DIAGNOSE'}).Count){'PASS_DIAGNOSTIC_RUN'}else{'PASS_READ_ONLY_RUN'};selected=@($Action);results=@($results)}
 }
}
if($Json){$out|ConvertTo-Json -Depth 14 -Compress}else{$out|ConvertTo-Json -Depth 14}
