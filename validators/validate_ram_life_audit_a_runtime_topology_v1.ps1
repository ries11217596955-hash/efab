$ErrorActionPreference='Stop'
$errors=@()
function Add-Err([string]$e){ $script:errors += $e }
function WJson($path,$obj){ $dir=Split-Path $path -Parent; if($dir){New-Item -ItemType Directory -Force -Path $dir|Out-Null}; $json=($obj|ConvertTo-Json -Depth 100) -replace "`r`n","`n"; [System.IO.File]::WriteAllText((Join-Path (Get-Location).Path $path),$json.TrimEnd()+"`n",(New-Object System.Text.UTF8Encoding($false))) }
$reportPath='operations/autonomous_inner_motor/reports/RAM_LIFE_AUDIT_A_RUNTIME_TOPOLOGY_V1.json'
foreach($p in @($reportPath,'operations/autonomous_inner_motor/start_agent_life_v1.ps1','operations/autonomous_inner_motor/run_autonomous_inner_motor.ps1')){ if(-not(Test-Path $p)){ Add-Err "missing:$p" } }
$r=$null
if(Test-Path $reportPath){ $r=Get-Content $reportPath -Raw | ConvertFrom-Json }
if($r){
  if($r.status -ne 'PASS_RAM_LIFE_AUDIT_A_RUNTIME_TOPOLOGY_V1'){ Add-Err "status_mismatch:$($r.status)" }
  if($r.current_runtime_topology.model -ne 'canonical_launcher_loop_spawns_separate_runner_process_per_cycle'){ Add-Err "model_mismatch:$($r.current_runtime_topology.model)" }
  if($r.current_runtime_topology.continuous_runtime -ne 'NOT_IMPLEMENTED'){ Add-Err "continuous_runtime_mismatch:$($r.current_runtime_topology.continuous_runtime)" }
  if($r.current_runtime_topology.ram_persistence -notlike '*lost after runner exits*'){ Add-Err 'ram_persistence_not_named' }
  foreach($surface in @('life_working_memory_context.json','SANDBOX_EXPLORATION_PROOF.json','LIVE_TRIAL_SUMMARY.json')){ if(($r | ConvertTo-Json -Depth 20) -notlike "*$surface*"){ Add-Err "missing_surface:$surface" } }
  foreach($gap in @('no single long-running agent process yet','no RAM-resident agent state across cycles','no continuous runtime lock/pid/heartbeat/stop contract yet')){ if(@($r.gaps_for_ram_life) -notcontains $gap){ Add-Err "missing_gap:$gap" } }
  if($r.boundary.continuous_runtime_launched -ne $false){ Add-Err 'continuous_runtime_launched_not_false' }
  if($r.boundary.active_memory_mutated -ne $false){ Add-Err 'active_memory_mutated_not_false' }
}
$status=if($errors.Count -eq 0){'PASS_RAM_LIFE_AUDIT_A_RUNTIME_TOPOLOGY_V1'}else{'FAIL_RAM_LIFE_AUDIT_A_RUNTIME_TOPOLOGY_V1'}
$proof=[ordered]@{
  schema='ram_life_audit_a_runtime_topology_v1_validation'
  status=$status
  checked_at=(Get-Date).ToUniversalTime().ToString('o')
  report=$reportPath
  errors=@($errors)
  boundary=[ordered]@{ audit_only=$true; continuous_runtime_launched=$false; active_memory_mutated=$false; repo_runtime_mutated=$false; codex_launched=$false; web_launched=$false }
}
WJson 'tests/self_development/RAM_LIFE_AUDIT_A_RUNTIME_TOPOLOGY_V1_PROOF.json' $proof
Write-Host "STATUS=$status"
if($errors.Count -gt 0){ foreach($e in $errors){Write-Host "ERROR=$e"}; exit 1 }
