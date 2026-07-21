$ErrorActionPreference='Stop'
$errors=@()
function Add-Err([string]$e){ $script:errors += $e }
function WJson($path,$obj){
  $dir=Split-Path $path -Parent
  if($dir){ New-Item -ItemType Directory -Force -Path $dir | Out-Null }
  $json=($obj|ConvertTo-Json -Depth 100) -replace "`r`n","`n"
  [System.IO.File]::WriteAllText((Join-Path (Get-Location).Path $path),$json.TrimEnd()+"`n",(New-Object System.Text.UTF8Encoding($false)))
}
function TreeStats($p){
  if(-not(Test-Path $p)){ return [ordered]@{exists=$false; files=0; bytes=0} }
  $files=@(Get-ChildItem $p -Recurse -File -Force -ErrorAction SilentlyContinue)
  return [ordered]@{exists=$true; files=$files.Count; bytes=[int64](($files|Measure-Object Length -Sum).Sum)}
}
function Run-Cycle($outputRoot,$question){
  $before=@(); if(Test-Path $outputRoot){ $before=@(Get-ChildItem $outputRoot -Directory -ErrorAction SilentlyContinue | Select-Object -ExpandProperty FullName) }
  powershell -NoProfile -ExecutionPolicy Bypass -File operations/autonomous_inner_motor/run_autonomous_inner_motor.ps1 -Mode SandboxExploration -EnableDeepThinking -EnableMemoryLearning -EnableBuildTaskExecutorDryRun -MemoryIngestionMode QueueOnly -OutputRoot $outputRoot -Question $question
  $exit=$LASTEXITCODE
  $after=@(); if(Test-Path $outputRoot){ $after=@(Get-ChildItem $outputRoot -Directory -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending) }
  $new=$null
  foreach($d in $after){ if($before -notcontains $d.FullName){ $new=$d; break } }
  if(-not $new -and $after.Count -gt 0){ $new=$after[0] }
  return [ordered]@{ exit_code=$exit; run_root=if($new){$new.FullName.Replace((Get-Location).Path+'\','')}else{$null}; run_root_full=if($new){$new.FullName}else{$null} }
}
$runner='operations/autonomous_inner_motor/run_autonomous_inner_motor.ps1'
$stamp=(Get-Date).ToUniversalTime().ToString('yyyyMMdd_HHmmss')
$outputRoot=".runtime/build_task_bounded_executor_v2_allowed_dry_run_validation/$stamp"
$canonicalProof='tests/self_development/BUILD_TASK_BOUNDED_EXECUTOR_V2_ALLOWED_DRY_RUN_PROOF.json'
$acceptance='operations/autonomous_inner_motor/reports/BUILD_TASK_BOUNDED_EXECUTOR_V2_ALLOWED_DRY_RUN_ACCEPTANCE.json'
$tokens=$null;$parseErrors=$null
if(-not(Test-Path $runner)){ Add-Err "missing_runner:$runner" } else { [System.Management.Automation.Language.Parser]::ParseFile((Resolve-Path $runner),[ref]$tokens,[ref]$parseErrors)|Out-Null; foreach($e in $parseErrors){ Add-Err "runner_parse:$($e.Message)" } }
$runnerText=if(Test-Path $runner){Get-Content $runner -Raw}else{''}
foreach($needle in @('EnableBuildTaskExecutorDryRun','DryRunAuthority','READY_FOR_BOUNDED_EXECUTOR_DRY_RUN','effective_dry_run_allowed','DRY_RUN_PLAN_READY_NO_WRITES','dry_run_plan_ready')){ if($runnerText -notlike "*$needle*"){ Add-Err "runner_missing:$needle" } }
$activeBefore=TreeStats '.runtime/active_compact_semantic_memory_v1'
$queueBefore=TreeStats '.runtime/compact_memory_intake_v1/queue'
$launcherHashBefore=(Get-FileHash 'operations/autonomous_inner_motor/start_agent_life_v1.ps1' -Algorithm SHA256).Hash
$runnerHashBefore=(Get-FileHash $runner -Algorithm SHA256).Hash
$run1=$null; $run2=$null
if($errors.Count -eq 0){
  $run1=Run-Cycle $outputRoot 'Validate BUILD_TASK_BOUNDED_EXECUTOR_V2_ALLOWED_DRY_RUN cycle 1: authorized dry-run plan, no writes.'
  if($run1.exit_code -ne 0){ Add-Err "run1_exit_code:$($run1.exit_code)" }
  Start-Sleep -Seconds 2
  $run2=Run-Cycle $outputRoot 'Validate BUILD_TASK_BOUNDED_EXECUTOR_V2_ALLOWED_DRY_RUN cycle 2: continuity plus authorized dry-run plan, no writes.'
  if($run2.exit_code -ne 0){ Add-Err "run2_exit_code:$($run2.exit_code)" }
}
$proof1=$null;$proof2=$null;$executor1=$null;$executor2=$null;$gate1=$null;$gate2=$null;$frontier2=$null;$state2=$null;$manifest1=$null;$manifest2=$null
foreach($pair in @(@('1',$run1),@('2',$run2))){
  $n=$pair[0]; $r=$pair[1]
  if(-not $r -or -not $r.run_root_full){ Add-Err "run${n}_root_missing"; continue }
  $proofPath=Join-Path $r.run_root_full 'SANDBOX_EXPLORATION_PROOF.json'
  $executorPath=Join-Path $r.run_root_full 'build_task_bounded_executor.json'
  $gatePath=Join-Path $r.run_root_full 'build_task_contract_execution_gate.json'
  $frontierPath=Join-Path $r.run_root_full 'frontier_to_build_task_router.json'
  $statePath=Join-Path $r.run_root_full 'short_term_mind_state.json'
  $manifestPath=Join-Path $r.run_root_full 'sandbox_proof_pack_manifest.json'
  if(Test-Path $proofPath){ Set-Variable -Name "proof$n" -Value (Get-Content $proofPath -Raw|ConvertFrom-Json) } else { Add-Err "run${n}_proof_missing" }
  if(Test-Path $executorPath){ Set-Variable -Name "executor$n" -Value (Get-Content $executorPath -Raw|ConvertFrom-Json) } else { Add-Err "run${n}_executor_missing" }
  if(Test-Path $gatePath){ Set-Variable -Name "gate$n" -Value (Get-Content $gatePath -Raw|ConvertFrom-Json) } else { Add-Err "run${n}_gate_missing" }
  if($n -eq '2' -and (Test-Path $frontierPath)){ $frontier2=Get-Content $frontierPath -Raw|ConvertFrom-Json }
  if($n -eq '2' -and (Test-Path $statePath)){ $state2=Get-Content $statePath -Raw|ConvertFrom-Json }
  if(Test-Path $manifestPath){ Set-Variable -Name "manifest$n" -Value (Get-Content $manifestPath -Raw|ConvertFrom-Json) } else { Add-Err "run${n}_manifest_missing" }
}
foreach($x in @(@('1',$gate1),@('2',$gate2))){
  $n=$x[0]; $g=$x[1]
  if($g){
    if($g.status -ne 'PASS_BUILD_TASK_CONTRACT_EXECUTION_GATE_V1'){ Add-Err "run${n}_gate_status:$($g.status)" }
    if($g.gate_decision -ne 'READY_FOR_BOUNDED_EXECUTOR_DRY_RUN'){ Add-Err "run${n}_gate_decision:$($g.gate_decision)" }
    if($g.effective_dry_run_allowed -ne $true){ Add-Err "run${n}_effective_dry_run_allowed_not_true" }
    if($g.effective_execution_allowed -ne $false){ Add-Err "run${n}_effective_execution_allowed_not_false" }
    if($g.auto_execution_performed -ne $false){ Add-Err "run${n}_auto_execution_performed_not_false" }
    if(@($g.errors).Count -ne 0){ Add-Err "run${n}_gate_errors_present:$(@($g.errors) -join ',')" }
    if($g.boundary.dry_run_allowed -ne $true){ Add-Err "run${n}_boundary_dry_run_allowed_not_true" }
    if($g.boundary.execution_allowed -ne $false){ Add-Err "run${n}_boundary_execution_allowed_not_false" }
  }
}
foreach($x in @(@('1',$executor1),@('2',$executor2))){
  $n=$x[0]; $ex=$x[1]
  if($ex){
    if($ex.status -ne 'PASS_BUILD_TASK_BOUNDED_EXECUTOR_V1'){ Add-Err "run${n}_executor_status:$($ex.status)" }
    if($ex.execution_status -ne 'DRY_RUN_PLAN_READY_NO_WRITES'){ Add-Err "run${n}_execution_status:$($ex.execution_status)" }
    if($ex.gate_effective_dry_run_allowed -ne $true){ Add-Err "run${n}_gate_effective_dry_run_allowed_not_true" }
    if($ex.gate_effective_execution_allowed -ne $false){ Add-Err "run${n}_gate_effective_execution_allowed_not_false" }
    if($ex.dry_run_plan_ready -ne $true){ Add-Err "run${n}_dry_run_plan_ready_not_true" }
    if(@($ex.planned_operations).Count -lt 1){ Add-Err "run${n}_planned_operations_empty" }
    if([int]$ex.executed_files_count -ne 0){ Add-Err "run${n}_executed_files_count:$($ex.executed_files_count)" }
    if(@($ex.executed_files).Count -ne 0){ Add-Err "run${n}_executed_files_not_empty" }
    if(@($ex.executed_operations).Count -ne 0){ Add-Err "run${n}_executed_operations_not_empty" }
    if($ex.validator_ran -ne $false){ Add-Err "run${n}_validator_ran_not_false" }
    if($ex.proof_written_by_executor -ne $false){ Add-Err "run${n}_proof_written_by_executor_not_false" }
    if($ex.rollback_needed -ne $false){ Add-Err "run${n}_rollback_needed_not_false" }
    if($ex.forbidden_surface_touched -ne $false){ Add-Err "run${n}_forbidden_surface_touched_not_false" }
    if($ex.boundary.dry_run_plan_allowed -ne $true){ Add-Err "run${n}_boundary_dry_run_plan_allowed_not_true" }
    if($ex.boundary.execution_performed -ne $false){ Add-Err "run${n}_execution_performed_not_false" }
    if($ex.boundary.no_repo_mutation_by_executor -ne $true){ Add-Err "run${n}_no_repo_mutation_by_executor_not_true" }
    if($ex.boundary.no_contract_file_write -ne $true){ Add-Err "run${n}_no_contract_file_write_not_true" }
    if($ex.boundary.direct_active_memory_write -ne $false){ Add-Err "run${n}_direct_active_memory_write_not_false" }
  }
}
if($frontier2){
  if($frontier2.contract.dry_run_allowed -ne $true){ Add-Err 'frontier_contract_dry_run_allowed_not_true' }
  if($frontier2.contract.execution_allowed -ne $false){ Add-Err 'frontier_contract_execution_allowed_not_false' }
}
if($state2 -and $state2.continuity.previous_state_found -ne $true){ Add-Err 'run2_previous_state_not_found' }
foreach($p in @(@('1',$proof1),@('2',$proof2))){
  $n=$p[0]; $pr=$p[1]
  if($pr){
    if(-not $pr.PSObject.Properties['build_task_bounded_executor']){ Add-Err "run${n}_proof_executor_missing" }
    if(@($pr.decision_trace | Where-Object { $_.step -eq 'build_task_bounded_executor' }).Count -ne 1){ Add-Err "run${n}_decision_trace_executor_missing" }
  }
}
foreach($m in @(@('1',$manifest1),@('2',$manifest2))){ $n=$m[0]; $mf=$m[1]; if($mf){ if(@($mf.required_files) -notcontains 'build_task_bounded_executor.json'){ Add-Err "run${n}_manifest_executor_required_missing" } } }
$activeAfter=TreeStats '.runtime/active_compact_semantic_memory_v1'
$queueAfter=TreeStats '.runtime/compact_memory_intake_v1/queue'
if($activeBefore.files -ne $activeAfter.files -or $activeBefore.bytes -ne $activeAfter.bytes){ Add-Err 'active_memory_changed' }
if($queueAfter.files -lt ($queueBefore.files + 2)){ Add-Err "queue_files_not_increased_by_2:before=$($queueBefore.files):after=$($queueAfter.files)" }
$launcherHashAfter=(Get-FileHash 'operations/autonomous_inner_motor/start_agent_life_v1.ps1' -Algorithm SHA256).Hash
$runnerHashAfter=(Get-FileHash $runner -Algorithm SHA256).Hash
if($launcherHashBefore -ne $launcherHashAfter){ Add-Err 'launcher_hash_changed' }
if($runnerHashBefore -ne $runnerHashAfter){ Add-Err 'runner_hash_changed_during_validation' }
$procs=@(Get-CimInstance Win32_Process | Where-Object { $_.ProcessId -ne $PID -and $_.CommandLine -and $_.CommandLine -notmatch 'Get-CimInstance Win32_Process|validate_build_task_bounded_executor_v2_allowed_dry_run.ps1' -and $_.CommandLine -match '\s-File\s+.*(start_agent_life_v1.ps1|run_autonomous_inner_motor.ps1|run_continuous_agent_runtime_v1_lab.ps1|school|invoke_body_self_inspection_circuit_v1.ps1)|codex exec|node_modules.*@openai/codex|node.*codex.js|continuous_agent_runtime_v1' })
if($procs.Count -ne 0){ Add-Err "process_count_not_zero:$($procs.Count)" }
$status=if($errors.Count -eq 0){'PASS_BUILD_TASK_BOUNDED_EXECUTOR_V2_ALLOWED_DRY_RUN'}else{'FAIL_BUILD_TASK_BOUNDED_EXECUTOR_V2_ALLOWED_DRY_RUN'}
$canonical=[ordered]@{
  schema='build_task_bounded_executor_v2_allowed_dry_run_validation'
  status=$status
  checked_at=(Get-Date).ToUniversalTime().ToString('o')
  output_root=$outputRoot
  run1=$run1
  run2=$run2
  run2_previous_state_found=if($state2){$state2.continuity.previous_state_found}else{$false}
  gate_decision=if($gate2){$gate2.gate_decision}else{$null}
  effective_dry_run_allowed=if($gate2){$gate2.effective_dry_run_allowed}else{$null}
  effective_execution_allowed=if($gate2){$gate2.effective_execution_allowed}else{$null}
  execution_status=if($executor2){$executor2.execution_status}else{$null}
  dry_run_plan_ready=if($executor2){$executor2.dry_run_plan_ready}else{$null}
  planned_operations_count=if($executor2){@($executor2.planned_operations).Count}else{$null}
  executed_files_count=if($executor2){$executor2.executed_files_count}else{$null}
  validator_ran=if($executor2){$executor2.validator_ran}else{$null}
  rollback_needed=if($executor2){$executor2.rollback_needed}else{$null}
  contract_task_id=if($executor2){$executor2.contract_task_id}else{$null}
  active_memory_before=$activeBefore
  active_memory_after=$activeAfter
  queue_before=$queueBefore
  queue_after=$queueAfter
  process_count=$procs.Count
  errors=@($errors)
  boundary=[ordered]@{runtime_launched_by_validator=$true; cycles=2; dry_run_authority_used=$true; dry_run_plan_ready=if($executor2){$executor2.dry_run_plan_ready}else{$false}; execution_performed=$false; validator_ran=$false; memory_ingestion_mode='QueueOnly'; active_memory_mutated=$false; direct_active_memory_write=$false; no_new_store_created=$true; school_launched=$false; codex_launched=$false; web_launched=$false}
}
WJson $canonicalProof $canonical
$accept=[ordered]@{
  schema='build_task_bounded_executor_v2_allowed_dry_run_acceptance'
  status=if($status -eq 'PASS_BUILD_TASK_BOUNDED_EXECUTOR_V2_ALLOWED_DRY_RUN'){'ACCEPTED_BUILD_TASK_BOUNDED_EXECUTOR_V2_ALLOWED_DRY_RUN'}else{'REJECTED_BUILD_TASK_BOUNDED_EXECUTOR_V2_ALLOWED_DRY_RUN'}
  accepted_at=(Get-Date).ToUniversalTime().ToString('o')
  proof=$canonicalProof
  gate_decision=$canonical.gate_decision
  execution_status=$canonical.execution_status
  planned_operations_count=$canonical.planned_operations_count
  executed_files_count=$canonical.executed_files_count
  validator_ran=$canonical.validator_ran
  may_claim='Agent can produce an authorized dry-run plan over allowed files while performing no writes and no validator execution.'
  may_not_claim=@('authorized write execution implemented','validator execution implemented','repo patch executed by agent','auto-patching allowed','RAM infinite life complete','school launched','active compact memory updated')
  boundary=$canonical.boundary
}
WJson $acceptance $accept
Write-Host "STATUS=$status"
if($errors.Count -gt 0){ foreach($e in $errors){ Write-Host "ERROR=$e" }; exit 1 }
