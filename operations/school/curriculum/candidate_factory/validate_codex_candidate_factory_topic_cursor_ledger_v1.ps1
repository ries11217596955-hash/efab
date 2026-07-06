param([int]$ProbeTargetAccepted=60,[int]$BatchSize=20)
$ErrorActionPreference='Stop'
$repoRoot=(git rev-parse --show-toplevel).Trim(); Set-Location $repoRoot
& operations/school/curriculum/candidate_factory/update_codex_candidate_factory_topic_cursor_ledger_v1.ps1 | Out-Host
$cursor=Get-Content operations/reports/FACTORY_TOPIC_CURSOR_LEDGER_V1.json -Raw|ConvertFrom-Json
$activeBefore=Get-Content reports/self_development/SELF_MODEL_ACTIVE_MAP.json -Raw|ConvertFrom-Json
& operations/school/curriculum/candidate_factory/validate_codex_curriculum_candidate_factory_v1.ps1 -TargetAccepted $ProbeTargetAccepted -BatchSize $BatchSize | Out-Host
$factory=Get-Content operations/reports/CODEX_CANDIDATE_FACTORY_VALIDATION_V1.json -Raw|ConvertFrom-Json
$run=Get-Content operations/reports/CODEX_CANDIDATE_FACTORY_RUN_V1.json -Raw|ConvertFrom-Json
$runDir="operations/reports/streaming_absorption/$($factory.run_id)"
& operations/school/curriculum/candidate_factory/validate_codex_candidate_factory_hot_path_invariants_v1.ps1 -RunDir $runDir | Out-Host
$hot=Get-Content operations/reports/FACTORY_HOT_PATH_INVARIANTS_V1.json -Raw|ConvertFrom-Json
$activeAfter=Get-Content reports/self_development/SELF_MODEL_ACTIVE_MAP.json -Raw|ConvertFrom-Json
$ok=($cursor.status -eq 'PASS_FACTORY_TOPIC_CURSOR_LEDGER_V1' -and $cursor.topic_duplicate_count -eq 0 -and $cursor.duplicate_key_duplicate_count -eq 0 -and $factory.status -eq 'PASS_CODEX_CANDIDATE_FACTORY_VALIDATION_V1' -and $factory.active_memory_mutated -eq $false -and $run.use_topic_cursor -eq $true -and $hot.status -eq 'PASS_FACTORY_HOT_PATH_INVARIANTS_V1' -and [int]$activeBefore.active_codex_curriculum_digest_atom_count -eq [int]$activeAfter.active_codex_curriculum_digest_atom_count)
$status=if($ok){'PASS_FACTORY_TOPIC_CURSOR_LEDGER_VALIDATION_V1'}else{'FAIL_FACTORY_TOPIC_CURSOR_LEDGER_VALIDATION_V1'}
$utf8=New-Object System.Text.UTF8Encoding($false)
$report=[pscustomObject]@{schema='factory_topic_cursor_ledger_validation_v1'; status=$status; runtime_ready=$false; active_before=$activeBefore.active_codex_curriculum_digest_atom_count; active_after=$activeAfter.active_codex_curriculum_digest_atom_count; cursor_status=$cursor.status; theme_cursors=$cursor.theme_cursor_count; topic_index=$cursor.topic_index_count; duplicate_key_index=$cursor.duplicate_key_index_count; probe_target=$ProbeTargetAccepted; probe_ready=$factory.ready_atoms; generated_theme_count=$run.generated_theme_count; use_topic_cursor=$run.use_topic_cursor; hot_path_status=$hot.status; hot_path_issues=$hot.issue_count; active_memory_mutated=([int]$activeBefore.active_codex_curriculum_digest_atom_count -ne [int]$activeAfter.active_codex_curriculum_digest_atom_count); boundary='Validates cursor ledger, probe generation and hot path invariants only; no active promotion.'}
[IO.File]::WriteAllText((Join-Path (Get-Location).Path 'operations/reports/FACTORY_TOPIC_CURSOR_LEDGER_VALIDATION_V1.json'),($report|ConvertTo-Json -Depth 100),$utf8)
$md=@('# FACTORY_TOPIC_CURSOR_LEDGER_VALIDATION_V1','',"Status: $status",'Runtime ready: false','',"Active before: $($report.active_before)","Active after: $($report.active_after)","Theme cursors: $($report.theme_cursors)","Probe ready: $($report.probe_ready)","Generated themes: $($report.generated_theme_count)","Hot path: $($report.hot_path_status)","Hot path issues: $($report.hot_path_issues)",'','Boundary: validation only; no active promotion.')
[IO.File]::WriteAllText((Join-Path (Get-Location).Path 'operations/reports/FACTORY_TOPIC_CURSOR_LEDGER_VALIDATION_V1.md'),($md -join "`r`n"),$utf8)
Write-Host "VALIDATION_STATUS=$status"
Write-Host "ACTIVE_BEFORE=$($report.active_before)"
Write-Host "ACTIVE_AFTER=$($report.active_after)"
Write-Host "THEME_CURSORS=$($report.theme_cursors)"
Write-Host "PROBE_READY=$($report.probe_ready)"
Write-Host "HOT_PATH_STATUS=$($report.hot_path_status)"
Write-Host "RUNTIME_READY=false"
if(-not $ok){ exit 1 }