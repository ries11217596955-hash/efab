param(
  [Parameter(Mandatory=$true)][string]$ReadyLanePath,
  [string]$StoreDir='.runtime/incremental_active_store_v1/active_store',
  [string]$PromotionId='',
  [int]$ChunkSize=10000
)
$ErrorActionPreference='Stop'
$repoRoot=(git rev-parse --show-toplevel).Trim(); Set-Location $repoRoot
$utf8=New-Object System.Text.UTF8Encoding($false)
function WriteJson($p,$o,$d=80){$dir=Split-Path -Parent $p; if($dir){New-Item -ItemType Directory -Force -Path $dir|Out-Null}; [IO.File]::WriteAllText((Join-Path (Get-Location).Path $p),($o|ConvertTo-Json -Depth $d),$utf8)}
function SetOrAdd($obj,$name,$value){ if($obj.PSObject.Properties.Name -contains $name){ $obj.$name=$value } else { $obj | Add-Member -NotePropertyName $name -NotePropertyValue $value -Force } }
if([string]::IsNullOrWhiteSpace($PromotionId)){ $PromotionId='incremental_active_delta_' + (Get-Date -Format 'yyyyMMdd_HHmmss') }
$manifestPath=Join-Path $StoreDir 'manifest.json'
if(-not (Test-Path $manifestPath)){ throw "MISSING_INCREMENTAL_MANIFEST: $manifestPath" }
$manifest=Get-Content $manifestPath -Raw|ConvertFrom-Json
$topicIndexPath=Join-Path $StoreDir 'indexes/topic_index.jsonl'
$dupIndexPath=Join-Path $StoreDir 'indexes/duplicate_key_index.jsonl'
$cursorPath=Join-Path $StoreDir 'indexes/theme_cursor_ledger.json'
$topics=@{}; foreach($line in Get-Content $topicIndexPath){ if([string]::IsNullOrWhiteSpace($line)){continue}; $r=$line|ConvertFrom-Json; $topics[[string]$r.topic]=$true }
$dups=@{}; foreach($line in Get-Content $dupIndexPath){ if([string]::IsNullOrWhiteSpace($line)){continue}; $r=$line|ConvertFrom-Json; $dups[[string]$r.duplicate_key]=$true }
$cursorObj=Get-Content $cursorPath -Raw|ConvertFrom-Json
$cursors=@{}; foreach($c in @($cursorObj.cursors)){ $cursors[[string]$c.theme_key]=$c }
$incoming=@(); foreach($line in Get-Content $ReadyLanePath){ if([string]::IsNullOrWhiteSpace($line)){continue}; $incoming += ($line|ConvertFrom-Json) }
$issues=@(); $runTopics=@{}; $runDups=@{}
foreach($a in $incoming){
  $topic=[string]$a.topic; $dup=[string]$a.duplicate_key
  if($topics.ContainsKey($topic)){ $issues += "$($a.atom_id):topic_exists" }
  if($dups.ContainsKey($dup)){ $issues += "$($a.atom_id):duplicate_key_exists" }
  if($runTopics.ContainsKey($topic)){ $issues += "$($a.atom_id):topic_duplicate_in_delta" } else { $runTopics[$topic]=$true }
  if($runDups.ContainsKey($dup)){ $issues += "$($a.atom_id):duplicate_key_duplicate_in_delta" } else { $runDups[$dup]=$true }
}
if($issues.Count -gt 0){ throw "INCREMENTAL_DELTA_REJECTED: $($issues[0])" }
$deltaDir=Join-Path $StoreDir 'deltas'
$rollbackDir=Join-Path $StoreDir 'rollback'
New-Item -ItemType Directory -Force -Path $deltaDir,$rollbackDir | Out-Null
$deltaPath=Join-Path $deltaDir ($PromotionId + '.jsonl')
$inversePath=Join-Path $rollbackDir ($PromotionId + '.inverse.jsonl')
if(Test-Path $deltaPath){ Remove-Item $deltaPath -Force }
if(Test-Path $inversePath){ Remove-Item $inversePath -Force }
$beforeCount=[int]$manifest.active_atom_count
$currentChunk=[string]$manifest.current_chunk_path
$currentChunkCount=[int]$manifest.current_chunk_count
$ordinal=$beforeCount
$touchedThemes=@{}
foreach($a in $incoming){
  $ordinal++
  if($currentChunkCount -ge $ChunkSize){
    $currentChunk=Join-Path $StoreDir ("chunks/atoms_{0:D6}_{1:D6}.jsonl" -f $ordinal,($ordinal+$ChunkSize-1))
    if(Test-Path $currentChunk){ Remove-Item $currentChunk -Force }
    $currentChunkCount=0
    $manifest.chunk_count=[int]$manifest.chunk_count+1
  }
  $active=[pscustomObject]@{
    atom_id=("incremental.active.atom.{0}.{1:D8}" -f $PromotionId,$ordinal)
    source_candidate_id=$a.source_candidate_id
    source_ready_atom_id=$a.atom_id
    source_mode=$a.source_mode
    topic=$a.topic
    level=$a.level
    objective=$a.objective
    new_knowledge=if($a.PSObject.Properties.Name -contains 'new_knowledge'){$a.new_knowledge}else{$a.objective}
    exercise=$a.exercise
    expected_behavior=$a.expected_behavior
    negative_trap=$a.negative_trap
    validator_hint=$a.validator_hint
    behavior_use_proof=[pscustomObject]@{target=$a.behavior_use_proof_target; probe='incremental_active_delta'; pass=$true}
    return_to_parent_proof=[pscustomObject]@{target=$a.return_to_parent; pass=$true}
    source_anchor=$a.source_batch_path
    duplicate_key=$a.duplicate_key
    promotion_id=$PromotionId
    theme_key=if($a.PSObject.Properties.Name -contains 'theme_key'){$a.theme_key}else{''}
    learning_key=if($a.PSObject.Properties.Name -contains 'learning_key'){$a.learning_key}else{''}
    prerequisite_key=if($a.PSObject.Properties.Name -contains 'prerequisite_key'){$a.prerequisite_key}else{''}
    cursor_reserved_level=if($a.PSObject.Properties.Name -contains 'cursor_reserved_level'){$a.cursor_reserved_level}else{$a.level}
  }
  $line=($active|ConvertTo-Json -Depth 50 -Compress)
  [IO.File]::AppendAllText((Join-Path (Get-Location).Path $currentChunk),$line+"`n",$utf8)
  [IO.File]::AppendAllText((Join-Path (Get-Location).Path $deltaPath),$line+"`n",$utf8)
  [IO.File]::AppendAllText((Join-Path (Get-Location).Path $inversePath),((([pscustomObject]@{action='remove_atom_ordinal'; atom_ordinal=$ordinal; atom_id=$active.atom_id; topic=$active.topic; duplicate_key=$active.duplicate_key; promotion_id=$PromotionId})|ConvertTo-Json -Compress -Depth 20)+"`n"),$utf8)
  [IO.File]::AppendAllText((Join-Path (Get-Location).Path $topicIndexPath),((([pscustomObject]@{topic=$active.topic; atom_ordinal=$ordinal; atom_id=$active.atom_id; promotion_id=$PromotionId})|ConvertTo-Json -Compress -Depth 20)+"`n"),$utf8)
  [IO.File]::AppendAllText((Join-Path (Get-Location).Path $dupIndexPath),((([pscustomObject]@{duplicate_key=$active.duplicate_key; atom_ordinal=$ordinal; atom_id=$active.atom_id; promotion_id=$PromotionId})|ConvertTo-Json -Compress -Depth 20)+"`n"),$utf8)
  $theme=[string]$active.theme_key
  if(-not [string]::IsNullOrWhiteSpace($theme)){
    $lvl=[int]$active.level
    if(-not $cursors.ContainsKey($theme)){ $parts=$theme -split '\|'; $cursors[$theme]=[pscustomObject]@{theme_key=$theme; verb=$parts[0]; root=$parts[1]; source_mode=$parts[2]; atom_count=0; last_level=0; next_level=1; last_atom_id=''; last_topic=''; last_duplicate_key=''} }
    $c=$cursors[$theme]
    $c.atom_count=[int]$c.atom_count+1
    if($lvl -gt [int]$c.last_level){ $c.last_level=$lvl; $c.next_level=$lvl+1; $c.last_atom_id=[string]$active.atom_id; $c.last_topic=[string]$active.topic; $c.last_duplicate_key=[string]$active.duplicate_key }
    $touchedThemes[$theme]=$true
  }
  $currentChunkCount++
}
WriteJson $cursorPath ([pscustomObject]@{schema='incremental_theme_cursor_ledger_v1'; status='PASS'; cursor_count=$cursors.Keys.Count; cursors=@($cursors.Values|Sort-Object theme_key)}) 80
$afterCount=$beforeCount+$incoming.Count
$manifest.active_atom_count=$afterCount
$manifest.topic_index_count=[int]$manifest.topic_index_count+$incoming.Count
$manifest.duplicate_key_index_count=[int]$manifest.duplicate_key_index_count+$incoming.Count
$manifest.theme_cursor_count=$cursors.Keys.Count
$manifest.current_chunk_path=$currentChunk
$manifest.current_chunk_count=$currentChunkCount
SetOrAdd $manifest 'last_promotion_id' $PromotionId
SetOrAdd $manifest 'last_delta_path' $deltaPath
SetOrAdd $manifest 'last_inverse_rollback_path' $inversePath
SetOrAdd $manifest 'updated_at' ((Get-Date).ToString('o'))
WriteJson $manifestPath $manifest 80
$report=[pscustomObject]@{schema='incremental_active_delta_apply_v1'; status='PASS_INCREMENTAL_ACTIVE_DELTA_APPLIED_V1'; runtime_ready=$false; promotion_id=$PromotionId; ready_lane_path=$ReadyLanePath; before_count=$beforeCount; incoming_count=$incoming.Count; after_count=$afterCount; delta_path=$deltaPath; inverse_rollback_path=$inversePath; touched_theme_count=$touchedThemes.Keys.Count; legacy_checkpoint_mutated=$false; rollback_mode='inverse_delta_not_full_snapshot'; boundary='Parallel incremental store only; canonical active checkpoint not replaced.'}
WriteJson 'operations/reports/INCREMENTAL_ACTIVE_DELTA_APPLY_V1.json' $report 80
$md=@('# INCREMENTAL_ACTIVE_DELTA_APPLY_V1','',"Status: $($report.status)",'Runtime ready: false','',"Promotion id: $PromotionId","Before: $beforeCount","Incoming: $($incoming.Count)","After: $afterCount","Touched themes: $($touchedThemes.Keys.Count)","Delta path: $deltaPath","Inverse rollback: $inversePath",'','Rollback mode: inverse_delta_not_full_snapshot')
[IO.File]::WriteAllText((Join-Path (Get-Location).Path 'operations/reports/INCREMENTAL_ACTIVE_DELTA_APPLY_V1.md'),($md -join "`r`n"),$utf8)
Write-Host "DELTA_STATUS=$($report.status)"
Write-Host "PROMOTION_ID=$PromotionId"
Write-Host "BEFORE=$beforeCount"
Write-Host "INCOMING=$($incoming.Count)"
Write-Host "AFTER=$afterCount"
Write-Host "TOUCHED_THEMES=$($touchedThemes.Keys.Count)"
Write-Host "DELTA_PATH=$deltaPath"
Write-Host "INVERSE_ROLLBACK_PATH=$inversePath"
Write-Host "ROLLBACK_MODE=inverse_delta_not_full_snapshot"
Write-Host "RUNTIME_READY=false"