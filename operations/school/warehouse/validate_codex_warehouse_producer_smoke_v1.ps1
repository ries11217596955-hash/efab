param()
$ErrorActionPreference='Stop'
$repoRoot=(git rev-parse --show-toplevel).Trim(); Set-Location $repoRoot
function Sha($p){ if(Test-Path $p){ (Get-FileHash $p -Algorithm SHA256).Hash } else { 'MISSING' } }
$mem='.runtime/active_compact_semantic_memory_v1'
$before=[ordered]@{manifest=Sha "$mem/manifest.json"; index=Sha "$mem/index.json"; cells=Sha "$mem/cells.jsonl"}
$out=@(& powershell -NoProfile -ExecutionPolicy Bypass -File operations/school/warehouse/invoke_codex_warehouse_producer_smoke_v1.ps1 -ProducerMode MockProducer -Topics AUTO -MaxRequestSize 50000 -MicroBatchSize 100 -MaxReadyBacklogCandidates 3000 *>&1 | ForEach-Object{[string]$_})
$root='.runtime/warehouse_producer_smoke_validation'
New-Item -ItemType Directory -Force -Path $root | Out-Null
$out | Set-Content -LiteralPath "$root/validator_stdout.txt" -Encoding UTF8
$reportPath=(($out|Where-Object{$_ -match '^CODEX_WAREHOUSE_PRODUCER_SMOKE_REPORT='}|Select-Object -Last 1) -replace '^CODEX_WAREHOUSE_PRODUCER_SMOKE_REPORT=','')
$fail=@()
if([string]::IsNullOrWhiteSpace($reportPath) -or -not (Test-Path $reportPath)){ $fail += 'SMOKE_REPORT_MISSING' }
$r=Get-Content $reportPath -Raw | ConvertFrom-Json
if($r.status -ne 'PASS_MOCK_CODEX_WAREHOUSE_PRODUCER_SMOKE_NO_ABSORB_V1'){ $fail += "BAD_SMOKE_STATUS:$($r.status)" }
if($r.producer_status -ne 'MOCK_PRODUCER_READY_CREATED'){ $fail += "BAD_PRODUCER_STATUS:$($r.producer_status)" }
if($r.consumer_status -ne 'PASS_WAREHOUSE_CONSUMED_READY_BATCHES_NO_ABSORB_V1'){ $fail += "BAD_CONSUMER_STATUS:$($r.consumer_status)" }
if([int]$r.accepted_count -ne 100){ $fail += "ACCEPTED_NOT_100:$($r.accepted_count)" }
if($r.absorption_run -ne $false){ $fail += 'ABSORPTION_SHOULD_BE_FALSE' }
if($r.memory_changed -ne $false){ $fail += 'REPORT_MEMORY_CHANGED_TRUE' }
$after=[ordered]@{manifest=Sha "$mem/manifest.json"; index=Sha "$mem/index.json"; cells=Sha "$mem/cells.jsonl"}
if($before.cells -ne $after.cells -or $before.index -ne $after.index -or $before.manifest -ne $after.manifest){ $fail += 'MEMORY_HASH_CHANGED' }
$status=if($fail.Count -eq 0){'PASS_CODEX_WAREHOUSE_PRODUCER_SMOKE_VALIDATION_V1'}else{'FAIL_CODEX_WAREHOUSE_PRODUCER_SMOKE_VALIDATION_V1'}
$proof=[ordered]@{
  schema='codex_warehouse_producer_smoke_validation_v1'
  status=$status
  created_at=(Get-Date).ToString('o')
  smoke_report=$reportPath
  smoke_status=$r.status
  producer_status=$r.producer_status
  consumer_status=$r.consumer_status
  request_candidate_count=$r.request_candidate_count
  micro_batch_size=$r.micro_batch_size
  micro_batch_count=$r.micro_batch_count
  accepted_count=$r.accepted_count
  absorption_run=$r.absorption_run
  memory_before=$before
  memory_after=$after
  memory_changed=($before.cells -ne $after.cells -or $before.index -ne $after.index -or $before.manifest -ne $after.manifest)
  failures=@($fail)
}
$proofPath='operations/reports/CODEX_WAREHOUSE_PRODUCER_SMOKE_VALIDATION_20260715.json'
$proof|ConvertTo-Json -Depth 100|Set-Content -LiteralPath $proofPath -Encoding UTF8
Write-Host "CODEX_WAREHOUSE_PRODUCER_SMOKE_VALIDATION_STATUS=$status"
Write-Host "CODEX_WAREHOUSE_PRODUCER_SMOKE_VALIDATION_PROOF=$proofPath"
Write-Host "CODEX_WAREHOUSE_PRODUCER_SMOKE_VALIDATION_ACCEPTED_COUNT=$($r.accepted_count)"
Write-Host "CODEX_WAREHOUSE_PRODUCER_SMOKE_VALIDATION_MEMORY_CHANGED=$($proof.memory_changed)"
if($fail.Count -gt 0){ Write-Host "CODEX_WAREHOUSE_PRODUCER_SMOKE_VALIDATION_FAILURES=$($fail -join ',')"; exit 1 }

