param(
  [string]$ReplayLedgerPath='operations/school/curriculum/incremental_active_store/ACTIVE_REPO_BODY_ROUTE_REPLAY_LEDGER_V1.json'
)
$ErrorActionPreference='Stop'
$repoRoot=(git rev-parse --show-toplevel).Trim(); Set-Location $repoRoot
$legacy='operations/school/curriculum/codex_digest/store/active_codex_curriculum_digest_v1/active_codex_curriculum_digest_checkpoint.json'
$legacyBefore=(Get-FileHash $legacy -Algorithm SHA256).Hash.ToLower()
$ledger=Get-Content $ReplayLedgerPath -Raw|ConvertFrom-Json
$store=[string]$ledger.store_dir
if(Test-Path $store){ Remove-Item $store -Recurse -Force }
& operations/school/curriculum/incremental_active_store/rebuild_incremental_active_store_from_route_replay_v1.ps1 -ReplayLedgerPath $ReplayLedgerPath -Force | Out-Host
$rebuild=Get-Content operations/reports/REBUILD_INCREMENTAL_ACTIVE_STORE_FROM_ROUTE_REPLAY_V1.json -Raw|ConvertFrom-Json
$projection=Get-Content operations/reports/INCREMENTAL_ACTIVE_STORE_COMPATIBILITY_PROJECTION_V1.json -Raw|ConvertFrom-Json
$route=Get-Content operations/school/curriculum/incremental_active_store/ACTIVE_REPO_BODY_ROUTE_POINTER_V1.json -Raw|ConvertFrom-Json
$legacyAfter=(Get-FileHash $legacy -Algorithm SHA256).Hash.ToLower()
$runtimeBytes=(Get-ChildItem $store -Recurse -File|Measure-Object Length -Sum).Sum
$runtimeFiles=(Get-ChildItem $store -Recurse -File|Measure-Object).Count
$deltaInfos=@()
foreach($d in @($ledger.deltas)){
  $deltaPath=Join-Path $store ("deltas/$($d.promotion_id).jsonl")
  $inversePath=Join-Path $store ("rollback/$($d.promotion_id).inverse.jsonl")
  $deltaInfos += [pscustomObject]@{promotion_id=$d.promotion_id; delta_path=$deltaPath; delta_size_bytes=(Get-Item $deltaPath).Length; inverse_rollback_path=$inversePath; inverse_rollback_size_bytes=(Get-Item $inversePath).Length}
}
$ok=($rebuild.status -eq 'PASS_REBUILD_INCREMENTAL_ACTIVE_STORE_FROM_ROUTE_REPLAY_V1' -and $projection.status -eq 'PASS_INCREMENTAL_ACTIVE_STORE_COMPATIBILITY_PROJECTION_V1' -and $route.status -eq 'PASS_INCREMENTAL_ACTIVE_STORE_ROUTE_SWITCHED_V1' -and [int]$rebuild.replayed_active_count -eq [int]$ledger.replayed_active_count -and [int]$projection.routed_active_count -eq [int]$ledger.replayed_active_count -and [int]$route.routed_active_count -eq [int]$ledger.replayed_active_count -and $legacyBefore -eq $legacyAfter)
$status=if($ok){'PASS_REPLAYABLE_INCREMENTAL_ACTIVE_ROUTE_V1'}else{'FAIL_REPLAYABLE_INCREMENTAL_ACTIVE_ROUTE_V1'}
$utf8=New-Object System.Text.UTF8Encoding($false)
$report=[pscustomObject]@{
  schema='replayable_incremental_active_route_validation_v1'
  status=$status
  runtime_ready=$false
  replay_ledger_path=$ReplayLedgerPath
  store_dir=$store
  legacy_checkpoint_sha_before=$legacyBefore
  legacy_checkpoint_sha_after=$legacyAfter
  legacy_checkpoint_mutated=($legacyBefore -ne $legacyAfter)
  legacy_frozen_count=$ledger.legacy_frozen_count
  delta_count=@($ledger.deltas).Count
  replayed_active_count=$ledger.replayed_active_count
  projection_active_count=$projection.routed_active_count
  route_pointer_active_count=$route.routed_active_count
  runtime_store_files=$runtimeFiles
  runtime_store_bytes=$runtimeBytes
  runtime_store_committed=$false
  delta_infos=@($deltaInfos)
  boundary='Validates route is rebuildable from committed repo artifacts; runtime store remains uncommitted.'
}
[IO.File]::WriteAllText((Join-Path (Get-Location).Path 'operations/reports/REPLAYABLE_INCREMENTAL_ACTIVE_ROUTE_V1.json'),($report|ConvertTo-Json -Depth 80),$utf8)
$md=@('# REPLAYABLE_INCREMENTAL_ACTIVE_ROUTE_V1','',"Status: $status",'Runtime ready: false','',"Legacy frozen count: $($report.legacy_frozen_count)","Delta count: $($report.delta_count)","Replayed active count: $($report.replayed_active_count)","Projection active count: $($report.projection_active_count)","Route pointer active count: $($report.route_pointer_active_count)","Legacy checkpoint mutated: $($report.legacy_checkpoint_mutated)","Runtime store committed: false",'','Boundary: replayability proof only; no live proof.')
[IO.File]::WriteAllText((Join-Path (Get-Location).Path 'operations/reports/REPLAYABLE_INCREMENTAL_ACTIVE_ROUTE_V1.md'),($md -join "`r`n"),$utf8)
Write-Host "REPLAY_VALIDATION_STATUS=$status"
Write-Host "LEGACY_FROZEN_COUNT=$($report.legacy_frozen_count)"
Write-Host "DELTA_COUNT=$($report.delta_count)"
Write-Host "REPLAYED_ACTIVE_COUNT=$($report.replayed_active_count)"
Write-Host "PROJECTION_ACTIVE_COUNT=$($report.projection_active_count)"
Write-Host "ROUTE_POINTER_ACTIVE_COUNT=$($report.route_pointer_active_count)"
Write-Host "LEGACY_MUTATED=$($report.legacy_checkpoint_mutated)"
Write-Host "RUNTIME_STORE_COMMITTED=false"
Write-Host "RUNTIME_READY=false"
if(-not $ok){ exit 1 }