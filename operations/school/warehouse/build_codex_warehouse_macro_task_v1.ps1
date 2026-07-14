param(
  [Parameter(Mandatory=$true)][string]$SelectionPath,
  [Parameter(Mandatory=$true)][string]$PatchPlanPath,
  [string]$OutputDir = '',
  [ValidateRange(1,1000)][int]$MicroBatchSize = 100,
  [ValidateRange(1,100)][int]$MaxBacklogBatches = 10
)
$ErrorActionPreference='Stop'
$repoRoot=(git rev-parse --show-toplevel).Trim(); Set-Location $repoRoot
function EnsureDir($Path){ if($Path -and -not (Test-Path $Path)){ New-Item -ItemType Directory -Force -Path $Path | Out-Null } }
function WriteJson($Path,$Obj,$Depth=100){ $d=Split-Path -Parent $Path; if($d){ EnsureDir $d }; $Obj|ConvertTo-Json -Depth $Depth|Set-Content -LiteralPath $Path -Encoding UTF8 }
if(-not (Test-Path $SelectionPath)){ throw "SELECTION_PATH_MISSING:$SelectionPath" }
if(-not (Test-Path $PatchPlanPath)){ throw "PATCH_PLAN_PATH_MISSING:$PatchPlanPath" }
$selection=Get-Content $SelectionPath -Raw | ConvertFrom-Json
$plan=Get-Content $PatchPlanPath -Raw | ConvertFrom-Json
if($selection.status -notin @('PASS_DEVELOPMENT_VECTOR_THEME_SELECTION_V1','PASS_DYNAMIC_THEME_CELL_SELECTION_V1')){ throw "BAD_SELECTION_STATUS:$($selection.status)" }
if($plan.status -notin @('PASS_TOPIC_PATCH_PLAN_READY','PASS_TOPIC_PATCH_PLAN_ALREADY_ABSORBED')){ throw "BAD_PATCH_PLAN_STATUS:$($plan.status)" }
if($null -eq $plan.next_patch){ throw 'NO_NEXT_PATCH_FOR_WAREHOUSE_TASK' }
$patch=$plan.next_patch
$patchCount=[int]$patch.candidate_count
if($patchCount -lt 1){ throw 'PATCH_COUNT_EMPTY' }
if($MicroBatchSize -gt $patchCount){ $MicroBatchSize=$patchCount }
$microCount=[int][Math]::Ceiling($patchCount / [double]$MicroBatchSize)
if($microCount -gt $MaxBacklogBatches){ throw "MICRO_COUNT_EXCEEDS_BACKLOG_LIMIT:$microCount/$MaxBacklogBatches" }
if([string]::IsNullOrWhiteSpace($OutputDir)){ $OutputDir=".runtime/codex_warehouse/$($plan.run_id)/$($patch.patch_id)" }
$warehouseRoot="$OutputDir/warehouse"
EnsureDir $warehouseRoot
$topic=[string]$patch.topic_key
if([string]::IsNullOrWhiteSpace($topic)){ $topic=[string]$selection.selected_topic.topic_key }
$template=$selection.codex_request_template
$requiredCandidateFields=@(
  'schema','candidate_id','topic_key','topic_label','depth_level','prerequisite_depth','target_depth','source_basis','source_missing','claim','expected_behavior','failure_contrast','validator','proof_requirements','negative_case','return_to_parent','digest_hint','quality_flags'
)
$microBatches=@()
for($i=1;$i -le $microCount;$i++){
  $remaining=$patchCount-(($i-1)*$MicroBatchSize)
  $count=[Math]::Min($MicroBatchSize,$remaining)
  $id=("micro_{0:D3}" -f $i)
  $microBatches += [ordered]@{
    micro_batch_id=$id
    sequence=$i
    candidate_count=$count
    tmp_jsonl="$warehouseRoot/$id.tmp.jsonl"
    writing_marker="$warehouseRoot/$id.WRITING.marker.json"
    ready_jsonl="$warehouseRoot/$id.READY.jsonl"
    ready_marker="$warehouseRoot/$id.READY.marker.json"
    consuming_marker="$warehouseRoot/$id.CONSUMING.marker.json"
    normalized_atoms_jsonl="$warehouseRoot/$id.normalized_atoms.jsonl"
    normalization_report="$warehouseRoot/$id.normalization_report.json"
    absorbed_marker="$warehouseRoot/$id.ABSORBED.marker.json"
    cleaned_marker="$warehouseRoot/$id.CLEANED.marker.json"
    failed_marker="$warehouseRoot/$id.FAILED.marker.json"
  }
}
$task=[ordered]@{
  schema='codex_warehouse_macro_task_v1'
  status='CODEX_WAREHOUSE_MACRO_TASK_BUILT'
  created_at=(Get-Date).ToString('o')
  run_id=$plan.run_id
  patch_id=$patch.patch_id
  mode=$plan.mode
  topic_key=$topic
  topic_label=[string]$selection.selected_topic.label
  selection_reason=[string]$selection.selected_topic.selection_reason
  current_depth=[int]$template.current_depth
  start_depth=[int]$template.start_depth
  target_depth=[int]$template.target_depth
  patch_candidate_count=$patchCount
  micro_batch_size=$MicroBatchSize
  micro_batch_count=$microCount
  max_backlog_batches=$MaxBacklogBatches
  warehouse_root=$warehouseRoot
  heartbeat_path="$warehouseRoot/producer.heartbeat.json"
  producer_done_marker="$warehouseRoot/producer.DONE.marker.json"
  producer_failed_marker="$warehouseRoot/producer.FAILED.marker.json"
  warehouse_ledger_path="$warehouseRoot/warehouse_ledger.jsonl"
  required_candidate_fields=$requiredCandidateFields
  micro_batches=$microBatches
  producer_protocol=[ordered]@{
    write_order=@('WRITING.marker','tmp.jsonl','atomic rename tmp.jsonl to READY.jsonl','READY.marker','heartbeat update')
    ready_rule='School may consume only READY.jsonl with READY.marker.json. WRITING is never consumed.'
    no_wait_rule='Codex does not wait for School inside one patch; it fills warehouse up to patch micro-batch count.'
    next_patch_guard='Codex must not start next patch until current warehouse is closed/cleaned by School policy.'
  }
  consumer_protocol=[ordered]@{
    waiting_rule='If no READY exists, School checks heartbeat, producer markers, stale WRITING markers, and bounded wait.'
    counted_memory_state='ABSORBED only'
    uncounted_states=@('READY','CONSUMING','VALIDATED_NORMALIZED','FAILED','QUARANTINED','CLEANED_WITHOUT_ABSORB')
    stale_writing_recovery='Stale WRITING marker is not consumed. It is classified for retry/quarantine.'
  }
  hard_rules=@('single topic only','no active memory mutation by Codex','no broad multi-topic pack','no external facts without source_basis','no reading unrelated reports','no tracked repo report per micro-batch','runtime warehouse only')
}
$taskJson="$OutputDir/codex_warehouse_macro_task.json"
$taskMd="$OutputDir/CODEX_WAREHOUSE_MACRO_TASK.md"
WriteJson $taskJson $task 100
$md=@"
# CODEX WAREHOUSE MACRO TASK

