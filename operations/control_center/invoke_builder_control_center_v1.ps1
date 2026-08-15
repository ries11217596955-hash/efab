[CmdletBinding()]
param(
  [ValidateSet('List','Plan','Run')][string]$Mode='List',
  [string[]]$Action=@(),
  [switch]$Json
)
$ErrorActionPreference='Stop'
$repo=(git rev-parse --show-toplevel).Trim()
Set-Location $repo
$registry=Get-Content 'operations/control_center/BUILDER_CONTROL_CENTER_REGISTRY_V1.json' -Raw | ConvertFrom-Json
$actions=@($registry.actions)
function Get-Reg([string]$Id){ @($actions | Where-Object { $_.id -eq $Id }) | Select-Object -First 1 }
function Get-RepoStatus { $d=@(git status --porcelain=v1); [ordered]@{id='repo.status';status=if($d.Count){'DIRTY'}else{'CLEAN'};head=(git rev-parse HEAD).Trim();dirty_count=$d.Count} }
function Get-SchoolStatus {
  $p=@(Get-CimInstance Win32_Process | Where-Object { $_.ProcessId -ne $PID -and $_.CommandLine -and $_.CommandLine -notmatch 'invoke_builder_control_center_v1.ps1' -and $_.CommandLine -match '(?i)run_agent_school\.ps1|canonical_exact_count_cycle_real_|Invoke-SchoolWarehouseConsumer|codex_school_task_template_strength' })
  $pending='.runtime/school_resume_v1/pending_request.json'; $queue='.runtime/school_resume_v1/queue'; $qc=0
  if(Test-Path $queue){ $qc=@(Get-ChildItem $queue -File -Filter 'request_*.json').Count }
  [ordered]@{id='school.status';status=if($p.Count){'RUNNING'}elseif((Test-Path $pending)-or $qc){'RECOVERY_OR_QUEUED'}else{'STOPPED'};process_count=$p.Count;pending=(Test-Path $pending);queue_count=$qc}
}
function Get-AgentStatus { $p=@(Get-CimInstance Win32_Process | Where-Object { $_.ProcessId -ne $PID -and $_.CommandLine -and $_.CommandLine -notmatch 'invoke_builder_control_center_v1.ps1' -and $_.CommandLine -match '(?i)start_agent_life_v1\.ps1|run_autonomous_inner_motor\.ps1|continuous_agent_runtime_v1' }); [ordered]@{id='agent.status';status=if($p.Count){'RUNNING'}else{'STOPPED'};process_count=$p.Count} }
function Get-InventoryStatus { $p='reports/self_development/agent_body_map.json'; if(-not(Test-Path $p)){ return [ordered]@{id='inventory.status';status='MISSING'} }; $j=Get-Content $p -Raw|ConvertFrom-Json; [ordered]@{id='inventory.status';status='PRESENT';component_count=@($j.components).Count;fingerprint=$j.body_source_fingerprint.sha256} }
function Get-CapabilityStatus { $a='reports/self_development/CAPABILITY_INVOCATION_MAP_V1.json'; $c='self_model/CAPABILITY_INVOCATION_MAP_V1_CONTRACT.json'; $cs=$null; if(Test-Path $c){$cs=(Get-Content $c -Raw|ConvertFrom-Json).status}; [ordered]@{id='capability.status';status=if(Test-Path $a){'PRESENT'}else{'MISSING_NOT_WIRED'};contract_status=$cs} }
function Get-MemoryStatus { $root='.runtime/active_compact_semantic_memory_v1'; $m=@('manifest.json','index.json','cells.jsonl') | Where-Object { -not(Test-Path (Join-Path $root $_)) }; $n=$null; if(-not $m.Count){$n=@(Get-Content (Join-Path $root 'cells.jsonl')).Count}; [ordered]@{id='memory.status';status=if($m.Count){'INCOMPLETE'}else{'PRESENT'};cell_count=$n;missing=@($m)} }
function Invoke-One([string]$Id){ switch($Id){ 'repo.status'{Get-RepoStatus} 'school.status'{Get-SchoolStatus} 'agent.status'{Get-AgentStatus} 'inventory.status'{Get-InventoryStatus} 'capability.status'{Get-CapabilityStatus} 'memory.status'{Get-MemoryStatus} 'builder.status'{[ordered]@{id='builder.status';status='OBSERVED';repo=(Get-RepoStatus);school=(Get-SchoolStatus);agent=(Get-AgentStatus);inventory=(Get-InventoryStatus);capability=(Get-CapabilityStatus);memory=(Get-MemoryStatus)}} default{throw "CONTROL_CENTER_HANDLER_NOT_IMPLEMENTED:$Id"} } }
if($Mode -eq 'List'){
  $out=@($actions | ForEach-Object { [ordered]@{id=$_.id;title=$_.title;group=$_.group;kind=$_.kind;read_only=[bool]$_.read_only;parallel_safe=[bool]$_.parallel_safe} })
}elseif($Mode -eq 'Plan'){
  if(-not $Action.Count){throw 'CONTROL_CENTER_ACTION_REQUIRED'}
  $selected=@(); foreach($id in $Action){$a=Get-Reg $id;if(-not $a){throw "CONTROL_CENTER_UNKNOWN_ACTION:$id"};$selected+=$a}
  $mut=@($selected | Where-Object { -not [bool]$_.read_only })
  $out=[ordered]@{status=if($mut.Count){'BLOCKED_MUTATION_NOT_ENABLED_V1'}else{'READY'};selected=@($selected.id);count=$selected.Count;mutation_count=$mut.Count;parallel_safe=(@($selected|Where-Object{-not [bool]$_.parallel_safe}).Count -eq 0)}
}else{
  if(-not $Action.Count){throw 'CONTROL_CENTER_ACTION_REQUIRED'}
  $plan=& $PSCommandPath -Mode Plan -Action $Action -Json | ConvertFrom-Json
  if($plan.status -ne 'READY'){throw "CONTROL_CENTER_PLAN_NOT_READY:$($plan.status)"}
  $results=@(); foreach($id in $Action){$results+=,(Invoke-One $id)}
  $out=[ordered]@{status='PASS_READ_ONLY_RUN';selected=@($Action);results=@($results)}
}
if($Json){$out|ConvertTo-Json -Depth 12 -Compress}else{$out|ConvertTo-Json -Depth 12}
