param(
  [string]$RepoRoot=(Get-Location).Path,
  [int]$KeepLatestCompletedRoot=1,
  [int]$KeepLatestCheckpoints=3,
  [string]$ProofPath='.runtime/school_retention_v1/LAST_CLEANUP_PROOF.json'
)
$ErrorActionPreference='Stop'
if($KeepLatestCompletedRoot -lt 0){throw 'KeepLatestCompletedRoot must be >= 0'}
if($KeepLatestCheckpoints -lt 1){throw 'KeepLatestCheckpoints must be >= 1'}
Set-Location $RepoRoot
$repo=(git rev-parse --show-toplevel).Trim();if(-not$repo){throw 'REPO_ROOT_NOT_FOUND'};Set-Location $repo
$active='.runtime/active_compact_semantic_memory_v1';if(-not(Test-Path $active)){throw 'ACTIVE_MEMORY_ROOT_MISSING'}
$all=Get-CimInstance Win32_Process
$busy=@($all|Where-Object{$_.ProcessId-ne$PID-and$_.CommandLine-and($_.CommandLine-match'(?i)[\\/]run_agent_school\.ps1(\s|$)'-or$_.CommandLine-match'(?i)memory_commit_controller_v1\.ps1(\s|$)'-or$_.CommandLine-match'(?i)absorb_atom_file_via_digest_pipeline_v1\.ps1(\s|$)')})
if($busy.Count){throw ('BLOCKED_PROTECTED_RUNTIME:'+ $busy.Count)}
$beforeMem=[ordered]@{};foreach($f in @('manifest.json','index.json','cells.jsonl')){$p=Join-Path $active $f;if(-not(Test-Path $p)){throw ('ACTIVE_MEMORY_FILE_MISSING:'+ $f)};$beforeMem[$f]=(Get-FileHash $p -Algorithm SHA256).Hash}
$root='.runtime/canonical_exact_count_cycle';$proofRoot='operations/reports';$eligible=@();$keptUnproven=@()
if(Test-Path $root){
  $proofFiles=@(Get-ChildItem $proofRoot -File -Filter 'CANONICAL_EXACT_COUNT_CYCLE_RUN_*.json' -ErrorAction SilentlyContinue)
  foreach($d in @(Get-ChildItem $root -Directory -Force)){
    $match=$null
    foreach($pf in $proofFiles){try{$j=Get-Content $pf.FullName -Raw|ConvertFrom-Json;if([string]$j.run_id-eq$d.Name){$match=[pscustomobject]@{file=$pf;json=$j};break}}catch{}}
    if($match -and [string]$match.json.status -match '^PASS_CANONICAL_EXACT_COUNT_CYCLE_(TEST|LIVE)_V1$' -and -not[string]::IsNullOrWhiteSpace([string]$match.json.finalizer_status)){
      $fs=@(Get-ChildItem $d.FullName -File -Recurse -Force -ErrorAction SilentlyContinue);$bytes=[int64](($fs|Measure-Object Length -Sum).Sum)
      $eligible+=[pscustomobject]@{dir=$d;proof=$match.file.FullName;proof_sha=(Get-FileHash $match.file.FullName -Algorithm SHA256).Hash;status=[string]$match.json.status;finalizer=[string]$match.json.finalizer_status;bytes=$bytes;files=$fs.Count}
    } else {$keptUnproven+=$d.FullName}
  }
}
$eligible=@($eligible|Sort-Object {$_.dir.LastWriteTimeUtc} -Descending)
$keep=@($eligible|Select-Object -First $KeepLatestCompletedRoot);$delete=@($eligible|Select-Object -Skip $KeepLatestCompletedRoot);$deleted=@()
foreach($x in $delete){
  $full=[IO.Path]::GetFullPath($x.dir.FullName);$guard=[IO.Path]::GetFullPath((Join-Path $repo '.runtime\canonical_exact_count_cycle'))
  if(-not$full.StartsWith($guard+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)){throw ('REFUSING_OUTSIDE_EXACT_ROOT:'+ $full)}
  Remove-Item -LiteralPath $full -Recurse -Force
  $deleted+=[ordered]@{run_id=$x.dir.Name;path=$full;bytes=[int64]$x.bytes;files=$x.files;canonical_proof=$x.proof;canonical_proof_sha256=$x.proof_sha;status=$x.status;finalizer_status=$x.finalizer}
}
$checkpointCleaner='operations/autonomous_inner_motor/cleanup_compact_memory_intake_checkpoints_v1.ps1';if(-not(Test-Path $checkpointCleaner)){throw 'CHECKPOINT_CLEANER_MISSING'}
$checkpointProof='.runtime/school_retention_v1/CHECKPOINT_RETENTION_PROOF.json'
& $checkpointCleaner -RepoRoot $repo -KeepLatest $KeepLatestCheckpoints -ProofPath $checkpointProof | Out-Null
if($LASTEXITCODE -ne 0){throw 'CHECKPOINT_RETENTION_FAILED'}
$cp=Get-Content $checkpointProof -Raw|ConvertFrom-Json;if([string]$cp.status-ne'PASS_COMPACT_MEMORY_INTAKE_CHECKPOINT_RETENTION_V1'){throw ('CHECKPOINT_RETENTION_NOT_PASS:'+ [string]$cp.status)}
$afterMem=[ordered]@{};foreach($f in @('manifest.json','index.json','cells.jsonl')){$p=Join-Path $active $f;$afterMem[$f]=(Get-FileHash $p -Algorithm SHA256).Hash;if($afterMem[$f]-ne$beforeMem[$f]){throw ('ACTIVE_MEMORY_CHANGED:'+ $f)}}
$proof=[ordered]@{schema='school_runtime_retention_v1';status='PASS_SCHOOL_RUNTIME_RETENTION_V1';checked_at=(Get-Date).ToString('o');keep_latest_completed_root=$KeepLatestCompletedRoot;keep_latest_checkpoints=$KeepLatestCheckpoints;completed_roots_before=$eligible.Count;completed_roots_deleted=$deleted.Count;reclaimed_exact_bytes=[int64](($deleted|ForEach-Object{[int64]$_['bytes']}|Measure-Object -Sum).Sum);kept_completed_roots=@($keep|ForEach-Object{$_.dir.FullName});kept_unproven_roots=@($keptUnproven);deleted_completed_roots=$deleted;checkpoint_retention_status=[string]$cp.status;checkpoint_deleted_count=[int]$cp.deleted_count;checkpoint_reclaimed_bytes=[int64]$cp.reclaimed_bytes;active_memory_before=$beforeMem;active_memory_after=$afterMem;boundary='Runs only with protected runtime absent; deletes only proof-backed finalized exact-count roots beyond retention limit and old intake checkpoints; never deletes active memory or unproven/incomplete roots.'}
$dir=Split-Path $ProofPath -Parent;if($dir){New-Item -ItemType Directory -Force -Path $dir|Out-Null};$proof|ConvertTo-Json -Depth 12|Set-Content $ProofPath -Encoding UTF8
Write-Host ('STATUS='+$proof.status);Write-Host ('EXACT_DELETED='+$proof.completed_roots_deleted);Write-Host ('CHECKPOINT_DELETED='+$proof.checkpoint_deleted_count)
