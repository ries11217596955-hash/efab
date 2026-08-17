[CmdletBinding()]param()
$ErrorActionPreference='Stop'
$root=(git rev-parse --show-toplevel).Trim();Set-Location $root
$reg='operations/control_center/BUILDER_CONTROL_CENTER_REGISTRY_V1.json';$ctl='operations/control_center/invoke_builder_control_center_v1.ps1'
foreach($f in @($reg,$ctl)){if(-not(Test-Path $f)){throw "MISSING:$f"}}
$r=Get-Content $reg -Raw|ConvertFrom-Json
if($r.schema -ne 'builder_control_center_registry_v1'){throw 'REGISTRY_SCHEMA_BAD'}
$ids=@($r.actions.id);if($ids.Count -ne @($ids|Sort-Object -Unique).Count){throw 'DUPLICATE_ACTION_ID'}
$need=@('builder.status','repo.status','school.status','agent.status','inventory.status','capability.status','memory.status','school.start','agent.start','runtime.diagnose','memory.diagnose','inventory.diagnose','capability.diagnose','control_center.diagnose','builder.overview','remote_access.status','builder.preflight');foreach($id in $need){if($ids -notcontains $id){throw "MISSING_ACTION:$id"}}
if($ids.Count -ne 17){throw 'ACTION_COUNT_BAD'}
$tok=$null;$err=$null;[void][System.Management.Automation.Language.Parser]::ParseFile((Resolve-Path $ctl),[ref]$tok,[ref]$err);if($err.Count){throw ('CONTROL_PARSE_FAIL:'+($err.Message -join ';'))}
$before=@(git status --porcelain=v1 -uall);$mr='.runtime/active_compact_semantic_memory_v1';$mh=@{};foreach($n in @('manifest.json','index.json','cells.jsonl')){$x=Join-Path $mr $n;if(Test-Path $x){$mh[$n]=(Get-FileHash -Algorithm SHA256 $x).Hash}}
$capProof='tests/self_development/CAPABILITY_INVOCATION_MAP_V1_CONTRACT_PROOF.json';$capHash=if(Test-Path $capProof){(Get-FileHash -Algorithm SHA256 $capProof).Hash}else{$null}
$procBefore=@(Get-CimInstance Win32_Process|Where-Object{$_.CommandLine -and $_.CommandLine -match '(?i)run_agent_school\.ps1|start_agent_life_v1\.ps1'}|Select-Object -ExpandProperty ProcessId)
$list=& $ctl -Mode List -Json|ConvertFrom-Json;if(@($list).Count -ne 17){throw 'LIST_ACTION_COUNT_BAD'}
$view=@('inventory.status','capability.status','memory.status');$vp=& $ctl -Mode Plan -Action $view -Json|ConvertFrom-Json;if($vp.status-ne'READY'-or[int]$vp.count-ne3-or-not[bool]$vp.parallel_safe){throw 'VIEW_PLAN_BAD'}
$vr=& $ctl -Mode Run -Action $view -Json|ConvertFrom-Json;if($vr.status-ne'PASS_READ_ONLY_RUN'-or@($vr.results).Count-ne3){throw 'VIEW_RUN_BAD'}
$diag=@('runtime.diagnose','memory.diagnose','inventory.diagnose','capability.diagnose','control_center.diagnose','builder.preflight');$dp=& $ctl -Mode Plan -Action $diag -Json|ConvertFrom-Json
if($dp.status-ne'READY'-or[int]$dp.diagnostic_count-ne6-or[int]$dp.live_mutation_count-ne0-or$dp.execution_mode-ne'SEQUENTIAL'){throw 'DIAG_PLAN_BAD'}
$dr=& $ctl -Mode Run -Action $diag -Json|ConvertFrom-Json;if($dr.status-ne'PASS_DIAGNOSTIC_RUN'-or@($dr.results).Count-ne6){throw 'DIAG_RUN_BAD'}
$pf=@($dr.results|Where-Object id -eq 'builder.preflight')|Select-Object -First 1;if($pf.id-ne'builder.preflight'-or-not$pf.freshness.observed_at-or$pf.protected_memory.protected-ne$true-or$pf.does_not_prove-ne'mutation_authority_or_action_completion'){throw 'BUILDER_PREFLIGHT_CONTRACT_BAD'};if($pf.repo.status-eq'CLEAN'-and$pf.runtime.school.status-ne'RUNNING'-and$pf.runtime.agent.status-ne'RUNNING'-and$pf.protected_memory.status-eq'PRESENT'-and$pf.applicable_agents){if($pf.status-ne'PREFLIGHT_PASS'-or-not$pf.mutation_ready){throw 'BUILDER_PREFLIGHT_FALSE_BLOCK'}}else{if($pf.status-ne'PREFLIGHT_BLOCKED'-or$pf.mutation_ready){throw 'BUILDER_PREFLIGHT_FALSE_READY'}}
$rt=@($dr.results|Where-Object id -eq 'runtime.diagnose')|Select-Object -First 1;if($rt.status -notin @('DIAGNOSTIC_PASS','DIAGNOSTIC_RUNNING','DIAGNOSTIC_ATTENTION')){throw 'RUNTIME_DIAG_BAD'}
$mm=@($dr.results|Where-Object id -eq 'memory.diagnose')|Select-Object -First 1;if($mm.status-ne'DIAGNOSTIC_PASS'){throw 'MEMORY_DIAG_BAD'}
$ii=@($dr.results|Where-Object id -eq 'inventory.diagnose')|Select-Object -First 1;if($ii.status-ne'DIAGNOSTIC_PASS'-or$ii.validator_status-ne'PASS_BODY_INVENTORY_MAP_CURRENT_V1'){throw 'INVENTORY_DIAG_BAD'}
$cc=@($dr.results|Where-Object id -eq 'control_center.diagnose')|Select-Object -First 1;if($cc.status-ne'DIAGNOSTIC_PASS'-or[int]$cc.action_count-ne17){throw 'CONTROL_DIAG_BAD'}
$cp=@($dr.results|Where-Object id -eq 'capability.diagnose')|Select-Object -First 1;if($cp.status-ne'DIAGNOSTIC_PASS_WITH_GAPS'-or-not$cp.validator_invoked-or$cp.validator-ne'operations/self_model/validate_capability_invocation_map_v1.ps1'-or[int]$cp.validator_exit-ne0){throw 'CAPABILITY_DIAGNOSTIC_CANONICAL_VALIDATOR_BAD'}
if(-not(Test-Path '.runtime/map_control/validations/body_inventory_map_current_validation.json')){throw 'INVENTORY_RUNTIME_ARTIFACT_MISSING'}

