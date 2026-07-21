$ErrorActionPreference='Stop'
$errors=@()
function Add-Err([string]$e){ $script:errors += $e }
function WJson($path,$obj){
  $dir=Split-Path $path -Parent
  if($dir){ New-Item -ItemType Directory -Force -Path $dir | Out-Null }
  $json=($obj|ConvertTo-Json -Depth 100) -replace "`r`n","`n"
  [System.IO.File]::WriteAllText((Join-Path (Get-Location).Path $path),$json.TrimEnd()+"`n",(New-Object System.Text.UTF8Encoding($false)))
}
function TreeStats($p){
  if(-not(Test-Path $p)){ return [ordered]@{exists=$false; files=0; bytes=0} }
  $files=@(Get-ChildItem $p -Recurse -File -Force -ErrorAction SilentlyContinue)
  return [ordered]@{exists=$true; files=$files.Count; bytes=[int64](($files|Measure-Object Length -Sum).Sum)}
}
function Run-Cycle($outputRoot,$question){
  $before=@(); if(Test-Path $outputRoot){ $before=@(Get-ChildItem $outputRoot -Directory -ErrorAction SilentlyContinue | Select-Object -ExpandProperty FullName) }
  powershell -NoProfile -ExecutionPolicy Bypass -File operations/autonomous_inner_motor/run_autonomous_inner_motor.ps1 -Mode SandboxExploration -EnableDeepThinking -EnableMemoryLearning -MemoryIngestionMode QueueOnly -OutputRoot $outputRoot -Question $question
  $exit=$LASTEXITCODE
  $after=@(); if(Test-Path $outputRoot){ $after=@(Get-ChildItem $outputRoot -Directory -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending) }
  $new=$null
  foreach($d in $after){ if($before -notcontains $d.FullName){ $new=$d; break } }
  if(-not $new -and $after.Count -gt 0){ $new=$after[0] }
  return [ordered]@{ exit_code=$exit; run_root=if($new){$new.FullName.Replace((Get-Location).Path+'\','')}else{$null}; run_root_full=if($new){$new.FullName}else{$null} }
}
$runner='operations/autonomous_inner_motor/run_autonomous_inner_motor.ps1'
$stamp=(Get-Date).ToUniversalTime().ToString('yyyyMMdd_HHmmss')
$outputRoot=".runtime/frontier_to_build_task_router_v1_validation/$stamp"
$canonicalProof='tests/self_development/FRONTIER_TO_BUILD_TASK_ROUTER_V1_PROOF.json'
$acceptance='operations/autonomous_inner_motor/reports/FRONTIER_TO_BUILD_TASK_ROUTER_V1_ACCEPTANCE.json'
$tokens=$null;$parseErrors=$null
if(-not(Test-Path $runner)){ Add-Err "missing_runner:$runner" } else { [System.Management.Automation.Language.Parser]::ParseFile((Resolve-Path $runner),[ref]$tokens,[ref]$parseErrors)|Out-Null; foreach($e in $parseErrors){ Add-Err "runner_parse:$($e.Message)" } }
$runnerText=if(Test-Path $runner){Get-Content $runner -Raw}else{''}
foreach($needle in @('function New-FrontierToBuildTaskRouter','frontier_to_build_task_router.json','frontier_to_build_task_router=$frontierToBuildTaskRouter','step=''frontier_to_build_task_router''','files_to_read','files_allowed_to_write','execution_allowed=$false')){ if($runnerText -notlike "*$needle*"){ Add-Err "runner_missing:$needle" } }
$activeBefore=TreeStats '.runtime/active_compact_semantic_memory_v1'
$queueBefore=TreeStats '.runtime/compact_memory_intake_v1/queue'
$launcherHashBefore=(Get-FileHash 'operations/autonomous_inner_motor/start_agent_life_v1.ps1' -Algorithm SHA256).Hash
$runnerHashBefore=(Get-FileHash $runner -Algorithm SHA256).Hash
$run1=$null; $run2=$null
if($errors.Count -eq 0){
  $run1=Run-Cycle $outputRoot 'Validate FRONTIER_TO_BUILD_TASK_ROUTER_V1 cycle 1: generate state and first contract signal.'
  if($run1.exit_code -ne 0){ Add-Err "run1_exit_code:$($run1.exit_code)" }
  Start-Sleep -Seconds 2
  $run2=Run-Cycle $outputRoot 'Validate FRONTIER_TO_BUILD_TASK_ROUTER_V1 cycle 2: use previous state and emit build task contract.'
  if($run2.exit_code -ne 0){ Add-Err "run2_exit_code:$($run2.exit_code)" }
}
$proof1=$null;$proof2=$null;$frontier1=$null;$frontier2=$null;$shortRouter2=$null;$state2=$null;$manifest1=$null;$manifest2=$null
foreach($pair in @(@('1',$run1),@('2',$run2))){
  $n=$pair[0]; $r=$pair[1]
  if(-not $r -or -not $r.run_root_full){ Add-Err "run${n}_root_missing"; continue }
  $proofPath=Join-Path $r.run_root_full 'SANDBOX_EXPLORATION_PROOF.json'
  $frontierPath=Join-Path $r.run_root_full 'frontier_to_build_task_router.json'
  $shortRouterPath=Join-Path $r.run_root_full 'short_term_state_to_next_task_router.json'
  $statePath=Join-Path $r.run_root_full 'short_term_mind_state.json'
  $manifestPath=Join-Path $r.run_root_full 'sandbox_proof_pack_manifest.json'
  if(Test-Path $proofPath){ Set-Variable -Name "proof$n" -Value (Get-Content $proofPath -Raw|ConvertFrom-Json) } else { Add-Err "run${n}_proof_missing" }
  if(Test-Path $frontierPath){ Set-Variable -Name "frontier$n" -Value (Get-Content $frontierPath -Raw|ConvertFrom-Json) } else { Add-Err "run${n}_frontier_router_missing" }
  if($n -eq '2' -and (Test-Path $shortRouterPath)){ $shortRouter2=Get-Content $shortRouterPath -Raw|ConvertFrom-Json }
  if($n -eq '2' -and (Test-Path $statePath)){ $state2=Get-Content $statePath -Raw|ConvertFrom-Json }
  if(Test-Path $manifestPath){ Set-Variable -Name "manifest$n" -Value (Get-Content $manifestPath -Raw|ConvertFrom-Json) } else { Add-Err "run${n}_manifest_missing" }
}
foreach($x in @(@('1',$frontier1),@('2',$frontier2))){
  $n=$x[0]; $fr=$x[1]
  if($fr){
    if($fr.status -ne 'PASS_FRONTIER_TO_BUILD_TASK_ROUTER_V1'){ Add-Err "run${n}_frontier_status:$($fr.status)" }
    if($fr.schema -ne 'frontier_to_build_task_router_v1'){ Add-Err "run${n}_frontier_schema:$($fr.schema)" }
    if(-not $fr.contract){ Add-Err "run${n}_contract_missing"; continue }
    if($fr.contract.task_type -ne 'BUILD_TASK_CONTRACT'){ Add-Err "run${n}_task_type:$($fr.contract.task_type)" }
    if($fr.contract.execution_allowed -ne $false){ Add-Err "run${n}_execution_allowed_not_false" }
    if($fr.contract.validator -ne 'validators/validate_frontier_to_build_task_router_v1.ps1'){ Add-Err "run${n}_validator_mismatch:$($fr.contract.validator)" }
    if($fr.contract.proof -ne 'tests/self_development/FRONTIER_TO_BUILD_TASK_ROUTER_V1_PROOF.json'){ Add-Err "run${n}_proof_mismatch:$($fr.contract.proof)" }
    foreach($required in @('operations/autonomous_inner_motor/run_autonomous_inner_motor.ps1','AGENT_BUILDER_MIND_REPAIR_PRIORITY_PLAN_V1.md','AGENT_BUILDER_SELF_NOTEBOOK.md','tests/self_development/SHORT_TERM_STATE_TO_NEXT_TASK_ROUTER_V1_PROOF.json')){ if(@($fr.contract.files_to_read) -notcontains $required){ Add-Err "run${n}_files_to_read_missing:$required" } }
    foreach($required in @('operations/autonomous_inner_motor/run_autonomous_inner_motor.ps1','validators/validate_frontier_to_build_task_router_v1.ps1','tests/self_development/FRONTIER_TO_BUILD_TASK_ROUTER_V1_PROOF.json','operations/autonomous_inner_motor/reports/FRONTIER_TO_BUILD_TASK_ROUTER_V1_ACCEPTANCE.json')){ if(@($fr.contract.files_allowed_to_write) -notcontains $required){ Add-Err "run${n}_files_allowed_to_write_missing:$required" } }
    foreach($forbidden in @('.runtime/active_compact_semantic_memory_v1','operations/autonomous_inner_motor/start_agent_life_v1.ps1')){ if(@($fr.contract.files_forbidden_to_write) -notcontains $forbidden){ Add-Err "run${n}_forbidden_missing:$forbidden" } }
    if($fr.boundary.router_only -ne $true){ Add-Err "run${n}_router_only_not_true" }
    if($fr.boundary.contract_only -ne $true){ Add-Err "run${n}_contract_only_not_true" }
    if($fr.boundary.execution_allowed -ne $false){ Add-Err "run${n}_boundary_execution_not_false" }
    if($fr.boundary.direct_active_memory_write -ne $false){ Add-Err "run${n}_direct_active_memory_write_not_false" }
  }
}
if($frontier2){
  if($frontier2.selected_next_task -ne 'FRONTIER_TO_BUILD_TASK_ROUTER_V1'){ Add-Err "run2_selected_next_task_unexpected:$($frontier2.selected_next_task)" }
  if($frontier2.contract.task_id -ne 'FRONTIER_TO_BUILD_TASK_ROUTER_V1'){ Add-Err "run2_contract_task_id_unexpected:$($frontier2.contract.task_id)" }
}
if($shortRouter2 -and $shortRouter2.selected_next_task -ne 'FRONTIER_TO_BUILD_TASK_ROUTER_V1'){ Add-Err "run2_short_router_selected_unexpected:$($shortRouter2.selected_next_task)" }
if($state2 -and $state2.continuity.previous_state_found -ne $true){ Add-Err 'run2_previous_state_not_found' }
foreach($p in @(@('1',$proof1),@('2',$proof2))){
  $n=$p[0]; $pr=$p[1]
  if($pr){
    if(-not $pr.PSObject.Properties['frontier_to_build_task_router']){ Add-Err "run${n}_proof_frontier_router_missing" }
    if(@($pr.decision_trace | Where-Object { $_.step -eq 'frontier_to_build_task_router' }).Count -ne 1){ Add-Err "run${n}_decision_trace_frontier_missing" }
  }
}
foreach($m in @(@('1',$manifest1),@('2',$manifest2))){ $n=$m[0]; $mf=$m[1]; if($mf){ if(@($mf.required_files) -notcontains 'frontier_to_build_task_router.json'){ Add-Err "run${n}_manifest_frontier_required_missing" } } }
$activeAfter=TreeStats '.runtime/active_compact_semantic_memory_v1'
$queueAfter=TreeStats '.runtime/compact_memory_intake_v1/queue'
if($activeBefore.files -ne $activeAfter.files -or $activeBefore.bytes -ne $activeAfter.bytes){ Add-Err 'active_memory_changed' }
if($queueAfter.files -lt ($queueBefore.files + 2)){ Add-Err "queue_files_not_increased_by_2:before=$($queueBefore.files):after=$($queueAfter.files)" }
$launcherHashAfter=(Get-FileHash 'operations/autonomous_inner_motor/start_agent_life_v1.ps1' -Algorithm SHA256).Hash
$runnerHashAfter=(Get-FileHash $runner -Algorithm SHA256).Hash
if($launcherHashBefore -ne $launcherHashAfter){ Add-Err 'launcher_hash_changed' }
if($runnerHashBefore -ne $runnerHashAfter){ Add-Err 'runner_hash_changed_during_validation' }
$procs=@(Get-CimInstance Win32_Process | Where-Object { $_.ProcessId -ne $PID -and $_.CommandLine -and $_.CommandLine -notmatch 'Get-CimInstance Win32_Process|validate_frontier_to_build_task_router_v1.ps1' -and $_.CommandLine -match '\s-File\s+.*(start_agent_life_v1.ps1|run_autonomous_inner_motor.ps1|run_continuous_agent_runtime_v1_lab.ps1|school|invoke_body_self_inspection_circuit_v1.ps1)|codex exec|node_modules.*@openai/codex|node.*codex.js|continuous_agent_runtime_v1' })
if($procs.Count -ne 0){ Add-Err "process_count_not_zero:$($procs.Count)" }
$status=if($errors.Count -eq 0){'PASS_FRONTIER_TO_BUILD_TASK_ROUTER_V1'}else{'FAIL_FRONTIER_TO_BUILD_TASK_ROUTER_V1'}
$canonical=[ordered]@{
  schema='frontier_to_build_task_router_v1_validation'
  status=$status
  checked_at=(Get-Date).ToUniversalTime().ToString('o')
  output_root=$outputRoot
  run1=$run1
  run2=$run2
  run2_previous_state_found=if($state2){$state2.continuity.previous_state_found}else{$false}
  selected_next_task=if($frontier2){$frontier2.selected_next_task}else{$null}
  contract=if($frontier2){$frontier2.contract}else{$null}
  input_summary=if($frontier2){$frontier2.input_summary}else{$null}
  active_memory_before=$activeBefore
  active_memory_after=$activeAfter
  queue_before=$queueBefore
  queue_after=$queueAfter
  process_count=$procs.Count
  errors=@($errors)
  boundary=[ordered]@{runtime_launched_by_validator=$true; cycles=2; router_only=$true; contract_only=$true; execution_allowed=$false; memory_ingestion_mode='QueueOnly'; active_memory_mutated=$false; direct_active_memory_write=$false; no_new_store_created=$true; school_launched=$false; codex_launched=$false; web_launched=$false}
}
WJson $canonicalProof $canonical
$accept=[ordered]@{
  schema='frontier_to_build_task_router_v1_acceptance'
  status=if($status -eq 'PASS_FRONTIER_TO_BUILD_TASK_ROUTER_V1'){'ACCEPTED_FRONTIER_TO_BUILD_TASK_ROUTER_V1'}else{'REJECTED_FRONTIER_TO_BUILD_TASK_ROUTER_V1'}
  accepted_at=(Get-Date).ToUniversalTime().ToString('o')
  proof=$canonicalProof
  selected_next_task=$canonical.selected_next_task
  contract=$canonical.contract
  may_claim='Agent can turn selected next frontier into a bounded build task contract with files, validator, proof, forbidden surfaces, and execution disabled.'
  may_not_claim=@('task execution implemented','auto patching allowed','RAM infinite life complete','school launched','active compact memory updated')
  boundary=$canonical.boundary
}
WJson $acceptance $accept
Write-Host "STATUS=$status"
if($errors.Count -gt 0){ foreach($e in $errors){ Write-Host "ERROR=$e" }; exit 1 }
