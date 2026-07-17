$ErrorActionPreference='Stop'
$errors=@()
function Add-Err([string]$e){ $script:errors += $e }
function WJson($path,$obj){ $dir=Split-Path $path -Parent; if($dir){New-Item -ItemType Directory -Force -Path $dir|Out-Null}; $json=($obj|ConvertTo-Json -Depth 100) -replace "`r`n","`n"; [System.IO.File]::WriteAllText((Join-Path (Get-Location).Path $path),$json.TrimEnd()+"`n",(New-Object System.Text.UTF8Encoding($false))) }
$report='operations/autonomous_inner_motor/reports/DAILY_AUDIT_20260717_V1.json'
if(-not(Test-Path $report)){ Add-Err "missing:$report" }
$r=$null
if(Test-Path $report){ $r=Get-Content $report -Raw|ConvertFrom-Json }
if($r){
  if($r.status -ne 'PASS_DAILY_AUDIT_20260717_V1'){ Add-Err "status_mismatch:$($r.status)" }
  if($r.repo.clean -ne $true){ Add-Err 'repo_not_clean_in_report' }
  if($r.repo.ahead -ne '0' -or $r.repo.behind -ne '0'){ Add-Err "remote_delta_not_zero:$($r.repo.delta)" }
  if($r.process.count -ne 0){ Add-Err "process_count_not_zero:$($r.process.count)" }
  foreach($need in @('ram','compact_memory','short_term_memory','reflexes','canonical_life')){ if(-not $r.current_reality.PSObject.Properties[$need]){ Add-Err "current_reality_missing:$need" } }
  if($r.recommended_next_action -ne 'AUDIT_M1_CURRENT_MIND_TOPOLOGY_V1'){ Add-Err 'next_action_mismatch' }
  if($r.boundary.runtime_launched -ne $false){ Add-Err 'runtime_launched_not_false' }
  if($r.boundary.active_memory_mutated -ne $false){ Add-Err 'active_memory_mutated_not_false' }
  $runtime_size_paths_required=@('.runtime/active_compact_semantic_memory_v1','.runtime/compact_memory_intake_v1','.runtime/compact_memory_intake_v1/queue','.runtime/compact_memory_intake_v1/checkpoints','.runtime/live_trials','.runtime/continuous_agent_runtime_v1_lab')
  foreach($p in $runtime_size_paths_required){ if(@($r.runtime_sizes | Where-Object { $_.path -eq $p }).Count -ne 1){ Add-Err "runtime_size_missing:$p" } }
  if(@($r.runtime_sizes).Count -lt 6){ Add-Err "runtime_sizes_too_few:$(@($r.runtime_sizes).Count)" }
  if(@($r.key_proofs).Count -lt 7){ Add-Err 'key_proofs_too_few' }
  foreach($status in @($r.key_proofs | ForEach-Object {$_.status})){ if($status -like 'MISSING*' -or $status -eq 'UNREADABLE'){ Add-Err "bad_key_proof_status:$status" } }
}
$status=if($errors.Count -eq 0){'PASS_DAILY_AUDIT_20260717_V1'}else{'FAIL_DAILY_AUDIT_20260717_V1'}
$proof=[ordered]@{
  schema='daily_audit_v1_validation'
  status=$status
  checked_at=(Get-Date).ToUniversalTime().ToString('o')
  report=$report
  errors=@($errors)
  boundary=[ordered]@{validation_only=$true; runtime_launched=$false; active_memory_mutated=$false; canonical_launcher_mutated=$false; cycle_runner_mutated=$false}
}
WJson 'tests/self_development/DAILY_AUDIT_20260717_V1_PROOF.json' $proof
Write-Host "STATUS=$status"
if($errors.Count -gt 0){ foreach($e in $errors){ Write-Host "ERROR=$e" }; exit 1 }
