$ErrorActionPreference='Stop'
$errors=@()
function Add-Err([string]$e){ $script:errors += $e }
function WJson($path,$obj){ $dir=Split-Path $path -Parent; if($dir){New-Item -ItemType Directory -Force -Path $dir|Out-Null}; $json=($obj|ConvertTo-Json -Depth 100) -replace "`r`n","`n"; [System.IO.File]::WriteAllText((Join-Path (Get-Location).Path $path),$json.TrimEnd()+"`n",(New-Object System.Text.UTF8Encoding($false))) }
function Parse-PS($path){ $tokens=$null;$parseErrors=$null;[System.Management.Automation.Language.Parser]::ParseFile((Resolve-Path $path),[ref]$tokens,[ref]$parseErrors)|Out-Null; if($parseErrors.Count){ foreach($e in $parseErrors){ Add-Err "parse_failed:${path}:$($e.Message)" } } }
$runner='operations/autonomous_inner_motor/run_autonomous_inner_motor.ps1'
$kernel='operations/autonomous_inner_motor/innate_reflex_kernel_v1.json'
$builder='operations/autonomous_inner_motor/build_innate_reflex_kernel_v1.ps1'
foreach($p in @($runner,$kernel,$builder,'validators/validate_body_self_inspection_circuit_v1.ps1','operations/body_self_inspection/invoke_body_self_inspection_circuit_v1.ps1')){ if(-not(Test-Path $p)){ Add-Err "missing:$p" } }
foreach($p in @($runner,$builder,'operations/body_self_inspection/invoke_body_self_inspection_circuit_v1.ps1')){ if(Test-Path $p){ Parse-PS $p } }
$body=$null
if(Test-Path $kernel){ $manifest=Get-Content $kernel -Raw | ConvertFrom-Json; $body=@($manifest.reflexes | Where-Object { $_.reflex_id -eq 'body_audit_reflex' } | Select-Object -First 1) }
if($null -eq $body){ Add-Err 'body_audit_reflex_missing' } else { if($body.status -ne 'DEFAULT_WAKE_OBSERVE'){ Add-Err "body_status_not_DEFAULT_WAKE_OBSERVE:$($body.status)" }; if($body.callable -ne $true){ Add-Err 'body_callable_not_true' }; if($body.wake_default -ne $true){ Add-Err 'body_wake_default_not_true' }; if($body.requires_owner_permission -ne $false){ Add-Err 'body_requires_owner_permission_not_false' }; if($body.trigger_required -ne $false){ Add-Err 'body_trigger_required_not_false' } }
$runnerText=if(Test-Path $runner){Get-Content $runner -Raw}else{''}
foreach($needle in @('function Invoke-DefaultWakeReflexes','default_wake_reflexes.json','invoke_body_self_inspection_circuit_v1.ps1','default_wake_reflexes=$defaultWakeReflexes','DEFAULT_WAKE_REFLEXES_STATUS')){ if($runnerText -notlike "*$needle*"){ Add-Err "runner_missing:$needle" } }
$testRoot='.runtime/self_development/default_wake_reflexes_v1_runner_test'
Remove-Item -Recurse -Force $testRoot -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force -Path $testRoot | Out-Null
$runnerOut=@(& powershell -NoProfile -ExecutionPolicy Bypass -File $runner -Mode SandboxExploration -Question 'default wake reflex validator' -OutputRoot $testRoot *>&1 | ForEach-Object { [string]$_ })
$runnerExit=$LASTEXITCODE
if($runnerExit -ne 0){ Add-Err "runner_smoke_failed:$runnerExit" }
$runDir=$null
if(Test-Path $testRoot){ $runDir=Get-ChildItem -Path $testRoot -Directory | Sort-Object LastWriteTime -Descending | Select-Object -First 1 }
$wake=$null;$proof=$null;$manifestJson=$null
if($runDir){ $wakePath=Join-Path $runDir.FullName 'default_wake_reflexes.json'; $proofPath=Join-Path $runDir.FullName 'SANDBOX_EXPLORATION_PROOF.json'; $manifestPath=Join-Path $runDir.FullName 'sandbox_proof_pack_manifest.json'; if(Test-Path $wakePath){ $wake=Get-Content $wakePath -Raw | ConvertFrom-Json } else { Add-Err 'runtime_default_wake_reflexes_missing' }; if(Test-Path $proofPath){ $proof=Get-Content $proofPath -Raw | ConvertFrom-Json } else { Add-Err 'runtime_proof_missing' }; if(Test-Path $manifestPath){ $manifestJson=Get-Content $manifestPath -Raw | ConvertFrom-Json } else { Add-Err 'runtime_manifest_missing' } } else { Add-Err 'runner_smoke_no_run_dir' }
if($wake){ if($wake.status -ne 'PASS_DEFAULT_WAKE_REFLEXES_V1'){ Add-Err "wake_status_mismatch:$($wake.status)" }; if(@($wake.default_reflexes_invoked) -notcontains 'body_audit_reflex'){ Add-Err 'body_audit_not_invoked_as_default' }; if($wake.body_audit_reflex.requires_owner_permission -ne $false){ Add-Err 'wake_body_requires_owner_permission_not_false' }; if($wake.body_audit_reflex.trigger_required -ne $false){ Add-Err 'wake_body_trigger_required_not_false' }; if($wake.body_audit_reflex.observe_only -ne $true){ Add-Err 'wake_body_observe_only_not_true' }; if($wake.body_audit_reflex.body_inspection_invoked -ne $true){ Add-Err 'wake_body_inspection_not_invoked' }; if($wake.boundary.body_repair_executed -ne $false){ Add-Err 'wake_repair_executed_not_false' }; if($wake.boundary.repo_mutated -ne $false){ Add-Err 'wake_repo_mutated_not_false' }; if($wake.boundary.active_memory_mutated -ne $false){ Add-Err 'wake_active_memory_mutated_not_false' }; if($wake.boundary.live_process_touched -ne $false){ Add-Err 'wake_live_process_touched_not_false' }; if($wake.boundary.codex_launched -ne $false){ Add-Err 'wake_codex_launched_not_false' }; foreach($p in @($wake.body_audit_reflex.signal_path,$wake.body_audit_reflex.parent_packet_path,$wake.body_audit_reflex.circuit_proof_path)){ if(-not(Test-Path -LiteralPath $p)){ Add-Err "wake_body_output_missing:$p" } } }
if($proof){ if(-not $proof.default_wake_reflexes){ Add-Err 'proof_missing_default_wake_reflexes' }; if(-not $proof.default_wake_reflexes_path){ Add-Err 'proof_missing_default_wake_reflexes_path' } }
if($manifestJson){ if(@($manifestJson.required_files) -notcontains 'default_wake_reflexes.json'){ Add-Err 'manifest_required_missing_default_wake' } }
$status=if($errors.Count -eq 0){'PASS_DEFAULT_WAKE_REFLEXES_V1'}else{'FAIL_DEFAULT_WAKE_REFLEXES_V1'}
$proofObj=[ordered]@{schema='default_wake_reflexes_v1_validation'; status=$status; checked_at=(Get-Date).ToUniversalTime().ToString('o'); runner=$runner; validator='validators/validate_default_wake_reflexes_v1.ps1'; runner_smoke_exit_code=$runnerExit; runner_smoke_output_root=$testRoot; runtime_run_dir=if($runDir){$runDir.FullName}else{$null}; wake_summary=if($wake){[ordered]@{status=$wake.status; body_audit_reflex=$wake.body_audit_reflex; boundary=$wake.boundary}}else{$null}; errors=@($errors); boundary=[ordered]@{wake_default_reflexes_integrated=$true; body_audit_reflex_wake_default=$true; requires_owner_permission=$false; trigger_required=$false; observe_only=$true; body_inspection_invoked=$true; repair_executed=$false; active_memory_mutated=$false; live_process_touched=$false; codex_launched=$false; web_launched=$false}}
WJson 'tests/self_development/DEFAULT_WAKE_REFLEXES_V1_PROOF.json' $proofObj
Write-Host "STATUS=$status"
if($errors.Count -gt 0){ foreach($e in $errors){Write-Host "ERROR=$e"}; exit 1 }
