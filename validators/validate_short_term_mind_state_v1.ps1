$ErrorActionPreference='Stop'
$errors=@()
function Add-Err([string]$e){ $script:errors += $e }
function WJson($path,$obj){ $dir=Split-Path $path -Parent; if($dir){New-Item -ItemType Directory -Force -Path $dir|Out-Null}; $json=($obj|ConvertTo-Json -Depth 100) -replace "`r`n","`n"; [System.IO.File]::WriteAllText((Join-Path (Get-Location).Path $path),$json.TrimEnd()+"`n",(New-Object System.Text.UTF8Encoding($false))) }
function TreeStats($p){ if(-not(Test-Path $p)){ return [ordered]@{exists=$false; files=0; bytes=0} }; $files=@(Get-ChildItem $p -Recurse -File -Force -ErrorAction SilentlyContinue); return [ordered]@{exists=$true; files=$files.Count; bytes=[int64](($files|Measure-Object Length -Sum).Sum)} }
function Run-AimoCycle($outputRoot,$question){
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
$outputRoot='.runtime/short_term_mind_state_v1_validation'
$canonicalProof='tests/self_development/SHORT_TERM_MIND_STATE_V1_PROOF.json'
$acceptance='operations/autonomous_inner_motor/reports/SHORT_TERM_MIND_STATE_V1_ACCEPTANCE.json'
if(-not(Test-Path $runner)){ Add-Err "missing_runner:$runner" }
$tokens=$null;$parseErrors=$null
if(Test-Path $runner){ [System.Management.Automation.Language.Parser]::ParseFile((Resolve-Path $runner),[ref]$tokens,[ref]$parseErrors)|Out-Null; foreach($e in $parseErrors){ Add-Err "runner_parse:$($e.Message)" } }
$runnerText=if(Test-Path $runner){Get-Content $runner -Raw}else{''}
foreach($needle in @('function New-ShortTermMindState','function Get-LatestShortTermMindState','short_term_mind_state.json','short_term_mind_state=$shortTermMindState','step=''short_term_mind_state''','MULTI_SOURCE_COMPACT_MEMORY_MERGE_QUEUE_V1 + MEMORY_COMMIT_ORGAN_V1')){ if($runnerText -notlike "*$needle*"){ Add-Err "runner_missing:$needle" } }
$activeBefore=TreeStats '.runtime/active_compact_semantic_memory_v1'
$queueBefore=TreeStats '.runtime/compact_memory_intake_v1/queue'
$launcherHashBefore=(Get-FileHash 'operations/autonomous_inner_motor/start_agent_life_v1.ps1' -Algorithm SHA256).Hash
$runnerHashBefore=(Get-FileHash $runner -Algorithm SHA256).Hash
$run1=$null; $run2=$null
if($errors.Count -eq 0){
  $run1=Run-AimoCycle $outputRoot 'Validate SHORT_TERM_MIND_STATE_V1 Slice A cycle 1: hold active thought and release completed candidate to existing multi-source warehouse.'
  if($run1.exit_code -ne 0){ Add-Err "run1_exit_code:$($run1.exit_code)" }
  Start-Sleep -Seconds 2
  $run2=Run-AimoCycle $outputRoot 'Validate SHORT_TERM_MIND_STATE_V1 Slice A cycle 2: read previous short-term state and continue without starting from zero.'
  if($run2.exit_code -ne 0){ Add-Err "run2_exit_code:$($run2.exit_code)" }
}
$proof1=$null; $proof2=$null; $state1=$null; $state2=$null; $manifest1=$null; $manifest2=$null
foreach($pair in @(@('1',$run1),@('2',$run2))){
  $n=$pair[0]; $r=$pair[1]
  if(-not $r -or -not $r.run_root_full){ Add-Err "run${n}_root_missing"; continue }
  $proofPath=Join-Path $r.run_root_full 'SANDBOX_EXPLORATION_PROOF.json'
  $statePath=Join-Path $r.run_root_full 'short_term_mind_state.json'
  $manifestPath=Join-Path $r.run_root_full 'sandbox_proof_pack_manifest.json'
  if(-not(Test-Path $proofPath)){ Add-Err "run${n}_proof_missing" } else { Set-Variable -Name "proof$n" -Value (Get-Content $proofPath -Raw|ConvertFrom-Json) }
  if(-not(Test-Path $statePath)){ Add-Err "run${n}_short_term_state_missing" } else { Set-Variable -Name "state$n" -Value (Get-Content $statePath -Raw|ConvertFrom-Json) }
  if(-not(Test-Path $manifestPath)){ Add-Err "run${n}_manifest_missing" } else { Set-Variable -Name "manifest$n" -Value (Get-Content $manifestPath -Raw|ConvertFrom-Json) }
}
foreach($s in @(@('1',$state1),@('2',$state2))){
  $n=$s[0]; $st=$s[1]
  if($st){
    if($st.status -ne 'PASS_SHORT_TERM_MIND_STATE_V1'){ Add-Err "run${n}_state_status:$($st.status)" }
    if($st.boundary.not_a_warehouse -ne $true){ Add-Err "run${n}_not_a_warehouse_not_true" }
    if($st.boundary.no_duplicate_store -ne $true){ Add-Err "run${n}_no_duplicate_store_not_true" }
    if($st.boundary.direct_active_memory_write -ne $false){ Add-Err "run${n}_direct_active_memory_write_not_false" }
    if($st.completed_candidate.existing_throat -ne 'MULTI_SOURCE_COMPACT_MEMORY_MERGE_QUEUE_V1 + MEMORY_COMMIT_ORGAN_V1'){ Add-Err "run${n}_existing_throat_mismatch" }
    if($st.completed_candidate.route_status -ne 'RELEASED_TO_EXISTING_MULTI_SOURCE_WAREHOUSE'){ Add-Err "run${n}_route_status:$($st.completed_candidate.route_status)" }
    if($st.completed_candidate.released_to_existing_warehouse -ne $true){ Add-Err "run${n}_not_released_to_existing_warehouse" }
    if([string]::IsNullOrWhiteSpace([string]$st.completed_candidate.queue_packet_path)){ Add-Err "run${n}_queue_packet_path_empty" }
    elseif(-not(Test-Path $st.completed_candidate.queue_packet_path)){ Add-Err "run${n}_queue_packet_missing:$($st.completed_candidate.queue_packet_path)" }
    if($st.completed_candidate.packet_validation_status -ne 'PASS_COMPACT_MEMORY_KNOWLEDGE_PACKET_V1'){ Add-Err "run${n}_packet_validation_status:$($st.completed_candidate.packet_validation_status)" }
    if([int]$st.active_thread.decomposition_node_count -lt 1){ Add-Err "run${n}_decomposition_node_count_lt_1" }
  }
}
foreach($p in @(@('1',$proof1),@('2',$proof2))){
  $n=$p[0]; $pr=$p[1]
  if($pr){
    if(-not $pr.PSObject.Properties['short_term_mind_state']){ Add-Err "run${n}_proof_short_term_missing" }
    if(@($pr.decision_trace | Where-Object { $_.step -eq 'short_term_mind_state' }).Count -ne 1){ Add-Err "run${n}_decision_trace_short_term_missing" }
  }
}
foreach($m in @(@('1',$manifest1),@('2',$manifest2))){
  $n=$m[0]; $mf=$m[1]
  if($mf){ if(@($mf.required_files) -notcontains 'short_term_mind_state.json'){ Add-Err "run${n}_manifest_required_short_term_missing" } }
}
if($state2){
  if($state2.continuity.previous_state_found -ne $true){ Add-Err 'run2_previous_state_not_found' }
  if([string]::IsNullOrWhiteSpace([string]$state2.continuity.previous_state_ref)){ Add-Err 'run2_previous_state_ref_empty' }
  if($state2.continuity.previous_candidate_route_status -ne 'RELEASED_TO_EXISTING_MULTI_SOURCE_WAREHOUSE'){ Add-Err "run2_previous_candidate_route_status:$($state2.continuity.previous_candidate_route_status)" }
}
$activeAfter=TreeStats '.runtime/active_compact_semantic_memory_v1'
$queueAfter=TreeStats '.runtime/compact_memory_intake_v1/queue'
if($activeBefore.files -ne $activeAfter.files -or $activeBefore.bytes -ne $activeAfter.bytes){ Add-Err 'active_memory_changed' }
if($queueAfter.files -lt ($queueBefore.files + 2)){ Add-Err "queue_files_not_increased_by_2:before=$($queueBefore.files):after=$($queueAfter.files)" }
$launcherHashAfter=(Get-FileHash 'operations/autonomous_inner_motor/start_agent_life_v1.ps1' -Algorithm SHA256).Hash
$runnerHashAfter=(Get-FileHash $runner -Algorithm SHA256).Hash
if($launcherHashBefore -ne $launcherHashAfter){ Add-Err 'launcher_hash_changed' }
if($runnerHashBefore -ne $runnerHashAfter){ Add-Err 'runner_hash_changed_during_validation' }
$procs=@(Get-CimInstance Win32_Process | Where-Object { $_.ProcessId -ne $PID -and $_.CommandLine -and $_.CommandLine -notmatch 'Get-CimInstance Win32_Process|validate_short_term_mind_state_v1.ps1' -and $_.CommandLine -match '\s-File\s+.*(start_agent_life_v1.ps1|run_autonomous_inner_motor.ps1|run_continuous_agent_runtime_v1_lab.ps1|school|invoke_body_self_inspection_circuit_v1.ps1)|codex exec|node_modules.*@openai/codex|node.*codex.js|continuous_agent_runtime_v1' })
if($procs.Count -ne 0){ Add-Err "process_count_not_zero:$($procs.Count)" }
$status=if($errors.Count -eq 0){'PASS_SHORT_TERM_MIND_STATE_V1'}else{'FAIL_SHORT_TERM_MIND_STATE_V1'}
$canonical=[ordered]@{
  schema='short_term_mind_state_v1_validation'
  status=$status
  checked_at=(Get-Date).ToUniversalTime().ToString('o')
  runner=$runner
  run1=$run1
  run2=$run2
  run1_short_term_mind_state=$state1
  run2_short_term_mind_state=$state2
  continuity_proven=if($state2){[bool]$state2.continuity.previous_state_found}else{$false}
  existing_warehouse_route_proven=if($state1 -and $state2){[bool]($state1.completed_candidate.released_to_existing_warehouse -and $state2.completed_candidate.released_to_existing_warehouse)}else{$false}
  active_memory_before=$activeBefore
  active_memory_after=$activeAfter
  queue_before=$queueBefore
  queue_after=$queueAfter
  process_count=$procs.Count
  errors=@($errors)
  boundary=[ordered]@{runtime_launched_by_validator=$true; cycles=2; memory_ingestion_mode='QueueOnly'; active_memory_mutated=$false; direct_active_memory_write=$false; queue_packets_added_expected=$true; no_new_store_created=$true; school_launched=$false; codex_launched=$false; web_launched=$false}
}
WJson $canonicalProof $canonical
$accept=[ordered]@{
  schema='short_term_mind_state_v1_acceptance'
  status=if($status -eq 'PASS_SHORT_TERM_MIND_STATE_V1'){'ACCEPTED_SHORT_TERM_MIND_STATE_V1_SLICE_A_WITH_EXISTING_MULTI_SOURCE_INTAKE_ROUTE'}else{'REJECTED_SHORT_TERM_MIND_STATE_V1_SLICE_A_WITH_EXISTING_MULTI_SOURCE_INTAKE_ROUTE'}
  accepted_at=(Get-Date).ToUniversalTime().ToString('o')
  proof=$canonicalProof
  may_claim='Short-term mind state sidecar exists, carries active thought, releases completed candidates to existing multi-source warehouse, and second cycle reads previous short-term state.'
  may_not_claim=@('RAM canonical migration complete','true infinite single-process life','school launched','active compact memory updated','new warehouse created')
  boundary=$canonical.boundary
}
WJson $acceptance $accept
Write-Host "STATUS=$status"
if($errors.Count -gt 0){ foreach($e in $errors){ Write-Host "ERROR=$e" }; exit 1 }
