param([int]$ProbeTargetAccepted=120,[int]$BatchSize=40)
$ErrorActionPreference='Stop'
$repoRoot=(git rev-parse --show-toplevel).Trim(); Set-Location $repoRoot
& operations/school/curriculum/candidate_factory/update_codex_candidate_factory_memory_ladder_v1.ps1 | Out-Host
$memory=Get-Content operations/reports/CODEX_CANDIDATE_FACTORY_MEMORY_LADDER_V1.json -Raw|ConvertFrom-Json
$activeBefore=Get-Content reports/self_development/SELF_MODEL_ACTIVE_MAP.json -Raw|ConvertFrom-Json
& operations/school/curriculum/candidate_factory/validate_codex_curriculum_candidate_factory_v1.ps1 -TargetAccepted $ProbeTargetAccepted -BatchSize $BatchSize | Out-Host
$factory=Get-Content operations/reports/CODEX_CANDIDATE_FACTORY_VALIDATION_V1.json -Raw|ConvertFrom-Json
$runDir="operations/reports/streaming_absorption/$($factory.run_id)"
& operations/school/curriculum/candidate_factory/validate_codex_candidate_factory_batch_delta_v1.ps1 -RunDir $runDir | Out-Host
$delta=Get-Content operations/reports/CODEX_CANDIDATE_FACTORY_BATCH_DELTA_V1.json -Raw|ConvertFrom-Json
$activeAfter=Get-Content reports/self_development/SELF_MODEL_ACTIVE_MAP.json -Raw|ConvertFrom-Json
$ok=($memory.status -eq 'PASS_FACTORY_MEMORY_LADDER_REPORT_V1' -and $memory.duplicate_topic_count -eq 0 -and $memory.duplicate_key_count -eq 0 -and $factory.status -eq 'PASS_CODEX_CANDIDATE_FACTORY_VALIDATION_V1' -and $factory.active_memory_mutated -eq $false -and $delta.status -eq 'PASS_CODEX_CANDIDATE_FACTORY_BATCH_DELTA_V1' -and [int]$activeBefore.active_codex_curriculum_digest_atom_count -eq [int]$activeAfter.active_codex_curriculum_digest_atom_count)
$status=if($ok){'PASS_CODEX_CANDIDATE_FACTORY_MEMORY_LADDER_VALIDATION_V1'}else{'FAIL_CODEX_CANDIDATE_FACTORY_MEMORY_LADDER_VALIDATION_V1'}
$utf8=New-Object System.Text.UTF8Encoding($false)
$report=[pscustomObject]@{schema='codex_candidate_factory_memory_ladder_validation_v1'; status=$status; runtime_ready=$false; active_before=$activeBefore.active_codex_curriculum_digest_atom_count; active_after=$activeAfter.active_codex_curriculum_digest_atom_count; memory_status=$memory.status; covered_learning_key_count=$memory.covered_learning_key_count; gap_count=$memory.gap_count; factory_probe_status=$factory.status; probe_target=$ProbeTargetAccepted; probe_ready=$factory.ready_atoms; batch_delta_status=$delta.status; batch_delta_pass=$delta.pass_count; batch_delta_fail=$delta.fail_count; active_memory_mutated=([int]$activeBefore.active_codex_curriculum_digest_atom_count -ne [int]$activeAfter.active_codex_curriculum_digest_atom_count); boundary='Validates factory memory, probe generation, and weak batch delta only; no active promotion.'}
[IO.File]::WriteAllText((Join-Path (Get-Location).Path 'operations/reports/CODEX_CANDIDATE_FACTORY_MEMORY_LADDER_VALIDATION_V1.json'),($report|ConvertTo-Json -Depth 100),$utf8)
$md=@('# CODEX_CANDIDATE_FACTORY_MEMORY_LADDER_VALIDATION_V1','',"Status: $status",'Runtime ready: false','',"Active before: $($report.active_before)","Active after: $($report.active_after)","Memory status: $($report.memory_status)","Covered learning keys: $($report.covered_learning_key_count)","Gap count: $($report.gap_count)","Probe ready: $($report.probe_ready)","Batch delta: $($report.batch_delta_status)","Batch delta pass/fail: $($report.batch_delta_pass)/$($report.batch_delta_fail)",'','Boundary: lab validation only; no active promotion.')
[IO.File]::WriteAllText((Join-Path (Get-Location).Path 'operations/reports/CODEX_CANDIDATE_FACTORY_MEMORY_LADDER_VALIDATION_V1.md'),($md -join "`r`n"),$utf8)
Write-Host "VALIDATION_STATUS=$status"
Write-Host "ACTIVE_BEFORE=$($report.active_before)"
Write-Host "ACTIVE_AFTER=$($report.active_after)"
Write-Host "MEMORY_STATUS=$($report.memory_status)"
Write-Host "PROBE_READY=$($report.probe_ready)"
Write-Host "BATCH_DELTA_STATUS=$($report.batch_delta_status)"
Write-Host "RUNTIME_READY=false"
if(-not $ok){ exit 1 }