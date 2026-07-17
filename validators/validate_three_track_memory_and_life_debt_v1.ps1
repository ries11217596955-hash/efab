$ErrorActionPreference='Stop'
$errors=@()
function Add-Err([string]$e){ $script:errors += $e }
function WJson($path,$obj){ $dir=Split-Path $path -Parent; if($dir){New-Item -ItemType Directory -Force -Path $dir|Out-Null}; $json=($obj|ConvertTo-Json -Depth 100) -replace "`r`n","`n"; [System.IO.File]::WriteAllText((Join-Path (Get-Location).Path $path),$json.TrimEnd()+"`n",(New-Object System.Text.UTF8Encoding($false))) }
$mind='AGENT_BUILDER_MIND_LOGIC_DEEP_AUDIT_PLAN_V1.md'
$ram='AGENT_BUILDER_RAM_LIFE_TRANSITION_MASTER_PLAN_V1.md'
$nb='AGENT_BUILDER_SELF_NOTEBOOK.md'
$report='operations/autonomous_inner_motor/reports/THREE_TRACK_MEMORY_AND_LIFE_DEBT_V1.json'
foreach($p in @($mind,$ram,$nb,$report)){ if(-not(Test-Path $p)){ Add-Err "missing:$p" } }
$mindText=if(Test-Path $mind){Get-Content $mind -Raw}else{''}
foreach($needle in @('Three parallel memory/life tracks','Track A — Compact Memory','Track B — Short-Term Memory','Track C — RAM / life process','AUDIT_S1_SHORT_TERM_MEMORY_CURRENT_STATE_V1','AUDIT_R1_RAM_CANONICAL_MIGRATION_GAP_V1','SELECTIVE_COMPACT_MEMORY_RETRIEVAL_V1','SHORT_TERM_MIND_STATE_V1','RAM gives a different body. Compact memory and short-term memory give the mind usable context')){ if($mindText -notlike "*$needle*"){ Add-Err "mind_plan_missing:$needle" } }
$ramText=if(Test-Path $ram){Get-Content $ram -Raw}else{''}
foreach($needle in @('Open RAM debt marker','RAM lab is proven, but RAM is not canonical life','AUDIT_R1_RAM_CANONICAL_MIGRATION_GAP_V1','No migration claim without fresh proof')){ if($ramText -notlike "*$needle*"){ Add-Err "ram_plan_missing:$needle" } }
$nbText=if(Test-Path $nb){Get-Content $nb -Raw}else{''}
foreach($needle in @('THREE_TRACK_MEMORY_AND_LIFE_DEBT','Compact Memory: partial','Short-Term Memory: partial','RAM: proven lab only','Do not treat LIFE_WORKING_MEMORY_V1 as complete short-term memory')){ if($nbText -notlike "*$needle*"){ Add-Err "notebook_missing:$needle" } }
$r=$null
if(Test-Path $report){$r=Get-Content $report -Raw|ConvertFrom-Json}
if($r){
  if($r.status -ne 'PASS_THREE_TRACK_MEMORY_AND_LIFE_DEBT_V1'){ Add-Err "report_status_mismatch:$($r.status)" }
  if($r.tracks.compact_memory.status -ne 'PARTIAL'){ Add-Err 'compact_status_mismatch' }
  if($r.tracks.compact_memory.next_audit -ne 'AUDIT_M3_COMPACT_MEMORY_READ_PATH_V1'){ Add-Err 'compact_next_audit_mismatch' }
  if($r.tracks.short_term_memory.status -ne 'PARTIAL_NOT_FULL_ORGAN'){ Add-Err 'short_term_status_mismatch' }
  if($r.tracks.short_term_memory.next_audit -ne 'AUDIT_S1_SHORT_TERM_MEMORY_CURRENT_STATE_V1'){ Add-Err 'short_term_next_audit_mismatch' }
  if($r.tracks.ram_life_process.status -ne 'PROVEN_LAB_NOT_CANONICAL'){ Add-Err 'ram_status_mismatch' }
  if($r.tracks.ram_life_process.next_audit -ne 'AUDIT_R1_RAM_CANONICAL_MIGRATION_GAP_V1'){ Add-Err 'ram_next_audit_mismatch' }
  foreach($step in @('AUDIT_M1_CURRENT_MIND_TOPOLOGY_V1','AUDIT_M3_COMPACT_MEMORY_READ_PATH_V1','AUDIT_S1_SHORT_TERM_MEMORY_CURRENT_STATE_V1','AUDIT_M4_FRONTIER_TO_BUILD_TASK_GAP_V1')){ if(@($r.sequencing) -notcontains $step){ Add-Err "sequencing_missing:$step" } }
  if($r.boundary.runtime_launched -ne $false){ Add-Err 'runtime_launched_not_false' }
  if($r.boundary.active_memory_mutated -ne $false){ Add-Err 'active_memory_mutated_not_false' }
  if($r.boundary.ram_migrated -ne $false){ Add-Err 'ram_migrated_not_false' }
}
foreach($p in @('tests/self_development/CONTINUOUS_AGENT_RUNTIME_V1_LAB_PROOF.json','tests/self_development/LIFE_WORKING_MEMORY_V1_PROOF.json')){ if(-not(Test-Path $p)){ Add-Err "proof_missing:$p" } }
$procs=@(Get-CimInstance Win32_Process | Where-Object { $_.CommandLine -and $_.CommandLine -notmatch 'Get-CimInstance Win32_Process' -and $_.CommandLine -match 'run_autonomous_inner_motor.ps1|start_agent_life_v1.ps1|invoke_body_self_inspection_circuit_v1.ps1|codex exec|node_modules.*@openai/codex|node.*codex.js|school|run_continuous_agent_runtime_v1_lab.ps1|continuous_agent_runtime_v1' })
if($procs.Count -ne 0){ Add-Err "process_count_not_zero:$($procs.Count)" }
$status=if($errors.Count -eq 0){'PASS_THREE_TRACK_MEMORY_AND_LIFE_DEBT_V1'}else{'FAIL_THREE_TRACK_MEMORY_AND_LIFE_DEBT_V1'}
$proof=[ordered]@{
  schema='three_track_memory_and_life_debt_v1_validation'
  status=$status
  checked_at=(Get-Date).ToUniversalTime().ToString('o')
  report=$report
  mind_plan=$mind
  ram_plan=$ram
  notebook=$nb
  process_count=$procs.Count
  errors=@($errors)
  boundary=[ordered]@{plan_only=$true; runtime_launched=$false; active_memory_mutated=$false; canonical_launcher_mutated=$false; cycle_runner_mutated=$false; ram_migrated=$false}
}
WJson 'tests/self_development/THREE_TRACK_MEMORY_AND_LIFE_DEBT_V1_PROOF.json' $proof
Write-Host "STATUS=$status"
if($errors.Count -gt 0){ foreach($e in $errors){Write-Host "ERROR=$e"}; exit 1 }
