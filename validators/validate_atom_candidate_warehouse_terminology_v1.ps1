$ErrorActionPreference='Stop'
$errors=@()
function Add-Err([string]$e){ $script:errors += $e }
function WJson($path,$obj){
  $dir=Split-Path $path -Parent
  if($dir){ New-Item -ItemType Directory -Force -Path $dir | Out-Null }
  $json=($obj|ConvertTo-Json -Depth 100) -replace "`r`n","`n"
  [System.IO.File]::WriteAllText((Join-Path (Get-Location).Path $path),$json.TrimEnd()+"`n",(New-Object System.Text.UTF8Encoding($false)))
}
$report='operations/autonomous_inner_motor/reports/ATOM_CANDIDATE_WAREHOUSE_TERMINOLOGY_V1.json'
$nb='AGENT_BUILDER_SELF_NOTEBOOK.md'
foreach($p in @($report,$nb)){ if(-not(Test-Path $p)){ Add-Err "missing:$p" } }
$r=$null
if(Test-Path $report){ $r=Get-Content $report -Raw|ConvertFrom-Json }
if($r){
  if($r.status -ne 'PASS_ATOM_CANDIDATE_WAREHOUSE_TERMINOLOGY_V1'){ Add-Err "status_mismatch:$($r.status)" }
  if($r.shared_understanding.throat -notlike '*Existing multi-source pipeline*'){ Add-Err 'throat_definition_missing' }
  if($r.shared_understanding.warehouse -notlike '*Temporary queue/staging/backlog*'){ Add-Err 'warehouse_definition_missing' }
  if($r.existing_mapping.throat_name -ne 'MULTI_SOURCE_COMPACT_MEMORY_MERGE_QUEUE_V1 + MEMORY_COMMIT_ORGAN_V1'){ Add-Err 'throat_name_mismatch' }
  foreach($field in @('queue_root','merge_root','processed_root','active_compact_memory_root','submit_script','submit_and_merge_script','merge_script','memory_commit_controller')){
    if(-not $r.existing_mapping.PSObject.Properties[$field]){ Add-Err "mapping_missing:$field" }
  }
  foreach($rule in @('do_not_create_duplicate_candidate_store','short_term_mind_state_holds_active_thought_only','live_atom_candidate_goes_to_existing_queue_or_submit_route','no_direct_active_memory_write')){
    if(@($r.rules) -notcontains $rule){ Add-Err "rule_missing:$rule" }
  }
  if($r.corrected_next_technical -ne 'SHORT_TERM_MIND_STATE_V1_SLICE_A_WITH_EXISTING_MULTI_SOURCE_INTAKE_ROUTE'){ Add-Err 'next_technical_mismatch' }
  if($r.boundary.no_new_store_created -ne $true){ Add-Err 'no_new_store_not_true' }
  if($r.boundary.active_memory_mutated -ne $false){ Add-Err 'active_memory_mutated_not_false' }
  if($r.boundary.runtime_launched -ne $false){ Add-Err 'runtime_launched_not_false' }
}
$nbText=if(Test-Path $nb){Get-Content $nb -Raw}else{''}
foreach($needle in @('ATOM_CANDIDATE_WAREHOUSE_TERMINOLOGY_V1','THROAT = the existing multi-source path','WAREHOUSE = temporary queue/staging/backlog inside that existing throat','no duplicate warehouse','SHORT_TERM_MIND_STATE_V1_SLICE_A_WITH_EXISTING_MULTI_SOURCE_INTAKE_ROUTE')){
  if($nbText -notlike "*$needle*"){ Add-Err "notebook_missing:$needle" }
}
$procs=@(Get-CimInstance Win32_Process | Where-Object { $_.ProcessId -ne $PID -and $_.CommandLine -and $_.CommandLine -notmatch 'Get-CimInstance Win32_Process|validate_atom_candidate_warehouse_terminology_v1.ps1' -and $_.CommandLine -match '\s-File\s+.*(start_agent_life_v1.ps1|run_autonomous_inner_motor.ps1|run_continuous_agent_runtime_v1_lab.ps1|school|invoke_body_self_inspection_circuit_v1.ps1)|codex exec|node_modules.*@openai/codex|node.*codex.js|continuous_agent_runtime_v1' })
if($procs.Count -ne 0){ Add-Err "process_count_not_zero:$($procs.Count)" }
$status=if($errors.Count -eq 0){'PASS_ATOM_CANDIDATE_WAREHOUSE_TERMINOLOGY_V1'}else{'FAIL_ATOM_CANDIDATE_WAREHOUSE_TERMINOLOGY_V1'}
$proof=[ordered]@{
  schema='atom_candidate_warehouse_terminology_v1_validation'
  status=$status
  checked_at=(Get-Date).ToUniversalTime().ToString('o')
  report=$report
  notebook=$nb
  throat=if($r){$r.existing_mapping.throat_name}else{$null}
  warehouse=if($r){$r.shared_understanding.warehouse}else{$null}
  queue_file_count=if($r){$r.observed_state.queue_file_count}else{$null}
  merge_result_file_count=if($r){$r.observed_state.merge_result_file_count}else{$null}
  corrected_next=if($r){$r.corrected_next_technical}else{$null}
  process_count=$procs.Count
  errors=@($errors)
  boundary=[ordered]@{terminology_update_only=$true; runtime_launched=$false; school_launched=$false; active_memory_mutated=$false; direct_active_memory_write=$false; no_new_store_created=$true}
}
WJson 'tests/self_development/ATOM_CANDIDATE_WAREHOUSE_TERMINOLOGY_V1_PROOF.json' $proof
Write-Host "STATUS=$status"
if($errors.Count -gt 0){ foreach($e in $errors){Write-Host "ERROR=$e"}; exit 1 }
