param(
  [Parameter(Mandatory=$true)][string]$SelectionPath,
  [Parameter(Mandatory=$true)][string]$PatchPlanPath,
  [string]$OutputDir = '',
  [ValidateRange(1,3)][int]$Attempt = 1,
  [string]$PreviousFailureClass = ''
)
$ErrorActionPreference='Stop'
$repoRoot=(git rev-parse --show-toplevel).Trim(); Set-Location $repoRoot
function EnsureDir($Path){ if(-not (Test-Path $Path)){ New-Item -ItemType Directory -Force -Path $Path | Out-Null } }
function WriteJson($Path,$Obj,$Depth=100){ $d=Split-Path -Parent $Path; if($d){ EnsureDir $d }; $Obj|ConvertTo-Json -Depth $Depth|Set-Content -LiteralPath $Path -Encoding UTF8 }
function Slug($s){
  $x=([string]$s).Trim().ToLowerInvariant()
  $x=[regex]::Replace($x, '[^\p{L}\p{Nd}]+', '_')
  $x=$x.Trim('_')
  if([string]::IsNullOrWhiteSpace($x)){ $x='unknown' }
  return $x
}
if(-not (Test-Path $SelectionPath)){ throw "SELECTION_PATH_MISSING:$SelectionPath" }
if(-not (Test-Path $PatchPlanPath)){ throw "PATCH_PLAN_PATH_MISSING:$PatchPlanPath" }
$selection=Get-Content $SelectionPath -Raw | ConvertFrom-Json
$plan=Get-Content $PatchPlanPath -Raw | ConvertFrom-Json
if($selection.status -notin @('PASS_DEVELOPMENT_VECTOR_THEME_SELECTION_V1','PASS_DYNAMIC_THEME_CELL_SELECTION_V1')){ throw "BAD_SELECTION_STATUS:$($selection.status)" }
if($plan.status -notin @('PASS_TOPIC_PATCH_PLAN_READY','PASS_TOPIC_PATCH_PLAN_ALREADY_ABSORBED')){ throw "BAD_PATCH_PLAN_STATUS:$($plan.status)" }
if($null -eq $plan.next_patch){ throw 'NO_NEXT_PATCH_TO_BUILD_CODEX_TASK' }
$patch=$plan.next_patch
if([int]$patch.candidate_count -gt 1000){ throw "PATCH_OVER_1000:$($patch.candidate_count)" }
$topic=[string]$patch.topic_key
if([string]::IsNullOrWhiteSpace($topic)){ $topic=[string]$selection.selected_topic.topic_key }
$template=$selection.codex_request_template
$currentDepth=[int]$template.current_depth
$targetDepth=[int]$template.target_depth
$startDepth=[int]$template.start_depth
if($Attempt -eq 2){
  $candidateLimit=[Math]::Min([int]$patch.candidate_count,500)
  $retryMode='narrowed_retry'
}elseif($Attempt -ge 3){
  $candidateLimit=[Math]::Min([int]$patch.candidate_count,200)
  $retryMode='minimal_retry_or_quarantine_after_failure'
}else{
  $candidateLimit=[int]$patch.candidate_count
  $retryMode='normal'
}
if([string]::IsNullOrWhiteSpace($OutputDir)){ $OutputDir=".runtime/school_patch_runs/$($plan.run_id)/codex_tasks/$($patch.patch_id)_attempt_$Attempt" }
EnsureDir $OutputDir
$candidateOutput="$OutputDir/candidates.jsonl"
$preflightOutput="$OutputDir/PREFLIGHT_PASS.json"
$attemptReport="$OutputDir/codex_attempt_report.json"
$requiredCandidateFields=@(
  'schema',
  'candidate_id',
  'topic_key',
  'topic_label',
  'depth_level',
  'prerequisite_depth',
  'target_depth',
  'source_basis',
  'source_missing',
  'claim',
  'expected_behavior',
  'failure_contrast',
  'validator',
  'proof_requirements',
  'negative_case',
  'return_to_parent',
  'digest_hint',
  'quality_flags'
)
$hardRules=@(
  'single topic only',
  'no active memory mutation',
  'no broad multi-topic pack',
  'no external factual invention without source_basis',
  'no raw archive dump',
  'each candidate must be compact-digest friendly',
  'each candidate must include validator and negative_case',
  'each candidate must include return_to_parent',
  'each candidate must declare depth_level and prerequisite_depth',
  'file writes only after PREFLIGHT_PASS'
)
$retryPolicy=[ordered]@{
  max_attempts=3
  attempt=$Attempt
  retry_mode=$retryMode
  previous_failure_class=$PreviousFailureClass
  on_failure=@(
    'do not decrement Count',
    'do not update memory',
    'record CODEX_FAILED in runtime patch ledger',
    'attempt 2 narrows candidate_limit to 500',
    'attempt 3 narrows candidate_limit to 200',
    'after attempt 3 quarantine topic patch and move to next topic'
  )
}
$task=[ordered]@{
  schema='codex_school_patch_task_v1'
  status='CODEX_TASK_BUILT'
  created_at=(Get-Date).ToString('o')
  run_id=$plan.run_id
  patch_id=$patch.patch_id
  attempt=$Attempt
  mode=$plan.mode
  topic_key=$topic
  topic_label=[string]$selection.selected_topic.label
  selection_reason=[string]$selection.selected_topic.selection_reason
  current_depth=$currentDepth
  start_depth=$startDepth
  target_depth=$targetDepth
  depth_gap=([int]$targetDepth-[int]$currentDepth)
  candidate_limit=$candidateLimit
  original_patch_candidate_count=[int]$patch.candidate_count
  output_candidates_jsonl=$candidateOutput
  preflight_output=$preflightOutput
  attempt_report=$attemptReport
  required_candidate_fields=$requiredCandidateFields
  hard_rules=$hardRules
  acceptance_contract=@(
    'PREFLIGHT_PASS file exists before candidate output write',
    'candidate_count equals requested candidate_limit unless blocked with explicit failure_class',
    'every line is valid JSON',
    'every candidate topic_key equals selected topic_key',
    'every candidate depth_level is between start_depth and target_depth',
    'every candidate has source_basis or source_missing=true',
    'every candidate has expected_behavior, validator, negative_case, proof_requirements, return_to_parent, digest_hint',
    'no candidate mutates active compact memory',
    'final report declares Files changed before PREFLIGHT_PASS: NO'
  )
  failure_classes=@('BROAD_TOPIC_DRIFT','SCHEMA_VIOLATION','EMPTY_OUTPUT','HANG_OR_TIMEOUT','SOURCE_MISSING','PRELIGHT_OR_PREFLIGHT_VIOLATION','WRITES_BEFORE_PREFLIGHT','UNVALIDATABLE_CANDIDATES')
  retry_policy=$retryPolicy
}
$md=@"
# CODEX SCHOOL PATCH TASK

