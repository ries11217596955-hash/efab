param(
  [string]$ParallelRunRoot='.runtime/parallel_school_aimo_live/school_aimo_parallel_20260715_211514',
  [string]$SchoolRunDir='.runtime/canonical_exact_count_cycle/canonical_exact_count_cycle_real_2000_20260715_211515'
)
$ErrorActionPreference='Stop'
$errors=New-Object System.Collections.Generic.List[string]
function Add-Err([string]$Message){ $script:errors.Add($Message) | Out-Null }
function Write-CleanJson([string]$Path,$Obj,[int]$Depth=50){
  $dir=Split-Path $Path -Parent
  if($dir){ New-Item -ItemType Directory -Force -Path $dir | Out-Null }
  $json=$Obj | ConvertTo-Json -Depth $Depth
  $lines=@($json -split "`r?`n" | ForEach-Object { $_.TrimEnd() })
  while($lines.Count -gt 0 -and $lines[$lines.Count-1] -eq ''){ if($lines.Count -eq 1){$lines=@();break}; $lines=@($lines[0..($lines.Count-2)]) }
  $utf8NoBom=New-Object System.Text.UTF8Encoding($false)
  [System.IO.File]::WriteAllText((Join-Path (Get-Location).Path $Path),(($lines -join "`n") + "`n"),$utf8NoBom)
}
function Read-Json([string]$Path){
  if(-not(Test-Path $Path)){ Add-Err "missing:$Path"; return $null }
  try { return (Get-Content $Path -Raw | ConvertFrom-Json) } catch { Add-Err "bad_json:${Path}:$($_.Exception.Message)"; return $null }
}
function Parse-DateSafe($s){ try { return [datetime]::Parse([string]$s) } catch { return $null } }
function Get-CellsHash($MemoryState){
  if(-not $MemoryState){ return $null }
  if(-not $MemoryState.before){ return $null }
  if(-not $MemoryState.before.files){ return $null }
  $files=@($MemoryState.before.files)
  $cells=$files | Where-Object { [string]$_.path -like '*cells.jsonl' } | Select-Object -First 1
  if($cells){ return [string]$cells.sha256 }
  return $null
}
function Get-ManifestHash($MemoryState){
  if(-not $MemoryState){ return $null }
  if(-not $MemoryState.before){ return $null }
  if(-not $MemoryState.before.files){ return $null }
  $files=@($MemoryState.before.files)
  $m=$files | Where-Object { [string]$_.path -like '*manifest.json' } | Select-Object -First 1
  if($m){ return [string]$m.sha256 }
  return $null
}
$loopPath=Join-Path $ParallelRunRoot 'aimo_loop_status.json'
$loop=Read-Json $loopPath
$schoolReports=@()
if(Test-Path $SchoolRunDir){ $schoolReports=@(Get-ChildItem $SchoolRunDir -File -Filter 'consumer_*_report.json' | Sort-Object Name) } else { Add-Err "missing_school_dir:$SchoolRunDir" }
$schoolEvents=@()
foreach($f in $schoolReports){
  $j=Read-Json $f.FullName
  if($j){
    $batch=$null
    if($j.consumed_batches -and @($j.consumed_batches).Count -gt 0){ $batch=@($j.consumed_batches)[0] }
    $schoolEvents += [ordered]@{
      report=$f.FullName.Replace((Resolve-Path '.').Path+'\','').Replace('\','/')
      created_at=$j.created_at
      created_dt=Parse-DateSafe $j.created_at
      micro_batch_id=if($batch){$batch.micro_batch_id}else{$null}
      candidate_count=if($batch){$batch.candidate_count}else{$null}
      accepted_count=if($batch){$batch.accepted_count}else{$null}
      memory_changed=$j.memory_changed
      memory_before=$j.memory_before
      memory_after=$j.memory_after
    }
  }
}
$aimoEvents=@()
if($loop){
  foreach($e in @($loop.events)){
    $proofPath=[string]$e.proof_path
    $proof=$null
    if(-not [string]::IsNullOrWhiteSpace($proofPath) -and (Test-Path $proofPath)){ $proof=Read-Json $proofPath }
    $cellsHash=$null; $manifestHash=$null
    if($proof){
      $cellsHash=Get-CellsHash $proof.memory_state
      $manifestHash=Get-ManifestHash $proof.memory_state
    }
    $aimoEvents += [ordered]@{
      iteration=$e.iteration
      started_at=$e.started_at
      started_dt=Parse-DateSafe $e.started_at
      finished_at=$e.finished_at
      proof_path=$proofPath
      ingestion_mode=$e.ingestion_mode
      busy=$e.busy
      memory_changed_by_agent=$e.memory_changed
      memory_cells_before=$cellsHash
      memory_manifest_before=$manifestHash
    }
  }
}
$schoolChanged=@($schoolEvents | Where-Object { $_.memory_changed -eq $true })
$aimoWithHashes=@($aimoEvents | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_['memory_cells_before']) })
$uniqueAimoHashes=@($aimoWithHashes | ForEach-Object { $_['memory_cells_before'] } | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) } | Sort-Object -Unique)
$matches=@(); $misses=@()
foreach($s in $schoolChanged){
  $target=[string]$s.memory_after.cells
  $later=@($aimoWithHashes | Where-Object { $_['started_dt'] -and $s.created_dt -and $_['started_dt'] -gt $s.created_dt })
  $exact=@($later | Where-Object { ([string]$_['memory_cells_before']).ToUpperInvariant() -eq $target.ToUpperInvariant() }) | Select-Object -First 1
  if($exact){
    $matches += [ordered]@{ micro_batch_id=$s.micro_batch_id; school_created_at=$s.created_at; target_cells=$target; aimo_iteration=$exact['iteration']; aimo_started_at=$exact['started_at']; result='EXACT_HASH_OBSERVED_BY_LATER_AIMO_CYCLE' }
  } else {
    $firstLater=@($later | Select-Object -First 1)
    $misses += [ordered]@{ micro_batch_id=$s.micro_batch_id; school_created_at=$s.created_at; target_cells=$target; later_aimo_exists=($null -ne $firstLater); first_later_aimo_iteration=if($firstLater){$firstLater['iteration']}else{$null}; first_later_aimo_cells=if($firstLater){$firstLater['memory_cells_before']}else{$null}; result='NOT_EXACTLY_OBSERVED_IN_AVAILABLE_TRACE' }
  }
}
$status='FAIL_AIMO_FRESH_MEMORY_SIGNAL_AFTER_SCHOOL_BATCH_V1'
if($errors.Count -eq 0){
  if($schoolChanged.Count -gt 0 -and $uniqueAimoHashes.Count -gt 1 -and $matches.Count -gt 0){ $status='PARTIAL_AIMO_FRESH_MEMORY_SIGNAL_OBSERVED_V1' }
  if($schoolChanged.Count -gt 0 -and $matches.Count -eq $schoolChanged.Count){ $status='PASS_AIMO_FRESH_MEMORY_SIGNAL_AFTER_EACH_SCHOOL_BATCH_V1' }
}
$out=[ordered]@{
  schema='aimo_fresh_memory_signal_after_school_batch_validation_v1'
  status=$status
  checked_at=(Get-Date).ToString('o')
  parallel_run_root=$ParallelRunRoot
  school_run_dir=$SchoolRunDir
  school_changed_batches=$schoolChanged.Count
  aimo_iterations=@($aimoEvents).Count
  aimo_iterations_with_memory_hash=@($aimoWithHashes).Count
  aimo_unique_memory_hashes=@($uniqueAimoHashes).Count
  exact_batch_matches=@($matches).Count
  missing_exact_matches=@($misses).Count
  matches=@($matches)
  misses=@($misses)
  interpretation=if($status -like 'PARTIAL*'){'Existing trace proves AIMO observed changing memory during School, but does not prove exact post-batch observation after every batch. Need explicit fresh-memory signal in next live test.'}elseif($status -like 'PASS*'){'Existing trace proves every School batch hash was observed by a later AIMO cycle.'}else{'Fresh-memory signal not proven from available trace.'}
  errors=@($errors)
}
$proofPath='tests/self_development/AIMO_FRESH_MEMORY_SIGNAL_AFTER_SCHOOL_BATCH_V1_PROOF.json'
Write-CleanJson $proofPath $out 80
Write-Host "STATUS=$status"
Write-Host "SCHOOL_CHANGED_BATCHES=$($schoolChanged.Count)"
Write-Host "AIMO_ITERATIONS=$(@($aimoEvents).Count)"
Write-Host "AIMO_HASH_EVENTS=$(@($aimoWithHashes).Count)"
Write-Host "AIMO_UNIQUE_MEMORY_HASHES=$(@($uniqueAimoHashes).Count)"
Write-Host "EXACT_BATCH_MATCHES=$(@($matches).Count)"
Write-Host "MISSING_EXACT_MATCHES=$(@($misses).Count)"
Write-Host "PROOF_OUT=$proofPath"
if($status -like 'FAIL*'){ exit 1 }
