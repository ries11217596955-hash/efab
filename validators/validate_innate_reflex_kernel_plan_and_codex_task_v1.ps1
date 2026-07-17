$ErrorActionPreference='Stop'
$errors=@()
function Add-Err([string]$e){ $script:errors += $e }
function WJson($path,$obj){
  $dir=Split-Path $path -Parent
  if($dir){New-Item -ItemType Directory -Force -Path $dir|Out-Null}
  $json=($obj|ConvertTo-Json -Depth 50) -replace "`r`n","`n"
  [System.IO.File]::WriteAllText((Join-Path (Get-Location).Path $path),$json.TrimEnd()+"`n",(New-Object System.Text.UTF8Encoding($false)))
}
$plan='AGENT_BUILDER_INNATE_REFLEX_KERNEL_V1_PLAN.md'
$task='operations/autonomous_inner_motor/CODEX_TASK_INNATE_REFLEX_KERNEL_V1.md'
$old='AGENT_BUILDER_NEXT_15_STEPS_LOCK_V2_R2.md'
foreach($p in @($plan,$task,$old)){ if(-not(Test-Path $p)){ Add-Err "missing:$p" } }
$planText=if(Test-Path $plan){Get-Content $plan -Raw}else{''}
$taskText=if(Test-Path $task){Get-Content $task -Raw}else{''}
$oldText=if(Test-Path $old){Get-Content $old -Raw}else{''}
$requiredPlan=@(
  'CORRECTED_EXECUTABLE_REFLEX_MODEL',
  'callable built-in reflexes',
  'A reflex is a built-in callable mechanism',
  'organ != reflex',
  'body_audit_reflex',
  'BODY_SELF_INSPECTION_CIRCUIT_V1',
  'AVAILABLE_NOT_WIRED',
  'RESERVED_NOT_BUILT',
  'Codex task status: NEEDS_REWRITE / OLD_TASK_BLOCKED',
  'Do not run the old Codex task'
)
foreach($needle in $requiredPlan){ if($planText -notlike "*$needle*"){ Add-Err "plan_missing:$needle" } }
$reflexes=@(
  'body_audit_reflex','organ_audit_reflex','full_body_map_audit_reflex','repo_reality_reflex','process_scan_reflex','runtime_pressure_reflex',
  'preflight_reflex','validator_run_reflex','proof_pack_reflex','rollback_reflex','quarantine_reflex','stop_or_freeze_reflex',
  'memory_queue_reflex','active_memory_read_reflex','memory_digest_reflex','handoff_write_reflex','self_notebook_update_reflex',
  'directory_create_reflex','file_normalize_reflex','archive_backup_reflex','artifact_convert_reflex',
  'codex_consult_reflex','codex_task_authoring_reflex','web_source_search_reflex','source_ingestion_reflex'
)
foreach($r in $reflexes){ if($planText -notlike "*$r*"){ Add-Err "reflex_missing:$r" } }
if($taskText -notlike '*CONCEPTUALLY_BLOCKED / DO_NOT_RUN*'){ Add-Err 'old_codex_task_not_blocked' }
if($taskText -notlike '*CODEX_TASK_CALLABLE_INNATE_REFLEX_KERNEL_V1.md*'){ Add-Err 'replacement_codex_task_not_named' }
if($oldText -notlike '*Superseded by AGENT_BUILDER_INNATE_REFLEX_KERNEL_V1_PLAN.md*'){ Add-Err 'old_plan_not_marked_superseded' }
$status=if($errors.Count -eq 0){'PASS_CALLABLE_INNATE_REFLEX_PLAN_V1'}else{'FAIL_CALLABLE_INNATE_REFLEX_PLAN_V1'}
$proof=[ordered]@{
  schema='callable_innate_reflex_plan_v1_validation'
  status=$status
  checked_at=(Get-Date).ToUniversalTime().ToString('o')
  plan=$plan
  blocked_old_codex_task=$task
  old_root_plan=$old
  reflex_count=$reflexes.Count
  first_real_reflex='body_audit_reflex'
  first_real_organ='BODY_SELF_INSPECTION_CIRCUIT_V1'
  errors=@($errors)
  boundary=[ordered]@{ plan_only=$true; codex_not_launched=$true; implementation_not_done=$true; body_inspection_invoked=$false; active_memory_mutated=$false; live_process_touched=$false; old_task_blocked=$true }
}
WJson 'tests/self_development/INNATE_REFLEX_KERNEL_PLAN_AND_CODEX_TASK_V1_PROOF.json' $proof
Write-Host "STATUS=$status"
if($errors.Count -gt 0){ foreach($e in $errors){Write-Host "ERROR=$e"}; exit 1 }