$ra=& $ctl -Mode Run -Action @('remote_access.status') -Json|ConvertFrom-Json
if($ra.status-ne'PASS_READ_ONLY_RUN'){throw 'REMOTE_ACCESS_RUN_BAD'}
$rar=@($ra.results|Where-Object id -eq 'remote_access.status')|Select-Object -First 1
if($rar.gpt_connector.status-ne'UNKNOWN_EXTERNAL_TO_LOCAL_PC'){throw 'REMOTE_CONNECTOR_SCOPE_BAD'}
$pcListener=@($rar.components|Where-Object endpoint -eq '127.0.0.1:18790')|Select-Object -First 1
if(-not $pcListener -or $pcListener.proof_scope-ne'tcp_listener_only' -or $pcListener.does_not_prove-ne'authenticated_api_behavior'){throw 'REMOTE_PC_LISTENER_SCOPE_BAD'}
if(-not$rar.freshness.observed_at -or [int]$rar.freshness.ttl_seconds-ne60 -or $rar.freshness.state-ne'FRESH'){throw 'REMOTE_FRESHNESS_BAD'}
$ov=& $ctl -Mode Run -Action @('builder.overview') -Json|ConvertFrom-Json
if($ov.status-ne'PASS_READ_ONLY_RUN'){throw 'OVERVIEW_RUN_BAD'}
$ovr=@($ov.results|Where-Object id -eq 'builder.overview')|Select-Object -First 1
if($ovr.status-ne'OVERVIEW_READY' -or @($ovr.surfaces).Count-lt8){throw 'OVERVIEW_SHAPE_BAD'}
if(-not$ovr.freshness.observed_at -or [int]$ovr.freshness.ttl_seconds-ne60 -or $ovr.freshness.state-ne'FRESH'){throw 'OVERVIEW_FRESHNESS_BAD'}
$repoSurface=@($ovr.surfaces|Where-Object id -eq 'repo')|Select-Object -First 1
$capSurface=@($ovr.surfaces|Where-Object id -eq 'capability')|Select-Object -First 1
if($capSurface.raw_status -eq 'MISSING_NOT_WIRED'){
 if($ovr.blockers -notcontains 'CAPABILITY_MAP_MISSING_NOT_WIRED'){throw 'OVERVIEW_CAPABILITY_BLOCKER_MISSING'}
 if($repoSurface.raw_status -eq 'CLEAN'){
  if($ovr.recommended_next_action.id -ne 'capability.diagnose'){throw 'OVERVIEW_NEXT_ACTION_CLEAN_BAD'}
 } else {
  if($ovr.blockers -notcontains 'REPO_DIRTY'){throw 'OVERVIEW_REPO_BLOCKER_MISSING'}
  if($ovr.recommended_next_action.id -ne 'repo.status'){throw 'OVERVIEW_NEXT_ACTION_DIRTY_BAD'}
 }
}

