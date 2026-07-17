$ErrorActionPreference='Stop'
$errors=@()
function Add-Err([string]$e){ $script:errors += $e }
function WJson($path,$obj){ $dir=Split-Path $path -Parent; if($dir){New-Item -ItemType Directory -Force -Path $dir|Out-Null}; $json=($obj|ConvertTo-Json -Depth 100) -replace "`r`n","`n"; [System.IO.File]::WriteAllText((Join-Path (Get-Location).Path $path),$json.TrimEnd()+"`n",(New-Object System.Text.UTF8Encoding($false))) }
$report='operations/autonomous_inner_motor/reports/MIND_AUDIT_M1_CURRENT_MIND_TOPOLOGY_V1.json'
$notebook='AGENT_BUILDER_SELF_NOTEBOOK.md'
$launcher='operations/autonomous_inner_motor/start_agent_life_v1.ps1'
$runner='operations/autonomous_inner_motor/run_autonomous_inner_motor.ps1'
foreach($p in @($report,$notebook,$launcher,$runner)){ if(-not(Test-Path $p)){ Add-Err "missing:$p" } }
$r=$null
if(Test-Path $report){$r=Get-Content $report -Raw|ConvertFrom-Json}
if($r){
  if($r.status -ne 'PASS_MIND_AUDIT_M1_CURRENT_MIND_TOPOLOGY_V1'){ Add-Err "report_status_mismatch:$($r.status)" }
  if($r.scope.audit_only -ne $true){ Add-Err 'scope_audit_only_not_true' }
  if($r.scope.runtime_launched -ne $false){ Add-Err 'scope_runtime_launched_not_false' }
  foreach($node in @('canonical_body','preflight','life_working_memory','wake_reflex_context','compact_memory_position','mind_logic_frame','action_decision','output')){ if(-not $r.topology.PSObject.Properties[$node]){ Add-Err "topology_missing:$node" } }
  foreach($label in @('CANONICAL_MIND_IS_PROCESS_PER_CYCLE','DECISION_CHAIN_ENDS_AT_QUEUE_PACKET','COMPACT_MEMORY_READ_USE_NOT_PROVEN','SHORT_TERM_MEMORY_IS_WAKE_CONTEXT_NOT_MIND_STATE','PROOF_ECONOMY_OBSCURES_DECISION_TRACE','FRONTIER_TO_BUILD_TASK_MISSING')){ if(@($r.findings | Where-Object {$_.label -eq $label}).Count -ne 1){ Add-Err "finding_missing:$label" } }
  if(@($r.findings).Count -lt 6){ Add-Err "findings_too_few:$(@($r.findings).Count)" }
  if($r.evidence.retained_cycle_proof_count -ne 0){ Add-Err "expected_latest_retained_cycle_proof_count_0_but:$($r.evidence.retained_cycle_proof_count)" }
  if(@($r.evidence.latest_queue_packets).Count -lt 1){ Add-Err 'latest_queue_packets_missing' }
  if($r.current_mind_chain.observed -notlike '*compact memory queue packet*'){ Add-Err 'observed_chain_missing_queue_packet' }
  if($r.current_mind_chain.missing -notlike '*selective memory retrieval*'){ Add-Err 'missing_chain_missing_retrieval' }
  if($r.recommended_next_action -ne 'AUDIT_M3_COMPACT_MEMORY_READ_PATH_V1'){ Add-Err 'recommended_next_action_mismatch' }
  if($r.boundary.runtime_launched -ne $false){ Add-Err 'boundary_runtime_launched_not_false' }
  if($r.boundary.active_memory_mutated -ne $false){ Add-Err 'boundary_active_memory_mutated_not_false' }
  if($r.boundary.canonical_launcher_mutated -ne $false){ Add-Err 'boundary_launcher_mutated_not_false' }
  if($r.boundary.cycle_runner_mutated -ne $false){ Add-Err 'boundary_runner_mutated_not_false' }
}
$nbText=if(Test-Path $notebook){Get-Content $notebook -Raw}else{''}
foreach($needle in @('MIND_AUDIT_M1_CURRENT_MIND_TOPOLOGY_V1','Canonical mind is still process-per-cycle','selective read/use path is not proven','AUDIT_M3_COMPACT_MEMORY_READ_PATH_V1')){ if($nbText -notlike "*$needle*"){ Add-Err "notebook_missing:$needle" } }
$procs=@(Get-CimInstance Win32_Process | Where-Object { $_.CommandLine -and $_.CommandLine -notmatch 'Get-CimInstance Win32_Process' -and $_.CommandLine -match 'run_autonomous_inner_motor.ps1|start_agent_life_v1.ps1|invoke_body_self_inspection_circuit_v1.ps1|codex exec|node_modules.*@openai/codex|node.*codex.js|school|run_continuous_agent_runtime_v1_lab.ps1|continuous_agent_runtime_v1' })
if($procs.Count -ne 0){ Add-Err "process_count_not_zero:$($procs.Count)" }
$status=if($errors.Count -eq 0){'PASS_MIND_AUDIT_M1_CURRENT_MIND_TOPOLOGY_V1'}else{'FAIL_MIND_AUDIT_M1_CURRENT_MIND_TOPOLOGY_V1'}
$proof=[ordered]@{
  schema='mind_audit_m1_current_mind_topology_v1_validation'
  status=$status
  checked_at=(Get-Date).ToUniversalTime().ToString('o')
  report=$report
  notebook=$notebook
  launcher=$launcher
  runner=$runner
  findings_count=if($r){@($r.findings).Count}else{0}
  retained_cycle_proof_count=if($r){$r.evidence.retained_cycle_proof_count}else{$null}
  process_count=$procs.Count
  errors=@($errors)
  boundary=[ordered]@{audit_only=$true; runtime_launched=$false; active_memory_mutated=$false; canonical_launcher_mutated=$false; cycle_runner_mutated=$false; codex_launched=$false; web_launched=$false; school_launched=$false}
}
WJson 'tests/self_development/MIND_AUDIT_M1_CURRENT_MIND_TOPOLOGY_V1_PROOF.json' $proof
Write-Host "STATUS=$status"
if($errors.Count -gt 0){ foreach($e in $errors){Write-Host "ERROR=$e"}; exit 1 }
