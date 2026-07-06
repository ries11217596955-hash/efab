param([Parameter(Mandatory=$true)][string]$RunDir,[string]$MemoryDir='operations/school/curriculum/candidate_factory/memory')
$ErrorActionPreference='Stop'
$repoRoot=(git rev-parse --show-toplevel).Trim(); Set-Location $repoRoot
$utf8=New-Object System.Text.UTF8Encoding($false)
function WriteJson($p,$o,$d=100){$dir=Split-Path -Parent $p; if($dir){New-Item -ItemType Directory -Force -Path $dir|Out-Null}; [IO.File]::WriteAllText((Join-Path (Get-Location).Path $p),($o|ConvertTo-Json -Depth $d),$utf8)}
$coveragePath=Join-Path $MemoryDir 'coverage_map.json'
$known=@{}
if(Test-Path $coveragePath){ $cov=Get-Content $coveragePath -Raw|ConvertFrom-Json; foreach($p in $cov.root_coverage.PSObject.Properties){ } }
$readyPath=Join-Path $RunDir 'ready_atoms.jsonl'
if(-not (Test-Path $readyPath)){ throw "READY_ATOMS_MISSING: $readyPath" }
$lines=@(Get-Content $readyPath | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
$batches=@{}
$seenTopics=@{}; $batchReports=@(); $batchIndex=0
foreach($line in $lines){
  $a=$line|ConvertFrom-Json
  $bp=[string]$a.source_batch_path
  if(-not $batches.ContainsKey($bp)){ $batches[$bp]=@() }
  $batches[$bp] += $a
}
foreach($bp in ($batches.Keys|Sort-Object)){
  $batchIndex++
  $atoms=@($batches[$bp])
  $newTopics=0; $levels=@{}; $modes=@{}; $roots=@{}
  foreach($a in $atoms){
    $topic=[string]$a.topic
    if(-not $seenTopics.ContainsKey($topic)){ $seenTopics[$topic]=$true; $newTopics++ }
    $levels[[string]$a.level]=$true
    $modes[[string]$a.source_mode]=$true
    if($topic -match '^factory_[^_]+_(?<root>.+?)_candidate_factory_'){ $roots[$Matches.root]=$true }
  }
  $pass=($atoms.Count -gt 0 -and $newTopics -eq $atoms.Count -and $levels.Keys.Count -ge 1 -and $modes.Keys.Count -ge 1)
  $batchReports += [pscustomObject]@{batch_index=$batchIndex; source_batch_path=$bp; atom_count=$atoms.Count; new_topic_count=$newTopics; distinct_level_count=$levels.Keys.Count; distinct_source_mode_count=$modes.Keys.Count; weak_delta_pass=$pass}
}
$fail=@($batchReports|Where-Object {-not $_.weak_delta_pass})
$status=if($fail.Count -eq 0 -and $batchReports.Count -gt 0){'PASS_CODEX_CANDIDATE_FACTORY_BATCH_DELTA_V1'}else{'FAIL_CODEX_CANDIDATE_FACTORY_BATCH_DELTA_V1'}
$report=[pscustomObject]@{schema='codex_candidate_factory_batch_delta_v1'; status=$status; runtime_ready=$false; run_dir=$RunDir; ready_atoms=$lines.Count; batch_count=$batchReports.Count; pass_count=@($batchReports|Where-Object {$_.weak_delta_pass}).Count; fail_count=$fail.Count; boundary='Weak batch delta only: each batch must add unique ready topics and at least one valid level/source-mode surface. Not proof of live learning.'; batches=@($batchReports)}
WriteJson 'operations/reports/CODEX_CANDIDATE_FACTORY_BATCH_DELTA_V1.json' $report 100
$md=@('# CODEX_CANDIDATE_FACTORY_BATCH_DELTA_V1','',"Status: $status",'Runtime ready: false','',"Run dir: $RunDir","Ready atoms: $($report.ready_atoms)","Batches: $($report.batch_count)","Pass: $($report.pass_count)","Fail: $($report.fail_count)",'','Boundary: weak batch delta only.')
[IO.File]::WriteAllText((Join-Path (Get-Location).Path 'operations/reports/CODEX_CANDIDATE_FACTORY_BATCH_DELTA_V1.md'),($md -join "`r`n"),$utf8)
Write-Host "BATCH_DELTA_STATUS=$status"
Write-Host "READY_ATOMS=$($report.ready_atoms)"
Write-Host "BATCHES=$($report.batch_count)"
Write-Host "PASS=$($report.pass_count)"
Write-Host "FAIL=$($report.fail_count)"
Write-Host "RUNTIME_READY=false"
if($status -notlike 'PASS_*'){ exit 1 }