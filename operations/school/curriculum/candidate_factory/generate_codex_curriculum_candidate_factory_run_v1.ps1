param(
  [Parameter(Mandatory=$true)][int]$TargetAccepted,
  [ValidateSet('Test','Real')][string]$RunKind='Test',
  [int]$BatchSize=100,
  [ValidateRange(0,1000000000)][int]$OrdinalOffset=0,
  [string]$RunId='',
  [bool]$UseFactoryMemory=$true,
  [bool]$UseTopicCursor=$true,
  [string]$TopicsPlan='operations/school/curriculum/topics/builder_night_school_topics_v1.json',
  [string]$MemoryDir='operations/school/curriculum/candidate_factory/memory'
)
$ErrorActionPreference='Stop'
$repoRoot=(git rev-parse --show-toplevel).Trim(); Set-Location $repoRoot
$utf8=New-Object System.Text.UTF8Encoding($false)
function WriteJson($p,$o,$d=80){$dir=Split-Path -Parent $p; if($dir){New-Item -ItemType Directory -Force -Path $dir|Out-Null}; [IO.File]::WriteAllText((Join-Path (Get-Location).Path $p),($o|ConvertTo-Json -Depth $d),$utf8)}
function Slug($s){ return (([string]$s).ToLowerInvariant() -replace '[^a-z0-9]+','_').Trim('_') }
if($RunKind -eq 'Real'){ throw 'BLOCKED_REAL_RUN_REQUIRES_LIVE_AUTHORITY_PASSPORT' }
if($TargetAccepted -lt 1){ throw 'TARGET_ACCEPTED_MUST_BE_POSITIVE' }
if($BatchSize -lt 1 -or $BatchSize -gt 100){ throw 'BATCH_SIZE_MUST_BE_1_TO_100' }
if([string]::IsNullOrWhiteSpace($RunId)){ $RunId='candidate_factory_test_' + $TargetAccepted + '_' + (Get-Date -Format 'yyyyMMdd_HHmmss') }
$runSlug=Slug $RunId
$runDir=".runtime/codex_curriculum_candidate_factory_runs/$RunId"
New-Item -ItemType Directory -Force -Path $runDir | Out-Null
$topicRoots=@('proof_boundary','school_life_boundary','codex_preflight','validator_consistency','streaming_absorption','ready_lane_gate','rollback_snapshot','scale_gate','decision_use','return_to_parent','contract_schema','source_anchor','duplicate_key_hygiene','count_not_learning','runtime_boundary','active_repo_body','quarantine_lane','factory_generation','batch_checkpoint','owner_selected_n','canonical_scheduler','local_first','no_external_brain','negative_control','promotion_boundary','lab_not_live','child_agent_delay','memory_compaction','source_ladder','failure_report')
$verbs=@('separate','classify','validate','guard','stream','promote','rollback','prove','route','compress')
$modes=@('directed_curriculum','experience_curriculum')
$rootWeights=@{}
foreach($r in $topicRoots){$rootWeights[$r]=1}
$topicPlanStatus='BUILTIN_DEFAULT_TOPICS'
if($TopicsPlan -and (Test-Path $TopicsPlan)){
  $topicPlan=Get-Content $TopicsPlan -Raw | ConvertFrom-Json
  if(@($topicPlan.topics).Count -lt 1){ throw 'TOPICS_PLAN_EMPTY' }
  $rootSet=New-Object System.Collections.Generic.List[string]
  $verbsSet=New-Object System.Collections.Generic.List[string]
  $modesSet=New-Object System.Collections.Generic.List[string]
  $rootWeights=@{}
  foreach($t in @($topicPlan.topics)){
    $root=Slug([string]$t.root)
    if([string]::IsNullOrWhiteSpace($root)){ throw 'TOPICS_PLAN_ROOT_EMPTY' }
    $w=[int]$t.weight; if($w -lt 1){$w=1}; if($w -gt 50){$w=50}
    if(-not $rootSet.Contains($root)){ $rootSet.Add($root) | Out-Null }
    $rootWeights[$root]=$w
    foreach($v in @($t.verbs)){ $sv=Slug([string]$v); if($sv -and -not $verbsSet.Contains($sv)){ $verbsSet.Add($sv)|Out-Null } }
    foreach($m in @($t.modes)){ $sm=Slug([string]$m); if($sm -and -not $modesSet.Contains($sm)){ $modesSet.Add($sm)|Out-Null } }
  }
  $topicRoots=@($rootSet.ToArray())
  if($verbsSet.Count -gt 0){ $verbs=@($verbsSet.ToArray()) }
  if($modesSet.Count -gt 0){ $modes=@($modesSet.ToArray()) }
  $topicPlanStatus='TOPICS_PLAN_APPLIED_FAST_UNIQUE_ROOTS'
}
function NewTaskListFromCursor(){
  $cursorMap=@{}
  $cursorPath=Join-Path $MemoryDir 'theme_cursor_ledger.json'
  if($UseTopicCursor -and (Test-Path $cursorPath)){
    $co=Get-Content $cursorPath -Raw|ConvertFrom-Json
    foreach($c in @($co.cursors)){ $cursorMap[[string]$c.theme_key]=$c }
  }
  $tasks=New-Object System.Collections.Generic.List[object]
  foreach($verb in $verbs){ foreach($root in $topicRoots){ foreach($mode in $modes){
    $themeKey="$verb|$root|$mode"
    if($cursorMap.ContainsKey($themeKey)){
      $c=$cursorMap[$themeKey]
      $last=[int]$c.last_level; $next=[int]$c.next_level; $count=[int]$c.atom_count
    } else { $last=0; $next=1; $count=0 }
    $weight=if($rootWeights.ContainsKey($root)){[int]$rootWeights[$root]}else{1}
    $tasks.Add([pscustomObject]@{verb=$verb; root=$root; source_mode=$mode; theme_key=$themeKey; last_level=$last; next_level=$next; atom_count=$count; weight=$weight}) | Out-Null
  } } }
  return @($tasks.ToArray() | Sort-Object last_level, atom_count, @{Expression='weight';Descending=$true}, verb, source_mode, root)
}
function NewTaskListFromMemoryFallback(){
  $counts=@{}
  $ledgerPath=Join-Path $MemoryDir 'factory_ledger.jsonl'
  if($UseFactoryMemory -and (Test-Path $ledgerPath)){
    foreach($line in Get-Content $ledgerPath){ if([string]::IsNullOrWhiteSpace($line)){ continue }; $rec=$line|ConvertFrom-Json; $lk=[string]$rec.learning_key; if($lk){ if(-not $counts.ContainsKey($lk)){ $counts[$lk]=0 }; $counts[$lk]++ } }
  }
  $tasks=New-Object System.Collections.Generic.List[object]
  foreach($verb in $verbs){ foreach($root in $topicRoots){ foreach($level in 1..5){ foreach($mode in $modes){
    $lk="$verb|$root|$level|$mode"; $count=if($counts.ContainsKey($lk)){[int]$counts[$lk]}else{0}; $weight=if($rootWeights.ContainsKey($root)){[int]$rootWeights[$root]}else{1}
    $tasks.Add([pscustomObject]@{verb=$verb; root=$root; source_mode=$mode; theme_key="$verb|$root|$mode"; last_level=$level-1; next_level=$level; atom_count=$count; weight=$weight}) | Out-Null
  } } } }
  return @($tasks.ToArray() | Sort-Object atom_count, @{Expression='weight';Descending=$true}, verb, source_mode, root, next_level)
}
$taskSchedule=if($UseTopicCursor){ NewTaskListFromCursor } else { NewTaskListFromMemoryFallback }
if($taskSchedule.Count -lt 1){ throw 'FACTORY_TASK_SCHEDULE_EMPTY' }
$allPath=Join-Path $runDir 'all_candidates.jsonl'
if(Test-Path $allPath){ Remove-Item $allPath -Force }
$created=@(); $ordinal=0; $batchIndex=0; $generatedKeys=@{}; $generatedThemes=@{}; $runNextLevel=@{}
while($ordinal -lt $TargetAccepted){
  $batchIndex++
  $batchTarget=[Math]::Min($BatchSize,$TargetAccepted-$ordinal)
  $batchDir=Join-Path $runDir ("chunk_0001/batch_{0:D4}" -f $batchIndex)
  New-Item -ItemType Directory -Force -Path $batchDir | Out-Null
  $batchPath=Join-Path $batchDir 'candidates.jsonl'
  if(Test-Path $batchPath){ Remove-Item $batchPath -Force }
  for($i=1;$i -le $batchTarget;$i++){
    $ordinal++
    $globalOrdinal=$OrdinalOffset + $ordinal - 1
    $task=$taskSchedule[$globalOrdinal % $taskSchedule.Count]
    $root=[string]$task.root; $verb=[string]$task.verb; $sourceMode=[string]$task.source_mode; $themeKey=[string]$task.theme_key
    $cycleLevelOffset=[int][Math]::Floor([double]$globalOrdinal / [double]$taskSchedule.Count)
    $level=[int]$task.next_level + $cycleLevelOffset
    if($runNextLevel.ContainsKey($themeKey)){ $level=[int]$runNextLevel[$themeKey] + 1 }
    $runNextLevel[$themeKey]=$level
    $learningKey="$verb|$root|$level|$sourceMode"
    $prereq=if($level -gt 1){"$verb|$root|$($level-1)|$sourceMode"}else{$null}
    $generatedKeys[$learningKey]=$true; $generatedThemes[$themeKey]=$true
    $topic=$root
    $obj=[ordered]@{
      schema='codex_curriculum_candidate_v1'
      candidate_id=("cand_{0:D8}" -f ($OrdinalOffset+$ordinal))
      run_id=$RunId
      run_kind=$RunKind
      source='local_cursor_guided_factory'
      source_mode=$sourceMode
      topic=$topic
      verb=$verb
      root=$root
      level=$level
      learning_key=$learningKey
      duplicate_key=$learningKey
      theme_key=$themeKey
      title="$verb $root level $level"
      objective="Create compact, testable learning material for $root at level $level using verb $verb without claiming that count or volume proves quality."
      new_knowledge="Builder should learn how $root works at level $level, how to use it safely, what boundary applies, and what mistake must be avoided when applying $verb in $sourceMode."
      exercise="Given a concrete Builder situation involving $root, explain the correct $verb response, name the boundary, and state one proof or validator needed before behavior changes."
      expected_behavior="When the Builder meets $root in a real task, it should ask the right context question, avoid overclaim, choose the smallest safe next step, and return evidence to parent."
      negative_trap="Do not treat count, generated volume, folder existence, or a candidate itself as proof of knowledge or skill."
      validator_hint="Accept only if the lesson separates meaning, boundary, proof requirement, and return-to-parent behavior for this topic."
      behavior_use_proof_target="A future recall/use probe should show the Builder applying this lesson to choose a safer reasoning or school-memory action, not merely repeating text."
      return_to_parent="Compress the accepted lesson into compact memory only after validation and report the resulting behavior boundary to the parent task."
      source_anchor="active_school_self_knowledge_curriculum:${root}:${verb}:${sourceMode}"
      self_generated_easy_candidate=$false
      acceptance_hint='must produce one compact atom candidate with evidence boundary and no active mutation'
      topic_plan=$TopicsPlan
      prerequisite_key=$prereq
      ladder_step=if($level -eq 1){'new_theme_base'}else{'cursor_next_level'}
      batch_delta_target="batch must reserve unique next level $level for $themeKey and avoid topic/key index hits"
      factory_memory_historical_count=[int]$task.atom_count
      cursor_previous_level=[int]$task.last_level
      cursor_reserved_level=$level
    }
    $line=($obj | ConvertTo-Json -Depth 20 -Compress)
    [IO.File]::AppendAllText((Join-Path (Get-Location).Path $batchPath),$line + "`n",$utf8)
    [IO.File]::AppendAllText((Join-Path (Get-Location).Path $allPath),$line + "`n",$utf8)
  }
  $created += [pscustomObject]@{batch_index=$batchIndex; batch_path=$batchPath; target=$batchTarget; lines=(Get-Content $batchPath|Measure-Object).Count; sha256=(Get-FileHash $batchPath -Algorithm SHA256).Hash.ToLower()}
  $checkpoint=[pscustomObject]@{schema='codex_candidate_factory_checkpoint_v1'; status='RUNNING'; run_id=$RunId; run_kind=$RunKind; run_slug=$runSlug; use_factory_memory=$UseFactoryMemory; use_topic_cursor=$UseTopicCursor; topics_plan=$TopicsPlan; topic_plan_status=$topicPlanStatus; target_accepted=$TargetAccepted; batch_size=$BatchSize; batches_created=$created.Count; candidates_created=$ordinal; run_dir=$runDir; all_candidates_path=$allPath; generated_learning_key_count=$generatedKeys.Keys.Count; generated_theme_count=$generatedThemes.Keys.Count; task_schedule_count=$taskSchedule.Count; updated_at=(Get-Date).ToString('o')}
  WriteJson (Join-Path $runDir 'checkpoint.json') $checkpoint 50
}
$report=[pscustomObject]@{schema='codex_candidate_factory_run_v1'; status='PASS_CODEX_CANDIDATE_FACTORY_GENERATION_V1'; runtime_ready=$false; run_id=$RunId; run_slug=$runSlug; run_kind=$RunKind; use_factory_memory=$UseFactoryMemory; use_topic_cursor=$UseTopicCursor; topics_plan=$TopicsPlan; topic_plan_status=$topicPlanStatus; target_accepted=$TargetAccepted; batch_size=$BatchSize; batches_created=$created.Count; candidates_created=$TargetAccepted; run_dir=$runDir; all_candidates_path=$allPath; all_candidates_sha256=(Get-FileHash $allPath -Algorithm SHA256).Hash.ToLower(); generated_learning_key_count=$generatedKeys.Keys.Count; generated_theme_count=$generatedThemes.Keys.Count; task_schedule_count=$taskSchedule.Count; codex_cli_invoked=$false; api_invoked=$false; active_memory_mutated=$false; batch_reports=@($created); boundary='Local cursor-guided factory generation only; no Codex CLI/API calls, no active promotion, no live proof.'}
WriteJson 'operations/reports/CODEX_CANDIDATE_FACTORY_RUN_V1.json' $report 80
$md=@('# CODEX_CANDIDATE_FACTORY_RUN_V1','',"Status: $($report.status)",'Runtime ready: false','',"Run id: $RunId","Run slug: $runSlug","Use factory memory: $UseFactoryMemory","Use topic cursor: $UseTopicCursor","TargetAccepted: $TargetAccepted","Batch size: $BatchSize","Batches created: $($created.Count)","Candidates created: $TargetAccepted","Generated learning keys: $($report.generated_learning_key_count)","Generated themes: $($report.generated_theme_count)","Task schedule count: $($report.task_schedule_count)","Codex CLI invoked: false","Active memory mutated: false",'', 'Boundary: local cursor-guided generation only; no active promotion.')
[IO.File]::WriteAllText((Join-Path (Get-Location).Path 'operations/reports/CODEX_CANDIDATE_FACTORY_RUN_V1.md'),($md -join "`r`n"),$utf8)
Write-Host "FACTORY_STATUS=PASS_CODEX_CANDIDATE_FACTORY_GENERATION_V1"
Write-Host "RUN_ID=$RunId"
Write-Host "RUN_SLUG=$runSlug"
Write-Host "USE_FACTORY_MEMORY=$UseFactoryMemory"
Write-Host "USE_TOPIC_CURSOR=$UseTopicCursor"
Write-Host "RUN_DIR=$runDir"
Write-Host "TARGET_ACCEPTED=$TargetAccepted"
Write-Host "BATCH_SIZE=$BatchSize"
Write-Host "BATCHES_CREATED=$($created.Count)"
Write-Host "CANDIDATES_CREATED=$TargetAccepted"
Write-Host "GENERATED_LEARNING_KEYS=$($report.generated_learning_key_count)"
Write-Host "GENERATED_THEMES=$($report.generated_theme_count)"
Write-Host "TASK_SCHEDULE_COUNT=$($report.task_schedule_count)"
Write-Host "CODEX_CLI_INVOKED=false"
Write-Host "ACTIVE_MEMORY_MUTATED=false"
Write-Host "RUNTIME_READY=false"




