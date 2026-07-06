$ErrorActionPreference='Stop'
$repoRoot=(git rev-parse --show-toplevel).Trim(); Set-Location $repoRoot
$utf8=New-Object System.Text.UTF8Encoding($false)
function WriteJson($p,$o,$d=80){$dir=Split-Path -Parent $p; if($dir){New-Item -ItemType Directory -Force -Path $dir|Out-Null}; [IO.File]::WriteAllText((Join-Path (Get-Location).Path $p),($o|ConvertTo-Json -Depth $d),$utf8)}
$routeBefore=Get-Content operations/school/curriculum/incremental_active_store/ACTIVE_REPO_BODY_ROUTE_POINTER_V1.json -Raw|ConvertFrom-Json
$ledgerBefore=Get-Content operations/school/curriculum/incremental_active_store/ACTIVE_REPO_BODY_ROUTE_REPLAY_LEDGER_V1.json -Raw|ConvertFrom-Json
$smallReady='operations/reports/streaming_absorption/candidate_factory_validation_120_20260701_151426/ready_atoms.jsonl'
& operations/school/curriculum/ready_lane/absorb_ready_lane_via_active_route_v1.ps1 -ReadyLanePath $smallReady -PromotionId replay_policy_wiring_small_dry_run -DryRun | Out-Host
$small=Get-Content operations/reports/ABSORB_READY_LANE_VIA_ACTIVE_ROUTE_V1.json -Raw|ConvertFrom-Json
$tmpDir='.runtime/replay_audit_policy_wiring_probe'
New-Item -ItemType Directory -Force -Path $tmpDir | Out-Null
$largeReady=Join-Path $tmpDir 'ready_5000.jsonl'
$line=Get-Content $smallReady -First 1
if(Test-Path $largeReady){ Remove-Item $largeReady -Force }
for($i=0;$i -lt 5000;$i++){ [IO.File]::AppendAllText((Join-Path (Get-Location).Path $largeReady),$line+"`n",$utf8) }
$blocked=$false; $blockMessage=''
try{
  & operations/school/curriculum/ready_lane/absorb_ready_lane_via_active_route_v1.ps1 -ReadyLanePath $largeReady -PromotionId replay_policy_wiring_large_should_block | Out-Host
}catch{
  $blockMessage=$_.Exception.Message
  if($blockMessage -like '*REPLAY_AUDIT_REQUIRED_BY_POLICY*'){ $blocked=$true }
}
$routeAfter=Get-Content operations/school/curriculum/incremental_active_store/ACTIVE_REPO_BODY_ROUTE_POINTER_V1.json -Raw|ConvertFrom-Json
$ledgerAfter=Get-Content operations/school/curriculum/incremental_active_store/ACTIVE_REPO_BODY_ROUTE_REPLAY_LEDGER_V1.json -Raw|ConvertFrom-Json
$selection=Get-Content operations/reports/REPLAY_AUDIT_POLICY_SELECTION_V1.json -Raw|ConvertFrom-Json
$ok=($small.status -eq 'DRY_RUN_ABSORPTION_ROUTE_SELECTED_V1' -and $small.replay_audit_decision -eq 'SKIP_FULL_REPLAY_HOT_PATH_V1' -and $small.full_replay_required -eq $false -and $blocked -and $selection.decision -eq 'REQUIRE_FULL_REPLAY_AUDIT_V1' -and [int]$routeBefore.routed_active_count -eq [int]$routeAfter.routed_active_count -and @($ledgerBefore.deltas).Count -eq @($ledgerAfter.deltas).Count -and [int]$ledgerBefore.replayed_active_count -eq [int]$ledgerAfter.replayed_active_count)
$status=if($ok){'PASS_REPLAY_AUDIT_POLICY_ENTRYPOINT_WIRING_V1'}else{'FAIL_REPLAY_AUDIT_POLICY_ENTRYPOINT_WIRING_V1'}
$report=[pscustomObject]@{
  schema='replay_audit_policy_entrypoint_wiring_v1'
  status=$status
  runtime_ready=$false
  small_ready_path=$smallReady
  small_incoming_count=$small.incoming_count
  small_entrypoint_status=$small.status
  small_replay_audit_decision=$small.replay_audit_decision
  small_full_replay_required=$small.full_replay_required
  large_ready_path=$largeReady
  large_incoming_count=5000
  large_blocked=$blocked
  large_block_message=$blockMessage
  last_selection_decision=$selection.decision
  last_selection_reasons=@($selection.reasons)
  route_pointer_count_before=$routeBefore.routed_active_count
  route_pointer_count_after=$routeAfter.routed_active_count
  ledger_delta_count_before=@($ledgerBefore.deltas).Count
  ledger_delta_count_after=@($ledgerAfter.deltas).Count
  ledger_active_before=$ledgerBefore.replayed_active_count
  ledger_active_after=$ledgerAfter.replayed_active_count
  route_mutated_by_policy_validation=([int]$routeBefore.routed_active_count -ne [int]$routeAfter.routed_active_count)
  ledger_mutated_by_policy_validation=(@($ledgerBefore.deltas).Count -ne @($ledgerAfter.deltas).Count -or [int]$ledgerBefore.replayed_active_count -ne [int]$ledgerAfter.replayed_active_count)
  boundary='Validates entrypoint consults replay audit policy before mutation; no absorption.'
}
WriteJson 'operations/reports/REPLAY_AUDIT_POLICY_ENTRYPOINT_WIRING_V1.json' $report 80
$md=@('# REPLAY_AUDIT_POLICY_ENTRYPOINT_WIRING_V1','',"Status: $status",'Runtime ready: false','',"Small decision: $($report.small_replay_audit_decision)","Small full replay required: $($report.small_full_replay_required)","Large blocked: $($report.large_blocked)","Large message: $($report.large_block_message)","Route mutated: $($report.route_mutated_by_policy_validation)","Ledger mutated: $($report.ledger_mutated_by_policy_validation)",'','Boundary: validation only; no absorption.')
[IO.File]::WriteAllText((Join-Path (Get-Location).Path 'operations/reports/REPLAY_AUDIT_POLICY_ENTRYPOINT_WIRING_V1.md'),($md -join "`r`n"),$utf8)
Write-Host "ENTRYPOINT_POLICY_WIRING_STATUS=$status"
Write-Host "SMALL_DECISION=$($report.small_replay_audit_decision)|required=$($report.small_full_replay_required)|incoming=$($report.small_incoming_count)"
Write-Host "LARGE_BLOCKED=$($report.large_blocked)|message=$($report.large_block_message)"
Write-Host "ROUTE_BEFORE=$($report.route_pointer_count_before)|ROUTE_AFTER=$($report.route_pointer_count_after)|mutated=$($report.route_mutated_by_policy_validation)"
Write-Host "LEDGER_BEFORE=$($report.ledger_delta_count_before)/$($report.ledger_active_before)|LEDGER_AFTER=$($report.ledger_delta_count_after)/$($report.ledger_active_after)|mutated=$($report.ledger_mutated_by_policy_validation)"
Write-Host "RUNTIME_READY=false"
if(-not $ok){ exit 1 }