$ErrorActionPreference='Stop'
$errors=@()
function Add-Err([string]$e){ $script:errors += $e }
function WJson($path,$obj){ $dir=Split-Path $path -Parent; if($dir){New-Item -ItemType Directory -Force -Path $dir|Out-Null}; $json=($obj|ConvertTo-Json -Depth 100) -replace "`r`n","`n"; [System.IO.File]::WriteAllText((Join-Path (Get-Location).Path $path),$json.TrimEnd()+"`n",(New-Object System.Text.UTF8Encoding($false))) }
$report='operations/autonomous_inner_motor/reports/EXISTING_MULTI_SOURCE_ATOM_THROAT_CORRECTION_V1.json'
$nb='AGENT_BUILDER_SELF_NOTEBOOK.md'
foreach($p in @($report,$nb)){ if(-not(Test-Path $p)){ Add-Err "missing:$p" } }
$r=$null
if(Test-Path $report){$r=Get-Content $report -Raw|ConvertFrom-Json}
if($r){
  if($r.status -ne 'PASS_EXISTING_MULTI_SOURCE_ATOM_THROAT_CORRECTION_V1'){ Add-Err "status_mismatch:$($r.status)" }
  if($r.correction_result -ne 'OWNER_CORRECT_PREVIOUS_NEXT_ACTION_WAS_TOO_DUPLICATIVE'){ Add-Err 'correction_result_mismatch' }
  foreach($p in @('submit_script','submit_and_merge_script','merge_script','memory_commit_controller','policy','doc')){
    $path=$r.existing_throat.$p
    if([string]::IsNullOrWhiteSpace([string]$path)){ Add-Err "existing_throat_missing_path:$p" }
    elseif(-not(Test-Path $path)){ Add-Err ("existing_throat_path_not_found:{0}:{1}" -f $p,$path) }
  }
  if([int]$r.evidence.merge_pass_count -lt 1){ Add-Err 'merge_pass_count_lt_1' }
  foreach($status in @('PASS_MULTI_SOURCE_COMPACT_MEMORY_MERGE_QUEUE_V1','PASS_SUBMIT_AND_MERGE_COMPACT_MEMORY_PACKET_V1','PASS_FINALIZER_AUTO_MERGE_QUEUE_V1')){ if(@($r.evidence.key_statuses) -notcontains $status){ Add-Err "key_status_missing:$status" } }
  if($r.corrected_interpretation.do_use_existing -ne 'MULTI_SOURCE_COMPACT_MEMORY_MERGE_QUEUE_V1'){ Add-Err 'do_use_existing_mismatch' }
  if($r.corrected_interpretation.next_repair_technical -ne 'SHORT_TERM_MIND_STATE_V1_SLICE_A_WITH_EXISTING_MULTI_SOURCE_INTAKE_ROUTE'){ Add-Err 'next_repair_mismatch' }
  if($r.boundary.no_new_store_created -ne $true){ Add-Err 'no_new_store_not_true' }
  if($r.boundary.active_memory_mutated -ne $false){ Add-Err 'active_memory_mutated_not_false' }
}
$nbText=if(Test-Path $nb){Get-Content $nb -Raw}else{''}
foreach($needle in @('EXISTING_MULTI_SOURCE_ATOM_THROAT_CORRECTION_V1','existing throat is MULTI_SOURCE_COMPACT_MEMORY_MERGE_QUEUE_V1','Do not create another warehouse','SHORT_TERM_MIND_STATE_V1_SLICE_A_WITH_EXISTING_MULTI_SOURCE_INTAKE_ROUTE')){ if($nbText -notlike "*$needle*"){ Add-Err "notebook_missing:$needle" } }
$procs=@(Get-CimInstance Win32_Process | Where-Object { $_.ProcessId -ne $PID -and $_.CommandLine -and $_.CommandLine -notmatch 'Get-CimInstance Win32_Process|validate_existing_multi_source_atom_throat_correction_v1.ps1' -and $_.CommandLine -match '\s-File\s+.*(start_agent_life_v1.ps1|run_autonomous_inner_motor.ps1|run_continuous_agent_runtime_v1_lab.ps1|school|invoke_body_self_inspection_circuit_v1.ps1)|codex exec|node_modules.*@openai/codex|node.*codex.js|continuous_agent_runtime_v1' })
if($procs.Count -ne 0){ Add-Err "process_count_not_zero:$($procs.Count)" }
$status=if($errors.Count -eq 0){'PASS_EXISTING_MULTI_SOURCE_ATOM_THROAT_CORRECTION_V1'}else{'FAIL_EXISTING_MULTI_SOURCE_ATOM_THROAT_CORRECTION_V1'}
$proof=[ordered]@{
  schema='existing_multi_source_atom_throat_correction_v1_validation'
  status=$status
  checked_at=(Get-Date).ToUniversalTime().ToString('o')
  report=$report
  notebook=$nb
  existing_throat=if($r){$r.existing_throat.name}else{$null}
  merge_pass_count=if($r){$r.evidence.merge_pass_count}else{$null}
  corrected_next=if($r){$r.corrected_interpretation.next_repair_technical}else{$null}
  process_count=$procs.Count
  errors=@($errors)
  boundary=[ordered]@{audit_correction_only=$true; runtime_launched=$false; school_launched=$false; active_memory_mutated=$false; direct_active_memory_write=$false; no_new_store_created=$true}
}
WJson 'tests/self_development/EXISTING_MULTI_SOURCE_ATOM_THROAT_CORRECTION_V1_PROOF.json' $proof
Write-Host "STATUS=$status"
if($errors.Count -gt 0){ foreach($e in $errors){Write-Host "ERROR=$e"}; exit 1 }
