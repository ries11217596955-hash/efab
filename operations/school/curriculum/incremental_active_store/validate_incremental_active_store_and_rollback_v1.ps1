param([int]$ProbeTargetAccepted=40,[int]$BatchSize=20)
$ErrorActionPreference='Stop'
$repoRoot=(git rev-parse --show-toplevel).Trim(); Set-Location $repoRoot
$legacy='operations/school/curriculum/codex_digest/store/active_codex_curriculum_digest_v1/active_codex_curriculum_digest_checkpoint.json'
$legacyBefore=(Get-FileHash $legacy -Algorithm SHA256).Hash.ToLower()
$store='.runtime/incremental_active_store_v1/active_store'
& operations/school/curriculum/incremental_active_store/initialize_incremental_active_store_v1.ps1 -StoreDir $store -Force | Out-Host
$init=Get-Content operations/reports/INCREMENTAL_ACTIVE_STORE_INITIALIZATION_V1.json -Raw|ConvertFrom-Json
& operations/school/curriculum/candidate_factory/validate_codex_curriculum_candidate_factory_v1.ps1 -TargetAccepted $ProbeTargetAccepted -BatchSize $BatchSize | Out-Host
$factory=Get-Content operations/reports/CODEX_CANDIDATE_FACTORY_VALIDATION_V1.json -Raw|ConvertFrom-Json
$runDir="operations/reports/streaming_absorption/$($factory.run_id)"
& operations/school/curriculum/candidate_factory/validate_codex_candidate_factory_hot_path_invariants_v1.ps1 -RunDir $runDir | Out-Host
$hot=Get-Content operations/reports/FACTORY_HOT_PATH_INVARIANTS_V1.json -Raw|ConvertFrom-Json
$ready="$runDir/ready_atoms.jsonl"
& operations/school/curriculum/incremental_active_store/apply_ready_lane_incremental_active_delta_v1.ps1 -ReadyLanePath $ready -StoreDir $store -PromotionId "incremental_probe_$($factory.run_id)" | Out-Host
$delta=Get-Content operations/reports/INCREMENTAL_ACTIVE_DELTA_APPLY_V1.json -Raw|ConvertFrom-Json
$manifest=Get-Content (Join-Path $store 'manifest.json') -Raw|ConvertFrom-Json
$legacyAfter=(Get-FileHash $legacy -Algorithm SHA256).Hash.ToLower()
$deltaSize=(Get-Item $delta.delta_path).Length
$inverseSize=(Get-Item $delta.inverse_rollback_path).Length
$legacySize=(Get-Item $legacy).Length
$storeChunkBytes=(Get-ChildItem (Join-Path $store 'chunks') -File | Measure-Object Length -Sum).Sum
$ok=($init.status -eq 'PASS_INCREMENTAL_ACTIVE_STORE_INITIALIZED_V1' -and $factory.status -eq 'PASS_CODEX_CANDIDATE_FACTORY_VALIDATION_V1' -and $hot.status -eq 'PASS_FACTORY_HOT_PATH_INVARIANTS_V1' -and $delta.status -eq 'PASS_INCREMENTAL_ACTIVE_DELTA_APPLIED_V1' -and $legacyBefore -eq $legacyAfter -and [int]$delta.before_count -eq [int]$init.active_atom_count -and [int]$delta.after_count -eq ([int]$init.active_atom_count + $ProbeTargetAccepted) -and [int]$manifest.active_atom_count -eq [int]$delta.after_count)
$status=if($ok){'PASS_INCREMENTAL_ACTIVE_STORE_AND_ROLLBACK_VALIDATION_V1'}else{'FAIL_INCREMENTAL_ACTIVE_STORE_AND_ROLLBACK_VALIDATION_V1'}
$utf8=New-Object System.Text.UTF8Encoding($false)
$report=[pscustomObject]@{schema='incremental_active_store_and_rollback_validation_v1'; status=$status; runtime_ready=$false; store_dir=$store; initialized_count=$init.active_atom_count; probe_target=$ProbeTargetAccepted; factory_run_id=$factory.run_id; hot_path_status=$hot.status; delta_status=$delta.status; before_count=$delta.before_count; incoming_count=$delta.incoming_count; after_count=$delta.after_count; legacy_checkpoint_sha_before=$legacyBefore; legacy_checkpoint_sha_after=$legacyAfter; legacy_checkpoint_mutated=($legacyBefore -ne $legacyAfter); legacy_checkpoint_size_bytes=$legacySize; delta_size_bytes=$deltaSize; inverse_rollback_size_bytes=$inverseSize; store_chunk_bytes=$storeChunkBytes; rollback_mode=$delta.rollback_mode; boundary='Lab validation of parallel incremental store; canonical active checkpoint not replaced.'}
[IO.File]::WriteAllText((Join-Path (Get-Location).Path 'operations/reports/INCREMENTAL_ACTIVE_STORE_AND_ROLLBACK_VALIDATION_V1.json'),($report|ConvertTo-Json -Depth 80),$utf8)
$md=@('# INCREMENTAL_ACTIVE_STORE_AND_ROLLBACK_VALIDATION_V1','',"Status: $status",'Runtime ready: false','',"Initialized count: $($report.initialized_count)","Incoming: $($report.incoming_count)","After count: $($report.after_count)","Legacy checkpoint mutated: $($report.legacy_checkpoint_mutated)","Legacy checkpoint size bytes: $legacySize","Delta size bytes: $deltaSize","Inverse rollback size bytes: $inverseSize","Rollback mode: $($report.rollback_mode)",'','Boundary: lab validation only; canonical active checkpoint not replaced.')
[IO.File]::WriteAllText((Join-Path (Get-Location).Path 'operations/reports/INCREMENTAL_ACTIVE_STORE_AND_ROLLBACK_VALIDATION_V1.md'),($md -join "`r`n"),$utf8)
Write-Host "VALIDATION_STATUS=$status"
Write-Host "INITIALIZED_COUNT=$($report.initialized_count)"
Write-Host "INCOMING=$($report.incoming_count)"
Write-Host "AFTER=$($report.after_count)"
Write-Host "LEGACY_CHECKPOINT_MUTATED=$($report.legacy_checkpoint_mutated)"
Write-Host "LEGACY_CHECKPOINT_SIZE_BYTES=$legacySize"
Write-Host "DELTA_SIZE_BYTES=$deltaSize"
Write-Host "INVERSE_ROLLBACK_SIZE_BYTES=$inverseSize"
Write-Host "ROLLBACK_MODE=$($report.rollback_mode)"
Write-Host "RUNTIME_READY=false"
if(-not $ok){ exit 1 }