param(
  [Parameter(Mandatory=$true)][int]$TargetAccepted,
  [ValidateSet('Test','Real')][string]$RunKind='Test',
  [int]$BatchSize=100,
  [ValidateRange(0,1000000000)][int]$OrdinalOffset=0,
  [string]$RunId='',
  [bool]$UseFactoryMemory=$true,
  [bool]$UseTopicCursor=$true,
  [string]$TopicsPlan='operations/school/curriculum/topics/builder_night_school_topics_v1.json',
  [string]$MemoryDir='operations/school/curriculum/candidate_factory/memory',
  [string]$CampaignPack='operations/school/curriculum/candidate_factory/campaign_packs/builder_self_knowledge_deep_v1.jsonl'
)
$ErrorActionPreference='Stop'
$repoRoot=(git rev-parse --show-toplevel).Trim(); Set-Location $repoRoot
$utf8=New-Object System.Text.UTF8Encoding($false)
function WriteJson($p,$o,$d=80){$dir=Split-Path -Parent $p; if($dir){New-Item -ItemType Directory -Force -Path $dir|Out-Null}; [IO.File]::WriteAllText((Join-Path (Get-Location).Path $p),($o|ConvertTo-Json -Depth $d),$utf8)}
function Slug($s){ return (([string]$s).ToLowerInvariant() -replace '[^a-z0-9]+','_').Trim('_') }
function SeedValue($Seed,$Name,$Default=''){
  if($null -eq $Seed){ return $Default }
  $p=$Seed.PSObject.Properties[$Name]
  if($null -eq $p -or $null -eq $p.Value){ return $Default }
  $v=[string]$p.Value
  if([string]::IsNullOrWhiteSpace($v)){ return $Default }
  return $v
}
function SeedList($Seed,$Name,$Default){
  if($null -eq $Seed){ return @($Default) }
  $p=$Seed.PSObject.Properties[$Name]
  if($null -eq $p -or $null -eq $p.Value){ return @($Default) }
  $out=@()
  foreach($item in @($p.Value)){
    $s=Slug([string]$item)
    if($s){ $out += $s }
  }
  if($out.Count -lt 1){ return @($Default) }
  return @($out | Select-Object -Unique)
}
function ReadCampaignPack($Path){
  $seeds=@()
  if([string]::IsNullOrWhiteSpace([string]$Path)){ return @() }
  if(-not (Test-Path $Path)){ return @() }
  $lineNo=0
  foreach($line in Get-Content $Path){
    $lineNo++
    if([string]::IsNullOrWhiteSpace($line)){ continue }
    $seed=$line | ConvertFrom-Json
    foreach($required in @('seed_id','campaign_id','root','source_kind','source_path','source_summary','lesson','negative_trap','proof_target','behavior_delta','return_to_parent','expansion_budget')){
      $p=$seed.PSObject.Properties[$required]
      if($null -eq $p -or [string]::IsNullOrWhiteSpace([string]$p.Value)){ throw "CAMPAIGN_SEED_MISSING_$required`:line_$lineNo" }
    }
    if(-not (Test-Path ([string]$seed.source_path))){ throw "CAMPAIGN_SEED_SOURCE_MISSING:$($seed.seed_id):$($seed.source_path)" }
    if([int]$seed.expansion_budget -lt 1){ throw "CAMPAIGN_SEED_EXPANSION_BUDGET_BAD:$($seed.seed_id)" }
    $seed | Add-Member -NotePropertyName pack_line -NotePropertyValue $lineNo -Force
    $seeds += $seed
  }
  return @($seeds)
}
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
function NewCampaignSeedTaskList($Seeds,$ExistingSchedule){
  if($null -eq $Seeds -or @($Seeds).Count -lt 1){ return @() }
  $taskByTheme=@{}
  foreach($task in @($ExistingSchedule)){
    $taskByTheme[[string]$task.theme_key]=$task
  }
  $seedTasks=New-Object System.Collections.Generic.List[object]
  $seedOrder=0
  foreach($seed in @($Seeds)){
    $seedOrder++
    $root=Slug(SeedValue $seed 'root')
    $verbs=SeedList $seed 'allowed_verbs' 'apply'
    $modes=SeedList $seed 'allowed_modes' 'directed_curriculum'
    foreach($verb in $verbs){ foreach($sourceMode in $modes){
      $baseThemeKey="$verb|$root|$sourceMode"
      if($taskByTheme.ContainsKey($baseThemeKey)){
        $base=$taskByTheme[$baseThemeKey]
        $last=[int]$base.last_level
        $next=[int]$base.next_level
        $count=[int]$base.atom_count
      } else {
        $last=0
        $next=1
        $count=0
      }
      $seedStart=0
      $startProp=$seed.PSObject.Properties['start_level']
      if($null -ne $startProp -and -not [string]::IsNullOrWhiteSpace([string]$startProp.Value)){ $seedStart=[int]$startProp.Value }
      if($seedStart -gt $next){
        $next=$seedStart
        $last=$next-1
      }
      $seedThemeKey="$(SeedValue $seed 'seed_id')|$verb|$root|$sourceMode"
      $seedTasks.Add([pscustomObject]@{
        verb=$verb
        root=$root
        source_mode=$sourceMode
        theme_key=$seedThemeKey
        last_level=$last
        next_level=$next
        atom_count=$count
        weight=100
        campaign_seed=$seed
        seed_id=(SeedValue $seed 'seed_id')
        seed_order=$seedOrder
      }) | Out-Null
    } }
  }
  return @($seedTasks.ToArray() | Sort-Object seed_order, verb, source_mode)
}
$taskSchedule=if($UseTopicCursor){ NewTaskListFromCursor } else { NewTaskListFromMemoryFallback }
if($taskSchedule.Count -lt 1){ throw 'FACTORY_TASK_SCHEDULE_EMPTY' }
$campaignSeeds=ReadCampaignPack $CampaignPack
$campaignSeedTasks=NewCampaignSeedTaskList $campaignSeeds $taskSchedule
$campaignPackStatus=if($campaignSeeds.Count -gt 0){'CAMPAIGN_PACK_APPLIED'}else{'NO_CAMPAIGN_PACK_FALLBACK_TEMPLATE_MODE'}
if($campaignSeeds.Count -gt 0 -and $campaignSeedTasks.Count -lt 1){ throw 'CAMPAIGN_PACK_LOADED_BUT_NO_SEED_TASKS' }
if($campaignSeedTasks.Count -gt 0){ $taskSchedule=@($campaignSeedTasks) }
$allPath=Join-Path $runDir 'all_candidates.jsonl'
if(Test-Path $allPath){ Remove-Item $allPath -Force }
$created=@(); $ordinal=0; $batchIndex=0; $generatedKeys=@{}; $generatedThemes=@{}; $runNextLevel=@{}; $campaignSeededCount=0; $fallbackTemplateCount=0
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
    $seed=$null
    if($task.PSObject.Properties.Name -contains 'campaign_seed'){ $seed=$task.campaign_seed }
    $seedId=SeedValue $seed 'seed_id' 'fallback_template'
    $campaignId=SeedValue $seed 'campaign_id' ''
    $seedBacked=($null -ne $seed)
    $cycleLevelOffset=[int][Math]::Floor([double]$globalOrdinal / [double]$taskSchedule.Count)
    $level=[int]$task.next_level + $cycleLevelOffset
    if($runNextLevel.ContainsKey($themeKey)){ $level=[int]$runNextLevel[$themeKey] + 1 }
    $runNextLevel[$themeKey]=$level
    $learningKey=if($seedBacked){"$seedId|$verb|$root|$level|$sourceMode"}else{"$verb|$root|$level|$sourceMode"}
    $prereq=if($level -gt 1){"$verb|$root|$($level-1)|$sourceMode"}else{$null}
    $generatedKeys[$learningKey]=$true; $generatedThemes[$themeKey]=$true
    $topic=$root
    if($seedBacked){
      $campaignSeededCount++
      $sourcePath=SeedValue $seed 'source_path'
      $sourceHint=SeedValue $seed 'source_anchor_or_hint'
      $sourceSummary=SeedValue $seed 'source_summary'
      $lesson=SeedValue $seed 'lesson'
      $proofTarget=SeedValue $seed 'proof_target'
      $behaviorDelta=SeedValue $seed 'behavior_delta'
      $negativeTrap=SeedValue $seed 'negative_trap'
      $returnToParent=SeedValue $seed 'return_to_parent'
      $objective="Use campaign seed $seedId to deepen $root at level $level through $verb, grounded in $sourcePath."
      $newKnowledge="$lesson Source summary: $sourceSummary"
      $exercise="Given a Builder situation involving $root, apply $verb using seed $seedId, cite the source boundary, name the proof target, and state the behavior change."
      $expectedBehavior="$behaviorDelta The Builder should use this sourced lesson only after matching the local evidence boundary and should keep Count, runtime, and memory authority separate."
      $validatorHint="Accept only if the response cites seed $seedId, keeps source path $sourcePath attached, satisfies proof target: $proofTarget, and avoids the negative trap."
      $behaviorUseProofTarget=$proofTarget
      $sourceAnchor="$sourcePath::$sourceHint"
      $candidateSource='campaign_pack_candidate_factory'
      $fallbackTemplate=$false
      $candidateDepthScore=5
    } else {
      $fallbackTemplateCount++
      $sourcePath=''
      $sourceHint=''
      $sourceSummary=''
      $lesson="Builder should learn how $root works at level $level, how to use it safely, what boundary applies, and what mistake must be avoided when applying $verb in $sourceMode."
      $proofTarget='A future recall/use probe should show the Builder applying this lesson to choose a safer reasoning or school-memory action, not merely repeating text.'
      $behaviorDelta='When the Builder meets this topic in a real task, it should ask the right context question, avoid overclaim, choose the smallest safe next step, and return evidence to parent.'
      $negativeTrap='Do not treat count, generated volume, folder existence, or a candidate itself as proof of knowledge or skill.'
      $returnToParent='Compress the accepted lesson into compact memory only after validation and report the resulting behavior boundary to the parent task.'
      $objective="Create compact, testable learning material for $root at level $level using verb $verb without claiming that count or volume proves quality."
      $newKnowledge=$lesson
      $exercise="Given a concrete Builder situation involving $root, explain the correct $verb response, name the boundary, and state one proof or validator needed before behavior changes."
      $expectedBehavior=$behaviorDelta
      $validatorHint="Accept only if the lesson separates meaning, boundary, proof requirement, and return-to-parent behavior for this topic."
      $behaviorUseProofTarget=$proofTarget
      $sourceAnchor="active_school_self_knowledge_curriculum:${root}:${verb}:${sourceMode}"
      $candidateSource='local_cursor_guided_factory'
      $fallbackTemplate=$true
      $candidateDepthScore=1
    }
    $obj=[ordered]@{
      schema='codex_curriculum_candidate_v1'
      candidate_id=("cand_{0:D8}" -f ($OrdinalOffset+$ordinal))
      run_id=$RunId
      run_kind=$RunKind
      source=$candidateSource
      source_mode=$sourceMode
      topic=$topic
      verb=$verb
      root=$root
      level=$level
      learning_key=$learningKey
      duplicate_key=$learningKey
      theme_key=$themeKey
      title="$verb $root level $level"
      objective=$objective
      new_knowledge=$newKnowledge
      exercise=$exercise
      expected_behavior=$expectedBehavior
      negative_trap=$negativeTrap
      validator_hint=$validatorHint
      behavior_use_proof_target=$behaviorUseProofTarget
      return_to_parent=$returnToParent
      source_anchor=$sourceAnchor
      self_generated_easy_candidate=$false
      acceptance_hint='must produce one compact atom candidate with evidence boundary and no active mutation'
      topic_plan=$TopicsPlan
      campaign_pack=$CampaignPack
      campaign_pack_status=$campaignPackStatus
      campaign_id=$campaignId
      seed_id=$seedId
      fallback_template=$fallbackTemplate
      evidence_kind=(SeedValue $seed 'source_kind' '')
      evidence_path=$sourcePath
      source_path=$sourcePath
      source_anchor_or_hint=$sourceHint
      source_summary=$sourceSummary
      campaign_lesson=$lesson
      campaign_negative_trap=$negativeTrap
      campaign_proof_target=$proofTarget
      campaign_behavior_delta=$behaviorDelta
      candidate_depth_score=$candidateDepthScore
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
  $checkpoint=[pscustomObject]@{schema='codex_candidate_factory_checkpoint_v1'; status='RUNNING'; run_id=$RunId; run_kind=$RunKind; run_slug=$runSlug; use_factory_memory=$UseFactoryMemory; use_topic_cursor=$UseTopicCursor; topics_plan=$TopicsPlan; topic_plan_status=$topicPlanStatus; campaign_pack=$CampaignPack; campaign_pack_status=$campaignPackStatus; campaign_seed_count=$campaignSeeds.Count; campaign_seed_task_count=$campaignSeedTasks.Count; target_accepted=$TargetAccepted; batch_size=$BatchSize; batches_created=$created.Count; candidates_created=$ordinal; campaign_seeded_candidates=$campaignSeededCount; fallback_template_candidates=$fallbackTemplateCount; run_dir=$runDir; all_candidates_path=$allPath; generated_learning_key_count=$generatedKeys.Keys.Count; generated_theme_count=$generatedThemes.Keys.Count; task_schedule_count=$taskSchedule.Count; updated_at=(Get-Date).ToString('o')}
  WriteJson (Join-Path $runDir 'checkpoint.json') $checkpoint 50
}
$report=[pscustomObject]@{schema='codex_candidate_factory_run_v1'; status='PASS_CODEX_CANDIDATE_FACTORY_GENERATION_V1'; runtime_ready=$false; run_id=$RunId; run_slug=$runSlug; run_kind=$RunKind; use_factory_memory=$UseFactoryMemory; use_topic_cursor=$UseTopicCursor; topics_plan=$TopicsPlan; topic_plan_status=$topicPlanStatus; campaign_pack=$CampaignPack; campaign_pack_status=$campaignPackStatus; campaign_seed_count=$campaignSeeds.Count; campaign_seed_task_count=$campaignSeedTasks.Count; target_accepted=$TargetAccepted; batch_size=$BatchSize; batches_created=$created.Count; candidates_created=$TargetAccepted; campaign_seeded_candidates=$campaignSeededCount; fallback_template_candidates=$fallbackTemplateCount; seed_backed_percent=if($TargetAccepted -gt 0){[Math]::Round((100.0*$campaignSeededCount/$TargetAccepted),2)}else{0}; fallback_percent=if($TargetAccepted -gt 0){[Math]::Round((100.0*$fallbackTemplateCount/$TargetAccepted),2)}else{0}; run_dir=$runDir; all_candidates_path=$allPath; all_candidates_sha256=(Get-FileHash $allPath -Algorithm SHA256).Hash.ToLower(); generated_learning_key_count=$generatedKeys.Keys.Count; generated_theme_count=$generatedThemes.Keys.Count; task_schedule_count=$taskSchedule.Count; codex_cli_invoked=$false; api_invoked=$false; active_memory_mutated=$false; batch_reports=@($created); boundary='Local cursor-guided factory generation with optional campaign pack seeds; no Codex CLI/API calls, no active promotion, no live proof.'}
WriteJson 'operations/reports/CODEX_CANDIDATE_FACTORY_RUN_V1.json' $report 80
$md=@('# CODEX_CANDIDATE_FACTORY_RUN_V1','',"Status: $($report.status)",'Runtime ready: false','',"Run id: $RunId","Run slug: $runSlug","Use factory memory: $UseFactoryMemory","Use topic cursor: $UseTopicCursor","Campaign pack: $CampaignPack","Campaign pack status: $campaignPackStatus","Campaign seeds: $($campaignSeeds.Count)","Campaign seed tasks: $($campaignSeedTasks.Count)","TargetAccepted: $TargetAccepted","Batch size: $BatchSize","Batches created: $($created.Count)","Candidates created: $TargetAccepted","Campaign seeded candidates: $campaignSeededCount","Fallback template candidates: $fallbackTemplateCount","Seed-backed percent: $($report.seed_backed_percent)","Fallback percent: $($report.fallback_percent)","Generated learning keys: $($report.generated_learning_key_count)","Generated themes: $($report.generated_theme_count)","Task schedule count: $($report.task_schedule_count)","Codex CLI invoked: false","Active memory mutated: false",'', 'Boundary: local cursor-guided generation only; no active promotion.')
[IO.File]::WriteAllText((Join-Path (Get-Location).Path 'operations/reports/CODEX_CANDIDATE_FACTORY_RUN_V1.md'),($md -join "`r`n"),$utf8)
Write-Host "FACTORY_STATUS=PASS_CODEX_CANDIDATE_FACTORY_GENERATION_V1"
Write-Host "RUN_ID=$RunId"
Write-Host "RUN_SLUG=$runSlug"
Write-Host "USE_FACTORY_MEMORY=$UseFactoryMemory"
Write-Host "USE_TOPIC_CURSOR=$UseTopicCursor"
Write-Host "CAMPAIGN_PACK=$CampaignPack"
Write-Host "CAMPAIGN_PACK_STATUS=$campaignPackStatus"
Write-Host "CAMPAIGN_SEEDS=$($campaignSeeds.Count)"
Write-Host "CAMPAIGN_SEED_TASKS=$($campaignSeedTasks.Count)"
Write-Host "RUN_DIR=$runDir"
Write-Host "TARGET_ACCEPTED=$TargetAccepted"
Write-Host "BATCH_SIZE=$BatchSize"
Write-Host "BATCHES_CREATED=$($created.Count)"
Write-Host "CANDIDATES_CREATED=$TargetAccepted"
Write-Host "CAMPAIGN_SEEDED_CANDIDATES=$campaignSeededCount"
Write-Host "FALLBACK_TEMPLATE_CANDIDATES=$fallbackTemplateCount"
Write-Host "SEED_BACKED_PERCENT=$($report.seed_backed_percent)"
Write-Host "FALLBACK_PERCENT=$($report.fallback_percent)"
Write-Host "GENERATED_LEARNING_KEYS=$($report.generated_learning_key_count)"
Write-Host "GENERATED_THEMES=$($report.generated_theme_count)"
Write-Host "TASK_SCHEDULE_COUNT=$($report.task_schedule_count)"
Write-Host "CODEX_CLI_INVOKED=false"
Write-Host "ACTIVE_MEMORY_MUTATED=false"
Write-Host "RUNTIME_READY=false"




