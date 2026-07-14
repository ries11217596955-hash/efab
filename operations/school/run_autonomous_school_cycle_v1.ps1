param(
  [ValidateRange(0,1000000)][int]$Count = 0,
  [Parameter(Mandatory=$true)][ValidateSet('Test','Live')][string]$Mode,
  [string]$Topics = 'AUTO',
  [ValidateRange(0,1000)][int]$MaxCycles = 0,
  [Alias('MaxRuntimeMinutes')][ValidateRange(0,10080)][double]$MaxCycleRuntimeMinutes = 0,
  [ValidateRange(0,10080)][double]$MaxTotalRuntimeMinutes = 0,
  [string]$StopFile = '',
  [switch]$RequireRepoClean,
  [string]$PolicyPath = 'operations/school/autonomous_school_cycle_policy.json'
)
$ErrorActionPreference='Stop'
$repoRoot=(git rev-parse --show-toplevel).Trim(); Set-Location $repoRoot
function EnsureDir($Path){ if(-not (Test-Path $Path)){ New-Item -ItemType Directory -Force -Path $Path | Out-Null } }
function WriteJson($Path,$Obj,$Depth=80){ $d=Split-Path $Path -Parent; if($d){ EnsureDir $d }; $Obj|ConvertTo-Json -Depth $Depth|Set-Content -LiteralPath $Path -Encoding UTF8 }
function LastValue($Lines,$Prefix){ (($Lines|Where-Object{$_ -match ('^'+[regex]::Escape($Prefix))}|Select-Object -Last 1) -replace ('^'+[regex]::Escape($Prefix)),'') }
function ActiveProcessMatches(){
  @(Get-CimInstance Win32_Process | Where-Object { $_.CommandLine -match 'operations[/\\]school[/\\]run_agent_school|candidate_factory|compact_memory_intake[/\\]merge_compact_memory_intake_queue|file_atom_absorption' } | ForEach-Object { [ordered]@{ pid=$_.ProcessId; command_line=$_.CommandLine } })
}
function MemoryState(){
  $manifestPath='.runtime/active_compact_semantic_memory_v1/manifest.json'
  if(-not (Test-Path $manifestPath)){ return $null }
  $m=Get-Content $manifestPath -Raw|ConvertFrom-Json
  return [ordered]@{ run_id=$m.run_id; status=$m.status; cell_count=[int]$m.cell_count; merged_count=[int]$m.merged_count; total_memory_bytes=[int64]$m.total_memory_bytes; cells_sha256=$m.cells_sha256; index_sha256=$m.index_sha256; runtime_ready=$m.runtime_ready }
}
if(-not (Test-Path $PolicyPath)){ throw "AUTONOMOUS_SCHOOL_POLICY_MISSING:$PolicyPath" }
$policy=Get-Content $PolicyPath -Raw|ConvertFrom-Json
if($Count -le 0){ $Count=[int]$policy.default_count }
if($MaxCycleRuntimeMinutes -le 0){
  if($policy.PSObject.Properties['default_max_cycle_runtime_minutes']){ $MaxCycleRuntimeMinutes=[double]$policy.default_max_cycle_runtime_minutes }
  elseif($policy.PSObject.Properties['default_max_runtime_minutes']){ $MaxCycleRuntimeMinutes=[double]$policy.default_max_runtime_minutes }
}
if($MaxTotalRuntimeMinutes -le 0 -and $policy.PSObject.Properties['default_max_total_runtime_minutes']){ $MaxTotalRuntimeMinutes=[double]$policy.default_max_total_runtime_minutes }
if([string]::IsNullOrWhiteSpace($StopFile)){ $StopFile=[string]$policy.stop_file }
if($Count -lt 1){ throw 'COUNT_NOT_RESOLVED_FROM_POLICY' }
if($MaxCycleRuntimeMinutes -le 0){ throw 'MAX_CYCLE_RUNTIME_NOT_RESOLVED_FROM_POLICY' }
$TopicsPlan='operations/school/curriculum/topics/builder_night_school_topics_v1.json'
if(-not (Test-Path $TopicsPlan)){ throw "INTERNAL_TOPICS_PLAN_MISSING:$TopicsPlan" }
$runId="autonomous_school_cycle_$(Get-Date -Format yyyyMMdd_HHmmss)"
$runRoot=".runtime/autonomous_school_cycles/$runId"
EnsureDir $runRoot
$startedAt=Get-Date
$totalDeadline=$null
if($MaxTotalRuntimeMinutes -gt 0){ $totalDeadline=$startedAt.AddMinutes($MaxTotalRuntimeMinutes) }
$headBefore=(git rev-parse HEAD).Trim()
$branch=(git rev-parse --abbrev-ref HEAD).Trim()
$dirtyBefore=@(git status --short --untracked-files=all | ForEach-Object{[string]$_})
$active=@(ActiveProcessMatches)
if(($RequireRepoClean -or [bool]$policy.require_repo_clean) -and $dirtyBefore.Count -gt 0){ throw 'AUTONOMOUS_SCHOOL_CYCLE_REPO_DIRTY' }
if($active.Count -gt 0){ throw 'AUTONOMOUS_SCHOOL_CYCLE_ACTIVE_PROCESS_CONFLICT' }
$cycleReports=@()
$status='STARTED'
$cycle=0
while($true){
  if($MaxCycles -gt 0 -and $cycle -ge $MaxCycles){ $status='PASS_AUTONOMOUS_SCHOOL_CYCLE_RUN_V1'; break }
  if(Test-Path $StopFile){ $status='STOPPED_BY_STOP_FILE'; break }
  if($totalDeadline -and (Get-Date) -ge $totalDeadline){ if($cycleReports.Count -gt 0){ $status='PASS_AUTONOMOUS_SCHOOL_CYCLE_RUN_V1' } else { $status='STOPPED_BY_TOTAL_RUNTIME_BEFORE_FIRST_CYCLE' }; break }
  $cycle++
  $memoryBefore=MemoryState
  $cycleId="${runId}_cycle_$cycle"
  $cycleStartedAt=Get-Date
  $out=@(& powershell -NoProfile -ExecutionPolicy Bypass -File operations/school/run_agent_school.ps1 -Count $Count -Mode $Mode -Topics $Topics *>&1 | ForEach-Object{[string]$_})
  $cycleFinishedAt=Get-Date
  $cycleDurationMinutes=[math]::Round(($cycleFinishedAt-$cycleStartedAt).TotalMinutes,6)
  $outPath=Join-Path $runRoot ("cycle_{0}_stdout.txt" -f $cycle)
  $out | Set-Content -LiteralPath $outPath -Encoding UTF8
  $schoolStatus=LastValue $out 'SCHOOL_RUN_STATUS='
  $finalizerStatus=LastValue $out 'FINALIZER_STATUS='
  $intakeStatus=LastValue $out 'FINALIZER_INTAKE_STATUS='
  $mergeStatus=LastValue $out 'FINALIZER_MERGE_QUEUE_STATUS='
  $mergeProof=LastValue $out 'FINALIZER_MERGE_QUEUE_PROOF='
  $memoryAfter=MemoryState
  $cycleStatus='PASS_AUTONOMOUS_SCHOOL_CYCLE_V1'
  $blockers=@()
  if($schoolStatus -notmatch '^PASS_'){ $cycleStatus='FAIL_AUTONOMOUS_SCHOOL_CYCLE_V1'; $blockers += "SCHOOL_STATUS_NOT_PASS:$schoolStatus" }
  if($intakeStatus -ne 'PASS_MULTI_SOURCE_COMPACT_MEMORY_INTAKE_SUBMIT_V1'){ $cycleStatus='FAIL_AUTONOMOUS_SCHOOL_CYCLE_V1'; $blockers += "INTAKE_STATUS_NOT_PASS:$intakeStatus" }
  if($mergeStatus -ne 'PASS_MULTI_SOURCE_COMPACT_MEMORY_MERGE_QUEUE_V1'){ $cycleStatus='FAIL_AUTONOMOUS_SCHOOL_CYCLE_V1'; $blockers += "MERGE_STATUS_NOT_PASS:$mergeStatus" }
  $hashChanged=$false
  if($memoryBefore -and $memoryAfter){ $hashChanged=([string]$memoryBefore.cells_sha256 -ne [string]$memoryAfter.cells_sha256) }
  if(-not $hashChanged){ $cycleStatus='FAIL_AUTONOMOUS_SCHOOL_CYCLE_V1'; $blockers += 'MEMORY_HASH_NOT_CHANGED' }
  $cycleRuntimeExceeded=($cycleDurationMinutes -gt [double]$MaxCycleRuntimeMinutes)
  if($cycleRuntimeExceeded){ $blockers += "CYCLE_RUNTIME_SLA_EXCEEDED:${cycleDurationMinutes}m>${MaxCycleRuntimeMinutes}m" }
  $report=[ordered]@{
    cycle=$cycle
    cycle_id=$cycleId
    status=$cycleStatus
    count=$Count
    mode=$Mode
    topics=$Topics
    internal_topics_plan=$TopicsPlan
    school_status=$schoolStatus
    finalizer_status=$finalizerStatus
    intake_status=$intakeStatus
    merge_status=$mergeStatus
    merge_proof=$mergeProof
    memory_before=$memoryBefore
    memory_after=$memoryAfter
    memory_hash_changed=$hashChanged
    stdout_path=$outPath
    cycle_started_at=$cycleStartedAt.ToString('o')
    cycle_finished_at=$cycleFinishedAt.ToString('o')
    cycle_duration_seconds=[math]::Round(($cycleFinishedAt-$cycleStartedAt).TotalSeconds,3)
    cycle_duration_minutes=$cycleDurationMinutes
    max_cycle_runtime_minutes=[double]$MaxCycleRuntimeMinutes
    cycle_runtime_sla_exceeded=$cycleRuntimeExceeded
    blockers=@($blockers)
  }
  $cycleReports += $report
  if($cycleStatus -notlike 'PASS_*'){ $status='FAIL_AUTONOMOUS_SCHOOL_CYCLE_RUN_V1'; break }
  if($cycleRuntimeExceeded){ $status='STOPPED_BY_CYCLE_RUNTIME_SLA_EXCEEDED'; break }
}
$finishedAt=Get-Date
$result=[ordered]@{
  schema='autonomous_school_cycle_run_v1'
  status=$status
  run_id=$runId
  branch=$branch
  repo_head_before=$headBefore
  repo_head_after=(git rev-parse HEAD).Trim()
  dirty_before=@($dirtyBefore)
  count=$Count
  mode=$Mode
  topics=$Topics
  internal_topics_plan=$TopicsPlan
  max_cycles=$MaxCycles
  max_cycle_runtime_minutes=[double]$MaxCycleRuntimeMinutes
  max_total_runtime_minutes=[double]$MaxTotalRuntimeMinutes
  completed_cycles=@($cycleReports).Count
  stop_file=$StopFile
  cycles=@($cycleReports)
  started_at=$startedAt.ToString('o')
  finished_at=$finishedAt.ToString('o')
  duration_minutes=[math]::Round(($finishedAt-$startedAt).TotalMinutes,3)
  boundary='Autonomous school cycle controller runs canonical school cycles only. Default SLA is 50000 candidates per cycle and 60 minutes max per cycle. If a cycle exceeds the SLA, the controller does not start the next cycle. It does not hard-kill an active school run.'
}
$proofPath=Join-Path $runRoot 'AUTONOMOUS_SCHOOL_CYCLE_RUN_V1.json'
WriteJson $proofPath $result 100
Write-Host "AUTONOMOUS_SCHOOL_CYCLE_STATUS=$($result.status)"
Write-Host "AUTONOMOUS_SCHOOL_CYCLE_PROOF=$proofPath"
Write-Host "AUTONOMOUS_SCHOOL_CYCLE_COMPLETED=$($result.completed_cycles)"
Write-Host "AUTONOMOUS_SCHOOL_CYCLE_COUNT=$($result.count)"
Write-Host "AUTONOMOUS_SCHOOL_CYCLE_MAX_CYCLE_RUNTIME_MINUTES=$($result.max_cycle_runtime_minutes)"
Write-Host "AUTONOMOUS_SCHOOL_CYCLE_MAX_TOTAL_RUNTIME_MINUTES=$($result.max_total_runtime_minutes)"
if($cycleReports.Count -gt 0){
  $last=$cycleReports[-1]
  Write-Host "LAST_SCHOOL_STATUS=$($last.school_status)"
  Write-Host "LAST_FINALIZER_STATUS=$($last.finalizer_status)"
  Write-Host "LAST_INTAKE_STATUS=$($last.intake_status)"
  Write-Host "LAST_MERGE_STATUS=$($last.merge_status)"
  Write-Host "LAST_MEMORY_HASH_CHANGED=$($last.memory_hash_changed)"
  Write-Host "LAST_CYCLE_DURATION_MINUTES=$($last.cycle_duration_minutes)"
  Write-Host "LAST_CYCLE_RUNTIME_SLA_EXCEEDED=$($last.cycle_runtime_sla_exceeded)"
}
if($status -like 'FAIL_*' -or $status -eq 'STOPPED_BY_TOTAL_RUNTIME_BEFORE_FIRST_CYCLE'){ exit 1 }