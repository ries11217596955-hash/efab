param(
  [int[]]$Counts = @(1,50,99,100,101,678,1000,3581,50000),
  [ValidateRange(1,10000)][int]$MicroBatchSize = 100,
  [ValidateRange(1,1000000)][int]$MaxRequestSize = 50000
)
$ErrorActionPreference='Stop'
$repoRoot=(git rev-parse --show-toplevel).Trim(); Set-Location $repoRoot
function Sha($p){ if(Test-Path $p){ (Get-FileHash $p -Algorithm SHA256).Hash } else { 'MISSING' } }
function EnsureDir($Path){ if($Path -and -not (Test-Path $Path)){ New-Item -ItemType Directory -Force -Path $Path | Out-Null } }
function ExpectedCounts([int]$Count,[int]$Micro){
  $arr=New-Object System.Collections.ArrayList
  $remaining=$Count
  while($remaining -gt 0){
    $take=[Math]::Min($Micro,$remaining)
    [void]$arr.Add([int]$take)
    $remaining -= $take
  }
  return @($arr)
}
$mem='.runtime/active_compact_semantic_memory_v1'
$before=[ordered]@{manifest=Sha "$mem/manifest.json"; index=Sha "$mem/index.json"; cells=Sha "$mem/cells.jsonl"}
$runId="validator_exact_request_engine_$(Get-Date -Format yyyyMMdd_HHmmss)"
$root=".runtime/exact_request_engine_validation/$runId"
EnsureDir $root
$selectionPath="$root/selection.json"
& powershell -NoProfile -ExecutionPolicy Bypass -File operations/school/memory/select_dynamic_theme_cell_v1.ps1 -RequestedTopics AUTO -PatchSize 1000 -OutputPath $selectionPath | Out-Host
$cases=New-Object System.Collections.ArrayList
$fail=New-Object System.Collections.ArrayList
foreach($count in $Counts){
  if($count -lt 1 -or $count -gt $MaxRequestSize){ [void]$fail.Add(('COUNT_OUT_OF_RANGE:{0}' -f $count)); continue }
  $caseRoot="$root/count_$count"
  EnsureDir $caseRoot
  $planPath="$caseRoot/request_plan.json"
  $plannerOut=@(& powershell -NoProfile -ExecutionPolicy Bypass -File operations/school/request/plan_dynamic_school_request_v1.ps1 -SelectionPath $selectionPath -OutputPath $planPath -ExactRequestSize $count -MicroBatchSize $MicroBatchSize -MaxRequestSize $MaxRequestSize -MaxReadyBacklogCandidates 3000 *>&1 | ForEach-Object{[string]$_})
  $plannerOut | Set-Content -LiteralPath "$caseRoot/planner_stdout.txt" -Encoding UTF8
  if(-not (Test-Path $planPath)){ [void]$fail.Add(('PLAN_MISSING:{0}' -f $count)); continue }
  $plan=Get-Content $planPath -Raw | ConvertFrom-Json
  $taskOut=@(& powershell -NoProfile -ExecutionPolicy Bypass -File operations/school/warehouse/build_codex_warehouse_request_macro_task_v1.ps1 -RequestPlanPath $planPath -SelectionPath $selectionPath -OutputDir "$caseRoot/warehouse_request" *>&1 | ForEach-Object{[string]$_})
  $taskOut | Set-Content -LiteralPath "$caseRoot/task_builder_stdout.txt" -Encoding UTF8
  $taskPath=(($taskOut|Where-Object{$_ -match '^CODEX_WAREHOUSE_DYNAMIC_REQUEST_TASK_JSON='}|Select-Object -Last 1) -replace '^CODEX_WAREHOUSE_DYNAMIC_REQUEST_TASK_JSON=','')
  if([string]::IsNullOrWhiteSpace($taskPath) -or -not (Test-Path $taskPath)){ [void]$fail.Add(('TASK_MISSING:{0}' -f $count)); continue }
  $task=Get-Content $taskPath -Raw | ConvertFrom-Json
  $expected=@(ExpectedCounts $count $MicroBatchSize)
  $actual=@($task.micro_batches | ForEach-Object {[int]$_.candidate_count})
  $expectedMicroCount=$expected.Count
  $expectedLast=$expected[$expected.Count-1]
  $ok=$true
  if($plan.status -ne 'PASS_DYNAMIC_SCHOOL_REQUEST_PLAN_READY_V1'){ $ok=$false; [void]$fail.Add(('BAD_PLAN_STATUS:{0}:{1}' -f $count,$plan.status)) }
  if([int]$plan.request_candidate_count -ne $count){ $ok=$false; [void]$fail.Add(('PLAN_COUNT_MISMATCH:{0}:{1}' -f $count,$plan.request_candidate_count)) }
  if($plan.exact_request_override -ne $true){ $ok=$false; [void]$fail.Add(('EXACT_OVERRIDE_FALSE:{0}' -f $count)) }
  if([int]$plan.micro_batch_count -ne $expectedMicroCount){ $ok=$false; [void]$fail.Add(('PLAN_MICRO_COUNT_MISMATCH:{0}:{1}/{2}' -f $count,$plan.micro_batch_count,$expectedMicroCount)) }
  if([int]$plan.last_micro_batch_size -ne $expectedLast){ $ok=$false; [void]$fail.Add(('PLAN_LAST_MISMATCH:{0}:{1}/{2}' -f $count,$plan.last_micro_batch_size,$expectedLast)) }
  if([int]$task.total_candidate_count -ne $count){ $ok=$false; [void]$fail.Add(('TASK_TOTAL_MISMATCH:{0}:{1}' -f $count,$task.total_candidate_count)) }
  if(@($task.micro_batches).Count -ne $expectedMicroCount){ $ok=$false; [void]$fail.Add(('TASK_MICRO_COUNT_MISMATCH:{0}:{1}/{2}' -f $count,@($task.micro_batches).Count,$expectedMicroCount)) }
  if(($actual -join ',') -ne ($expected -join ',')){ $ok=$false; [void]$fail.Add(('BATCH_COUNTS_MISMATCH:{0}:{1}/{2}' -f $count,($actual -join ','),($expected -join ','))) }
  $sum=0; foreach($x in $actual){ $sum += [int]$x }
  if($sum -ne $count){ $ok=$false; [void]$fail.Add(('BATCH_SUM_MISMATCH:{0}:{1}' -f $count,$sum)) }
  [void]$cases.Add([ordered]@{count=$count; status=if($ok){'PASS'}else{'FAIL'}; micro_batch_size=$MicroBatchSize; micro_batch_count=$actual.Count; last_micro_batch_size=$actual[$actual.Count-1]; batch_counts=$actual; batch_sum=$sum; exact_request_override=[bool]$plan.exact_request_override; task_json=$taskPath})
}
$after=[ordered]@{manifest=Sha "$mem/manifest.json"; index=Sha "$mem/index.json"; cells=Sha "$mem/cells.jsonl"}
if($before.cells -ne $after.cells -or $before.index -ne $after.index -or $before.manifest -ne $after.manifest){ [void]$fail.Add('MEMORY_HASH_CHANGED') }
$status=if($fail.Count -eq 0){'PASS_GENERIC_EXACT_REQUEST_ENGINE_VALIDATION_V1'}else{'FAIL_GENERIC_EXACT_REQUEST_ENGINE_VALIDATION_V1'}
$proof=[ordered]@{schema='generic_exact_request_engine_validation_v1'; status=$status; created_at=(Get-Date).ToString('o'); counts=@($Counts); micro_batch_size=$MicroBatchSize; max_request_size=$MaxRequestSize; case_count=$cases.Count; cases=@($cases); formula='micro_batch_count = ceil(N / MicroBatchSize); batch_i = min(MicroBatchSize, remaining); last batch may be partial'; memory_before=$before; memory_after=$after; memory_changed=($before.cells -ne $after.cells -or $before.index -ne $after.index -or $before.manifest -ne $after.manifest); supersedes='validate_exact_678_dynamic_request_v1.ps1'; failures=@($fail)}
$proofPath='operations/reports/GENERIC_EXACT_REQUEST_ENGINE_VALIDATION_20260715.json'
$proof|ConvertTo-Json -Depth 100|Set-Content -LiteralPath $proofPath -Encoding UTF8
Write-Host "GENERIC_EXACT_REQUEST_ENGINE_VALIDATION_STATUS=$status"
Write-Host "GENERIC_EXACT_REQUEST_ENGINE_VALIDATION_PROOF=$proofPath"
Write-Host "GENERIC_EXACT_REQUEST_ENGINE_CASES=$($cases.Count)"
foreach($c in $cases){ Write-Host ("CASE count=$($c.count)|batches=$($c.batch_counts -join ',')|sum=$($c.batch_sum)|status=$($c.status)") }
Write-Host "GENERIC_EXACT_REQUEST_ENGINE_MEMORY_CHANGED=$($proof.memory_changed)"
if($fail.Count -gt 0){ Write-Host "GENERIC_EXACT_REQUEST_ENGINE_FAILURES=$($fail -join ';')"; exit 1 }
