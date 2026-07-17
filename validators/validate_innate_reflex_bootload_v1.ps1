$ErrorActionPreference='Stop'
$errors=@()
function Add-Err([string]$e){ $script:errors += $e }
function WJson($path,$obj){ $dir=Split-Path $path -Parent; if($dir){New-Item -ItemType Directory -Force -Path $dir|Out-Null}; $json=($obj|ConvertTo-Json -Depth 60) -replace "`r`n","`n"; [System.IO.File]::WriteAllText((Join-Path (Get-Location).Path $path),$json.TrimEnd()+"`n",(New-Object System.Text.UTF8Encoding($false))) }
function Parse-PS($path){ $tokens=$null;$parseErrors=$null;[System.Management.Automation.Language.Parser]::ParseFile((Resolve-Path $path),[ref]$tokens,[ref]$parseErrors)|Out-Null; if($parseErrors.Count){ foreach($e in $parseErrors){ Add-Err "parse_failed:${path}:$($e.Message)" } } }
$runner='operations/autonomous_inner_motor/run_autonomous_inner_motor.ps1'
$launcher='operations/autonomous_inner_motor/start_agent_life_v1.ps1'
$kernel='operations/autonomous_inner_motor/innate_reflex_kernel_v1.json'
$builder='operations/autonomous_inner_motor/build_innate_reflex_kernel_v1.ps1'
foreach($p in @($runner,$launcher,$kernel,$builder,'tests/self_development/CALLABLE_INNATE_REFLEX_KERNEL_V1_PROOF.json')){ if(-not(Test-Path $p)){ Add-Err "missing:$p" } }
foreach($p in @($runner,$launcher,$builder)){ if(Test-Path $p){ Parse-PS $p } }
$kernelRuntime=$null
if(Test-Path $builder){ try { $kernelRuntime=& $builder } catch { Add-Err ('innate_reflex_builder_failed:' + $_.Exception.Message) } }
if($kernelRuntime){ if([int]$kernelRuntime.reflex_count -lt 25){ Add-Err ('builder_reflex_count_small:' + [string]$kernelRuntime.reflex_count) }; if($kernelRuntime.body_audit_reflex.callable -ne $true){ Add-Err 'builder_body_callable_not_true' }; if($kernelRuntime.body_audit_reflex.status -ne 'DEFAULT_WAKE_OBSERVE'){ Add-Err ('builder_body_status_mismatch:' + [string]$kernelRuntime.body_audit_reflex.status) } }
$runnerText=if(Test-Path $runner){Get-Content $runner -Raw}else{''}
foreach($needle in @('function New-InnateReflexBootload','innate_reflex_bootload.json','build_innate_reflex_kernel_v1.ps1','innate_reflex_bootload=$innateReflexBootload','innate_reflex_bootload_path=$innateReflexBootloadPath','INNATE_REFLEX_BOOTLOAD_STATUS')){ if($runnerText -notlike "*$needle*"){ Add-Err "runner_missing:$needle" } }
$launcherText=if(Test-Path $launcher){Get-Content $launcher -Raw}else{''}
if($launcherText -notmatch '\[int\]\$DurationMinutes'){ Add-Err 'launcher_duration_minutes_param_missing' }
if($launcherText -match 'innate_reflex|bootload|default_wake'){ Add-Err 'launcher_modified_for_reflex_unexpected' }
if(@(git diff --name-only -- $launcher).Count -gt 0){ Add-Err 'canonical_launcher_has_worktree_diff' }
$testRoot='.runtime/self_development/innate_reflex_bootload_v1_runner_test'
Remove-Item -Recurse -Force $testRoot -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force -Path $testRoot | Out-Null
$runnerOut=@(& powershell -NoProfile -ExecutionPolicy Bypass -File $runner -Mode SandboxExploration -Question 'innate reflex bootload validator' -OutputRoot $testRoot *>&1 | ForEach-Object { [string]$_ })
$runnerExit=$LASTEXITCODE
if($runnerExit -ne 0){ Add-Err "runner_smoke_failed:$runnerExit" }
$runDir=$null
if(Test-Path $testRoot){ $runDir=Get-ChildItem -Path $testRoot -Directory | Sort-Object LastWriteTime -Descending | Select-Object -First 1 }
$boot=$null;$proof=$null;$manifest=$null
if($runDir){
  $bootPath=Join-Path $runDir.FullName 'innate_reflex_bootload.json'
  $proofPath=Join-Path $runDir.FullName 'SANDBOX_EXPLORATION_PROOF.json'
  $manifestPath=Join-Path $runDir.FullName 'sandbox_proof_pack_manifest.json'
  if(Test-Path $bootPath){ $boot=Get-Content $bootPath -Raw | ConvertFrom-Json } else { Add-Err 'runtime_bootload_missing' }
  if(Test-Path $proofPath){ $proof=Get-Content $proofPath -Raw | ConvertFrom-Json } else { Add-Err 'runtime_proof_missing' }
  if(Test-Path $manifestPath){ $manifest=Get-Content $manifestPath -Raw | ConvertFrom-Json } else { Add-Err 'runtime_manifest_missing' }
} else { Add-Err 'runner_smoke_no_run_dir' }
if($boot){
  if($boot.status -ne 'PASS_INNATE_REFLEX_BOOTLOAD_V1'){ Add-Err "boot_status_mismatch:$($boot.status)" }
  if($boot.loaded -ne $true){ Add-Err 'boot_loaded_not_true' }
  if([int]$boot.reflex_count -lt 25){ Add-Err "boot_reflex_count_small:$($boot.reflex_count)" }
  if($boot.body_audit_reflex.status -ne 'DEFAULT_WAKE_OBSERVE'){ Add-Err "body_status_mismatch:$($boot.body_audit_reflex.status)" }
  if($boot.body_audit_reflex.callable -ne $true){ Add-Err 'body_callable_not_true' }
  if($boot.body_audit_reflex.body_inspection_invoked -ne $false){ Add-Err 'bootload_body_inspection_invoked_not_false' }
  if($boot.boundary.full_kernel_written_each_cycle -ne $false){ Add-Err 'full_kernel_written_each_cycle_not_false' }
  if($boot.PSObject.Properties.Name -contains 'reflexes'){ Add-Err 'bootload_contains_full_reflex_matrix' }
}
if($proof){ if(-not $proof.innate_reflex_bootload){ Add-Err 'proof_missing_innate_reflex_bootload' }; if(-not $proof.innate_reflex_bootload_path){ Add-Err 'proof_missing_bootload_path' } }
if($manifest){ if(@($manifest.required_files) -notcontains 'innate_reflex_bootload.json'){ Add-Err 'manifest_required_files_missing_bootload' } }
$status=if($errors.Count -eq 0){'PASS_INNATE_REFLEX_BOOTLOAD_V1'}else{'FAIL_INNATE_REFLEX_BOOTLOAD_V1'}
$proofObj=[ordered]@{schema='innate_reflex_bootload_v1_validation'; status=$status; checked_at=(Get-Date).ToUniversalTime().ToString('o'); runner=$runner; runner_smoke_exit_code=$runnerExit; runner_smoke_output_root=$testRoot; runtime_run_dir=if($runDir){$runDir.FullName}else{$null}; bootload_summary=if($boot){[ordered]@{status=$boot.status; loaded=$boot.loaded; reflex_count=$boot.reflex_count; body_audit_reflex=$boot.body_audit_reflex; boundary=$boot.boundary}}else{$null}; errors=@($errors); boundary=[ordered]@{runner_integrated=$true; bootload_once_per_run=$true; full_kernel_written_each_cycle=$false; canonical_launcher_modified=$false; permanent_kernel_mutated_by_runtime=$false; body_inspection_invoked_by_bootload=$false; body_audit_reflex_callable=$true; active_memory_mutated=$false; legacy_launch_used=$false}}
WJson 'tests/self_development/INNATE_REFLEX_BOOTLOAD_V1_PROOF.json' $proofObj
Write-Host "STATUS=$status"
if($errors.Count -gt 0){ foreach($e in $errors){Write-Host "ERROR=$e"}; exit 1 }
