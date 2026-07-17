
$ErrorActionPreference='Stop'
$errors=@()
function Add-Err([string]$e){ $script:errors += $e }
function WJson($path,$obj){ $dir=Split-Path $path -Parent; if($dir){New-Item -ItemType Directory -Force -Path $dir|Out-Null}; $json=($obj|ConvertTo-Json -Depth 100) -replace "`r`n","`n"; [System.IO.File]::WriteAllText((Join-Path (Get-Location).Path $path),$json.TrimEnd()+"`n",(New-Object System.Text.UTF8Encoding($false))) }
function Parse-PS($path){ $tokens=$null;$parseErrors=$null;[System.Management.Automation.Language.Parser]::ParseFile((Resolve-Path $path),[ref]$tokens,[ref]$parseErrors)|Out-Null; if($parseErrors.Count){ foreach($e in $parseErrors){ Add-Err "parse_failed:${path}:$($e.Message)" } } }
$runner='operations/autonomous_inner_motor/run_autonomous_inner_motor.ps1'
$kernel='operations/autonomous_inner_motor/innate_reflex_kernel_v1.json'
$builder='operations/autonomous_inner_motor/build_innate_reflex_kernel_v1.ps1'
$wakeIds=@('body_audit_reflex','repo_reality_reflex','process_scan_reflex','runtime_pressure_reflex','active_memory_read_reflex')
foreach($p in @($runner,$kernel,$builder,'operations/body_self_inspection/invoke_body_self_inspection_circuit_v1.ps1')){ if(-not(Test-Path $p)){ Add-Err "missing:$p" } }
foreach($p in @($runner,$builder,'operations/body_self_inspection/invoke_body_self_inspection_circuit_v1.ps1')){ if(Test-Path $p){ Parse-PS $p } }
if(Test-Path $kernel){
  $manifest=Get-Content $kernel -Raw | ConvertFrom-Json
  foreach($id in $wakeIds){
    $r=@($manifest.reflexes | Where-Object { $_.reflex_id -eq $id } | Select-Object -First 1)
    if($null -eq $r){ Add-Err "wake_reflex_missing:$id"; continue }
    if($r.callable -ne $true){ Add-Err "wake_callable_not_true:$id" }
    if($r.wake_default -ne $true){ Add-Err "wake_default_not_true:$id" }
    if($r.requires_owner_permission -ne $false){ Add-Err "wake_requires_owner_permission:$id" }
    if($r.trigger_required -ne $false){ Add-Err "wake_trigger_required:$id" }
  }
}
$runnerText=if(Test-Path $runner){Get-Content $runner -Raw}else{''}
foreach($needle in @('PASS_DEFAULT_WAKE_REFLEXES_V2','repo_reality_reflex','process_scan_reflex','runtime_pressure_reflex','active_memory_read_reflex','git_write_performed=$false','process_killed=$false','runtime_cleanup_performed=$false','active_memory_written=$false')){ if($runnerText -notlike "*$needle*"){ Add-Err "runner_missing:$needle" } }
$testRoot='.runtime/self_development/default_wake_reflexes_v2_runner_test'
Remove-Item -Recurse -Force $testRoot -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force -Path $testRoot | Out-Null
$runnerOut=@(& powershell -NoProfile -ExecutionPolicy Bypass -File $runner -Mode SandboxExploration -Question 'default wake reflex v2 validator' -OutputRoot $testRoot *>&1 | ForEach-Object { [string]$_ })
$runnerExit=$LASTEXITCODE
if($runnerExit -ne 0){ Add-Err "runner_smoke_failed:$runnerExit" }
$runDir=$null
if(Test-Path $testRoot){ $runDir=Get-ChildItem -Path $testRoot -Directory | Sort-Object LastWriteTime -Descending | Select-Object -First 1 }
$wake=$null;$proof=$null;$manifestJson=$null
if($runDir){
  $wakePath=Join-Path $runDir.FullName 'default_wake_reflexes.json'
  $proofPath=Join-Path $runDir.FullName 'SANDBOX_EXPLORATION_PROOF.json'
  $manifestPath=Join-Path $runDir.FullName 'sandbox_proof_pack_manifest.json'
  if(Test-Path $wakePath){ $wake=Get-Content $wakePath -Raw | ConvertFrom-Json } else { Add-Err 'runtime_default_wake_reflexes_missing' }
  if(Test-Path $proofPath){ $proof=Get-Content $proofPath -Raw | ConvertFrom-Json } else { Add-Err 'runtime_proof_missing' }
  if(Test-Path $manifestPath){ $manifestJson=Get-Content $manifestPath -Raw | ConvertFrom-Json } else { Add-Err 'runtime_manifest_missing' }
} else { Add-Err 'runner_smoke_no_run_dir' }
if($wake){
  if($wake.status -ne 'PASS_DEFAULT_WAKE_REFLEXES_V2'){ Add-Err "wake_status_mismatch:$($wake.status)" }
  foreach($id in $wakeIds){ if(@($wake.default_reflexes_invoked) -notcontains $id){ Add-Err "wake_missing_invoked:$id" } }
  foreach($name in @('body_audit_reflex','repo_reality_reflex','process_scan_reflex','runtime_pressure_reflex','active_memory_read_reflex')){ if(-not $wake.$name){ Add-Err "wake_missing_object:$name" } }
  if($wake.repo_reality_reflex.boundary.git_mutated -ne $false){ Add-Err 'repo_git_mutated_not_false' }
  if($wake.process_scan_reflex.boundary.process_killed -ne $false){ Add-Err 'process_killed_not_false' }
  if($wake.runtime_pressure_reflex.boundary.cleanup_performed -ne $false){ Add-Err 'runtime_cleanup_not_false' }
  if($wake.active_memory_read_reflex.boundary.active_memory_written -ne $false){ Add-Err 'active_memory_written_not_false' }
  if($wake.boundary.body_repair_executed -ne $false){ Add-Err 'wake_repair_executed_not_false' }
  if($wake.boundary.repo_mutated -ne $false){ Add-Err 'wake_repo_mutated_not_false' }
  if($wake.boundary.git_write_performed -ne $false){ Add-Err 'wake_git_write_performed_not_false' }
  if($wake.boundary.process_killed -ne $false){ Add-Err 'wake_process_killed_not_false' }
  if($wake.boundary.runtime_cleanup_performed -ne $false){ Add-Err 'wake_runtime_cleanup_not_false' }
  if($wake.boundary.active_memory_written -ne $false){ Add-Err 'wake_active_memory_written_not_false' }
  if($wake.boundary.codex_launched -ne $false){ Add-Err 'wake_codex_launched_not_false' }
  if($wake.boundary.web_launched -ne $false){ Add-Err 'wake_web_launched_not_false' }
}
if($proof){ if(-not $proof.default_wake_reflexes){ Add-Err 'proof_missing_default_wake_reflexes' }; if($proof.default_wake_reflexes.status -ne 'PASS_DEFAULT_WAKE_REFLEXES_V2'){ Add-Err 'proof_wake_status_not_v2' } }
if($manifestJson){ if(@($manifestJson.required_files) -notcontains 'default_wake_reflexes.json'){ Add-Err 'manifest_required_missing_default_wake' } }
$status=if($errors.Count -eq 0){'PASS_DEFAULT_WAKE_REFLEXES_V2'}else{'FAIL_DEFAULT_WAKE_REFLEXES_V2'}
$proofObj=[ordered]@{schema='default_wake_reflexes_v2_validation'; status=$status; checked_at=(Get-Date).ToUniversalTime().ToString('o'); runner=$runner; validator='validators/validate_default_wake_reflexes_v1.ps1'; runner_smoke_exit_code=$runnerExit; runner_smoke_output_root=$testRoot; runtime_run_dir=if($runDir){$runDir.FullName}else{$null}; wake_summary=if($wake){[ordered]@{status=$wake.status; invoked=$wake.default_reflexes_invoked; repo_reality_reflex=$wake.repo_reality_reflex; process_scan_reflex=$wake.process_scan_reflex; runtime_pressure_reflex=$wake.runtime_pressure_reflex; active_memory_read_reflex=$wake.active_memory_read_reflex; body_audit_reflex=$wake.body_audit_reflex; boundary=$wake.boundary}}else{$null}; errors=@($errors); boundary=[ordered]@{wake_default_reflexes_integrated=$true; wake_default_count=5; requires_owner_permission=$false; trigger_required=$false; observe_only=$true; body_inspection_invoked=$true; repair_executed=$false; repo_mutated=$false; git_write_performed=$false; process_killed=$false; runtime_cleanup_performed=$false; active_memory_written=$false; active_memory_mutated=$false; live_process_touched=$false; codex_launched=$false; web_launched=$false}}
WJson 'tests/self_development/DEFAULT_WAKE_REFLEXES_V1_PROOF.json' $proofObj
Write-Host "STATUS=$status"
if($errors.Count -gt 0){ foreach($e in $errors){Write-Host "ERROR=$e"}; exit 1 }
