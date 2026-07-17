$ErrorActionPreference='Stop'
$errors=@()
function Add-Err([string]$e){ $script:errors += $e }
function WJson($path,$obj){ $dir=Split-Path $path -Parent; if($dir){New-Item -ItemType Directory -Force -Path $dir|Out-Null}; $json=($obj|ConvertTo-Json -Depth 100) -replace "`r`n","`n"; [System.IO.File]::WriteAllText((Join-Path (Get-Location).Path $path),$json.TrimEnd()+"`n",(New-Object System.Text.UTF8Encoding($false))) }
$expected=@('body_audit_reflex','organ_audit_reflex','full_body_map_audit_reflex','repo_reality_reflex','process_scan_reflex','runtime_pressure_reflex','preflight_reflex','validator_run_reflex','proof_pack_reflex','rollback_reflex','quarantine_reflex','stop_or_freeze_reflex','memory_queue_reflex','active_memory_read_reflex','memory_digest_reflex','handoff_write_reflex','self_notebook_update_reflex','directory_create_reflex','file_normalize_reflex','archive_backup_reflex','artifact_convert_reflex','codex_consult_reflex','codex_task_authoring_reflex','web_source_search_reflex','source_ingestion_reflex')
$report='operations/autonomous_inner_motor/reports/REFLEX_DEBT_SOURCE_MAP_V1.json'
$old='operations/autonomous_inner_motor/reports/REFLECTION_DEBT_SOURCE_MAP_V1.json'
$plan='AGENT_BUILDER_INNATE_REFLEX_KERNEL_V1_PLAN.md'
$mind='AGENT_BUILDER_MIND_LOGIC_DEEP_AUDIT_PLAN_V1.md'
$nb='AGENT_BUILDER_SELF_NOTEBOOK.md'
foreach($p in @($report,$old,$plan,$mind,$nb)){ if(-not(Test-Path $p)){ Add-Err "missing:$p" } }
$planText=if(Test-Path $plan){Get-Content $plan -Raw}else{''}
foreach($id in $expected){ if($planText -notlike "*$id*"){ Add-Err "plan_missing_reflex:$id" } }
$r=$null
if(Test-Path $report){$r=Get-Content $report -Raw|ConvertFrom-Json}
if($r){
  if($r.status -ne 'PASS_REFLEX_DEBT_SOURCE_MAP_V1'){ Add-Err "status_mismatch:$($r.status)" }
  if([int]$r.plan_slot_count -ne 25){ Add-Err "slot_count_not_25:$($r.plan_slot_count)" }
  foreach($id in $expected){ if(@($r.plan_slots) -notcontains $id){ Add-Err "report_missing_reflex:$id" } }
  if($r.needed_audit -ne 'AUDIT_RX1_REFLEX_MATRIX_CURRENT_STATE_V1'){ Add-Err 'needed_audit_mismatch' }
  if($r.known_status -ne 'REFLEX_TRACK_PARTIAL_PROVEN'){ Add-Err 'known_status_mismatch' }
  foreach($id in @('body_audit_reflex','repo_reality_reflex','process_scan_reflex','runtime_pressure_reflex','active_memory_read_reflex')){ if(@($r.proven_or_wired_subset) -notcontains $id){ Add-Err "proven_subset_missing:$id" } }
  if($r.boundary.reflection_branch_marked_superseded -ne $true){ Add-Err 'reflection_not_marked_superseded' }
  if($r.boundary.runtime_launched -ne $false){ Add-Err 'runtime_launched_not_false' }
  if($r.boundary.active_memory_mutated -ne $false){ Add-Err 'active_memory_mutated_not_false' }
}
$oldJson=$null
if(Test-Path $old){$oldJson=Get-Content $old -Raw|ConvertFrom-Json}
if($oldJson){
  if($oldJson.active_planning_status -ne 'SUPERSEDED_BY_REFLEX_DEBT_SOURCE_MAP_V1_NOT_ACTIVE_OWNER_CONFIRMED'){ Add-Err 'old_report_not_superseded' }
  if($oldJson.superseded_by -ne $report){ Add-Err 'old_report_superseded_by_mismatch' }
}
$mindText=if(Test-Path $mind){Get-Content $mind -Raw}else{''}
foreach($needle in @('Correction — reflex debt is the active Owner-confirmed branch','REFLECTION_DEBT_SOURCE_MAP_V1 is not an Owner-confirmed active branch','Full matrix in that source contains 25 reserved reflex slots','AUDIT_RX1_REFLEX_MATRIX_CURRENT_STATE_V1')){ if($mindText -notlike "*$needle*"){ Add-Err "mind_missing:$needle" } }
$nbText=if(Test-Path $nb){Get-Content $nb -Raw}else{''}
foreach($needle in @('REFLEX_DEBT_CORRECTION_25_SLOT_MATRIX','Owner corrected: the discussed debt was reflexes','Correct count:','25 reserved reflex slots','Do not invent a separate reflection branch')){ if($nbText -notlike "*$needle*"){ Add-Err "notebook_missing:$needle" } }
$procs=@(Get-CimInstance Win32_Process | Where-Object { $_.CommandLine -and $_.CommandLine -notmatch 'Get-CimInstance Win32_Process' -and $_.CommandLine -match 'run_autonomous_inner_motor.ps1|start_agent_life_v1.ps1|invoke_body_self_inspection_circuit_v1.ps1|codex exec|node_modules.*@openai/codex|node.*codex.js|school|run_continuous_agent_runtime_v1_lab.ps1|continuous_agent_runtime_v1' })
if($procs.Count -ne 0){ Add-Err "process_count_not_zero:$($procs.Count)" }
$status=if($errors.Count -eq 0){'PASS_REFLEX_DEBT_SOURCE_MAP_V1'}else{'FAIL_REFLEX_DEBT_SOURCE_MAP_V1'}
$proof=[ordered]@{
  schema='reflex_debt_source_map_v1_validation'
  status=$status
  checked_at=(Get-Date).ToUniversalTime().ToString('o')
  report=$report
  superseded_report=$old
  primary_source=$plan
  plan_slot_count=25
  expected_slots=$expected
  process_count=$procs.Count
  errors=@($errors)
  boundary=[ordered]@{source_map_only=$true; runtime_launched=$false; active_memory_mutated=$false; reflex_registry_mutated=$false; old_reflection_branch_superseded=$true; canonical_launcher_mutated=$false; cycle_runner_mutated=$false}
}
WJson 'tests/self_development/REFLEX_DEBT_SOURCE_MAP_V1_PROOF.json' $proof
Write-Host "STATUS=$status"
if($errors.Count -gt 0){ foreach($e in $errors){Write-Host "ERROR=$e"}; exit 1 }
