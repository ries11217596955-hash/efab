param(
  [Parameter(Mandatory=$true)][string]$SelectionPath,
  [string]$OutputPath = '',
  [ValidateRange(1,1000000)][int]$MinRequestSize = 50,
  [ValidateRange(1,1000000)][int]$MaxRequestSize = 50000,
  [ValidateRange(1,10000)][int]$MicroBatchSize = 100,
  [ValidateRange(1,1000000)][int]$MaxReadyBacklogCandidates = 3000,
  [ValidateRange(1,1000000)][int]$ProductionWindowCandidates = 1000,
  [ValidateRange(0,1000000)][int]$ExactRequestSize = 0
)
$ErrorActionPreference='Stop'
$repoRoot=(git rev-parse --show-toplevel).Trim(); Set-Location $repoRoot
function EnsureDir($Path){ if($Path -and -not (Test-Path $Path)){ New-Item -ItemType Directory -Force -Path $Path | Out-Null } }
function WriteJson($Path,$Obj,$Depth=100){ $d=Split-Path -Parent $Path; if($d){ EnsureDir $d }; $Obj|ConvertTo-Json -Depth $Depth|Set-Content -LiteralPath $Path -Encoding UTF8 }
function GetProp($obj,$name,$default=$null){ if($null -ne $obj -and $obj.PSObject.Properties[$name]){ return $obj.PSObject.Properties[$name].Value }; return $default }
function Clamp([int]$v,[int]$lo,[int]$hi){ return [Math]::Max($lo,[Math]::Min($hi,$v)) }
function RoundUpToMicro([int]$v,[int]$micro,[int]$min,[int]$max){
  if($v -le $min){ return $min }
  $r=[int]([Math]::Ceiling($v/[double]$micro)*$micro)
  return (Clamp $r $min $max)
}
if(-not (Test-Path $SelectionPath)){ throw "SELECTION_PATH_MISSING:$SelectionPath" }
$selection=Get-Content $SelectionPath -Raw | ConvertFrom-Json
if($selection.status -notin @('PASS_DEVELOPMENT_VECTOR_THEME_SELECTION_V1','PASS_DYNAMIC_THEME_CELL_SELECTION_V1')){ throw "BAD_SELECTION_STATUS:$($selection.status)" }
$template=$selection.codex_request_template
$topic=[string](GetProp $selection.selected_topic 'topic_key' '')
if([string]::IsNullOrWhiteSpace($topic)){ $topic=[string](GetProp $template 'target_topic' '') }
if([string]::IsNullOrWhiteSpace($topic)){ throw 'TOPIC_KEY_MISSING' }
$label=[string](GetProp $selection.selected_topic 'label' $topic)
$priority=[string](GetProp $template 'priority_queue' (GetProp $selection.selected_topic 'priority_queue' 'unknown'))
$currentDepth=[int](GetProp $template 'current_depth' 0)
$targetDepth=[int](GetProp $template 'target_depth' 1)
$startDepth=[int](GetProp $template 'start_depth' $currentDepth)
$depthGap=[int](GetProp $template 'depth_gap' ([Math]::Max(0,$targetDepth-$currentDepth)))
$reason=[string](GetProp $selection.selected_topic 'selection_reason' '')
$missingLike=($currentDepth -le 0 -or $reason -match '(missing|absent|new|requested_missing|expected_missing)')
# Base request by memory pressure. This is intentionally a request planner, not a producer backlog limit.
if($missingLike -and $depthGap -ge 4){
  $base=20000
  $pressure='MISSING_OR_ZERO_DEPTH_HIGH_GAP'
}elseif($missingLike){
  $base=10000
  $pressure='MISSING_OR_ZERO_DEPTH'
}elseif($depthGap -ge 4){
  $base=10000
  $pressure='HIGH_DEPTH_GAP'
}elseif($depthGap -eq 3){
  $base=5000
  $pressure='MEDIUM_HIGH_DEPTH_GAP'
}elseif($depthGap -eq 2){
  $base=3000
  $pressure='MEDIUM_DEPTH_GAP'
}elseif($depthGap -eq 1){
  $base=1000
  $pressure='LOW_DEPTH_GAP'
}else{
  $base=100
  $pressure='MAINTENANCE_OR_NEAR_COMPLETE'
}
# Priority can raise the request, but never beyond MaxRequestSize.
$priorityBoost=1.0
if($priority -match '(p0|critical|core|head|brain|foundation|priority_1)'){ $priorityBoost=2.5 }
elseif($priority -match '(p1|high|priority_2)'){ $priorityBoost=1.5 }
$raw=[int][Math]::Round($base*$priorityBoost)
$exact_request_override=$false
if($ExactRequestSize -gt 0){
  $requestSize=Clamp $ExactRequestSize $MinRequestSize $MaxRequestSize
  $exact_request_override=$true
} else {
  $requestSize=RoundUpToMicro (Clamp $raw $MinRequestSize $MaxRequestSize) $MicroBatchSize $MinRequestSize $MaxRequestSize
  # If micro size is 100 and min is 50, allow tiny closeout request of 50 only for near-complete low pressure.
  if($pressure -ne 'MAINTENANCE_OR_NEAR_COMPLETE' -and $requestSize -lt $MicroBatchSize){ $requestSize=$MicroBatchSize }
}
$microBatchCount=[int][Math]::Ceiling($requestSize/[double]$MicroBatchSize)
$lastMicroBatchSize=$requestSize - (($microBatchCount-1)*$MicroBatchSize)
$maxReadyBacklogCandidates=Clamp $MaxReadyBacklogCandidates $MicroBatchSize $MaxRequestSize
$maxReadyBacklogBatches=[int][Math]::Ceiling($maxReadyBacklogCandidates/[double]$MicroBatchSize)
$productionWindowCandidates=Clamp $ProductionWindowCandidates $MicroBatchSize $MaxRequestSize
$productionWindowBatches=[int][Math]::Ceiling($productionWindowCandidates/[double]$MicroBatchSize)
$requestId="school_request_{0}_{1}_{2}" -f (($topic -replace '[^A-Za-z0-9_\-]','_').ToLowerInvariant()),$requestSize,(Get-Date -Format 'yyyyMMdd_HHmmss')
if([string]::IsNullOrWhiteSpace($OutputPath)){ $OutputPath=".runtime/school_request_plans/$requestId/request_plan.json" }
$plan=[ordered]@{
  schema='dynamic_school_request_plan_v1'
  status='PASS_DYNAMIC_SCHOOL_REQUEST_PLAN_READY_V1'
  created_at=(Get-Date).ToString('o')
  request_id=$requestId
  selection_path=$SelectionPath
  topic_key=$topic
  topic_label=$label
  priority_queue=$priority
  selection_reason=$reason
  current_depth=$currentDepth
  start_depth=$startDepth
  target_depth=$targetDepth
  depth_gap=$depthGap
  pressure_class=$pressure
  missing_or_zero_depth=$missingLike
  min_request_size=$MinRequestSize
  max_request_size=$MaxRequestSize
  request_candidate_count=$requestSize
  raw_request_before_rounding=$raw
  exact_request_override=$exact_request_override
  exact_request_size_param=$ExactRequestSize
  micro_batch_size=$MicroBatchSize
  micro_batch_count=$microBatchCount
  last_micro_batch_size=$lastMicroBatchSize
  max_ready_backlog_candidates=$maxReadyBacklogCandidates
  max_ready_backlog_batches=$maxReadyBacklogBatches
  production_window_candidates=$productionWindowCandidates
  production_window_batches=$productionWindowBatches
  topic_reselection_rule='after_request_complete_only'
  memory_progress_rule='ABSORBED only'
  codex_role='producer only; no active memory mutation'
  school_role='consumer/validator/digester/absorber; reads READY only'
  next_request_rule='re-read compact memory and development vector after this request is complete/closed'
  request_sizing_rules=@(
    'near-complete or no depth gap => 50-100 maintenance request',
    'low depth gap => 1000',
    'medium depth gap => 3000',
    'medium-high depth gap => 5000',
    'high depth gap => 10000',
    'missing/zero-depth high gap => 20000',
    'priority boost can raise request but never beyond max_request_size',
    'warehouse backlog limit is separate from request size'
  )
  memory_mutated=$false
}
WriteJson $OutputPath $plan 100
Write-Host "DYNAMIC_SCHOOL_REQUEST_PLAN_STATUS=$($plan.status)"
Write-Host "DYNAMIC_SCHOOL_REQUEST_PLAN_PATH=$OutputPath"
Write-Host "DYNAMIC_SCHOOL_REQUEST_TOPIC=$topic"
Write-Host "DYNAMIC_SCHOOL_REQUEST_SIZE=$requestSize"
Write-Host "DYNAMIC_SCHOOL_REQUEST_MICRO_BATCH_SIZE=$MicroBatchSize"
Write-Host "DYNAMIC_SCHOOL_REQUEST_MICRO_BATCH_COUNT=$microBatchCount"
Write-Host "DYNAMIC_SCHOOL_REQUEST_LAST_MICRO_BATCH_SIZE=$lastMicroBatchSize"
Write-Host "DYNAMIC_SCHOOL_REQUEST_EXACT_OVERRIDE=$exact_request_override"
Write-Host "DYNAMIC_SCHOOL_REQUEST_PRESSURE=$pressure"
Write-Host "DYNAMIC_SCHOOL_REQUEST_BACKLOG_LIMIT=$maxReadyBacklogCandidates"
