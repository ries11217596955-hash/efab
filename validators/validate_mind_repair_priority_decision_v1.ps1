$ErrorActionPreference='Stop'
$errors=@()
function Add-Err([string]$e){ $script:errors += $e }
function WJson($path,$obj){ $dir=Split-Path $path -Parent; if($dir){New-Item -ItemType Directory -Force -Path $dir|Out-Null}; $json=($obj|ConvertTo-Json -Depth 100) -replace "`r`n","`n"; [System.IO.File]::WriteAllText((Join-Path (Get-Location).Path $path),$json.TrimEnd()+"`n",(New-Object System.Text.UTF8Encoding($false))) }
$plan='AGENT_BUILDER_MIND_REPAIR_PRIORITY_PLAN_V1.md'
$main='AGENT_BUILDER_MIND_LOGIC_DEEP_AUDIT_PLAN_V1.md'
$nb='AGENT_BUILDER_SELF_NOTEBOOK.md'
$report='operations/autonomous_inner_motor/reports/MIND_REPAIR_PRIORITY_DECISION_V1.json'
$m1='operations/autonomous_inner_motor/reports/MIND_AUDIT_M1_CURRENT_MIND_TOPOLOGY_V1.json'
foreach($p in @($plan,$main,$nb,$report,$m1)){ if(-not(Test-Path $p)){ Add-Err "missing:$p" } }
$planText=if(Test-Path $plan){Get-Content $plan -Raw}else{''}
foreach($needle in @('LOGIC FIRST','NEXT_BUILD_TASK_DECISION_SPINE_V1','DECISION_CHAIN_ENDS_AT_QUEUE_PACKET','FRONTIER_TO_BUILD_TASK_MISSING','SHORT_TERM_MEMORY_IS_WAKE_CONTEXT_NOT_MIND_STATE','Do not build short-term memory before defining the decision spine','NEXT_BUILD_TASK_DECISION_SPINE_V1_SLICE_A')){ if($planText -notlike "*$needle*"){ Add-Err "plan_missing:$needle" } }
$r=$null
if(Test-Path $report){$r=Get-Content $report -Raw|ConvertFrom-Json}
if($r){
  if($r.status -ne 'PASS_MIND_REPAIR_PRIORITY_DECISION_V1'){ Add-Err "status_mismatch:$($r.status)" }
  if($r.decision -ne 'LOGIC_FIRST'){ Add-Err "decision_mismatch:$($r.decision)" }
  if($r.first_repair_target -ne 'NEXT_BUILD_TASK_DECISION_SPINE_V1'){ Add-Err 'first_repair_target_mismatch' }
  foreach($item in @('NEXT_BUILD_TASK_DECISION_SPINE_V1','SELECTIVE_COMPACT_MEMORY_RETRIEVAL_V1','SHORT_TERM_MIND_STATE_V1','FRONTIER_TO_BUILD_TASK_ROUTER_V1','AUDIT_RX1_REFLEX_MATRIX_CURRENT_STATE_V1','AUDIT_R1_RAM_CANONICAL_MIGRATION_GAP_V1')){ if(@($r.priority_order) -notcontains $item){ Add-Err "priority_missing:$item" } }
  foreach($item in @('decision_spine field exists in proof/summary','candidate_build_task or blocked_reason is non-empty','next_action_type is explicit','queue packet creation is not counted as final action','validator proves boundary')){ if(@($r.acceptance_for_first_repair) -notcontains $item){ Add-Err "acceptance_missing:$item" } }
  if($r.boundary.runtime_launched -ne $false){ Add-Err 'runtime_launched_not_false' }
  if($r.boundary.active_memory_mutated -ne $false){ Add-Err 'active_memory_mutated_not_false' }
}
$m1r=$null
if(Test-Path $m1){$m1r=Get-Content $m1 -Raw|ConvertFrom-Json}
if($m1r){
  foreach($label in @('DECISION_CHAIN_ENDS_AT_QUEUE_PACKET','FRONTIER_TO_BUILD_TASK_MISSING','SHORT_TERM_MEMORY_IS_WAKE_CONTEXT_NOT_MIND_STATE')){ if(@($m1r.findings | Where-Object {$_.label -eq $label}).Count -ne 1){ Add-Err "m1_basis_missing:$label" } }
}
$mainText=if(Test-Path $main){Get-Content $main -Raw}else{''}
foreach($needle in @('Repair priority decision after M1','LOGIC FIRST','NEXT_BUILD_TASK_DECISION_SPINE_V1')){ if($mainText -notlike "*$needle*"){ Add-Err "main_plan_missing:$needle" } }
$nbText=if(Test-Path $nb){Get-Content $nb -Raw}else{''}
foreach($needle in @('MIND_REPAIR_PRIORITY_LOGIC_FIRST','first repair priority is logic','Build NEXT_BUILD_TASK_DECISION_SPINE_V1 first')){ if($nbText -notlike "*$needle*"){ Add-Err "notebook_missing:$needle" } }
$procs=@(Get-CimInstance Win32_Process | Where-Object { $_.CommandLine -and $_.CommandLine -notmatch 'Get-CimInstance Win32_Process' -and $_.CommandLine -match 'run_autonomous_inner_motor.ps1|start_agent_life_v1.ps1|invoke_body_self_inspection_circuit_v1.ps1|codex exec|node_modules.*@openai/codex|node.*codex.js|school|run_continuous_agent_runtime_v1_lab.ps1|continuous_agent_runtime_v1' })
if($procs.Count -ne 0){ Add-Err "process_count_not_zero:$($procs.Count)" }
$status=if($errors.Count -eq 0){'PASS_MIND_REPAIR_PRIORITY_DECISION_V1'}else{'FAIL_MIND_REPAIR_PRIORITY_DECISION_V1'}
$proof=[ordered]@{
  schema='mind_repair_priority_decision_v1_validation'
  status=$status
  checked_at=(Get-Date).ToUniversalTime().ToString('o')
  report=$report
  plan=$plan
  m1_report=$m1
  decision=if($r){$r.decision}else{$null}
  first_repair_target=if($r){$r.first_repair_target}else{$null}
  process_count=$procs.Count
  errors=@($errors)
  boundary=[ordered]@{plan_only=$true; runtime_launched=$false; active_memory_mutated=$false; canonical_launcher_mutated=$false; cycle_runner_mutated=$false; codex_launched=$false; web_launched=$false; school_launched=$false}
}
WJson 'tests/self_development/MIND_REPAIR_PRIORITY_DECISION_V1_PROOF.json' $proof
Write-Host "STATUS=$status"
if($errors.Count -gt 0){ foreach($e in $errors){Write-Host "ERROR=$e"}; exit 1 }
