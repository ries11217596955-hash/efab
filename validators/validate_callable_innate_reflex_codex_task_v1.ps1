$ErrorActionPreference='Stop'
$errors=@()
function Add-Err([string]$e){ $script:errors += $e }
function WJson($path,$obj){ $dir=Split-Path $path -Parent; if($dir){New-Item -ItemType Directory -Force -Path $dir|Out-Null}; $json=($obj|ConvertTo-Json -Depth 50) -replace "`r`n","`n"; [System.IO.File]::WriteAllText((Join-Path (Get-Location).Path $path),$json.TrimEnd()+"`n",(New-Object System.Text.UTF8Encoding($false))) }
$task='operations/autonomous_inner_motor/CODEX_TASK_CALLABLE_INNATE_REFLEX_KERNEL_V1.md'
$plan='AGENT_BUILDER_INNATE_REFLEX_KERNEL_V1_PLAN.md'
if(-not(Test-Path $task)){ Add-Err 'missing_callable_codex_task' }
if(-not(Test-Path $plan)){ Add-Err 'missing_root_plan' }
$taskText=if(Test-Path $task){Get-Content $task -Raw}else{''}
$planText=if(Test-Path $plan){Get-Content $plan -Raw}else{''}
$requiredTask=@(
  'READY_FOR_CODEX / NOT_RUN','callable innate reflexes','PREFLIGHT_PASS','Files changed before PREFLIGHT_PASS: YES/NO',
  'Allowed new files','Allowed modifications','Forbidden files / surfaces','invoke body self-inspection circuit',
  'body_audit_reflex','BODY_SELF_INSPECTION_CIRCUIT_V1','AVAILABLE_NOT_WIRED','RESERVED_NOT_BUILT',
  'build_innate_reflex_kernel_v1.ps1','validate_callable_innate_reflex_kernel_v1.ps1','CALLABLE_INNATE_REFLEX_KERNEL_V1_PROOF.json',
  'PASS_CALLABLE_INNATE_REFLEX_KERNEL_V1','All 25 reflexes implemented: YES/NO'
)
foreach($needle in $requiredTask){ if($taskText -notlike "*$needle*"){ Add-Err "task_missing:$needle" } }
$reflexes=@('body_audit_reflex','organ_audit_reflex','full_body_map_audit_reflex','repo_reality_reflex','process_scan_reflex','runtime_pressure_reflex','preflight_reflex','validator_run_reflex','proof_pack_reflex','rollback_reflex','quarantine_reflex','stop_or_freeze_reflex','memory_queue_reflex','active_memory_read_reflex','memory_digest_reflex','handoff_write_reflex','self_notebook_update_reflex','directory_create_reflex','file_normalize_reflex','archive_backup_reflex','artifact_convert_reflex','codex_consult_reflex','codex_task_authoring_reflex','web_source_search_reflex','source_ingestion_reflex')
foreach($r in $reflexes){ if($taskText -notlike "*$r*" -or $planText -notlike "*$r*"){ Add-Err "reflex_missing:$r" } }
$allowedBlock = [regex]::Match($taskText, 'Allowed modifications:[\s\S]*?Allowed runtime outputs').Value
if($allowedBlock -like '*operations/autonomous_inner_motor/start_agent_life_v1.ps1*'){ Add-Err 'canonical_launcher_appears_allowed_for_modification' }
$status=if($errors.Count -eq 0){'PASS_CALLABLE_INNATE_REFLEX_CODEX_TASK_V1'}else{'FAIL_CALLABLE_INNATE_REFLEX_CODEX_TASK_V1'}
$proof=[ordered]@{
  schema='callable_innate_reflex_codex_task_v1_validation'
  status=$status
  checked_at=(Get-Date).ToUniversalTime().ToString('o')
  task=$task
  plan=$plan
  reflex_count=$reflexes.Count
  errors=@($errors)
  boundary=[ordered]@{ task_only=$true; codex_not_launched_by_validator=$true; implementation_not_done=$true; body_inspection_invoked=$false; active_memory_mutated=$false; live_process_touched=$false }
}
WJson 'tests/self_development/CALLABLE_INNATE_REFLEX_CODEX_TASK_V1_PROOF.json' $proof
Write-Host "STATUS=$status"
if($errors.Count -gt 0){ foreach($e in $errors){Write-Host "ERROR=$e"}; exit 1 }
