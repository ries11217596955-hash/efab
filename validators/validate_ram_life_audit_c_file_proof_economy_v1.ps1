$ErrorActionPreference='Stop'
$errors=@()
function Add-Err([string]$e){ $script:errors += $e }
function WJson($path,$obj){ $dir=Split-Path $path -Parent; if($dir){New-Item -ItemType Directory -Force -Path $dir|Out-Null}; $json=($obj|ConvertTo-Json -Depth 100) -replace "`r`n","`n"; [System.IO.File]::WriteAllText((Join-Path (Get-Location).Path $path),$json.TrimEnd()+"`n",(New-Object System.Text.UTF8Encoding($false))) }
$reportPath='operations/autonomous_inner_motor/reports/RAM_LIFE_AUDIT_C_FILE_PROOF_ECONOMY_V1.json'
if(-not(Test-Path $reportPath)){ Add-Err "missing:$reportPath" }
$r=$null
if(Test-Path $reportPath){ $r=Get-Content $reportPath -Raw | ConvertFrom-Json }
if($r){
  if($r.status -ne 'PASS_RAM_LIFE_AUDIT_C_FILE_PROOF_ECONOMY_V1'){ Add-Err "status_mismatch:$($r.status)" }
  if([double]$r.compact_memory_intake.total_mb -lt 1){ Add-Err 'total_mb_too_small_for_audit' }
  if([double]$r.compact_memory_intake.checkpoint_total_mb -lt 1){ Add-Err 'checkpoint_mb_too_small_for_audit' }
  if([double]$r.compact_memory_intake.queue_total_mb -gt 5){ Add-Err 'queue_too_large_unexpected' }
  if([double]$r.compact_memory_intake.checkpoint_delete_candidate_mb -lt 1){ Add-Err 'delete_candidate_mb_missing' }
  if($r.answer_to_owner_question.can_delete_all_711mb -ne 'NO_NOT_BLINDLY'){ Add-Err 'delete_all_answer_wrong' }
  if($r.answer_to_owner_question.can_delete_large_tail -ne 'YES_AFTER_RETENTION_GATE'){ Add-Err 'delete_tail_answer_wrong' }
  if($r.answer_to_owner_question.queue_should_not_be_deleted_blindly -ne $true){ Add-Err 'queue_guard_missing' }
  if($r.answer_to_owner_question.active_memory_must_not_be_touched -ne $true){ Add-Err 'active_memory_guard_missing' }
  if($r.proposed_retention_rule.status -ne 'PROPOSED_NOT_EXECUTED'){ Add-Err 'retention_rule_should_not_be_executed' }
  foreach($surface in @('active_compact_memory_root','compact_memory_intake_v1/queue','latest 3 compact_memory_intake checkpoints')){
    $found=$false
    foreach($x in @($r.classification.keep_now)){ if($x.surface -eq $surface){ $found=$true } }
    if(-not $found){ Add-Err "keep_surface_missing:$surface" }
  }
  if($r.boundary.audit_only -ne $true){ Add-Err 'audit_only_not_true' }
  if($r.boundary.files_deleted -ne $false){ Add-Err 'files_deleted_not_false' }
  if($r.boundary.runtime_mutated -ne $false){ Add-Err 'runtime_mutated_not_false' }
  if($r.boundary.active_memory_mutated -ne $false){ Add-Err 'active_memory_mutated_not_false' }
}
$procs=@(Get-CimInstance Win32_Process | Where-Object { $_.CommandLine -and $_.CommandLine -notmatch '\s-Command\s' -and $_.CommandLine -match 'run_autonomous_inner_motor.ps1|start_agent_life_v1.ps1|invoke_body_self_inspection_circuit_v1.ps1|codex exec|node.*codex|school|continuous' })
if($procs.Count -ne 0){ Add-Err "process_count_not_zero:$($procs.Count)" }
$status=if($errors.Count -eq 0){'PASS_RAM_LIFE_AUDIT_C_FILE_PROOF_ECONOMY_V1'}else{'FAIL_RAM_LIFE_AUDIT_C_FILE_PROOF_ECONOMY_V1'}
$proof=[ordered]@{
  schema='ram_life_audit_c_file_proof_economy_v1_validation'
  status=$status
  checked_at=(Get-Date).ToUniversalTime().ToString('o')
  report=$reportPath
  total_mb=if($r){$r.compact_memory_intake.total_mb}else{$null}
  checkpoint_mb=if($r){$r.compact_memory_intake.checkpoint_total_mb}else{$null}
  queue_mb=if($r){$r.compact_memory_intake.queue_total_mb}else{$null}
  delete_candidate_mb=if($r){$r.compact_memory_intake.checkpoint_delete_candidate_mb}else{$null}
  answer_to_owner_question=if($r){$r.answer_to_owner_question}else{$null}
  process_count=$procs.Count
  errors=@($errors)
  boundary=[ordered]@{ audit_only=$true; files_deleted=$false; runtime_mutated=$false; active_memory_mutated=$false; continuous_runtime_launched=$false; codex_launched=$false; web_launched=$false; school_launched=$false }
}
WJson 'tests/self_development/RAM_LIFE_AUDIT_C_FILE_PROOF_ECONOMY_V1_PROOF.json' $proof
Write-Host "STATUS=$status"
if($errors.Count -gt 0){ foreach($e in $errors){Write-Host "ERROR=$e"}; exit 1 }
