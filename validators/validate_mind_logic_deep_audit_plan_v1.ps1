$ErrorActionPreference='Stop'
$errors=@()
function Add-Err([string]$e){ $script:errors += $e }
function WJson($path,$obj){ $dir=Split-Path $path -Parent; if($dir){New-Item -ItemType Directory -Force -Path $dir|Out-Null}; $json=($obj|ConvertTo-Json -Depth 100) -replace "`r`n","`n"; [System.IO.File]::WriteAllText((Join-Path (Get-Location).Path $path),$json.TrimEnd()+"`n",(New-Object System.Text.UTF8Encoding($false))) }
$plan='AGENT_BUILDER_MIND_LOGIC_DEEP_AUDIT_PLAN_V1.md'
$transition='AGENT_BUILDER_RAM_LIFE_TRANSITION_MASTER_PLAN_V1.md'
$notebook='AGENT_BUILDER_SELF_NOTEBOOK.md'
$report='operations/autonomous_inner_motor/reports/MIND_LOGIC_DEEP_AUDIT_PLAN_V1_ACCEPTANCE.json'
foreach($p in @($plan,$transition,$notebook,$report)){ if(-not(Test-Path $p)){ Add-Err "missing:$p" } }
$planText=if(Test-Path $plan){Get-Content $plan -Raw}else{''}
foreach($needle in @('AUDIT_M1_CURRENT_MIND_TOPOLOGY_V1','AUDIT_M2_LOOP_AND_STALL_PATTERNS_V1','AUDIT_M3_COMPACT_MEMORY_READ_PATH_V1','AUDIT_M4_FRONTIER_TO_BUILD_TASK_GAP_V1','AUDIT_M5_DECISION_QUALITY_AND_UTILITY_V1','AUDIT_M6_MINIMUM_MIND_REPAIR_PLAN_V1','SELECTIVE_COMPACT_MEMORY_RETRIEVAL_V1','FRONTIER_TO_BUILD_TASK_ROUTER_V1','Do not run more life trials to hope for intelligence')){ if($planText -notlike "*$needle*"){ Add-Err "plan_missing:$needle" } }
$transitionText=if(Test-Path $transition){Get-Content $transition -Raw}else{''}
if($transitionText -notlike '*PHASE_PROVEN_LAB_NOT_CANONICAL_REPLACEMENT*'){ Add-Err 'transition_status_missing' }
if($transitionText -notlike '*Do not delete this transition plan yet*'){ Add-Err 'transition_delete_guard_missing' }
$nbText=if(Test-Path $notebook){Get-Content $notebook -Raw}else{''}
foreach($needle in @('CURRENT_LIFE_REALITY_RAM_LAB_NOT_CANONICAL','RAM life is not the canonical life process yet','Canonical agent life still launches through operations/autonomous_inner_motor/start_agent_life_v1.ps1','Deep audit of mind/logic/decision flow')){ if($nbText -notlike "*$needle*"){ Add-Err "notebook_missing:$needle" } }
$r=$null
if(Test-Path $report){$r=Get-Content $report -Raw|ConvertFrom-Json}
if($r){
  if($r.status -ne 'ACCEPTED_STRATEGY_SUPPORTED_MIND_LOGIC_DEEP_AUDIT_PLAN_V1'){ Add-Err "report_status_mismatch:$($r.status)" }
  if($r.transition_plan_status -ne 'PHASE_PROVEN_LAB_NOT_CANONICAL_REPLACEMENT'){ Add-Err 'report_transition_status_mismatch' }
  if($r.current_life_reality.ram_lab_status -ne 'PROVEN_LAB_NOT_CANONICAL'){ Add-Err 'report_ram_status_mismatch' }
  if($r.first_audit -ne 'AUDIT_M1_CURRENT_MIND_TOPOLOGY_V1'){ Add-Err 'first_audit_mismatch' }
  foreach($organ in @('SELECTIVE_COMPACT_MEMORY_RETRIEVAL_V1','FRONTIER_TO_BUILD_TASK_ROUTER_V1','LOOP_STALL_DETECTOR_V1','DECISION_UTILITY_SCORE_V1','PARENT_GOAL_RETURN_GATE_V1')){ if(@($r.candidate_organs) -notcontains $organ){ Add-Err "candidate_missing:$organ" } }
  if($r.boundary.runtime_launched -ne $false){ Add-Err 'runtime_launched_not_false' }
  if($r.boundary.active_memory_mutated -ne $false){ Add-Err 'active_memory_mutated_not_false' }
  if($r.boundary.transition_plan_deleted -ne $false){ Add-Err 'transition_plan_deleted_not_false' }
}
$procs=@(Get-CimInstance Win32_Process | Where-Object { $_.CommandLine -and $_.CommandLine -notmatch 'Get-CimInstance Win32_Process' -and $_.CommandLine -match 'run_autonomous_inner_motor.ps1|start_agent_life_v1.ps1|invoke_body_self_inspection_circuit_v1.ps1|codex exec|node_modules.*@openai/codex|node.*codex.js|school|run_continuous_agent_runtime_v1_lab.ps1|continuous_agent_runtime_v1' })
if($procs.Count -ne 0){ Add-Err "process_count_not_zero:$($procs.Count)" }
$status=if($errors.Count -eq 0){'PASS_MIND_LOGIC_DEEP_AUDIT_PLAN_V1'}else{'FAIL_MIND_LOGIC_DEEP_AUDIT_PLAN_V1'}
$proof=[ordered]@{
  schema='mind_logic_deep_audit_plan_v1_validation'
  status=$status
  checked_at=(Get-Date).ToUniversalTime().ToString('o')
  plan=$plan
  transition_plan=$transition
  notebook=$notebook
  report=$report
  process_count=$procs.Count
  errors=@($errors)
  boundary=[ordered]@{plan_only=$true; runtime_launched=$false; active_memory_mutated=$false; canonical_launcher_mutated=$false; cycle_runner_mutated=$false; transition_plan_deleted=$false}
}
WJson 'tests/self_development/MIND_LOGIC_DEEP_AUDIT_PLAN_V1_PROOF.json' $proof
Write-Host "STATUS=$status"
if($errors.Count -gt 0){foreach($e in $errors){Write-Host "ERROR=$e"}; exit 1}
