param(
  [Parameter(Mandatory=$true)][string]$RunDir,
  [int]$MaxReadyBatches=0
)
$ErrorActionPreference="Stop"
$repoRoot=(git rev-parse --show-toplevel).Trim(); Set-Location $repoRoot
$utf8=New-Object System.Text.UTF8Encoding($false)
function WriteJson($p,$o,$d=80){$dir=Split-Path -Parent $p; if($dir){New-Item -ItemType Directory -Force -Path $dir|Out-Null}; [IO.File]::WriteAllText((Join-Path (Get-Location).Path $p),($o|ConvertTo-Json -Depth $d),$utf8)}
function ReadJson($p){ return Get-Content $p -Raw | ConvertFrom-Json }
function IsGenericOrPlaceholder($obj){
  $joined=@($obj.topic,$obj.objective,$obj.new_knowledge,$obj.exercise,$obj.expected_behavior,$obj.negative_trap,$obj.validator_hint,$obj.behavior_use_proof_target,$obj.return_to_parent) -join ' '
  if($joined -match '(?i)same-as-above|lorem|TODO'){ return $true }
  $topic=([string]$obj.topic).Trim().ToLowerInvariant()
  if($topic -in @('placeholder','generic','filler','todo','same-as-above')){ return $true }
  if($topic -match '^(placeholder|generic|filler)[_\- ]?(text|candidate|lesson)?$'){ return $true }
  return $false
}
if(-not (Test-Path $RunDir)){ throw "RUN_DIR_MISSING: $RunDir" }
$runName=(Split-Path $RunDir -Leaf)
$outDir="operations/reports/streaming_absorption/$runName"
New-Item -ItemType Directory -Force -Path $outDir | Out-Null
$candidateFiles=@(Get-ChildItem $RunDir -Recurse -File -Filter candidates.jsonl | Sort-Object FullName)
if($MaxReadyBatches -gt 0){ $candidateFiles=@($candidateFiles | Select-Object -First $MaxReadyBatches) }
$seenStreamKeys=@{}
$batchReports=@(); $readyAtoms=@(); $quarantineAtoms=@(); $contractRejected=@()
$processedTotal=0; $contractAcceptedTotal=0; $contractRejectedTotal=0
$batchIndex=0
foreach($file in $candidateFiles){
  $batchIndex++
  $rel=$file.FullName.Substring((Get-Location).Path.Length+1)
  & operations/school/curriculum/codex_contract/validate_codex_curriculum_batch_v1.ps1 -BatchPath $rel | Out-Host
  $validation=ReadJson 'operations/reports/CODEX_CURRICULUM_CONTRACT_V1_VALIDATION.json'
  $batchOutDir="$outDir/batch_$('{0:D4}' -f $batchIndex)"
  New-Item -ItemType Directory -Force -Path $batchOutDir | Out-Null
  WriteJson "$batchOutDir/contract_validation.json" $validation 80
  $objects=@(); $lineNo=0
  foreach($line in Get-Content $file.FullName){
    if([string]::IsNullOrWhiteSpace($line)){ continue }
    $lineNo++
    try{ $obj=$line | ConvertFrom-Json; $obj | Add-Member -NotePropertyName _line -NotePropertyValue $lineNo -Force; $objects += $obj }catch{}
  }
  $acceptedLines=@{}; foreach($a in @($validation.accepted)){ $acceptedLines[[int]$a.line]=$true }
  $rejectedLines=@{}; foreach($r in @($validation.rejected)){ $rejectedLines[[int]$r.line]=$r }
  $batchReady=@(); $batchQuarantine=@(); $batchContractRejected=@()
  foreach($obj in $objects){
    $line=[int]$obj._line
    if($rejectedLines.ContainsKey($line)){
      $batchContractRejected += [pscustomObject]@{line=$line; candidate_id=$obj.candidate_id; topic=$obj.topic; reason='contract_rejected'; failures=@($rejectedLines[$line].failures)}
      continue
    }
    if(-not $acceptedLines.ContainsKey($line)){ continue }
    $topic=[string]$obj.topic
    $streamKey=if($obj.duplicate_key){[string]$obj.duplicate_key}elseif($obj.learning_key){[string]$obj.learning_key}else{[string]$obj.candidate_id}
    $reason=$null
    if($seenStreamKeys.ContainsKey($streamKey)){ $reason='duplicate_learning_key_stream' }
    elseif(IsGenericOrPlaceholder $obj){ $reason='generic_or_placeholder_stream' }
    $atom=[pscustomObject]@{
      atom_id=("codex.curriculum.stream.atom.{0:D4}.{1}.v1" -f ($readyAtoms.Count + $quarantineAtoms.Count + 1), (($topic -replace '[^A-Za-z0-9_\-]','_').ToLowerInvariant()))
      source_candidate_id=$obj.candidate_id
      source_line=$line
      topic=$topic
      level=$obj.level
      source_mode=$obj.source_mode
      objective=$obj.objective
      expected_behavior=$obj.expected_behavior
      exercise=$obj.exercise
      negative_trap=$obj.negative_trap
      validator_hint=$obj.validator_hint
      behavior_use_proof_target=$obj.behavior_use_proof_target
      return_to_parent=$obj.return_to_parent
      duplicate_key=$obj.duplicate_key
      source_batch_path=$rel
    }
    foreach($extra in @('theme_key','learning_key','prerequisite_key','ladder_step','batch_delta_target','factory_memory_historical_count','cursor_previous_level','cursor_reserved_level')){
      if($obj.PSObject.Properties.Name -contains $extra){
        $atom | Add-Member -NotePropertyName $extra -NotePropertyValue $obj.$extra -Force
      }
    }
    if($reason){
      $qAtom=$atom | Select-Object *
      $qAtom | Add-Member -NotePropertyName quarantine_reason -NotePropertyValue $reason -Force
      $batchQuarantine += $qAtom
      $quarantineAtoms += $qAtom
    } else {
      $batchReady += $atom
      $readyAtoms += $atom
      $seenStreamKeys[$streamKey]=$true
    }
  }
  $processedTotal += [int]$validation.processed_count
  $contractAcceptedTotal += [int]$validation.accepted_count
  $contractRejectedTotal += [int]$validation.rejected_count
  $contractRejected += @($batchContractRejected)
  $batchReport=[pscustomObject]@{
    batch_index=$batchIndex
    batch_path=$rel
    status='PASS_STREAMING_BATCH_ABSORPTION_V1'
    processed=$validation.processed_count
    contract_accepted=$validation.accepted_count
    contract_rejected=$validation.rejected_count
    ready_atoms=$batchReady.Count
    stream_quarantined=$batchQuarantine.Count
    contract_rejected_items=@($batchContractRejected)
    stream_quarantined_items=@($batchQuarantine)
    boundary='Per-batch school-to-absorption lane only. Does not mutate active memory.'
  }
  WriteJson "$batchOutDir/streaming_absorption_batch_report.json" $batchReport 80
  $batchReports += $batchReport
  $checkpoint=[pscustomObject]@{schema='codex_curriculum_streaming_absorption_checkpoint_v1'; status='RUNNING'; run_dir=$RunDir; batches_processed=$batchReports.Count; processed_total=$processedTotal; contract_accepted_total=$contractAcceptedTotal; contract_rejected_total=$contractRejectedTotal; ready_atoms_total=$readyAtoms.Count; stream_quarantined_total=$quarantineAtoms.Count; active_memory_mutated=$false; updated_at=(Get-Date).ToString('o')}
  WriteJson "$outDir/checkpoint.json" $checkpoint 80
}
$status=if($batchReports.Count -gt 0 -and $readyAtoms.Count -gt 0){'PASS_STREAMING_SCHOOL_TO_ABSORPTION_PIPELINE_V1'}else{'FAIL_STREAMING_SCHOOL_TO_ABSORPTION_PIPELINE_V1'}
$report=[pscustomObject]@{
  schema='streaming_school_to_absorption_pipeline_v1'
  status=$status
  runtime_ready=$false
  run_dir=$RunDir
  candidate_batches_seen=$candidateFiles.Count
  batches_processed=$batchReports.Count
  processed_total=$processedTotal
  contract_accepted_total=$contractAcceptedTotal
  contract_rejected_total=$contractRejectedTotal
  ready_atoms_total=$readyAtoms.Count
  stream_quarantined_total=$quarantineAtoms.Count
  active_memory_mutated=$false
  ready_lane_path="$outDir/ready_atoms.jsonl"
  quarantine_path="$outDir/quarantined_atoms.jsonl"
  contract_rejected_path="$outDir/contract_rejected.jsonl"
  batch_reports=@($batchReports)
  boundary='Streaming school-to-absorption lane. Processes each ready batch independently; does not wait for full N; does not promote active memory.'
}
WriteJson 'operations/reports/STREAMING_SCHOOL_TO_ABSORPTION_PIPELINE_V1.json' $report 100
$readyAtoms | ForEach-Object { ($_ | ConvertTo-Json -Depth 30 -Compress) } | Set-Content -Encoding utf8 "$outDir/ready_atoms.jsonl"
$quarantineAtoms | ForEach-Object { ($_ | ConvertTo-Json -Depth 30 -Compress) } | Set-Content -Encoding utf8 "$outDir/quarantined_atoms.jsonl"
$contractRejected | ForEach-Object { ($_ | ConvertTo-Json -Depth 30 -Compress) } | Set-Content -Encoding utf8 "$outDir/contract_rejected.jsonl"
$md=@('# STREAMING_SCHOOL_TO_ABSORPTION_PIPELINE_V1','',"Status: $status",'Runtime ready: false','',"Run dir: $RunDir","Batches processed: $($batchReports.Count)","Processed total: $processedTotal","Contract accepted: $contractAcceptedTotal","Contract rejected: $contractRejectedTotal","Ready atoms: $($readyAtoms.Count)","Stream quarantined: $($quarantineAtoms.Count)","Active memory mutated: false",'', 'Boundary: per-batch absorption lane only; not active promotion.')
[IO.File]::WriteAllText((Join-Path (Get-Location).Path 'operations/reports/STREAMING_SCHOOL_TO_ABSORPTION_PIPELINE_V1.md'),($md -join "`r`n"),$utf8)
Write-Host "STREAMING_STATUS=$status"
Write-Host "BATCHES_PROCESSED=$($batchReports.Count)"
Write-Host "PROCESSED_TOTAL=$processedTotal"
Write-Host "CONTRACT_ACCEPTED=$contractAcceptedTotal"
Write-Host "CONTRACT_REJECTED=$contractRejectedTotal"
Write-Host "READY_ATOMS=$($readyAtoms.Count)"
Write-Host "STREAM_QUARANTINED=$($quarantineAtoms.Count)"
Write-Host "ACTIVE_MEMORY_MUTATED=false"
if($status -notlike 'PASS_*'){exit 1}
