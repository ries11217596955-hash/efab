param(
  [string]$ReadyLanePath='operations/reports/streaming_absorption/candidate_factory_validation_40_20260701_144905/ready_atoms.jsonl'
)
$ErrorActionPreference='Stop'
$repoRoot=(git rev-parse --show-toplevel).Trim(); Set-Location $repoRoot
$legacyBlocked=$false; $legacyMessage=''
try{
  & operations/school/curriculum/ready_lane/promote_codex_curriculum_ready_lane_additive_active_v1.ps1 -ReadyLanePath $ReadyLanePath | Out-Host
}catch{
  $legacyMessage=$_.Exception.Message
  if($legacyMessage -like '*LEGACY_FULL_CHECKPOINT_PROMOTION_BLOCKED_BY_ACTIVE_ROUTE*'){ $legacyBlocked=$true }
}
if(-not $legacyBlocked){ throw "LEGACY_PROMOTION_NOT_BLOCKED: $legacyMessage" }
$routeBefore=Get-Content operations/school/curriculum/incremental_active_store/ACTIVE_REPO_BODY_ROUTE_POINTER_V1.json -Raw|ConvertFrom-Json
& operations/school/curriculum/ready_lane/absorb_ready_lane_via_active_route_v1.ps1 -ReadyLanePath $ReadyLanePath -PromotionId 'dry_run_route_guard_probe' -DryRun | Out-Host
$entry=Get-Content operations/reports/ABSORB_READY_LANE_VIA_ACTIVE_ROUTE_V1.json -Raw|ConvertFrom-Json
$routeAfter=Get-Content operations/school/curriculum/incremental_active_store/ACTIVE_REPO_BODY_ROUTE_POINTER_V1.json -Raw|ConvertFrom-Json
$ok=($legacyBlocked -and $entry.status -eq 'DRY_RUN_ABSORPTION_ROUTE_SELECTED_V1' -and $entry.active_source -eq 'incremental_active_store_v1' -and $entry.legacy_full_checkpoint_path_used -eq $false -and [int]$routeBefore.routed_active_count -eq [int]$routeAfter.routed_active_count)
$status=if($ok){'PASS_ABSORPTION_ROUTE_GUARD_V1'}else{'FAIL_ABSORPTION_ROUTE_GUARD_V1'}
$utf8=New-Object System.Text.UTF8Encoding($false)
$report=[pscustomObject]@{
  schema='absorption_route_guard_v1'
  status=$status
  runtime_ready=$false
  legacy_promote_blocked=$legacyBlocked
  legacy_block_message=$legacyMessage
  active_source=$entry.active_source
  controlled_entrypoint_status=$entry.status
  ready_lane_path=$ReadyLanePath
  incoming_count=$entry.incoming_count
  before_count=$entry.before_count
  dry_run_after_count=$entry.after_count
  route_pointer_count_before=$routeBefore.routed_active_count
  route_pointer_count_after=$routeAfter.routed_active_count
  route_pointer_mutated_by_dry_run=([int]$routeBefore.routed_active_count -ne [int]$routeAfter.routed_active_count)
  legacy_full_checkpoint_path_used=$false
  boundary='Validates legacy full-checkpoint path is blocked and route-aware entrypoint selects incremental path without mutation.'
}
[IO.File]::WriteAllText((Join-Path (Get-Location).Path 'operations/reports/ABSORPTION_ROUTE_GUARD_V1.json'),($report|ConvertTo-Json -Depth 80),$utf8)
$md=@('# ABSORPTION_ROUTE_GUARD_V1','',"Status: $status",'Runtime ready: false','',"Legacy promote blocked: $legacyBlocked","Active source: $($entry.active_source)","Controlled entrypoint: $($entry.status)","Incoming: $($entry.incoming_count)","Route pointer mutated by dry run: $($report.route_pointer_mutated_by_dry_run)","Legacy full checkpoint path used: false",'','Boundary: route guard validation only.')
[IO.File]::WriteAllText((Join-Path (Get-Location).Path 'operations/reports/ABSORPTION_ROUTE_GUARD_V1.md'),($md -join "`r`n"),$utf8)
Write-Host "ROUTE_GUARD_STATUS=$status"
Write-Host "LEGACY_PROMOTE_BLOCKED=$legacyBlocked"
Write-Host "CONTROLLED_ENTRYPOINT_STATUS=$($entry.status)"
Write-Host "ACTIVE_SOURCE=$($entry.active_source)"
Write-Host "ROUTE_POINTER_MUTATED_BY_DRY_RUN=$($report.route_pointer_mutated_by_dry_run)"
Write-Host "LEGACY_FULL_CHECKPOINT_USED=false"
Write-Host "RUNTIME_READY=false"
if(-not $ok){ exit 1 }