$ErrorActionPreference='Stop'
$errors=@()
function Add-Err([string]$e){ $script:errors += $e }
function WJson($path,$obj){ $dir=Split-Path $path -Parent; if($dir){New-Item -ItemType Directory -Force -Path $dir|Out-Null}; $json=($obj|ConvertTo-Json -Depth 100) -replace "`r`n","`n"; [System.IO.File]::WriteAllText((Join-Path (Get-Location).Path $path),$json.TrimEnd()+"`n",(New-Object System.Text.UTF8Encoding($false))) }
function TreeStats($p){ if(-not(Test-Path $p)){return [ordered]@{exists=$false;files=0;bytes=0}}; $files=@(Get-ChildItem $p -Recurse -File -Force -ErrorAction SilentlyContinue); return [ordered]@{exists=$true;files=$files.Count;bytes=[int64](($files|Measure-Object Length -Sum).Sum)} }
$runner='operations/autonomous_inner_motor/run_autonomous_inner_motor.ps1'
$proofPath='tests/self_development/NEW_THOUGHT_SEED_TO_ACTIVE_GOAL_V1_PROOF.json'
$acceptance='operations/autonomous_inner_motor/reports/NEW_THOUGHT_SEED_TO_ACTIVE_GOAL_V1_ACCEPTANCE.json'
$stamp=(Get-Date).ToUniversalTime().ToString('yyyyMMdd_HHmmss')
$outputRoot=".runtime/new_thought_seed_to_active_goal_v1_validation/$stamp"
New-Item -ItemType Directory -Force -Path $outputRoot | Out-Null
$seedQuestion='What assumption under the repeated topic has not been examined yet, and what different angle would make the next cycle stronger?'
$seedRun=Join-Path $outputRoot 'prev_refocus_seed_001'
New-Item -ItemType Directory -Force -Path $seedRun | Out-Null
WJson (Join-Path $seedRun 'refocus_to_new_thought_seed.json') ([ordered]@{
  schema='refocus_to_new_thought_seed_v1'
  status='PASS_REFOCUS_TO_NEW_THOUGHT_SEED_V1'
  run_id='prev_refocus_seed_001'
  refocus_needed=$true
  repeated_task='FRONTIER_TO_BUILD_TASK_ROUTER_V1'
  repeated_topic='aimo.deep_thinking.recursive_thought_frame.memory_learning'
  new_thought_seed=[ordered]@{ seed_id='seed_test_001'; seed_type='NEW_THOUGHT_QUESTION'; question=$seedQuestion; lens='unexamined_assumption'; goal='Move from repeated topic to a new question.'; must_not_repeat_task='FRONTIER_TO_BUILD_TASK_ROUTER_V1'; must_not_repeat_topic='aimo.deep_thinking.recursive_thought_frame.memory_learning'; success_condition='Next cycle should use this seed as active question.' }
  boundary=[ordered]@{ thinking_only=$true; no_action_execution=$true; no_active_memory_write=$true }
})
$tokens=$null;$parseErrors=$null
[System.Management.Automation.Language.Parser]::ParseFile((Resolve-Path $runner),[ref]$tokens,[ref]$parseErrors)|Out-Null
foreach($e in $parseErrors){ Add-Err "runner_parse:$($e.Message)" }
$text=Get-Content $runner -Raw
foreach($needle in @('function Get-LatestRefocusToNewThoughtSeed','function New-NewThoughtSeedToActiveGoal','new_thought_seed_to_active_goal.json','new_thought_seed_to_active_goal=$newThoughtSeedToActiveGoal','REFOCUS_THOUGHT_SEED_ACTIVE_GOAL')){ if($text -notlike "*$needle*"){ Add-Err "runner_missing:$needle" } }
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
$proof=$null;$consume=$null;$manifest=$null
if($run){
  foreach($pair in @(@('proof','SANDBOX_EXPLORATION_PROOF.json'),@('consume','new_thought_seed_to_active_goal.json'),@('manifest','sandbox_proof_pack_manifest.json'))){
    $var=$pair[0]; $file=Join-Path $run.run_root_full $pair[1]
    if(Test-Path $file){ Set-Variable -Name $var -Value (Get-Content $file -Raw|ConvertFrom-Json) } else { Add-Err "missing_run_file:$($pair[1])" }
  }
}
if($consume){
  if($consume.status -ne 'PASS_NEW_THOUGHT_SEED_TO_ACTIVE_GOAL_V1'){ Add-Err "consume_status:$($consume.status)" }
  if($consume.seed_found -ne $true){ Add-Err 'seed_found_not_true' }
  if($consume.seed_consumed -ne $true){ Add-Err 'seed_consumed_not_true' }
  if($consume.active_goal.question -ne $seedQuestion){ Add-Err 'active_goal_question_mismatch' }
  if($consume.active_goal.lens -ne 'unexamined_assumption'){ Add-Err "active_goal_lens:$($consume.active_goal.lens)" }
  if($consume.boundary.thinking_only -ne $true){ Add-Err 'boundary_thinking_not_true' }
  if($consume.boundary.no_action_execution -ne $true){ Add-Err 'boundary_action_not_blocked' }
  if($consume.boundary.owner_question_preserved -ne $false){ Add-Err 'owner_question_preserved_should_be_false' }
}
if($proof){
  if(-not $proof.PSObject.Properties['new_thought_seed_to_active_goal']){ Add-Err 'proof_missing_new_seed_to_goal' }
  if($proof.internal_goal.goal -ne $seedQuestion){ Add-Err 'proof_internal_goal_not_seed_question' }
  if($proof.internal_goal.source -ne 'REFOCUS_THOUGHT_SEED_ACTIVE_GOAL'){ Add-Err "proof_internal_goal_source:$($proof.internal_goal.source)" }
  if($proof.internal_goal.refocus_seed_consumed -ne $true){ Add-Err 'proof_internal_goal_seed_not_consumed' }
  if(@($proof.decision_trace | Where-Object { $_.step -eq 'new_thought_seed_to_active_goal' }).Count -ne 1){ Add-Err 'decision_trace_missing_seed_to_goal' }
}
if($manifest){ if(@($manifest.required_files) -notcontains 'new_thought_seed_to_active_goal.json'){ Add-Err 'manifest_missing_seed_to_goal' } }
$activeAfter=TreeStats '.runtime/active_compact_semantic_memory_v1'
$queueAfter=TreeStats '.runtime/compact_memory_intake_v1/queue'
if($activeBefore.files -ne $activeAfter.files -or $activeBefore.bytes -ne $activeAfter.bytes){ Add-Err 'active_memory_changed' }
if($queueBefore.files -ne $queueAfter.files){ Add-Err "queue_changed_without_memory_learning:before=$($queueBefore.files):after=$($queueAfter.files)" }
if((Get-FileHash 'operations/autonomous_inner_motor/start_agent_life_v1.ps1' -Algorithm SHA256).Hash -ne $launcherHashBefore){ Add-Err 'launcher_hash_changed' }
if((Get-FileHash $runner -Algorithm SHA256).Hash -ne $runnerHashBefore){ Add-Err 'runner_hash_changed_during_validation' }
$procs=@(Get-CimInstance Win32_Process | Where-Object { $_.ProcessId -ne $PID -and $_.CommandLine -and $_.CommandLine -notmatch 'Get-CimInstance Win32_Process|validate_new_thought_seed_to_active_goal_v1.ps1' -and $_.CommandLine -match '\s-File\s+.*(start_agent_life_v1.ps1|run_autonomous_inner_motor.ps1|run_continuous_agent_runtime_v1_lab.ps1|school|invoke_body_self_inspection_circuit_v1.ps1)|codex exec|node_modules.*@openai/codex|node.*codex.js|continuous_agent_runtime_v1' })
if($procs.Count -ne 0){ Add-Err "process_count_not_zero:$($procs.Count)" }
$status=if($errors.Count -eq 0){'PASS_NEW_THOUGHT_SEED_TO_ACTIVE_GOAL_V1'}else{'FAIL_NEW_THOUGHT_SEED_TO_ACTIVE_GOAL_V1'}
$canonical=[ordered]@{ schema='new_thought_seed_to_active_goal_v1_validation'; status=$status; checked_at=(Get-Date).ToUniversalTime().ToString('o'); run=$run; seed_question=$seedQuestion; seed_found=if($consume){$consume.seed_found}else{$false}; seed_consumed=if($consume){$consume.seed_consumed}else{$false}; active_goal_source=if($proof){$proof.internal_goal.source}else{$null}; active_goal=if($proof){$proof.internal_goal.goal}else{$null}; queue_before=$queueBefore; queue_after=$queueAfter; active_memory_before=$activeBefore; active_memory_after=$activeAfter; process_count=$procs.Count; errors=@($errors); boundary=[ordered]@{runtime_launched_by_validator=$true; thinking_only=$true; action_execution_allowed=$false; memory_learning_enabled=$false; active_memory_mutated=$false; direct_active_memory_write=$false; no_new_store_created=$true; codex_launched=$false; web_launched=$false} }
WJson $proofPath $canonical
$accept=[ordered]@{ schema='new_thought_seed_to_active_goal_v1_acceptance'; status=if($status -eq 'PASS_NEW_THOUGHT_SEED_TO_ACTIVE_GOAL_V1'){'ACCEPTED_NEW_THOUGHT_SEED_TO_ACTIVE_GOAL_V1'}else{'REJECTED_NEW_THOUGHT_SEED_TO_ACTIVE_GOAL_V1'}; accepted_at=(Get-Date).ToUniversalTime().ToString('o'); proof=$proofPath; may_claim='Next cycle can consume latest refocus seed as active internal goal when no Owner question overrides it.'; may_not_claim=@('dynamic memory retrieval budget implemented','refocus seed creates rich novel reasoning by itself','action execution allowed','active compact memory updated'); boundary=$canonical.boundary }
WJson $acceptance $accept
Write-Host "STATUS=$status"
if($errors.Count -gt 0){ foreach($e in $errors){ Write-Host "ERROR=$e" }; exit 1 }
