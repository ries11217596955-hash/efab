$ErrorActionPreference='Stop'
$errors=@()
function Add-Err([string]$e){ $script:errors += $e }
function WJson($path,$obj){ $dir=Split-Path $path -Parent; if($dir){New-Item -ItemType Directory -Force -Path $dir|Out-Null}; $json=($obj|ConvertTo-Json -Depth 100) -replace "`r`n","`n"; [System.IO.File]::WriteAllText((Join-Path (Get-Location).Path $path),$json.TrimEnd()+"`n",(New-Object System.Text.UTF8Encoding($false))) }
function TreeStats($p){ if(-not(Test-Path $p)){return [ordered]@{exists=$false;files=0;bytes=0}}; $files=@(Get-ChildItem $p -Recurse -File -Force -ErrorAction SilentlyContinue); return [ordered]@{exists=$true;files=$files.Count;bytes=[int64](($files|Measure-Object Length -Sum).Sum)} }
$runner='operations/autonomous_inner_motor/run_autonomous_inner_motor.ps1'
$proofPath='tests/self_development/DYNAMIC_MEMORY_RETRIEVAL_BUDGET_V1_PROOF.json'
$acceptance='operations/autonomous_inner_motor/reports/DYNAMIC_MEMORY_RETRIEVAL_BUDGET_V1_ACCEPTANCE.json'
$stamp=(Get-Date).ToUniversalTime().ToString('yyyyMMdd_HHmmss')
$outputRoot=".runtime/dynamic_memory_retrieval_budget_v1_validation/$stamp"
New-Item -ItemType Directory -Force -Path $outputRoot | Out-Null
$seedQuestion='What assumption under the repeated topic has not been examined yet, and what different angle would make the next cycle stronger?'
$seedRun=Join-Path $outputRoot 'prev_refocus_seed_001'
New-Item -ItemType Directory -Force -Path $seedRun | Out-Null
WJson (Join-Path $seedRun 'refocus_to_new_thought_seed.json') ([ordered]@{schema='refocus_to_new_thought_seed_v1';status='PASS_REFOCUS_TO_NEW_THOUGHT_SEED_V1';run_id='prev_refocus_seed_001';refocus_needed=$true;repeated_task='FRONTIER_TO_BUILD_TASK_ROUTER_V1';repeated_topic='aimo.deep_thinking.recursive_thought_frame.memory_learning';new_thought_seed=[ordered]@{seed_id='seed_test_budget_001';seed_type='NEW_THOUGHT_QUESTION';question=$seedQuestion;lens='unexamined_assumption';goal='Move from repeated topic to a new question.';must_not_repeat_task='FRONTIER_TO_BUILD_TASK_ROUTER_V1';must_not_repeat_topic='aimo.deep_thinking.recursive_thought_frame.memory_learning';success_condition='Next cycle should use focused retrieval budget.'};boundary=[ordered]@{thinking_only=$true;no_action_execution=$true;no_active_memory_write=$true}})
$tokens=$null;$parseErrors=$null
[System.Management.Automation.Language.Parser]::ParseFile((Resolve-Path $runner),[ref]$tokens,[ref]$parseErrors)|Out-Null
foreach($e in $parseErrors){ Add-Err "runner_parse:$($e.Message)" }
$text=Get-Content $runner -Raw
foreach($needle in @('function New-DynamicMemoryRetrievalBudget','dynamic_memory_retrieval_budget.json','dynamic_memory_retrieval_budget=$dynamicMemoryRetrievalBudget','budget_target_count=$budgetLimit','retrieval_budget=$DynamicMemoryRetrievalBudget')){ if($text -notlike "*$needle*"){ Add-Err "runner_missing:$needle" } }
$activeBefore=TreeStats '.runtime/active_compact_semantic_memory_v1'
$queueBefore=TreeStats '.runtime/compact_memory_intake_v1/queue'
$launcherHashBefore=(Get-FileHash 'operations/autonomous_inner_motor/start_agent_life_v1.ps1' -Algorithm SHA256).Hash
$runnerHashBefore=(Get-FileHash $runner -Algorithm SHA256).Hash
$run=$null
if($errors.Count -eq 0){
  $before=@(Get-ChildItem $outputRoot -Directory | Select-Object -ExpandProperty FullName)
  powershell -NoProfile -ExecutionPolicy Bypass -File $runner -Mode SandboxExploration -EnableDeepThinking -OutputRoot $outputRoot
  $exit=$LASTEXITCODE
  if($exit -ne 0){ Add-Err "runner_exit_code:$exit" }
  $after=@(Get-ChildItem $outputRoot -Directory | Sort-Object LastWriteTime -Descending)
  $new=$null
  foreach($d in $after){ if($before -notcontains $d.FullName){ $new=$d; break } }
  if($new){ $run=[ordered]@{run_root=$new.FullName.Replace((Get-Location).Path+'\',''); run_root_full=$new.FullName} } else { Add-Err 'new_run_root_missing' }
}
$proof=$null;$budget=$null;$retrieval=$null;$consume=$null;$manifest=$null
if($run){
  foreach($pair in @(@('proof','SANDBOX_EXPLORATION_PROOF.json'),@('budget','dynamic_memory_retrieval_budget.json'),@('retrieval','selective_compact_memory_retrieval.json'),@('consume','new_thought_seed_to_active_goal.json'),@('manifest','sandbox_proof_pack_manifest.json'))){
    $var=$pair[0]; $file=Join-Path $run.run_root_full $pair[1]
    if(Test-Path $file){ Set-Variable -Name $var -Value (Get-Content $file -Raw|ConvertFrom-Json) } else { Add-Err "missing_run_file:$($pair[1])" }
  }
}
if($consume){
  if($consume.seed_consumed -ne $true){ Add-Err 'seed_not_consumed' }
  if($consume.active_goal.question -ne $seedQuestion){ Add-Err 'active_goal_not_seed_question' }
}
if($budget){
  if($budget.status -ne 'PASS_DYNAMIC_MEMORY_RETRIEVAL_BUDGET_V1'){ Add-Err "budget_status:$($budget.status)" }
  if([int]$budget.base_limit -ne 7){ Add-Err "base_limit:$($budget.base_limit)" }
  if([int]$budget.target_count -ne 5){ Add-Err "target_count_not_5:$($budget.target_count)" }
  if($budget.inputs.seed_consumed -ne $true){ Add-Err 'budget_seed_consumed_not_true' }
  if($budget.inputs.active_memory_ready -ne $true){ Add-Err 'budget_active_memory_ready_not_true' }
  if($budget.boundary.budget_only -ne $true){ Add-Err 'budget_boundary_not_only' }
}
if($retrieval){
  if([int]$retrieval.budget_target_count -ne 5){ Add-Err "retrieval_budget_target_not_5:$($retrieval.budget_target_count)" }
  if([int]$retrieval.selected_count -gt 5){ Add-Err "selected_count_gt_5:$($retrieval.selected_count)" }
  if($retrieval.retrieval_budget.target_count -ne 5){ Add-Err 'retrieval_embedded_budget_not_5' }
  if($retrieval.active_memory_mutated -ne $false){ Add-Err 'retrieval_active_memory_mutated_not_false' }
}
if($proof){
  if(-not $proof.PSObject.Properties['dynamic_memory_retrieval_budget']){ Add-Err 'proof_missing_dynamic_budget' }
  if(@($proof.decision_trace | Where-Object { $_.step -eq 'dynamic_memory_retrieval_budget' }).Count -ne 1){ Add-Err 'decision_trace_missing_dynamic_budget' }
}
if($manifest){ if(@($manifest.required_files) -notcontains 'dynamic_memory_retrieval_budget.json'){ Add-Err 'manifest_missing_dynamic_budget' } }
$activeAfter=TreeStats '.runtime/active_compact_semantic_memory_v1'
$queueAfter=TreeStats '.runtime/compact_memory_intake_v1/queue'
if($activeBefore.files -ne $activeAfter.files -or $activeBefore.bytes -ne $activeAfter.bytes){ Add-Err 'active_memory_changed' }
if($queueBefore.files -ne $queueAfter.files){ Add-Err "queue_changed_without_memory_learning:before=$($queueBefore.files):after=$($queueAfter.files)" }
if((Get-FileHash 'operations/autonomous_inner_motor/start_agent_life_v1.ps1' -Algorithm SHA256).Hash -ne $launcherHashBefore){ Add-Err 'launcher_hash_changed' }
if((Get-FileHash $runner -Algorithm SHA256).Hash -ne $runnerHashBefore){ Add-Err 'runner_hash_changed_during_validation' }
$procs=@(Get-CimInstance Win32_Process | Where-Object { $_.ProcessId -ne $PID -and $_.CommandLine -and $_.CommandLine -notmatch 'Get-CimInstance Win32_Process|validate_dynamic_memory_retrieval_budget_v1.ps1' -and $_.CommandLine -match '\s-File\s+.*(start_agent_life_v1.ps1|run_autonomous_inner_motor.ps1|run_continuous_agent_runtime_v1_lab.ps1|school|invoke_body_self_inspection_circuit_v1.ps1)|codex exec|node_modules.*@openai/codex|node.*codex.js|continuous_agent_runtime_v1' })
if($procs.Count -ne 0){ Add-Err "process_count_not_zero:$($procs.Count)" }
$status=if($errors.Count -eq 0){'PASS_DYNAMIC_MEMORY_RETRIEVAL_BUDGET_V1'}else{'FAIL_DYNAMIC_MEMORY_RETRIEVAL_BUDGET_V1'}
$canonical=[ordered]@{schema='dynamic_memory_retrieval_budget_v1_validation';status=$status;checked_at=(Get-Date).ToUniversalTime().ToString('o');run=$run;seed_consumed=if($consume){$consume.seed_consumed}else{$false};active_goal=if($consume){$consume.active_goal.question}else{$null};budget_target_count=if($budget){$budget.target_count}else{$null};budget_reason=if($budget){$budget.reason}else{$null};selected_count=if($retrieval){$retrieval.selected_count}else{$null};base_limit=if($budget){$budget.base_limit}else{$null};queue_before=$queueBefore;queue_after=$queueAfter;active_memory_before=$activeBefore;active_memory_after=$activeAfter;process_count=$procs.Count;errors=@($errors);boundary=[ordered]@{runtime_launched_by_validator=$true;thinking_only=$true;action_execution_allowed=$false;memory_learning_enabled=$false;active_memory_mutated=$false;direct_active_memory_write=$false;no_new_store_created=$true;codex_launched=$false;web_launched=$false}}
WJson $proofPath $canonical
$accept=[ordered]@{schema='dynamic_memory_retrieval_budget_v1_acceptance';status=if($status -eq 'PASS_DYNAMIC_MEMORY_RETRIEVAL_BUDGET_V1'){'ACCEPTED_DYNAMIC_MEMORY_RETRIEVAL_BUDGET_V1'}else{'REJECTED_DYNAMIC_MEMORY_RETRIEVAL_BUDGET_V1'};accepted_at=(Get-Date).ToUniversalTime().ToString('o');proof=$proofPath;may_claim='Memory retrieval now uses a dynamic budget derived from active goal/refocus seed and wake reflex context; refocus seed path uses target_count=5 instead of fixed 7.';may_not_claim=@('full adaptive relevance model implemented','dynamic budget influences all future topics perfectly','action execution allowed','active compact memory updated');boundary=$canonical.boundary}
WJson $acceptance $accept
Write-Host "STATUS=$status"
if($errors.Count -gt 0){ foreach($e in $errors){ Write-Host "ERROR=$e" }; exit 1 }
