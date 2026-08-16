[CmdletBinding()]param()
$ErrorActionPreference='Stop'
$RepoRoot=(git rev-parse --show-toplevel).Trim();Set-Location $RepoRoot
function Assert($Cond,[string]$Msg){if(-not$Cond){throw $Msg}}
$contractPath='self_model/CAPABILITY_INVOCATION_MAP_V1_CONTRACT.json';$bodyPath='reports/self_development/agent_body_map.json';$mapPath='reports/self_development/CAPABILITY_INVOCATION_MAP_V1.json';$docPath='docs/operations/CAPABILITY_INVOCATION_MAP_V1.md';$proofPath='tests/self_development/CAPABILITY_INVOCATION_MAP_V1_PROOF.json'
$validatorAliasMap=@{
 'item_level_execution_ledger_v1'='packs/PHASE98_ITEM_LEVEL_EXECUTION_LEDGER_V1/VALIDATE.ps1'
 'generated_conveyor_failure_trial_family_v1_failure_pack_v1'='validators/validate_generated_family_autonomous_conveyor_failure_recovery_v1.ps1'
 'generated_conveyor_trial_family_v1_live_pack_v1'='validators/validate_generated_family_autonomous_conveyor_live_trial_v1.ps1'
 'repair_loop_generator_v1'='packs/PHASE103_REPAIR_LOOP_GENERATOR_V1/VALIDATE.ps1'
}

