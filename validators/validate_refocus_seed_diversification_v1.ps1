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
  if(-not(Test-Path $p)){ return [ordered]@{exists=$false;files=0;bytes=0} }
  $files=@(Get-ChildItem $p -Recurse -File -Force -ErrorAction SilentlyContinue)
  return [ordered]@{exists=$true;files=$files.Count;bytes=[int64](($files|Measure-Object Length -Sum).Sum)}
}
function Run-Cycle($outputRoot,$question){
  $before=@(Get-ChildItem $outputRoot -Directory -ErrorAction SilentlyContinue | Select-Object -ExpandProperty FullName)
  if([string]::IsNullOrWhiteSpace($question)){
    powershell -NoProfile -ExecutionPolicy Bypass -File operations/autonomous_inner_motor/run_autonomous_inner_motor.ps1 -Mode SandboxExploration -EnableDeepThinking -OutputRoot $outputRoot
  } else {
    powershell -NoProfile -ExecutionPolicy Bypass -File operations/autonomous_inner_motor/run_autonomous_inner_motor.ps1 -Mode SandboxExploration -EnableDeepThinking -OutputRoot $outputRoot -Question $question
  }
  $exit=$LASTEXITCODE
  $after=@(Get-ChildItem $outputRoot -Directory -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending)
  $new=$null
  foreach($d in $after){ if($before -notcontains $d.FullName){ $new=$d; break } }
  return [ordered]@{ exit_code=$exit; run_root=if($new){$new.FullName.Replace((Get-Location).Path+'\','')}else{$null}; run_root_full=if($new){$new.FullName}else{$null} }
}
$runner='operations/autonomous_inner_motor/run_autonomous_inner_motor.ps1'
$proofPath='tests/self_development/REFOCUS_SEED_DIVERSIFICATION_V1_PROOF.json'
$acceptance='operations/autonomous_inner_motor/reports/REFOCUS_SEED_DIVERSIFICATION_V1_ACCEPTANCE.json'
$stamp=(Get-Date).ToUniversalTime().ToString('yyyyMMdd_HHmmss')
$outputRoot=".runtime/refocus_seed_diversification_v1_validation/$stamp"
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
foreach($needle in @('function New-RefocusSeedDiversification','function New-ThoughtDepthLadder','refocus_seed_diversification.json','thought_depth_ladder.json','source_kind=$seedFile')){ if($text -notlike "*$needle*"){ Add-Err "runner_missing:$needle" } }
$activeBefore=TreeStats '.runtime/active_compact_semantic_memory_v1'
$queueBefore=TreeStats '.runtime/compact_memory_intake_v1/queue'
$launcherHashBefore=(Get-FileHash 'operations/autonomous_inner_motor/start_agent_life_v1.ps1' -Algorithm SHA256).Hash
$runnerHashBefore=(Get-FileHash $runner -Algorithm SHA256).Hash
$run1=$null;$run2=$null
if($errors.Count -eq 0){
  $run1=Run-Cycle $outputRoot 'Validate diversification: repeated seed must split into non-repeating branches.'
  if($run1.exit_code -ne 0){ Add-Err "run1_exit_code:$($run1.exit_code)" }
  Start-Sleep -Seconds 2
  $run2=Run-Cycle $outputRoot ''
  if($run2.exit_code -ne 0){ Add-Err "run2_exit_code:$($run2.exit_code)" }
}
$div1=$null;$ladder1=$null;$proof1=$null;$manifest1=$null;$consume2=$null;$proof2=$null
if($run1 -and $run1.run_root_full){
  foreach($pair in @(@('div1','refocus_seed_diversification.json'),@('ladder1','thought_depth_ladder.json'),@('proof1','SANDBOX_EXPLORATION_PROOF.json'),@('manifest1','sandbox_proof_pack_manifest.json'))){
    $file=Join-Path $run1.run_root_full $pair[1]
    if(Test-Path $file){ Set-Variable -Name $pair[0] -Value (Get-Content $file -Raw|ConvertFrom-Json) } else { Add-Err "run1_missing:$($pair[1])" }
  }
}
if($run2 -and $run2.run_root_full){
  foreach($pair in @(@('consume2','new_thought_seed_to_active_goal.json'),@('proof2','SANDBOX_EXPLORATION_PROOF.json'))){
    $file=Join-Path $run2.run_root_full $pair[1]
    if(Test-Path $file){ Set-Variable -Name $pair[0] -Value (Get-Content $file -Raw|ConvertFrom-Json) } else { Add-Err "run2_missing:$($pair[1])" }
  }
}
if($div1){
  if($div1.status -ne 'PASS_REFOCUS_SEED_DIVERSIFICATION_V1'){ Add-Err "div_status:$($div1.status)" }
  if($div1.diversification_needed -ne $true){ Add-Err 'div_needed_not_true' }
  if([int]$div1.branch_count -lt 5){ Add-Err "branch_count_lt_5:$($div1.branch_count)" }
  if($div1.source_lens -ne 'unexamined_assumption'){ Add-Err "source_lens:$($div1.source_lens)" }
  if($div1.selected_lens -eq $div1.source_lens){ Add-Err 'selected_lens_repeats_source_lens' }
  if([string]::IsNullOrWhiteSpace([string]$div1.selected_question)){ Add-Err 'selected_question_empty' }
  if($div1.selected_question -eq $div1.source_question){ Add-Err 'selected_question_repeats_source_question' }
  if(-not $div1.new_thought_seed){ Add-Err 'new_thought_seed_missing' }
  if($div1.boundary.no_external_access -ne $true){ Add-Err 'div_external_access_not_blocked' }
}
if($ladder1){
  if($ladder1.status -ne 'PASS_THOUGHT_DEPTH_LADDER_V1'){ Add-Err "ladder_status:$($ladder1.status)" }
  if([int]$ladder1.depth_level -lt 3){ Add-Err "depth_level_lt_3:$($ladder1.depth_level)" }
  if(@($ladder1.steps).Count -lt 3){ Add-Err 'ladder_steps_lt_3' }
  if($ladder1.boundary.no_external_access -ne $true){ Add-Err 'ladder_external_access_not_blocked' }
}
if($proof1){
  if(-not $proof1.PSObject.Properties['refocus_seed_diversification']){ Add-Err 'proof1_missing_diversification' }
  if(-not $proof1.PSObject.Properties['thought_depth_ladder']){ Add-Err 'proof1_missing_ladder' }
  if(@($proof1.decision_trace | Where-Object { $_.step -eq 'refocus_seed_diversification' }).Count -ne 1){ Add-Err 'trace_missing_diversification' }
  if(@($proof1.decision_trace | Where-Object { $_.step -eq 'thought_depth_ladder' }).Count -ne 1){ Add-Err 'trace_missing_ladder' }
}
if($manifest1){
  if(@($manifest1.required_files) -notcontains 'refocus_seed_diversification.json'){ Add-Err 'manifest_missing_diversification' }
  if(@($manifest1.required_files) -notcontains 'thought_depth_ladder.json'){ Add-Err 'manifest_missing_ladder' }
}
if($consume2){
  if($consume2.seed_consumed -ne $true){ Add-Err 'run2_seed_not_consumed' }
  if($consume2.source_kind -ne 'refocus_seed_diversification.json' -and $consume2.source_path -notlike '*refocus_seed_diversification.json'){ Add-Err "run2_not_consuming_diversified_seed:$($consume2.source_path)" }
  if($consume2.active_goal.question -ne $div1.selected_question){ Add-Err 'run2_active_goal_not_diversified_question' }
  if($consume2.active_goal.lens -ne $div1.selected_lens){ Add-Err 'run2_active_goal_not_diversified_lens' }
}
if($proof2){
  if($proof2.internal_goal.goal -ne $div1.selected_question){ Add-Err 'proof2_internal_goal_not_diversified' }
  if($proof2.internal_goal.refocus_lens -ne $div1.selected_lens){ Add-Err 'proof2_internal_goal_lens_not_diversified' }
}
$activeAfter=TreeStats '.runtime/active_compact_semantic_memory_v1'
$queueAfter=TreeStats '.runtime/compact_memory_intake_v1/queue'
if($activeBefore.files -ne $activeAfter.files -or $activeBefore.bytes -ne $activeAfter.bytes){ Add-Err 'active_memory_changed' }
if($queueBefore.files -ne $queueAfter.files){ Add-Err "queue_changed_without_memory_learning:before=$($queueBefore.files):after=$($queueAfter.files)" }
if((Get-FileHash 'operations/autonomous_inner_motor/start_agent_life_v1.ps1' -Algorithm SHA256).Hash -ne $launcherHashBefore){ Add-Err 'launcher_hash_changed' }
if((Get-FileHash $runner -Algorithm SHA256).Hash -ne $runnerHashBefore){ Add-Err 'runner_hash_changed_during_validation' }
$procs=@(Get-CimInstance Win32_Process | Where-Object { $_.ProcessId -ne $PID -and $_.CommandLine -and $_.CommandLine -notmatch 'Get-CimInstance Win32_Process|validate_refocus_seed_diversification_v1.ps1' -and $_.CommandLine -match '\s-File\s+.*(start_agent_life_v1.ps1|run_autonomous_inner_motor.ps1|run_continuous_agent_runtime_v1_lab.ps1|school|invoke_body_self_inspection_circuit_v1.ps1)|codex exec|node_modules.*@openai/codex|node.*codex.js|continuous_agent_runtime_v1' })
if($procs.Count -ne 0){ Add-Err "process_count_not_zero:$($procs.Count)" }
$status=if($errors.Count -eq 0){'PASS_REFOCUS_SEED_DIVERSIFICATION_V1'}else{'FAIL_REFOCUS_SEED_DIVERSIFICATION_V1'}
$canonical=[ordered]@{ schema='refocus_seed_diversification_v1_validation'; status=$status; checked_at=(Get-Date).ToUniversalTime().ToString('o'); run1=$run1; run2=$run2; source_lens=if($div1){$div1.source_lens}else{$null}; selected_lens=if($div1){$div1.selected_lens}else{$null}; selected_question=if($div1){$div1.selected_question}else{$null}; branch_count=if($div1){$div1.branch_count}else{$null}; depth_level=if($ladder1){$ladder1.depth_level}else{$null}; run2_seed_consumed=if($consume2){$consume2.seed_consumed}else{$false}; run2_source_path=if($consume2){$consume2.source_path}else{$null}; active_memory_before=$activeBefore; active_memory_after=$activeAfter; queue_before=$queueBefore; queue_after=$queueAfter; process_count=$procs.Count; errors=@($errors); boundary=[ordered]@{runtime_launched_by_validator=$true; cycles=2; thinking_only=$true; memory_learning_enabled=$false; action_execution_allowed=$false; active_memory_mutated=$false; direct_active_memory_write=$false; no_external_access=$true; no_new_store_created=$true; codex_launched=$false; web_launched=$false} }
WJson $proofPath $canonical
$accept=[ordered]@{ schema='refocus_seed_diversification_v1_acceptance'; status=if($status -eq 'PASS_REFOCUS_SEED_DIVERSIFICATION_V1'){'ACCEPTED_REFOCUS_SEED_DIVERSIFICATION_V1'}else{'REJECTED_REFOCUS_SEED_DIVERSIFICATION_V1'}; accepted_at=(Get-Date).ToUniversalTime().ToString('o'); proof=$proofPath; may_claim='Agent can split a repeated refocus seed into multiple branches, select a non-repeating lens, and the next cycle can consume the diversified seed as active goal.'; may_not_claim=@('external access enabled','full autonomous research depth solved','actions allowed','active compact memory updated'); boundary=$canonical.boundary }
WJson $acceptance $accept
Write-Host "STATUS=$status"
if($errors.Count -gt 0){ foreach($e in $errors){ Write-Host "ERROR=$e" }; exit 1 }
