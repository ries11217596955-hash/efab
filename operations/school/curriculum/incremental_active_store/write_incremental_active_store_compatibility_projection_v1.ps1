param(
  [string]$RoutePointerPath='operations/school/curriculum/incremental_active_store/ACTIVE_REPO_BODY_ROUTE_POINTER_V1.json'
)
$ErrorActionPreference='Stop'
$repoRoot=(git rev-parse --show-toplevel).Trim(); Set-Location $repoRoot
$utf8=New-Object System.Text.UTF8Encoding($false)
function WriteJson($p,$o,$d=80){$dir=Split-Path -Parent $p; if($dir){New-Item -ItemType Directory -Force -Path $dir|Out-Null}; [IO.File]::WriteAllText((Join-Path (Get-Location).Path $p),($o|ConvertTo-Json -Depth $d),$utf8)}
function SetOrAdd($obj,$name,$value){ if($obj.PSObject.Properties.Name -contains $name){ $obj.$name=$value } else { $obj | Add-Member -NotePropertyName $name -NotePropertyValue $value -Force } }
$route=Get-Content $RoutePointerPath -Raw|ConvertFrom-Json
$manifest=Get-Content (Join-Path $route.store_dir 'manifest.json') -Raw|ConvertFrom-Json
$legacyHash=(Get-FileHash $route.legacy_checkpoint_path -Algorithm SHA256).Hash.ToLower()
$projection=[pscustomObject]@{
  schema='incremental_active_store_compatibility_projection_v1'
  status='PASS_INCREMENTAL_ACTIVE_STORE_COMPATIBILITY_PROJECTION_V1'
  runtime_ready=$false
  active_source=$route.active_source
  store_dir=$route.store_dir
  routed_active_count=$manifest.active_atom_count
  topic_index_count=$manifest.topic_index_count
  duplicate_key_index_count=$manifest.duplicate_key_index_count
  theme_cursor_count=$manifest.theme_cursor_count
  last_promotion_id=$manifest.last_promotion_id
  last_delta_path=if($manifest.PSObject.Properties.Name -contains 'last_delta_path'){$manifest.last_delta_path}else{''}
  last_inverse_rollback_path=if($manifest.PSObject.Properties.Name -contains 'last_inverse_rollback_path'){$manifest.last_inverse_rollback_path}else{''}
  legacy_checkpoint_path=$route.legacy_checkpoint_path
  legacy_checkpoint_sha256=$legacyHash
  legacy_checkpoint_frozen_count=$route.legacy_checkpoint_frozen_count
  legacy_checkpoint_replaced=$false
  boundary='Compatibility projection only; does not write full legacy checkpoint.'
}
SetOrAdd $route 'routed_active_count' $manifest.active_atom_count
SetOrAdd $route 'last_projection_status' $projection.status
SetOrAdd $route 'last_delta_path' $projection.last_delta_path
SetOrAdd $route 'last_inverse_rollback_path' $projection.last_inverse_rollback_path
SetOrAdd $route 'updated_at' ((Get-Date).ToString('o'))
WriteJson $RoutePointerPath $route 80
WriteJson 'operations/reports/ACTIVE_REPO_BODY_ROUTE_POINTER_V1.json' $route 80
WriteJson 'operations/reports/INCREMENTAL_ACTIVE_STORE_COMPATIBILITY_PROJECTION_V1.json' $projection 80
$md=@('# INCREMENTAL_ACTIVE_STORE_COMPATIBILITY_PROJECTION_V1','',"Status: $($projection.status)",'Runtime ready: false','',"Active source: $($projection.active_source)","Routed active count: $($projection.routed_active_count)","Topic index: $($projection.topic_index_count)","Duplicate-key index: $($projection.duplicate_key_index_count)","Theme cursors: $($projection.theme_cursor_count)","Legacy checkpoint replaced: $($projection.legacy_checkpoint_replaced)",'','Boundary: compact projection only; no full checkpoint write.')
[IO.File]::WriteAllText((Join-Path (Get-Location).Path 'operations/reports/INCREMENTAL_ACTIVE_STORE_COMPATIBILITY_PROJECTION_V1.md'),($md -join "`r`n"),$utf8)
Write-Host "PROJECTION_STATUS=$($projection.status)"
Write-Host "ROUTED_ACTIVE_COUNT=$($projection.routed_active_count)"
Write-Host "ROUTE_POINTER_ACTIVE=$($route.routed_active_count)"
Write-Host "LEGACY_REPLACED=false"
Write-Host "RUNTIME_READY=false"