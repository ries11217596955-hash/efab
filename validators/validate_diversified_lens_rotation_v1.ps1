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
$runner='operations/autonomous_inner_motor/run_autonomous_inner_motor.ps1'
$proofPath='tests/self_development/DIVERSIFIED_LENS_ROTATION_V1_PROOF.json'
$acceptance='operations/autonomous_inner_motor/reports/DIVERSIFIED_LENS_ROTATION_V1_ACCEPTANCE.json'
$stamp=(Get-Date).ToUniversalTime().ToString('yyyyMMdd_HHmmss')
$outputRoot=".runtime/diversified_lens_rotation_v1_validation/$stamp"
New-Item -ItemType Directory -Force -Path $outputRoot | Out-Null
for($i=1;$i -le 3;$i++){
  $d=Join-Path $outputRoot ("prev_repeat_{0}" -f $i)
  New-Item -ItemType Directory -Force -Path $d | Out-Null
  WJson (Join-Path $d 'short_term_mind_state.json') ([ordered]@{ schema='short_term_mind_state_v1'; status='PASS_SHORT_TERM_MIND_STATE_V1'; run_id="prev_repeat_$i"; completed_candidate=[ordered]@{ topic='aimo.deep_thinking.recursive_thought_frame.memory_learning'; route_status='RELEASED_TO_EXISTING_MULTI_SOURCE_WAREHOUSE' }; continuity=[ordered]@{ previous_state_found=($i -gt 1) } })
  WJson (Join-Path $d 'short_term_state_to_next_task_router.json') ([ordered]@{ schema='short_term_state_to_next_task_router_v1'; status='PASS_SHORT_TERM_STATE_TO_NEXT_TASK_ROUTER_V1'; run_id="prev_repeat_$i"; selected_next_task='FRONTIER_TO_BUILD_TASK_ROUTER_V1' })
}
$prevDiv=Join-Path $outputRoot 'prev_diversified_counterexample'
New-Item -ItemType Directory -Force -Path $prevDiv | Out-Null
WJson (Join-Path $prevDiv 'refocus_seed_diversification.json') ([ordered]@{
  schema='refocus_seed_diversification_v1'
  status='PASS_REFOCUS_SEED_DIVERSIFICATION_V1'
  run_id='prev_diversified_counterexample'
  diversification_needed=$true
  source_lens='unexamined_assumption'
  selected_lens='counterexample'
  selected_question='What counterexample would break the repeated assumption, and what would it reveal about the next thought?'
  branch_count=5
  new_thought_seed=[ordered]@{ seed_type='DIVERSIFIED_THOUGHT_QUESTION'; question='What counterexample would break the repeated assumption, and what would it reveal about the next thought?'; lens='counterexample' }
})
$tokens=$null;$parseErrors=$null
[System.Management.Automation.Language.Parser]::ParseFile((Resolve-Path $runner),[ref]$tokens,[ref]$parseErrors)|Out-Null
foreach($e in $parseErrors){ Add-Err "runner_parse:$($e.Message)" }
$text=Get-Content $runner -Raw
foreach($needle in @('function Get-RecentDiversifiedLensRotation','diversified_lens_rotation.json','avoid_lenses','rotation_applied','must_not_repeat_recent_lenses')){ if($text -notlike "*$needle*"){ Add-Err "runner_missing:$needle" } }
$activeBefore=TreeStats '.runtime/active_compact_semantic_memory_v1'
$queueBefore=TreeStats '.runtime/compact_memory_intake_v1/queue'
$launcherHashBefore=(Get-FileHash 'operations/autonomous_inner_motor/start_agent_life_v1.ps1' -Algorithm SHA256).Hash
$runnerHashBefore=(Get-FileHash $runner -Algorithm SHA256).Hash
$run=$null
if($errors.Count -eq 0){
  $before=@(Get-ChildItem $outputRoot -Directory | Select-Object -ExpandProperty FullName)
  powershell -NoProfile -ExecutionPolicy Bypass -File $runner -Mode SandboxExploration -EnableDeepThinking -OutputRoot $outputRoot -Question 'Validate lens rotation: avoid repeating counterexample lens.'
  $exit=$LASTEXITCODE
  if($exit -ne 0){ Add-Err "runner_exit_code:$exit" }
  $after=@(Get-ChildItem $outputRoot -Directory | Sort-Object LastWriteTime -Descending)
  $new=$null
  foreach($d in $after){ if($before -notcontains $d.FullName){ $new=$d; break } }
  if($new){ $run=[ordered]@{run_root=$new.FullName.Replace((Get-Location).Path+'\',''); run_root_full=$new.FullName} } else { Add-Err 'new_run_root_missing' }
}
$rotation=$null;$div=$null;$ladder=$null;$proof=$null;$manifest=$null
if($run -and $run.run_root_full){
  foreach($pair in @(@('rotation','diversified_lens_rotation.json'),@('div','refocus_seed_diversification.json'),@('ladder','thought_depth_ladder.json'),@('proof','SANDBOX_EXPLORATION_PROOF.json'),@('manifest','sandbox_proof_pack_manifest.json'))){
    $file=Join-Path $run.run_root_full $pair[1]
    if(Test-Path $file){ Set-Variable -Name $pair[0] -Value (Get-Content $file -Raw|ConvertFrom-Json) } else { Add-Err "missing_run_file:$($pair[1])" }
  }
}
if($rotation){
  if($rotation.status -ne 'PASS_DIVERSIFIED_LENS_ROTATION_V1'){ Add-Err "rotation_status:$($rotation.status)" }
  if($rotation.rotate_needed -ne $true){ Add-Err 'rotate_needed_not_true' }
  if(@($rotation.avoid_lenses) -notcontains 'counterexample'){ Add-Err 'counterexample_not_in_avoid_lenses' }
  if([int]$rotation.recent_count -lt 1){ Add-Err "recent_count_lt_1:$($rotation.recent_count)" }
  if($rotation.boundary.no_external_access -ne $true){ Add-Err 'rotation_external_not_blocked' }
}
if($div){
  if($div.status -ne 'PASS_REFOCUS_SEED_DIVERSIFICATION_V1'){ Add-Err "div_status:$($div.status)" }
  if($div.rotation_applied -ne $true){ Add-Err 'rotation_applied_not_true' }
  if(@($div.avoid_lenses) -notcontains 'counterexample'){ Add-Err 'div_avoid_missing_counterexample' }
  if(@($div.avoid_lenses) -notcontains 'unexamined_assumption'){ Add-Err 'div_avoid_missing_source_lens' }
  if($div.selected_lens -eq 'counterexample'){ Add-Err 'selected_repeated_counterexample' }
  if($div.selected_lens -eq 'unexamined_assumption'){ Add-Err 'selected_source_lens' }
  if($div.selected_lens -ne 'boundary_condition'){ Add-Err "selected_lens_not_boundary_condition:$($div.selected_lens)" }
  if($div.new_thought_seed.must_not_repeat_recent_lenses -notcontains 'counterexample'){ Add-Err 'seed_missing_recent_avoid' }
  if($div.boundary.rotation_aware -ne $true){ Add-Err 'div_boundary_rotation_not_true' }
}
if($ladder){
  if($ladder.status -ne 'PASS_THOUGHT_DEPTH_LADDER_V1'){ Add-Err "ladder_status:$($ladder.status)" }
  if([int]$ladder.depth_level -lt 3){ Add-Err "depth_lt_3:$($ladder.depth_level)" }
}
if($proof){
  if(-not $proof.PSObject.Properties['diversified_lens_rotation']){ Add-Err 'proof_missing_lens_rotation' }
  if(-not $proof.PSObject.Properties['refocus_seed_diversification']){ Add-Err 'proof_missing_diversification' }
  if(@($proof.decision_trace | Where-Object { $_.step -eq 'diversified_lens_rotation' }).Count -ne 1){ Add-Err 'trace_missing_rotation' }
}
if($manifest){ if(@($manifest.required_files) -notcontains 'diversified_lens_rotation.json'){ Add-Err 'manifest_missing_rotation' } }
$activeAfter=TreeStats '.runtime/active_compact_semantic_memory_v1'
$queueAfter=TreeStats '.runtime/compact_memory_intake_v1/queue'
if($activeBefore.files -ne $activeAfter.files -or $activeBefore.bytes -ne $activeAfter.bytes){ Add-Err 'active_memory_changed' }
if($queueBefore.files -ne $queueAfter.files){ Add-Err "queue_changed_without_memory_learning:before=$($queueBefore.files):after=$($queueAfter.files)" }
if((Get-FileHash 'operations/autonomous_inner_motor/start_agent_life_v1.ps1' -Algorithm SHA256).Hash -ne $launcherHashBefore){ Add-Err 'launcher_hash_changed' }
if((Get-FileHash $runner -Algorithm SHA256).Hash -ne $runnerHashBefore){ Add-Err 'runner_hash_changed_during_validation' }
$procs=@(Get-CimInstance Win32_Process | Where-Object { $_.ProcessId -ne $PID -and $_.CommandLine -and $_.CommandLine -notmatch 'Get-CimInstance Win32_Process|validate_diversified_lens_rotation_v1.ps1' -and $_.CommandLine -match '\s-File\s+.*(start_agent_life_v1.ps1|run_autonomous_inner_motor.ps1|run_continuous_agent_runtime_v1_lab.ps1|school|invoke_body_self_inspection_circuit_v1.ps1)|codex exec|node_modules.*@openai/codex|node.*codex.js|continuous_agent_runtime_v1' })
if($procs.Count -ne 0){ Add-Err "process_count_not_zero:$($procs.Count)" }
$status=if($errors.Count -eq 0){'PASS_DIVERSIFIED_LENS_ROTATION_V1'}else{'FAIL_DIVERSIFIED_LENS_ROTATION_V1'}
$canonical=[ordered]@{ schema='diversified_lens_rotation_v1_validation'; status=$status; checked_at=(Get-Date).ToUniversalTime().ToString('o'); run=$run; avoided_lenses=if($div){@($div.avoid_lenses)}else{@()}; previous_lens='counterexample'; selected_lens=if($div){$div.selected_lens}else{$null}; rotation_applied=if($div){$div.rotation_applied}else{$false}; branch_count=if($div){$div.branch_count}else{$null}; depth_level=if($ladder){$ladder.depth_level}else{$null}; active_memory_before=$activeBefore; active_memory_after=$activeAfter; queue_before=$queueBefore; queue_after=$queueAfter; process_count=$procs.Count; errors=@($errors); boundary=[ordered]@{runtime_launched_by_validator=$true; cycles=1; thinking_only=$true; memory_learning_enabled=$false; action_execution_allowed=$false; active_memory_mutated=$false; direct_active_memory_write=$false; no_external_access=$true; no_new_store_created=$true; codex_launched=$false; web_launched=$false} }
WJson $proofPath $canonical
$accept=[ordered]@{ schema='diversified_lens_rotation_v1_acceptance'; status=if($status -eq 'PASS_DIVERSIFIED_LENS_ROTATION_V1'){'ACCEPTED_DIVERSIFIED_LENS_ROTATION_V1'}else{'REJECTED_DIVERSIFIED_LENS_ROTATION_V1'}; accepted_at=(Get-Date).ToUniversalTime().ToString('o'); proof=$proofPath; may_claim='Agent can avoid the latest repeated diversified lens and select a different lens branch.'; may_not_claim=@('long live run proves lens keeps rotating over hours','external access enabled','actions allowed','active compact memory updated'); boundary=$canonical.boundary }
WJson $acceptance $accept
Write-Host "STATUS=$status"
if($errors.Count -gt 0){ foreach($e in $errors){ Write-Host "ERROR=$e" }; exit 1 }
