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
  powershell -NoProfile -ExecutionPolicy Bypass -File operations/autonomous_inner_motor/run_autonomous_inner_motor.ps1 -Mode SandboxExploration -EnableDeepThinking -EnableMemoryLearning -MemoryIngestionMode QueueOnly -OutputRoot $outputRoot -Question $question
  $exit=$LASTEXITCODE
  $after=@(); if(Test-Path $outputRoot){ $after=@(Get-ChildItem $outputRoot -Directory -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending) }
  $new=$null
  foreach($d in $after){ if($before -notcontains $d.FullName){ $new=$d; break } }
  if(-not $new -and $after.Count -gt 0){ $new=$after[0] }
  return [ordered]@{ exit_code=$exit; run_root=if($new){$new.FullName.Replace((Get-Location).Path+'\','')}else{$null}; run_root_full=if($new){$new.FullName}else{$null} }
}
$runner='operations/autonomous_inner_motor/run_autonomous_inner_motor.ps1'
$stamp=(Get-Date).ToUniversalTime().ToString('yyyyMMdd_HHmmss')
$outputRoot=".runtime/build_task_bounded_executor_v1_validation/$stamp"
$canonicalProof='tests/self_development/BUILD_TASK_BOUNDED_EXECUTOR_V1_PROOF.json'
$acceptance='operations/autonomous_inner_motor/reports/BUILD_TASK_BOUNDED_EXECUTOR_V1_ACCEPTANCE.json'
$tokens=$null;$parseErrors=$null
if(-not(Test-Path $runner)){ Add-Err "missing_runner:$runner" } else { [System.Management.Automation.Language.Parser]::ParseFile((Resolve-Path $runner),[ref]$tokens,[ref]$parseErrors)|Out-Null; foreach($e in $parseErrors){ Add-Err "runner_parse:$($e.Message)" } }
$runnerText=if(Test-Path $runner){Get-Content $runner -Raw}else{''}
foreach($needle in @('function New-BuildTaskBoundedExecutor','build_task_bounded_executor.json','build_task_bounded_executor=$buildTaskBoundedExecutor','step=''build_task_bounded_executor''','NOT_EXECUTED_GATE_BLOCKED','executed_files_count=0','validator_ran=$false')){ if($runnerText -notlike "*$needle*"){ Add-Err "runner_missing:$needle" } }
$activeBefore=TreeStats '.runtime/active_compact_semantic_memory_v1'
$queueBefore=TreeStats '.runtime/compact_memory_intake_v1/queue'
$launcherHashBefore=(Get-FileHash 'operations/autonomous_inner_motor/start_agent_life_v1.ps1' -Algorithm SHA256).Hash
$runnerHashBefore=(Get-FileHash $runner -Algorithm SHA256).Hash
$run1=$null; $run2=$null
if($errors.Count -eq 0){
  $run1=Run-Cycle $outputRoot 'Validate BUILD_TASK_BOUNDED_EXECUTOR_V1 cycle 1: executor must respect blocked gate and not execute.'
  if($run1.exit_code -ne 0){ Add-Err "run1_exit_code:$($run1.exit_code)" }
  Start-Sleep -Seconds 2
  $run2=Run-Cycle $outputRoot 'Validate BUILD_TASK_BOUNDED_EXECUTOR_V1 cycle 2: continuity plus blocked executor, no repo mutation.'
  if($run2.exit_code -ne 0){ Add-Err "run2_exit_code:$($run2.exit_code)" }
}
$proof1=$null;$proof2=$null;$executor1=$null;$executor2=$null;$gate2=$null;$state2=$null;$manifest1=$null;$manifest2=$null
foreach($pair in @(@('1',$run1),@('2',$run2))){
  $n=$pair[0]; $r=$pair[1]
  if(-not $r -or -not $r.run_root_full){ Add-Err "run${n}_root_missing"; continue }
  $proofPath=Join-Path $r.run_root_full 'SANDBOX_EXPLORATION_PROOF.json'
  $executorPath=Join-Path $r.run_root_full 'build_task_bounded_executor.json'
  $gatePath=Join-Path $r.run_root_full 'build_task_contract_execution_gate.json'
  $statePath=Join-Path $r.run_root_full 'short_term_mind_state.json'
  $manifestPath=Join-Path $r.run_root_full 'sandbox_proof_pack_manifest.json'
  if(Test-Path $proofPath){ Set-Variable -Name "proof$n" -Value (Get-Content $proofPath -Raw|ConvertFrom-Json) } else { Add-Err "run${n}_proof_missing" }
  if(Test-Path $executorPath){ Set-Variable -Name "executor$n" -Value (Get-Content $executorPath -Raw|ConvertFrom-Json) } else { Add-Err "run${n}_executor_missing" }
  if($n -eq '2' -and (Test-Path $gatePath)){ $gate2=Get-Content $gatePath -Raw|ConvertFrom-Json }
  if($n -eq '2' -and (Test-Path $statePath)){ $state2=Get-Content $statePath -Raw|ConvertFrom-Json }
  if(Test-Path $manifestPath){ Set-Variable -Name "manifest$n" -Value (Get-Content $manifestPath -Raw|ConvertFrom-Json) } else { Add-Err "run${n}_manifest_missing" }
}
foreach($x in @(@('1',$executor1),@('2',$executor2))){
  $n=$x[0]; $ex=$x[1]
  if($ex){
    if($ex.status -ne 'PASS_BUILD_TASK_BOUNDED_EXECUTOR_V1'){ Add-Err "run${n}_executor_status:$($ex.status)" }
    if($ex.schema -ne 'build_task_bounded_executor_v1'){ Add-Err "run${n}_executor_schema:$($ex.schema)" }
    if($ex.execution_status -ne 'NOT_EXECUTED_GATE_BLOCKED'){ Add-Err "run${n}_execution_status:$($ex.execution_status)" }
    if($ex.gate_effective_execution_allowed -ne $false){ Add-Err "run${n}_gate_effective_execution_allowed_not_false" }
    if([int]$ex.executed_files_count -ne 0){ Add-Err "run${n}_executed_files_count:$($ex.executed_files_count)" }
    if(@($ex.executed_files).Count -ne 0){ Add-Err "run${n}_executed_files_not_empty" }
    if(@($ex.executed_operations).Count -ne 0){ Add-Err "run${n}_executed_operations_not_empty" }
    if($ex.validator_ran -ne $false){ Add-Err "run${n}_validator_ran_not_false" }
    if($ex.proof_written_by_executor -ne $false){ Add-Err "run${n}_proof_written_by_executor_not_false" }
    if($ex.rollback_needed -ne $false){ Add-Err "run${n}_rollback_needed_not_false" }
    if($ex.forbidden_surface_touched -ne $false){ Add-Err "run${n}_forbidden_surface_touched_not_false" }
    if($ex.boundary.executor_only -ne $true){ Add-Err "run${n}_executor_only_not_true" }
    if($ex.boundary.respects_gate -ne $true){ Add-Err "run${n}_respects_gate_not_true" }
    if($ex.boundary.execution_performed -ne $false){ Add-Err "run${n}_execution_performed_not_false" }
    if($ex.boundary.no_repo_mutation_by_executor -ne $true){ Add-Err "run${n}_no_repo_mutation_by_executor_not_true" }
    if($ex.boundary.no_contract_file_write -ne $true){ Add-Err "run${n}_no_contract_file_write_not_true" }
    if($ex.boundary.direct_active_memory_write -ne $false){ Add-Err "run${n}_direct_active_memory_write_not_false" }
    if($ex.next_required_step -ne 'AUTHORIZE_OR_REWRITE_CONTRACT_BEFORE_EXECUTION'){ Add-Err "run${n}_next_required_step:$($ex.next_required_step)" }
  }
}
if($gate2){
  if($gate2.gate_decision -ne 'BLOCKED_CONTRACT_EXECUTION_NOT_AUTHORIZED'){ Add-Err "run2_gate_decision:$($gate2.gate_decision)" }
  if($gate2.effective_execution_allowed -ne $false){ Add-Err 'run2_gate_allowed_not_false' }
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
$procs=@(Get-CimInstance Win32_Process | Where-Object { $_.ProcessId -ne $PID -and $_.CommandLine -and $_.CommandLine -notmatch 'Get-CimInstance Win32_Process|validate_build_task_bounded_executor_v1.ps1' -and $_.CommandLine -match '\s-File\s+.*(start_agent_life_v1.ps1|run_autonomous_inner_motor.ps1|run_continuous_agent_runtime_v1_lab.ps1|school|invoke_body_self_inspection_circuit_v1.ps1)|codex exec|node_modules.*@openai/codex|node.*codex.js|continuous_agent_runtime_v1' })
if($procs.Count -ne 0){ Add-Err "process_count_not_zero:$($procs.Count)" }
$status=if($errors.Count -eq 0){'PASS_BUILD_TASK_BOUNDED_EXECUTOR_V1'}else{'FAIL_BUILD_TASK_BOUNDED_EXECUTOR_V1'}
$canonical=[ordered]@{
  schema='build_task_bounded_executor_v1_validation'
  status=$status
  checked_at=(Get-Date).ToUniversalTime().ToString('o')
  output_root=$outputRoot
  run1=$run1
  run2=$run2
  run2_previous_state_found=if($state2){$state2.continuity.previous_state_found}else{$false}
  execution_status=if($executor2){$executor2.execution_status}else{$null}
  gate_decision=if($executor2){$executor2.gate_decision}else{$null}
  gate_effective_execution_allowed=if($executor2){$executor2.gate_effective_execution_allowed}else{$null}
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
  boundary=[ordered]@{runtime_launched_by_validator=$true; cycles=2; executor_only=$true; respects_gate=$true; execution_performed=$false; memory_ingestion_mode='QueueOnly'; active_memory_mutated=$false; direct_active_memory_write=$false; no_new_store_created=$true; school_launched=$false; codex_launched=$false; web_launched=$false}
}
WJson $canonicalProof $canonical
$accept=[ordered]@{
  schema='build_task_bounded_executor_v1_acceptance'
  status=if($status -eq 'PASS_BUILD_TASK_BOUNDED_EXECUTOR_V1'){'ACCEPTED_BUILD_TASK_BOUNDED_EXECUTOR_V1'}else{'REJECTED_BUILD_TASK_BOUNDED_EXECUTOR_V1'}
  accepted_at=(Get-Date).ToUniversalTime().ToString('o')
  proof=$canonicalProof
  execution_status=$canonical.execution_status
  gate_decision=$canonical.gate_decision
  executed_files_count=$canonical.executed_files_count
  validator_ran=$canonical.validator_ran
  may_claim='Agent has a bounded executor shell that respects the execution gate and performs no repo mutation when gate blocks.'
  may_not_claim=@('authorized write execution implemented','validator execution implemented','repo patch executed by agent','auto-patching allowed','RAM infinite life complete','school launched','active compact memory updated')
  boundary=$canonical.boundary
}
WJson $acceptance $accept
Write-Host "STATUS=$status"
if($errors.Count -gt 0){ foreach($e in $errors){ Write-Host "ERROR=$e" }; exit 1 }
