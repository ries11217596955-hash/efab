$ErrorActionPreference='Stop'
$errors=@()
function Add-Err([string]$e){ $script:errors += $e }
function WJson($path,$obj){ $dir=Split-Path $path -Parent; if($dir){New-Item -ItemType Directory -Force -Path $dir|Out-Null}; $json=($obj|ConvertTo-Json -Depth 50) -replace "`r`n","`n"; [System.IO.File]::WriteAllText((Join-Path (Get-Location).Path $path),$json.TrimEnd()+"`n",(New-Object System.Text.UTF8Encoding($false))) }
$task='operations/autonomous_inner_motor/CODEX_TASK_CALLABLE_INNATE_REFLEX_KERNEL_V1_SLICE_A.md'
if(-not(Test-Path $task)){ Add-Err 'missing_slice_a_task' }
$text=if(Test-Path $task){Get-Content $task -Raw}else{''}
$required=@('READY_FOR_CODEX / NOT_RUN','Scope: manifest + builder + validator only','Explicitly out of scope: canonical runner integration','PREFLIGHT_PASS','Files changed before PREFLIGHT_PASS: YES/NO','Allowed files','Forbidden scope','Do not modify:','run_autonomous_inner_motor.ps1','invoke body self-inspection circuit','wire runner','PASS_CALLABLE_INNATE_REFLEX_KERNEL_V1_SLICE_A','Runner modified: YES/NO')
foreach($needle in $required){ if($text -notlike "*$needle*"){ Add-Err "task_missing:$needle" } }
$reflexes=@('body_audit_reflex','organ_audit_reflex','full_body_map_audit_reflex','repo_reality_reflex','process_scan_reflex','runtime_pressure_reflex','preflight_reflex','validator_run_reflex','proof_pack_reflex','rollback_reflex','quarantine_reflex','stop_or_freeze_reflex','memory_queue_reflex','active_memory_read_reflex','memory_digest_reflex','handoff_write_reflex','self_notebook_update_reflex','directory_create_reflex','file_normalize_reflex','archive_backup_reflex','artifact_convert_reflex','codex_consult_reflex','codex_task_authoring_reflex','web_source_search_reflex','source_ingestion_reflex')
foreach($r in $reflexes){ if($text -notlike "*$r*"){ Add-Err "reflex_missing:$r" } }
if($text -notlike '*.runtime/codex_drafts/callable_innate_reflex_kernel_v1_hung_20260717_161706*'){ Add-Err 'draft_reference_missing' }
$status=if($errors.Count -eq 0){'PASS_CALLABLE_INNATE_REFLEX_CODEX_TASK_SLICE_A_V1'}else{'FAIL_CALLABLE_INNATE_REFLEX_CODEX_TASK_SLICE_A_V1'}
$proof=[ordered]@{
 schema='callable_innate_reflex_codex_task_slice_a_v1_validation'
 status=$status
 checked_at=(Get-Date).ToUniversalTime().ToString('o')
 task=$task
 reflex_count=$reflexes.Count
 errors=@($errors)
 boundary=[ordered]@{ task_only=$true; codex_not_launched_by_validator=$true; implementation_not_done=$true; runner_integration_out_of_scope=$true; body_inspection_invoked=$false; active_memory_mutated=$false }
}
WJson 'tests/self_development/CALLABLE_INNATE_REFLEX_CODEX_TASK_SLICE_A_V1_PROOF.json' $proof
Write-Host "STATUS=$status"
if($errors.Count -gt 0){ foreach($e in $errors){Write-Host "ERROR=$e"}; exit 1 }
