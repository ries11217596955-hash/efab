$ErrorActionPreference='Stop'
$errors=@()
function Add-Err([string]$e){ $script:errors += $e }
function WJson($path,$obj){ $dir=Split-Path $path -Parent; if($dir){New-Item -ItemType Directory -Force -Path $dir|Out-Null}; $json=($obj|ConvertTo-Json -Depth 100) -replace "`r`n","`n"; [System.IO.File]::WriteAllText((Join-Path (Get-Location).Path $path),$json.TrimEnd()+"`n",(New-Object System.Text.UTF8Encoding($false))) }
$mind='AGENT_BUILDER_MIND_LOGIC_DEEP_AUDIT_PLAN_V1.md'
$reflex='AGENT_BUILDER_INNATE_REFLEX_KERNEL_V1_PLAN.md'
$nb='AGENT_BUILDER_SELF_NOTEBOOK.md'
$report='operations/autonomous_inner_motor/reports/REFLECTION_DEBT_SOURCE_MAP_V1.json'
foreach($p in @($mind,$reflex,$nb,$report)){ if(-not(Test-Path $p)){ Add-Err "missing:$p" } }
$mindText=if(Test-Path $mind){Get-Content $mind -Raw}else{''}
foreach($needle in @('Reflection / reflexion debt source','Reflexes = callable built-in sensing/action capabilities','Reflection = the mind''s ability to inspect its own thinking','AUDIT_REF1_REFLECTION_CURRENT_STATE_V1','SELF_REFLECTION_FRAME_V1','LOOP_STALL_DETECTOR_V1','DECISION_UTILITY_SCORE_V1','PARENT_GOAL_RETURN_GATE_V1','LAST_ACTION_POSTMORTEM_V1','FAKE_PROGRESS_DETECTOR_V1','NEXT_STEP_SHARPENER_V1','reflection_output_used_by_action_decision = true')){ if($mindText -notlike "*$needle*"){ Add-Err "mind_missing:$needle" } }
$reflexText=if(Test-Path $reflex){Get-Content $reflex -Raw}else{''}
foreach($needle in @('INNATE_REFLEX_KERNEL_V1','DEFAULT_WAKE_REFLEXES','body_audit_reflex','repo_reality_reflex','process_scan_reflex','runtime_pressure_reflex')){ if($reflexText -notlike "*$needle*"){ Add-Err "reflex_source_missing:$needle" } }
$nbText=if(Test-Path $nb){Get-Content $nb -Raw}else{''}
foreach($needle in @('REFLECTION_DEBT_NOT_REFLEX_DEBT','Reflexes = callable built-in capabilities','Reflection = mind''s ability to inspect last cycle','AUDIT_REF1_REFLECTION_CURRENT_STATE_V1','Reflection is accepted only when proof shows reflection output changed action decision')){ if($nbText -notlike "*$needle*"){ Add-Err "notebook_missing:$needle" } }
$r=$null
if(Test-Path $report){$r=Get-Content $report -Raw|ConvertFrom-Json}
if($r){
  if($r.status -ne 'PASS_REFLECTION_DEBT_SOURCE_MAP_V1'){ Add-Err "report_status_mismatch:$($r.status)" }
  if($r.reflection_status -ne 'REFLECTION_TRACK_NOT_FULL_ORGAN'){ Add-Err 'reflection_status_mismatch' }
  if($r.needed_audit -ne 'AUDIT_REF1_REFLECTION_CURRENT_STATE_V1'){ Add-Err 'needed_audit_mismatch' }
  foreach($organ in @('SELF_REFLECTION_FRAME_V1','LOOP_STALL_DETECTOR_V1','DECISION_UTILITY_SCORE_V1','PARENT_GOAL_RETURN_GATE_V1','LAST_ACTION_POSTMORTEM_V1','FAKE_PROGRESS_DETECTOR_V1','NEXT_STEP_SHARPENER_V1')){ if(@($r.candidate_organs) -notcontains $organ){ Add-Err "candidate_missing:$organ" } }
  foreach($k in @('last_cycle_observed','loop_or_stall_checked','utility_score_computed','parent_goal_delta_computed','fake_progress_checked','next_step_changed_by_reflection','reflection_output_used_by_action_decision')){ if($r.acceptance_condition.$k -ne $true){ Add-Err "acceptance_missing:$k" } }
  if($r.boundary.runtime_launched -ne $false){ Add-Err 'runtime_launched_not_false' }
  if($r.boundary.active_memory_mutated -ne $false){ Add-Err 'active_memory_mutated_not_false' }
  if($r.boundary.reflection_organ_built -ne $false){ Add-Err 'reflection_organ_built_not_false' }
  if($r.boundary.canonical_launcher_mutated -ne $false){ Add-Err 'canonical_launcher_mutated_not_false' }
}
$procs=@(Get-CimInstance Win32_Process | Where-Object { $_.CommandLine -and $_.CommandLine -notmatch 'Get-CimInstance Win32_Process' -and $_.CommandLine -match 'run_autonomous_inner_motor.ps1|start_agent_life_v1.ps1|invoke_body_self_inspection_circuit_v1.ps1|codex exec|node_modules.*@openai/codex|node.*codex.js|school|run_continuous_agent_runtime_v1_lab.ps1|continuous_agent_runtime_v1' })
if($procs.Count -ne 0){ Add-Err "process_count_not_zero:$($procs.Count)" }
$status=if($errors.Count -eq 0){'PASS_REFLECTION_DEBT_SOURCE_MAP_V1'}else{'FAIL_REFLECTION_DEBT_SOURCE_MAP_V1'}
$proof=[ordered]@{
  schema='reflection_debt_source_map_v1_validation'
  status=$status
  checked_at=(Get-Date).ToUniversalTime().ToString('o')
  report=$report
  mind_plan=$mind
  reflex_source=$reflex
  notebook=$nb
  process_count=$procs.Count
  errors=@($errors)
  boundary=[ordered]@{source_map_only=$true; runtime_launched=$false; active_memory_mutated=$false; reflex_plan_deleted=$false; reflection_organ_built=$false; canonical_launcher_mutated=$false; cycle_runner_mutated=$false}
}
WJson 'tests/self_development/REFLECTION_DEBT_SOURCE_MAP_V1_PROOF.json' $proof
Write-Host "STATUS=$status"
if($errors.Count -gt 0){ foreach($e in $errors){Write-Host "ERROR=$e"}; exit 1 }
