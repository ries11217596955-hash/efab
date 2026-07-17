$ErrorActionPreference='Stop'
$errors=@()
function Add-Err([string]$e){ $script:errors += $e }
function WJson($path,$obj){ $dir=Split-Path $path -Parent; if($dir){New-Item -ItemType Directory -Force -Path $dir|Out-Null}; $json=($obj|ConvertTo-Json -Depth 100) -replace "`r`n","`n"; [System.IO.File]::WriteAllText((Join-Path (Get-Location).Path $path),$json.TrimEnd()+"`n",(New-Object System.Text.UTF8Encoding($false))) }
function Parse-PS($path){ $tokens=$null;$parseErrors=$null;[System.Management.Automation.Language.Parser]::ParseFile((Resolve-Path $path),[ref]$tokens,[ref]$parseErrors)|Out-Null; if($parseErrors.Count){ foreach($e in $parseErrors){ Add-Err "parse_failed:${path}:$($e.Message)" } } }
$runner='operations/autonomous_inner_motor/run_autonomous_inner_motor.ps1'
$launcher='operations/autonomous_inner_motor/start_agent_life_v1.ps1'
foreach($p in @($runner,$launcher)){ if(-not(Test-Path $p)){ Add-Err "missing:$p" } else { Parse-PS $p } }
$runnerText=if(Test-Path $runner){Get-Content $runner -Raw}else{''}
foreach($needle in @('WakeContextPath','PASS_LIFE_WORKING_MEMORY_V1','reused_life_working_memory','created_life_working_memory','cycleWakeArtifactsWritten','life_working_memory=$lifeWorkingMemory')){ if($runnerText -notlike "*$needle*"){ Add-Err "runner_missing:$needle" } }
$launcherText=if(Test-Path $launcher){Get-Content $launcher -Raw}else{''}
foreach($needle in @('lifeWorkingMemoryPath','-WakeContextPath $lifeWorkingMemoryPath','life_working_memory_exists')){ if($launcherText -notlike "*$needle*"){ Add-Err "launcher_missing:$needle" } }
$testRoot='.runtime/self_development/life_working_memory_v1_runner_test'
Remove-Item -Recurse -Force $testRoot -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force -Path $testRoot | Out-Null
$ctx=Join-Path $testRoot 'life_working_memory_context.json'
$firstRoot=Join-Path $testRoot 'cycles_first'
$secondRoot=Join-Path $testRoot 'cycles_second'
New-Item -ItemType Directory -Force -Path $firstRoot,$secondRoot | Out-Null
$firstOut=@(& powershell -NoProfile -ExecutionPolicy Bypass -File $runner -Mode SandboxExploration -Question 'life working memory create validator' -OutputRoot $firstRoot -WakeContextPath $ctx *>&1 | ForEach-Object { [string]$_ })
$firstExit=$LASTEXITCODE
if($firstExit -ne 0){ Add-Err "first_runner_failed:$firstExit" }
$secondOut=@(& powershell -NoProfile -ExecutionPolicy Bypass -File $runner -Mode SandboxExploration -Question 'life working memory reuse validator' -OutputRoot $secondRoot -WakeContextPath $ctx *>&1 | ForEach-Object { [string]$_ })
$secondExit=$LASTEXITCODE
if($secondExit -ne 0){ Add-Err "second_runner_failed:$secondExit" }
$firstDir=if(Test-Path $firstRoot){Get-ChildItem $firstRoot -Directory | Sort-Object LastWriteTime -Descending | Select-Object -First 1}else{$null}
$secondDir=if(Test-Path $secondRoot){Get-ChildItem $secondRoot -Directory | Sort-Object LastWriteTime -Descending | Select-Object -First 1}else{$null}
$ctxObj=$null;$firstProof=$null;$secondProof=$null
if(Test-Path $ctx){ $ctxObj=Get-Content $ctx -Raw | ConvertFrom-Json } else { Add-Err 'life_working_memory_context_missing' }
if($firstDir){ $fp=Join-Path $firstDir.FullName 'SANDBOX_EXPLORATION_PROOF.json'; if(Test-Path $fp){$firstProof=Get-Content $fp -Raw|ConvertFrom-Json}else{Add-Err 'first_proof_missing'} } else { Add-Err 'first_run_dir_missing' }
if($secondDir){ $sp=Join-Path $secondDir.FullName 'SANDBOX_EXPLORATION_PROOF.json'; if(Test-Path $sp){$secondProof=Get-Content $sp -Raw|ConvertFrom-Json}else{Add-Err 'second_proof_missing'} } else { Add-Err 'second_run_dir_missing' }
if($ctxObj){
  if($ctxObj.status -ne 'PASS_LIFE_WORKING_MEMORY_V1'){ Add-Err "ctx_status_mismatch:$($ctxObj.status)" }
  if($ctxObj.default_wake_reflexes.status -ne 'PASS_DEFAULT_WAKE_REFLEXES_V2'){ Add-Err "ctx_wake_status_mismatch:$($ctxObj.default_wake_reflexes.status)" }
  if($ctxObj.boundary.active_memory_mutated -ne $false){ Add-Err 'ctx_active_memory_mutated_not_false' }
  if($ctxObj.boundary.repo_mutated -ne $false){ Add-Err 'ctx_repo_mutated_not_false' }
}
if($firstProof){
  if($firstProof.life_working_memory_mode -ne 'created_life_working_memory'){ Add-Err "first_mode_mismatch:$($firstProof.life_working_memory_mode)" }
  if($firstProof.life_working_memory.status -ne 'PASS_LIFE_WORKING_MEMORY_V1'){ Add-Err 'first_lwm_status_not_pass' }
  if(-not (Test-Path (Join-Path $firstDir.FullName 'wake_body_audit'))){ Add-Err 'first_wake_body_audit_missing_expected' }
  if(-not (Test-Path (Join-Path $firstDir.FullName 'default_wake_reflexes.json'))){ Add-Err 'first_default_wake_missing_expected' }
}
if($secondProof){
  if($secondProof.life_working_memory_mode -ne 'reused_life_working_memory'){ Add-Err "second_mode_mismatch:$($secondProof.life_working_memory_mode)" }
  if($secondProof.life_working_memory.status -ne 'PASS_LIFE_WORKING_MEMORY_V1'){ Add-Err 'second_lwm_status_not_pass' }
  if(Test-Path (Join-Path $secondDir.FullName 'wake_body_audit')){ Add-Err 'second_wake_body_audit_should_not_exist' }
  if(Test-Path (Join-Path $secondDir.FullName 'default_wake_reflexes.json')){ Add-Err 'second_default_wake_should_not_exist' }
  if(Test-Path (Join-Path $secondDir.FullName 'innate_reflex_bootload.json')){ Add-Err 'second_bootload_should_not_exist' }
  $written=@($secondProof.mutation_audit.files_written | ForEach-Object { [string]$_ })
  foreach($bad in @('default_wake_reflexes.json','innate_reflex_bootload.json')){ if(@($written | Where-Object { $_ -like "*$bad" }).Count -gt 0){ Add-Err "second_files_written_contains:$bad" } }
}
$status=if($errors.Count -eq 0){'PASS_LIFE_WORKING_MEMORY_V1'}else{'FAIL_LIFE_WORKING_MEMORY_V1'}
$proof=[ordered]@{
  schema='life_working_memory_v1_validation'
  status=$status
  checked_at=(Get-Date).ToUniversalTime().ToString('o')
  runner=$runner
  launcher=$launcher
  validator='validators/validate_life_working_memory_v1.ps1'
  test_root=$testRoot
  wake_context_path=$ctx
  first=[ordered]@{ exit_code=$firstExit; run_dir=if($firstDir){$firstDir.FullName}else{$null}; mode=if($firstProof){$firstProof.life_working_memory_mode}else{$null}; wake_body_audit_exists=if($firstDir){Test-Path (Join-Path $firstDir.FullName 'wake_body_audit')}else{$false}; default_wake_exists=if($firstDir){Test-Path (Join-Path $firstDir.FullName 'default_wake_reflexes.json')}else{$false} }
  second=[ordered]@{ exit_code=$secondExit; run_dir=if($secondDir){$secondDir.FullName}else{$null}; mode=if($secondProof){$secondProof.life_working_memory_mode}else{$null}; wake_body_audit_exists=if($secondDir){Test-Path (Join-Path $secondDir.FullName 'wake_body_audit')}else{$false}; default_wake_exists=if($secondDir){Test-Path (Join-Path $secondDir.FullName 'default_wake_reflexes.json')}else{$false}; bootload_exists=if($secondDir){Test-Path (Join-Path $secondDir.FullName 'innate_reflex_bootload.json')}else{$false} }
  errors=@($errors)
  boundary=[ordered]@{ first_cycle_creates_life_working_memory=$true; later_cycle_reuses_life_working_memory=$true; repeated_body_wake_scan_after_context_exists=$false; per_cycle_wake_files_after_context_exists=$false; active_memory_mutated=$false; repo_mutated=$false; codex_launched=$false; web_launched=$false }
}
WJson 'tests/self_development/LIFE_WORKING_MEMORY_V1_PROOF.json' $proof
Write-Host "STATUS=$status"
if($errors.Count -gt 0){ foreach($e in $errors){Write-Host "ERROR=$e"}; exit 1 }