STATUS: CODEX_WAREHOUSE_MACRO_TASK_BUILT

You are Codex acting only as producer for one school patch warehouse. You are not the Builder brain.

## TARGET

```text
topic_key = $topic
topic_label = $($task.topic_label)
patch_candidate_count = $patchCount
micro_batch_size = $MicroBatchSize
micro_batch_count = $microCount
current_depth = $($task.current_depth)
start_depth = $($task.start_depth)
target_depth = $($task.target_depth)
warehouse_root = $warehouseRoot
```

## PRODUCER RULE

Codex receives one patch of `$patchCount` candidates, but writes it as `$microCount` micro-batches of up to `$MicroBatchSize` candidates.
Codex does not wait for School inside this patch. Codex fills the warehouse and then writes producer DONE.

## ATOMIC OUTPUT PROTOCOL

For each micro-batch:

```text
1. write WRITING marker
2. write tmp JSONL
3. rename tmp JSONL to READY JSONL only when complete
4. write READY marker
5. update producer heartbeat
```

School consumes only READY marker + READY JSONL. The READY marker is the final consumer-visible signal. School never consumes WRITING.

## REQUIRED CANDIDATE FIELDS

```text
$($requiredCandidateFields -join "`n")
```

## MICRO-BATCH OUTPUTS

```text
$($microBatches | ForEach-Object { "$($_.micro_batch_id): count=$($_.candidate_count); tmp=$($_.tmp_jsonl); ready=$($_.ready_jsonl); marker=$($_.ready_marker)" } | Out-String)
```

## FORBIDDEN

```text
- do not mutate active compact memory
- do not edit tracked repo files
- do not read unrelated reports
- do not invent external facts without source_basis
- do not create broad multi-topic material
- do not start next patch
```

## PRODUCER HEARTBEAT

Write/update:

```text
$($task.heartbeat_path)
```

Fields:

```text
status = PRODUCER_RUNNING | PRODUCER_DONE | PRODUCER_FAILED
patch_id
last_written_batch
updated_at
```

When all micro-batches are READY, write:

```text
$($task.producer_done_marker)
```
"@
$md | Set-Content -LiteralPath $taskMd -Encoding UTF8
Write-Host "CODEX_WAREHOUSE_MACRO_TASK_STATUS=$($task.status)"
Write-Host "CODEX_WAREHOUSE_MACRO_TASK_JSON=$taskJson"
Write-Host "CODEX_WAREHOUSE_MACRO_TASK_MD=$taskMd"
Write-Host "CODEX_WAREHOUSE_ROOT=$warehouseRoot"
Write-Host "CODEX_WAREHOUSE_TOPIC=$topic"
Write-Host "CODEX_WAREHOUSE_PATCH_COUNT=$patchCount"
Write-Host "CODEX_WAREHOUSE_MICRO_BATCH_SIZE=$MicroBatchSize"
Write-Host "CODEX_WAREHOUSE_MICRO_BATCH_COUNT=$microCount"
