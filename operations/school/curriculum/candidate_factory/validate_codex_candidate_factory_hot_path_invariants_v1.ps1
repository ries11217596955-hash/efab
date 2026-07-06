param(
  [Parameter(Mandatory=$true)][string]$RunDir,
  [string]$MemoryDir='operations/school/curriculum/candidate_factory/memory'
)
$ErrorActionPreference='Stop'
$repoRoot=(git rev-parse --show-toplevel).Trim(); Set-Location $repoRoot
$utf8=New-Object System.Text.UTF8Encoding($false)
function WriteJson($p,$o,$d=100){$dir=Split-Path -Parent $p; if($dir){New-Item -ItemType Directory -Force -Path $dir|Out-Null}; [IO.File]::WriteAllText((Join-Path (Get-Location).Path $p),($o|ConvertTo-Json -Depth $d),$utf8)}
$readyPath=Join-Path $RunDir 'ready_atoms.jsonl'
if(-not (Test-Path $readyPath)){ throw "READY_ATOMS_MISSING: $readyPath" }
$cursorObj=Get-Content (Join-Path $MemoryDir 'theme_cursor_ledger.json') -Raw|ConvertFrom-Json
$topicObj=Get-Content (Join-Path $MemoryDir 'topic_hash_index.json') -Raw|ConvertFrom-Json
$dupObj=Get-Content (Join-Path $MemoryDir 'duplicate_key_hash_index.json') -Raw|ConvertFrom-Json
$cursors=@{}; foreach($c in @($cursorObj.cursors)){ $cursors[[string]$c.theme_key]=$c }
$topicIndex=$topicObj.index; $dupIndex=$dupObj.index
$lines=@(Get-Content $readyPath|Where-Object{-not [string]::IsNullOrWhiteSpace($_)})
$issues=@(); $reservations=@(); $runThemeLevels=@{}; $runTopics=@{}; $runDupKeys=@{}
foreach($line in $lines){
  $a=$line|ConvertFrom-Json
  $topic=[string]$a.topic; $dup=[string]$a.duplicate_key; $theme=[string]$a.theme_key
  if([string]::IsNullOrWhiteSpace($theme)){
    if($a.PSObject.Properties.Name -contains 'learning_key'){ $parts=([string]$a.learning_key) -split '\|'; if($parts.Count -ge 4){ $theme="$($parts[0])|$($parts[1])|$($parts[3])" } }
  }
  if([string]::IsNullOrWhiteSpace($theme)){ $issues += "$($a.atom_id):missing_theme_key"; continue }
  $base=if($cursors.ContainsKey($theme)){[int]$cursors[$theme].next_level}else{1}
  if(-not $runThemeLevels.ContainsKey($theme)){ $runThemeLevels[$theme]=$base }
  $expected=[int]$runThemeLevels[$theme]
  $lvl=[int]$a.level
  if($lvl -ne $expected){ $issues += "$($a.atom_id):level_not_cursor_next expected=$expected actual=$lvl theme=$theme" }
  $runThemeLevels[$theme]=$expected+1
  if($topicIndex.PSObject.Properties.Name -contains $topic){ $issues += "$($a.atom_id):topic_already_in_index" }
  if($dupIndex.PSObject.Properties.Name -contains $dup){ $issues += "$($a.atom_id):duplicate_key_already_in_index" }
  if($runTopics.ContainsKey($topic)){ $issues += "$($a.atom_id):topic_duplicate_in_run" } else { $runTopics[$topic]=$true }
  if($runDupKeys.ContainsKey($dup)){ $issues += "$($a.atom_id):duplicate_key_duplicate_in_run" } else { $runDupKeys[$dup]=$true }
  $reservations += [pscustomObject]@{theme_key=$theme; reserved_level=$lvl; atom_id=$a.atom_id; topic=$topic; duplicate_key=$dup}
}
$status=if($issues.Count -eq 0){'PASS_FACTORY_HOT_PATH_INVARIANTS_V1'}else{'FAIL_FACTORY_HOT_PATH_INVARIANTS_V1'}
$report=[pscustomObject]@{schema='factory_hot_path_invariants_v1'; status=$status; runtime_ready=$false; run_dir=$RunDir; ready_atoms=$lines.Count; reservation_count=$reservations.Count; issue_count=$issues.Count; issues=@($issues); boundary='Hot path only: cursor continuity and hash-index duplicate checks against existing indexes; no active mutation.'}
WriteJson 'operations/reports/FACTORY_HOT_PATH_INVARIANTS_V1.json' $report 100
$md=@('# FACTORY_HOT_PATH_INVARIANTS_V1','',"Status: $status",'Runtime ready: false','',"Run dir: $RunDir","Ready atoms: $($report.ready_atoms)","Reservations: $($report.reservation_count)","Issues: $($report.issue_count)",'','Boundary: hot path invariant only.')
[IO.File]::WriteAllText((Join-Path (Get-Location).Path 'operations/reports/FACTORY_HOT_PATH_INVARIANTS_V1.md'),($md -join "`r`n"),$utf8)
if($status -like 'PASS_*'){
  $logPath=Join-Path $MemoryDir 'cursor_reservation_log.jsonl'
  foreach($r in $reservations){ [IO.File]::AppendAllText((Join-Path (Get-Location).Path $logPath),(($r|ConvertTo-Json -Compress -Depth 20)+"`n"),$utf8) }
}
Write-Host "HOT_PATH_STATUS=$status"
Write-Host "READY_ATOMS=$($report.ready_atoms)"
Write-Host "RESERVATIONS=$($report.reservation_count)"
Write-Host "ISSUES=$($report.issue_count)"
Write-Host "RUNTIME_READY=false"
if($status -notlike 'PASS_*'){ exit 1 }