STATUS: CODEX_TASK_BUILT

You are Codex acting as a bounded school material author. You are not the Builder brain. You must create candidate atoms for one school patch only.

## PREFLIGHT

Before writing any candidate output, write this file:

```text
$preflightOutput
```

It must contain JSON with:

```json
{
  "status": "PREFLIGHT_PASS",
  "files_changed_before_preflight": "NO",
  "understood_topic_key": "$topic",
  "candidate_limit": $candidateLimit,
  "output_candidates_jsonl": "$candidateOutput"
}
```

If you cannot satisfy the task, do not write candidates. Write `$attemptReport` with `status=BLOCKED_PREFLIGHT` and a precise `failure_class`.

## TARGET

```text
topic_key = $topic
topic_label = $($task.topic_label)
selection_reason = $($task.selection_reason)
current_depth = $currentDepth
start_depth = $startDepth
target_depth = $targetDepth
candidate_limit = $candidateLimit
attempt = $Attempt
retry_mode = $retryMode
```

Depth rule: start from depth `$startDepth` and create material that advances toward depth `$targetDepth`. Do not jump outside this depth range.

## OUTPUT

Write exactly one JSONL file:

```text
$candidateOutput
```

Each line must be one candidate atom JSON object. Required fields:

```text
$($requiredCandidateFields -join "`n")
```

## CANDIDATE QUALITY RULES

Single topic only. Each candidate must:

```text
- single topic only
- belong only to topic_key: $topic
- declare depth_level and prerequisite_depth
- include source_basis OR source_missing=true
- include expected_behavior
- include validator
- include proof_requirements
- include negative_case
- include failure_contrast
- include return_to_parent
- include digest_hint
- be compact enough for memory digestion
- avoid broad multi-topic expansion
- avoid external facts unless source_basis is explicit
```

## FORBIDDEN

```text
- do not mutate active compact memory
- do not edit runtime active memory
- do not create broad curriculum packs
- do not write reports into tracked repo for every patch
- do not invent source facts
- do not change school scripts
- do not write candidates before PREFLIGHT_PASS
```

## FINAL REPORT

Write:

```text
$attemptReport
```

Required final fields:

```text
status
candidate_count
failure_class
files_changed_before_preflight
output_candidates_jsonl
schema_valid_self_check
single_topic_self_check
depth_self_check
source_self_check
validator_self_check
return_to_parent_self_check
```

The final field `files_changed_before_preflight` must be `NO`.
"@
$taskJson="$OutputDir/codex_school_patch_task.json"
$taskMd="$OutputDir/CODEX_SCHOOL_PATCH_TASK.md"
WriteJson $taskJson $task 100
$md | Set-Content -LiteralPath $taskMd -Encoding UTF8
Write-Host "CODEX_PATCH_TASK_STATUS=CODEX_TASK_BUILT"
Write-Host "CODEX_PATCH_TASK_JSON=$taskJson"
Write-Host "CODEX_PATCH_TASK_MD=$taskMd"
Write-Host "CODEX_PATCH_TASK_TOPIC=$topic"
Write-Host "CODEX_PATCH_TASK_DEPTH=$currentDepth->$targetDepth"
Write-Host "CODEX_PATCH_TASK_CANDIDATE_LIMIT=$candidateLimit"
Write-Host "CODEX_PATCH_TASK_ATTEMPT=$Attempt"
