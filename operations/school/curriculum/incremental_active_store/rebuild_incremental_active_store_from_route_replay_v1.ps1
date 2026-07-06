param(
  [string]$ReplayLedgerPath='operations/school/curriculum/incremental_active_store/ACTIVE_REPO_BODY_ROUTE_REPLAY_LEDGER_V1.json',
  [switch]$Force
)
$ErrorActionPreference='Stop'
$repoRoot=(git rev-parse --show-toplevel).Trim(); Set-Location $repoRoot
$utf8=New-Object System.Text.UTF8Encoding($false)
function WriteJson($p,$o,$d=80){$dir=Split-Path -Parent $p; if($dir){New-Item -ItemType Directory -Force -Path $dir|Out-Null}; [IO.File]::WriteAllText((Join-Path (Get-Location).Path $p),($o|ConvertTo-Json -Depth $d),$utf8)}
$ledger=Get-Content $ReplayLedgerPath -Raw|ConvertFrom-Json
$store=[string]$ledger.store_dir
$legacy=[string]$ledger.legacy_checkpoint_path
$legacyHash=(Get-FileHash $legacy -Algorithm SHA256).Hash.ToLower()
if($legacyHash -ne [string]$ledger.legacy_checkpoint_sha256){ throw "LEGACY_HASH_MISMATCH|expected=$($ledger.legacy_checkpoint_sha256)|actual=$legacyHash" }
if((Test-Path $store) -and $Force){ Remove-Item $store -Recurse -Force }
& operations/school/curriculum/incremental_active_store/initialize_incremental_active_store_v1.ps1 -ActiveCheckpointPath $legacy -StoreDir $store -Force:$Force | Out-Host
$manifest=Get-Content (Join-Path $store 'manifest.json') -Raw|ConvertFrom-Json
if([int]$manifest.active_atom_count -ne [int]$ledger.legacy_frozen_count){ throw "BASE_COUNT_MISMATCH|manifest=$($manifest.active_atom_count)|ledger=$($ledger.legacy_frozen_count)" }
$applied=@()
foreach($d in @($ledger.deltas | Sort-Object ordinal)){
  $ready=[string]$d.ready_lane_path
  if(-not (Test-Path $ready)){ throw "REPLAY_READY_MISSING|$ready" }
  $sha=(Get-FileHash $ready -Algorithm SHA256).Hash.ToLower()
  $lines=(Get-Content $ready|Measure-Object).Count
  if($sha -ne [string]$d.ready_lane_sha256){ throw "REPLAY_READY_SHA_MISMATCH|$ready" }
  if($lines -ne [int]$d.incoming_count){ throw "REPLAY_READY_COUNT_MISMATCH|$ready|$lines" }
  $m=Get-Content (Join-Path $store 'manifest.json') -Raw|ConvertFrom-Json
  if([int]$m.active_atom_count -ne [int]$d.before_count){ throw "REPLAY_DELTA_BEFORE_MISMATCH|expected=$($d.before_count)|actual=$($m.active_atom_count)" }
  & operations/school/curriculum/incremental_active_store/apply_ready_lane_incremental_active_delta_v1.ps1 -ReadyLanePath $ready -StoreDir $store -PromotionId ([string]$d.promotion_id) | Out-Host
  $m2=Get-Content (Join-Path $store 'manifest.json') -Raw|ConvertFrom-Json
  if([int]$m2.active_atom_count -ne [int]$d.after_count){ throw "REPLAY_DELTA_AFTER_MISMATCH|expected=$($d.after_count)|actual=$($m2.active_atom_count)" }
  $applied += [pscustomObject]@{promotion_id=$d.promotion_id; ready_lane_path=$ready; incoming_count=$lines; before_count=$d.before_count; after_count=$d.after_count; ready_lane_sha256=$sha}
}
& operations/school/curriculum/incremental_active_store/write_incremental_active_store_compatibility_projection_v1.ps1 | Out-Host
$projection=Get-Content operations/reports/INCREMENTAL_ACTIVE_STORE_COMPATIBILITY_PROJECTION_V1.json -Raw|ConvertFrom-Json
$route=Get-Content operations/school/curriculum/incremental_active_store/ACTIVE_REPO_BODY_ROUTE_POINTER_V1.json -Raw|ConvertFrom-Json
if([int]$projection.routed_active_count -ne [int]$ledger.replayed_active_count){ throw "REPLAY_PROJECTION_COUNT_MISMATCH" }
if([int]$route.routed_active_count -ne [int]$ledger.replayed_active_count){ throw "REPLAY_ROUTE_POINTER_COUNT_MISMATCH" }
Set-Content -Path (Join-Path $store 'REPLAY_SOURCE_LEDGER_PATH.txt') -Value $ReplayLedgerPath -Encoding utf8
$report=[pscustomObject]@{
  schema='rebuild_incremental_active_store_from_route_replay_v1'
  status='PASS_REBUILD_INCREMENTAL_ACTIVE_STORE_FROM_ROUTE_REPLAY_V1'
  runtime_ready=$false
  replay_ledger_path=$ReplayLedgerPath
  store_dir=$store
  legacy_checkpoint_path=$legacy
  legacy_checkpoint_sha256=$legacyHash
  legacy_frozen_count=$ledger.legacy_frozen_count
  delta_count=@($ledger.deltas).Count
  replayed_active_count=$ledger.replayed_active_count
  projection_active_count=$projection.routed_active_count
  route_pointer_active_count=$route.routed_active_count
  applied_deltas=@($applied)
  boundary='Rebuilds runtime routed store from committed legacy checkpoint and committed replay delta sources; no live proof.'
}
WriteJson 'operations/reports/REBUILD_INCREMENTAL_ACTIVE_STORE_FROM_ROUTE_REPLAY_V1.json' $report 80
$md=@('# REBUILD_INCREMENTAL_ACTIVE_STORE_FROM_ROUTE_REPLAY_V1','',"Status: $($report.status)",'Runtime ready: false','',"Store dir: $store","Legacy frozen count: $($report.legacy_frozen_count)","Delta count: $($report.delta_count)","Replayed active count: $($report.replayed_active_count)","Projection active count: $($report.projection_active_count)","Route pointer active count: $($report.route_pointer_active_count)",'','Boundary: runtime rebuild only; no live proof.')
[IO.File]::WriteAllText((Join-Path (Get-Location).Path 'operations/reports/REBUILD_INCREMENTAL_ACTIVE_STORE_FROM_ROUTE_REPLAY_V1.md'),($md -join "`r`n"),$utf8)
Write-Host "REBUILD_STATUS=$($report.status)"
Write-Host "STORE_DIR=$store"
Write-Host "LEGACY_FROZEN_COUNT=$($report.legacy_frozen_count)"
Write-Host "DELTA_COUNT=$($report.delta_count)"
Write-Host "REPLAYED_ACTIVE_COUNT=$($report.replayed_active_count)"
Write-Host "PROJECTION_ACTIVE_COUNT=$($report.projection_active_count)"
Write-Host "ROUTE_POINTER_ACTIVE_COUNT=$($report.route_pointer_active_count)"
Write-Host "RUNTIME_READY=false"