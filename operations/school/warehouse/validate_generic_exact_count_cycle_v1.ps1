
param(
  [int[]]$Counts = @(1,101,678),
  [ValidateRange(1,10000)][int]$MicroBatchSize = 100
)
$ErrorActionPreference='Stop'
$repoRoot=(git rev-parse --show-toplevel).Trim(); Set-Location $repoRoot
function Sha($p){ if(Test-Path $p){ (Get-FileHash $p -Algorithm SHA256).Hash } else { 'MISSING' } }
$mem='.runtime/active_compact_semantic_memory_v1'
$before=[ordered]@{manifest=Sha "$mem/manifest.json"; index=Sha "$mem/index.json"; cells=Sha "$mem/cells.jsonl"}
$root='.runtime/exact_count_cycle_validation'
if(Test-Path $root){ Remove-Item -LiteralPath $root -Recurse -Force }
New-Item -ItemType Directory -Force -Path $root | Out-Null
$fail=New-Object System.Collections.ArrayList
$cases=New-Object System.Collections.ArrayList
foreach($count in $Counts){
  $out=@(& powershell -NoProfile -ExecutionPolicy Bypass -File operations/school/warehouse/invoke_exact_count_warehouse_cycle_v1.ps1 -ProducerMode MockProducer -Count $count -MicroBatchSize $MicroBatchSize -OutputRoot "$root/count_$count" *>&1 | ForEach-Object{[string]$_})
  $out | Set-Content -LiteralPath "$root/count_$count/stdout.txt" -Encoding UTF8
  $rp=(($out|Where-Object{$_ -match '^EXACT_COUNT_CYCLE_REPORT='}|Select-Object -Last 1) -replace '^EXACT_COUNT_CYCLE_REPORT=','')
  if([string]::IsNullOrWhiteSpace($rp) -or -not (Test-Path $rp)){ [void]$fail.Add(('REPORT_MISSING:{0}' -f $count)); continue }
  $r=Get-Content $rp -Raw | ConvertFrom-Json
  if($r.status -ne 'PASS_MOCK_EXACT_COUNT_CYCLE_NO_ABSORB_V1'){ [void]$fail.Add(('BAD_STATUS:{0}:{1}' -f $count,$r.status)) }
  if([int]$r.accepted_count -ne $count){ [void]$fail.Add(('ACCEPTED_MISMATCH:{0}:{1}' -f $count,$r.accepted_count)) }
  if($r.memory_changed -ne $false){ [void]$fail.Add(('MEMORY_CHANGED:{0}' -f $count)) }
  [void]$cases.Add([ordered]@{count=$count; status=$r.status; batch_counts=$r.batch_counts; accepted_count=$r.accepted_count; memory_changed=$r.memory_changed; report=$rp})
}
$after=[ordered]@{manifest=Sha "$mem/manifest.json"; index=Sha "$mem/index.json"; cells=Sha "$mem/cells.jsonl"}
if($before.cells -ne $after.cells -or $before.index -ne $after.index -or $before.manifest -ne $after.manifest){ [void]$fail.Add('ACTIVE_MEMORY_HASH_CHANGED') }
$status=if($fail.Count -eq 0){'PASS_GENERIC_EXACT_COUNT_CYCLE_VALIDATION_V1'}else{'FAIL_GENERIC_EXACT_COUNT_CYCLE_VALIDATION_V1'}
$proof=[ordered]@{schema='generic_exact_count_cycle_validation_v1'; status=$status; created_at=(Get-Date).ToString('o'); counts=@($Counts); case_count=$cases.Count; cases=@($cases); memory_before=$before; memory_after=$after; memory_changed=($before.cells -ne $after.cells -or $before.index -ne $after.index -or $before.manifest -ne $after.manifest); failures=@($fail)}
$proofPath='operations/reports/GENERIC_EXACT_COUNT_CYCLE_VALIDATION_20260715.json'
$proof|ConvertTo-Json -Depth 100|Set-Content -LiteralPath $proofPath -Encoding UTF8
Write-Host "GENERIC_EXACT_COUNT_CYCLE_VALIDATION_STATUS=$status"
Write-Host "GENERIC_EXACT_COUNT_CYCLE_VALIDATION_PROOF=$proofPath"
foreach($c in $cases){ Write-Host ("CASE count=$($c.count)|accepted=$($c.accepted_count)|batches=$($c.batch_counts -join ',')|status=$($c.status)") }
Write-Host "GENERIC_EXACT_COUNT_CYCLE_MEMORY_CHANGED=$($proof.memory_changed)"
if($fail.Count -gt 0){ Write-Host "GENERIC_EXACT_COUNT_CYCLE_FAILURES=$($fail -join ';')"; exit 1 }
