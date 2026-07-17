$ErrorActionPreference='Stop'
$errors=@()
function Add-Err([string]$e){ $script:errors += $e }
function WJson($path,$obj){ $dir=Split-Path $path -Parent; if($dir){New-Item -ItemType Directory -Force -Path $dir|Out-Null}; $json=($obj|ConvertTo-Json -Depth 80) -replace "`r`n","`n"; [System.IO.File]::WriteAllText((Join-Path (Get-Location).Path $path),$json.TrimEnd()+"`n",(New-Object System.Text.UTF8Encoding($false))) }
function Parse-PS($path){ $tokens=$null;$parseErrors=$null;[System.Management.Automation.Language.Parser]::ParseFile((Resolve-Path $path),[ref]$tokens,[ref]$parseErrors)|Out-Null; if($parseErrors.Count){ foreach($e in $parseErrors){ Add-Err "parse_failed:${path}:$($e.Message)" } } }
$manifestPath='operations/autonomous_inner_motor/innate_reflex_kernel_v1.json'
$builder='operations/autonomous_inner_motor/build_innate_reflex_kernel_v1.ps1'
foreach($p in @($manifestPath,$builder)){ if(-not(Test-Path $p)){ Add-Err "missing:$p" } }
if(Test-Path $builder){ Parse-PS $builder }
$manifest=$null; $body=$null
if(Test-Path $manifestPath){ $manifest=Get-Content $manifestPath -Raw | ConvertFrom-Json; $body=@($manifest.reflexes | Where-Object {$_.reflex_id -eq 'body_audit_reflex'} | Select-Object -First 1) }
$required=@('body_audit_reflex','organ_audit_reflex','full_body_map_audit_reflex','repo_reality_reflex','process_scan_reflex','runtime_pressure_reflex','preflight_reflex','validator_run_reflex','proof_pack_reflex','rollback_reflex','quarantine_reflex','stop_or_freeze_reflex','memory_queue_reflex','active_memory_read_reflex','memory_digest_reflex','handoff_write_reflex','self_notebook_update_reflex','directory_create_reflex','file_normalize_reflex','archive_backup_reflex','artifact_convert_reflex','codex_consult_reflex','codex_task_authoring_reflex','web_source_search_reflex','source_ingestion_reflex')
if($manifest){ $ids=@($manifest.reflexes | ForEach-Object {$_.reflex_id}); foreach($id in $required){ if($ids -notcontains $id){ Add-Err "missing_reflex:$id" } }; if(@($manifest.reflexes).Count -lt 25){ Add-Err "reflex_count_small:$(@($manifest.reflexes).Count)" } }
if($body){
  if($body.built_in -ne $true){ Add-Err 'body_built_in_not_true' }
  if($body.callable -ne $true){ Add-Err 'body_callable_not_true' }
  if($body.status -ne 'DEFAULT_WAKE_OBSERVE'){ Add-Err "body_status_not_DEFAULT_WAKE_OBSERVE:$($body.status)" }
  if($body.organ_id -ne 'BODY_SELF_INSPECTION_CIRCUIT_V1'){ Add-Err "body_organ_mismatch:$($body.organ_id)" }
  if($body.can_hear_body -ne $true){ Add-Err 'body_can_hear_not_true' }
  if($body.wake_default -ne $true){ Add-Err 'body_wake_default_not_true' }
  if($body.requires_owner_permission -ne $false){ Add-Err 'body_requires_owner_permission_not_false' }
  if($body.trigger_required -ne $false){ Add-Err 'body_trigger_required_not_false' }
} else { Add-Err 'body_audit_reflex_missing' }
if($manifest){ foreach($r in @($manifest.reflexes | Where-Object {$_.reflex_id -ne 'body_audit_reflex'})){ if($r.callable -ne $false){ Add-Err "reserved_callable_not_false:$($r.reflex_id)" }; if($r.status -ne 'RESERVED_NOT_BUILT'){ Add-Err "reserved_status_mismatch:$($r.reflex_id):$($r.status)" }; if($r.maturity -ne 'RESERVED_SLOT'){ Add-Err "reserved_maturity_mismatch:$($r.reflex_id):$($r.maturity)" } } }
$temp='.runtime/self_development/innate_reflex_kernel_v1_test/innate_reflex_kernel.json'
Remove-Item -Recurse -Force (Split-Path $temp -Parent) -ErrorAction SilentlyContinue
$runtime=$null
if(Test-Path $builder){ try { $runtime=& $builder -OutputPath $temp } catch { Add-Err ('builder_failed:' + $_.Exception.Message) } }
if(-not(Test-Path $temp)){ Add-Err 'builder_output_missing' }
if($runtime){ if($runtime.status -ne 'PASS_CALLABLE_INNATE_REFLEX_KERNEL_V1_SLICE_A'){ Add-Err "runtime_status_mismatch:$($runtime.status)" }; if([int]$runtime.reflex_count -lt 25){ Add-Err "runtime_reflex_count_small:$($runtime.reflex_count)" }; if($runtime.body_audit_reflex.callable -ne $true){ Add-Err 'runtime_body_callable_not_true' }; if($runtime.body_audit_reflex.status -ne 'DEFAULT_WAKE_OBSERVE'){ Add-Err "runtime_body_status_mismatch:$($runtime.body_audit_reflex.status)" }; if($runtime.body_audit_reflex.body_inspection_invoked -ne $false){ Add-Err 'runtime_body_inspection_invoked_not_false' }; if($runtime.wake_default_count -lt 1){ Add-Err 'runtime_wake_default_count_small' }; if($runtime.reserved_count -lt 24){ Add-Err "runtime_reserved_count_small:$($runtime.reserved_count)" } }
$status=if($errors.Count -eq 0){'PASS_CALLABLE_INNATE_REFLEX_KERNEL_V1_SLICE_A'}else{'FAIL_CALLABLE_INNATE_REFLEX_KERNEL_V1_SLICE_A'}
$proof=[ordered]@{schema='callable_innate_reflex_kernel_v1_validation'; status=$status; checked_at=(Get-Date).ToUniversalTime().ToString('o'); manifest=$manifestPath; builder=$builder; reflex_count=if($manifest){@($manifest.reflexes).Count}else{0}; body_audit_reflex=if($body){$body}else{$null}; runtime_summary=if($runtime){[ordered]@{status=$runtime.status; reflex_count=$runtime.reflex_count; callable_count=$runtime.callable_count; wake_default_count=$runtime.wake_default_count; reserved_count=$runtime.reserved_count; body_audit_reflex=$runtime.body_audit_reflex}}else{$null}; errors=@($errors); boundary=[ordered]@{manifest_only=$true; body_audit_reflex_wake_default=$true; body_inspection_invoked=$false; active_memory_mutated=$false; live_process_touched=$false; repair_executed=$false; legacy_launch_used=$false}}
WJson 'tests/self_development/CALLABLE_INNATE_REFLEX_KERNEL_V1_PROOF.json' $proof
Write-Host "STATUS=$status"
if($errors.Count -gt 0){ foreach($e in $errors){Write-Host "ERROR=$e"}; exit 1 }
