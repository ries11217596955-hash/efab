param()
$ErrorActionPreference='Stop'
$repoRoot=(git rev-parse --show-toplevel).Trim(); Set-Location $repoRoot
function Sha($p){ if(Test-Path $p){ (Get-FileHash $p -Algorithm SHA256).Hash } else { 'MISSING' } }
function EnsureDir($Path){ if($Path -and -not (Test-Path $Path)){ New-Item -ItemType Directory -Force -Path $Path | Out-Null } }
function WriteJson($Path,$Obj,$Depth=100){ $d=Split-Path -Parent $Path; if($d){ EnsureDir $d }; $Obj|ConvertTo-Json -Depth $Depth|Set-Content -LiteralPath $Path -Encoding UTF8 }
$mem='.runtime/active_compact_semantic_memory_v1'
$before=[ordered]@{manifest=Sha "$mem/manifest.json"; index=Sha "$mem/index.json"; cells=Sha "$mem/cells.jsonl"}
$runId="validator_dynamic_request_$(Get-Date -Format yyyyMMdd_HHmmss)"
$root=".runtime/dynamic_school_request_validation/$runId"
EnsureDir $root
$sel="$root/selection_auto.json"
& powershell -NoProfile -ExecutionPolicy Bypass -File operations/school/memory/select_dynamic_theme_cell_v1.ps1 -RequestedTopics AUTO -PatchSize 1000 -OutputPath $sel | Out-Host
$out=@(& powershell -NoProfile -ExecutionPolicy Bypass -File operations/school/request/plan_dynamic_school_request_v1.ps1 -SelectionPath $sel -OutputPath "$root/request_plan.json" -MaxRequestSize 50000 -MicroBatchSize 100 -MaxReadyBacklogCandidates 3000 *>&1 | ForEach-Object{[string]$_})
$out | Set-Content -LiteralPath "$root/planner_stdout.txt" -Encoding UTF8
$planPath=(($out|Where-Object{$_ -match '^DYNAMIC_SCHOOL_REQUEST_PLAN_PATH='}|Select-Object -Last 1) -replace '^DYNAMIC_SCHOOL_REQUEST_PLAN_PATH=','')
$plan=Get-Content $planPath -Raw | ConvertFrom-Json
$fail=@()
if($plan.status -ne 'PASS_DYNAMIC_SCHOOL_REQUEST_PLAN_READY_V1'){ $fail += "BAD_PLAN_STATUS:$($plan.status)" }
if([int]$plan.request_candidate_count -lt 50){ $fail += 'REQUEST_BELOW_MIN' }
if([int]$plan.request_candidate_count -gt 50000){ $fail += 'REQUEST_OVER_MAX' }
if([int]$plan.micro_batch_size -ne 100){ $fail += 'MICRO_SIZE_NOT_100' }
if([int]$plan.max_ready_backlog_candidates -ne 3000){ $fail += 'BACKLOG_NOT_3000' }
if($plan.topic_reselection_rule -ne 'after_request_complete_only'){ $fail += 'BAD_RESELECTION_RULE' }
# Build warehouse dynamic request task and verify total can exceed 1000.
$taskOut=@(& powershell -NoProfile -ExecutionPolicy Bypass -File operations/school/warehouse/build_codex_warehouse_request_macro_task_v1.ps1 -RequestPlanPath $planPath -SelectionPath $sel -OutputDir "$root/warehouse_request" *>&1 | ForEach-Object{[string]$_})
$taskOut | Set-Content -LiteralPath "$root/task_builder_stdout.txt" -Encoding UTF8
$taskPath=(($taskOut|Where-Object{$_ -match '^CODEX_WAREHOUSE_DYNAMIC_REQUEST_TASK_JSON='}|Select-Object -Last 1) -replace '^CODEX_WAREHOUSE_DYNAMIC_REQUEST_TASK_JSON=','')
$task=Get-Content $taskPath -Raw | ConvertFrom-Json
if($task.status -ne 'CODEX_WAREHOUSE_DYNAMIC_REQUEST_TASK_BUILT'){ $fail += "BAD_TASK_STATUS:$($task.status)" }
if([int]$task.total_candidate_count -ne [int]$plan.request_candidate_count){ $fail += 'TASK_TOTAL_MISMATCH' }
if([int]$task.micro_batch_size -ne 100){ $fail += 'TASK_MICRO_NOT_100' }
if([int]$task.max_ready_backlog_candidates -ne 3000){ $fail += 'TASK_BACKLOG_NOT_3000' }
if(@($task.micro_batches).Count -ne [int]$plan.micro_batch_count){ $fail += 'TASK_MICRO_COUNT_MISMATCH' }
if(@($task.micro_batches).Count -gt 500){ $fail += 'TASK_MICRO_COUNT_HARD_LIMIT_EXCEEDED' }
# Synthetic pressure cases: near complete, missing high gap, capped high-priority.
$baseSel=Get-Content $sel -Raw | ConvertFrom-Json
$cases=@(
  @{name='near_complete'; current=4; target=4; reason='maintenance'; priority='p2'; expectedMax=100},
  @{name='missing_high_gap'; current=0; target=4; reason='expected_missing'; priority='p2'; expectedMin=10000},
  @{name='cap_50k'; current=0; target=5; reason='expected_missing'; priority='p0'; expectedExact=50000}
)
$caseResults=@()
foreach($c in $cases){
  $caseSel=$baseSel | ConvertTo-Json -Depth 100 | ConvertFrom-Json
  $caseSel.selected_topic.selection_reason=$c.reason
  $caseSel.codex_request_template.current_depth=$c.current
  $caseSel.codex_request_template.start_depth=$c.current
  $caseSel.codex_request_template.target_depth=$c.target
  $caseSel.codex_request_template.depth_gap=([Math]::Max(0,$c.target-$c.current))
  $caseSel.codex_request_template.priority_queue=$c.priority
  $casePath="$root/selection_$($c.name).json"
  $caseSel|ConvertTo-Json -Depth 100|Set-Content -LiteralPath $casePath -Encoding UTF8
  $caseOut=@(& powershell -NoProfile -ExecutionPolicy Bypass -File operations/school/request/plan_dynamic_school_request_v1.ps1 -SelectionPath $casePath -OutputPath "$root/request_$($c.name).json" -MaxRequestSize 50000 -MicroBatchSize 100 -MaxReadyBacklogCandidates 3000 *>&1 | ForEach-Object{[string]$_})
  $casePlan=Get-Content "$root/request_$($c.name).json" -Raw | ConvertFrom-Json
  if($c.ContainsKey('expectedMax') -and [int]$casePlan.request_candidate_count -gt [int]$c.expectedMax){ $fail += "CASE_$($c.name)_OVER_MAX:$($casePlan.request_candidate_count)" }
  if($c.ContainsKey('expectedMin') -and [int]$casePlan.request_candidate_count -lt [int]$c.expectedMin){ $fail += "CASE_$($c.name)_BELOW_MIN:$($casePlan.request_candidate_count)" }
  if($c.ContainsKey('expectedExact') -and [int]$casePlan.request_candidate_count -ne [int]$c.expectedExact){ $fail += "CASE_$($c.name)_NOT_EXACT:$($casePlan.request_candidate_count)" }
  $caseResults += [ordered]@{case=$c.name; request_candidate_count=[int]$casePlan.request_candidate_count; micro_batch_count=[int]$casePlan.micro_batch_count; pressure_class=$casePlan.pressure_class; priority_queue=$casePlan.priority_queue}
}
$after=[ordered]@{manifest=Sha "$mem/manifest.json"; index=Sha "$mem/index.json"; cells=Sha "$mem/cells.jsonl"}
if($before.cells -ne $after.cells -or $before.index -ne $after.index -or $before.manifest -ne $after.manifest){ $fail += 'MEMORY_HASH_CHANGED' }
$status=if($fail.Count -eq 0){'PASS_DYNAMIC_SCHOOL_REQUEST_PLANNER_VALIDATION_V1'}else{'FAIL_DYNAMIC_SCHOOL_REQUEST_PLANNER_VALIDATION_V1'}
$proof=[ordered]@{
  schema='dynamic_school_request_planner_validation_v1'
  status=$status
  created_at=(Get-Date).ToString('o')
  selection_path=$sel
  request_plan_path=$planPath
  warehouse_request_task=$taskPath
  selected_topic=$plan.topic_key
  selected_pressure_class=$plan.pressure_class
  selected_request_candidate_count=$plan.request_candidate_count
  selected_micro_batch_size=$plan.micro_batch_size
  selected_micro_batch_count=$plan.micro_batch_count
  selected_max_ready_backlog_candidates=$plan.max_ready_backlog_candidates
  selected_topic_reselection_rule=$plan.topic_reselection_rule
  task_total_candidate_count=$task.total_candidate_count
  task_micro_batch_count=@($task.micro_batches).Count
  synthetic_cases=$caseResults
  memory_before=$before
  memory_after=$after
  memory_changed=($before.cells -ne $after.cells -or $before.index -ne $after.index -or $before.manifest -ne $after.manifest)
  failures=@($fail)
}
$proofPath='operations/reports/DYNAMIC_SCHOOL_REQUEST_PLANNER_VALIDATION_20260715.json'
$proof|ConvertTo-Json -Depth 100|Set-Content -LiteralPath $proofPath -Encoding UTF8
Write-Host "DYNAMIC_SCHOOL_REQUEST_PLANNER_VALIDATION_STATUS=$status"
Write-Host "DYNAMIC_SCHOOL_REQUEST_PLANNER_VALIDATION_PROOF=$proofPath"
Write-Host "DYNAMIC_SCHOOL_REQUEST_SELECTED_SIZE=$($plan.request_candidate_count)"
Write-Host "DYNAMIC_SCHOOL_REQUEST_SELECTED_MICRO_BATCH_COUNT=$($plan.micro_batch_count)"
Write-Host "DYNAMIC_SCHOOL_REQUEST_TASK_TOTAL=$($task.total_candidate_count)"
Write-Host "DYNAMIC_SCHOOL_REQUEST_MEMORY_CHANGED=$($proof.memory_changed)"
if($fail.Count -gt 0){ Write-Host "DYNAMIC_SCHOOL_REQUEST_FAILURES=$($fail -join ',')"; exit 1 }
