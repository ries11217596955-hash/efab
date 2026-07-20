$ErrorActionPreference='Stop'
$errors=@()
function Add-Err([string]$e){ $script:errors += $e }
function WJson($path,$obj){ $dir=Split-Path $path -Parent; if($dir){New-Item -ItemType Directory -Force -Path $dir|Out-Null}; $json=($obj|ConvertTo-Json -Depth 100) -replace "`r`n","`n"; [System.IO.File]::WriteAllText((Join-Path (Get-Location).Path $path),$json.TrimEnd()+"`n",(New-Object System.Text.UTF8Encoding($false))) }
$report='operations/autonomous_inner_motor/reports/SCHOOL_AGENT_ATOM_CANDIDATE_PIPELINE_AUDIT_V1.json'
$nb='AGENT_BUILDER_SELF_NOTEBOOK.md'
foreach($p in @($report,$nb)){ if(-not(Test-Path $p)){ Add-Err "missing:$p" } }
$r=$null
if(Test-Path $report){ $r=Get-Content $report -Raw|ConvertFrom-Json }
if($r){
  if($r.status -ne 'PASS_SCHOOL_AGENT_ATOM_CANDIDATE_PIPELINE_AUDIT_V1'){ Add-Err "status_mismatch:$($r.status)" }
  foreach($step in @('school_first','agent_second','unified_throat_assessment_third')){ if(@($r.audit_order) -notcontains $step){ Add-Err "audit_order_missing:$step" } }
  if($r.school_audit.candidate_factory_exists -ne $true){ Add-Err 'school_candidate_factory_missing' }
  if($r.school_audit.digest_absorption_script_exists -ne $true){ Add-Err 'school_digest_absorption_missing' }
  if($r.school_audit.observed_school_packets_in_current_queue -ne 0){ Add-Err 'school_packets_unexpected_in_current_queue' }
  if($r.agent_audit.parsed_queue_packet_count -lt 1){ Add-Err 'agent_queue_packets_lt_1' }
  if(@($r.agent_audit.queue_groups | Where-Object { $_.source_kind -eq 'AgentLife' -and $_.packet_count -gt 0 }).Count -ne 1){ Add-Err 'agentlife_queue_group_missing' }
  if($r.agent_audit.boundary.direct_active_memory_write -ne $false){ Add-Err 'agent_direct_active_memory_write_not_false' }
  if($r.unified_throat_assessment.do_not_build_new_warehouse_from_zero -ne $true){ Add-Err 'do_not_build_new_warehouse_not_true' }
  if($r.unified_throat_assessment.required_next_contract -ne 'ATOM_CANDIDATE_UNIFIED_INTAKE_CONTRACT_V1'){ Add-Err 'required_next_contract_mismatch' }
  if(@($r.findings | Where-Object { $_.label -eq 'UNIFIED_INTAKE_CONTRACT_NOT_EXPLICITLY_PROVEN' }).Count -ne 1){ Add-Err 'finding_unified_contract_missing' }
  if($r.boundary.runtime_launched -ne $false){ Add-Err 'runtime_launched_not_false' }
  if($r.boundary.school_launched -ne $false){ Add-Err 'school_launched_not_false' }
  if($r.boundary.active_memory_mutated -ne $false){ Add-Err 'active_memory_mutated_not_false' }
}
$nbText=if(Test-Path $nb){Get-Content $nb -Raw}else{''}
foreach($needle in @('SCHOOL_AGENT_ATOM_CANDIDATE_PIPELINE_AUDIT_V1','Do not create a second store','ATOM_CANDIDATE_UNIFIED_INTAKE_CONTRACT_V1_SLICE_A','SHORT_TERM_MIND_STATE_V1_SLICE_A should use that outbox')){ if($nbText -notlike "*$needle*"){ Add-Err "notebook_missing:$needle" } }
$procs=@(Get-CimInstance Win32_Process | Where-Object { $_.ProcessId -ne $PID -and $_.CommandLine -and $_.CommandLine -notmatch 'Get-CimInstance Win32_Process|validate_school_agent_atom_candidate_pipeline_audit_v1.ps1' -and $_.CommandLine -match '\s-File\s+.*(start_agent_life_v1.ps1|run_autonomous_inner_motor.ps1|run_continuous_agent_runtime_v1_lab.ps1|school|invoke_body_self_inspection_circuit_v1.ps1)|codex exec|node_modules.*@openai/codex|node.*codex.js|continuous_agent_runtime_v1' })
if($procs.Count -ne 0){ Add-Err "process_count_not_zero:$($procs.Count)" }
$status=if($errors.Count -eq 0){'PASS_SCHOOL_AGENT_ATOM_CANDIDATE_PIPELINE_AUDIT_V1'}else{'FAIL_SCHOOL_AGENT_ATOM_CANDIDATE_PIPELINE_AUDIT_V1'}
$proof=[ordered]@{
  schema='school_agent_atom_candidate_pipeline_audit_v1_validation'
  status=$status
  checked_at=(Get-Date).ToUniversalTime().ToString('o')
  report=$report
  notebook=$nb
  school_status=if($r){$r.school_audit.status}else{$null}
  agent_status=if($r){$r.agent_audit.status}else{$null}
  agent_queue_packets=if($r){$r.agent_audit.parsed_queue_packet_count}else{$null}
  required_next_contract=if($r){$r.unified_throat_assessment.required_next_contract}else{$null}
  process_count=$procs.Count
  errors=@($errors)
  boundary=[ordered]@{audit_only=$true; runtime_launched=$false; school_launched=$false; active_memory_mutated=$false; direct_active_memory_write=$false}
}
WJson 'tests/self_development/SCHOOL_AGENT_ATOM_CANDIDATE_PIPELINE_AUDIT_V1_PROOF.json' $proof
Write-Host "STATUS=$status"
if($errors.Count -gt 0){ foreach($e in $errors){Write-Host "ERROR=$e"}; exit 1 }
