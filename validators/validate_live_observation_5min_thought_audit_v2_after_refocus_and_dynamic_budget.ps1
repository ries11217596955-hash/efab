$ErrorActionPreference='Stop'
$errors=@()
function Add-Err([string]$e){ $script:errors += $e }
function WJson($path,$obj){ $dir=Split-Path $path -Parent; if($dir){New-Item -ItemType Directory -Force -Path $dir|Out-Null}; $json=($obj|ConvertTo-Json -Depth 100) -replace "`r`n","`n"; [System.IO.File]::WriteAllText((Join-Path (Get-Location).Path $path),$json.TrimEnd()+"`n",(New-Object System.Text.UTF8Encoding($false))) }
$report='operations/autonomous_inner_motor/reports/LIVE_OBSERVATION_5MIN_THOUGHT_AUDIT_V2_AFTER_REFOCUS_AND_DYNAMIC_BUDGET.json'
if(-not(Test-Path $report)){ Add-Err "missing_report:$report" }
$r=$null
if(Test-Path $report){ $r=Get-Content $report -Raw|ConvertFrom-Json }
if($r){
  if($r.status -ne 'PASS_LIVE_OBSERVATION_5MIN_THOUGHT_AUDIT_V2_AFTER_REFOCUS_AND_DYNAMIC_BUDGET'){ Add-Err "status:$($r.status)" }
  if([int]$r.observations.cycle_count -ne 8){ Add-Err "cycle_count:$($r.observations.cycle_count)" }
  if(@($r.observations.budgets | Where-Object { $_.budget -eq '5' -and $_.count -eq 7 }).Count -ne 1){ Add-Err 'budget_5_count_7_missing' }
  if(@($r.observations.budgets | Where-Object { $_.budget -eq '4' -and $_.count -eq 1 }).Count -ne 1){ Add-Err 'budget_4_count_1_missing' }
  if(@($r.observations.next_tasks | Where-Object { $_.next -eq 'REPEAT_TO_REFOCUS_ROUTER_V1' -and $_.count -eq 8 }).Count -ne 1){ Add-Err 'next_repeat_refocus_8_missing' }
  if([int]$r.observations.ref_set_count -ne 2){ Add-Err "ref_set_count:$($r.observations.ref_set_count)" }
  if([int]$r.observations.repeat_count -ne 8){ Add-Err "repeat_count:$($r.observations.repeat_count)" }
  if($r.observations.safety.any_executed -ne $false){ Add-Err 'executed_true' }
  if($r.observations.safety.any_git -ne $false){ Add-Err 'git_true' }
  if($r.observations.safety.any_codex -ne $false){ Add-Err 'codex_true' }
  if($r.observations.safety.any_web -ne $false){ Add-Err 'web_true' }
  if($r.external_access_decision.decision -ne 'NOT_YET'){ Add-Err "external_decision:$($r.external_access_decision.decision)" }
  if($r.recommended_next.technical -notlike '*REFOCUS_SEED_DIVERSIFICATION_V1*'){ Add-Err 'next_seed_diversification_missing' }
}
$procs=@(Get-CimInstance Win32_Process | Where-Object { $_.ProcessId -ne $PID -and $_.CommandLine -and $_.CommandLine -notmatch 'Get-CimInstance Win32_Process|validate_live_observation_5min_thought_audit_v2_after_refocus_and_dynamic_budget.ps1' -and $_.CommandLine -match '\s-File\s+.*(start_agent_life_v1.ps1|run_autonomous_inner_motor.ps1|run_continuous_agent_runtime_v1_lab.ps1|school|invoke_body_self_inspection_circuit_v1.ps1)|codex exec|node_modules.*@openai/codex|node.*codex.js|continuous_agent_runtime_v1|validate_|live_observation' })
if($procs.Count -ne 0){ Add-Err "process_count_not_zero:$($procs.Count)" }
$status=if($errors.Count -eq 0){'PASS_LIVE_OBSERVATION_5MIN_THOUGHT_AUDIT_V2_AFTER_REFOCUS_AND_DYNAMIC_BUDGET'}else{'FAIL_LIVE_OBSERVATION_5MIN_THOUGHT_AUDIT_V2_AFTER_REFOCUS_AND_DYNAMIC_BUDGET'}
$proof=[ordered]@{schema='live_observation_5min_thought_audit_v2_validation';status=$status;checked_at=(Get-Date).ToUniversalTime().ToString('o');report=$report;cycle_count=if($r){$r.observations.cycle_count}else{$null};unique_goal_count=if($r){$r.observations.unique_goal_count}else{$null};ref_set_count=if($r){$r.observations.ref_set_count}else{$null};repeat_count=if($r){$r.observations.repeat_count}else{$null};external_access_decision=if($r){$r.external_access_decision.decision}else{$null};process_count=$procs.Count;errors=@($errors);boundary=[ordered]@{audit_only=$true;runtime_launched_by_validator=$false;active_memory_mutated_by_validator=$false;repo_mutation_by_validator=$false}}
WJson 'tests/self_development/LIVE_OBSERVATION_5MIN_THOUGHT_AUDIT_V2_AFTER_REFOCUS_AND_DYNAMIC_BUDGET_PROOF.json' $proof
Write-Host "STATUS=$status"
if($errors.Count -gt 0){ foreach($e in $errors){ Write-Host "ERROR=$e" }; exit 1 }
