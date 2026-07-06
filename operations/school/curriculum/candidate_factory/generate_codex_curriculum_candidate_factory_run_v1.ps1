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
$topicPlanStatus='BUILTIN_DEFAULT_TOPICS'
if($TopicsPlan -and (Test-Path $TopicsPlan)){
  $topicPlan=Get-Content $TopicsPlan -Raw | ConvertFrom-Json
  if(@($topicPlan.topics).Count -lt 1){ throw 'TOPICS_PLAN_EMPTY' }
  $weightedRoots=New-Object System.Collections.Generic.List[string]
  $verbsSet=New-Object System.Collections.Generic.List[string]
  $modesSet=New-Object System.Collections.Generic.List[string]
  foreach($t in @($topicPlan.topics)){
    $root=Slug([string]$t.root)
    if([string]::IsNullOrWhiteSpace($root)){ throw 'TOPICS_PLAN_ROOT_EMPTY' }
    $w=[int]$t.weight; if($w -lt 1){$w=1}; if($w -gt 50){$w=50}
    for($wi=0;$wi -lt $w;$wi++){ $weightedRoots.Add($root) | Out-Null }
    foreach($v in @($t.verbs)){ $sv=Slug([string]$v); if($sv -and -not $verbsSet.Contains($sv)){ $verbsSet.Add($sv)|Out-Null } }
    foreach($m in @($t.modes)){ $sm=Slug([string]$m); if($sm -and -not $modesSet.Contains($sm)){ $modesSet.Add($sm)|Out-Null } }
  }
  $topicRoots=@($weightedRoots.ToArray())
  if($verbsSet.Count -gt 0){ $verbs=@($verbsSet.ToArray()) }
  if($modesSet.Count -gt 0){ $modes=@($modesSet.ToArray()) }
  $topicPlanStatus='TOPICS_PLAN_APPLIED'
}
function NewTaskListFromCursor(){
  $cursorMap=@{}
  $cursorPath=Join-Path $MemoryDir 'theme_cursor_ledger.json'
  if($UseTopicCursor -and (Test-Path $cursorPath)){
    $co=Get-Content $cursorPath -Raw|ConvertFrom-Json
    foreach($c in @($co.cursors)){ $cursorMap[[string]$c.theme_key]=$c }
  }
  $tasks=@()
  foreach($verb in $verbs){ foreach($root in $topicRoots){ foreach($mode in $modes){
    $themeKey="$verb|$root|$mode"
    if($cursorMap.ContainsKey($themeKey)){
      $c=$cursorMap[$themeKey]
      $last=[int]$c.last_level; $next=[int]$c.next_level; $count=[int]$c.atom_count
    } else { $last=0; $next=1; $count=0 }
    $tasks += [pscustomObject]@{verb=$verb; root=$root; source_mode=$mode; theme_key=$themeKey; last_level=$last; next_level=$next; atom_count=$count}
  } } }
  return @($tasks | Sort-Object last_level, atom_count, root, verb, source_mode)
}
function NewTaskListFromMemoryFallback(){
  $counts=@{}
  $ledgerPath=Join-Path $MemoryDir 'factory_ledger.jsonl'
  if($UseFactoryMemory -and (Test-Path $ledgerPath)){
    foreach($line in Get-Content $ledgerPath){ if([string]::IsNullOrWhiteSpace($line)){ continue }; $rec=$line|ConvertFrom-Json; $lk=[string]$rec.learning_key; if($lk){ if(-not $counts.ContainsKey($lk)){ $counts[$lk]=0 }; $counts[$lk]++ } }
  }
  $tasks=@()
  foreach($verb in $verbs){ foreach($root in $topicRoots){ foreach($level in 1..5){ foreach($mode in $modes){
    $lk="$verb|$root|$level|$mode"; $count=if($counts.ContainsKey($lk)){[int]$counts[$lk]}else{0}; $tasks += [pscustomObject]@{verb=$verb; root=$root; source_mode=$mode; theme_key="$verb|$root|$mode"; last_level=$level-1; next_level=$level; atom_count=$count}
  } } } }
  return @($tasks | Sort-Object atom_count, root, verb, next_level, source_mode)
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
    $learningKey="$verb|$root|$level|$sourceMode"
    $prereq=if($level -gt 1){"$verb|$root|$($level-1)|$sourceMode"}else{''}
    if(-not $generatedKeys.ContainsKey($learningKey)){ $generatedKeys[$learningKey]=0 }; $generatedKeys[$learningKey]++
    if(-not $generatedThemes.ContainsKey($themeKey)){ $generatedThemes[$themeKey]=0 }; $generatedThemes[$themeKey]++
    $topic=("factory_{0}_{1}_level_{2:D6}_{3}_{4:D6}" -f $verb,$root,$level,$runSlug,$ordinal)
    $id=("codex.curriculum.factory.{0}.{1:D6}" -f $RunId,$ordinal)
    $dk=("{0}_{1:D6}" -f (Slug $topic),$ordinal)
    $ladderText=if($level -eq 1){"start a new theme at level 1"}else{"continue theme cursor $themeKey from level $($level-1) to level $level"}
    $objective="Teach the Builder to $verb the $root rule at cursor level $level for theme $themeKey during local factory run $runSlug."
    $knowledge="Factory cursor selected theme_key $themeKey with previous last_level $($task.last_level); this candidate must $ladderText and pass validation before absorption."
    $exercise="Given a factory candidate for $themeKey from run $runSlug, verify that level $level follows the cursor and identify validator, rollback, and return-to-parent requirements."
    $expected="The Builder uses theme cursor $themeKey at level $level to change a future repo-body decision only after contract validation, hot-path invariant proof, batch-delta proof, and promotion gates pass."
    $trap="Treating cursor reservation level $level as active learning before decision-use and scale proof."
    $hint="Check theme_key, level continuity, topic index, duplicate_key index, prerequisite_key, and batch_delta_target."
    $proof="A later decision cites theme_key $themeKey level $level and shows why this next cursor step changes behavior."
    $return="Return theme_key $themeKey level $level from run $runSlug to the parent Builder loop as compact active rule material, not raw archive text."
    $obj=[pscustomObject]@{
      candidate_id=$id; source_mode=$sourceMode; topic=$topic; level=$level; objective=$objective; new_knowledge=$knowledge; exercise=$exercise; expected_behavior=$expected; negative_trap=$trap; validator_hint=$hint; behavior_use_proof_target=$proof; return_to_parent=$return; source_anchor='operations/school/curriculum/candidate_factory/FACTORY_TOPIC_CURSOR_LEDGER_V1.md'; duplicate_key=$dk; self_generated_easy_candidate=$false; theme_key=$themeKey; learning_key=$learningKey; prerequisite_key=$prereq; ladder_step=if($level -eq 1){'new_theme_base'}else{'cursor_next_level'}; batch_delta_target="batch must reserve unique next level $level for $themeKey and avoid topic/key index hits"; factory_memory_historical_count=[int]$task.atom_count; cursor_previous_level=[int]$task.last_level; cursor_reserved_level=$level
    }
    $line=($obj | ConvertTo-Json -Depth 20 -Compress)
    [IO.File]::AppendAllText((Join-Path (Get-Location).Path $batchPath),$line + "`n",$utf8)
    [IO.File]::AppendAllText((Join-Path (Get-Location).Path $allPath),$line + "`n",$utf8)
  }
  $created += [pscustomObject]@{batch_index=$batchIndex; batch_path=$batchPath; target=$batchTarget; lines=(Get-Content $batchPath|Measure-Object).Count; sha256=(Get-FileHash $batchPath -Algorithm SHA256).Hash.ToLower()}
  $checkpoint=[pscustomObject]@{schema='codex_candidate_factory_checkpoint_v1'; status='RUNNING'; run_id=$RunId; run_kind=$RunKind; run_slug=$runSlug; use_factory_memory=$UseFactoryMemory; use_topic_cursor=$UseTopicCursor; topics_plan=$TopicsPlan; topic_plan_status=$topicPlanStatus; target_accepted=$TargetAccepted; batch_size=$BatchSize; batches_created=$created.Count; candidates_created=$ordinal; run_dir=$runDir; all_candidates_path=$allPath; generated_learning_key_count=$generatedKeys.Keys.Count; generated_theme_count=$generatedThemes.Keys.Count; updated_at=(Get-Date).ToString('o')}
  WriteJson (Join-Path $runDir 'checkpoint.json') $checkpoint 50
}
$report=[pscustomObject]@{schema='codex_candidate_factory_run_v1'; status='PASS_CODEX_CANDIDATE_FACTORY_GENERATION_V1'; runtime_ready=$false; run_id=$RunId; run_slug=$runSlug; run_kind=$RunKind; use_factory_memory=$UseFactoryMemory; use_topic_cursor=$UseTopicCursor; topics_plan=$TopicsPlan; topic_plan_status=$topicPlanStatus; target_accepted=$TargetAccepted; batch_size=$BatchSize; batches_created=$created.Count; candidates_created=$TargetAccepted; run_dir=$runDir; all_candidates_path=$allPath; all_candidates_sha256=(Get-FileHash $allPath -Algorithm SHA256).Hash.ToLower(); generated_learning_key_count=$generatedKeys.Keys.Count; generated_theme_count=$generatedThemes.Keys.Count; codex_cli_invoked=$false; api_invoked=$false; active_memory_mutated=$false; batch_reports=@($created); boundary='Local cursor-guided factory generation only; no Codex CLI/API calls, no active promotion, no live proof.'}
WriteJson 'operations/reports/CODEX_CANDIDATE_FACTORY_RUN_V1.json' $report 80
$md=@('# CODEX_CANDIDATE_FACTORY_RUN_V1','',"Status: $($report.status)",'Runtime ready: false','',"Run id: $RunId","Run slug: $runSlug","Use factory memory: $UseFactoryMemory","Use topic cursor: $UseTopicCursor","TargetAccepted: $TargetAccepted","Batch size: $BatchSize","Batches created: $($created.Count)","Candidates created: $TargetAccepted","Generated learning keys: $($report.generated_learning_key_count)","Generated themes: $($report.generated_theme_count)","Codex CLI invoked: false","Active memory mutated: false",'', 'Boundary: local cursor-guided generation only; no active promotion.')
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
Write-Host "CODEX_CLI_INVOKED=false"
Write-Host "ACTIVE_MEMORY_MUTATED=false"
Write-Host "RUNTIME_READY=false"
