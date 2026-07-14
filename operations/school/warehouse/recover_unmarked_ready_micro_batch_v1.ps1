param(
  [Parameter(Mandatory=$true)][string]$MacroTaskJsonPath,
  [Parameter(Mandatory=$true)][string]$MicroBatchId,
  [string]$ReportPath = ''
)
$ErrorActionPreference='Stop'
$repoRoot=(git rev-parse --show-toplevel).Trim(); Set-Location $repoRoot
function EnsureDir($Path){ if($Path -and -not (Test-Path $Path)){ New-Item -ItemType Directory -Force -Path $Path | Out-Null } }
function WriteJson($Path,$Obj,$Depth=80){ $d=Split-Path -Parent $Path; if($d){ EnsureDir $d }; $Obj|ConvertTo-Json -Depth $Depth|Set-Content -LiteralPath $Path -Encoding UTF8 }
if(-not (Test-Path $MacroTaskJsonPath)){ throw "MACRO_TASK_MISSING:$MacroTaskJsonPath" }
$task=Get-Content $MacroTaskJsonPath -Raw | ConvertFrom-Json
$mb=@($task.micro_batches | Where-Object { $_.micro_batch_id -eq $MicroBatchId } | Select-Object -First 1)
if($null -eq $mb){ throw "MICRO_BATCH_NOT_FOUND:$MicroBatchId" }
$readyJsonl=[string]$mb.ready_jsonl
$readyMarker=[string]$mb.ready_marker
$tmpJsonl=[string]$mb.tmp_jsonl
$writingMarker=[string]$mb.writing_marker
if(-not (Test-Path $readyJsonl)){ throw "READY_JSONL_MISSING:$readyJsonl" }
if(Test-Path $readyMarker){ throw "READY_MARKER_ALREADY_EXISTS:$readyMarker" }
$lineCount=(Get-Content $readyJsonl | Measure-Object).Count
$expected=[int]$mb.candidate_count
$fail=@()
if($lineCount -ne $expected){ $fail += "LINE_COUNT_MISMATCH:$lineCount/$expected" }
$badJson=0
$wrongTopic=0
$missingRequired=0
$topic=[string]$task.topic_key
$required=@('schema','candidate_id','topic_key','topic_label','depth_level','prerequisite_depth','target_depth','source_basis','source_missing','claim','expected_behavior','failure_contrast','validator','proof_requirements','negative_case','return_to_parent','digest_hint','quality_flags')
foreach($line in Get-Content $readyJsonl){
  if([string]::IsNullOrWhiteSpace($line)){ continue }
  try{ $o=$line|ConvertFrom-Json }catch{ $badJson++; continue }
  if([string]$o.topic_key -ne $topic){ $wrongTopic++ }
  foreach($f in $required){ if(-not $o.PSObject.Properties[$f]){ $missingRequired++; break } }
}
if($badJson -gt 0){ $fail += "BAD_JSON_LINES:$badJson" }
if($wrongTopic -gt 0){ $fail += "WRONG_TOPIC_LINES:$wrongTopic" }
if($missingRequired -gt 0){ $fail += "MISSING_REQUIRED_LINES:$missingRequired" }
if($fail.Count -gt 0){ throw "RECOVERY_VALIDATION_FAILED:$($fail -join ',')" }
$marker=[ordered]@{
  schema='codex_warehouse_micro_marker_v1'
  status='READY_RECOVERED_BY_SCHOOL'
  micro_batch_id=$MicroBatchId
  topic_key=$topic
  candidate_count=$lineCount
  ready_jsonl=$readyJsonl
  recovery_reason='READY_JSONL_EXISTED_WITHOUT_READY_MARKER_AFTER_CODEX_TIMEOUT_OR_MARKER_WRITE_FAILURE'
  tmp_jsonl_exists=(Test-Path $tmpJsonl)
  writing_marker_exists=(Test-Path $writingMarker)
  recovered_at=(Get-Date).ToString('o')
  absorption_run=$false
}
WriteJson $readyMarker $marker 50
if([string]::IsNullOrWhiteSpace($ReportPath)){ $ReportPath=(Join-Path (Split-Path -Parent $readyJsonl) "$MicroBatchId.recovery_report.json") }
$report=[ordered]@{
  schema='codex_warehouse_unmarked_ready_recovery_v1'
  status='PASS_CODEX_WAREHOUSE_UNMARKED_READY_RECOVERY_V1'
  created_at=(Get-Date).ToString('o')
  macro_task=$MacroTaskJsonPath
  micro_batch_id=$MicroBatchId
  ready_jsonl=$readyJsonl
  ready_marker=$readyMarker
  line_count=$lineCount
  expected_count=$expected
  bad_json_lines=$badJson
  wrong_topic_lines=$wrongTopic
  missing_required_lines=$missingRequired
  tmp_jsonl_exists=(Test-Path $tmpJsonl)
  writing_marker_exists=(Test-Path $writingMarker)
  absorption_run=$false
}
WriteJson $ReportPath $report 80
Write-Host "WAREHOUSE_UNMARKED_READY_RECOVERY_STATUS=$($report.status)"
Write-Host "WAREHOUSE_UNMARKED_READY_RECOVERY_REPORT=$ReportPath"
Write-Host "WAREHOUSE_UNMARKED_READY_RECOVERY_MARKER=$readyMarker"
Write-Host "WAREHOUSE_UNMARKED_READY_RECOVERY_LINE_COUNT=$lineCount"