$sp=& $ctl -Mode Plan -Action @('school.start') -SchoolCount 37 -SchoolMode Test -SchoolTopics 'codex_school_task_template_strength' -Json|ConvertFrom-Json;if($sp.status -notin @('READY','BLOCKED')){throw 'SCHOOL_PLAN_STATUS_BAD'}
$ap=& $ctl -Mode Plan -Action @('agent.start') -AgentDurationMinutes 1 -Json|ConvertFrom-Json;if($ap.status -notin @('READY','BLOCKED')){throw 'AGENT_PLAN_STATUS_BAD'}
if($sp.status -eq 'READY'){$sr=& $ctl -Mode Run -Action @('school.start') -SchoolCount 37 -SchoolMode Test -SchoolTopics 'codex_school_task_template_strength' -Json|ConvertFrom-Json;if($sr.status-ne'BLOCKED_CONFIRMATION_REQUIRED'){throw 'SCHOOL_CONFIRM_GATE_BAD'}}
if($ap.status -eq 'READY'){$ar=& $ctl -Mode Run -Action @('agent.start') -AgentDurationMinutes 1 -Json|ConvertFrom-Json;if($ar.status-ne'BLOCKED_CONFIRMATION_REQUIRED'){throw 'AGENT_CONFIRM_GATE_BAD'}}
$conf=& $ctl -Mode Plan -Action @('school.start','agent.start') -Json|ConvertFrom-Json;if($conf.status-ne'BLOCKED_CONFLICT'){throw 'START_CONFLICT_GATE_BAD'}
$after=@(git status --porcelain=v1 -uall);if(($before-join"`n")-ne($after-join"`n")){throw 'VALIDATOR_MUTATED_WORKTREE'}
foreach($n in $mh.Keys){if((Get-FileHash -Algorithm SHA256 (Join-Path $mr $n)).Hash-ne$mh[$n]){throw "VALIDATOR_MUTATED_MEMORY:$n"}}
if($null-ne$capHash -and (Get-FileHash -Algorithm SHA256 $capProof).Hash-ne$capHash){throw 'CAPABILITY_TRACKED_PROOF_MUTATED'}
$procAfter=@(Get-CimInstance Win32_Process|Where-Object{$_.CommandLine -and $_.CommandLine -match '(?i)run_agent_school\.ps1|start_agent_life_v1\.ps1'}|Select-Object -ExpandProperty ProcessId);$new=@($procAfter|Where-Object{$procBefore -notcontains $_});if($new.Count){throw ('VALIDATOR_STARTED_RUNTIME:'+($new-join','))}
$capRun=& $ctl -Mode Run -Action @('capability.status') -Json|ConvertFrom-Json
$cap=@($capRun.results|Where-Object id -eq 'capability.status')|Select-Object -First 1
if(Test-Path 'reports/self_development/CAPABILITY_INVOCATION_MAP_V1.json'){
 if($cap.status-ne'PRESENT_DRAFT_NOT_READY'){throw 'CAPABILITY_DRAFT_STATUS_BAD'}
 $cm=Get-Content 'reports/self_development/CAPABILITY_INVOCATION_MAP_V1.json' -Raw|ConvertFrom-Json;$cmCaps=@($cm.capabilities).Count;$cmTasks=[int]$cm.coverage.current_tasks_seen;$cmNoId=[int]$cm.coverage.tasks_without_capability_id
 if([int]$cap.capability_count-ne$cmCaps -or [int]$cap.current_tasks_seen-ne$cmTasks -or [int]$cap.tasks_without_capability_id-ne$cmNoId){throw 'CAPABILITY_DRAFT_COUNTS_BAD'}
 $cmOwners=@($cm.capabilities|Where-Object{$null-ne$_.owning_organ_id -and -not[string]::IsNullOrWhiteSpace([string]$_.owning_organ_id)}).Count;$cmInvocable=@($cm.capabilities|Where-Object{@($_.invocation_modes).Count-gt0}).Count;$cmLive=@($cm.capabilities|Where-Object{$_.live_or_lab_status-eq'PROVEN_LIVE'}).Count
 if([int]$cap.owners_resolved-ne$cmOwners -or [int]$cap.invocable_count-ne$cmInvocable -or [int]$cap.live_proven_count-ne$cmLive){throw 'CAPABILITY_DRAFT_READINESS_FALSE_POSITIVE'}
 $cd=& $ctl -Mode Run -Action @('capability.diagnose') -Json|ConvertFrom-Json
 $cdr=@($cd.results|Where-Object id -eq 'capability.diagnose')|Select-Object -First 1
 if($cdr.status-ne'DIAGNOSTIC_PASS_WITH_GAPS' -or -not$cdr.validator_invoked -or $cdr.validator_exit-ne0){throw 'CAPABILITY_DIAG_WIRING_BAD'}
 $bo=& $ctl -Mode Run -Action @('builder.overview') -Json|ConvertFrom-Json
 $bor=@($bo.results|Where-Object id -eq 'builder.overview')|Select-Object -First 1
 if($bor.overall-ne'DEGRADED' -or $bor.blockers -notcontains 'CAPABILITY_MAP_PRESENT_DRAFT_NOT_READY'){throw 'OVERVIEW_CAPABILITY_DRAFT_BLOCKER_BAD'}
}
Write-Output ('PASS_BUILDER_CONTROL_CENTER_V4|ACTIONS=17|DIAGNOSE_ROUTES=6|OVERVIEW=PASS|REMOTE_SCOPE=PASS|MULTI_DIAG=PASS|LIVE_MUTATION=0|TRACKED_MUTATION=0|RUNTIME_STARTED=0')
