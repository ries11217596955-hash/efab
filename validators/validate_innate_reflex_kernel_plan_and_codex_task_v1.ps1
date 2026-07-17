$ErrorActionPreference='Stop'
$errors=@()
function Add-Err([string]$e){ $script:errors += $e }
function WJson($path,$obj){ $dir=Split-Path $path -Parent; if($dir){New-Item -ItemType Directory -Force -Path $dir|Out-Null}; $json=($obj|ConvertTo-Json -Depth 40) -replace "`r`n","`n"; [System.IO.File]::WriteAllText((Join-Path (Get-Location).Path $path),$json.TrimEnd()+"`n",(New-Object System.Text.UTF8Encoding($false))) }
$plan='AGENT_BUILDER_INNATE_REFLEX_KERNEL_V1_PLAN.md'
$task='operations/autonomous_inner_motor/CODEX_TASK_INNATE_REFLEX_KERNEL_V1.md'
$old='AGENT_BUILDER_NEXT_15_STEPS_LOCK_V2_R2.md'
foreach($p in @($plan,$task,$old)){ if(-not(Test-Path $p)){ Add-Err "missing:$p" } }
$planText=if(Test-Path $plan){Get-Content $plan -Raw}else{''}
$taskText=if(Test-Path $task){Get-Content $task -Raw}else{''}
$oldText=if(Test-Path $old){Get-Content $old -Raw}else{''}
foreach($needle in @('INNATE_REFLEX_KERNEL_V1','BODY_AWARENESS_REFLEX_V1','body_awareness_reflex','18+ reflex slots','RESERVED_NOT_BUILT','AVAILABLE_NOT_INVOKED','canonical AIMO life','Do not implement all 18 reflexes','Do not delete the old root plan')){ if($planText -notlike "*$needle*"){ Add-Err "plan_missing:$needle" } }
foreach($needle in @('PREFLIGHT_PASS','Files changed before PREFLIGHT_PASS: YES/NO','Allowed new files','innate_reflex_kernel_v1.json','build_innate_reflex_kernel_v1.ps1','validate_innate_reflex_kernel_v1.ps1','INNATE_REFLEX_KERNEL_V1_PROOF.json','Do not invoke body self-inspection circuit','canonical launcher still has only DurationMinutes','PASS_INNATE_REFLEX_KERNEL_V1')){ if($taskText -notlike "*$needle*"){ Add-Err "task_missing:$needle" } }
$reflexes=@('body_awareness_reflex','proof_pain_reflex','confusion_reflex','owner_call_reflex','danger_stop_reflex','repetition_boredom_reflex','memory_hunger_reflex','source_hunger_reflex','sleep_digest_reflex','runtime_pressure_reflex','body_damage_reflex','unknown_gap_reflex','return_to_parent_reflex','quarantine_reflex','self_map_reflex','food_request_reflex','boundary_respect_reflex','validator_need_reflex')
foreach($r in $reflexes){ if($planText -notlike "*$r*" -or $taskText -notlike "*$r*"){ Add-Err "reflex_missing:$r" } }
if($oldText -notlike '*Superseded by AGENT_BUILDER_INNATE_REFLEX_KERNEL_V1_PLAN.md*'){ Add-Err 'old_plan_not_marked_superseded' }
if($taskText -like '*Allowed modifications:*' -and $taskText -notlike '*run_autonomous_inner_motor.ps1*'){ Add-Err 'task_missing_runner_modification_allowance' }
$status=if($errors.Count -eq 0){'PASS_INNATE_REFLEX_KERNEL_PLAN_AND_CODEX_TASK_V1'}else{'FAIL_INNATE_REFLEX_KERNEL_PLAN_AND_CODEX_TASK_V1'}
$proof=[ordered]@{
  schema='innate_reflex_kernel_plan_and_codex_task_v1_validation'
  status=$status
  checked_at=(Get-Date).ToUniversalTime().ToString('o')
  plan=$plan
  codex_task=$task
  old_plan=$old
  reflex_count=$reflexes.Count
  errors=@($errors)
  boundary=[ordered]@{ plan_only=$true; codex_not_launched=$true; implementation_not_done=$true; body_inspection_invoked=$false; active_memory_mutated=$false; live_process_touched=$false; old_plan_deleted=$false }
}
WJson 'tests/self_development/INNATE_REFLEX_KERNEL_PLAN_AND_CODEX_TASK_V1_PROOF.json' $proof
Write-Host "STATUS=$status"
if($errors.Count -gt 0){ foreach($e in $errors){Write-Host "ERROR=$e"}; exit 1 }
