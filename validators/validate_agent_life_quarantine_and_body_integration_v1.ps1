$ErrorActionPreference='Stop'
$errors=@()
function Add-Err([string]$e){ $script:errors += $e }
function WJson($path,$obj){ $dir=Split-Path $path -Parent; if($dir){New-Item -ItemType Directory -Force -Path $dir|Out-Null}; $json=($obj|ConvertTo-Json -Depth 40) -replace "`r`n","`n"; [System.IO.File]::WriteAllText((Join-Path (Get-Location).Path $path),$json.TrimEnd()+"`n",(New-Object System.Text.UTF8Encoding($false))) }
$quarantine='operations/autonomous_inner_motor/AGENT_LIFE_LEGACY_LAUNCH_QUARANTINE_V1.json'
$plan='operations/autonomous_inner_motor/BODY_SELF_INSPECTION_CANONICAL_INTEGRATION_PLAN_V1.md'
$audit='operations/autonomous_inner_motor/reports/AGENT_LIFE_SINGLE_LAUNCH_WIRING_AUDIT_V1.json'
if(-not(Test-Path $quarantine)){ Add-Err 'missing_quarantine_manifest' }
if(-not(Test-Path $plan)){ Add-Err 'missing_body_integration_plan' }
if(-not(Test-Path $audit)){ Add-Err 'missing_single_launch_audit_report' }
$q=$null; $r=$null; $planText=''
if(Test-Path $quarantine){ $q=Get-Content $quarantine -Raw|ConvertFrom-Json }
if(Test-Path $audit){ $r=Get-Content $audit -Raw|ConvertFrom-Json }
if(Test-Path $plan){ $planText=Get-Content $plan -Raw }
if($q){
  if($q.status -ne 'ACTIVE_QUARANTINE_MANIFEST'){ Add-Err 'quarantine_status_not_active' }
  if($q.canonical_owner_launch -notlike '*start_agent_life_v1.ps1 -DurationMinutes*'){ Add-Err 'canonical_launch_not_declared' }
  if(@($q.legacy_noncanonical_launch_surfaces).Count -lt 6){ Add-Err 'legacy_surface_count_too_low' }
  foreach($item in @($q.legacy_noncanonical_launch_surfaces)){
    if($item.forbidden_use -ne 'Owner-facing agent life launch'){ Add-Err "legacy_surface_not_forbidden:$($item.path)" }
  }
  if($q.boundary.legacy_files_modified -ne $false){ Add-Err 'legacy_files_modified_should_be_false' }
  if($q.boundary.deletion_performed -ne $false){ Add-Err 'deletion_performed_should_be_false' }
}
if($r){
  if($r.status -ne 'PASS_AGENT_LIFE_SINGLE_LAUNCH_WIRING_AUDIT_V1'){ Add-Err 'single_launch_audit_not_pass' }
  if($r.findings.frontier_referenced_not_invoked -notcontains 'BODY_SELF_INSPECTION_CIRCUIT_V1'){ Add-Err 'body_self_inspection_not_reported_as_frontier_reference' }
}
foreach($needle in @('INSTALL_READY_PLAN / NOT_WIRED','selected_frontier == body_self_inspection_signal','observe-only','repair_executed = false','BODY_SELF_INSPECTION_CANONICAL_OBSERVE_HOOK_V1','Do not run body self-inspection on every cycle','Do not execute repair drafts')){
  if($planText -notlike "*$needle*"){ Add-Err "plan_missing:$needle" }
}
$status=if($errors.Count -eq 0){'PASS_AGENT_LIFE_QUARANTINE_AND_BODY_INTEGRATION_V1'}else{'FAIL_AGENT_LIFE_QUARANTINE_AND_BODY_INTEGRATION_V1'}
$proof=[ordered]@{
  schema='agent_life_quarantine_and_body_integration_v1_validation'
  status=$status
  checked_at=(Get-Date).ToUniversalTime().ToString('o')
  quarantine_manifest=$quarantine
  body_integration_plan=$plan
  single_launch_audit=$audit
  errors=@($errors)
  boundary=[ordered]@{ validator_did_not_start_agent_life=$true; legacy_files_modified=$false; deletion_performed=$false; active_memory_mutated=$false; live_process_touched=$false; codex_launched=$false; web_launched=$false; body_inspection_invoked=$false }
}
WJson 'tests/self_development/AGENT_LIFE_QUARANTINE_AND_BODY_INTEGRATION_V1_PROOF.json' $proof
Write-Host "STATUS=$status"
if($errors.Count -gt 0){ foreach($e in $errors){Write-Host "ERROR=$e"}; exit 1 }
