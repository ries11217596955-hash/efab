$ErrorActionPreference='Stop'
$errors=@()
function Add-Err([string]$e){ $script:errors += $e }
function WJson($path,$obj){ $dir=Split-Path $path -Parent; if($dir){New-Item -ItemType Directory -Force -Path $dir|Out-Null}; $json=($obj|ConvertTo-Json -Depth 100) -replace "`r`n","`n"; [System.IO.File]::WriteAllText((Join-Path (Get-Location).Path $path),$json.TrimEnd()+"`n",(New-Object System.Text.UTF8Encoding($false))) }
function Parse-PS($path){ $tokens=$null;$parseErrors=$null;[System.Management.Automation.Language.Parser]::ParseFile((Resolve-Path $path),[ref]$tokens,[ref]$parseErrors)|Out-Null; if($parseErrors.Count){ foreach($e in $parseErrors){ Add-Err "parse_failed:${path}:$($e.Message)" } } }
$runner='operations/autonomous_inner_motor/run_autonomous_inner_motor.ps1'
foreach($p in @($runner,'operations/body_self_inspection/invoke_body_self_inspection_circuit_v1.ps1')){ if(-not(Test-Path $p)){ Add-Err "missing:$p" } }
foreach($p in @($runner,'operations/body_self_inspection/invoke_body_self_inspection_circuit_v1.ps1')){ if(Test-Path $p){ Parse-PS $p } }
$runnerText=if(Test-Path $runner){Get-Content $runner -Raw}else{''}
foreach($needle in @('body_wake_raw_retention_v1','body_wake_raw_retention=$retentionPolicy','raw_debug_retained=$false','compact_outputs_retained=$true','Remove-Item -LiteralPath $f.FullName')){ if($runnerText -notlike "*$needle*"){ Add-Err "runner_missing:$needle" } }
$testRoot='.runtime/self_development/body_wake_raw_retention_v1_runner_test'
Remove-Item -Recurse -Force $testRoot -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force -Path $testRoot | Out-Null
$runnerOut=@(& powershell -NoProfile -ExecutionPolicy Bypass -File $runner -Mode SandboxExploration -Question 'body wake raw retention validator' -OutputRoot $testRoot *>&1 | ForEach-Object { [string]$_ })
$runnerExit=$LASTEXITCODE
if($runnerExit -ne 0){ Add-Err "runner_smoke_failed:$runnerExit" }
$runDir=$null
if(Test-Path $testRoot){ $runDir=Get-ChildItem -Path $testRoot -Directory | Sort-Object LastWriteTime -Descending | Select-Object -First 1 }
$wake=$null;$bodyDir=$null;$files=@()
if($runDir){
  $wakePath=Join-Path $runDir.FullName 'default_wake_reflexes.json'
  $bodyDir=Join-Path $runDir.FullName 'wake_body_audit'
  if(Test-Path $wakePath){ $wake=Get-Content $wakePath -Raw | ConvertFrom-Json } else { Add-Err 'default_wake_reflexes_missing' }
  if(Test-Path $bodyDir){ $files=@(Get-ChildItem -LiteralPath $bodyDir -File -Force | Select-Object Name,Length,FullName) } else { Add-Err 'wake_body_audit_dir_missing' }
} else { Add-Err 'runner_smoke_no_run_dir' }
$keep=@('body_self_inspection_signal.json','body_self_inspection_parent_packet.json','BODY_SELF_INSPECTION_CIRCUIT_PROOF.json')
$rawNames=@('repo_inventory.json','organ_candidates.json','organ_similarity_index.json','passport_audit.json','signal_readiness_audit.json','body_reconciliation.json','body_pain_register.json','repair_draft_board.json','next_logic_queue.json','body_map_read.json','capability_map_read.json')
if($wake){
  if($wake.status -ne 'PASS_DEFAULT_WAKE_REFLEXES_V2'){ Add-Err "wake_status_mismatch:$($wake.status)" }
  if(-not $wake.body_wake_raw_retention){ Add-Err 'retention_policy_missing_from_wake' } else {
    if($wake.body_wake_raw_retention.status -ne 'PASS_BODY_WAKE_RAW_RETENTION_V1'){ Add-Err "retention_status_mismatch:$($wake.body_wake_raw_retention.status)" }
    if($wake.body_wake_raw_retention.raw_debug_retained -ne $false){ Add-Err 'raw_debug_retained_not_false' }
    if($wake.body_wake_raw_retention.compact_outputs_retained -ne $true){ Add-Err 'compact_outputs_retained_not_true' }
    if([int]$wake.body_wake_raw_retention.removed_count -lt 1){ Add-Err 'retention_removed_count_zero' }
    if([int64]$wake.body_wake_raw_retention.removed_bytes -lt 1){ Add-Err 'retention_removed_bytes_zero' }
  }
  if($wake.boundary.raw_debug_retained -ne $false){ Add-Err 'wake_boundary_raw_debug_retained_not_false' }
  if($wake.boundary.compact_outputs_retained -ne $true){ Add-Err 'wake_boundary_compact_outputs_retained_not_true' }
  if($wake.boundary.active_memory_mutated -ne $false){ Add-Err 'wake_active_memory_mutated_not_false' }
  if($wake.boundary.repo_mutated -ne $false){ Add-Err 'wake_repo_mutated_not_false' }
}
if($files.Count -gt 0){
  foreach($k in $keep){ if(@($files | Where-Object { $_.Name -eq $k }).Count -ne 1){ Add-Err "compact_keep_missing:$k" } }
  foreach($f in $files){ if($keep -notcontains $f.Name){ Add-Err "unexpected_body_wake_file_retained:$($f.Name)" } }
  foreach($r in $rawNames){ if(@($files | Where-Object { $_.Name -eq $r }).Count -gt 0){ Add-Err "raw_file_still_retained:$r" } }
}
$status=if($errors.Count -eq 0){'PASS_BODY_WAKE_RAW_RETENTION_V1'}else{'FAIL_BODY_WAKE_RAW_RETENTION_V1'}
$proofObj=[ordered]@{
  schema='body_wake_raw_retention_v1_validation'
  status=$status
  checked_at=(Get-Date).ToUniversalTime().ToString('o')
  runner=$runner
  validator='validators/validate_body_wake_raw_retention_v1.ps1'
  runner_smoke_exit_code=$runnerExit
  runner_smoke_output_root=$testRoot
  runtime_run_dir=if($runDir){$runDir.FullName}else{$null}
  retained_files=@($files | ForEach-Object { [ordered]@{name=$_.Name; bytes=[int64]$_.Length; path=$_.FullName} })
  retention_summary=if($wake -and $wake.body_wake_raw_retention){$wake.body_wake_raw_retention}else{$null}
  errors=@($errors)
  boundary=[ordered]@{ compact_outputs_retained=$true; raw_debug_retained=$false; raw_debug_deleted=$true; active_memory_mutated=$false; repo_mutated=$false; repair_executed=$false; tracked_repo_files_deleted=$false }
}
WJson 'tests/self_development/BODY_WAKE_RAW_RETENTION_V1_PROOF.json' $proofObj
Write-Host "STATUS=$status"
if($errors.Count -gt 0){ foreach($e in $errors){Write-Host "ERROR=$e"}; exit 1 }
