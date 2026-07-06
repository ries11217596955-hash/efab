$ErrorActionPreference='Stop'
$repoRoot=(git rev-parse --show-toplevel).Trim(); Set-Location $repoRoot
$utf8=New-Object System.Text.UTF8Encoding($false)
function RunSelect($label,[string[]]$selectArgs){
  $script='operations/school/curriculum/incremental_active_store/select_replay_audit_policy_v1.ps1'
  $cmdArgs=@('-NoProfile','-ExecutionPolicy','Bypass','-File',$script) + $selectArgs
  $out=& powershell @cmdArgs 2>&1
  $code=$LASTEXITCODE
  $report=Get-Content operations/reports/REPLAY_AUDIT_POLICY_SELECTION_V1.json -Raw|ConvertFrom-Json
  return [pscustomObject]@{
    label=$label
    exit_code=$code
    decision=$report.decision
    full_replay_required=$report.full_replay_required
    reasons=@($report.reasons)
    incoming_count=$report.incoming_count
    ledger_delta_count=$report.ledger_delta_count
    last_full_replay_delta_count=$report.last_full_replay_delta_count
    deltas_since_last_full_replay=$report.deltas_since_last_full_replay
    output=($out -join "`n")
  }
}
$small=RunSelect 'small_120_hot_path' @('-IncomingCount','120')
$large=RunSelect 'large_10000_requires_audit' @('-IncomingCount','10000')
$crash=RunSelect 'crash_requires_audit' @('-IncomingCount','120','-CrashRecovery')
$force=RunSelect 'force_requires_audit' @('-IncomingCount','120','-ForceFullReplay')
$ok=($small.exit_code -eq 0 -and $small.decision -eq 'SKIP_FULL_REPLAY_HOT_PATH_V1' -and $small.full_replay_required -eq $false -and $large.exit_code -eq 2 -and $large.full_replay_required -eq $true -and $large.decision -eq 'REQUIRE_FULL_REPLAY_AUDIT_V1' -and $crash.exit_code -eq 2 -and $crash.full_replay_required -eq $true -and $force.exit_code -eq 2 -and $force.full_replay_required -eq $true)
$status=if($ok){'PASS_REPLAY_AUDIT_POLICY_V1'}else{'FAIL_REPLAY_AUDIT_POLICY_V1'}
$report=[pscustomObject]@{
  schema='replay_audit_policy_validation_v1'
  status=$status
  runtime_ready=$false
  small_hot_path_decision=$small.decision
  small_hot_path_full_replay_required=$small.full_replay_required
  large_batch_decision=$large.decision
  crash_decision=$crash.decision
  force_decision=$force.decision
  cases=@($small,$large,$crash,$force)
  boundary='Validates policy decisions only; does not run full replay and does not absorb atoms.'
}
[IO.File]::WriteAllText((Join-Path (Get-Location).Path 'operations/reports/REPLAY_AUDIT_POLICY_V1.json'),($report|ConvertTo-Json -Depth 100),$utf8)
$md=@('# REPLAY_AUDIT_POLICY_V1','',"Status: $status",'Runtime ready: false','',"Small 120 decision: $($small.decision)","Large 10000 decision: $($large.decision)","Crash decision: $($crash.decision)","Force decision: $($force.decision)",'','Boundary: policy validation only; no replay rebuild.')
[IO.File]::WriteAllText((Join-Path (Get-Location).Path 'operations/reports/REPLAY_AUDIT_POLICY_V1.md'),($md -join "`r`n"),$utf8)
Write-Host "REPLAY_AUDIT_POLICY_STATUS=$status"
Write-Host "SMALL_120=$($small.decision)|required=$($small.full_replay_required)|exit=$($small.exit_code)|incoming=$($small.incoming_count)"
Write-Host "LARGE_10000=$($large.decision)|required=$($large.full_replay_required)|exit=$($large.exit_code)|incoming=$($large.incoming_count)|reasons=$($large.reasons -join ',')"
Write-Host "CRASH=$($crash.decision)|required=$($crash.full_replay_required)|exit=$($crash.exit_code)|reasons=$($crash.reasons -join ',')"
Write-Host "FORCE=$($force.decision)|required=$($force.full_replay_required)|exit=$($force.exit_code)|reasons=$($force.reasons -join ',')"
Write-Host "RUNTIME_READY=false"
if(-not $ok){ exit 1 }