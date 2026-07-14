param()
$ErrorActionPreference='Stop'
$repoRoot=(git rev-parse --show-toplevel).Trim(); Set-Location $repoRoot
function Sha($p){ if(Test-Path $p){ (Get-FileHash $p -Algorithm SHA256).Hash } else { 'MISSING' } }
function EnsureDir($Path){ if($Path -and -not (Test-Path $Path)){ New-Item -ItemType Directory -Force -Path $Path | Out-Null } }
function WriteJson($Path,$Obj,$Depth=80){ $d=Split-Path -Parent $Path; if($d){ EnsureDir $d }; $Obj|ConvertTo-Json -Depth $Depth|Set-Content -LiteralPath $Path -Encoding UTF8 }
$mem='.runtime/active_compact_semantic_memory_v1'
$before=[ordered]@{manifest=Sha "$mem/manifest.json"; index=Sha "$mem/index.json"; cells=Sha "$mem/cells.jsonl"}
$runId="validator_warehouse_$(Get-Date -Format yyyyMMdd_HHmmss)"
$root=".runtime/codex_warehouse_validation/$runId"
$selectionPath="$root/selection.json"
$planPath="$root/topic_patch_plan.json"
& powershell -NoProfile -ExecutionPolicy Bypass -File operations/school/memory/select_dynamic_theme_cell_v1.ps1 -RequestedTopics 'codex_school_task_template_strength' -PatchSize 1000 -OutputPath $selectionPath | Out-Host
& powershell -NoProfile -ExecutionPolicy Bypass -File operations/school/plan_topic_patch_cycle_v1.ps1 -Count 1000 -Mode Test -Topics 'codex_school_task_template_strength' -RunId $runId -PatchSize 1000 -DynamicSelectionPath $selectionPath -OutputPath $planPath | Out-Host
$out=@(& powershell -NoProfile -ExecutionPolicy Bypass -File operations/school/warehouse/build_codex_warehouse_macro_task_v1.ps1 -SelectionPath $selectionPath -PatchPlanPath $planPath -OutputDir "$root/macro" -MicroBatchSize 100 *>&1 | ForEach-Object{[string]$_})
$out | Set-Content -LiteralPath "$root/builder_stdout.txt" -Encoding UTF8
$taskPath=(($out|Where-Object{$_ -match '^CODEX_WAREHOUSE_MACRO_TASK_JSON='}|Select-Object -Last 1) -replace '^CODEX_WAREHOUSE_MACRO_TASK_JSON=','')
$task=Get-Content $taskPath -Raw | ConvertFrom-Json
$fail=@()
if($task.status -ne 'CODEX_WAREHOUSE_MACRO_TASK_BUILT'){ $fail += "BAD_TASK_STATUS:$($task.status)" }
if([int]$task.micro_batch_size -ne 100){ $fail += "BAD_MICRO_SIZE:$($task.micro_batch_size)" }
if([int]$task.micro_batch_count -ne 10){ $fail += "BAD_MICRO_COUNT:$($task.micro_batch_count)" }
# Mock producer makes micro_001 READY.
$mb=$task.micro_batches[0]
WriteJson ([string]$mb.writing_marker) ([ordered]@{status='WRITING'; micro_batch_id=$mb.micro_batch_id; updated_at=(Get-Date).ToString('o')}) 20
$rows=New-Object System.Collections.ArrayList
for($i=1;$i -le [int]$mb.candidate_count;$i++){
  $depth=1 + (($i-1) % [Math]::Max(1,[int]$task.target_depth))
  $obj=[ordered]@{
    schema='codex_school_patch_candidate_v1'
    candidate_id=("warehouse.mock.{0:D6}" -f $i)
    topic_key=$task.topic_key
    topic_label=$task.topic_label
    depth_level=$depth
    prerequisite_depth=[Math]::Max(0,$depth-1)
    target_depth=$task.target_depth
    source_basis=@('warehouse mock validator source')
    source_missing=$false
    claim="Warehouse mock candidate $i for $($task.topic_key)"
    expected_behavior="Builder applies $($task.topic_key) micro-batch rule $i with proof boundary."
    failure_contrast="Without it Builder consumes unready or unvalidated warehouse material."
    validator="Check READY marker, topic, depth, source, proof, validator, negative case, return-to-parent."
    proof_requirements="Consumer report must show accepted_count and memory_changed=false without absorption."
    negative_case="Reject WRITING-only files and missing source/proof/validator fields."
    return_to_parent="Improves warehouse producer-consumer patch flow."
    digest_hint="Compact into $($task.topic_key) after absorption only."
    quality_flags=@('mock','warehouse','validator_safe')
  }
  [void]$rows.Add($obj)
}
($rows|ForEach-Object{$_|ConvertTo-Json -Depth 50 -Compress}) -join "`n" | Set-Content -LiteralPath ([string]$mb.tmp_jsonl) -Encoding UTF8
Move-Item -LiteralPath ([string]$mb.tmp_jsonl) -Destination ([string]$mb.ready_jsonl) -Force
WriteJson ([string]$mb.ready_marker) ([ordered]@{status='READY'; micro_batch_id=$mb.micro_batch_id; candidate_count=[int]$mb.candidate_count; updated_at=(Get-Date).ToString('o')}) 20
WriteJson ([string]$task.heartbeat_path) ([ordered]@{status='PRODUCER_RUNNING'; patch_id=$task.patch_id; last_written_batch=1; updated_at=(Get-Date).ToString('o')}) 20
$consumeOut=@(& powershell -NoProfile -ExecutionPolicy Bypass -File operations/school/warehouse/consume_codex_warehouse_micro_batches_v1.ps1 -MacroTaskJsonPath $taskPath -MaxConsumeBatches 1 -MaxWaitSeconds 0 *>&1 | ForEach-Object{[string]$_})
$consumeOut | Set-Content -LiteralPath "$root/consumer_ready_stdout.txt" -Encoding UTF8
$consumerReport=(($consumeOut|Where-Object{$_ -match '^CODEX_WAREHOUSE_CONSUMER_REPORT='}|Select-Object -Last 1) -replace '^CODEX_WAREHOUSE_CONSUMER_REPORT=','')
$consumer=Get-Content $consumerReport -Raw | ConvertFrom-Json
if($consumer.status -ne 'PASS_WAREHOUSE_CONSUMED_READY_BATCHES_NO_ABSORB_V1'){ $fail += "BAD_CONSUMER_READY_STATUS:$($consumer.status)" }
if(@($consumer.consumed_batches).Count -ne 1){ $fail += 'CONSUMED_BATCH_COUNT_NOT_1' }
if([int]$consumer.consumed_batches[0].accepted_count -ne 100){ $fail += "ACCEPTED_NOT_100:$($consumer.consumed_batches[0].accepted_count)" }
if($consumer.memory_changed -ne $false){ $fail += 'READY_CONSUMER_MEMORY_CHANGED' }
# School ahead scenario: no READY, fresh heartbeat, bounded timeout.
$waitRoot="$root/wait_case"
Copy-Item -LiteralPath $taskPath -Destination "$waitRoot.task.json" -Force
$waitTaskPath="$waitRoot.task.json"
$waitTask=Get-Content $waitTaskPath -Raw | ConvertFrom-Json
$waitTask.warehouse_root="$root/wait_warehouse"
$waitTask.heartbeat_path="$root/wait_warehouse/producer.heartbeat.json"
$waitTask.producer_done_marker="$root/wait_warehouse/producer.DONE.marker.json"
$waitTask.producer_failed_marker="$root/wait_warehouse/producer.FAILED.marker.json"
$waitTask.warehouse_ledger_path="$root/wait_warehouse/warehouse_ledger.jsonl"
foreach($x in $waitTask.micro_batches){
  $id=$x.micro_batch_id
  $x.tmp_jsonl="$root/wait_warehouse/$id.tmp.jsonl"; $x.writing_marker="$root/wait_warehouse/$id.WRITING.marker.json"; $x.ready_jsonl="$root/wait_warehouse/$id.READY.jsonl"; $x.ready_marker="$root/wait_warehouse/$id.READY.marker.json"; $x.consuming_marker="$root/wait_warehouse/$id.CONSUMING.marker.json"; $x.normalized_atoms_jsonl="$root/wait_warehouse/$id.normalized_atoms.jsonl"; $x.normalization_report="$root/wait_warehouse/$id.normalization_report.json"; $x.absorbed_marker="$root/wait_warehouse/$id.ABSORBED.marker.json"; $x.cleaned_marker="$root/wait_warehouse/$id.CLEANED.marker.json"; $x.failed_marker="$root/wait_warehouse/$id.FAILED.marker.json"
}
WriteJson $waitTaskPath $waitTask 100
EnsureDir "$root/wait_warehouse"
WriteJson ([string]$waitTask.heartbeat_path) ([ordered]@{status='PRODUCER_RUNNING'; patch_id=$waitTask.patch_id; last_written_batch=0; updated_at=(Get-Date).ToString('o')}) 20
$waitOut=@(& powershell -NoProfile -ExecutionPolicy Bypass -File operations/school/warehouse/consume_codex_warehouse_micro_batches_v1.ps1 -MacroTaskJsonPath $waitTaskPath -MaxConsumeBatches 1 -MaxWaitSeconds 1 -PollSeconds 1 *>&1 | ForEach-Object{[string]$_})
$waitOut | Set-Content -LiteralPath "$root/consumer_wait_stdout.txt" -Encoding UTF8
$waitReport=(($waitOut|Where-Object{$_ -match '^CODEX_WAREHOUSE_CONSUMER_REPORT='}|Select-Object -Last 1) -replace '^CODEX_WAREHOUSE_CONSUMER_REPORT=','')
$waitConsumer=Get-Content $waitReport -Raw | ConvertFrom-Json
if($waitConsumer.status -ne 'PASS_WAREHOUSE_CONSUMER_WAIT_TIMEOUT_NO_READY_V1'){ $fail += "BAD_WAIT_STATUS:$($waitConsumer.status)" }
if($waitConsumer.memory_changed -ne $false){ $fail += 'WAIT_CONSUMER_MEMORY_CHANGED' }
$after=[ordered]@{manifest=Sha "$mem/manifest.json"; index=Sha "$mem/index.json"; cells=Sha "$mem/cells.jsonl"}
if($before.cells -ne $after.cells -or $before.index -ne $after.index -or $before.manifest -ne $after.manifest){ $fail += 'MEMORY_HASH_CHANGED' }
$status=if($fail.Count -eq 0){'PASS_CODEX_WAREHOUSE_PIPELINE_VALIDATION_V1'}else{'FAIL_CODEX_WAREHOUSE_PIPELINE_VALIDATION_V1'}
$proof=[ordered]@{
  schema='codex_warehouse_pipeline_validation_v1'
  status=$status
  created_at=(Get-Date).ToString('o')
  macro_task=$taskPath
  warehouse_root=$task.warehouse_root
  patch_candidate_count=$task.patch_candidate_count
  micro_batch_size=$task.micro_batch_size
  micro_batch_count=$task.micro_batch_count
  ready_consumer_report=$consumerReport
  ready_consumer_status=$consumer.status
  ready_consumed_count=@($consumer.consumed_batches).Count
  ready_accepted_count=$consumer.consumed_batches[0].accepted_count
  wait_consumer_report=$waitReport
  wait_consumer_status=$waitConsumer.status
  memory_before=$before
  memory_after=$after
  memory_changed=($before.cells -ne $after.cells -or $before.index -ne $after.index -or $before.manifest -ne $after.manifest)
  failures=@($fail)
}
$proofPath='operations/reports/CODEX_WAREHOUSE_PIPELINE_VALIDATION_20260714.json'
$proof|ConvertTo-Json -Depth 100|Set-Content -LiteralPath $proofPath -Encoding UTF8
Write-Host "CODEX_WAREHOUSE_PIPELINE_VALIDATION_STATUS=$status"
Write-Host "CODEX_WAREHOUSE_PIPELINE_VALIDATION_PROOF=$proofPath"
Write-Host "CODEX_WAREHOUSE_READY_CONSUMER_STATUS=$($consumer.status)"
Write-Host "CODEX_WAREHOUSE_WAIT_CONSUMER_STATUS=$($waitConsumer.status)"
Write-Host "CODEX_WAREHOUSE_MEMORY_CHANGED=$($proof.memory_changed)"
if($fail.Count -gt 0){ Write-Host "CODEX_WAREHOUSE_FAILURES=$($fail -join ',')"; exit 1 }
