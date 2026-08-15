[CmdletBinding()]param()
$ErrorActionPreference='Stop'
$root=(git rev-parse --show-toplevel).Trim();Set-Location $root
$reg='operations/control_center/BUILDER_CONTROL_CENTER_REGISTRY_V1.json';$ctl='operations/control_center/invoke_builder_control_center_v1.ps1'
foreach($f in @($reg,$ctl)){if(-not(Test-Path $f)){throw "MISSING:$f"}}
$r=Get-Content $reg -Raw|ConvertFrom-Json
if($r.schema -ne 'builder_control_center_registry_v1'){throw 'REGISTRY_SCHEMA_BAD'}
$ids=@($r.actions.id);if($ids.Count -ne @($ids|Sort-Object -Unique).Count){throw 'DUPLICATE_ACTION_ID'}
$need=@('builder.status','repo.status','school.status','agent.status','inventory.status','capability.status','memory.status','school.start','agent.start','runtime.diagnose','memory.diagnose','inventory.diagnose','capability.diagnose','control_center.diagnose');foreach($id in $need){if($ids -notcontains $id){throw "MISSING_ACTION:$id"}}
if($ids.Count -ne 14){throw 'ACTION_COUNT_BAD'}
$tok=$null;$err=$null;[void][System.Management.Automation.Language.Parser]::ParseFile((Resolve-Path $ctl),[ref]$tok,[ref]$err);if($err.Count){throw ('CONTROL_PARSE_FAIL:'+($err.Message -join ';'))}
$before=@(git status --porcelain=v1 -uall);$mr='.runtime/active_compact_semantic_memory_v1';$mh=@{};foreach($n in @('manifest.json','index.json','cells.jsonl')){$x=Join-Path $mr $n;if(Test-Path $x){$mh[$n]=(Get-FileHash -Algorithm SHA256 $x).Hash}}
$capProof='tests/self_development/CAPABILITY_INVOCATION_MAP_V1_CONTRACT_PROOF.json';$capHash=if(Test-Path $capProof){(Get-FileHash -Algorithm SHA256 $capProof).Hash}else{$null}
$procBefore=@(Get-CimInstance Win32_Process|Where-Object{$_.CommandLine -and $_.CommandLine -match '(?i)run_agent_school\.ps1|start_agent_life_v1\.ps1'}|Select-Object -ExpandProperty ProcessId)
$list=& $ctl -Mode List -Json|ConvertFrom-Json;if(@($list).Count -ne 14){throw 'LIST_ACTION_COUNT_BAD'}
$view=@('inventory.status','capability.status','memory.status');$vp=& $ctl -Mode Plan -Action $view -Json|ConvertFrom-Json;if($vp.status-ne'READY'-or[int]$vp.count-ne3-or-not[bool]$vp.parallel_safe){throw 'VIEW_PLAN_BAD'}
$vr=& $ctl -Mode Run -Action $view -Json|ConvertFrom-Json;if($vr.status-ne'PASS_READ_ONLY_RUN'-or@($vr.results).Count-ne3){throw 'VIEW_RUN_BAD'}
$diag=@('runtime.diagnose','memory.diagnose','inventory.diagnose','capability.diagnose','control_center.diagnose');$dp=& $ctl -Mode Plan -Action $diag -Json|ConvertFrom-Json
if($dp.status-ne'READY'-or[int]$dp.diagnostic_count-ne5-or[int]$dp.live_mutation_count-ne0-or$dp.execution_mode-ne'SEQUENTIAL'){throw 'DIAG_PLAN_BAD'}
$dr=& $ctl -Mode Run -Action $diag -Json|ConvertFrom-Json;if($dr.status-ne'PASS_DIAGNOSTIC_RUN'-or@($dr.results).Count-ne5){throw 'DIAG_RUN_BAD'}
$rt=@($dr.results|Where-Object id -eq 'runtime.diagnose')|Select-Object -First 1;if($rt.status -notin @('DIAGNOSTIC_PASS','DIAGNOSTIC_RUNNING','DIAGNOSTIC_ATTENTION')){throw 'RUNTIME_DIAG_BAD'}
$mm=@($dr.results|Where-Object id -eq 'memory.diagnose')|Select-Object -First 1;if($mm.status-ne'DIAGNOSTIC_PASS'){throw 'MEMORY_DIAG_BAD'}
$ii=@($dr.results|Where-Object id -eq 'inventory.diagnose')|Select-Object -First 1;if($ii.status-ne'DIAGNOSTIC_PASS'-or$ii.validator_status-ne'PASS_BODY_INVENTORY_MAP_CURRENT_V1'){throw 'INVENTORY_DIAG_BAD'}
$cc=@($dr.results|Where-Object id -eq 'control_center.diagnose')|Select-Object -First 1;if($cc.status-ne'DIAGNOSTIC_PASS'-or[int]$cc.action_count-ne14){throw 'CONTROL_DIAG_BAD'}
$cp=@($dr.results|Where-Object id -eq 'capability.diagnose')|Select-Object -First 1;if($cp.unsafe_validator_invoked -ne $false){throw 'CAPABILITY_UNSAFE_VALIDATOR_INVOKED'}
if(-not(Test-Path '.runtime/map_control/validations/body_inventory_map_current_validation.json')){throw 'INVENTORY_RUNTIME_ARTIFACT_MISSING'}
$sp=& $ctl -Mode Plan -Action @('school.start') -SchoolCount 37 -SchoolMode Test -SchoolTopics 'codex_school_task_template_strength' -Json|ConvertFrom-Json;if($sp.status -notin @('READY','BLOCKED')){throw 'SCHOOL_PLAN_STATUS_BAD'}
$ap=& $ctl -Mode Plan -Action @('agent.start') -AgentDurationMinutes 1 -Json|ConvertFrom-Json;if($ap.status -notin @('READY','BLOCKED')){throw 'AGENT_PLAN_STATUS_BAD'}
if($sp.status -eq 'READY'){$sr=& $ctl -Mode Run -Action @('school.start') -SchoolCount 37 -SchoolMode Test -SchoolTopics 'codex_school_task_template_strength' -Json|ConvertFrom-Json;if($sr.status-ne'BLOCKED_CONFIRMATION_REQUIRED'){throw 'SCHOOL_CONFIRM_GATE_BAD'}}
if($ap.status -eq 'READY'){$ar=& $ctl -Mode Run -Action @('agent.start') -AgentDurationMinutes 1 -Json|ConvertFrom-Json;if($ar.status-ne'BLOCKED_CONFIRMATION_REQUIRED'){throw 'AGENT_CONFIRM_GATE_BAD'}}
$conf=& $ctl -Mode Plan -Action @('school.start','agent.start') -Json|ConvertFrom-Json;if($conf.status-ne'BLOCKED_CONFLICT'){throw 'START_CONFLICT_GATE_BAD'}
$after=@(git status --porcelain=v1 -uall);if(($before-join"`n")-ne($after-join"`n")){throw 'VALIDATOR_MUTATED_WORKTREE'}
foreach($n in $mh.Keys){if((Get-FileHash -Algorithm SHA256 (Join-Path $mr $n)).Hash-ne$mh[$n]){throw "VALIDATOR_MUTATED_MEMORY:$n"}}
if($null-ne$capHash -and (Get-FileHash -Algorithm SHA256 $capProof).Hash-ne$capHash){throw 'CAPABILITY_TRACKED_PROOF_MUTATED'}
$procAfter=@(Get-CimInstance Win32_Process|Where-Object{$_.CommandLine -and $_.CommandLine -match '(?i)run_agent_school\.ps1|start_agent_life_v1\.ps1'}|Select-Object -ExpandProperty ProcessId);$new=@($procAfter|Where-Object{$procBefore -notcontains $_});if($new.Count){throw ('VALIDATOR_STARTED_RUNTIME:'+($new-join','))}
Write-Output ('PASS_BUILDER_CONTROL_CENTER_V3|ACTIONS=14|DIAGNOSE_ROUTES=5|MULTI_DIAG=PASS|LIVE_MUTATION=0|TRACKED_MUTATION=0|RUNTIME_STARTED=0')