foreach($p in @($contractPath,$bodyPath,$mapPath,$docPath,$proofPath)){Assert (Test-Path $p) ("MISSING:$p")}
git check-ignore -q -- $mapPath 2>$null;$mapIgnored=($LASTEXITCODE -eq 0);Assert (-not $mapIgnored) 'CANONICAL_MAP_IS_GIT_IGNORED'
$before=@(git status --porcelain=v1 -uall);$taskBefore=@(git status --porcelain=v1 -uall -- tasks);$mr='.runtime/active_compact_semantic_memory_v1';$mh=@{};foreach($n in @('manifest.json','index.json','cells.jsonl')){$p=Join-Path $mr $n;if(Test-Path $p){$mh[$n]=(Get-FileHash -Algorithm SHA256 $p).Hash}}
& powershell -NoProfile -ExecutionPolicy Bypass -File operations/self_model/validate_capability_invocation_map_v1_contract.ps1 | Out-Null
Assert ($LASTEXITCODE -eq 0) 'CONTRACT_V2_INVALID'
$c=Get-Content $contractPath -Raw|ConvertFrom-Json;$b=Get-Content $bodyPath -Raw|ConvertFrom-Json;$m=Get-Content $mapPath -Raw|ConvertFrom-Json;$p=Get-Content $proofPath -Raw|ConvertFrom-Json
Assert ($m.schema -eq 'capability_invocation_map_v1') 'MAP_SCHEMA_BAD';Assert ($m.status -eq 'DRAFT_NORMALIZED_WITH_GAPS') 'MAP_STATUS_BAD';Assert ($m.live_process_touched -eq $false) 'LIVE_PROCESS_TOUCH_BAD';Assert ($m.active_memory_mutated -eq $false) 'MEMORY_MUTATION_BAD'
foreach($f in $c.required_top_level_fields){Assert ($m.PSObject.Properties.Name -contains $f) ("TOP_FIELD_MISSING:$f")}
$tasks=@(Get-ChildItem tasks -File -Filter '*.json'|Sort-Object Name);$withId=@();$withoutId=@();foreach($f in $tasks){$t=Get-Content $f.FullName -Raw|ConvertFrom-Json;if([string]::IsNullOrWhiteSpace([string]$t.capability_id)){$withoutId+='tasks/'+$f.Name}else{$withId+='tasks/'+$f.Name}}
Assert ([int]$m.coverage.current_tasks_seen -eq $tasks.Count) 'CURRENT_TASK_COUNT_BAD';Assert ([int]$m.coverage.normalized_capabilities -eq $withId.Count) 'CAPABILITY_COUNT_BAD';Assert ([int]$m.coverage.tasks_without_capability_id -eq $withoutId.Count) 'NO_ID_COUNT_BAD';Assert ([int]$m.coverage.retired_tasks_accounted -eq @($c.coverage_requirements_for_v1.retired_task_refs).Count) 'RETIRED_COUNT_BAD';Assert ([int]$m.coverage.accounted_total -eq [int]$c.coverage_requirements_for_v1.historical_task_baseline) 'ACCOUNTED_TOTAL_BAD';Assert ([int]$m.coverage.unexplained_historical_task_loss -eq 0) 'UNEXPLAINED_HISTORICAL_TASK_LOSS'
$capIds=@($m.capabilities.capability_id);Assert ($capIds.Count -eq @($capIds|Sort-Object -Unique).Count) 'DUPLICATE_CAPABILITY_ID'
$bodyIds=@($b.components.id);$mappedTasks=New-Object System.Collections.Generic.List[string]
$allowedMat=@($c.allowed_maturity);$allowedLive=@($c.allowed_live_or_lab_status)
foreach($cap in @($m.capabilities)){
 foreach($f in $c.capability_required_fields){Assert ($cap.PSObject.Properties.Name -contains $f) ("CAP_FIELD_MISSING:$($cap.capability_id):$f")}
 Assert ($allowedMat -contains [string]$cap.maturity) ("MATURITY_BAD:$($cap.capability_id)");Assert ($allowedLive -contains [string]$cap.live_or_lab_status) ("LIVE_LAB_BAD:$($cap.capability_id)")
 foreach($tr in @($cap.source_task_refs)){Assert (Test-Path $tr) ("TASK_REF_MISSING:$($cap.capability_id):$tr");$mappedTasks.Add([string]$tr)}
 if($null-ne$cap.owning_organ_id -and -not[string]::IsNullOrWhiteSpace([string]$cap.owning_organ_id)){Assert ($bodyIds -contains [string]$cap.owning_organ_id) ("OWNER_NOT_IN_BODY_MAP:$($cap.capability_id)")}else{Assert (@($cap.gaps) -contains 'OWNING_ORGAN_UNRESOLVED') ("UNRESOLVED_OWNER_GAP_MISSING:$($cap.capability_id)")}
 $expectedValidator=if($validatorAliasMap.ContainsKey([string]$cap.capability_id)){[string]$validatorAliasMap[[string]$cap.capability_id]}else{'validators/validate_'+[string]$cap.capability_id+'.ps1'}
 $eligibleValidator=$false
 if(Test-Path $expectedValidator){$expectedValidatorRaw=Get-Content $expectedValidator -Raw;$eligibleValidator=($expectedValidatorRaw -match [regex]::Escape([string]$cap.capability_id))}
 if($eligibleValidator){Assert (@($cap.validator_refs).Count -eq 1) ("VALIDATOR_REF_COUNT_BAD:$($cap.capability_id)");Assert ([string]$cap.validator_refs[0] -eq $expectedValidator) ("VALIDATOR_REF_NOT_EXACT:$($cap.capability_id)");Assert (@($cap.gaps) -notcontains 'VALIDATOR_REF_UNSPECIFIED') ("VALIDATOR_GAP_SHOULD_BE_CLOSED:$($cap.capability_id)")}else{Assert (@($cap.validator_refs).Count -eq 0) ("UNPROVEN_VALIDATOR_REF_PRESENT:$($cap.capability_id)");Assert (@($cap.gaps) -contains 'VALIDATOR_REF_UNSPECIFIED') ("VALIDATOR_GAP_MISSING:$($cap.capability_id)")}
 foreach($r in @($cap.validator_refs)){Assert (Test-Path $r) ("VALIDATOR_REF_MISSING:$($cap.capability_id):$r")}
 foreach($r in @($cap.proof_refs)){Assert (Test-Path $r) ("PROOF_REF_MISSING:$($cap.capability_id):$r")}
 foreach($r in @($cap.source_script_refs)){Assert (Test-Path $r) ("SCRIPT_REF_MISSING:$($cap.capability_id):$r")}
 foreach($r in @($cap.source_report_refs)){Assert (Test-Path $r) ("REPORT_REF_MISSING:$($cap.capability_id):$r")}
 if($cap.maturity -eq 'VALIDATED_LIVE' -or $cap.live_or_lab_status -eq 'PROVEN_LIVE'){Assert (@($cap.proof_refs).Count -gt 0) ("LIVE_WITHOUT_PROOF:$($cap.capability_id)")}
 foreach($mode in @($cap.invocation_modes)){
  foreach($f in $c.invocation_mode_required_fields){Assert ($mode.PSObject.Properties.Name -contains $f) ("INVOCATION_FIELD_MISSING:$($cap.capability_id):$f")}
  Assert (-not[string]::IsNullOrWhiteSpace([string]$mode.command_or_entrypoint)) ("INVOCATION_ENTRYPOINT_EMPTY:$($cap.capability_id)")
  Assert (-not[string]::IsNullOrWhiteSpace([string]$mode.cwd)) ("INVOCATION_CWD_EMPTY:$($cap.capability_id)")
  Assert (-not[string]::IsNullOrWhiteSpace([string]$mode.stop_condition)) ("INVOCATION_STOP_EMPTY:$($cap.capability_id)")
  Assert (-not[string]::IsNullOrWhiteSpace([string]$mode.rollback_or_cleanup)) ("INVOCATION_ROLLBACK_EMPTY:$($cap.capability_id)")
  Assert (-not[string]::IsNullOrWhiteSpace([string]$mode.proof_after_run)) ("INVOCATION_PROOF_EMPTY:$($cap.capability_id)")
 }
}
Assert (@(Compare-Object ($withId|Sort-Object) (@($mappedTasks)|Sort-Object)).Count -eq 0) 'TASK_TO_CAPABILITY_COVERAGE_MISMATCH'
$noIdGap=@($m.gaps|Where-Object gap_id -eq 'TASKS_WITHOUT_CAPABILITY_ID')|Select-Object -First 1;Assert ($null-ne$noIdGap) 'NO_ID_GAP_MISSING';$gapTaskRefs=@($noIdGap.items.source_task_ref|Sort-Object);Assert (@(Compare-Object ($withoutId|Sort-Object) $gapTaskRefs).Count -eq 0) 'NO_ID_TASK_SET_MISMATCH'
Assert ($p.status -eq 'PASS_CAPABILITY_INVOCATION_MAP_V1_DRAFT_GENERATION_CANDIDATE') 'PROOF_STATUS_BAD';Assert ($p.map_sha256 -eq (Get-FileHash -Algorithm SHA256 $mapPath).Hash) 'MAP_HASH_MISMATCH';Assert ([int]$p.normalized_capabilities -eq @($m.capabilities).Count) 'PROOF_CAP_COUNT_BAD'
$after=@(git status --porcelain=v1 -uall);$taskAfter=@(git status --porcelain=v1 -uall -- tasks);Assert (($before-join"`n")-eq($after-join"`n")) 'VALIDATOR_MUTATED_WORKTREE';Assert (($taskBefore-join"`n")-eq($taskAfter-join"`n")) 'VALIDATOR_MUTATED_TASKS';foreach($n in $mh.Keys){Assert ((Get-FileHash -Algorithm SHA256 (Join-Path $mr $n)).Hash-eq$mh[$n]) ("VALIDATOR_MUTATED_MEMORY:$n")}
Write-Output ('PASS_CAPABILITY_INVOCATION_MAP_V1_DRAFT|TASKS='+$tasks.Count+'|CAPABILITIES='+@($m.capabilities).Count+'|NO_CAPABILITY_ID='+$withoutId.Count+'|RETIRED='+[int]$m.coverage.retired_tasks_accounted+'|ACCOUNTED='+[int]$m.coverage.accounted_total+'|LIVE_PROVEN='+@($m.capabilities|Where-Object{$_.live_or_lab_status-eq'PROVEN_LIVE'}).Count+'|INVOCABLE='+@($m.capabilities|Where-Object{@($_.invocation_modes).Count-gt0}).Count+'|VALIDATOR_LINKED='+@($m.capabilities|Where-Object{@($_.validator_refs).Count-gt0}).Count+'|VALIDATOR_GAPPED='+@($m.capabilities|Where-Object{@($_.validator_refs).Count-eq0}).Count+'|WORKTREE_MUTATION=0|MEMORY_MUTATION=0')
