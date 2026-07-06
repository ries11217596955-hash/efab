param(
  [string]$ActiveCheckpointPath='operations/school/curriculum/codex_digest/store/active_codex_curriculum_digest_v1/active_codex_curriculum_digest_checkpoint.json',
  [string]$StoreDir='.runtime/incremental_active_store_v1/active_store',
  [int]$ChunkSize=10000,
  [switch]$Force
)
$ErrorActionPreference='Stop'
$repoRoot=(git rev-parse --show-toplevel).Trim(); Set-Location $repoRoot
$utf8=New-Object System.Text.UTF8Encoding($false)
function WriteJson($p,$o,$d=80){$dir=Split-Path -Parent $p; if($dir){New-Item -ItemType Directory -Force -Path $dir|Out-Null}; [IO.File]::WriteAllText((Join-Path (Get-Location).Path $p),($o|ConvertTo-Json -Depth $d),$utf8)}
function Slug($s){ return (([string]$s).ToLowerInvariant() -replace '[^a-z0-9]+','_').Trim('_') }
$topicRoots=@('proof_boundary','school_life_boundary','codex_preflight','validator_consistency','streaming_absorption','ready_lane_gate','rollback_snapshot','scale_gate','decision_use','return_to_parent','contract_schema','source_anchor','duplicate_key_hygiene','count_not_learning','runtime_boundary','active_repo_body','quarantine_lane','factory_generation','batch_checkpoint','owner_selected_n','canonical_scheduler','local_first','no_external_brain','negative_control','promotion_boundary','lab_not_live','child_agent_delay','memory_compaction','source_ladder','failure_report')
$verbs=@('separate','classify','validate','guard','stream','promote','rollback','prove','route','compress')
function ParseTheme($a){
  if($a.PSObject.Properties.Name -contains 'theme_key' -and -not [string]::IsNullOrWhiteSpace([string]$a.theme_key)){ return [string]$a.theme_key }
  $topic=[string]$a.topic
  foreach($verb in $verbs){ foreach($root in $topicRoots){ if($topic.StartsWith("factory_${verb}_${root}_")){ return "$verb|$root|$([string]$a.source_mode)" } } }
  return ''
}
if((Test-Path $StoreDir) -and $Force){ Remove-Item $StoreDir -Recurse -Force }
New-Item -ItemType Directory -Force -Path $StoreDir,(Join-Path $StoreDir 'chunks'),(Join-Path $StoreDir 'indexes'),(Join-Path $StoreDir 'deltas'),(Join-Path $StoreDir 'rollback'),(Join-Path $StoreDir 'audits') | Out-Null
$sourceHash=(Get-FileHash $ActiveCheckpointPath -Algorithm SHA256).Hash.ToLower()
$cp=Get-Content $ActiveCheckpointPath -Raw|ConvertFrom-Json
$atoms=@($cp.atoms)
$topicIndexPath=Join-Path $StoreDir 'indexes/topic_index.jsonl'
$dupIndexPath=Join-Path $StoreDir 'indexes/duplicate_key_index.jsonl'
if(Test-Path $topicIndexPath){ Remove-Item $topicIndexPath -Force }
if(Test-Path $dupIndexPath){ Remove-Item $dupIndexPath -Force }
$topicSet=@{}; $dupSet=@{}; $cursors=@{}; $chunkReports=@(); $chunkNo=0; $lineInChunk=0; $chunkPath=$null
for($i=0;$i -lt $atoms.Count;$i++){
  if(($i % $ChunkSize) -eq 0){
    $chunkNo++
    $chunkPath=Join-Path $StoreDir ("chunks/atoms_{0:D6}_{1:D6}.jsonl" -f ($i+1),([Math]::Min($i+$ChunkSize,$atoms.Count)))
    if(Test-Path $chunkPath){ Remove-Item $chunkPath -Force }
    $chunkReports += [pscustomObject]@{chunk_no=$chunkNo; path=$chunkPath; start_ordinal=$i+1; end_ordinal=[Math]::Min($i+$ChunkSize,$atoms.Count); count=0}
  }
  $a=$atoms[$i]
  $line=($a|ConvertTo-Json -Depth 50 -Compress)
  [IO.File]::AppendAllText((Join-Path (Get-Location).Path $chunkPath),$line+"`n",$utf8)
  $chunkReports[-1].count=[int]$chunkReports[-1].count+1
  $topic=[string]$a.topic; $dup=[string]$a.duplicate_key
  if(-not $topicSet.ContainsKey($topic)){ $topicSet[$topic]=$true; [IO.File]::AppendAllText((Join-Path (Get-Location).Path $topicIndexPath),((([pscustomObject]@{topic=$topic; atom_ordinal=$i+1; atom_id=$a.atom_id})|ConvertTo-Json -Compress -Depth 10)+"`n"),$utf8) }
  if(-not $dupSet.ContainsKey($dup)){ $dupSet[$dup]=$true; [IO.File]::AppendAllText((Join-Path (Get-Location).Path $dupIndexPath),((([pscustomObject]@{duplicate_key=$dup; atom_ordinal=$i+1; atom_id=$a.atom_id})|ConvertTo-Json -Compress -Depth 10)+"`n"),$utf8) }
  $theme=ParseTheme $a
  if(-not [string]::IsNullOrWhiteSpace($theme)){
    $lvl=[int]$a.level
    if(-not $cursors.ContainsKey($theme)){ $parts=$theme -split '\|'; $cursors[$theme]=[pscustomObject]@{theme_key=$theme; verb=$parts[0]; root=$parts[1]; source_mode=$parts[2]; atom_count=0; last_level=0; next_level=1; last_atom_id=''; last_topic=''; last_duplicate_key=''} }
    $c=$cursors[$theme]; $c.atom_count=[int]$c.atom_count+1
    if($lvl -gt [int]$c.last_level){ $c.last_level=$lvl; $c.next_level=$lvl+1; $c.last_atom_id=[string]$a.atom_id; $c.last_topic=$topic; $c.last_duplicate_key=$dup }
  }
}
$cursorPath=Join-Path $StoreDir 'indexes/theme_cursor_ledger.json'
WriteJson $cursorPath ([pscustomObject]@{schema='incremental_theme_cursor_ledger_v1'; status='PASS'; cursor_count=$cursors.Keys.Count; cursors=@($cursors.Values|Sort-Object theme_key)}) 80
$manifest=[pscustomObject]@{schema='incremental_active_store_manifest_v1'; status='PASS_INCREMENTAL_ACTIVE_STORE_INITIALIZED_V1'; runtime_ready=$false; store_dir=$StoreDir; source_checkpoint_path=$ActiveCheckpointPath; source_checkpoint_sha256=$sourceHash; chunk_size=$ChunkSize; active_atom_count=$atoms.Count; topic_index_count=$topicSet.Keys.Count; duplicate_key_index_count=$dupSet.Keys.Count; theme_cursor_count=$cursors.Keys.Count; current_chunk_path=$chunkReports[-1].path; current_chunk_count=$chunkReports[-1].count; chunk_count=$chunkReports.Count; chunks=@($chunkReports); last_promotion_id='initial_from_legacy_active_checkpoint'; boundary='Parallel lab store; canonical active checkpoint not replaced.'}
WriteJson (Join-Path $StoreDir 'manifest.json') $manifest 80
WriteJson 'operations/reports/INCREMENTAL_ACTIVE_STORE_INITIALIZATION_V1.json' $manifest 80
$md=@('# INCREMENTAL_ACTIVE_STORE_INITIALIZATION_V1','',"Status: $($manifest.status)",'Runtime ready: false','',"Store dir: $StoreDir","Active atoms: $($manifest.active_atom_count)","Chunks: $($manifest.chunk_count)","Topic index: $($manifest.topic_index_count)","Duplicate-key index: $($manifest.duplicate_key_index_count)","Theme cursors: $($manifest.theme_cursor_count)",'','Boundary: parallel lab store; canonical active checkpoint not replaced.')
[IO.File]::WriteAllText((Join-Path (Get-Location).Path 'operations/reports/INCREMENTAL_ACTIVE_STORE_INITIALIZATION_V1.md'),($md -join "`r`n"),$utf8)
Write-Host "INIT_STATUS=$($manifest.status)"
Write-Host "STORE_DIR=$StoreDir"
Write-Host "ACTIVE_ATOMS=$($manifest.active_atom_count)"
Write-Host "CHUNKS=$($manifest.chunk_count)"
Write-Host "TOPIC_INDEX=$($manifest.topic_index_count)"
Write-Host "DUPKEY_INDEX=$($manifest.duplicate_key_index_count)"
Write-Host "THEME_CURSORS=$($manifest.theme_cursor_count)"
Write-Host "RUNTIME_READY=false"