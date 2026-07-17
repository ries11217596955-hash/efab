$ErrorActionPreference='Stop'
$errors=@()
function Add-Err([string]$e){ $script:errors += $e }
function WJson($path,$obj){ $dir=Split-Path $path -Parent; if($dir){New-Item -ItemType Directory -Force -Path $dir|Out-Null}; $json=($obj|ConvertTo-Json -Depth 50) -replace "`r`n","`n"; [System.IO.File]::WriteAllText((Join-Path (Get-Location).Path $path),$json.TrimEnd()+"`n",(New-Object System.Text.UTF8Encoding($false))) }
function Parse-File($path){ $tokens=$null; $parseErrors=$null; [System.Management.Automation.Language.Parser]::ParseFile((Resolve-Path $path),[ref]$tokens,[ref]$parseErrors)|Out-Null; if(@($parseErrors).Count -gt 0){ Add-Err "parse_failed:$path" } }
$audit='operations/autonomous_inner_motor/audit_agent_life_single_launch_wiring_v1.ps1'
$report='operations/autonomous_inner_motor/reports/AGENT_LIFE_SINGLE_LAUNCH_WIRING_AUDIT_V1.json'
Parse-File $audit
& powershell -NoProfile -ExecutionPolicy Bypass -File $audit -OutputPath $report | Out-Null
if($LASTEXITCODE -ne 0){ Add-Err 'audit_exit_nonzero' }
$r=$null
if(Test-Path $report){ $r=Get-Content $report -Raw|ConvertFrom-Json } else { Add-Err 'audit_report_missing' }
if($r){
  if($r.status -ne 'PASS_AGENT_LIFE_SINGLE_LAUNCH_WIRING_AUDIT_V1'){ Add-Err "audit_status_not_pass:$($r.status)" }
  if($r.canonical_launcher.owner_parameters.parameter_name -ne 'DurationMinutes'){ Add-Err 'canonical_launcher_not_duration_only' }
  if($r.findings.canonical_launcher_controls_modes -ne $true){ Add-Err 'canonical_launcher_mode_contract_failed' }
  if($r.findings.runner_contains_current_mental_organs -ne $true){ Add-Err 'runner_current_organs_not_all_wired' }
  if($r.findings.selector_contains_current_action_candidates -ne $true){ Add-Err 'selector_current_candidates_missing' }
  if($r.findings.unknown_tracked_runner_references -and @($r.findings.unknown_tracked_runner_references).Count -gt 0){ Add-Err 'unknown_tracked_runner_references_present' }
  if($r.findings.frontier_referenced_not_invoked -notcontains 'BODY_SELF_INSPECTION_CIRCUIT_V1'){ Add-Err 'body_self_inspection_frontier_not_reported' }
  if([int]$r.findings.legacy_noncanonical_launch_surface_count -lt 1){ Add-Err 'legacy_noncanonical_launch_surfaces_not_reported' }
  $router= @($r.organ_wiring | Where-Object { $_.name -eq 'MENTAL_FRONTIER_ROUTER_V1' }) | Select-Object -First 1
  if(-not $router -or $router.wired_to_canonical -ne $true){ Add-Err 'mental_frontier_router_not_wired_to_canonical' }
}
$status=if($errors.Count -eq 0){'PASS_AGENT_LIFE_SINGLE_LAUNCH_WIRING_AUDIT_V1'}else{'FAIL_AGENT_LIFE_SINGLE_LAUNCH_WIRING_AUDIT_V1'}
$proof=[ordered]@{
  schema='agent_life_single_launch_wiring_audit_v1_validation'
  status=$status
  checked_at=(Get-Date).ToUniversalTime().ToString('o')
  audit_script=$audit
  audit_report=$report
  errors=@($errors)
  boundary=[ordered]@{ validator_did_not_start_agent_life=$true; active_memory_mutated=$false; live_process_touched=$false; codex_launched=$false; web_launched=$false; repair_executed=$false }
}
WJson 'tests/self_development/AGENT_LIFE_SINGLE_LAUNCH_WIRING_AUDIT_V1_PROOF.json' $proof
Write-Host "STATUS=$status"
if($errors.Count -gt 0){ foreach($e in $errors){Write-Host "ERROR=$e"}; exit 1 }
