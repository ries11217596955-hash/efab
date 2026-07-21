$ErrorActionPreference='Stop'
$errors=@()
function Add-Err([string]$e){ $script:errors += $e }
function WJson($path,$obj){ $dir=Split-Path $path -Parent; if($dir){New-Item -ItemType Directory -Force -Path $dir|Out-Null}; $json=($obj|ConvertTo-Json -Depth 100) -replace "`r`n","`n"; [System.IO.File]::WriteAllText((Join-Path (Get-Location).Path $path),$json.TrimEnd()+"`n",(New-Object System.Text.UTF8Encoding($false))) }
$report='operations/autonomous_inner_motor/reports/LIVE_OBSERVATION_5MIN_THOUGHT_AUDIT_V3_AFTER_SEED_DIVERSIFICATION.json'
if(-not(Test-Path $report)){ Add-Err "missing_report:$report" }
$r=$null
if(Test-Path $report){ $r=Get-Content $report -Raw|ConvertFrom-Json }
if($r){
  if($r.status -ne 'PASS_LIVE_OBSERVATION_5MIN_THOUGHT_AUDIT_V3_AFTER_SEED_DIVERSIFICATION'){ Add-Err "status:$($r.status)" }
  if([int]$r.observations.cycle_count -ne 8){ Add-Err "cycle_count:$($r.observations.cycle_count)" }
  if(@($r.observations.internal_goal_sources | Where-Object { $_.name -eq 'REFOCUS_THOUGHT_SEED_ACTIVE_GOAL' -and $_.count -eq 8 }).Count -ne 1){ Add-Err 'active_goal_source_8_missing' }
  if(@($r.observations.active_goal_lenses | Where-Object { $_.name -eq 'counterexample' -and $_.count -eq 7 }).Count -ne 1){ Add-Err 'counterexample_7_missing' }
  if(@($r.observations.selected_lenses | Where-Object { $_.name -eq 'counterexample' -and $_.count -eq 8 }).Count -ne 1){ Add-Err 'selected_counterexample_8_missing' }
  if(@($r.observations.budgets | Where-Object { $_.name -eq '5' -and $_.count -eq 8 }).Count -ne 1){ Add-Err 'budget_5_8_missing' }
  if(@($r.observations.depth_levels | Where-Object { $_.name -eq '3' -and $_.count -eq 8 }).Count -ne 1){ Add-Err 'depth_3_8_missing' }
  if([int]$r.observations.unique_ref_sets -ne 1){ Add-Err "unique_ref_sets:$($r.observations.unique_ref_sets)" }
  if($r.observations.safety.any_executed -ne $false){ Add-Err 'executed_true' }
  if($r.observations.safety.any_git -ne $false){ Add-Err 'git_true' }
  if($r.observations.safety.any_codex -ne $false){ Add-Err 'codex_true' }
  if($r.observations.safety.any_web -ne $false){ Add-Err 'web_true' }
  if([double]$r.bloat.new_run_total_mb -lt 7){ Add-Err "new_run_total_too_low:$($r.bloat.new_run_total_mb)" }
  if([double]$r.bloat.runtime_delta_mb.active_memory_bytes_delta -ne 0){ Add-Err 'active_memory_delta_not_zero' }
  if($r.recommended_next.technical -notlike '*PROOF_PACK_DIET_V1*'){ Add-Err 'proof_pack_diet_missing' }
}
$procs=@(Get-CimInstance Win32_Process | Where-Object { $_.ProcessId -ne $PID -and $_.CommandLine -and $_.CommandLine -notmatch 'Get-CimInstance Win32_Process|validate_live_observation_5min_thought_audit_v3_after_seed_diversification.ps1' -and $_.CommandLine -match '\s-File\s+.*(start_agent_life_v1.ps1|run_autonomous_inner_motor.ps1|run_continuous_agent_runtime_v1_lab.ps1|school|invoke_body_self_inspection_circuit_v1.ps1)|codex exec|node_modules.*@openai/codex|node.*codex.js|continuous_agent_runtime_v1|validate_|live_observation' })
if($procs.Count -ne 0){ Add-Err "process_count_not_zero:$($procs.Count)" }
$status=if($errors.Count -eq 0){'PASS_LIVE_OBSERVATION_5MIN_THOUGHT_AUDIT_V3_AFTER_SEED_DIVERSIFICATION'}else{'FAIL_LIVE_OBSERVATION_5MIN_THOUGHT_AUDIT_V3_AFTER_SEED_DIVERSIFICATION'}
$proof=[ordered]@{schema='live_observation_5min_thought_audit_v3_validation';status=$status;checked_at=(Get-Date).ToUniversalTime().ToString('o');report=$report;cycle_count=if($r){$r.observations.cycle_count}else{$null};dominant_lens='counterexample';unique_ref_sets=if($r){$r.observations.unique_ref_sets}else{$null};new_run_total_mb=if($r){$r.bloat.new_run_total_mb}else{$null};projected_per_day_mb=if($r){$r.bloat.projected_per_day_mb}else{$null};process_count=$procs.Count;errors=@($errors);boundary=[ordered]@{audit_only=$true;runtime_launched_by_validator=$false;active_memory_mutated_by_validator=$false;repo_mutation_by_validator=$false}}
WJson 'tests/self_development/LIVE_OBSERVATION_5MIN_THOUGHT_AUDIT_V3_AFTER_SEED_DIVERSIFICATION_PROOF.json' $proof
Write-Host "STATUS=$status"
if($errors.Count -gt 0){ foreach($e in $errors){ Write-Host "ERROR=$e" }; exit 1 }
