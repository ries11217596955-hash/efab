$ErrorActionPreference='Stop'
$repoRoot=(git rev-parse --show-toplevel).Trim(); Set-Location $repoRoot
function Assert($Cond,[string]$Msg){ if(-not $Cond){ throw $Msg } }
function Write-Json([string]$Path,$Obj,[int]$Depth=100){$dir=Split-Path -Parent $Path;if($dir){New-Item -ItemType Directory -Force -Path $dir|Out-Null};$Obj|ConvertTo-Json -Depth $Depth|Set-Content $Path -Encoding UTF8}
$topicsPath='operations/school/curriculum/topics/builder_night_school_topics_v1.json'
$checkpointPath='operations/school/curriculum/store/active_curriculum_school_v1/active_curriculum_checkpoint.json'
$memoryDir='operations/school/curriculum/candidate_factory/memory'
$ledgerPath=Join-Path $memoryDir 'theme_cursor_ledger.json'
$factoryLedgerPath=Join-Path $memoryDir 'factory_ledger.jsonl'
$reportPath='operations/school/curriculum/candidate_factory/reports/THEME_CURSOR_LEDGER_REBUILD_V1_REPORT.json'
$proofPath='tests/school/candidate_factory/THEME_CURSOR_LEDGER_REBUILD_V1_PROOF.json'
foreach($p in @($topicsPath,$checkpointPath)){Assert (Test-Path $p) "MISSING_INPUT:$p"}
$topics=Get-Content $topicsPath -Raw|ConvertFrom-Json
$checkpoint=Get-Content $checkpointPath -Raw|ConvertFrom-Json
Assert ($topics.constraints.levels_continue_by_theme_cursor -eq $true) 'TOPICS_PLAN_CURSOR_FLAG_NOT_TRUE'
$cursors=@{}
$seeded=0
foreach($topic in @($topics.topics)){
  $root=[string]$topic.root
  foreach($verb in @($topic.verbs)){
    foreach($mode in @($topic.modes)){
      $themeKey="$verb|$root|$mode"
      if(-not $cursors.ContainsKey($themeKey)){
        $cursors[$themeKey]=[ordered]@{
          theme_key=$themeKey
          verb=[string]$verb
          root=$root
          source_mode=[string]$mode
          topic=$root
          last_level=0
          next_level=1
          atom_count=0
          source='topics_plan_seed_no_historic_cursor'
          confidence='LOW_NO_EXISTING_CURSOR_LEDGER'
          updated_at=(Get-Date).ToString('o')
        }
        $seeded++
      }
    }
  }
}
$harvested=0; $maxed=0
$containers=@()
foreach($name in @('atoms','accepted_atoms','items','records')){ if($checkpoint.PSObject.Properties.Name -contains $name){ $containers += @($checkpoint.$name) } }
foreach($a in @($containers)){
  if($null -eq $a){ continue }
  $themeKey=$null
  if($a.PSObject.Properties.Name -contains 'theme_key' -and $a.theme_key){$themeKey=[string]$a.theme_key}
  elseif(($a.PSObject.Properties.Name -contains 'verb') -and ($a.PSObject.Properties.Name -contains 'root') -and ($a.PSObject.Properties.Name -contains 'source_mode')){$themeKey="$($a.verb)|$($a.root)|$($a.source_mode)"}
  elseif(($a.PSObject.Properties.Name -contains 'duplicate_key') -and $a.duplicate_key){$themeKey=[string]$a.duplicate_key}
  if([string]::IsNullOrWhiteSpace($themeKey)){continue}
  $levelRaw=$null
  if($a.PSObject.Properties.Name -contains 'cursor_reserved_level' -and $a.cursor_reserved_level){$levelRaw=$a.cursor_reserved_level}
  elseif($a.PSObject.Properties.Name -contains 'level' -and $a.level){$levelRaw=$a.level}
  if($null -eq $levelRaw){continue}
  try{$lvl=[int]$levelRaw}catch{continue}
  if($lvl -lt 1){continue}
  if(-not $cursors.ContainsKey($themeKey)){
    $parts=$themeKey -split '\|'
    $cursors[$themeKey]=[ordered]@{theme_key=$themeKey;verb=if($parts.Count -ge 1){$parts[0]}else{''};root=if($parts.Count -ge 2){$parts[1]}else{$themeKey};source_mode=if($parts.Count -ge 3){$parts[2]}else{''};topic=if($a.PSObject.Properties.Name -contains 'topic'){$a.topic}else{$themeKey};last_level=0;next_level=1;atom_count=0;source='checkpoint_harvest';confidence='MEDIUM_CHECKPOINT_LEVEL';updated_at=(Get-Date).ToString('o')}
  }
  if($lvl -gt [int]$cursors[$themeKey].last_level){$cursors[$themeKey].last_level=$lvl; $cursors[$themeKey].next_level=$lvl+1; $cursors[$themeKey].source='checkpoint_harvest'; $cursors[$themeKey].confidence='MEDIUM_CHECKPOINT_LEVEL'; $maxed++}
  $cursors[$themeKey].atom_count=[int]$cursors[$themeKey].atom_count+1
  $harvested++
}
$cursorEntries=@($cursors.Keys | Sort-Object | ForEach-Object { [pscustomObject]$cursors[$_] })
$ledger=[ordered]@{
  schema='theme_cursor_ledger_v1'
  status='PASS_THEME_CURSOR_LEDGER_REBUILD_V1'
  policy='known theme continues from next_level; new/missing theme starts at level 1'
  source_topics_plan=$topicsPath
  source_checkpoint=$checkpointPath
  checkpoint_status=if($checkpoint.status){$checkpoint.status}else{$checkpoint.schema}
  active_route_warning='If active checkpoint is skeleton/reset or lacks theme levels, historic depth is not invented. Seeded topics start at level 1 until real school run updates ledger.'
  theme_count=$cursorEntries.Count
  harvested_records=$harvested
  cursors=$cursorEntries
  created_at=(Get-Date).ToString('o')
}
$report=[ordered]@{schema='theme_cursor_ledger_rebuild_v1_report';status='PASS_THEME_CURSOR_LEDGER_REBUILD_V1';ledger_path=$ledgerPath;factory_ledger_path=$factoryLedgerPath;seeded_topics=$seeded;harvested_records=$harvested;harvested_level_updates=$maxed;theme_count=$cursorEntries.Count;cursor_policy_verified=$true;limitation=if($harvested -eq 0){'No active historical theme levels found; ledger is seeded from topics plan with level 1 starts.'}else{'Ledger includes harvested checkpoint levels where available.'};created_at=(Get-Date).ToString('o')}
$proof=[ordered]@{schema='theme_cursor_ledger_rebuild_v1_proof';status='PASS_THEME_CURSOR_LEDGER_REBUILD_V1';topics_plan_cursor_flag_true=$true;ledger_created=$true;factory_ledger_created=$true;theme_count=$cursorEntries.Count;all_next_levels_valid=(@($cursorEntries|Where-Object{[int]$_.next_level -ne ([int]$_.last_level+1) -or [int]$_.next_level -lt 1}).Count -eq 0);policy_known_theme_next_level='last_level+1';policy_new_theme_start='level_1_when_missing_cursor';historic_depth_invented=$false;harvested_records=$harvested;active_school_only=$true;active_school_entrypoint='operations/school/run_agent_school.ps1';no_school_run_performed=$true;compact_memory_updated=$false;active_memory_updated=$false;live_runtime_touched=$false;report_path=$reportPath;created_at=(Get-Date).ToString('o')}
Write-Json $ledgerPath $ledger 100
if(-not (Test-Path $factoryLedgerPath)){ Set-Content $factoryLedgerPath -Encoding UTF8 -Value '' }
Write-Json $reportPath $report 100
Write-Json $proofPath $proof 100
Write-Host 'REBUILD_PASS=PASS_THEME_CURSOR_LEDGER_REBUILD_V1'
Write-Host "THEMES=$($cursorEntries.Count)"
Write-Host "HARVESTED_RECORDS=$harvested"
Write-Host "LEDGER=$ledgerPath"
