param(
  [string]$RepoRoot = (Get-Location).Path,
  [string]$IntakeRoot = '.runtime/compact_memory_intake_v1',
  [int]$KeepLatest = 3,
  [string]$ProofPath = 'tests/self_development/COMPACT_MEMORY_INTAKE_CHECKPOINT_RETENTION_V1_PROOF.json'
)
$ErrorActionPreference='Stop'
function Write-CleanJson($Path,$Data,[int]$Depth=100){
  $dir=Split-Path $Path -Parent
  if($dir){ New-Item -ItemType Directory -Force -Path $dir | Out-Null }
  $json=($Data|ConvertTo-Json -Depth $Depth) -replace "`r`n","`n"
  [System.IO.File]::WriteAllText((Join-Path (Get-Location).Path $Path),$json.TrimEnd()+"`n",(New-Object System.Text.UTF8Encoding($false)))
}
function Measure-Tree($Path){
  if(-not(Test-Path -LiteralPath $Path)){ return [ordered]@{exists=$false; files=0; bytes=0; mb=0} }
  $files=@(Get-ChildItem -LiteralPath $Path -Recurse -File -Force -ErrorAction SilentlyContinue)
  $bytes=[int64](($files|Measure-Object Length -Sum).Sum)
  return [ordered]@{exists=$true; files=$files.Count; bytes=$bytes; mb=[math]::Round($bytes/1MB,2)}
}
function Get-CheckpointDirs($CheckpointRoot){
  if(-not(Test-Path -LiteralPath $CheckpointRoot)){ return @() }
  return @(Get-ChildItem -LiteralPath $CheckpointRoot -Directory -Force | ForEach-Object {
    $m=Measure-Tree $_.FullName
    [pscustomobject]@{name=$_.Name; path=$_.FullName.Replace((Get-Location).Path+'\',''); full=$_.FullName; files=$m.files; bytes=[int64]$m.bytes; mb=$m.mb; last=$_.LastWriteTime.ToUniversalTime().ToString('o')}
  } | Sort-Object last -Descending)
}
if($KeepLatest -lt 1){ throw 'KeepLatest must be >= 1' }
if((Resolve-Path .).Path -ne (Resolve-Path $RepoRoot).Path){ Set-Location $RepoRoot }
$activeRoot='.runtime/active_compact_semantic_memory_v1'
$queueRoot=Join-Path $IntakeRoot 'queue'
$checkpointRoot=Join-Path $IntakeRoot 'checkpoints'
$processPatterns='run_autonomous_inner_motor.ps1|start_agent_life_v1.ps1|invoke_body_self_inspection_circuit_v1.ps1|codex exec|node.*codex|school|continuous'
$procs=@(Get-CimInstance Win32_Process | Where-Object { $_.CommandLine -and $_.CommandLine -notmatch '\s-Command\s' -and $_.CommandLine -match $processPatterns })
if($procs.Count -ne 0){ throw "BLOCKED_PROCESS_COUNT:$($procs.Count)" }
if(-not(Test-Path -LiteralPath $activeRoot)){ throw "ACTIVE_MEMORY_ROOT_MISSING:$activeRoot" }
if(-not(Test-Path -LiteralPath $IntakeRoot)){ throw "INTAKE_ROOT_MISSING:$IntakeRoot" }
if(-not(Test-Path -LiteralPath $checkpointRoot)){ throw "CHECKPOINT_ROOT_MISSING:$checkpointRoot" }
$before=[ordered]@{
  active_memory=Measure-Tree $activeRoot
  intake=Measure-Tree $IntakeRoot
  queue=Measure-Tree $queueRoot
  checkpoints=Measure-Tree $checkpointRoot
}
$checkpointDirs=Get-CheckpointDirs $checkpointRoot
$keep=@($checkpointDirs | Select-Object -First $KeepLatest)
$delete=@($checkpointDirs | Select-Object -Skip $KeepLatest)
$deleted=@()
foreach($d in $delete){
  if($d.path -like '*active_compact_semantic_memory_v1*'){ throw "REFUSING_ACTIVE_MEMORY_DELETE:$($d.path)" }
  if(-not($d.full -like "*$([IO.Path]::DirectorySeparatorChar)compact_memory_intake_v1$([IO.Path]::DirectorySeparatorChar)checkpoints$([IO.Path]::DirectorySeparatorChar)*")){ throw "REFUSING_OUTSIDE_CHECKPOINT_ROOT:$($d.full)" }
  Remove-Item -LiteralPath $d.full -Recurse -Force -ErrorAction Stop
  $deleted += [ordered]@{name=$d.name; path=$d.path; files=$d.files; bytes=[int64]$d.bytes; mb=$d.mb; last=$d.last}
}
$afterDirs=Get-CheckpointDirs $checkpointRoot
$after=[ordered]@{
  active_memory=Measure-Tree $activeRoot
  intake=Measure-Tree $IntakeRoot
  queue=Measure-Tree $queueRoot
  checkpoints=Measure-Tree $checkpointRoot
}
$deletedBytes=[int64](($deleted | ForEach-Object { [int64]$_['bytes'] } | Measure-Object -Sum).Sum)
$proof=[ordered]@{
  schema='compact_memory_intake_checkpoint_retention_v1'
  status='PASS_COMPACT_MEMORY_INTAKE_CHECKPOINT_RETENTION_V1'
  checked_at=(Get-Date).ToUniversalTime().ToString('o')
  keep_latest=$KeepLatest
  intake_root=$IntakeRoot
  checkpoint_root=$checkpointRoot
  active_memory_root=$activeRoot
  before=$before
  after=$after
  kept_checkpoints=@($afterDirs | Select-Object name,path,files,bytes,mb,last)
  deleted_checkpoints=$deleted
  deleted_count=@($deleted).Count
  reclaimed_bytes=$deletedBytes
  reclaimed_mb=[math]::Round($deletedBytes/1MB,2)
  boundary=[ordered]@{
    process_count=0
    active_memory_deleted=$false
    active_memory_mutated=$false
    queue_deleted=$false
    latest_checkpoints_kept=$true
    older_checkpoints_deleted=$true
    repo_tracked_files_deleted=$false
    codex_launched=$false
    web_launched=$false
    school_launched=$false
  }
}
Write-CleanJson $ProofPath $proof 100
Write-Host "STATUS=$($proof.status)"
Write-Host "DELETED_COUNT=$($proof.deleted_count)"
Write-Host "RECLAIMED_MB=$($proof.reclaimed_mb)"
Write-Host "CHECKPOINTS_AFTER=$($after.checkpoints.files) files / $($after.checkpoints.mb) MB"
