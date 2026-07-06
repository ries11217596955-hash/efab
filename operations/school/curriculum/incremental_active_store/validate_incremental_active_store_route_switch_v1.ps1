param([int]$ProbeTargetAccepted=40,[int]$BatchSize=20)
$ErrorActionPreference='Stop'
$repoRoot=(git rev-parse --show-toplevel).Trim(); Set-Location $repoRoot
$legacy='operations/school/curriculum/codex_digest/store/active_codex_curriculum_digest_v1/active_codex_curriculum_digest_checkpoint.json'
$legacyBefore=(Get-FileHash $legacy -Algorithm SHA256).Hash.ToLower()
$store='.runtime/incremental_active_store_v1/routed_active_store'
& operations/school/curriculum/incremental_active_store/activate_incremental_active_store_route_v1.ps1 -StoreDir $store -Force | Out-Host
$route=Get-Content operations/school/curriculum/incremental_active_store/ACTIVE_REPO_BODY_ROUTE_POINTER_V1.json -Raw|ConvertFrom-Json
& operations/school/curriculum/candidate_factory/validate_codex_curriculum_candidate_factory_v1.ps1 -TargetAccepted $ProbeTargetAccepted -BatchSize $BatchSize | Out-Host
$factory=Get-Content operations/reports/CODEX_CANDIDATE_FACTORY_VALIDATION_V1.json -Raw|ConvertFrom-Json
$runDir="operations/reports/streaming_absorption/$($factory.run_id)"
& operations/school/curriculum/candidate_factory/validate_codex_candidate_factory_hot_path_invariants_v1.ps1 -RunDir $runDir | Out-Host
$hot=Get-Content operations/reports/FACTORY_HOT_PATH_INVARIANTS_V1.json -Raw|ConvertFrom-Json
$ready="$runDir/ready_atoms.jsonl"
& operations/school/curriculum/incremental_active_store/apply_ready_lane_incremental_active_delta_v1.ps1 -ReadyLanePath $ready -StoreDir $store -PromotionId "route_probe_$($factory.run_id)" | Out-Host
$delta=Get-Content operations/reports/INCREMENTAL_ACTIVE_DELTA_APPLY_V1.json -Raw|ConvertFrom-Json
& operations/school/curriculum/incremental_active_store/write_incremental_active_store_compatibility_projection_v1.ps1 | Out-Host
$projection=Get-Content operations/reports/INCREMENTAL_ACTIVE_STORE_COMPATIBILITY_PROJECTION_V1.json -Raw|ConvertFrom-Json
$routeAfter=Get-Content operations/school/curriculum/incremental_active_store/ACTIVE_REPO_BODY_ROUTE_POINTER_V1.json -Raw|ConvertFrom-Json
$manifest=Get-Content (Join-Path $store 'manifest.json') -Raw|ConvertFrom-Json
$legacyAfter=(Get-FileHash $legacy -Algorithm SHA256).Hash.ToLower()
$deltaSize=(Get-Item $delta.delta_path).Length
$inverseSize=(Get-Item $delta.inverse_rollback_path).Length
$legacySize=(Get-Item $legacy).Length
$ok=($route.status -eq 'PASS_INCREMENTAL_ACTIVE_STORE_ROUTE_SWITCHED_V1' -and $factory.status -eq 'PASS_CODEX_CANDIDATE_FACTORY_VALIDATION_V1' -and $hot.status -eq 'PASS_FACTORY_HOT_PATH_INVARIANTS_V1' -and $delta.status -eq 'PASS_INCREMENTAL_ACTIVE_DELTA_APPLIED_V1' -and $projection.status -eq 'PASS_INCREMENTAL_ACTIVE_STORE_COMPATIBILITY_PROJECTION_V1' -and $legacyBefore -eq $legacyAfter -and [int]$delta.before_count -eq [int]$route.routed_active_count -and [int]$delta.after_count -eq ([int]$route.routed_active_count + $ProbeTargetAccepted) -and [int]$projection.routed_active_count -eq [int]$delta.after_count -and [int]$routeAfter.routed_active_count -eq [int]$delta.after_count -and [int]$manifest.active_atom_count -eq [int]$delta.after_count)
$status=if($ok){'PASS_ROUTE_SWITCH_INCREMENTAL_ACTIVE_STORE_V1'}else{'FAIL_ROUTE_SWITCH_INCREMENTAL_ACTIVE_STORE_V1'}
$utf8=New-Object System.Text.UTF8Encoding($false)
$report=[pscustomObject]@{
  schema='route_switch_incremental_active_store_validation_v1'
  status=$status
  runtime_ready=$false
  route_status=$route.status
  active_source=$route.active_source
  store_dir=$store
  legacy_frozen_count=$route.legacy_checkpoint_frozen_count
  before_count=$delta.before_count
  incoming_count=$delta.incoming_count
  after_count=$delta.after_count
  projection_status=$projection.status
  projection_active_count=$projection.routed_active_count
  route_pointer_active_count=$routeAfter.routed_active_count
  hot_path_status=$hot.status
  legacy_checkpoint_sha_before=$legacyBefore
  legacy_checkpoint_sha_after=$legacyAfter
  legacy_checkpoint_mutated=($legacyBefore -ne $legacyAfter)
  legacy_checkpoint_size_bytes=$legacySize
  delta_size_bytes=$deltaSize
  inverse_rollback_size_bytes=$inverseSize
  rollback_mode=$delta.rollback_mode
  canonical_legacy_checkpoint_replaced=$false
  boundary='Validates route-switched incremental repo-body growth path; no full legacy checkpoint write; no live proof.'
}
[IO.File]::WriteAllText((Join-Path (Get-Location).Path 'operations/reports/ROUTE_SWITCH_INCREMENTAL_ACTIVE_STORE_V1.json'),($report|ConvertTo-Json -Depth 80),$utf8)
$md=@('# ROUTE_SWITCH_INCREMENTAL_ACTIVE_STORE_V1','',"Status: $status",'Runtime ready: false','',"Active source: $($report.active_source)","Legacy frozen count: $($report.legacy_frozen_count)","Before: $($report.before_count)","Incoming: $($report.incoming_count)","After: $($report.after_count)","Projection active count: $($report.projection_active_count)","Route pointer active count: $($report.route_pointer_active_count)","Legacy checkpoint mutated: $($report.legacy_checkpoint_mutated)","Delta size bytes: $($report.delta_size_bytes)","Inverse rollback size bytes: $($report.inverse_rollback_size_bytes)","Rollback mode: $($report.rollback_mode)",'','Boundary: route-switched lab/proof path; no live proof.')
[IO.File]::WriteAllText((Join-Path (Get-Location).Path 'operations/reports/ROUTE_SWITCH_INCREMENTAL_ACTIVE_STORE_V1.md'),($md -join "`r`n"),$utf8)
Write-Host "ROUTE_VALIDATION_STATUS=$status"
Write-Host "ACTIVE_SOURCE=$($report.active_source)"
Write-Host "LEGACY_FROZEN_COUNT=$($report.legacy_frozen_count)"
Write-Host "BEFORE=$($report.before_count)"
Write-Host "INCOMING=$($report.incoming_count)"
Write-Host "AFTER=$($report.after_count)"
Write-Host "PROJECTION_ACTIVE=$($report.projection_active_count)"
Write-Host "ROUTE_POINTER_ACTIVE=$($report.route_pointer_active_count)"
Write-Host "LEGACY_MUTATED=$($report.legacy_checkpoint_mutated)"
Write-Host "DELTA_SIZE_BYTES=$($report.delta_size_bytes)"
Write-Host "INVERSE_ROLLBACK_SIZE_BYTES=$($report.inverse_rollback_size_bytes)"
Write-Host "RUNTIME_READY=false"
if(-not $ok){ exit 1 }