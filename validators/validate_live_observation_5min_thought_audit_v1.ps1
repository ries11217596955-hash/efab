$ErrorActionPreference='Stop'
$errors=@()
function Add-Err([string]$e){ $script:errors += $e }
function WJson($path,$obj){
  $dir=Split-Path $path -Parent
  if($dir){ New-Item -ItemType Directory -Force -Path $dir | Out-Null }
  $json=($obj|ConvertTo-Json -Depth 100) -replace "`r`n","`n"
  [System.IO.File]::WriteAllText((Join-Path (Get-Location).Path $path),$json.TrimEnd()+"`n",(New-Object System.Text.UTF8Encoding($false)))
}
$report='operations/autonomous_inner_motor/reports/LIVE_OBSERVATION_5MIN_THOUGHT_AUDIT_V1.json'
$notebook='AGENT_BUILDER_SELF_NOTEBOOK.md'
if(-not(Test-Path $report)){ Add-Err "missing:$report" }
if(-not(Test-Path $notebook)){ Add-Err "missing:$notebook" }
$r=$null
if(Test-Path $report){ $r=Get-Content $report -Raw|ConvertFrom-Json }
if($r){
  if($r.status -ne 'PASS_LIVE_OBSERVATION_5MIN_THOUGHT_AUDIT_V1'){ Add-Err "status_mismatch:$($r.status)" }
  if([int]$r.observed_life.cycle_count -ne 8){ Add-Err "cycle_count_not_8:$($r.observed_life.cycle_count)" }
  if(@($r.observed_life.cycles).Count -ne 8){ Add-Err "cycles_array_not_8:$(@($r.observed_life.cycles).Count)" }
  if($r.observed_life.repeated_candidate_topic -ne 'aimo.deep_thinking.recursive_thought_frame.memory_learning'){ Add-Err 'repeated_candidate_topic_mismatch' }
  $frontierCount=@($r.observed_life.cycles | Where-Object { $_.selected_next_task -eq 'FRONTIER_TO_BUILD_TASK_ROUTER_V1' }).Count
  if($frontierCount -ne 7){ Add-Err "frontier_count_not_7:$frontierCount" }
  $continuityCount=@($r.observed_life.cycles | Where-Object { $_.previous_state_found -eq $true }).Count
  if($continuityCount -ne 7){ Add-Err "continuity_count_not_7:$continuityCount" }
  foreach($c in @($r.observed_life.cycles)){
    if($c.candidate_route -ne 'RELEASED_TO_EXISTING_MULTI_SOURCE_WAREHOUSE'){ Add-Err "candidate_route_bad:$($c.cycle):$($c.candidate_route)" }
    if($c.gate_decision -ne 'BLOCKED_CONTRACT_EXECUTION_NOT_AUTHORIZED'){ Add-Err "gate_bad:$($c.cycle):$($c.gate_decision)" }
    if($c.executor_status -ne 'NOT_EXECUTED_GATE_BLOCKED'){ Add-Err "executor_bad:$($c.cycle):$($c.executor_status)" }
    if([int]$c.executed_files_count -ne 0){ Add-Err "executed_files_nonzero:$($c.cycle)" }
    if($c.validator_ran -ne $false){ Add-Err "validator_ran_true:$($c.cycle)" }
  }
  if($r.safety_result.process_count_after -ne 0){ Add-Err 'process_count_after_not_zero' }
  if($r.safety_result.git_mutated_any -ne $false){ Add-Err 'git_mutated_any_not_false' }
  if($r.safety_result.codex_launched_any -ne $false){ Add-Err 'codex_any_not_false' }
  if($r.safety_result.web_research_any -ne $false){ Add-Err 'web_any_not_false' }
  if($r.process_hang_analysis.agent_process_hung -ne $false){ Add-Err 'agent_process_hung_not_false' }
  if($r.bridge_outage_analysis.observed_errors -notcontains 'ERR_NGROK_3200 endpoint offline'){ Add-Err 'bridge_3200_missing' }
  if($r.recommended_next.technical -notlike '*REPEAT_TO_REFOCUS_ROUTER_V1*'){ Add-Err 'next_repeat_router_missing' }
}
$nb=if(Test-Path $notebook){Get-Content $notebook -Raw}else{''}
foreach($needle in @('LIVE_OBSERVATION_5MIN_THOUGHT_AUDIT_V1','8 cycles','FRONTIER_TO_BUILD_TASK_ROUTER_V1','REPEAT_TO_REFOCUS_ROUTER_V1','ERR_NGROK_3200')){
  if($nb -notlike "*$needle*"){ Add-Err "notebook_missing:$needle" }
}
$procs=@(Get-CimInstance Win32_Process | Where-Object { $_.ProcessId -ne $PID -and $_.CommandLine -and $_.CommandLine -notmatch 'Get-CimInstance Win32_Process|validate_live_observation_5min_thought_audit_v1.ps1' -and $_.CommandLine -match '\s-File\s+.*(start_agent_life_v1.ps1|run_autonomous_inner_motor.ps1|run_continuous_agent_runtime_v1_lab.ps1|school|invoke_body_self_inspection_circuit_v1.ps1)|codex exec|node_modules.*@openai/codex|node.*codex.js|continuous_agent_runtime_v1|live_observation|validate_' })
if($procs.Count -ne 0){ Add-Err "process_count_not_zero:$($procs.Count)" }
$status=if($errors.Count -eq 0){'PASS_LIVE_OBSERVATION_5MIN_THOUGHT_AUDIT_V1'}else{'FAIL_LIVE_OBSERVATION_5MIN_THOUGHT_AUDIT_V1'}
$proof=[ordered]@{
  schema='live_observation_5min_thought_audit_v1_validation'
  status=$status
  checked_at=(Get-Date).ToUniversalTime().ToString('o')
  report=$report
  cycle_count=if($r){$r.observed_life.cycle_count}else{$null}
  frontier_repeat_count=if($r){@($r.observed_life.cycles | Where-Object { $_.selected_next_task -eq 'FRONTIER_TO_BUILD_TASK_ROUTER_V1' }).Count}else{$null}
  process_count=$procs.Count
  errors=@($errors)
  boundary=[ordered]@{audit_only=$true; runtime_launched_by_validator=$false; active_memory_mutated_by_validator=$false; repo_mutation_by_validator=$false}
}
WJson 'tests/self_development/LIVE_OBSERVATION_5MIN_THOUGHT_AUDIT_V1_PROOF.json' $proof
Write-Host "STATUS=$status"
if($errors.Count -gt 0){ foreach($e in $errors){ Write-Host "ERROR=$e" }; exit 1 }
