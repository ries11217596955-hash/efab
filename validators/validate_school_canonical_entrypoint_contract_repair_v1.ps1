$ErrorActionPreference='Stop'
$errors=@()
function AddErr([string]$e){ $script:errors += $e }
$entry='operations/school/run_agent_school.ps1'
$policy='operations/school/validate_agent_school_canonical_entrypoint_v1.ps1'
$finalizer='operations/school/finalize_agent_school_run_v1.ps1'
$lifecycle='operations/school/school_lifecycle_policy.json'
$proofPath='tests/self_development/SCHOOL_CANONICAL_ENTRYPOINT_CONTRACT_REPAIR_V1_PROOF.json'
$latestReport='operations/reports/CANONICAL_EXACT_COUNT_CYCLE_RUN_20260722_105408.json'
if(-not(Test-Path $entry)){ AddErr "missing_entry:$entry" }
if(-not(Test-Path $policy)){ AddErr "missing_policy:$policy" }
if(-not(Test-Path $finalizer)){ AddErr "missing_finalizer:$finalizer" }
if(-not(Test-Path $lifecycle)){ AddErr "missing_lifecycle:$lifecycle" }
if(-not(Test-Path $latestReport)){ AddErr "missing_test_report:$latestReport" }
$entryText=''
if(Test-Path $entry){ $entryText=Get-Content $entry -Raw }
if($entryText -notlike '*--dangerously-bypass-approvals-and-sandbox*'){ AddErr 'school_codex_bounded_bypass_missing' }
if($entryText -like '*-s workspace-write*'){ AddErr 'school_codex_workspace_write_sandbox_still_present' }
foreach($requiredPrompt in @('- Write exactly TARGET_COUNT JSONL candidate lines total across all batches.','- For each batch, write READY.jsonl directly, then write READY.marker.json.','- Write heartbeat and DONE marker after all batches are READY.','- Do not mutate active memory. Do not edit tracked repo files.')){
  if($entryText -notlike ('*'+$requiredPrompt+'*')){ AddErr ('school_codex_output_boundary_missing:'+ $requiredPrompt) }
}
if($entryText -notlike '*BOUNDED_BYPASS_WINDOWS_SYSTEM*'){ AddErr 'school_codex_execution_mode_event_missing' }
foreach($needle in @('Global\EFAB_SCHOOL_SINGLE_PUBLIC_LAUNCH_V1','System.Threading.Mutex','WaitOne(0,$false)','SCHOOL_SINGLE_INSTANCE_BLOCKED_ACTIVE_RUN','exit 73','ReleaseMutex()')){
  if(-not $entryText.Contains($needle)){ AddErr ('school_single_instance_guard_missing:'+ $needle) }
}
foreach($forbidden in @('school_singleton_v1','ACTIVE_RUN.lock.json','SCHOOL_SINGLETON_ACQUIRE_RACE')){
  if($entryText.Contains($forbidden)){ AddErr ('school_redundant_filesystem_singleton_present:'+ $forbidden) }
}
if($entryText -like '*$p.WaitForExit($CodexTimeoutSeconds*1000)*'){ AddErr 'school_streaming_waitforexit_before_consume_present' }
foreach($needle in @('STREAM_READY_DETECTED','STREAM_BATCH_CONSUMED','streaming_enabled','producer_completed_at','first_consume_started_at','stream_batches','overlap_proven','Invoke-SchoolWarehouseConsumer -MacroTaskJsonPath $taskJson -MaxConsumeBatches 1')){
  if($entryText -notlike ('*'+$needle+'*')){ AddErr ('school_streaming_contract_missing:'+ $needle) }
}
if($entryText -like '*try{ $producerCompletedAtValue=$p.ExitTime }catch{ $producerCompletedAtValue=Get-Date }*'){ AddErr 'school_streaming_exit_time_null_guard_missing' }
if($entryText -notlike '*if($null -ne $exitTime){ $producerCompletedAtValue=$exitTime }*'){ AddErr 'school_streaming_exit_time_null_guard_missing' }
if($entryText -notlike '*After writing each READY.marker.json, immediately continue producing the next batch without waiting for School consumption.*'){ AddErr 'school_streaming_prompt_continue_after_ready_missing' }
$agentsText=Get-Content 'AGENTS.md' -Raw
foreach($needle in @('C:\Users\Azerbaijan\.codex\.sandbox-bin\codex.exe','CODEX_HOME=C:\Users\Azerbaijan\.codex','--dangerously-bypass-approvals-and-sandbox','workspace-write','known non-working Windows/SYSTEM branch','do not install or create a second Codex')){
  if($agentsText -notlike ('*'+$needle+'*')){ AddErr ('agents_codex_windows_route_missing:'+ $needle) }
}
foreach($needle in @('SCHOOL_CANONICAL_ENTRYPOINT_CONTRACT_REPAIR_V1','operations/school/plan_topic_patch_cycle_v1.ps1','operations/school/finalize_agent_school_run_v1.ps1','finalizer_status','finalizer_hook')){
  if($entryText -notlike "*$needle*"){ AddErr "entry_missing:$needle" }
}
if($entryText -like '*FINALIZER_STATUS=SKIPPED_EXACT_COUNT_CYCLE_CANONICAL_ROUTE*'){ AddErr 'entry_still_skips_finalizer' }
$policyOut=@(& powershell -NoProfile -ExecutionPolicy Bypass -File $policy *>&1 | ForEach-Object{[string]$_})
$policyStatus=(($policyOut|Where-Object{$_ -match '^VALIDATION_STATUS='}|Select-Object -Last 1) -replace '^VALIDATION_STATUS=','')
if($policyStatus -ne 'PASS_AGENT_SCHOOL_CANONICAL_POLICY_V2'){ AddErr "policy_status:$policyStatus" }
$finalizerText=if(Test-Path $finalizer){Get-Content $finalizer -Raw}else{''}
$lifecycleJson=if(Test-Path $lifecycle){Get-Content $lifecycle -Raw|ConvertFrom-Json}else{$null}
if($finalizerText -notlike '*$intakeAllowed = @($finalizer.intake_modes) -contains $publicMode*'){ AddErr 'finalizer_intake_mode_gate_missing' }
if($finalizerText -notlike '*SKIPPED_FINALIZER_INTAKE_MODE_NOT_ALLOWED*'){ AddErr 'finalizer_test_skip_status_missing' }
if($finalizerText -like '*Use fresh school memory before next autonomous path selection; prefer tasks that exploit newly accepted concepts.*'){ AddErr 'finalizer_summary_recency_selects_next_topic' }
if($finalizerText -notlike '*Select the next topic/path independently from Owner task, parent task, fresh reality, gaps, priorities, safety, and bounded exploration; only after selection, retrieve fresh school memory when it is relevant. Recency or the latest School run must not choose the next topic.*'){ AddErr 'finalizer_summary_post_selection_relevance_rule_missing' }
if($lifecycleJson){
  $intakeModes=@($lifecycleJson.finalizer.intake_modes)
  if($intakeModes.Count -ne 1 -or $intakeModes[0] -ne 'Live'){ AddErr ('lifecycle_intake_modes:'+($intakeModes -join ',')) }
  if($intakeModes -contains 'Test'){ AddErr 'test_mode_must_not_be_intake_mode' }
}
$r=$null
if(Test-Path $latestReport){ $r=Get-Content $latestReport -Raw|ConvertFrom-Json }
if($r){
  if($r.status -ne 'PASS_CANONICAL_EXACT_COUNT_CYCLE_TEST_V1'){ AddErr "test_status:$($r.status)" }
  if([int]$r.accepted_count -ne 1){ AddErr "accepted_count:$($r.accepted_count)" }
  if($r.finalizer_status -ne 'FINALIZER_RUNTIME_ONLY_MODE_NOT_COMMITTABLE'){ AddErr "finalizer_status:$($r.finalizer_status)" }
  if($r.finalizer_hook -ne 'operations/school/finalize_agent_school_run_v1.ps1'){ AddErr "finalizer_hook:$($r.finalizer_hook)" }
  if(@($r.finalizer_output).Count -lt 5){ AddErr "finalizer_output_too_short:$(@($r.finalizer_output).Count)" }
  if([bool]$r.absorb -ne $false){ AddErr 'test_absorb_not_false' }
  if([bool]$r.memory_changed -ne $false){ AddErr 'test_memory_changed_not_false' }
}
$procs=@(Get-CimInstance Win32_Process | Where-Object {
  $_.ProcessId -ne $PID -and $_.CommandLine -and
  $_.CommandLine -notmatch 'Get-CimInstance Win32_Process|validate_school_canonical_entrypoint_contract_repair_v1.ps1' -and
  $_.CommandLine -match '\s-File\s+.*(run_agent_school.ps1|start_agent_life_v1.ps1|run_autonomous_inner_motor.ps1|school|validate_)|codex exec|node_modules.*@openai/codex|node.*codex.js'
})
if($procs.Count -ne 0){ AddErr "process_count_not_zero:$($procs.Count)" }
$status=if($errors.Count -eq 0){'PASS_SCHOOL_CANONICAL_ENTRYPOINT_CONTRACT_REPAIR_V1'}else{'FAIL_SCHOOL_CANONICAL_ENTRYPOINT_CONTRACT_REPAIR_V1'}
$proof=[ordered]@{
  schema='school_canonical_entrypoint_contract_repair_v1'
  status=$status
  checked_at=(Get-Date).ToUniversalTime().ToString('o')
  entrypoint=$entry
  owner_command='powershell -NoProfile -ExecutionPolicy Bypass -File operations/school/run_agent_school.ps1 -Count <N> -Mode Live -Topics AUTO'
  policy_validator=$policy
  policy_status=$policyStatus
  finalizer=$finalizer
  lifecycle=$lifecycle
  finalizer_intake_modes=if($lifecycleJson){@($lifecycleJson.finalizer.intake_modes)}else{@()}
  test_intake_allowed=if($lifecycleJson){@($lifecycleJson.finalizer.intake_modes) -contains 'Test'}else{$null}
  test_report=$latestReport
  test_status=if($r){$r.status}else{$null}
  test_accepted_count=if($r){$r.accepted_count}else{$null}
  finalizer_status=if($r){$r.finalizer_status}else{$null}
  finalizer_hook=if($r){$r.finalizer_hook}else{$null}
  finalizer_output_count=if($r){@($r.finalizer_output).Count}else{0}
  process_count=$procs.Count
  errors=@($errors)
  boundary=[ordered]@{
    school_live_launched=$false
    test_count_1_launched=$true
    active_memory_absorb=$false
    memory_changed=$false
    no_duplicate_owner_launcher=$true
    external_access=$false
    codex_launched=$false
  }
}
$dir=Split-Path $proofPath -Parent
if($dir){New-Item -ItemType Directory -Force -Path $dir|Out-Null}
$proof|ConvertTo-Json -Depth 100|Set-Content -LiteralPath $proofPath -Encoding UTF8
Write-Host "STATUS=$status"
Write-Host "PROOF_PATH=$proofPath"
if($errors.Count -gt 0){$errors|ForEach-Object{Write-Host "ERROR=$_"}; exit 1}
