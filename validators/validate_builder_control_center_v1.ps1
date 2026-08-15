[CmdletBinding()]param()
$ErrorActionPreference='Stop'
$root=(git rev-parse --show-toplevel).Trim();Set-Location $root
$reg='operations/control_center/BUILDER_CONTROL_CENTER_REGISTRY_V1.json';$ctl='operations/control_center/invoke_builder_control_center_v1.ps1'
foreach($f in @($reg,$ctl)){if(-not(Test-Path $f)){throw "MISSING:$f"}}
$r=Get-Content $reg -Raw|ConvertFrom-Json
if($r.schema -ne 'builder_control_center_registry_v1'){throw 'REGISTRY_SCHEMA_BAD'}
$ids=@($r.actions.id);if($ids.Count -ne @($ids|Sort-Object -Unique).Count){throw 'DUPLICATE_ACTION_ID'}
$need=@('builder.status','repo.status','school.status','agent.status','inventory.status','capability.status','memory.status','school.start','agent.start');foreach($id in $need){if($ids -notcontains $id){throw "MISSING_ACTION:$id"}}
$schoolStart=@($r.actions|Where-Object id -eq 'school.start')|Select-Object -First 1
$agentStart=@($r.actions|Where-Object id -eq 'agent.start')|Select-Object -First 1
if($schoolStart.canonical_entrypoint -ne 'operations/school/run_agent_school.ps1'){throw 'SCHOOL_ENTRYPOINT_BAD'}
if($agentStart.canonical_entrypoint -ne 'operations/autonomous_inner_motor/start_agent_life_v1.ps1'){throw 'AGENT_ENTRYPOINT_BAD'}
$tok=$null;$err=$null;[void][System.Management.Automation.Language.Parser]::ParseFile((Resolve-Path $ctl),[ref]$tok,[ref]$err);if($err.Count){throw ('CONTROL_PARSE_FAIL:'+($err.Message -join ';'))}
$before=@(git status --porcelain=v1 -uall);$mr='.runtime/active_compact_semantic_memory_v1';$mh=@{};foreach($n in @('manifest.json','index.json','cells.jsonl')){$x=Join-Path $mr $n;if(Test-Path $x){$mh[$n]=(Get-FileHash -Algorithm SHA256 $x).Hash}}
$procBefore=@(Get-CimInstance Win32_Process|Where-Object{$_.CommandLine -and $_.CommandLine -match '(?i)run_agent_school\.ps1|start_agent_life_v1\.ps1'}|Select-Object -ExpandProperty ProcessId)
$list=& $ctl -Mode List -Json|ConvertFrom-Json;if(@($list).Count -ne 9){throw 'LIST_ACTION_COUNT_BAD'}
$selection=@('inventory.status','capability.status','memory.status');$plan=& $ctl -Mode Plan -Action $selection -Json|ConvertFrom-Json;if($plan.status -ne 'READY' -or [int]$plan.count -ne 3 -or -not [bool]$plan.parallel_safe){throw 'MULTISELECT_PLAN_BAD'}
$run=& $ctl -Mode Run -Action $selection -Json|ConvertFrom-Json;if($run.status -ne 'PASS_READ_ONLY_RUN' -or @($run.results).Count -ne 3){throw 'MULTISELECT_RUN_BAD'}
$overall=& $ctl -Mode Run -Action @('builder.status') -Json|ConvertFrom-Json;if($overall.status -ne 'PASS_READ_ONLY_RUN'){throw 'BUILDER_STATUS_BAD'}
$sp=& $ctl -Mode Plan -Action @('school.start') -SchoolCount 37 -SchoolMode Test -SchoolTopics 'codex_school_task_template_strength' -Json|ConvertFrom-Json
if($sp.status -notin @('READY','BLOCKED')){throw 'SCHOOL_PLAN_STATUS_BAD'}
$ap=& $ctl -Mode Plan -Action @('agent.start') -AgentDurationMinutes 1 -Json|ConvertFrom-Json
if($ap.status -notin @('READY','BLOCKED')){throw 'AGENT_PLAN_STATUS_BAD'}
if($sp.status -eq 'READY'){$sr=& $ctl -Mode Run -Action @('school.start') -SchoolCount 37 -SchoolMode Test -SchoolTopics 'codex_school_task_template_strength' -Json|ConvertFrom-Json;if($sr.status -ne 'BLOCKED_CONFIRMATION_REQUIRED'){throw 'SCHOOL_CONFIRM_GATE_BAD'}}
if($ap.status -eq 'READY'){$ar=& $ctl -Mode Run -Action @('agent.start') -AgentDurationMinutes 1 -Json|ConvertFrom-Json;if($ar.status -ne 'BLOCKED_CONFIRMATION_REQUIRED'){throw 'AGENT_CONFIRM_GATE_BAD'}}
$conf=& $ctl -Mode Plan -Action @('school.start','agent.start') -Json|ConvertFrom-Json;if($conf.status -ne 'BLOCKED_CONFLICT'){throw 'START_CONFLICT_GATE_BAD'}
$after=@(git status --porcelain=v1 -uall);if(($before -join "`n") -ne ($after -join "`n")){throw 'VALIDATOR_MUTATED_WORKTREE'}
foreach($n in $mh.Keys){if((Get-FileHash -Algorithm SHA256 (Join-Path $mr $n)).Hash -ne $mh[$n]){throw "VALIDATOR_MUTATED_MEMORY:$n"}}
$procAfter=@(Get-CimInstance Win32_Process|Where-Object{$_.CommandLine -and $_.CommandLine -match '(?i)run_agent_school\.ps1|start_agent_life_v1\.ps1'}|Select-Object -ExpandProperty ProcessId)
$new=@($procAfter|Where-Object{$procBefore -notcontains $_});if($new.Count){throw ('VALIDATOR_STARTED_RUNTIME:'+($new -join ','))}
Write-Output ('PASS_BUILDER_CONTROL_CENTER_V2|ACTIONS='+$ids.Count+'|MULTISELECT=3|START_ROUTES=2|CONFIRM_GATE=PASS|CONFLICT_GATE=PASS|RUNTIME_STARTED=0')
