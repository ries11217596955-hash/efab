param(
  [Parameter(Mandatory=$true)][string]$RequestPlanPath,
  [Parameter(Mandatory=$true)][string]$SelectionPath,
  [string]$OutputDir = ''
)
$ErrorActionPreference='Stop'
$repoRoot=(git rev-parse --show-toplevel).Trim(); Set-Location $repoRoot
function EnsureDir($Path){ if($Path -and -not (Test-Path $Path)){ New-Item -ItemType Directory -Force -Path $Path | Out-Null } }
function WriteJson($Path,$Obj,$Depth=100){ $d=Split-Path -Parent $Path; if($d){ EnsureDir $d }; $Obj|ConvertTo-Json -Depth $Depth|Set-Content -LiteralPath $Path -Encoding UTF8 }
if(-not (Test-Path $RequestPlanPath)){ throw "REQUEST_PLAN_MISSING:$RequestPlanPath" }
if(-not (Test-Path $SelectionPath)){ throw "SELECTION_PATH_MISSING:$SelectionPath" }
$request=Get-Content $RequestPlanPath -Raw | ConvertFrom-Json
$selection=Get-Content $SelectionPath -Raw | ConvertFrom-Json
if($request.status -ne 'PASS_DYNAMIC_SCHOOL_REQUEST_PLAN_READY_V1'){ throw "BAD_REQUEST_PLAN_STATUS:$($request.status)" }
if($selection.status -notin @('PASS_DEVELOPMENT_VECTOR_THEME_SELECTION_V1','PASS_DYNAMIC_THEME_CELL_SELECTION_V1')){ throw "BAD_SELECTION_STATUS:$($selection.status)" }
$topic=[string]$request.topic_key
$total=[int]$request.request_candidate_count
$micro=[int]$request.micro_batch_size
$microCount=[int]$request.micro_batch_count
$maxBacklog=[int]$request.max_ready_backlog_candidates
$maxBacklogBatches=[int]$request.max_ready_backlog_batches
if($total -lt 1){ throw 'REQUEST_TOTAL_EMPTY' }
if($total -gt [int]$request.max_request_size){ throw 'REQUEST_EXCEEDS_MAX' }
if($microCount -gt 500){ throw "MICRO_BATCH_COUNT_OVER_HARD_LIMIT:$microCount" }
if([string]::IsNullOrWhiteSpace($OutputDir)){ $OutputDir=".runtime/codex_warehouse_requests/$($request.request_id)" }
$warehouseRoot="$OutputDir/warehouse"
EnsureDir $warehouseRoot
$requiredCandidateFields=@('schema','candidate_id','topic_key','topic_label','depth_level','prerequisite_depth','target_depth','source_basis','source_missing','claim','expected_behavior','failure_contrast','validator','proof_requirements','negative_case','return_to_parent','digest_hint','quality_flags')
$microBatches=@()
for($i=1;$i -le $microCount;$i++){
  $remaining=$total-(($i-1)*$micro)
  $count=[Math]::Min($micro,$remaining)
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
  schema='codex_warehouse_dynamic_request_macro_task_v1'
  status='CODEX_WAREHOUSE_DYNAMIC_REQUEST_TASK_BUILT'
  created_at=(Get-Date).ToString('o')
  request_plan_path=$RequestPlanPath
  selection_path=$SelectionPath
  request_id=$request.request_id
  topic_key=$topic
  topic_label=$request.topic_label
  priority_queue=$request.priority_queue
  pressure_class=$request.pressure_class
  selection_reason=$request.selection_reason
  current_depth=[int]$request.current_depth
  start_depth=[int]$request.start_depth
  target_depth=[int]$request.target_depth
  depth_gap=[int]$request.depth_gap
  total_candidate_count=$total
  micro_batch_size=$micro
  micro_batch_count=$microCount
  max_ready_backlog_candidates=$maxBacklog
  max_ready_backlog_batches=$maxBacklogBatches
  production_window_candidates=[int]$request.production_window_candidates
  production_window_batches=[int]$request.production_window_batches
  warehouse_root=$warehouseRoot
  heartbeat_path="$warehouseRoot/producer.heartbeat.json"
  producer_done_marker="$warehouseRoot/producer.DONE.marker.json"
  producer_failed_marker="$warehouseRoot/producer.FAILED.marker.json"
  warehouse_ledger_path="$warehouseRoot/warehouse_ledger.jsonl"
  required_candidate_fields=$requiredCandidateFields
  micro_batches=$microBatches
  producer_protocol=[ordered]@{
    macro_request_rule="Produce total_candidate_count=$total for one topic, as micro-batches of $micro."
    no_wait_inside_request='Codex may continue producing micro-batches without waiting for School, while respecting backlog limit.'
    backlog_guard="If READY backlog reaches $maxBacklog candidates, pause producer until School drains READY/CONSUMING/ABSORBED backlog."
    output_order=@('WRITING.marker','tmp.jsonl','promote tmp to READY.jsonl, or copy/write READY directly if sandbox denies rename','READY.marker','heartbeat update')
    next_topic_guard='Do not start a new topic/request. School reselects topic only after request is complete/closed.'
  }
  consumer_protocol=[ordered]@{
    ready_only='School consumes only READY marker + READY JSONL. The READY marker is the final consumer-visible signal.'
    waiting='If no READY, School uses heartbeat and bounded wait; no duplicate producer until status is resolved.'
    memory_progress='Only ABSORBED counts as memory progress.'
  }
  hard_rules=@('single topic only','no active memory mutation by Codex','no tracked repo writes by Codex','no unrelated reports','no broad multi-topic pack','warehouse runtime only')
}
$taskJson="$OutputDir/codex_warehouse_dynamic_request_task.json"
$taskMd="$OutputDir/CODEX_WAREHOUSE_DYNAMIC_REQUEST_TASK.md"
WriteJson $taskJson $task 100
$md=@"
# CODEX WAREHOUSE DYNAMIC REQUEST TASK

