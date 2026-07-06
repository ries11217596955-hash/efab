param(
  [int]$IncomingCount=0,
  [switch]$ForceFullReplay,
  [switch]$CrashRecovery,
  [switch]$BeforeLive,
  [switch]$BeforeAcceptedCore,
  [string]$PolicyPath='operations/school/curriculum/incremental_active_store/ACTIVE_REPO_BODY_REPLAY_AUDIT_POLICY_V1.json',
  [string]$ReplayLedgerPath='operations/school/curriculum/incremental_active_store/ACTIVE_REPO_BODY_ROUTE_REPLAY_LEDGER_V1.json',
  [string]$LastReplayReportPath='operations/reports/REPLAYABLE_INCREMENTAL_ACTIVE_ROUTE_V1.json'
)
$ErrorActionPreference='Stop'
$repoRoot=(git rev-parse --show-toplevel).Trim(); Set-Location $repoRoot
$utf8=New-Object System.Text.UTF8Encoding($false)
function WriteJson($p,$o,$d=80){$dir=Split-Path -Parent $p; if($dir){New-Item -ItemType Directory -Force -Path $dir|Out-Null}; [IO.File]::WriteAllText((Join-Path (Get-Location).Path $p),($o|ConvertTo-Json -Depth $d),$utf8)}
$policy=Get-Content $PolicyPath -Raw|ConvertFrom-Json
$ledger=Get-Content $ReplayLedgerPath -Raw|ConvertFrom-Json
$ledgerDeltaCount=@($ledger.deltas).Count
$lastReplayDeltaCount=0
$lastReplayStatus='MISSING_LAST_REPLAY_REPORT'
if(Test-Path $LastReplayReportPath){
  $last=Get-Content $LastReplayReportPath -Raw|ConvertFrom-Json
  $lastReplayStatus=[string]$last.status
  $lastReplayDeltaCount=[int]$last.delta_count
}
$deltasSince=[Math]::Max(0, $ledgerDeltaCount - $lastReplayDeltaCount)
$reasons=@()
if($ForceFullReplay){ $reasons += 'force_full_replay' }
if($CrashRecovery -and $policy.require_full_replay_after_crash){ $reasons += 'crash_recovery' }
if($BeforeLive -and $policy.require_full_replay_before_live){ $reasons += 'before_live' }
if($BeforeAcceptedCore -and $policy.require_full_replay_before_accepted_core){ $reasons += 'before_accepted_core' }
if($IncomingCount -ge [int]$policy.max_incoming_without_replay){ $reasons += "incoming_count_gte_$($policy.max_incoming_without_replay)" }
if($deltasSince -ge [int]$policy.max_deltas_since_full_replay){ $reasons += "deltas_since_full_replay_gte_$($policy.max_deltas_since_full_replay)" }
if($lastReplayStatus -ne 'PASS_REPLAYABLE_INCREMENTAL_ACTIVE_ROUTE_V1'){ $reasons += 'last_full_replay_not_pass' }
$require=($reasons.Count -gt 0)
$status=if($require){'REQUIRE_FULL_REPLAY_AUDIT_V1'}else{'SKIP_FULL_REPLAY_HOT_PATH_V1'}
$report=[pscustomObject]@{
  schema='replay_audit_policy_selection_v1'
  status='PASS_REPLAY_AUDIT_POLICY_SELECTION_V1'
  runtime_ready=$false
  decision=$status
  full_replay_required=$require
  incoming_count=$IncomingCount
  policy_mode=$policy.policy_mode
  ledger_delta_count=$ledgerDeltaCount
  last_full_replay_delta_count=$lastReplayDeltaCount
  deltas_since_last_full_replay=$deltasSince
  max_deltas_since_full_replay=$policy.max_deltas_since_full_replay
  max_incoming_without_replay=$policy.max_incoming_without_replay
  reasons=@($reasons)
  hot_path_allowed=(-not $require)
  cold_audit_command='operations/school/curriculum/incremental_active_store/validate_replayable_incremental_active_route_v1.ps1'
  boundary='Policy selection only; does not run replay rebuild and does not absorb atoms.'
}
WriteJson 'operations/reports/REPLAY_AUDIT_POLICY_SELECTION_V1.json' $report 80
$md=@('# REPLAY_AUDIT_POLICY_SELECTION_V1','',"Status: $($report.status)",'Runtime ready: false','',"Decision: $($report.decision)","Full replay required: $($report.full_replay_required)","Incoming count: $IncomingCount","Ledger deltas: $ledgerDeltaCount","Last full replay delta count: $lastReplayDeltaCount","Deltas since last full replay: $deltasSince","Reasons: $($reasons -join ', ')",'','Boundary: selection only; no replay rebuild.')
[IO.File]::WriteAllText((Join-Path (Get-Location).Path 'operations/reports/REPLAY_AUDIT_POLICY_SELECTION_V1.md'),($md -join "`r`n"),$utf8)
Write-Host "REPLAY_AUDIT_SELECTION_STATUS=$($report.status)"
Write-Host "DECISION=$($report.decision)"
Write-Host "FULL_REPLAY_REQUIRED=$($report.full_replay_required)"
Write-Host "INCOMING_COUNT=$IncomingCount"
Write-Host "LEDGER_DELTAS=$ledgerDeltaCount"
Write-Host "LAST_FULL_REPLAY_DELTAS=$lastReplayDeltaCount"
Write-Host "DELTAS_SINCE_FULL_REPLAY=$deltasSince"
Write-Host "REASONS=$($reasons -join ',')"
Write-Host "RUNTIME_READY=false"
if($require){ exit 2 } else { exit 0 }