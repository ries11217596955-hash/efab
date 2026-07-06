param(
  [string]$StoreDir='.runtime/incremental_active_store_v1/routed_active_store',
  [string]$LegacyCheckpointPath='operations/school/curriculum/codex_digest/store/active_codex_curriculum_digest_v1/active_codex_curriculum_digest_checkpoint.json',
  [switch]$Force
)
$ErrorActionPreference='Stop'
$repoRoot=(git rev-parse --show-toplevel).Trim(); Set-Location $repoRoot
$utf8=New-Object System.Text.UTF8Encoding($false)
function WriteJson($p,$o,$d=80){$dir=Split-Path -Parent $p; if($dir){New-Item -ItemType Directory -Force -Path $dir|Out-Null}; [IO.File]::WriteAllText((Join-Path (Get-Location).Path $p),($o|ConvertTo-Json -Depth $d),$utf8)}
$legacyHash=(Get-FileHash $LegacyCheckpointPath -Algorithm SHA256).Hash.ToLower()
& operations/school/curriculum/incremental_active_store/initialize_incremental_active_store_v1.ps1 -ActiveCheckpointPath $LegacyCheckpointPath -StoreDir $StoreDir -Force:$Force | Out-Host
$manifest=Get-Content (Join-Path $StoreDir 'manifest.json') -Raw|ConvertFrom-Json
$route=[pscustomObject]@{
  schema='active_repo_body_route_pointer_v1'
  status='PASS_INCREMENTAL_ACTIVE_STORE_ROUTE_SWITCHED_V1'
  runtime_ready=$false
  active_source='incremental_active_store_v1'
  store_dir=$StoreDir
  legacy_checkpoint_path=$LegacyCheckpointPath
  legacy_checkpoint_sha256=$legacyHash
  legacy_checkpoint_frozen_count=$manifest.active_atom_count
  routed_active_count=$manifest.active_atom_count
  route_mode='incremental_growth_route_legacy_bootstrap'
  rollback_mode='inverse_delta_not_full_snapshot'
  compatibility_projection_required=$true
  canonical_legacy_checkpoint_replaced=$false
  activated_at=(Get-Date).ToString('o')
  boundary='Repo-body growth route pointer only; legacy checkpoint remains bootstrap/compatibility source; no live proof.'
}
WriteJson 'operations/school/curriculum/incremental_active_store/ACTIVE_REPO_BODY_ROUTE_POINTER_V1.json' $route 80
WriteJson 'operations/reports/ACTIVE_REPO_BODY_ROUTE_POINTER_V1.json' $route 80
$md=@('# ACTIVE_REPO_BODY_ROUTE_POINTER_V1','',"Status: $($route.status)",'Runtime ready: false','',"Active source: $($route.active_source)","Store dir: $StoreDir","Legacy frozen count: $($route.legacy_checkpoint_frozen_count)","Routed active count: $($route.routed_active_count)","Rollback mode: $($route.rollback_mode)","Legacy checkpoint replaced: $($route.canonical_legacy_checkpoint_replaced)",'','Boundary: route pointer only; no live proof.')
[IO.File]::WriteAllText((Join-Path (Get-Location).Path 'operations/reports/ACTIVE_REPO_BODY_ROUTE_POINTER_V1.md'),($md -join "`r`n"),$utf8)
Write-Host "ROUTE_STATUS=$($route.status)"
Write-Host "ACTIVE_SOURCE=$($route.active_source)"
Write-Host "STORE_DIR=$StoreDir"
Write-Host "LEGACY_FROZEN_COUNT=$($route.legacy_checkpoint_frozen_count)"
Write-Host "ROUTED_ACTIVE_COUNT=$($route.routed_active_count)"
Write-Host "LEGACY_REPLACED=false"
Write-Host "RUNTIME_READY=false"