You are Codex acting only as producer for one School Request. You are not the Builder brain.

## TARGET

```text
topic_key = $topic
topic_label = $($request.topic_label)
pressure_class = $($request.pressure_class)
request_candidate_count = $total
micro_batch_size = $micro
micro_batch_count = $microCount
current_depth = $($request.current_depth)
start_depth = $($request.start_depth)
target_depth = $($request.target_depth)
max_ready_backlog_candidates = $maxBacklog
warehouse_root = $warehouseRoot
```

## PRODUCER RULE

Create `$total` candidates for this single topic. Do not output one huge file. Write `$microCount` micro-batches of up to `$micro` candidates each.

Codex does not wait for School inside the request, except when READY backlog reaches `$maxBacklog` candidates. If backlog is full, pause and keep heartbeat fresh until School drains backlog.

## ATOMIC MICRO-BATCH PROTOCOL

For each micro-batch:

```text
1. write micro_NNN.WRITING.marker.json
2. write micro_NNN.tmp.jsonl
3. promote tmp JSONL to micro_NNN.READY.jsonl only when complete; if sandbox denies rename, write/copy READY.jsonl directly and keep tmp as staging
4. write micro_NNN.READY.marker.json
5. update producer.heartbeat.json
```

School consumes only READY marker + READY JSONL. The READY marker is the final consumer-visible signal. School never consumes WRITING.

## REQUIRED CANDIDATE FIELDS

```text
$($requiredCandidateFields -join "`n")
```

## REQUIRED QUALITY

```text
- every candidate topic_key must equal $topic
- every candidate must declare depth_level between start_depth and target_depth
- every candidate must include source_basis or source_missing=true
- every candidate must include expected_behavior, validator, proof_requirements, negative_case, return_to_parent, digest_hint
- every candidate must be compact-digest friendly
```

## FORBIDDEN

```text
- do not mutate active compact memory
- do not edit tracked repo files
- do not read unrelated reports
- do not create broad multi-topic material
- do not start a new topic or request
```

## HEARTBEAT AND DONE

Heartbeat path:

```text
$($task.heartbeat_path)
```

When all `$microCount` micro-batches are READY, write:

```text
$($task.producer_done_marker)
```
"@
$md | Set-Content -LiteralPath $taskMd -Encoding UTF8
Write-Host "CODEX_WAREHOUSE_DYNAMIC_REQUEST_TASK_STATUS=$($task.status)"
Write-Host "CODEX_WAREHOUSE_DYNAMIC_REQUEST_TASK_JSON=$taskJson"
Write-Host "CODEX_WAREHOUSE_DYNAMIC_REQUEST_TASK_MD=$taskMd"
Write-Host "CODEX_WAREHOUSE_DYNAMIC_REQUEST_SIZE=$total"
Write-Host "CODEX_WAREHOUSE_DYNAMIC_REQUEST_MICRO_BATCH_COUNT=$microCount"
Write-Host "CODEX_WAREHOUSE_DYNAMIC_REQUEST_BACKLOG_LIMIT=$maxBacklog"
