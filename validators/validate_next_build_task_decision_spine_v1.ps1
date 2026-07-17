$ErrorActionPreference='Stop'
$errors=@()
function Add-Err([string]$e){ $script:errors += $e }
function WJson($path,$obj){ $dir=Split-Path $path -Parent; if($dir){New-Item -ItemType Directory -Force -Path $dir|Out-Null}; $json=($obj|ConvertTo-Json -Depth 100) -replace "`r`n","`n"; [System.IO.File]::WriteAllText((Join-Path (Get-Location).Path $path),$json.TrimEnd()+"`n",(New-Object System.Text.UTF8Encoding($false))) }
function TreeStats($p){ if(-not(Test-Path $p)){ return [ordered]@{exists=$false; files=0; bytes=0} }; $files=@(Get-ChildItem $p -Recurse -File -Force -ErrorAction SilentlyContinue); return [ordered]@{exists=$true; files=$files.Count; bytes=[int64](($files|Measure-Object Length -Sum).Sum)} }
$runner='operations/autonomous_inner_motor/run_autonomous_inner_motor.ps1'
$outputRoot='.runtime/next_build_task_decision_spine_v1_validation'
$canonicalProof='tests/self_development/NEXT_BUILD_TASK_DECISION_SPINE_V1_PROOF.json'
$acceptance='operations/autonomous_inner_motor/reports/NEXT_BUILD_TASK_DECISION_SPINE_V1_ACCEPTANCE.json'
if(-not(Test-Path $runner)){ Add-Err "missing_runner:$runner" }
$tokens=$null;$parseErrors=$null
if(Test-Path $runner){ [System.Management.Automation.Language.Parser]::ParseFile((Resolve-Path $runner),[ref]$tokens,[ref]$parseErrors)|Out-Null; foreach($e in $parseErrors){ Add-Err "runner_parse:$($e.Message)" } }
$runnerText=if(Test-Path $runner){Get-Content $runner -Raw}else{''}
foreach($needle in @('function New-NextBuildTaskDecisionSpine','next_build_task_decision_spine.json','decision_spine=$decisionSpine','step=''decision_spine''','DECISION_SPINE_STATUS','next_build_task_decision_spine.json')){ if($runnerText -notlike "*$needle*"){ Add-Err "runner_missing:$needle" } }
$activeBefore=TreeStats '.runtime/active_compact_semantic_memory_v1'
$launcherHashBefore=(Get-FileHash 'operations/autonomous_inner_motor/start_agent_life_v1.ps1' -Algorithm SHA256).Hash
$runnerHashBefore=(Get-FileHash $runner -Algorithm SHA256).Hash
$beforeDirs=@(); if(Test-Path $outputRoot){ $beforeDirs=@(Get-ChildItem $outputRoot -Directory -ErrorAction SilentlyContinue | Select-Object -ExpandProperty FullName) }
if($errors.Count -eq 0){
  powershell -NoProfile -ExecutionPolicy Bypass -File $runner -Mode SandboxExploration -EnableDeepThinking -MemoryIngestionMode QueueOnly -OutputRoot $outputRoot -Question 'Validate NEXT_BUILD_TASK_DECISION_SPINE_V1 Slice A: produce explicit candidate or blocked reason without action execution.'
  if($LASTEXITCODE -ne 0){ Add-Err "runner_exit_code:$LASTEXITCODE" }
}
$afterDirs=@(); if(Test-Path $outputRoot){ $afterDirs=@(Get-ChildItem $outputRoot -Directory -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending) }
$newDir=$null
foreach($d in $afterDirs){ if($beforeDirs -notcontains $d.FullName){ $newDir=$d; break } }
if(-not $newDir -and $afterDirs.Count -gt 0){ $newDir=$afterDirs[0] }
$proofPath=$null; $spinePath=$null; $proof=$null; $spine=$null; $manifest=$null
if($newDir){
  $proofPath=Join-Path $newDir.FullName 'SANDBOX_EXPLORATION_PROOF.json'
  $spinePath=Join-Path $newDir.FullName 'next_build_task_decision_spine.json'
  $manifestPath=Join-Path $newDir.FullName 'sandbox_proof_pack_manifest.json'
  if(Test-Path $proofPath){ $proof=Get-Content $proofPath -Raw|ConvertFrom-Json } else { Add-Err 'proof_missing_after_run' }
  if(Test-Path $spinePath){ $spine=Get-Content $spinePath -Raw|ConvertFrom-Json } else { Add-Err 'spine_sidecar_missing_after_run' }
  if(Test-Path $manifestPath){ $manifest=Get-Content $manifestPath -Raw|ConvertFrom-Json } else { Add-Err 'manifest_missing_after_run' }
} else { Add-Err 'new_runtime_dir_missing' }
if($proof){
  if(-not $proof.PSObject.Properties['decision_spine']){ Add-Err 'proof_decision_spine_missing' }
  elseif($proof.decision_spine.status -ne 'PASS_NEXT_BUILD_TASK_DECISION_SPINE_V1'){ Add-Err "proof_decision_spine_status:$($proof.decision_spine.status)" }
  if($proof.boundary.action_execution_allowed -ne $false){ Add-Err 'action_execution_allowed_not_false' }
  if($proof.boundary.direct_active_memory_write -ne $false){ Add-Err 'direct_active_memory_write_not_false' }
  if(@($proof.decision_trace | Where-Object { $_.step -eq 'decision_spine' }).Count -ne 1){ Add-Err 'decision_trace_step_missing' }
}
if($spine){
  if($spine.status -ne 'PASS_NEXT_BUILD_TASK_DECISION_SPINE_V1'){ Add-Err "spine_status:$($spine.status)" }
  foreach($field in @('current_parent_goal','current_cycle_goal','selected_frontier','relevant_memory_refs','observed_gap','candidate_build_task','candidate_files_in','candidate_files_out','validator_target','proof_target','risk_boundary','blocked_reason','parent_goal_delta','utility_score','next_action_type')){ if(-not $spine.PSObject.Properties[$field]){ Add-Err "spine_missing_field:$field" } }
  if([string]::IsNullOrWhiteSpace([string]$spine.next_action_type)){ Add-Err 'next_action_type_empty' }
  $allowed=@('BUILD_TASK_CANDIDATE','AUDIT_TASK_CANDIDATE','REPAIR_TASK_CANDIDATE','BLOCKED_NEEDS_MEMORY_RETRIEVAL','BLOCKED_NEEDS_OWNER_DECISION','BLOCKED_NEEDS_PROOF','NO_OP_SAFE')
  if($allowed -notcontains [string]$spine.next_action_type){ Add-Err "next_action_type_invalid:$($spine.next_action_type)" }
  if([string]::IsNullOrWhiteSpace([string]$spine.candidate_build_task) -and [string]::IsNullOrWhiteSpace([string]$spine.blocked_reason)){ Add-Err 'candidate_and_blocked_reason_both_empty' }
  if($spine.queue_packet_is_final_action -ne $false){ Add-Err 'queue_packet_is_final_action_not_false' }
  if($spine.risk_boundary.action_execution_allowed -ne $false){ Add-Err 'risk_boundary_action_execution_not_false' }
}
if($manifest){ if(@($manifest.required_files) -notcontains 'next_build_task_decision_spine.json'){ Add-Err 'manifest_required_file_missing_spine' } }
$activeAfter=TreeStats '.runtime/active_compact_semantic_memory_v1'
if($activeBefore.files -ne $activeAfter.files -or $activeBefore.bytes -ne $activeAfter.bytes){ Add-Err 'active_memory_changed' }
$launcherHashAfter=(Get-FileHash 'operations/autonomous_inner_motor/start_agent_life_v1.ps1' -Algorithm SHA256).Hash
$runnerHashAfter=(Get-FileHash $runner -Algorithm SHA256).Hash
if($launcherHashBefore -ne $launcherHashAfter){ Add-Err 'launcher_hash_changed' }
if($runnerHashBefore -ne $runnerHashAfter){ Add-Err 'runner_hash_changed_during_validation' }
$procs=@(Get-CimInstance Win32_Process | Where-Object { $_.CommandLine -and $_.CommandLine -notmatch 'Get-CimInstance Win32_Process' -and $_.CommandLine -match 'start_agent_life_v1.ps1|run_autonomous_inner_motor.ps1|codex exec|node_modules.*@openai/codex|node.*codex.js|school|continuous_agent_runtime_v1' })
if($procs.Count -ne 0){ Add-Err "process_count_not_zero:$($procs.Count)" }
$status=if($errors.Count -eq 0){'PASS_NEXT_BUILD_TASK_DECISION_SPINE_V1'}else{'FAIL_NEXT_BUILD_TASK_DECISION_SPINE_V1'}
$canonical=[ordered]@{
  schema='next_build_task_decision_spine_v1_validation'
  status=$status
  checked_at=(Get-Date).ToUniversalTime().ToString('o')
  runner=$runner
  runtime_root=if($newDir){$newDir.FullName.Replace((Get-Location).Path+'\','')}else{$null}
  runtime_proof_path=if($proofPath){$proofPath.Replace((Get-Location).Path+'\','')}else{$null}
  spine_path=if($spinePath){$spinePath.Replace((Get-Location).Path+'\','')}else{$null}
  decision_spine=$spine
  proof_status=if($proof){$proof.status}else{$null}
  decision_trace_has_spine=if($proof){(@($proof.decision_trace | Where-Object { $_.step -eq 'decision_spine' }).Count -eq 1)}else{$false}
  manifest_has_spine=if($manifest){(@($manifest.required_files) -contains 'next_build_task_decision_spine.json')}else{$false}
  active_memory_before=$activeBefore
  active_memory_after=$activeAfter
  process_count=$procs.Count
  errors=@($errors)
  boundary=[ordered]@{runtime_launched_by_validator=$true; action_execution_allowed=$false; active_memory_mutated=$false; canonical_launcher_mutated=$false; direct_active_memory_write=$false; codex_launched=$false; web_launched=$false; school_launched=$false; ram_migration=$false}
}
WJson $canonicalProof $canonical
$accept=[ordered]@{
  schema='next_build_task_decision_spine_v1_acceptance'
  status=if($status -eq 'PASS_NEXT_BUILD_TASK_DECISION_SPINE_V1'){'ACCEPTED_NEXT_BUILD_TASK_DECISION_SPINE_V1_SLICE_A'}else{'REJECTED_NEXT_BUILD_TASK_DECISION_SPINE_V1_SLICE_A'}
  accepted_at=(Get-Date).ToUniversalTime().ToString('o')
  proof=$canonicalProof
  runtime_proof_path=$canonical.runtime_proof_path
  spine_path=$canonical.spine_path
  may_claim='Slice A adds decision_spine to canonical runner proof/manifest; each cycle now exposes explicit next_action_type and blocked_reason/candidate boundary.'
  may_not_claim=@('build task router complete','short-term memory repaired','compact retrieval repaired','RAM canonical migration complete','external actions executed')
  boundary=$canonical.boundary
}
WJson $acceptance $accept
Write-Host "STATUS=$status"
if($errors.Count -gt 0){ foreach($e in $errors){ Write-Host "ERROR=$e" }; exit 1 }
