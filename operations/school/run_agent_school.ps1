param(
  [Parameter(Mandatory=$true)][ValidateRange(1,1000000)][int]$Count,
  [Parameter(Mandatory=$true)][ValidateSet('Test','Live')][string]$Mode
)
$TargetAccepted=$Count
$RunKind=if($Mode -eq 'Live'){'Real'}else{'Test'}
$TopicsPlan='operations/school/curriculum/topics/builder_night_school_topics_v1.json'
$ResumeOrdinalOffset=0
$ResumeCompletedChunks=0
$ResumePlannedTotalAccepted=0
if(-not (Test-Path $TopicsPlan)){ throw "CANONICAL_TOPICS_PLAN_MISSING:$TopicsPlan" }
$ErrorActionPreference='Stop'
$repoRoot=(git rev-parse --show-toplevel).Trim(); Set-Location $repoRoot
$utf8=New-Object System.Text.UTF8Encoding($false)
function EnsureDir($Path){ if(-not (Test-Path $Path)){ New-Item -ItemType Directory -Force $Path | Out-Null } }
function WriteJson($Path,$Obj,$Depth=100){ $d=Split-Path $Path -Parent; if($d){ EnsureDir $d }; [IO.File]::WriteAllText((Join-Path (Get-Location).Path $Path),($Obj|ConvertTo-Json -Depth $Depth),$utf8) }
function FileSha256($Path){
  $sha=[System.Security.Cryptography.SHA256]::Create()
  $fs=[IO.File]::OpenRead((Resolve-Path $Path).Path)
  try { (($sha.ComputeHash($fs)|ForEach-Object{$_.ToString('x2')}) -join '') } finally { $fs.Dispose() }
}
function ReadJsonRequired($Path,$ExpectedStatus,$Label){
  if(-not (Test-Path $Path)){ throw ("RECOVERY_CONTRACT_MISSING:{0}:{1}" -f $Label,$Path) }
  $obj=Get-Content $Path -Raw|ConvertFrom-Json
  if($ExpectedStatus -and [string]$obj.status -ne $ExpectedStatus){ throw ("RECOVERY_CONTRACT_STATUS_BAD:{0}:{1}" -f $Label,$obj.status) }
  return $obj
}
function IsTrackedPath($Path){
  if([string]::IsNullOrWhiteSpace([string]$Path)){ return $false }
  $rel=([string]$Path).Replace('\\','/').Replace('\','/')
  $tracked=@(git ls-files -- $rel 2>$null)
  return ($tracked.Count -gt 0)
}
function RemoveTrash($Items){
  $removed=@()
  $safeRuntimeTrash=@('.runtime/codex_curriculum_candidate_factory_runs','.runtime/file_atom_absorption','.runtime/memory_use_probes','.runtime/digestion_policy','.runtime/digestion_reports')
  foreach($target in @($Items + $safeRuntimeTrash)){
    if([string]::IsNullOrWhiteSpace([string]$target)){ continue }
    $removeTarget=[string]$target
    if($removeTarget -eq 'operations/reports'){ continue }
    if((Test-Path $removeTarget) -and -not (Get-Item $removeTarget).PSIsContainer){
      if(IsTrackedPath $removeTarget){ continue }
      $removeTarget=Split-Path $removeTarget -Parent
    }
    if($removeTarget -and (Test-Path $removeTarget)){
      if(IsTrackedPath $removeTarget){ continue }
      Remove-Item $removeTarget -Recurse -Force
      $removed += $removeTarget
    }
  }
  return @($removed | Select-Object -Unique)
}
$continueContractPath='self_build_batch/runtime/CONTINUE_ON_FAILURE_RUNTIME_V1.json'
$quarantineContractPath='self_build_batch/quarantine/QUARANTINE_AND_BLOCKER_REGISTRY_V1.json'
$proofAggregatorPath='self_build_batch/proof_aggregation/BATCH_PROOF_AGGREGATOR_V1.json'
$continueContract=ReadJsonRequired $continueContractPath 'ACTIVE_RUNTIME_CONTRACT' 'continue_on_failure_runtime'
$quarantineContract=ReadJsonRequired $quarantineContractPath 'ACTIVE_REGISTRY_CONTRACT' 'quarantine_blocker_registry'
$proofAggregator=ReadJsonRequired $proofAggregatorPath 'ACTIVE_AGGREGATOR_CONTRACT' 'batch_proof_aggregator'
$recoveryContracts=[ordered]@{
  wiring_status='SCHOOL_CHUNK_RECOVERY_CONTRACTS_WIRED_V1'
  continue_on_failure_runtime=[ordered]@{path=$continueContractPath; status=$continueContract.status; runtime_id=$continueContract.runtime_id; sha256=FileSha256 $continueContractPath}
  quarantine_blocker_registry=[ordered]@{path=$quarantineContractPath; status=$quarantineContract.status; registry_id=$quarantineContract.registry_id; sha256=FileSha256 $quarantineContractPath}
  batch_proof_aggregator=[ordered]@{path=$proofAggregatorPath; status=$proofAggregator.status; aggregator_id=$proofAggregator.aggregator_id; sha256=FileSha256 $proofAggregatorPath}
  no_fake_pass_policy=$proofAggregator.aggregation_policy.no_fake_pass
  no_hidden_failures_policy=$proofAggregator.aggregation_policy.no_hidden_failures
  record_failure_before_continuing=$continueContract.continue_rules.record_failure_before_continuing
  record_quarantine_before_continuing=$continueContract.continue_rules.record_quarantine_before_continuing
  stop_on_systemic_failure=$continueContract.stop_rules.stop_on_systemic_failure
  no_blind_retry=$quarantineContract.registry_policy.no_blind_retry
  proof_boundary='Contracts are wired into school proof. Controlled chunk failure/resume remains NOT_PROVEN until a deliberate negative test.'
  memory_rollback_capability='SCHOOL_REAL_CHUNK_MEMORY_CHECKPOINT_ROLLBACK_V1'
  failure_test_hook='GUARDED_BY_OWNER_APPROVED_FAILURE_TEST_TOKEN'
}
function GetMemoryState($Root){
  $manifestPath=Join-Path $Root 'manifest.json'
  $cellsPath=Join-Path $Root 'cells.jsonl'
  if(-not (Test-Path $manifestPath)){ return [ordered]@{exists=$false; root=$Root; run_id=$null; cells=0; cells_sha256='MISSING'; manifest_sha256='MISSING'} }
  $manifest=Get-Content $manifestPath -Raw|ConvertFrom-Json
  $cells=0
  if(Test-Path $cellsPath){ $cells=(Get-Content $cellsPath|Measure-Object -Line).Lines }
  return [ordered]@{
    exists=$true
    root=$Root
    run_id=$manifest.run_id
    status=$manifest.status
    cells=$cells
    manifest_cell_count=[int]$manifest.cell_count
    cells_sha256=(Get-FileHash -Algorithm SHA256 $cellsPath).Hash
    manifest_sha256=(Get-FileHash -Algorithm SHA256 $manifestPath).Hash
  }
}
function NewMemoryCheckpoint($Root,$RunId,$ChunkIndex,$OrdinalOffset){
  if(-not (Test-Path $Root)){ throw "MEMORY_ROOT_MISSING_FOR_CHECKPOINT:$Root" }
  $checkpointRoot=".runtime/school_runs/$RunId/memory_checkpoints/chunk_${ChunkIndex}_offset_${OrdinalOffset}"
  EnsureDir $checkpointRoot
  $snapshotPath=Join-Path $checkpointRoot 'active_compact_semantic_memory_v1'
  if(Test-Path $snapshotPath){ Remove-Item $snapshotPath -Recurse -Force }
  $before=GetMemoryState $Root
  Copy-Item -Path $Root -Destination $snapshotPath -Recurse -Force
  $snapshot=GetMemoryState $snapshotPath
  if($before.cells_sha256 -ne $snapshot.cells_sha256 -or $before.manifest_sha256 -ne $snapshot.manifest_sha256 -or $before.run_id -ne $snapshot.run_id){ throw 'MEMORY_CHECKPOINT_COPY_MISMATCH' }
  return [ordered]@{
    schema='school_real_chunk_memory_checkpoint_v1'
    status='CHECKPOINT_READY'
    checkpoint_kind='ACTIVE_COMPACT_MEMORY_BEFORE_REAL_CHUNK'
    run_id=$RunId
    chunk_index=[int]$ChunkIndex
    ordinal_offset=[int]$OrdinalOffset
    checkpoint_root=$checkpointRoot
    snapshot_path=$snapshotPath
    before_state=$before
    snapshot_state=$snapshot
  }
}
function PruneMemoryCheckpoints($RunId,[int]$KeepLatest=3){
  $removed=@()
  if([string]::IsNullOrWhiteSpace([string]$RunId)){ return @() }
  if($KeepLatest -lt 1){ $KeepLatest=1 }
  $root=".runtime/school_runs/$RunId/memory_checkpoints"
  if(-not(Test-Path $root)){ return @() }
  $dirs=@(Get-ChildItem $root -Directory -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending)
  if($dirs.Count -le $KeepLatest){ return @() }
  foreach($d in @($dirs | Select-Object -Skip $KeepLatest)){
    Remove-Item $d.FullName -Recurse -Force
    $removed += $d.FullName
  }
  return @($removed)
}
function RestoreMemoryCheckpoint($Checkpoint,$Root){
  if($null -eq $Checkpoint){ return [ordered]@{status='NO_CHECKPOINT_AVAILABLE'; restored=$false; reason='checkpoint_missing'} }
  $snapshotPath=[string]$Checkpoint.snapshot_path
  if([string]::IsNullOrWhiteSpace($snapshotPath) -or -not (Test-Path $snapshotPath)){ return [ordered]@{status='CHECKPOINT_SNAPSHOT_MISSING'; restored=$false; checkpoint=$Checkpoint} }
  $beforeFailure=GetMemoryState $Root
  if(Test-Path $Root){ Remove-Item $Root -Recurse -Force }
  $parent=Split-Path $Root -Parent
  if($parent){ EnsureDir $parent }
  Copy-Item -Path $snapshotPath -Destination $Root -Recurse -Force
  $afterRestore=GetMemoryState $Root
  $expected=$Checkpoint.before_state
  $matched=($afterRestore.cells_sha256 -eq $expected.cells_sha256 -and $afterRestore.manifest_sha256 -eq $expected.manifest_sha256 -and $afterRestore.run_id -eq $expected.run_id)
  return [ordered]@{
    schema='school_real_chunk_memory_rollback_v1'
    status=if($matched){'ROLLBACK_RESTORED_ACTIVE_MEMORY_V1'}else{'ROLLBACK_RESTORE_MISMATCH_V1'}
    restored=$matched
    root=$Root
    checkpoint_root=$Checkpoint.checkpoint_root
    snapshot_path=$snapshotPath
    chunk_index=[int]$Checkpoint.chunk_index
    ordinal_offset=[int]$Checkpoint.ordinal_offset
    before_failure_state=$beforeFailure
    restored_state=$afterRestore
    expected_state=$expected
  }
}
function BuildResumeState($Status,$FailureState,$CompletedChunks,$CurrentChunkIndex,$CurrentOffset,$NextChunkIndex,$NextOffset,$ErrorMessage){
  return [ordered]@{
    status=$Status
    failure_state=$FailureState
    completed_chunk_count=[int]$CompletedChunks
    current_chunk_index=[int]$CurrentChunkIndex
    current_ordinal_offset=[int]$CurrentOffset
    next_chunk_index=[int]$NextChunkIndex
    resume_ordinal_offset=[int]$NextOffset
    last_good_chunk_index=[int]$CompletedChunks
    error=$ErrorMessage
    resume_requires='OWNER_OR_REPAIR_DECISION_AFTER_FAILURE_CLASSIFICATION'
  }
}
function BuildAggregationSummary($Status,$Chunks,$FailedCount,$QuarantinedCount,$BlockedCount,$AssistanceCount){
  return [ordered]@{
    status=$Status
    planned_chunk_count=$null
    pass_count=[int]@($Chunks).Count
    failed_count=[int]$FailedCount
    quarantined_count=[int]$QuarantinedCount
    blocked_count=[int]$BlockedCount
    assistance_required_count=[int]$AssistanceCount
    unresolved_record_count=([int]$FailedCount+[int]$QuarantinedCount+[int]$BlockedCount+[int]$AssistanceCount)
    no_fake_pass=$true
    no_hidden_failures=$true
    source_contract=$proofAggregatorPath
  }
}
function TestSchoolStopRequested($RunId,$ChunkIndex,$OrdinalOffset,$ProcessedInThisRun,$TargetAccepted,$Reason){
  $stopPath=if($env:EF_SCHOOL_STOP_REQUEST_PATH){[string]$env:EF_SCHOOL_STOP_REQUEST_PATH}else{'.runtime/control/school_stop_requested.json'}
  if(-not (Test-Path $stopPath)){ return $false }
  $request=$null
  try { $request=Get-Content $stopPath -Raw | ConvertFrom-Json } catch { $request=[ordered]@{ parse_error=$_.Exception.Message } }
  $ackPath=(".runtime/control/school_stop_ack_{0}_chunk_{1}.json" -f $RunId,$ChunkIndex)
  $ack=[ordered]@{
    schema='school_controlled_stop_ack_v1'
    status='CONTROLLED_STOP_REQUEST_ACKNOWLEDGED'
    run_id=$RunId
    chunk_index=[int]$ChunkIndex
    ordinal_offset=[int]$OrdinalOffset
    processed_in_this_run=[int]$ProcessedInThisRun
    target_accepted=[int]$TargetAccepted
    remaining_target=[int]([Math]::Max(0,$TargetAccepted-$ProcessedInThisRun))
    reason=$Reason
    stop_request_path=$stopPath
    stop_request=$request
    resume_hint=[ordered]@{ resume_completed_chunks=[int]($ChunkIndex-1); resume_ordinal_offset=[int]$OrdinalOffset; resume_remaining_target=[int]([Math]::Max(0,$TargetAccepted-$ProcessedInThisRun)) }
    active_memory_root='.runtime/active_compact_semantic_memory_v1'
    runtime_ready=$false
    created_at=(Get-Date).ToString('o')
  }
  WriteJson $ackPath $ack 100
  Write-Host "SCHOOL_CONTROLLED_STOP_ACK=$ackPath"
  Write-Host 'SCHOOL_RUN_STATUS=CONTROLLED_STOP_REQUEST_ACKNOWLEDGED'
  return $true
}
$runId="school_factory_digest_use_{0}_{1}_{2}" -f $RunKind.ToLowerInvariant(),$TargetAccepted,(Get-Date -Format 'yyyyMMdd_HHmmss')
$proofDir=".runtime/school_runs/$runId"
$proofPath="$proofDir/AGENT_SCHOOL_CANONICAL_ENTRYPOINT_V1.json"
$routePath='operations/school/curriculum/incremental_active_store/ACTIVE_REPO_BODY_ROUTE_POINTER_V1.json'
$ledgerPath='operations/school/curriculum/incremental_active_store/ACTIVE_REPO_BODY_ROUTE_REPLAY_LEDGER_V1.json'
$routeBefore=Get-Content $routePath -Raw|ConvertFrom-Json
$ledgerBefore=Get-Content $ledgerPath -Raw|ConvertFrom-Json
$outerChunkSize=5000
$resumeMode=($ResumeOrdinalOffset -gt 0 -or $ResumeCompletedChunks -gt 0 -or $ResumePlannedTotalAccepted -gt 0)
if($ResumeOrdinalOffset -lt 0 -or $ResumeCompletedChunks -lt 0 -or $ResumePlannedTotalAccepted -lt 0){ throw 'RESUME_PARAMS_NEGATIVE' }
if($resumeMode -and $ResumePlannedTotalAccepted -lt ($ResumeOrdinalOffset + $TargetAccepted)){ throw 'RESUME_PLANNED_TOTAL_LT_OFFSET_PLUS_TARGET' }
$plannedTotalAccepted=if($ResumePlannedTotalAccepted -gt 0){$ResumePlannedTotalAccepted}else{$ResumeOrdinalOffset + $TargetAccepted}
if($env:EF_SCHOOL_OUTER_CHUNK_SIZE){ $outerChunkSize=[int]$env:EF_SCHOOL_OUTER_CHUNK_SIZE }
if($outerChunkSize -lt 1){ throw 'BAD_OUTER_CHUNK_SIZE' }
$innerBatchSizeMax=100
$failureTestEnabled=$false
$failureTestChunk=0
$failureTestStage=''
if($env:EF_SCHOOL_FORCE_FAIL_CHUNK_INDEX -or $env:EF_SCHOOL_FORCE_FAIL_STAGE -or $env:EF_SCHOOL_FAILURE_TEST_TOKEN){
  if($env:EF_SCHOOL_FAILURE_TEST_TOKEN -ne 'OWNER_APPROVED_FAILURE_TEST'){ throw 'FAILURE_TEST_TOKEN_REQUIRED' }
  if(-not $env:EF_SCHOOL_FORCE_FAIL_CHUNK_INDEX){ throw 'FAILURE_TEST_CHUNK_REQUIRED' }
  if(-not $env:EF_SCHOOL_FORCE_FAIL_STAGE){ throw 'FAILURE_TEST_STAGE_REQUIRED' }
  $failureTestChunk=[int]$env:EF_SCHOOL_FORCE_FAIL_CHUNK_INDEX
  $failureTestStage=[string]$env:EF_SCHOOL_FORCE_FAIL_STAGE
  if($failureTestChunk -lt 1){ throw 'FAILURE_TEST_CHUNK_BAD' }
  if($failureTestStage -notin @('before_factory','after_streaming_before_digest','after_digest_before_recall_use')){ throw 'FAILURE_TEST_STAGE_BAD' }
  if($failureTestStage -eq 'after_digest_before_recall_use' -and $RunKind -ne 'Real'){ throw 'FAILURE_TEST_DIGEST_STAGE_REQUIRES_REAL' }
  $failureTestEnabled=$true
}
$cleanupRemoved=@(); $chunks=@(); $totalFactoryCandidates=0; $totalReadyAtoms=0; $totalStreamQuarantined=0; $lastProof=$null; $lastUseProof=$null; $lastSourceRouterReport=$null; $activeMemoryRoot='.runtime/active_compact_semantic_memory_v1'; $lastChunkMemoryCheckpoint=$null; $memoryRollbackEvents=@(); $chunkTimingRows=@()
$chunkIndex=$ResumeCompletedChunks; $remaining=$TargetAccepted; $processedInThisRun=0; $ordinalOffset=$ResumeOrdinalOffset; $totalChunks=$ResumeCompletedChunks + [int][Math]::Ceiling($TargetAccepted / $outerChunkSize)
try {
  while($remaining -gt 0){
    $chunkIndex++
    $ordinalOffset=$ResumeOrdinalOffset + $processedInThisRun
    $chunkTarget=[Math]::Min($outerChunkSize,$remaining)
    $batchSize=[Math]::Min($innerBatchSizeMax,[Math]::Max(1,$chunkTarget))
    $chunkStart=Get-Date
    if(TestSchoolStopRequested $runId $chunkIndex $ordinalOffset $processedInThisRun $TargetAccepted 'before_chunk_start'){ return }
    if($failureTestEnabled -and $chunkIndex -eq $failureTestChunk -and $failureTestStage -eq 'before_factory'){ throw ("FORCED_SCHOOL_CHUNK_FAILURE:chunk={0}:stage=before_factory" -f $chunkIndex) }
    $chunkRunId="${runId}_chunk_${chunkIndex}_of_$totalChunks"
    $factoryOut=@(& powershell -NoProfile -ExecutionPolicy Bypass -File operations/school/curriculum/source_router/run_school_source_router_v1.ps1 -TargetAccepted $chunkTarget -RunKind Test -BatchSize $batchSize -RunId $chunkRunId -OrdinalOffset $ordinalOffset -TopicsPlan $TopicsPlan -SourceMode Auto *>&1 | ForEach-Object {[string]$_})
    $factoryStatus=($factoryOut|Where-Object{$_ -match '^FACTORY_STATUS='}|Select-Object -Last 1) -replace '^FACTORY_STATUS=',''
    if($factoryStatus -ne 'PASS_CODEX_CANDIDATE_FACTORY_GENERATION_V1'){ throw "FACTORY_NOT_PASS:$factoryStatus" }
    $factoryReport=Get-Content operations/reports/CODEX_CANDIDATE_FACTORY_RUN_V1.json -Raw|ConvertFrom-Json
    $sourceRouterReport=$null
    if(Test-Path 'operations/reports/SCHOOL_SOURCE_ROUTER_SELECTION_V1.json'){ $sourceRouterReport=Get-Content 'operations/reports/SCHOOL_SOURCE_ROUTER_SELECTION_V1.json' -Raw|ConvertFrom-Json; $lastSourceRouterReport=$sourceRouterReport }
    & operations/school/curriculum/codex_contract/validate_codex_curriculum_contract_consistency_v1.ps1 -RunDir $factoryReport.run_dir | Out-Host
    $consistency=Get-Content operations/reports/CODEX_CURRICULUM_CONTRACT_CONSISTENCY_V1.json -Raw|ConvertFrom-Json
    if($consistency.status -ne 'PASS_CODEX_CURRICULUM_CONTRACT_CONSISTENCY_V1'){ throw "CONTRACT_NOT_PASS:$($consistency.status)" }
    & operations/school/curriculum/streaming_absorption/validate_codex_curriculum_streaming_absorption_v1.ps1 -RunDir $factoryReport.run_dir | Out-Host
    $stream=Get-Content operations/reports/STREAMING_SCHOOL_TO_ABSORPTION_PIPELINE_V1.json -Raw|ConvertFrom-Json
    if($stream.status -ne 'PASS_STREAMING_SCHOOL_TO_ABSORPTION_PIPELINE_V1'){ throw "STREAMING_NOT_PASS:$($stream.status)" }
    if([int]$stream.ready_atoms_total -ne $chunkTarget){ throw "READY_ATOMS_COUNT_BAD:$($stream.ready_atoms_total)" }
    $totalFactoryCandidates += [int]$factoryReport.candidates_created
    $totalReadyAtoms += [int]$stream.ready_atoms_total
    $totalStreamQuarantined += [int]$stream.stream_quarantined_total
    if($failureTestEnabled -and $chunkIndex -eq $failureTestChunk -and $failureTestStage -eq 'after_streaming_before_digest'){ throw ("FORCED_SCHOOL_CHUNK_FAILURE:chunk={0}:stage=after_streaming_before_digest" -f $chunkIndex) }
    if($RunKind -eq 'Test'){
      $cleanupRemoved += RemoveTrash @($factoryReport.run_dir,'operations/reports')
      $chunks += [ordered]@{chunk_index=$chunkIndex; chunk_target=$chunkTarget; ordinal_offset=$ordinalOffset; inner_batch_size=$batchSize; factory_candidates=[int]$factoryReport.candidates_created; ready_atoms=[int]$stream.ready_atoms_total; source_router_selected=if($sourceRouterReport){$sourceRouterReport.selected_source}else{'UNKNOWN'}; record_status='PASS'; digested=$false; recall_use=$false; cleanup_after_chunk=$true}
      $partial=[ordered]@{schema='agent_school_canonical_run_v7_chunked_cumulative_recovery_wired'; status='RUNNING_CHUNKED_SCHOOL_PARTIAL_PROOF_V1'; run_id=$runId; run_kind=$RunKind; public_mode=$Mode; target_accepted=$TargetAccepted; topics_plan=$TopicsPlan; resume_execution=[ordered]@{mode=[bool]$resumeMode; resume_ordinal_offset=[int]$ResumeOrdinalOffset; resume_completed_chunks=[int]$ResumeCompletedChunks; resume_remaining_target=[int]$TargetAccepted; planned_total_accepted=[int]$plannedTotalAccepted}; outer_chunk_size=$outerChunkSize; inner_batch_size_max=$innerBatchSizeMax; chunk_count=@($chunks).Count; chunks=@($chunks); ready_atoms=$totalReadyAtoms; recovery_contracts=$recoveryContracts; resume_state=(BuildResumeState 'RUNNING' 'NONE' @($chunks).Count ($chunkIndex+1) ($ordinalOffset+$chunkTarget) ($chunkIndex+1) ($ordinalOffset+$chunkTarget) $null); aggregation_summary=(BuildAggregationSummary 'RUNNING' $chunks 0 0 0 0); cleanup_after_each_chunk=$true; cleanup_removed=@($cleanupRemoved|Select-Object -Unique); runtime_ready=$false}
      $partial.aggregation_summary.planned_chunk_count=$totalChunks
      WriteJson $proofPath $partial 100
      $remaining -= $chunkTarget
      $processedInThisRun += $chunkTarget
      continue
    }
    $lastChunkMemoryCheckpoint=NewMemoryCheckpoint $activeMemoryRoot $runId $chunkIndex $ordinalOffset
    $checkpointPruneRemoved=PruneMemoryCheckpoints $runId 3
    if($checkpointPruneRemoved){ $cleanupRemoved += $checkpointPruneRemoved }
    $activeMemoryBytes=0
    if(Test-Path $activeMemoryRoot){ $activeMemoryBytes=[int64]((Get-ChildItem $activeMemoryRoot -Recurse -File -ErrorAction SilentlyContinue | Measure-Object Length -Sum).Sum) }
    $budget=[int64][Math]::Max([double]1600000,[Math]::Max(([double]([Math]::Max($plannedTotalAccepted,1000) * 1600)),([double]($activeMemoryBytes + ($chunkTarget * 2000) + 2000000))))
    $digestOrdinalForPolicy=[int]($ResumeCompletedChunks + $processedInThisRun / [Math]::Max(1,$outerChunkSize) + 1)
    $digestsSinceStable=if(($digestOrdinalForPolicy % 10) -eq 0){10}else{[int]($digestOrdinalForPolicy % 10)}
    $digestsSinceFull=if(($digestOrdinalForPolicy % 50) -eq 0){50}else{[int]($digestOrdinalForPolicy % 50)}
    $pipeOut=@(& powershell -NoProfile -ExecutionPolicy Bypass -File operations/school/digestion/absorb_atom_file_via_digest_pipeline_v1.ps1 -InputPath $stream.ready_lane_path -MemoryRoot $activeMemoryRoot -ValidationTier Auto -SizeBudgetBytes $budget -DigestsSinceStable $digestsSinceStable -DigestsSinceFull $digestsSinceFull *>&1 | ForEach-Object {[string]$_})
    $pipeStatus=($pipeOut|Where-Object{$_ -match '^FILE_ATOM_ABSORPTION_STATUS='}|Select-Object -Last 1) -replace '^FILE_ATOM_ABSORPTION_STATUS=',''
    $pipeProofPath=($pipeOut|Where-Object{$_ -match '^PROOF_PATH='}|Select-Object -Last 1) -replace '^PROOF_PATH=',''
    if($pipeStatus -ne 'PASS_FILE_ATOM_ABSORPTION_PIPELINE_V1'){ throw "PIPELINE_NOT_PASS:$pipeStatus" }
    $pipeProof=Get-Content $pipeProofPath -Raw|ConvertFrom-Json
    if($pipeProof.cumulative_memory_merge -ne $true){ throw 'PIPELINE_CUMULATIVE_MEMORY_MERGE_NOT_PROVEN' }
    if($failureTestEnabled -and $chunkIndex -eq $failureTestChunk -and $failureTestStage -eq 'after_digest_before_recall_use'){ throw ("FORCED_SCHOOL_CHUNK_FAILURE:chunk={0}:stage=after_digest_before_recall_use" -f $chunkIndex) }
    $routeMid=Get-Content $routePath -Raw|ConvertFrom-Json
    $ledgerMid=Get-Content $ledgerPath -Raw|ConvertFrom-Json
    if([int]$routeMid.routed_active_count -ne [int]$routeBefore.routed_active_count){ throw 'ROUTE_MUTATED_BY_REAL_FACTORY_DIGEST' }
    if([int]$ledgerMid.replayed_active_count -ne [int]$ledgerBefore.replayed_active_count){ throw 'LEDGER_MUTATED_BY_REAL_FACTORY_DIGEST' }
    $useTask="Chunk $chunkIndex of cumulative night school must prove compact memory is recalled and used before continuing."
    $useOut=@(& powershell -NoProfile -ExecutionPolicy Bypass -File operations/school/memory/validate_compact_memory_recall_use_probe_v1.ps1 -MemoryRoot $pipeProof.memory_root -Task $useTask *>&1 | ForEach-Object {[string]$_})
    $useStatus=($useOut|Where-Object{$_ -match '^VALIDATION_PASS=COMPACT_MEMORY_RECALL_USE_PROBE_V1_VALID$'}|Select-Object -Last 1)
    $useProofPath=($useOut|Where-Object{$_ -match '^PROOF_PATH='}|Select-Object -Last 1) -replace '^PROOF_PATH=',''
    if($useStatus -ne 'VALIDATION_PASS=COMPACT_MEMORY_RECALL_USE_PROBE_V1_VALID'){ throw 'RECALL_USE_GATE_NOT_PASS' }
    if([string]::IsNullOrWhiteSpace($useProofPath) -or -not (Test-Path $useProofPath)){ throw 'RECALL_USE_PROOF_MISSING' }
    $useProof=Get-Content $useProofPath -Raw|ConvertFrom-Json
    if($useProof.behavior_delta -ne $true){ throw 'BEHAVIOR_DELTA_NOT_PROVEN' }
    $chunkElapsedMs=[int][Math]::Round(((Get-Date)-$chunkStart).TotalMilliseconds)
    $chunkTimingRows += [ordered]@{chunk_index=[int]$chunkIndex; elapsed_ms=$chunkElapsedMs; validation_tier=$pipeProof.selected_validation_tier; absorption_total_elapsed_ms=$pipeProof.total_elapsed_ms; absorption_stage_timings=$pipeProof.stage_timings}
    $chunks += [ordered]@{chunk_index=$chunkIndex; chunk_target=$chunkTarget; ordinal_offset=$ordinalOffset; inner_batch_size=$batchSize; factory_candidates=[int]$factoryReport.candidates_created; ready_atoms=[int]$stream.ready_atoms_total; source_router_selected=if($sourceRouterReport){$sourceRouterReport.selected_source}else{'UNKNOWN'}; record_status='PASS'; digested=$true; validation_tier=$pipeProof.selected_validation_tier; absorption_total_elapsed_ms=$pipeProof.total_elapsed_ms; digested_cells=[int]$pipeProof.digested_cells; merged_count=[int]$pipeProof.merged_count; cumulative_memory_merge=$pipeProof.cumulative_memory_merge; existing_memory_seeded=$pipeProof.existing_memory_seeded; existing_memory_cells_before=[int]$pipeProof.existing_memory_cells_before; total_memory_bytes=[int]$pipeProof.total_memory_bytes; recall_use_status=$useProof.status; behavior_delta=$useProof.behavior_delta; used_memory_cells_count=@($useProof.used_labels).Count; cleanup_after_chunk=$true}
    if(TestSchoolStopRequested $runId ($chunkIndex+1) ($ordinalOffset+$chunkTarget) $processedInThisRun $TargetAccepted 'after_chunk_complete'){ return }
    $lastProof=$pipeProof; $lastUseProof=$useProof
    $cleanupRemoved += RemoveTrash @($factoryReport.run_dir,$pipeProofPath,$pipeProof.candidate_memory_root,$useProofPath,'operations/reports')
    $partial=[ordered]@{schema='agent_school_canonical_run_v7_chunked_cumulative_recovery_wired'; status='RUNNING_CHUNKED_SCHOOL_PARTIAL_PROOF_V1'; run_id=$runId; run_kind=$RunKind; public_mode=$Mode; target_accepted=$TargetAccepted; topics_plan=$TopicsPlan; resume_execution=[ordered]@{mode=[bool]$resumeMode; resume_ordinal_offset=[int]$ResumeOrdinalOffset; resume_completed_chunks=[int]$ResumeCompletedChunks; resume_remaining_target=[int]$TargetAccepted; planned_total_accepted=[int]$plannedTotalAccepted}; outer_chunk_size=$outerChunkSize; inner_batch_size_max=$innerBatchSizeMax; chunk_count=@($chunks).Count; chunks=@($chunks); ready_atoms=$totalReadyAtoms; recovery_contracts=$recoveryContracts; resume_state=(BuildResumeState 'RUNNING' 'NONE' @($chunks).Count ($chunkIndex+1) ($ordinalOffset+$chunkTarget) ($chunkIndex+1) ($ordinalOffset+$chunkTarget) $null); aggregation_summary=(BuildAggregationSummary 'RUNNING' $chunks 0 0 0 0); cleanup_after_each_chunk=$true; cleanup_removed=@($cleanupRemoved|Select-Object -Unique); runtime_ready=$false}
    $partial.aggregation_summary.planned_chunk_count=$totalChunks
    WriteJson $proofPath $partial 100
    $remaining -= $chunkTarget
    $processedInThisRun += $chunkTarget
  }
} catch {
  $memoryRollbackResult=RestoreMemoryCheckpoint $lastChunkMemoryCheckpoint $activeMemoryRoot
  $memoryRollbackEvents += $memoryRollbackResult
  $cleanupRemoved += RemoveTrash @('.runtime/codex_curriculum_candidate_factory_runs','.runtime/file_atom_absorption','.runtime/memory_use_probes','.runtime/digestion_policy','.runtime/digestion_reports')
  $routeFailure=Get-Content $routePath -Raw|ConvertFrom-Json
  $ledgerFailure=Get-Content $ledgerPath -Raw|ConvertFrom-Json
  $failedChunkIndex=[Math]::Max(1,$chunkIndex)
  $resumeOffset=[Math]::Max(0,$ordinalOffset)
  $failureRecord=[ordered]@{record_type='FAILED'; status='FAILED_REQUIRES_OWNER_OR_REPAIR_DECISION'; failed_chunk_index=$failedChunkIndex; resume_ordinal_offset=$resumeOffset; reason=$_.Exception.Message; source_contract=$quarantineContractPath; no_blind_retry=$true}
  $failAgg=BuildAggregationSummary 'FAILURE_AGGREGATED' $chunks 1 0 0 1
  $failAgg.planned_chunk_count=$totalChunks
  $fail=[ordered]@{schema='agent_school_canonical_run_v7_chunked_cumulative_recovery_wired'; status='FAIL_CHUNKED_SCHOOL_CLEANED_TRANSIENTS_V1'; run_id=$runId; run_kind=$RunKind; public_mode=$Mode; target_accepted=$TargetAccepted; topics_plan=$TopicsPlan; resume_execution=[ordered]@{mode=[bool]$resumeMode; resume_ordinal_offset=[int]$ResumeOrdinalOffset; resume_completed_chunks=[int]$ResumeCompletedChunks; resume_remaining_target=[int]$TargetAccepted; planned_total_accepted=[int]$plannedTotalAccepted}; outer_chunk_size=$outerChunkSize; inner_batch_size_max=$innerBatchSizeMax; chunk_count=@($chunks).Count; chunks=@($chunks); recovery_contracts=$recoveryContracts; resume_state=(BuildResumeState 'FAILURE_RECORDED' 'FAILED_CHUNK_REQUIRES_DECISION' @($chunks).Count $failedChunkIndex $resumeOffset $failedChunkIndex $resumeOffset $_.Exception.Message); quarantine_record=$failureRecord; aggregation_summary=$failAgg; memory_checkpoint=$lastChunkMemoryCheckpoint; memory_rollback=$memoryRollbackResult; memory_rollback_events=@($memoryRollbackEvents); memory_rollback_capability='SCHOOL_REAL_CHUNK_MEMORY_CHECKPOINT_ROLLBACK_V1'; failure_test_enabled=$failureTestEnabled; forced_failure_chunk=$failureTestChunk; forced_failure_stage=$failureTestStage; route_before=[int]$routeBefore.routed_active_count; ledger_before=[int]$ledgerBefore.replayed_active_count; route_after=[int]$routeFailure.routed_active_count; ledger_after=[int]$ledgerFailure.replayed_active_count; route_unchanged=([int]$routeBefore.routed_active_count -eq [int]$routeFailure.routed_active_count); ledger_unchanged=([int]$ledgerBefore.replayed_active_count -eq [int]$ledgerFailure.replayed_active_count); error=$_.Exception.Message; cleanup_removed=@($cleanupRemoved|Select-Object -Unique); runtime_ready=$false; no_fake_pass=$true; no_hidden_failures=$true}
  WriteJson $proofPath $fail 100
  throw
}
$routeAfter=Get-Content $routePath -Raw|ConvertFrom-Json
$ledgerAfter=Get-Content $ledgerPath -Raw|ConvertFrom-Json
if([int]$routeAfter.routed_active_count -ne [int]$routeBefore.routed_active_count){ throw 'ROUTE_MUTATED_BY_RUN' }
if([int]$ledgerAfter.replayed_active_count -ne [int]$ledgerBefore.replayed_active_count){ throw 'LEDGER_MUTATED_BY_RUN' }
$base=[ordered]@{schema='agent_school_canonical_run_v7_chunked_cumulative_recovery_wired'; run_id=$runId; run_kind=$RunKind; public_mode=$Mode; target_accepted=$TargetAccepted; topics_plan=$TopicsPlan; resume_execution=[ordered]@{mode=[bool]$resumeMode; resume_ordinal_offset=[int]$ResumeOrdinalOffset; resume_completed_chunks=[int]$ResumeCompletedChunks; resume_remaining_target=[int]$TargetAccepted; planned_total_accepted=[int]$plannedTotalAccepted}; outer_chunk_size=$outerChunkSize; inner_batch_size_max=$innerBatchSizeMax; chunk_count=@($chunks).Count; chunks=@($chunks); recovery_contracts=$recoveryContracts; school_recovery_wiring_status='PASS_SCHOOL_CHUNK_RECOVERY_CONTRACTS_WIRED_V1'; resume_state=(BuildResumeState 'COMPLETE' 'NONE' (@($chunks).Count + $ResumeCompletedChunks) ($chunkIndex+1) ($ResumeOrdinalOffset + $TargetAccepted) ($chunkIndex+1) ($ResumeOrdinalOffset + $TargetAccepted) $null); aggregation_summary=(BuildAggregationSummary 'PASS_AGGREGATED' $chunks 0 0 0 0); memory_rollback_capability='SCHOOL_REAL_CHUNK_MEMORY_CHECKPOINT_ROLLBACK_V1'; memory_rollback_events=@($memoryRollbackEvents); runtime_ready=$false; raw_route_absorption_allowed=$false; factory_candidates_created=$totalFactoryCandidates; ready_atoms=$totalReadyAtoms; stream_quarantined=$totalStreamQuarantined; codex_cli_invoked=$false; api_invoked=$false; school_source_router_status=if($lastSourceRouterReport){$lastSourceRouterReport.status}else{'UNKNOWN'}; school_source_selected=if($lastSourceRouterReport){$lastSourceRouterReport.selected_source}else{'UNKNOWN'}; route_before=[int]$routeBefore.routed_active_count; ledger_before=[int]$ledgerBefore.replayed_active_count; route_after=[int]$routeAfter.routed_active_count; ledger_after=[int]$ledgerAfter.replayed_active_count; retention_policy='KEEP_ACTIVE_COMPACT_MEMORY_AND_LATEST_3_MEMORY_CHECKPOINTS_V2'; cleanup_removed=@($cleanupRemoved|Select-Object -Unique); cleanup_after_each_chunk=$true; no_fake_pass=$true; no_hidden_failures=$true; failure_resume_boundary='Recovery contracts are wired into canonical proof. Controlled chunk failure/resume remains NOT_PROVEN until negative test.'; law='Count + Mode + TopicsPlan uses outer chunks of 5000 and inner factory batches of 100. Real uses cumulative compact semantic memory and cannot continue past a chunk without recall/use behavior_delta proof; failure records must expose resume_state and quarantine_record before any continuation.'}
$base.aggregation_summary.planned_chunk_count=$totalChunks
$base.resume_execution.processed_in_this_run=[int]$processedInThisRun
$base.chunk_timing_rows=@($chunkTimingRows)
if($RunKind -eq 'Test'){
  $base.status='PASS_TEST_FACTORY_STREAMING_READY_V1'; $base.digested_knowledge_mutated=$false; $base.recall_use_required=$false; $base.behavior_delta=$false; $base.boundary='Test validates existing factory and streaming ready lane only. It does not digest or mutate compact memory.'
} else {
  if($null -eq $lastProof -or $null -eq $lastUseProof){ throw 'REAL_FINAL_PROOF_MISSING' }
  $base.status='PASS_REAL_FACTORY_DIGEST_RECALL_USE_V1'; $base.digested_knowledge_mutated=$true; $base.pipeline_status=$lastProof.status; $base.validation_tier=$lastProof.selected_validation_tier; $base.digested_cells=[int]$lastProof.digested_cells; $base.merged_count=[int]$lastProof.merged_count; $base.raw_source_dependency_removed=$lastProof.raw_source_dependency_removed; $base.total_memory_bytes=[int]$lastProof.total_memory_bytes; $base.memory_root=$lastProof.memory_root; $base.cumulative_memory_merge=$lastProof.cumulative_memory_merge; $base.existing_memory_seeded=$lastProof.existing_memory_seeded; $base.existing_memory_cells_before=[int]$lastProof.existing_memory_cells_before; $base.recall_use_status=$lastUseProof.status; $base.used_memory_cells=@($lastUseProof.used_labels); $base.baseline_decision=$lastUseProof.baseline_decision; $base.active_decision=$lastUseProof.active_decision; $base.behavior_delta=$lastUseProof.behavior_delta; $base.boundary='Real uses chunked factory output, streaming ready_atoms, cumulative compact semantic memory, recall/use proof after every chunk, in-run transient cleanup, and recovery contract wiring.'
}
WriteJson $proofPath $base 100
$schoolFinalizerPath = 'operations/school/finalize_agent_school_run_v1.ps1'
if (Test-Path $schoolFinalizerPath) {
  try {
    & powershell -NoProfile -ExecutionPolicy Bypass -File $schoolFinalizerPath -ProofPath $proofPath | Out-Host
  } catch {
    Write-Host ("FINALIZER_STATUS=FAILED:{0}" -f $_.Exception.Message)
  }
} else {
  Write-Host 'FINALIZER_STATUS=SKIPPED_FINALIZER_MISSING'
}
Write-Host "SCHOOL_RUN_STATUS=$($base.status)"
Write-Host "PROOF_PATH=$proofPath"
Write-Host "TARGET_ACCEPTED=$TargetAccepted"
Write-Host "RUN_KIND=$RunKind"
Write-Host "OUTER_CHUNK_SIZE=$outerChunkSize"
Write-Host "INNER_BATCH_SIZE_MAX=$innerBatchSizeMax"
Write-Host "CHUNK_COUNT=$($base.chunk_count)"
Write-Host "RECOVERY_WIRING_STATUS=$($base.school_recovery_wiring_status)"
Write-Host "FACTORY_CANDIDATES=$totalFactoryCandidates"
Write-Host "READY_ATOMS=$totalReadyAtoms"
Write-Host "CUMULATIVE_MEMORY_MERGE=$($base.cumulative_memory_merge)"
Write-Host "DIGESTED_CELLS=$($base.digested_cells)"
Write-Host "MERGED_COUNT=$($base.merged_count)"
Write-Host "TOTAL_MEMORY_BYTES=$($base.total_memory_bytes)"
Write-Host "RECALL_USE_STATUS=$($base.recall_use_status)"
Write-Host "BEHAVIOR_DELTA=$($base.behavior_delta)"
Write-Host "ROUTE_AFTER=$($base.route_after)"
Write-Host "LEDGER_AFTER=$($base.ledger_after)"
Write-Host 'RUNTIME_READY=false'




