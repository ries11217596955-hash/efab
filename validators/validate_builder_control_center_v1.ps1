[CmdletBinding()]param()
$ErrorActionPreference='Stop'
$root=(git rev-parse --show-toplevel).Trim(); Set-Location $root
$reg='operations/control_center/BUILDER_CONTROL_CENTER_REGISTRY_V1.json'; $ctl='operations/control_center/invoke_builder_control_center_v1.ps1'
foreach($f in @($reg,$ctl)){ if(-not(Test-Path $f)){ throw "MISSING:$f" } }
$r=Get-Content $reg -Raw | ConvertFrom-Json
if($r.schema -ne 'builder_control_center_registry_v1'){ throw 'REGISTRY_SCHEMA_BAD' }
$ids=@($r.actions.id)
if($ids.Count -ne @($ids|Sort-Object -Unique).Count){ throw 'DUPLICATE_ACTION_ID' }
$need=@('builder.status','repo.status','school.status','agent.status','inventory.status','capability.status','memory.status')
foreach($id in $need){ if($ids -notcontains $id){ throw "MISSING_ACTION:$id" } }
if(@($r.actions|Where-Object{-not [bool]$_.read_only}).Count){ throw 'V1_MUST_BE_READ_ONLY' }
$tok=$null;$err=$null;[void][System.Management.Automation.Language.Parser]::ParseFile((Resolve-Path $ctl),[ref]$tok,[ref]$err)
if($err.Count){ throw ('CONTROL_PARSE_FAIL:'+($err.Message -join ';')) }
$before=@(git status --porcelain=v1)
$mr='.runtime/active_compact_semantic_memory_v1'; $mh=@{}
foreach($n in @('manifest.json','index.json','cells.jsonl')){ $x=Join-Path $mr $n; if(Test-Path $x){$mh[$n]=(Get-FileHash -Algorithm SHA256 $x).Hash} }
$list=& $ctl -Mode List -Json | ConvertFrom-Json
if(@($list).Count -lt 7){ throw 'LIST_TOO_SMALL' }
$selection=@('inventory.status','capability.status','memory.status')
$plan=& $ctl -Mode Plan -Action $selection -Json | ConvertFrom-Json
if($plan.status -ne 'READY' -or [int]$plan.count -ne 3 -or -not [bool]$plan.parallel_safe){ throw 'MULTISELECT_PLAN_BAD' }
$run=& $ctl -Mode Run -Action $selection -Json | ConvertFrom-Json
if($run.status -ne 'PASS_READ_ONLY_RUN' -or @($run.results).Count -ne 3){ throw 'MULTISELECT_RUN_BAD' }
$all=& $ctl -Mode Run -Action @('builder.status') -Json | ConvertFrom-Json
if($all.status -ne 'PASS_READ_ONLY_RUN'){ throw 'BUILDER_STATUS_BAD' }
$after=@(git status --porcelain=v1)
if(($before -join "`n") -ne ($after -join "`n")){ throw 'VALIDATOR_MUTATED_WORKTREE' }
foreach($n in $mh.Keys){ if((Get-FileHash -Algorithm SHA256 (Join-Path $mr $n)).Hash -ne $mh[$n]){ throw "VALIDATOR_MUTATED_MEMORY:$n" } }
Write-Output ('PASS_BUILDER_CONTROL_CENTER_V1|ACTIONS='+$ids.Count+'|MULTISELECT=3|MUTATION=0')
