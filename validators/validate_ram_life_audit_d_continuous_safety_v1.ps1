$ErrorActionPreference='Stop'
$errors=@()
function Add-Err([string]$e){ $script:errors += $e }
function WJson($path,$obj){ $dir=Split-Path $path -Parent; if($dir){New-Item -ItemType Directory -Force -Path $dir|Out-Null}; $json=($obj|ConvertTo-Json -Depth 100) -replace "`r`n","`n"; [System.IO.File]::WriteAllText((Join-Path (Get-Location).Path $path),$json.TrimEnd()+"`n",(New-Object System.Text.UTF8Encoding($false))) }
$plan='AGENT_BUILDER_RAM_LIFE_TRANSITION_MASTER_PLAN_V1.md'
$reportPath='operations/autonomous_inner_motor/reports/RAM_LIFE_AUDIT_D_CONTINUOUS_SAFETY_V1.json'
foreach($p in @($plan,$reportPath)){ if(-not(Test-Path $p)){ Add-Err "missing:$p" } }
$planText=if(Test-Path $plan){Get-Content $plan -Raw}else{''}
foreach($needle in @('AUDIT_D_CONTINUOUS_SAFETY_V1 detailed design','runtime_lock','heartbeat','stop_signal','watchdog','bounded_duration','checkpoint_writer','crash_recovery_reader','quarantine_on_fault','Start gate for CONTINUOUS_AGENT_RUNTIME_V1_LAB','same_pid_across_cycles=true','per_cycle_json_bridge_used_for_ram_state=false')){ if($planText -notlike "*$needle*"){ Add-Err "plan_missing:$needle" } }
$r=$null
if(Test-Path $reportPath){ $r=Get-Content $reportPath -Raw | ConvertFrom-Json }
if($r){
  if($r.status -ne 'PASS_RAM_LIFE_AUDIT_D_CONTINUOUS_SAFETY_V1'){ Add-Err "status_mismatch:$($r.status)" }
  foreach($organ in @('runtime_lock','pid_file','heartbeat','stop_signal','watchdog','bounded_duration','memory_budget','cpu_budget','disk_budget','checkpoint_writer','crash_recovery_reader','quarantine_on_fault','duplicate_runtime_prevention','safe_shutdown','final_proof_writer')){ if(@($r.safety_organs) -notcontains $organ){ Add-Err "missing_organ:$organ" } }
  foreach($gate in @('repo clean','remote delta 0/0','process_count 0','active memory root exists','minimal supervised life context exists or is generated from current canonical launch context','runtime lock absent or proven stale','heartbeat path writable','checkpoint path writable','duration cap provided','SandboxExploration only','QueueOnly only','git/codex/web/repair disabled','proof path writable')){ if(@($r.start_gate) -notcontains $gate){ Add-Err "missing_start_gate:$gate" } }
  if($r.lab_limits.duration_minutes_max -gt 5){ Add-Err 'duration_limit_too_high' }
  if($r.lab_limits.mode -ne 'SandboxExploration'){ Add-Err 'mode_not_sandbox' }
  if($r.lab_limits.memory_ingestion -ne 'QueueOnly'){ Add-Err 'memory_ingestion_not_queueonly' }
  foreach($flag in @('git_enabled','codex_enabled','web_enabled','repair_enabled','active_memory_direct_write','raw_debug_retained_default')){ if($r.lab_limits.$flag -ne $false){ Add-Err "lab_limit_not_false:$flag" } }
  if($r.proof_expectations.same_pid_across_cycles -ne $true){ Add-Err 'same_pid_expectation_missing' }
  if($r.proof_expectations.ram_state_counter_persisted -ne $true){ Add-Err 'ram_state_counter_expectation_missing' }
  if($r.proof_expectations.per_cycle_json_bridge_used_for_ram_state -ne $false){ Add-Err 'json_bridge_expectation_wrong' }
  foreach($flag in @('repo_mutated','active_memory_direct_mutated','codex_launched','web_launched','school_launched')){ if($r.proof_expectations.$flag -ne $false){ Add-Err "proof_expectation_not_false:$flag" } }
  if($r.implementation_decision -notlike '*SUPERVISED_RAM_LAB_CAN_PROCEED_AFTER_AUDIT_F*'){ Add-Err 'implementation_gate_missing' }
  if($r.next_audit -ne 'AUDIT_F_CONTINUOUS_RUNTIME_LAB_DESIGN_V1'){ Add-Err 'next_audit_mismatch' }
  if($r.boundary.audit_only -ne $true){ Add-Err 'audit_only_not_true' }
  if($r.boundary.continuous_runtime_launched -ne $false){ Add-Err 'continuous_runtime_launched_not_false' }
  if($r.boundary.runtime_root_created -ne $false){ Add-Err 'runtime_root_created_not_false' }
  if($r.boundary.active_memory_mutated -ne $false){ Add-Err 'active_memory_mutated_not_false' }
}
$procs=@(Get-CimInstance Win32_Process | Where-Object { $_.CommandLine -and $_.CommandLine -notmatch '\s-Command\s' -and $_.CommandLine -match 'run_autonomous_inner_motor.ps1|start_agent_life_v1.ps1|invoke_body_self_inspection_circuit_v1.ps1|codex exec|node.*codex|school|run_continuous_agent_runtime_v1.ps1|continuous_agent_runtime_v1' })
if($procs.Count -ne 0){ Add-Err "process_count_not_zero:$($procs.Count)" }
$status=if($errors.Count -eq 0){'PASS_RAM_LIFE_AUDIT_D_CONTINUOUS_SAFETY_V1'}else{'FAIL_RAM_LIFE_AUDIT_D_CONTINUOUS_SAFETY_V1'}
$proof=[ordered]@{
  schema='ram_life_audit_d_continuous_safety_v1_validation'
  status=$status
  checked_at=(Get-Date).ToUniversalTime().ToString('o')
  plan=$plan
  report=$reportPath
  safety_organs_count=if($r){@($r.safety_organs).Count}else{0}
  start_gate_count=if($r){@($r.start_gate).Count}else{0}
  process_count=$procs.Count
  errors=@($errors)
  boundary=[ordered]@{ audit_only=$true; continuous_runtime_launched=$false; runtime_root_created=$false; active_memory_mutated=$false; repo_runtime_mutated=$false; codex_launched=$false; web_launched=$false; school_launched=$false }
}
WJson 'tests/self_development/RAM_LIFE_AUDIT_D_CONTINUOUS_SAFETY_V1_PROOF.json' $proof
Write-Host "STATUS=$status"
if($errors.Count -gt 0){ foreach($e in $errors){Write-Host "ERROR=$e"}; exit 1 }
