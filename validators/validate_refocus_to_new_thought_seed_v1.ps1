$ErrorActionPreference='Stop'
$errors=@()
function Add-Err([string]$e){ $script:errors += $e }
function WJson($path,$obj){ $dir=Split-Path $path -Parent; if($dir){New-Item -ItemType Directory -Force -Path $dir|Out-Null}; $json=($obj|ConvertTo-Json -Depth 100) -replace "`r`n","`n"; [System.IO.File]::WriteAllText((Join-Path (Get-Location).Path $path),$json.TrimEnd()+"`n",(New-Object System.Text.UTF8Encoding($false))) }
function TreeStats($p){ if(-not(Test-Path $p)){return [ordered]@{exists=$false;files=0;bytes=0}}; $files=@(Get-ChildItem $p -Recurse -File -Force -ErrorAction SilentlyContinue); return [ordered]@{exists=$true;files=$files.Count;bytes=[int64](($files|Measure-Object Length -Sum).Sum)} }
$runner='operations/autonomous_inner_motor/run_autonomous_inner_motor.ps1'
$proofPath='tests/self_development/REFOCUS_TO_NEW_THOUGHT_SEED_V1_PROOF.json'
$acceptance='operations/autonomous_inner_motor/reports/REFOCUS_TO_NEW_THOUGHT_SEED_V1_ACCEPTANCE.json'
$stamp=(Get-Date).ToUniversalTime().ToString('yyyyMMdd_HHmmss')
$outputRoot=".runtime/refocus_to_new_thought_seed_v1_validation/$stamp"
New-Item -ItemType Directory -Force -Path $outputRoot | Out-Null
for($i=1;$i -le 3;$i++){
  $d=Join-Path $outputRoot ("prev_repeat_{0}" -f $i)
  New-Item -ItemType Directory -Force -Path $d | Out-Null
  WJson (Join-Path $d 'short_term_mind_state.json') ([ordered]@{ schema='short_term_mind_state_v1'; status='PASS_SHORT_TERM_MIND_STATE_V1'; run_id="prev_repeat_$i"; completed_candidate=[ordered]@{ topic='aimo.deep_thinking.recursive_thought_frame.memory_learning'; route_status='RELEASED_TO_EXISTING_MULTI_SOURCE_WAREHOUSE' }; continuity=[ordered]@{ previous_state_found=($i -gt 1) } })
  WJson (Join-Path $d 'short_term_state_to_next_task_router.json') ([ordered]@{ schema='short_term_state_to_next_task_router_v1'; status='PASS_SHORT_TERM_STATE_TO_NEXT_TASK_ROUTER_V1'; run_id="prev_repeat_$i"; selected_next_task='FRONTIER_TO_BUILD_TASK_ROUTER_V1' })
}
$tokens=$null;$parseErrors=$null
[System.Management.Automation.Language.Parser]::ParseFile((Resolve-Path $runner),[ref]$tokens,[ref]$parseErrors)|Out-Null
foreach($e in $parseErrors){ Add-Err "runner_parse:$($e.Message)" }
$text=Get-Content $runner -Raw
foreach($needle in @('function New-RefocusToNewThoughtSeed','refocus_to_new_thought_seed.json','refocus_to_new_thought_seed=$refocusToNewThoughtSeed','REFOCUS_TO_NEW_THOUGHT_SEED_V1','Use new_thought_seed.question as the next active thought')){ if($text -notlike "*$needle*"){ Add-Err "runner_missing:$needle" } }
$activeBefore=TreeStats '.runtime/active_compact_semantic_memory_v1'
$queueBefore=TreeStats '.runtime/compact_memory_intake_v1/queue'
$launcherHashBefore=(Get-FileHash 'operations/autonomous_inner_motor/start_agent_life_v1.ps1' -Algorithm SHA256).Hash
$runnerHashBefore=(Get-FileHash $runner -Algorithm SHA256).Hash
$run=$null
if($errors.Count -eq 0){
  $before=@(Get-ChildItem $outputRoot -Directory | Select-Object -ExpandProperty FullName)
  powershell -NoProfile -ExecutionPolicy Bypass -File $runner -Mode SandboxExploration -EnableDeepThinking -EnableMemoryLearning -MemoryIngestionMode QueueOnly -OutputRoot $outputRoot -Question 'Validate refocus seed: repeated loop must become a new thought question, not an action.'
  $exit=$LASTEXITCODE
  if($exit -ne 0){ Add-Err "runner_exit_code:$exit" }
  $after=@(Get-ChildItem $outputRoot -Directory | Sort-Object LastWriteTime -Descending)
  $new=$null
  foreach($d in $after){ if($before -notcontains $d.FullName){ $new=$d; break } }
  if($new){ $run=[ordered]@{run_root=$new.FullName.Replace((Get-Location).Path+'\',''); run_root_full=$new.FullName} } else { Add-Err 'new_run_root_missing' }
}
$proof=$null;$pattern=$null;$router=$null;$seed=$null;$manifest=$null
if($run){
  foreach($pair in @(@('proof','SANDBOX_EXPLORATION_PROOF.json'),@('pattern','recent_thought_repetition_pattern.json'),@('router','short_term_state_to_next_task_router.json'),@('seed','refocus_to_new_thought_seed.json'),@('manifest','sandbox_proof_pack_manifest.json'))){
    $var=$pair[0]; $file=Join-Path $run.run_root_full $pair[1]
    if(Test-Path $file){ Set-Variable -Name $var -Value (Get-Content $file -Raw|ConvertFrom-Json) } else { Add-Err "missing_run_file:$($pair[1])" }
  }
}
if($pattern){
  if($pattern.repeat_detected -ne $true){ Add-Err 'repeat_not_detected' }
  if($pattern.repeated_task -ne 'FRONTIER_TO_BUILD_TASK_ROUTER_V1'){ Add-Err "repeated_task:$($pattern.repeated_task)" }
}
if($router){
  if($router.selected_next_task -ne 'REPEAT_TO_REFOCUS_ROUTER_V1'){ Add-Err "selected_next_task:$($router.selected_next_task)" }
  if($router.repeat_refocus_selected -ne $true){ Add-Err 'repeat_refocus_selected_not_true' }
}
if($seed){
  if($seed.status -ne 'PASS_REFOCUS_TO_NEW_THOUGHT_SEED_V1'){ Add-Err "seed_status:$($seed.status)" }
  if($seed.refocus_needed -ne $true){ Add-Err 'seed_refocus_needed_not_true' }
  if($seed.new_thought_seed.seed_type -ne 'NEW_THOUGHT_QUESTION'){ Add-Err "seed_type:$($seed.new_thought_seed.seed_type)" }
  if([string]::IsNullOrWhiteSpace([string]$seed.new_thought_seed.question)){ Add-Err 'seed_question_empty' }
  if($seed.new_thought_seed.question -like '*FRONTIER_TO_BUILD_TASK_ROUTER_V1*'){ Add-Err 'seed_question_repeats_technical_task' }
  if($seed.new_thought_seed.must_not_repeat_task -ne 'FRONTIER_TO_BUILD_TASK_ROUTER_V1'){ Add-Err "must_not_repeat_task:$($seed.new_thought_seed.must_not_repeat_task)" }
  if($seed.memory_retrieval_guidance.current_limit -ne 7){ Add-Err "memory_limit_note_bad:$($seed.memory_retrieval_guidance.current_limit)" }
  if($seed.memory_retrieval_guidance.dynamic_budget_not_built -ne $true){ Add-Err 'dynamic_budget_flag_not_true' }
  if($seed.boundary.thinking_only -ne $true){ Add-Err 'seed_boundary_thinking_not_true' }
  if($seed.boundary.no_action_execution -ne $true){ Add-Err 'seed_boundary_action_not_blocked' }
}
if($proof){
  if(-not $proof.PSObject.Properties['refocus_to_new_thought_seed']){ Add-Err 'proof_missing_refocus_seed' }
  if(@($proof.decision_trace | Where-Object { $_.step -eq 'refocus_to_new_thought_seed' }).Count -ne 1){ Add-Err 'decision_trace_missing_refocus_seed' }
}
if($manifest){ if(@($manifest.required_files) -notcontains 'refocus_to_new_thought_seed.json'){ Add-Err 'manifest_missing_refocus_seed' } }
$activeAfter=TreeStats '.runtime/active_compact_semantic_memory_v1'
$queueAfter=TreeStats '.runtime/compact_memory_intake_v1/queue'
if($activeBefore.files -ne $activeAfter.files -or $activeBefore.bytes -ne $activeAfter.bytes){ Add-Err 'active_memory_changed' }
if($queueAfter.files -lt ($queueBefore.files + 1)){ Add-Err "queue_not_increased:before=$($queueBefore.files):after=$($queueAfter.files)" }
if((Get-FileHash 'operations/autonomous_inner_motor/start_agent_life_v1.ps1' -Algorithm SHA256).Hash -ne $launcherHashBefore){ Add-Err 'launcher_hash_changed' }
if((Get-FileHash $runner -Algorithm SHA256).Hash -ne $runnerHashBefore){ Add-Err 'runner_hash_changed_during_validation' }
$procs=@(Get-CimInstance Win32_Process | Where-Object { $_.ProcessId -ne $PID -and $_.CommandLine -and $_.CommandLine -notmatch 'Get-CimInstance Win32_Process|validate_refocus_to_new_thought_seed_v1.ps1' -and $_.CommandLine -match '\s-File\s+.*(start_agent_life_v1.ps1|run_autonomous_inner_motor.ps1|run_continuous_agent_runtime_v1_lab.ps1|school|invoke_body_self_inspection_circuit_v1.ps1)|codex exec|node_modules.*@openai/codex|node.*codex.js|continuous_agent_runtime_v1' })
if($procs.Count -ne 0){ Add-Err "process_count_not_zero:$($procs.Count)" }
$status=if($errors.Count -eq 0){'PASS_REFOCUS_TO_NEW_THOUGHT_SEED_V1'}else{'FAIL_REFOCUS_TO_NEW_THOUGHT_SEED_V1'}
$canonical=[ordered]@{ schema='refocus_to_new_thought_seed_v1_validation'; status=$status; checked_at=(Get-Date).ToUniversalTime().ToString('o'); run=$run; repeated_task=if($pattern){$pattern.repeated_task}else{$null}; repeated_topic=if($pattern){$pattern.repeated_topic}else{$null}; selected_next_task=if($router){$router.selected_next_task}else{$null}; seed_status=if($seed){$seed.status}else{$null}; seed_question=if($seed){$seed.new_thought_seed.question}else{$null}; seed_lens=if($seed){$seed.new_thought_seed.lens}else{$null}; memory_limit_note=if($seed){$seed.memory_retrieval_guidance}else{$null}; queue_before=$queueBefore; queue_after=$queueAfter; active_memory_before=$activeBefore; active_memory_after=$activeAfter; process_count=$procs.Count; errors=@($errors); boundary=[ordered]@{runtime_launched_by_validator=$true; thinking_only=$true; action_execution_allowed=$false; memory_ingestion_mode='QueueOnly'; active_memory_mutated=$false; direct_active_memory_write=$false; no_new_store_created=$true; codex_launched=$false; web_launched=$false} }
WJson $proofPath $canonical
$accept=[ordered]@{ schema='refocus_to_new_thought_seed_v1_acceptance'; status=if($status -eq 'PASS_REFOCUS_TO_NEW_THOUGHT_SEED_V1'){'ACCEPTED_REFOCUS_TO_NEW_THOUGHT_SEED_V1'}else{'REJECTED_REFOCUS_TO_NEW_THOUGHT_SEED_V1'}; accepted_at=(Get-Date).ToUniversalTime().ToString('o'); proof=$proofPath; may_claim='Agent converts repeated topic/task into a new thought seed question before action routing.'; may_not_claim=@('new seed is already consumed by next cycle','dynamic memory retrieval budget implemented','rich autonomous thought generation solved','action execution allowed','active compact memory updated'); boundary=$canonical.boundary }
WJson $acceptance $accept
Write-Host "STATUS=$status"
if($errors.Count -gt 0){ foreach($e in $errors){ Write-Host "ERROR=$e" }; exit 1 }
