$ErrorActionPreference='Stop'
$errors=@()
function Add-Err([string]$e){ $script:errors += $e }
function WJson($path,$obj){ $dir=Split-Path $path -Parent; if($dir){New-Item -ItemType Directory -Force -Path $dir|Out-Null}; $json=($obj|ConvertTo-Json -Depth 100) -replace "`r`n","`n"; [System.IO.File]::WriteAllText((Join-Path (Get-Location).Path $path),$json.TrimEnd()+"`n",(New-Object System.Text.UTF8Encoding($false))) }
function TreeStats($p){ if(-not(Test-Path $p)){ return [ordered]@{exists=$false; files=0; bytes=0} }; $files=@(Get-ChildItem $p -Recurse -File -Force -ErrorAction SilentlyContinue); return [ordered]@{exists=$true; files=$files.Count; bytes=[int64](($files|Measure-Object Length -Sum).Sum)} }
$runner='operations/autonomous_inner_motor/run_autonomous_inner_motor.ps1'
$outputRoot='.runtime/selective_compact_memory_retrieval_v1_validation'
$canonicalProof='tests/self_development/SELECTIVE_COMPACT_MEMORY_RETRIEVAL_V1_PROOF.json'
$acceptance='operations/autonomous_inner_motor/reports/SELECTIVE_COMPACT_MEMORY_RETRIEVAL_V1_ACCEPTANCE.json'
if(-not(Test-Path $runner)){ Add-Err "missing_runner:$runner" }
$tokens=$null;$parseErrors=$null
if(Test-Path $runner){ [System.Management.Automation.Language.Parser]::ParseFile((Resolve-Path $runner),[ref]$tokens,[ref]$parseErrors)|Out-Null; foreach($e in $parseErrors){ Add-Err "runner_parse:$($e.Message)" } }
$runnerText=if(Test-Path $runner){Get-Content $runner -Raw}else{''}
foreach($needle in @('function New-SelectiveCompactMemoryRetrieval','selective_compact_memory_retrieval.json','selective_compact_memory_retrieval=$selectiveCompactMemoryRetrieval','RELEVANT_COMPACT_MEMORY_RETRIEVED_BUT_NEXT_ORGAN_MISSING','SHORT_TERM_MIND_STATE_V1_SLICE_A')){ if($runnerText -notlike "*$needle*"){ Add-Err "runner_missing:$needle" } }
$activeBefore=TreeStats '.runtime/active_compact_semantic_memory_v1'
$launcherHashBefore=(Get-FileHash 'operations/autonomous_inner_motor/start_agent_life_v1.ps1' -Algorithm SHA256).Hash
$runnerHashBefore=(Get-FileHash $runner -Algorithm SHA256).Hash
$beforeDirs=@(); if(Test-Path $outputRoot){ $beforeDirs=@(Get-ChildItem $outputRoot -Directory -ErrorAction SilentlyContinue | Select-Object -ExpandProperty FullName) }
if($errors.Count -eq 0){
  powershell -NoProfile -ExecutionPolicy Bypass -File $runner -Mode SandboxExploration -EnableDeepThinking -MemoryIngestionMode QueueOnly -OutputRoot $outputRoot -Question 'Validate SELECTIVE_COMPACT_MEMORY_RETRIEVAL_V1: retrieve active compact memory refs and affect decision spine.'
  if($LASTEXITCODE -ne 0){ Add-Err "runner_exit_code:$LASTEXITCODE" }
}
$afterDirs=@(); if(Test-Path $outputRoot){ $afterDirs=@(Get-ChildItem $outputRoot -Directory -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending) }
$newDir=$null
foreach($d in $afterDirs){ if($beforeDirs -notcontains $d.FullName){ $newDir=$d; break } }
if(-not $newDir -and $afterDirs.Count -gt 0){ $newDir=$afterDirs[0] }
$proof=$null; $retrieval=$null; $spine=$null; $manifest=$null; $proofPath=$null; $retrievalPath=$null
if($newDir){
  $proofPath=Join-Path $newDir.FullName 'SANDBOX_EXPLORATION_PROOF.json'
  $retrievalPath=Join-Path $newDir.FullName 'selective_compact_memory_retrieval.json'
  $spinePath=Join-Path $newDir.FullName 'next_build_task_decision_spine.json'
  $manifestPath=Join-Path $newDir.FullName 'sandbox_proof_pack_manifest.json'
  if(Test-Path $proofPath){ $proof=Get-Content $proofPath -Raw|ConvertFrom-Json } else { Add-Err 'proof_missing_after_run' }
  if(Test-Path $retrievalPath){ $retrieval=Get-Content $retrievalPath -Raw|ConvertFrom-Json } else { Add-Err 'retrieval_sidecar_missing_after_run' }
  if(Test-Path $spinePath){ $spine=Get-Content $spinePath -Raw|ConvertFrom-Json } else { Add-Err 'decision_spine_sidecar_missing_after_run' }
  if(Test-Path $manifestPath){ $manifest=Get-Content $manifestPath -Raw|ConvertFrom-Json } else { Add-Err 'manifest_missing_after_run' }
}else{ Add-Err 'new_runtime_dir_missing' }
if($retrieval){
  if($retrieval.status -ne 'PASS_SELECTIVE_COMPACT_MEMORY_RETRIEVAL_V1'){ Add-Err "retrieval_status:$($retrieval.status)" }
  if([int]$retrieval.scanned_cells -lt 1){ Add-Err "scanned_cells_lt_1:$($retrieval.scanned_cells)" }
  if([int]$retrieval.selected_count -lt 1){ Add-Err "selected_count_lt_1:$($retrieval.selected_count)" }
  if($retrieval.active_memory_mutated -ne $false){ Add-Err 'retrieval_active_memory_mutated_not_false' }
  foreach($ref in @($retrieval.selected_memory_refs)){ if([string]::IsNullOrWhiteSpace([string]$ref.cell_id)){ Add-Err 'selected_ref_missing_cell_id' }; if([string]::IsNullOrWhiteSpace([string]$ref.source_ref)){ Add-Err 'selected_ref_missing_source_ref' } }
}
if($proof){
  if(-not $proof.PSObject.Properties['selective_compact_memory_retrieval']){ Add-Err 'proof_retrieval_field_missing' }
  elseif($proof.selective_compact_memory_retrieval.status -ne 'PASS_SELECTIVE_COMPACT_MEMORY_RETRIEVAL_V1'){ Add-Err "proof_retrieval_status:$($proof.selective_compact_memory_retrieval.status)" }
  if(@($proof.decision_trace | Where-Object { $_.step -eq 'selective_compact_memory_retrieval' }).Count -ne 1){ Add-Err 'decision_trace_retrieval_step_missing' }
  if($proof.decision_spine.next_action_type -eq 'BLOCKED_NEEDS_MEMORY_RETRIEVAL'){ Add-Err 'decision_spine_still_blocked_on_memory_retrieval' }
}
if($spine){
  if([int]$spine.relevant_memory_ref_count -lt 1){ Add-Err "spine_relevant_memory_ref_count_lt_1:$($spine.relevant_memory_ref_count)" }
  if($spine.next_action_type -ne 'REPAIR_TASK_CANDIDATE'){ Add-Err "spine_next_action_type_not_repair_candidate:$($spine.next_action_type)" }
  if($spine.candidate_build_task -notlike '*SHORT_TERM_MIND_STATE_V1_SLICE_A*'){ Add-Err "spine_candidate_build_task_unexpected:$($spine.candidate_build_task)" }
  if($spine.observed_gap -ne 'RELEVANT_COMPACT_MEMORY_RETRIEVED_BUT_NEXT_ORGAN_MISSING'){ Add-Err "spine_observed_gap_unexpected:$($spine.observed_gap)" }
}
if($manifest){ if(@($manifest.required_files) -notcontains 'selective_compact_memory_retrieval.json'){ Add-Err 'manifest_required_file_missing_retrieval' } }
$activeAfter=TreeStats '.runtime/active_compact_semantic_memory_v1'
if($activeBefore.files -ne $activeAfter.files -or $activeBefore.bytes -ne $activeAfter.bytes){ Add-Err 'active_memory_changed' }
$launcherHashAfter=(Get-FileHash 'operations/autonomous_inner_motor/start_agent_life_v1.ps1' -Algorithm SHA256).Hash
$runnerHashAfter=(Get-FileHash $runner -Algorithm SHA256).Hash
if($launcherHashBefore -ne $launcherHashAfter){ Add-Err 'launcher_hash_changed' }
if($runnerHashBefore -ne $runnerHashAfter){ Add-Err 'runner_hash_changed_during_validation' }
$procs=@(Get-CimInstance Win32_Process | Where-Object { $_.ProcessId -ne $PID -and $_.CommandLine -and $_.CommandLine -notmatch 'Get-CimInstance Win32_Process|validate_selective_compact_memory_retrieval_v1.ps1' -and $_.CommandLine -match '\\s-File\\s+.*(start_agent_life_v1.ps1|run_autonomous_inner_motor.ps1)|codex exec|node_modules.*@openai/codex|node.*codex.js|school|continuous_agent_runtime_v1' })
if($procs.Count -ne 0){ Add-Err "process_count_not_zero:$($procs.Count)" }
$status=if($errors.Count -eq 0){'PASS_SELECTIVE_COMPACT_MEMORY_RETRIEVAL_V1'}else{'FAIL_SELECTIVE_COMPACT_MEMORY_RETRIEVAL_V1'}
$canonical=[ordered]@{
  schema='selective_compact_memory_retrieval_v1_validation'
  status=$status
  checked_at=(Get-Date).ToUniversalTime().ToString('o')
  runner=$runner
  runtime_root=if($newDir){$newDir.FullName.Replace((Get-Location).Path+'\','')}else{$null}
  runtime_proof_path=if($proofPath){$proofPath.Replace((Get-Location).Path+'\','')}else{$null}
  retrieval_path=if($retrievalPath){$retrievalPath.Replace((Get-Location).Path+'\','')}else{$null}
  selective_compact_memory_retrieval=$retrieval
  decision_spine=$spine
  decision_effect=[ordered]@{ previous_next_action_type='BLOCKED_NEEDS_MEMORY_RETRIEVAL'; current_next_action_type=if($spine){$spine.next_action_type}else{$null}; changed_by_retrieval=if($spine){$spine.next_action_type -ne 'BLOCKED_NEEDS_MEMORY_RETRIEVAL'}else{$false} }
  manifest_has_retrieval=if($manifest){(@($manifest.required_files) -contains 'selective_compact_memory_retrieval.json')}else{$false}
  active_memory_before=$activeBefore
  active_memory_after=$activeAfter
  process_count=$procs.Count
  errors=@($errors)
  boundary=[ordered]@{runtime_launched_by_validator=$true; active_memory_mutated=$false; direct_active_memory_write=$false; action_execution_allowed=$false; canonical_launcher_mutated=$false; codex_launched=$false; web_launched=$false; school_launched=$false; ram_migration=$false}
}
WJson $canonicalProof $canonical
$accept=[ordered]@{
  schema='selective_compact_memory_retrieval_v1_acceptance'
  status=if($status -eq 'PASS_SELECTIVE_COMPACT_MEMORY_RETRIEVAL_V1'){'ACCEPTED_SELECTIVE_COMPACT_MEMORY_RETRIEVAL_V1_SLICE_A'}else{'REJECTED_SELECTIVE_COMPACT_MEMORY_RETRIEVAL_V1_SLICE_A'}
  accepted_at=(Get-Date).ToUniversalTime().ToString('o')
  proof=$canonicalProof
  runtime_proof_path=$canonical.runtime_proof_path
  retrieval_path=$canonical.retrieval_path
  may_claim='Slice A retrieves active compact memory refs and proves they affect decision_spine next_action_type.'
  may_not_claim=@('semantic retrieval is optimal','short-term memory built','frontier router built','agent executes build task autonomously','active memory was mutated')
  boundary=$canonical.boundary
}
WJson $acceptance $accept
Write-Host "STATUS=$status"
if($errors.Count -gt 0){ foreach($e in $errors){ Write-Host "ERROR=$e" }; exit 1 }
