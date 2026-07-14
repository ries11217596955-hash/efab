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
$outDir=".runtime/streaming_absorption/$runName"
if(Test-Path $outDir){ Remove-Item -Recurse -Force $outDir }
New-Item -ItemType Directory -Force -Path $outDir | Out-Null
$candidateFiles=@(Get-ChildItem $RunDir -Recurse -File -Filter candidates.jsonl | Sort-Object FullName)
if($MaxReadyBatches -gt 0){ $candidateFiles=@($candidateFiles | Select-Object -First $MaxReadyBatches) }
$seenStreamKeys=@{}
$processedTotal=0; $contractAcceptedTotal=0; $contractRejectedTotal=0
$readyAtomsTotal=0; $quarantineAtomsTotal=0; $batchReportsCount=0
$batchIndex=0
$readyPath=(Join-Path (Get-Location).Path "$outDir/ready_atoms.jsonl")
$quarantinePath=(Join-Path (Get-Location).Path "$outDir/quarantined_atoms.jsonl")
$contractRejectedPath=(Join-Path (Get-Location).Path "$outDir/contract_rejected.jsonl")
$readyWriter=New-Object System.IO.StreamWriter($readyPath,$false,$utf8)
$quarantineWriter=New-Object System.IO.StreamWriter($quarantinePath,$false,$utf8)
$contractRejectedWriter=New-Object System.IO.StreamWriter($contractRejectedPath,$false,$utf8)
try{
  foreach($file in $candidateFiles){
    $batchIndex++
    $rel=$file.FullName.Substring((Get-Location).Path.Length+1)
    & operations/school/curriculum/codex_contract/validate_codex_curriculum_batch_v1.ps1 -BatchPath $rel | Out-Host
    $validation=ReadJson 'operations/reports/CODEX_CURRICULUM_CONTRACT_V1_VALIDATION.json'
    $batchOutDir="$outDir/batch_$('{0:D4}' -f $batchIndex)"
    New-Item -ItemType Directory -Force -Path $batchOutDir | Out-Null
    WriteJson "$batchOutDir/contract_validation.json" $validation 80
    $acceptedLines=@{}; foreach($a in @($validation.accepted)){ $acceptedLines[[int]$a.line]=$true }
    $rejectedLines=@{}; foreach($r in @($validation.rejected)){ $rejectedLines[[int]$r.line]=$r }
    $batchReadyCount=0; $batchQuarantineCount=0
    $batchContractRejected=New-Object System.Collections.Generic.List[object]
    $batchQuarantine=New-Object System.Collections.Generic.List[object]
    $lineNo=0
    foreach($lineText in Get-Content $file.FullName){
      if([string]::IsNullOrWhiteSpace($lineText)){ continue }
      $lineNo++
      try{ $obj=$lineText | ConvertFrom-Json }catch{ continue }
      if($rejectedLines.ContainsKey($lineNo)){
        $rej=[pscustomObject]@{line=$lineNo; candidate_id=$obj.candidate_id; topic=$obj.topic; reason='contract_rejected'; failures=@($rejectedLines[$lineNo].failures)}
        [void]$batchContractRejected.Add($rej)
        $contractRejectedWriter.WriteLine(($rej | ConvertTo-Json -Depth 30 -Compress))
        continue
      }
      if(-not $acceptedLines.ContainsKey($lineNo)){ continue }
      $topic=[string]$obj.topic
      $streamKey=if($obj.duplicate_key){[string]$obj.duplicate_key}elseif($obj.learning_key){[string]$obj.learning_key}else{[string]$obj.candidate_id}
      $reason=$null
      if($seenStreamKeys.ContainsKey($streamKey)){ $reason='duplicate_learning_key_stream' }
      elseif(IsGenericOrPlaceholder $obj){ $reason='generic_or_placeholder_stream' }
      $atomOrdinal=$readyAtomsTotal + $quarantineAtomsTotal + 1
      $atom=[pscustomObject]@{
        atom_id=("codex.curriculum.stream.atom.{0:D8}.{1}.v1" -f $atomOrdinal, (($topic -replace '[^A-Za-z0-9_\-]','_').ToLowerInvariant()))
        source_candidate_id=$obj.candidate_id
        source_line=$lineNo
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
        if($obj.PSObject.Properties.Name -contains $extra){ $atom | Add-Member -NotePropertyName $extra -NotePropertyValue $obj.$extra -Force }
      }
      if($reason){
        $qAtom=$atom | Select-Object *
        $qAtom | Add-Member -NotePropertyName quarantine_reason -NotePropertyValue $reason -Force
        [void]$batchQuarantine.Add($qAtom)
        $quarantineWriter.WriteLine(($qAtom | ConvertTo-Json -Depth 30 -Compress))
        $batchQuarantineCount++
        $quarantineAtomsTotal++
      } else {
        $readyWriter.WriteLine(($atom | ConvertTo-Json -Depth 30 -Compress))
        $batchReadyCount++
        $readyAtomsTotal++
        $seenStreamKeys[$streamKey]=$true
      }
    }
    $readyWriter.Flush(); $quarantineWriter.Flush(); $contractRejectedWriter.Flush()
    $processedTotal += [int]$validation.processed_count
    $contractAcceptedTotal += [int]$validation.accepted_count
    $contractRejectedTotal += [int]$validation.rejected_count
    $batchReport=[pscustomObject]@{
      batch_index=$batchIndex
      batch_path=$rel
      status='PASS_STREAMING_BATCH_ABSORPTION_V1'
      processed=$validation.processed_count
      contract_accepted=$validation.accepted_count
      contract_rejected=$validation.rejected_count
      ready_atoms=$batchReadyCount
      stream_quarantined=$batchQuarantineCount
      contract_rejected_items=$batchContractRejected.ToArray()
      stream_quarantined_items=$batchQuarantine.ToArray()
      boundary='Per-batch school-to-absorption lane only. Does not mutate active memory.'
    }
    WriteJson "$batchOutDir/streaming_absorption_batch_report.json" $batchReport 80
    $batchReportsCount++
    $checkpoint=[pscustomObject]@{schema='codex_curriculum_streaming_absorption_checkpoint_v1'; status='RUNNING'; run_dir=$RunDir; batches_processed=$batchReportsCount; processed_total=$processedTotal; contract_accepted_total=$contractAcceptedTotal; contract_rejected_total=$contractRejectedTotal; ready_atoms_total=$readyAtomsTotal; stream_quarantined_total=$quarantineAtomsTotal; active_memory_mutated=$false; updated_at=(Get-Date).ToString('o')}
    WriteJson "$outDir/checkpoint.json" $checkpoint 80
  }
} finally {
  $readyWriter.Close(); $quarantineWriter.Close(); $contractRejectedWriter.Close()
}
$status=if($batchReportsCount -gt 0 -and $readyAtomsTotal -gt 0){'PASS_STREAMING_SCHOOL_TO_ABSORPTION_PIPELINE_V1'}else{'FAIL_STREAMING_SCHOOL_TO_ABSORPTION_PIPELINE_V1'}
$report=[pscustomObject]@{
  schema='streaming_school_to_absorption_pipeline_v1'
  status=$status
  runtime_ready=$false
  run_dir=$RunDir
  candidate_batches_seen=$candidateFiles.Count
  batches_processed=$batchReportsCount
  processed_total=$processedTotal
  contract_accepted_total=$contractAcceptedTotal
  contract_rejected_total=$contractRejectedTotal
  ready_atoms_total=$readyAtomsTotal
  stream_quarantined_total=$quarantineAtomsTotal
  active_memory_mutated=$false
  ready_lane_path="$outDir/ready_atoms.jsonl"
  quarantine_path="$outDir/quarantined_atoms.jsonl"
  contract_rejected_path="$outDir/contract_rejected.jsonl"
  batch_report_count=$batchReportsCount
  batch_reports_path=$outDir
  streaming_memory_mode='bounded_counters_and_jsonl_writers_v2'
  boundary='Streaming school-to-absorption lane. Processes each ready batch independently; does not accumulate ready atoms in PowerShell arrays; does not promote active memory.'
}
WriteJson 'operations/reports/STREAMING_SCHOOL_TO_ABSORPTION_PIPELINE_V1.json' $report 100
$finalCheckpoint=[pscustomObject]@{schema='codex_curriculum_streaming_absorption_checkpoint_v1'; status=$status; run_dir=$RunDir; batches_processed=$batchReportsCount; processed_total=$processedTotal; contract_accepted_total=$contractAcceptedTotal; contract_rejected_total=$contractRejectedTotal; ready_atoms_total=$readyAtomsTotal; stream_quarantined_total=$quarantineAtomsTotal; active_memory_mutated=$false; streaming_memory_mode='bounded_counters_and_jsonl_writers_v2'; updated_at=(Get-Date).ToString('o')}
WriteJson "$outDir/checkpoint.json" $finalCheckpoint 80
$md=@('# STREAMING_SCHOOL_TO_ABSORPTION_PIPELINE_V1','',"Status: $status",'Runtime ready: false','',"Run dir: $RunDir","Batches processed: $batchReportsCount","Processed total: $processedTotal","Contract accepted: $contractAcceptedTotal","Contract rejected: $contractRejectedTotal","Ready atoms: $readyAtomsTotal","Stream quarantined: $quarantineAtomsTotal","Active memory mutated: false",'Streaming memory mode: bounded_counters_and_jsonl_writers_v2','', 'Boundary: per-batch absorption lane only; not active promotion.')
[IO.File]::WriteAllText((Join-Path (Get-Location).Path 'operations/reports/STREAMING_SCHOOL_TO_ABSORPTION_PIPELINE_V1.md'),($md -join "`r`n"),$utf8)
Write-Host "STREAMING_STATUS=$status"
Write-Host "BATCHES_PROCESSED=$batchReportsCount"
Write-Host "PROCESSED_TOTAL=$processedTotal"
Write-Host "CONTRACT_ACCEPTED=$contractAcceptedTotal"
Write-Host "CONTRACT_REJECTED=$contractRejectedTotal"
Write-Host "READY_ATOMS=$readyAtomsTotal"
Write-Host "STREAM_QUARANTINED=$quarantineAtomsTotal"
Write-Host "STREAMING_MEMORY_MODE=bounded_counters_and_jsonl_writers_v2"
Write-Host "ACTIVE_MEMORY_MUTATED=false"
if($status -notlike 'PASS_*'){exit 1}