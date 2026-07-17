$ErrorActionPreference='Stop'
$errors=@()
function Add-Err([string]$e){ $script:errors += $e }
function WJson($path,$obj){ $dir=Split-Path $path -Parent; if($dir){New-Item -ItemType Directory -Force -Path $dir|Out-Null}; $json=($obj|ConvertTo-Json -Depth 100) -replace "`r`n","`n"; [System.IO.File]::WriteAllText((Join-Path (Get-Location).Path $path),$json.TrimEnd()+"`n",(New-Object System.Text.UTF8Encoding($false))) }
$script='operations/autonomous_inner_motor/cleanup_compact_memory_intake_checkpoints_v1.ps1'
$proofPath='tests/self_development/COMPACT_MEMORY_INTAKE_CHECKPOINT_RETENTION_V1_PROOF.json'
foreach($p in @($script,$proofPath)){ if(-not(Test-Path $p)){ Add-Err "missing:$p" } }
if(Test-Path $script){ $tokens=$null;$parseErrors=$null;[System.Management.Automation.Language.Parser]::ParseFile((Resolve-Path $script),[ref]$tokens,[ref]$parseErrors)|Out-Null; if($parseErrors.Count){ foreach($e in $parseErrors){ Add-Err "script_parse_failed:$($e.Message)" } } }
$p=$null
if(Test-Path $proofPath){ $p=Get-Content $proofPath -Raw | ConvertFrom-Json }
if($p){
  if($p.status -ne 'PASS_COMPACT_MEMORY_INTAKE_CHECKPOINT_RETENTION_V1'){ Add-Err "proof_status_mismatch:$($p.status)" }
  if([int]$p.keep_latest -ne 3){ Add-Err "keep_latest_not_3:$($p.keep_latest)" }
  if([int]$p.deleted_count -lt 1){ Add-Err 'deleted_count_zero' }
  if([double]$p.reclaimed_mb -lt 1){ Add-Err 'reclaimed_mb_too_small' }
  if([double]$p.before.intake.mb -le [double]$p.after.intake.mb){ Add-Err 'intake_not_smaller_after' }
  if([int]@($p.kept_checkpoints).Count -ne 3){ Add-Err "kept_checkpoints_not_3:$(@($p.kept_checkpoints).Count)" }
  if($p.boundary.process_count -ne 0){ Add-Err 'process_count_not_zero_in_proof' }
  if($p.boundary.active_memory_deleted -ne $false){ Add-Err 'active_memory_deleted_not_false' }
  if($p.boundary.active_memory_mutated -ne $false){ Add-Err 'active_memory_mutated_not_false' }
  if($p.boundary.queue_deleted -ne $false){ Add-Err 'queue_deleted_not_false' }
  if($p.boundary.latest_checkpoints_kept -ne $true){ Add-Err 'latest_checkpoints_kept_not_true' }
  if($p.boundary.older_checkpoints_deleted -ne $true){ Add-Err 'older_checkpoints_deleted_not_true' }
  if($p.boundary.repo_tracked_files_deleted -ne $false){ Add-Err 'repo_tracked_files_deleted_not_false' }
}
$activeRoot='.runtime/active_compact_semantic_memory_v1'
$queueRoot='.runtime/compact_memory_intake_v1/queue'
$checkpointRoot='.runtime/compact_memory_intake_v1/checkpoints'
if(-not(Test-Path $activeRoot)){ Add-Err 'active_memory_root_missing_after_cleanup' }
if(-not(Test-Path $queueRoot)){ Add-Err 'queue_root_missing_after_cleanup' }
$checkpointDirs=@(); if(Test-Path $checkpointRoot){ $checkpointDirs=@(Get-ChildItem $checkpointRoot -Directory -Force) } else { Add-Err 'checkpoint_root_missing_after_cleanup' }
if(@($checkpointDirs).Count -ne 3){ Add-Err "checkpoint_dir_count_after_not_3:$(@($checkpointDirs).Count)" }
$procs=@(Get-CimInstance Win32_Process | Where-Object { $_.CommandLine -and $_.CommandLine -notmatch '\s-Command\s' -and $_.CommandLine -match 'run_autonomous_inner_motor.ps1|start_agent_life_v1.ps1|invoke_body_self_inspection_circuit_v1.ps1|codex exec|node.*codex|school|continuous' })
if($procs.Count -ne 0){ Add-Err "process_count_not_zero:$($procs.Count)" }
$status=if($errors.Count -eq 0){'PASS_COMPACT_MEMORY_INTAKE_CHECKPOINT_RETENTION_V1'}else{'FAIL_COMPACT_MEMORY_INTAKE_CHECKPOINT_RETENTION_V1'}
$validation=[ordered]@{
  schema='compact_memory_intake_checkpoint_retention_v1_validation'
  status=$status
  checked_at=(Get-Date).ToUniversalTime().ToString('o')
  script=$script
  proof=$proofPath
  checkpoint_dir_count_after=@($checkpointDirs).Count
  process_count=$procs.Count
  errors=@($errors)
  boundary=[ordered]@{ validation_only=$true; active_memory_deleted=$false; queue_deleted=$false; repo_tracked_files_deleted=$false; codex_launched=$false; web_launched=$false; school_launched=$false }
}
WJson 'tests/self_development/COMPACT_MEMORY_INTAKE_CHECKPOINT_RETENTION_V1_VALIDATION.json' $validation
Write-Host "STATUS=$status"
if($errors.Count -gt 0){ foreach($e in $errors){Write-Host "ERROR=$e"}; exit 1 }
