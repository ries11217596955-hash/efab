$ErrorActionPreference='Stop'
$errors=@()
function Add-Err([string]$e){ $script:errors += $e }
function WJson($path,$obj){ $dir=Split-Path $path -Parent; if($dir){New-Item -ItemType Directory -Force -Path $dir|Out-Null}; $json=($obj|ConvertTo-Json -Depth 100) -replace "`r`n","`n"; [System.IO.File]::WriteAllText((Join-Path (Get-Location).Path $path),$json.TrimEnd()+"`n",(New-Object System.Text.UTF8Encoding($false))) }
$plan='AGENT_BUILDER_RAM_LIFE_TRANSITION_MASTER_PLAN_V1.md'
$audit0='operations/autonomous_inner_motor/reports/RAM_LIFE_AUDIT_0_CURRENT_REALITY_V1.json'
foreach($p in @($plan,$audit0,'operations/autonomous_inner_motor/start_agent_life_v1.ps1','operations/autonomous_inner_motor/run_autonomous_inner_motor.ps1')){ if(-not(Test-Path $p)){ Add-Err "missing:$p" } }
$planText=if(Test-Path $plan){Get-Content $plan -Raw}else{''}
foreach($needle in @(
  'Move Agent Builder from process-per-cycle life',
  'AUDIT A',
  'AUDIT B',
  'AUDIT C',
  'AUDIT D',
  'AUDIT E',
  'AUDIT F',
  'IMMUTABLE_LIFE_ORIENTATION_CARD_V1',
  'ORIENTATION_DRIFT_SENSOR_V1',
  'CONTINUOUS_AGENT_RUNTIME_V1_LAB',
  'no infinite while loop without lock/heartbeat/stop',
  'no auto-update orientation card',
  'no active memory direct write',
  'AUDIT_A_PASS',
  'AUDIT_F_PASS'
)){ if($planText -notlike "*$needle*"){ Add-Err "plan_missing:$needle" } }
$a=$null
if(Test-Path $audit0){ $a=Get-Content $audit0 -Raw | ConvertFrom-Json }
if($a){
  if($a.status -ne 'PASS_RAM_LIFE_AUDIT_0_CURRENT_REALITY_V1'){ Add-Err "audit0_status_mismatch:$($a.status)" }
  if($a.current_life_model.model -ne 'launcher_loop_spawns_separate_runner_process_per_cycle'){ Add-Err "audit0_model_mismatch:$($a.current_life_model.model)" }
  if($a.current_life_model.continuous_runtime -ne 'NOT_IMPLEMENTED'){ Add-Err "audit0_continuous_runtime_mismatch:$($a.current_life_model.continuous_runtime)" }
  if($a.proven_foundations.default_wake_reflexes -notlike 'PASS*'){ Add-Err 'audit0_default_wake_not_pass' }
  if($a.proven_foundations.body_wake_raw_retention -notlike 'PASS*'){ Add-Err 'audit0_retention_not_pass' }
  if($a.proven_foundations.life_working_memory -notlike 'PASS*'){ Add-Err 'audit0_life_working_memory_not_pass' }
  if($a.boundary.continuous_runtime_launched -ne $false){ Add-Err 'audit0_continuous_runtime_launched_not_false' }
  if($a.boundary.active_memory_mutated -ne $false){ Add-Err 'audit0_active_memory_mutated_not_false' }
}
$procs=@(Get-CimInstance Win32_Process | Where-Object { $_.CommandLine -and $_.CommandLine -notmatch '\s-Command\s' -and $_.CommandLine -match 'run_autonomous_inner_motor.ps1|start_agent_life_v1.ps1|invoke_body_self_inspection_circuit_v1.ps1|codex exec|node.*codex|school|continuous' })
if($procs.Count -ne 0){ Add-Err "process_count_not_zero:$($procs.Count)" }
$status=if($errors.Count -eq 0){'PASS_RAM_LIFE_TRANSITION_MASTER_PLAN_V1'}else{'FAIL_RAM_LIFE_TRANSITION_MASTER_PLAN_V1'}
$proof=[ordered]@{
  schema='ram_life_transition_master_plan_v1_validation'
  status=$status
  checked_at=(Get-Date).ToUniversalTime().ToString('o')
  plan=$plan
  audit0=$audit0
  repo=[ordered]@{ branch=(git rev-parse --abbrev-ref HEAD); head=(git rev-parse --short HEAD); remote_delta=(git rev-list --left-right --count HEAD...origin/main); status_short=@(git status --short --untracked-files=all) }
  process_count=$procs.Count
  audit_sequence=@('AUDIT_A_RUNTIME_TOPOLOGY_V1','AUDIT_B_STATE_MEMORY_LAYERS_V1','AUDIT_C_FILE_PROOF_ECONOMY_V1','AUDIT_D_CONTINUOUS_SAFETY_V1','AUDIT_E_ORIENTATION_DRIFT_V1','AUDIT_F_LAB_DESIGN_V1')
  implementation_gate=@('AUDIT_A_PASS','AUDIT_B_PASS','AUDIT_C_PASS','AUDIT_D_PASS','AUDIT_E_PASS','AUDIT_F_PASS','IMMUTABLE_LIFE_ORIENTATION_CARD_V1_PROVEN_LAB','ORIENTATION_DRIFT_SENSOR_V1_PROVEN_LAB')
  errors=@($errors)
  boundary=[ordered]@{ master_plan_only=$true; continuous_runtime_launched=$false; active_memory_mutated=$false; repo_runtime_mutated=$false; codex_launched=$false; web_launched=$false; school_launched=$false }
}
WJson 'tests/self_development/RAM_LIFE_TRANSITION_MASTER_PLAN_V1_PROOF.json' $proof
Write-Host "STATUS=$status"
if($errors.Count -gt 0){ foreach($e in $errors){Write-Host "ERROR=$e"}; exit 1 }
