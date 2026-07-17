$ErrorActionPreference='Stop'
$errors=@()
function Add-Err([string]$e){ $script:errors += $e }
function WJson($path,$obj){ $dir=Split-Path $path -Parent; if($dir){New-Item -ItemType Directory -Force -Path $dir|Out-Null}; $json=($obj|ConvertTo-Json -Depth 100) -replace "`r`n","`n"; [System.IO.File]::WriteAllText((Join-Path (Get-Location).Path $path),$json.TrimEnd()+"`n",(New-Object System.Text.UTF8Encoding($false))) }
$plan='AGENT_BUILDER_RAM_LIFE_TRANSITION_MASTER_PLAN_V1.md'
$reportPath='operations/autonomous_inner_motor/reports/RAM_LIFE_AUDIT_F_CONTINUOUS_RUNTIME_LAB_DESIGN_V1.json'
foreach($p in @($plan,$reportPath)){ if(-not(Test-Path $p)){ Add-Err "missing:$p" } }
$planText=if(Test-Path $plan){Get-Content $plan -Raw}else{''}
foreach($needle in @('AUDIT_F_CONTINUOUS_RUNTIME_LAB_DESIGN_V1 detailed design','CONTINUOUS_AGENT_RUNTIME_V1_LAB','same process + RAM state persistence + safety boundary','Cycle must not call canonical runner in first lab','per-cycle JSON bridge for RAM state','CODEX_TASK_CONTINUOUS_AGENT_RUNTIME_V1_LAB_SLICE_A')){ if($planText -notlike "*$needle*"){ Add-Err "plan_missing:$needle" } }
$r=$null
if(Test-Path $reportPath){ $r=Get-Content $reportPath -Raw | ConvertFrom-Json }
if($r){
  if($r.status -ne 'PASS_RAM_LIFE_AUDIT_F_CONTINUOUS_RUNTIME_LAB_DESIGN_V1'){ Add-Err "status_mismatch:$($r.status)" }
  if($r.lab_id -ne 'CONTINUOUS_AGENT_RUNTIME_V1_LAB'){ Add-Err 'lab_id_mismatch' }
  if($r.lab_principle -ne 'same_process_ram_state_persistence_under_safety_boundary'){ Add-Err 'lab_principle_mismatch' }
  foreach($x in @('single PowerShell process','2-5 minute duration cap','SandboxExploration only','QueueOnly only','minimal supervised life context','RAM state object','cycle loop inside same process','heartbeat','runtime lock','stop signal support','bounded checkpoints','compact final proof')){ if(@($r.allowed) -notcontains $x){ Add-Err "allowed_missing:$x" } }
  foreach($x in @('replace canonical launcher','run unattended','mutate repo','write active memory directly','launch Codex','use web','run git mutation','repair body','cleanup runtime','load full compact memory','keep raw cycle transcript','create per-cycle JSON bridge for RAM state')){ if(@($r.forbidden) -notcontains $x){ Add-Err "forbidden_missing:$x" } }
  foreach($f in @('runtime_id','mode','repo_root','repo_head','active_memory_root_exists','compact_memory_queue_exists','allowed_actions','memory_mode','safety_mode','current_goal','forbidden')){ if(@($r.minimal_supervised_life_context_fields) -notcontains $f){ Add-Err "minimal_context_missing:$f" } }
  foreach($f in @('runtime_id','pid','started_at','cycle_count','ram_counter','recent_cycles','current_goal','last_checkpoint_ref')){ if(@($r.ram_state_required_fields) -notcontains $f){ Add-Err "ram_state_field_missing:$f" } }
  foreach($x in @('runtime.lock.json','heartbeat.json','checkpoints/latest.json','CONTINUOUS_AGENT_RUNTIME_V1_LAB_PROOF.json','CONTINUOUS_AGENT_RUNTIME_V1_LAB_SUMMARY.json')){ if(@($r.disk_outputs_allowed) -notcontains $x){ Add-Err "disk_allowed_missing:$x" } }
  foreach($x in @('per-cycle mind_logic_frame.json','per-cycle action_decision_packet.json','per-cycle wake_body_audit','per-cycle default_wake_reflexes.json','per-cycle RAM bridge JSON','raw reasoning transcript')){ if(@($r.disk_outputs_forbidden) -notcontains $x){ Add-Err "disk_forbidden_missing:$x" } }
  if(@($r.owner_facing_parameters).Count -ne 1 -or @($r.owner_facing_parameters)[0] -ne 'DurationMinutes'){ Add-Err 'owner_params_not_duration_only' }
  if($r.internal_defaults.Mode -ne 'SandboxExploration'){ Add-Err 'default_mode_mismatch' }
  if($r.internal_defaults.MemoryMode -ne 'QueueOnly'){ Add-Err 'default_memory_mode_mismatch' }
  foreach($flag in @('NoGit','NoCodex','NoWeb','NoRepair','NoCleanup')){ if($r.internal_defaults.$flag -ne $true){ Add-Err "internal_default_not_true:$flag" } }
  if($r.validator_expectations.same_pid_across_cycles -ne $true){ Add-Err 'same_pid_expectation_missing' }
  if($r.validator_expectations.cycle_count_min -lt 2){ Add-Err 'cycle_min_too_low' }
  if($r.validator_expectations.ram_counter_final_min -lt 2){ Add-Err 'ram_counter_min_too_low' }
  if($r.validator_expectations.per_cycle_json_bridge_used_for_ram_state -ne $false){ Add-Err 'json_bridge_expectation_wrong' }
  foreach($flag in @('repo_mutated','active_memory_direct_mutated','codex_launched','web_launched','school_launched','raw_debug_retained')){ if($r.validator_expectations.$flag -ne $false){ Add-Err "validator_expectation_not_false:$flag" } }
  foreach($claim in @('canonical life replaced','agent became autonomous','mind quality improved','compact memory integration solved','live/unattended runtime ready')){ if(@($r.acceptance_boundary.may_not_claim) -notcontains $claim){ Add-Err "missing_may_not_claim:$claim" } }
  if($r.next_slice -ne 'CODEX_TASK_CONTINUOUS_AGENT_RUNTIME_V1_LAB_SLICE_A'){ Add-Err 'next_slice_mismatch' }
  if($r.boundary.audit_only -ne $true){ Add-Err 'audit_only_not_true' }
  if($r.boundary.continuous_runtime_launched -ne $false){ Add-Err 'continuous_runtime_launched_not_false' }
  if($r.boundary.runtime_root_created -ne $false){ Add-Err 'runtime_root_created_not_false' }
  if($r.boundary.canonical_launcher_mutated -ne $false){ Add-Err 'canonical_launcher_mutated_not_false' }
  if($r.boundary.cycle_runner_mutated -ne $false){ Add-Err 'cycle_runner_mutated_not_false' }
  if($r.boundary.active_memory_mutated -ne $false){ Add-Err 'active_memory_mutated_not_false' }
}
$procs=@(Get-CimInstance Win32_Process | Where-Object { $_.CommandLine -and $_.CommandLine -notmatch '\s-Command\s' -and $_.CommandLine -match 'run_autonomous_inner_motor.ps1|start_agent_life_v1.ps1|invoke_body_self_inspection_circuit_v1.ps1|codex exec|node.*codex|school|run_continuous_agent_runtime_v1.ps1|continuous_agent_runtime_v1' })
if($procs.Count -ne 0){ Add-Err "process_count_not_zero:$($procs.Count)" }
$status=if($errors.Count -eq 0){'PASS_RAM_LIFE_AUDIT_F_CONTINUOUS_RUNTIME_LAB_DESIGN_V1'}else{'FAIL_RAM_LIFE_AUDIT_F_CONTINUOUS_RUNTIME_LAB_DESIGN_V1'}
$proof=[ordered]@{
  schema='ram_life_audit_f_continuous_runtime_lab_design_v1_validation'
  status=$status
  checked_at=(Get-Date).ToUniversalTime().ToString('o')
  plan=$plan
  report=$reportPath
  allowed_count=if($r){@($r.allowed).Count}else{0}
  forbidden_count=if($r){@($r.forbidden).Count}else{0}
  process_count=$procs.Count
  errors=@($errors)
  boundary=[ordered]@{ audit_only=$true; continuous_runtime_launched=$false; runtime_root_created=$false; canonical_launcher_mutated=$false; cycle_runner_mutated=$false; active_memory_mutated=$false; repo_runtime_mutated=$false; codex_launched=$false; web_launched=$false; school_launched=$false }
}
WJson 'tests/self_development/RAM_LIFE_AUDIT_F_CONTINUOUS_RUNTIME_LAB_DESIGN_V1_PROOF.json' $proof
Write-Host "STATUS=$status"
if($errors.Count -gt 0){ foreach($e in $errors){Write-Host "ERROR=$e"}; exit 1 }
