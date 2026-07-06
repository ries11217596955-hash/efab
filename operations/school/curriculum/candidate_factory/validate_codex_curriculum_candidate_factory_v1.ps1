param([int]$TargetAccepted=1000,[int]$BatchSize=100)
$ErrorActionPreference='Stop'
$utf8=New-Object System.Text.UTF8Encoding($false)
function WriteJson($p,$o,$d=80){$dir=Split-Path -Parent $p; if($dir){New-Item -ItemType Directory -Force -Path $dir|Out-Null}; [IO.File]::WriteAllText((Join-Path (Get-Location).Path $p),($o|ConvertTo-Json -Depth $d),$utf8)}
function GetActiveCompactMemoryState(){
  $root='.runtime/active_compact_semantic_memory_v1'
  $manifestPath=Join-Path $root 'manifest.json'
  $cellsPath=Join-Path $root 'cells.jsonl'
  if(-not (Test-Path $manifestPath)){ throw "ACTIVE_COMPACT_MEMORY_MANIFEST_MISSING:$manifestPath" }
  if(-not (Test-Path $cellsPath)){ throw "ACTIVE_COMPACT_MEMORY_CELLS_MISSING:$cellsPath" }
  $manifest=Get-Content $manifestPath -Raw|ConvertFrom-Json
  $cells=(Get-Content $cellsPath|Measure-Object -Line).Lines
  [pscustomObject]@{
    root=$root
    status=$manifest.status
    run_id=$manifest.run_id
    cells=[int]$cells
    cells_sha256=(Get-FileHash -Algorithm SHA256 $cellsPath).Hash
    manifest_sha256=(Get-FileHash -Algorithm SHA256 $manifestPath).Hash
  }
}
$script='operations/school/curriculum/candidate_factory/generate_codex_curriculum_candidate_factory_run_v1.ps1'
$forbiddenPatterns=@('codex\s+(exec|run|apply|review|resume)', 'openai\s+', 'curl\s+', 'Invoke-WebRequest', 'Invoke-RestMethod')
$content=Get-Content $script -Raw
$forbiddenHits=@($forbiddenPatterns|Where-Object{$content -match $_})
if($forbiddenHits.Count -gt 0){ throw "FORBIDDEN_EXTERNAL_OR_CODEX_CLI_CALL_IN_FACTORY: $($forbiddenHits -join ',')" }
$activeBefore=GetActiveCompactMemoryState
$runId='candidate_factory_validation_' + $TargetAccepted + '_' + (Get-Date -Format 'yyyyMMdd_HHmmss')
& $script -TargetAccepted $TargetAccepted -RunKind Test -BatchSize $BatchSize -RunId $runId | Out-Host
$run=Get-Content operations/reports/CODEX_CANDIDATE_FACTORY_RUN_V1.json -Raw|ConvertFrom-Json
& operations/school/curriculum/codex_contract/validate_codex_curriculum_contract_consistency_v1.ps1 -RunDir $run.run_dir | Out-Host
$consistency=Get-Content operations/reports/CODEX_CURRICULUM_CONTRACT_CONSISTENCY_V1.json -Raw|ConvertFrom-Json
& operations/school/curriculum/streaming_absorption/validate_codex_curriculum_streaming_absorption_v1.ps1 -RunDir $run.run_dir | Out-Host
$stream=Get-Content operations/reports/STREAMING_SCHOOL_TO_ABSORPTION_PIPELINE_V1.json -Raw | ConvertFrom-Json
$activeAfter=GetActiveCompactMemoryState
$activeMutated=($activeAfter.cells_sha256 -ne $activeBefore.cells_sha256 -or $activeAfter.manifest_sha256 -ne $activeBefore.manifest_sha256 -or $activeAfter.run_id -ne $activeBefore.run_id -or $activeAfter.cells -ne $activeBefore.cells)
$ok=($run.status -eq 'PASS_CODEX_CANDIDATE_FACTORY_GENERATION_V1' -and [int]$run.candidates_created -eq $TargetAccepted -and $run.codex_cli_invoked -eq $false -and $run.api_invoked -eq $false -and $run.active_memory_mutated -eq $false -and $consistency.status -eq 'PASS_CODEX_CURRICULUM_CONTRACT_CONSISTENCY_V1' -and [int]$consistency.aggregate.accepted -eq $TargetAccepted -and [int]$consistency.aggregate.rejected -eq 0 -and $stream.status -eq 'PASS_STREAMING_SCHOOL_TO_ABSORPTION_PIPELINE_V1' -and [int]$stream.ready_atoms_total -eq $TargetAccepted -and [int]$stream.stream_quarantined_total -eq 0 -and -not $activeMutated)
$status=if($ok){'PASS_CODEX_CANDIDATE_FACTORY_VALIDATION_V1'}else{'FAIL_CODEX_CANDIDATE_FACTORY_VALIDATION_V1'}
$report=[pscustomObject]@{schema='codex_candidate_factory_validator_v2_active_compact_memory'; status=$status; runtime_ready=$false; target_accepted=$TargetAccepted; batch_size=$BatchSize; run_id=$run.run_id; run_dir=$run.run_dir; candidates_created=$run.candidates_created; batch_count=$run.batches_created; codex_cli_invoked=$run.codex_cli_invoked; api_invoked=$run.api_invoked; contract_consistency_status=$consistency.status; contract_accepted=$consistency.aggregate.accepted; contract_rejected=$consistency.aggregate.rejected; streaming_status=$stream.status; ready_atoms=$stream.ready_atoms_total; stream_quarantined=$stream.stream_quarantined_total; active_memory_count_before=$activeBefore.cells; active_memory_count_after=$activeAfter.cells; active_memory_before=$activeBefore; active_memory_after=$activeAfter; active_memory_mutated=$activeMutated; forbidden_call_hits=@($forbiddenHits); boundary='Validates local candidate factory only; no active promotion, no Real run, and active compact semantic memory must remain hash-identical.'}
WriteJson 'operations/reports/CODEX_CANDIDATE_FACTORY_VALIDATION_V1.json' $report 100
$md=@('# CODEX_CANDIDATE_FACTORY_VALIDATION_V1','',"Status: $status",'Runtime ready: false','',"TargetAccepted: $TargetAccepted","Candidates created: $($run.candidates_created)","Batch count: $($run.batches_created)","Codex CLI invoked: $($run.codex_cli_invoked)","API invoked: $($run.api_invoked)","Contract consistency: $($consistency.status)","Contract accepted: $($consistency.aggregate.accepted)","Contract rejected: $($consistency.aggregate.rejected)","Streaming: $($stream.status)","Ready atoms: $($stream.ready_atoms_total)","Stream quarantined: $($stream.stream_quarantined_total)","Active memory count before: $($activeBefore.cells)","Active memory count after: $($activeAfter.cells)","Active memory mutated: $activeMutated","Active memory before run_id: $($activeBefore.run_id)","Active memory after run_id: $($activeAfter.run_id)","Active memory before cells sha256: $($activeBefore.cells_sha256)","Active memory after cells sha256: $($activeAfter.cells_sha256)",'','Boundary: local factory validation only; no active promotion, no Real run, active compact semantic memory hash must remain unchanged.')
[IO.File]::WriteAllText((Join-Path (Get-Location).Path 'operations/reports/CODEX_CANDIDATE_FACTORY_VALIDATION_V1.md'),($md -join "`r`n"),$utf8)
Write-Host "VALIDATION_STATUS=$status"
Write-Host "RUN_ID=$($run.run_id)"
Write-Host "CANDIDATES_CREATED=$($run.candidates_created)"
Write-Host "CONTRACT_ACCEPTED=$($consistency.aggregate.accepted)"
Write-Host "CONTRACT_REJECTED=$($consistency.aggregate.rejected)"
Write-Host "STREAM_READY=$($stream.ready_atoms_total)"
Write-Host "STREAM_QUARANTINED=$($stream.stream_quarantined_total)"
Write-Host "CODEX_CLI_INVOKED=$($run.codex_cli_invoked)"
Write-Host "API_INVOKED=$($run.api_invoked)"
Write-Host "ACTIVE_MEMORY_COUNT_BEFORE=$($activeBefore.cells)"
Write-Host "ACTIVE_MEMORY_COUNT_AFTER=$($activeAfter.cells)"
Write-Host "ACTIVE_MEMORY_MUTATED=$activeMutated"
Write-Host "ACTIVE_MEMORY_BEFORE_RUN_ID=$($activeBefore.run_id)"
Write-Host "ACTIVE_MEMORY_AFTER_RUN_ID=$($activeAfter.run_id)"
Write-Host "ACTIVE_MEMORY_BEFORE_CELLS_SHA256=$($activeBefore.cells_sha256)"
Write-Host "ACTIVE_MEMORY_AFTER_CELLS_SHA256=$($activeAfter.cells_sha256)"
Write-Host "RUNTIME_READY=false"
if(-not $ok){ exit 1 }