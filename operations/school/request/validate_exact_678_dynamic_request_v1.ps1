param()
$ErrorActionPreference='Stop'
$repoRoot=(git rev-parse --show-toplevel).Trim(); Set-Location $repoRoot
function Sha($p){ if(Test-Path $p){ (Get-FileHash $p -Algorithm SHA256).Hash } else { 'MISSING' } }
$mem='.runtime/active_compact_semantic_memory_v1'
$before=[ordered]@{manifest=Sha "$mem/manifest.json"; index=Sha "$mem/index.json"; cells=Sha "$mem/cells.jsonl"}
$runId="validator_exact_678_$(Get-Date -Format yyyyMMdd_HHmmss)"
$root=".runtime/exact_678_validation/$runId"
New-Item -ItemType Directory -Force -Path $root | Out-Null
$sel="$root/selection.json"
& powershell -NoProfile -ExecutionPolicy Bypass -File operations/school/memory/select_dynamic_theme_cell_v1.ps1 -RequestedTopics AUTO -PatchSize 1000 -OutputPath $sel | Out-Host
$out=@(& powershell -NoProfile -ExecutionPolicy Bypass -File operations/school/request/plan_dynamic_school_request_v1.ps1 -SelectionPath $sel -OutputPath "$root/request_plan_678.json" -ExactRequestSize 678 -MaxRequestSize 50000 -MicroBatchSize 100 -MaxReadyBacklogCandidates 3000 *>&1 | ForEach-Object{[string]$_})
$out | Set-Content "$root/planner_stdout.txt" -Encoding UTF8
$plan=Get-Content "$root/request_plan_678.json" -Raw | ConvertFrom-Json
$taskOut=@(& powershell -NoProfile -ExecutionPolicy Bypass -File operations/school/warehouse/build_codex_warehouse_request_macro_task_v1.ps1 -RequestPlanPath "$root/request_plan_678.json" -SelectionPath $sel -OutputDir "$root/warehouse_request" *>&1 | ForEach-Object{[string]$_})
$taskPath=(($taskOut|Where-Object{$_ -match '^CODEX_WAREHOUSE_DYNAMIC_REQUEST_TASK_JSON='}|Select-Object -Last 1) -replace '^CODEX_WAREHOUSE_DYNAMIC_REQUEST_TASK_JSON=','')
$task=Get-Content $taskPath -Raw | ConvertFrom-Json
$fail=@()
if($plan.status -ne 'PASS_DYNAMIC_SCHOOL_REQUEST_PLAN_READY_V1'){ $fail += "BAD_PLAN_STATUS:$($plan.status)" }
if([int]$plan.request_candidate_count -ne 678){ $fail += "PLAN_COUNT_NOT_678:$($plan.request_candidate_count)" }
if([int]$plan.micro_batch_count -ne 7){ $fail += "PLAN_MICRO_COUNT_NOT_7:$($plan.micro_batch_count)" }
if([int]$plan.last_micro_batch_size -ne 78){ $fail += "PLAN_LAST_NOT_78:$($plan.last_micro_batch_size)" }
if($plan.exact_request_override -ne $true){ $fail += 'PLAN_EXACT_OVERRIDE_FALSE' }
if([int]$task.total_candidate_count -ne 678){ $fail += "TASK_TOTAL_NOT_678:$($task.total_candidate_count)" }
if(@($task.micro_batches).Count -ne 7){ $fail += "TASK_BATCH_COUNT_NOT_7:$(@($task.micro_batches).Count)" }
$counts=@($task.micro_batches | ForEach-Object {[int]$_.candidate_count})
if(($counts[0..5] | Where-Object { $_ -ne 100 }).Count -gt 0){ $fail += 'FIRST_SIX_NOT_100' }
if($counts[6] -ne 78){ $fail += "LAST_BATCH_NOT_78:$($counts[6])" }
$after=[ordered]@{manifest=Sha "$mem/manifest.json"; index=Sha "$mem/index.json"; cells=Sha "$mem/cells.jsonl"}
if($before.cells -ne $after.cells -or $before.index -ne $after.index -or $before.manifest -ne $after.manifest){ $fail += 'MEMORY_HASH_CHANGED' }
$status=if($fail.Count -eq 0){'PASS_EXACT_678_DYNAMIC_REQUEST_VALIDATION_V1'}else{'FAIL_EXACT_678_DYNAMIC_REQUEST_VALIDATION_V1'}
$proof=[ordered]@{
 schema='exact_678_dynamic_request_validation_v1'
 status=$status
 created_at=(Get-Date).ToString('o')
 selection_path=$sel
 request_plan_path="$root/request_plan_678.json"
 task_json=$taskPath
 topic_key=$plan.topic_key
 request_candidate_count=$plan.request_candidate_count
 micro_batch_size=$plan.micro_batch_size
 micro_batch_count=$plan.micro_batch_count
 last_micro_batch_size=$plan.last_micro_batch_size
 batch_counts=$counts
 exact_request_override=$plan.exact_request_override
 memory_before=$before
 memory_after=$after
 memory_changed=($before.cells -ne $after.cells -or $before.index -ne $after.index -or $before.manifest -ne $after.manifest)
 failures=@($fail)
}
$proofPath='operations/reports/EXACT_678_DYNAMIC_REQUEST_VALIDATION_20260715.json'
$proof|ConvertTo-Json -Depth 100|Set-Content $proofPath -Encoding UTF8
Write-Host "EXACT_678_VALIDATION_STATUS=$status"
Write-Host "EXACT_678_VALIDATION_PROOF=$proofPath"
Write-Host "EXACT_678_BATCH_COUNTS=$($counts -join ',')"
Write-Host "EXACT_678_MEMORY_CHANGED=$($proof.memory_changed)"
if($fail.Count -gt 0){ Write-Host "EXACT_678_FAILURES=$($fail -join ',')"; exit 1 }
