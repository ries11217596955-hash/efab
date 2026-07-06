param(
  [string]$ActiveCheckpointPath='operations/school/curriculum/codex_digest/store/active_codex_curriculum_digest_v1/active_codex_curriculum_digest_checkpoint.json',
  [string]$MemoryDir='operations/school/curriculum/candidate_factory/memory'
)
$ErrorActionPreference='Stop'
$repoRoot=(git rev-parse --show-toplevel).Trim(); Set-Location $repoRoot
$utf8=New-Object System.Text.UTF8Encoding($false)
function WriteJson($p,$o,$d=100){$dir=Split-Path -Parent $p; if($dir){New-Item -ItemType Directory -Force -Path $dir|Out-Null}; [IO.File]::WriteAllText((Join-Path (Get-Location).Path $p),($o|ConvertTo-Json -Depth $d),$utf8)}
$topicRoots=@('proof_boundary','school_life_boundary','codex_preflight','validator_consistency','streaming_absorption','ready_lane_gate','rollback_snapshot','scale_gate','decision_use','return_to_parent','contract_schema','source_anchor','duplicate_key_hygiene','count_not_learning','runtime_boundary','active_repo_body','quarantine_lane','factory_generation','batch_checkpoint','owner_selected_n','canonical_scheduler','local_first','no_external_brain','negative_control','promotion_boundary','lab_not_live','child_agent_delay','memory_compaction','source_ladder','failure_report')
$verbs=@('separate','classify','validate','guard','stream','promote','rollback','prove','route','compress')
function ParseFactoryTopic([string]$topic){
  foreach($verb in $verbs){ foreach($root in $topicRoots){ $prefix="factory_${verb}_${root}_"; if($topic.StartsWith($prefix)){ return [pscustomObject]@{is_factory=$true; verb=$verb; root=$root} } } }
  return [pscustomObject]@{is_factory=$false; verb=''; root=''}
}
New-Item -ItemType Directory -Force -Path $MemoryDir | Out-Null
$cp=Get-Content $ActiveCheckpointPath -Raw | ConvertFrom-Json
$atoms=@($cp.atoms)
$cursors=@{}; $topicIndex=@{}; $dupIndex=@{}; $topicDup=0; $dupDup=0; $factoryCount=0
foreach($a in $atoms){
  $topic=[string]$a.topic; $dup=[string]$a.duplicate_key
  if($topicIndex.ContainsKey($topic)){ $topicDup++ } else { $topicIndex[$topic]=[pscustomObject]@{atom_id=$a.atom_id; topic=$topic} }
  if($dupIndex.ContainsKey($dup)){ $dupDup++ } else { $dupIndex[$dup]=[pscustomObject]@{atom_id=$a.atom_id; duplicate_key=$dup} }
  $p=ParseFactoryTopic $topic
  if(-not $p.is_factory){ continue }
  $factoryCount++
  $src=[string]$a.source_mode
  $themeKey="$($p.verb)|$($p.root)|$src"
  $lvl=0; try{$lvl=[int]$a.level}catch{$lvl=0}
  if(-not $cursors.ContainsKey($themeKey)){
    $cursors[$themeKey]=[pscustomObject]@{theme_key=$themeKey; verb=$p.verb; root=$p.root; source_mode=$src; atom_count=0; last_level=0; next_level=1; last_atom_id=''; last_topic=''; last_duplicate_key=''; status='OPEN'}
  }
  $c=$cursors[$themeKey]
  $c.atom_count=[int]$c.atom_count+1
  if($lvl -gt [int]$c.last_level){ $c.last_level=$lvl; $c.next_level=$lvl+1; $c.last_atom_id=[string]$a.atom_id; $c.last_topic=$topic; $c.last_duplicate_key=$dup }
}
$cursorList=@($cursors.Values | Sort-Object last_level, root, verb, source_mode)
$report=[pscustomObject]@{schema='factory_topic_cursor_ledger_v1'; status='PASS_FACTORY_TOPIC_CURSOR_LEDGER_V1'; runtime_ready=$false; active_atom_count=$atoms.Count; factory_atom_count=$factoryCount; theme_cursor_count=$cursorList.Count; topic_index_count=$topicIndex.Keys.Count; duplicate_key_index_count=$dupIndex.Keys.Count; topic_duplicate_count=$topicDup; duplicate_key_duplicate_count=$dupDup; cursor_path=(Join-Path $MemoryDir 'theme_cursor_ledger.json'); topic_index_path=(Join-Path $MemoryDir 'topic_hash_index.json'); duplicate_key_index_path=(Join-Path $MemoryDir 'duplicate_key_hash_index.json'); reservation_log_path=(Join-Path $MemoryDir 'cursor_reservation_log.jsonl'); boundary='Cursor ledger and O(1)-style hash indexes only; no generation, no active mutation, no live proof.'}
WriteJson (Join-Path $MemoryDir 'theme_cursor_ledger.json') ([pscustomObject]@{schema='theme_cursor_ledger_v1'; status='PASS'; generated_at=(Get-Date).ToString('o'); cursors=@($cursorList)}) 100
WriteJson (Join-Path $MemoryDir 'topic_hash_index.json') ([pscustomObject]@{schema='topic_hash_index_v1'; status='PASS'; count=$topicIndex.Keys.Count; index=$topicIndex}) 100
WriteJson (Join-Path $MemoryDir 'duplicate_key_hash_index.json') ([pscustomObject]@{schema='duplicate_key_hash_index_v1'; status='PASS'; count=$dupIndex.Keys.Count; index=$dupIndex}) 100
if(-not (Test-Path (Join-Path $MemoryDir 'cursor_reservation_log.jsonl'))){ New-Item -ItemType File -Path (Join-Path $MemoryDir 'cursor_reservation_log.jsonl') | Out-Null }
WriteJson (Join-Path $MemoryDir 'factory_topic_cursor_ledger_report.json') $report 100
WriteJson 'operations/reports/FACTORY_TOPIC_CURSOR_LEDGER_V1.json' $report 100
$md=@('# FACTORY_TOPIC_CURSOR_LEDGER_V1','',"Status: $($report.status)",'Runtime ready: false','',"Active atoms: $($report.active_atom_count)","Factory atoms: $($report.factory_atom_count)","Theme cursors: $($report.theme_cursor_count)","Topic index count: $($report.topic_index_count)","Duplicate-key index count: $($report.duplicate_key_index_count)","Topic duplicates: $($report.topic_duplicate_count)","Duplicate-key duplicates: $($report.duplicate_key_duplicate_count)",'','Boundary: cursor/index only; no active mutation.')
[IO.File]::WriteAllText((Join-Path (Get-Location).Path 'operations/reports/FACTORY_TOPIC_CURSOR_LEDGER_V1.md'),($md -join "`r`n"),$utf8)
Write-Host "CURSOR_STATUS=$($report.status)"
Write-Host "ACTIVE_ATOMS=$($report.active_atom_count)"
Write-Host "FACTORY_ATOMS=$($report.factory_atom_count)"
Write-Host "THEME_CURSORS=$($report.theme_cursor_count)"
Write-Host "TOPIC_INDEX=$($report.topic_index_count)"
Write-Host "DUPKEY_INDEX=$($report.duplicate_key_index_count)"
Write-Host "TOPIC_DUPS=$($report.topic_duplicate_count)"
Write-Host "DUPKEY_DUPS=$($report.duplicate_key_duplicate_count)"
Write-Host "RUNTIME_READY=false"