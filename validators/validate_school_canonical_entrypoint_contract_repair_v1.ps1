$ErrorActionPreference='Stop'
$errors=@()
function AddErr([string]$e){ $script:errors += $e }
$entry='operations/school/run_agent_school.ps1'
$policy='operations/school/validate_agent_school_canonical_entrypoint_v1.ps1'
$proofPath='tests/self_development/SCHOOL_CANONICAL_ENTRYPOINT_CONTRACT_REPAIR_V1_PROOF.json'
$latestReport='operations/reports/CANONICAL_EXACT_COUNT_CYCLE_RUN_20260722_105408.json'
if(-not(Test-Path $entry)){ AddErr "missing_entry:$entry" }
if(-not(Test-Path $policy)){ AddErr "missing_policy:$policy" }
if(-not(Test-Path $latestReport)){ AddErr "missing_test_report:$latestReport" }
$entryText=''
if(Test-Path $entry){ $entryText=Get-Content $entry -Raw }
foreach($needle in @('SCHOOL_CANONICAL_ENTRYPOINT_CONTRACT_REPAIR_V1','operations/school/plan_topic_patch_cycle_v1.ps1','operations/school/finalize_agent_school_run_v1.ps1','finalizer_status','finalizer_hook')){
  if($entryText -notlike "*$needle*"){ AddErr "entry_missing:$needle" }
}
if($entryText -like '*FINALIZER_STATUS=SKIPPED_EXACT_COUNT_CYCLE_CANONICAL_ROUTE*'){ AddErr 'entry_still_skips_finalizer' }
$policyOut=@(& powershell -NoProfile -ExecutionPolicy Bypass -File $policy *>&1 | ForEach-Object{[string]$_})
$policyStatus=(($policyOut|Where-Object{$_ -match '^VALIDATION_STATUS='}|Select-Object -Last 1) -replace '^VALIDATION_STATUS=','')
if($policyStatus -ne 'PASS_AGENT_SCHOOL_CANONICAL_POLICY_V2'){ AddErr "policy_status:$policyStatus" }
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
