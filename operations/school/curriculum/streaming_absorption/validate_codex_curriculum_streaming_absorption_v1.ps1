param([Parameter(Mandatory=$true)][string]$RunDir)
$ErrorActionPreference="Stop"
$repoRoot=(git rev-parse --show-toplevel).Trim(); Set-Location $repoRoot
& operations/school/curriculum/streaming_absorption/process_codex_curriculum_streaming_absorption_v1.ps1 -RunDir $RunDir | Out-Host
$r=Get-Content operations/reports/STREAMING_SCHOOL_TO_ABSORPTION_PIPELINE_V1.json -Raw | ConvertFrom-Json
$ok=($r.status -eq 'PASS_STREAMING_SCHOOL_TO_ABSORPTION_PIPELINE_V1' -and [int]$r.batches_processed -ge 1 -and [int]$r.ready_atoms_total -ge 1 -and $r.active_memory_mutated -eq $false)
$status=if($ok){'PASS_STREAMING_SCHOOL_TO_ABSORPTION_VALIDATION_V1'}else{'FAIL_STREAMING_SCHOOL_TO_ABSORPTION_VALIDATION_V1'}
$v=[pscustomObject]@{schema='streaming_school_to_absorption_validator_v1'; status=$status; runtime_ready=$false; run_dir=$RunDir; batches_processed=$r.batches_processed; processed_total=$r.processed_total; contract_accepted_total=$r.contract_accepted_total; contract_rejected_total=$r.contract_rejected_total; ready_atoms_total=$r.ready_atoms_total; stream_quarantined_total=$r.stream_quarantined_total; active_memory_mutated=$false; boundary='Validates streaming lane only; no active promotion.'}
$utf8=New-Object System.Text.UTF8Encoding($false)
[IO.File]::WriteAllText((Join-Path (Get-Location).Path 'operations/reports/STREAMING_SCHOOL_TO_ABSORPTION_VALIDATION_V1.json'),($v|ConvertTo-Json -Depth 50),$utf8)
Write-Host "VALIDATION_STATUS=$status"
Write-Host "BATCHES_PROCESSED=$($r.batches_processed)"
Write-Host "READY_ATOMS=$($r.ready_atoms_total)"
Write-Host "STREAM_QUARANTINED=$($r.stream_quarantined_total)"
Write-Host "ACTIVE_MEMORY_MUTATED=false"
if(-not $ok){ exit 1 }