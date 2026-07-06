param(
  [string]$RoutePointerPath='operations/school/curriculum/incremental_active_store/ACTIVE_REPO_BODY_ROUTE_POINTER_V1.json',
  [string]$ReplayLedgerPath='operations/school/curriculum/incremental_active_store/ACTIVE_REPO_BODY_ROUTE_REPLAY_LEDGER_V1.json',
  [string]$MemoryDir='operations/school/curriculum/candidate_factory/memory'
)
$ErrorActionPreference='Stop'
$repoRoot=(git rev-parse --show-toplevel).Trim(); Set-Location $repoRoot
$utf8=New-Object System.Text.UTF8Encoding($false)
function WriteJson($p,$o,$d=100){$dir=Split-Path -Parent $p; if($dir){New-Item -ItemType Directory -Force -Path $dir|Out-Null}; [IO.File]::WriteAllText((Join-Path (Get-Location).Path $p),($o|ConvertTo-Json -Depth $d),$utf8)}
$route=Get-Content $RoutePointerPath -Raw|ConvertFrom-Json
if([string]$route.active_source -ne 'incremental_active_store_v1'){ throw "UNSUPPORTED_ACTIVE_SOURCE_FOR_FACTORY_ROUTE_SYNC: $($route.active_source)" }
$store=[string]$route.store_dir
$manifestPath=Join-Path $store 'manifest.json'
if((-not (Test-Path $manifestPath)) -or ([int](Get-Content $manifestPath -Raw|ConvertFrom-Json).active_atom_count -ne [int]$route.routed_active_count)){
  & operations/school/curriculum/incremental_active_store/rebuild_incremental_active_store_from_route_replay_v1.ps1 -ReplayLedgerPath $ReplayLedgerPath -Force | Out-Host
}
$manifest=Get-Content $manifestPath -Raw|ConvertFrom-Json
if([int]$manifest.active_atom_count -ne [int]$route.routed_active_count){ throw 'ROUTE_STORE_MANIFEST_COUNT_MISMATCH_AFTER_REBUILD' }
New-Item -ItemType Directory -Force -Path $MemoryDir | Out-Null
$topicIndex=@{}; foreach($line in Get-Content (Join-Path $store 'indexes/topic_index.jsonl')){ if([string]::IsNullOrWhiteSpace($line)){continue}; $r=$line|ConvertFrom-Json; $topicIndex[[string]$r.topic]=[pscustomObject]@{atom_id=$r.atom_id; topic=$r.topic; atom_ordinal=$r.atom_ordinal} }
$dupIndex=@{}; foreach($line in Get-Content (Join-Path $store 'indexes/duplicate_key_index.jsonl')){ if([string]::IsNullOrWhiteSpace($line)){continue}; $r=$line|ConvertFrom-Json; $dupIndex[[string]$r.duplicate_key]=[pscustomObject]@{atom_id=$r.atom_id; duplicate_key=$r.duplicate_key; atom_ordinal=$r.atom_ordinal} }
$cursorObj=Get-Content (Join-Path $store 'indexes/theme_cursor_ledger.json') -Raw|ConvertFrom-Json
$cursorList=@($cursorObj.cursors)
WriteJson (Join-Path $MemoryDir 'topic_hash_index.json') ([pscustomObject]@{schema='topic_hash_index_v1'; status='PASS'; source='incremental_active_store_v1'; count=$topicIndex.Keys.Count; index=$topicIndex}) 100
WriteJson (Join-Path $MemoryDir 'duplicate_key_hash_index.json') ([pscustomObject]@{schema='duplicate_key_hash_index_v1'; status='PASS'; source='incremental_active_store_v1'; count=$dupIndex.Keys.Count; index=$dupIndex}) 100
WriteJson (Join-Path $MemoryDir 'theme_cursor_ledger.json') ([pscustomObject]@{schema='theme_cursor_ledger_v1'; status='PASS'; source='incremental_active_store_v1'; generated_at=(Get-Date).ToString('o'); cursor_count=$cursorList.Count; cursors=@($cursorList)}) 100
$report=[pscustomObject]@{
  schema='factory_memory_from_active_route_v1'
  status='PASS_FACTORY_MEMORY_FROM_ACTIVE_ROUTE_V1'
  runtime_ready=$false
  active_source=$route.active_source
  store_dir=$store
  routed_active_count=$route.routed_active_count
  manifest_active_count=$manifest.active_atom_count
  topic_index_count=$topicIndex.Keys.Count
  duplicate_key_index_count=$dupIndex.Keys.Count
  theme_cursor_count=$cursorList.Count
  legacy_checkpoint_used=$false
  boundary='Factory generation memory synced from active route; no absorption; no live proof.'
}
WriteJson (Join-Path $MemoryDir 'factory_memory_from_active_route_report.json') $report 100
WriteJson 'operations/reports/FACTORY_MEMORY_FROM_ACTIVE_ROUTE_V1.json' $report 100
$md=@('# FACTORY_MEMORY_FROM_ACTIVE_ROUTE_V1','',"Status: $($report.status)",'Runtime ready: false','',"Active source: $($report.active_source)","Routed active count: $($report.routed_active_count)","Manifest active count: $($report.manifest_active_count)","Topic index: $($report.topic_index_count)","Duplicate-key index: $($report.duplicate_key_index_count)","Theme cursors: $($report.theme_cursor_count)","Legacy checkpoint used: false",'','Boundary: sync only; no absorption.')
[IO.File]::WriteAllText((Join-Path (Get-Location).Path 'operations/reports/FACTORY_MEMORY_FROM_ACTIVE_ROUTE_V1.md'),($md -join "`r`n"),$utf8)
Write-Host "FACTORY_ROUTE_MEMORY_STATUS=$($report.status)"
Write-Host "ACTIVE_SOURCE=$($report.active_source)"
Write-Host "ROUTED_ACTIVE_COUNT=$($report.routed_active_count)"
Write-Host "TOPIC_INDEX=$($report.topic_index_count)"
Write-Host "DUPKEY_INDEX=$($report.duplicate_key_index_count)"
Write-Host "THEME_CURSORS=$($report.theme_cursor_count)"
Write-Host "LEGACY_CHECKPOINT_USED=false"
Write-Host "RUNTIME_READY=false"