$ErrorActionPreference='Stop'
$errors=@()
function Add-Err([string]$e){ $script:errors += $e }
function WJson($path,$obj){ $dir=Split-Path $path -Parent; if($dir){New-Item -ItemType Directory -Force -Path $dir|Out-Null}; $json=($obj|ConvertTo-Json -Depth 100) -replace "`r`n","`n"; [System.IO.File]::WriteAllText((Join-Path (Get-Location).Path $path),$json.TrimEnd()+"`n",(New-Object System.Text.UTF8Encoding($false))) }
$report='operations/autonomous_inner_motor/reports/REFLEX_USAGE_DURING_THINKING_AUDIT_V1.json'
if(-not(Test-Path $report)){ Add-Err "missing_report:$report" }
$r=$null
if(Test-Path $report){ $r=Get-Content $report -Raw|ConvertFrom-Json }
if($r){
  if($r.status -ne 'PASS_REFLEX_USAGE_DURING_THINKING_AUDIT_V1'){ Add-Err "status:$($r.status)" }
  if([int]$r.reserved_reflex_slots -ne 25){ Add-Err "reserved_count:$($r.reserved_reflex_slots)" }
  if([int]$r.active_in_latest_thinking_cycle -ne 5){ Add-Err "active_count:$($r.active_in_latest_thinking_cycle)" }
  foreach($name in @('body_audit_reflex','repo_reality_reflex','process_scan_reflex','runtime_pressure_reflex','active_memory_read_reflex')){
    if(@($r.active_reflexes | Where-Object { $_.reflex -eq $name }).Count -ne 1){ Add-Err "missing_active:$name" }
  }
  foreach($name in @('organ_audit_reflex','validator_run_reflex','memory_queue_reflex','directory_create_reflex','codex_task_authoring_reflex','web_source_search_reflex','source_ingestion_reflex')){
    if(@($r.inactive_reserved_reflexes | Where-Object { $_.reflex -eq $name }).Count -ne 1){ Add-Err "missing_inactive:$name" }
  }
  if($r.usage_answer.uses_reflexes_during_thinking -ne $true){ Add-Err 'uses_reflexes_false' }
  if($r.boundary.audit_only -ne $true){ Add-Err 'boundary_audit_only_false' }
}
$procs=@(Get-CimInstance Win32_Process | Where-Object { $_.ProcessId -ne $PID -and $_.CommandLine -and $_.CommandLine -notmatch 'Get-CimInstance Win32_Process|validate_reflex_usage_during_thinking_audit_v1.ps1' -and $_.CommandLine -match '\s-File\s+.*(start_agent_life_v1.ps1|run_autonomous_inner_motor.ps1|run_continuous_agent_runtime_v1_lab.ps1|school|invoke_body_self_inspection_circuit_v1.ps1)|codex exec|node_modules.*@openai/codex|node.*codex.js|continuous_agent_runtime_v1|validate_' })
if($procs.Count -ne 0){ Add-Err "process_count_not_zero:$($procs.Count)" }
$status=if($errors.Count -eq 0){'PASS_REFLEX_USAGE_DURING_THINKING_AUDIT_V1'}else{'FAIL_REFLEX_USAGE_DURING_THINKING_AUDIT_V1'}
$proof=[ordered]@{schema='reflex_usage_during_thinking_audit_v1_validation';status=$status;checked_at=(Get-Date).ToUniversalTime().ToString('o');report=$report;reserved_reflex_slots=if($r){$r.reserved_reflex_slots}else{$null};active_in_latest_thinking_cycle=if($r){$r.active_in_latest_thinking_cycle}else{$null};active_reflexes=if($r){@($r.active_reflexes|Select-Object -ExpandProperty reflex)}else{@()};process_count=$procs.Count;errors=@($errors);boundary=[ordered]@{audit_only=$true;runtime_launched_by_validator=$false;active_memory_mutated_by_validator=$false;repo_mutation_by_validator=$false}}
WJson 'tests/self_development/REFLEX_USAGE_DURING_THINKING_AUDIT_V1_PROOF.json' $proof
Write-Host "STATUS=$status"
if($errors.Count -gt 0){ foreach($e in $errors){ Write-Host "ERROR=$e" }; exit 1 }
