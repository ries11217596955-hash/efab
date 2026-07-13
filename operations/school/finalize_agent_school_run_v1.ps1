param(
  [Parameter(Mandatory=$true)][string]$ProofPath,
  [string]$PolicyPath = "operations/school/school_lifecycle_policy.json"
)
$ErrorActionPreference = 'Stop'
$RepoRoot = (git rev-parse --show-toplevel).Trim()
Set-Location $RepoRoot
function WriteJson($Path,$Obj,$Depth=40){
  $dir=Split-Path $Path -Parent
  if($dir){ New-Item -ItemType Directory -Force -Path $dir | Out-Null }
  $Obj | ConvertTo-Json -Depth $Depth | Set-Content -LiteralPath $Path -Encoding UTF8
}
function Slug($s){
  return (([string]$s) -replace '[^A-Za-z0-9_.-]','_')
}
function InvokeSchoolPacketMergeQueue($FinalizerPolicy,$QueuePath){
  $cfg=$FinalizerPolicy.merge_queue_after_intake
  if(-not $cfg -or -not [bool]$cfg.enabled){ return [ordered]@{ status='SKIPPED_MERGE_QUEUE_DISABLED' } }
  if(-not $QueuePath){ return [ordered]@{ status='SKIPPED_MERGE_QUEUE_NO_QUEUE_PATH' } }
  if(-not (Test-Path $QueuePath)){ return [ordered]@{ status='SKIPPED_MERGE_QUEUE_PACKET_MISSING'; queue_path=$QueuePath } }
  if(Test-Path '.runtime/compact_memory_intake_v1/MERGE_QUEUE.lock.json'){ return [ordered]@{ status='SKIPPED_MERGE_QUEUE_LOCK_EXISTS'; queue_path=$QueuePath } }
  $dirty=@(git status --short --untracked-files=all | ForEach-Object{[string]$_})
  if([bool]$cfg.require_repo_clean_before_merge -and $dirty.Count -gt 0){ return [ordered]@{ status='SKIPPED_MERGE_QUEUE_REPO_DIRTY'; queue_path=$QueuePath; dirty=@($dirty) } }
  $limit=1
  if($cfg.process_limit){ $limit=[int]$cfg.process_limit }
  $out=@(& powershell -NoProfile -ExecutionPolicy Bypass -File operations/compact_memory_intake/merge_compact_memory_intake_queue_v1.ps1 -PacketPath $QueuePath -ProcessLimit $limit *>&1 | ForEach-Object{[string]$_})
  $status=($out|Where-Object{$_ -match '^MERGE_QUEUE_STATUS='}|Select-Object -Last 1) -replace '^MERGE_QUEUE_STATUS=',''
  $proof=($out|Where-Object{$_ -match '^MERGE_QUEUE_PROOF='}|Select-Object -Last 1) -replace '^MERGE_QUEUE_PROOF=',''
  return [ordered]@{ status=$status; proof=$proof; queue_path=$QueuePath; output=@($out) }
}
function SubmitSchoolPacketToIntake($Proof,$RunId,$ProofPath,$Manifest,$ManifestPath){
  $submitPath='operations/compact_memory_intake/submit_compact_memory_packet_v1.ps1'
  if(-not (Test-Path $submitPath)){ return [ordered]@{ status='SKIPPED_INTAKE_SUBMITTER_MISSING'; submitter=$submitPath } }
  $packetRoot='operations/reports'
  New-Item -ItemType Directory -Force -Path $packetRoot | Out-Null
  $safeRunId=([string]$RunId) -replace '[^A-Za-z0-9_.-]','_'
  $packetPath=Join-Path $packetRoot ("SCHOOL_KNOWLEDGE_PACKET_$safeRunId.json")
  $ready=[int]$Proof.ready_atoms
  $maturityDelta=[Math]::Min(5,[Math]::Max(0.1,($ready/100000.0)))
  $topic='school_live_growth'
  if($Proof.topics_plan){ $topic='school_topics_plan' }
  $packet=[ordered]@{
    schema='compact_memory_knowledge_packet_v1'
    source_kind='School'
    source_id=$RunId
    created_at=(Get-Date).ToString('o')
    quality_summary=[ordered]@{ atom_count=$ready; chunk_count=[int]@($Proof.chunks).Count; proof_status=$Proof.status; semantic_growth=$true; note='Compact summary packet for completed school run; raw atoms remain in runtime proof pipeline.' }
    atoms=@([ordered]@{ id="school-summary:$RunId"; topic=$topic; level=5; quality_score=1.0; novelty_score=0.7; proof_ref=$ProofPath; behavior_use_hint='Use fresh school memory before next autonomous path selection; prefer tasks that exploit newly accepted concepts.' })
    influence=[ordered]@{ maturity_delta=$maturityDelta; memory_support_policy='USE_SCHOOL_MEMORY_WHEN_SELECTED_PATH_TOPIC_MATCHES'; focus_boosts=@('fresh_school_memory','recall_use_behavior_delta','avoid_idle_repeat') }
    refs=[ordered]@{ proof_path=$ProofPath; active_memory_manifest=$ManifestPath; memory_run_id=$Manifest.run_id; memory_cells_sha256=$Manifest.cells_sha256 }
  }
  WriteJson $packetPath $packet 50
  $out=@(& powershell -NoProfile -ExecutionPolicy Bypass -File $submitPath -PacketPath $packetPath *>&1 | ForEach-Object {[string]$_})
  $status=($out|Where-Object{$_ -match '^INTAKE_STATUS='}|Select-Object -Last 1) -replace '^INTAKE_STATUS=',''
  $growth=($out|Where-Object{$_ -match '^GROWTH_SIGNAL_PATH='}|Select-Object -Last 1) -replace '^GROWTH_SIGNAL_PATH=',''
  $queue=($out|Where-Object{$_ -match '^INTAKE_QUEUE_PATH='}|Select-Object -Last 1) -replace '^INTAKE_QUEUE_PATH=',''
  return [ordered]@{ status=$status; packet_path=$packetPath; queue_path=$queue; growth_signal_path=$growth; output=@($out) }
}
function InvokeQueueMaintenanceAfterSchoolMerge($FinalizerPolicy,$SchoolMergeResult){
  $cfg=$FinalizerPolicy.queue_maintenance_after_school_merge
  if(-not $cfg -or -not [bool]$cfg.enabled){ return [ordered]@{ status='SKIPPED_QUEUE_MAINTENANCE_DISABLED' } }
  if([bool]$cfg.require_school_merge_pass -and $SchoolMergeResult.status -ne 'PASS_MULTI_SOURCE_COMPACT_MEMORY_MERGE_QUEUE_V1'){
    return [ordered]@{ status='SKIPPED_QUEUE_MAINTENANCE_SCHOOL_MERGE_NOT_PASS'; school_merge_status=$SchoolMergeResult.status }
  }
  if(Test-Path '.runtime/compact_memory_intake_v1/MERGE_QUEUE.lock.json'){
    return [ordered]@{ status='SKIPPED_QUEUE_MAINTENANCE_LOCK_EXISTS_AFTER_SCHOOL_MERGE' }
  }
  $runner='operations/compact_memory_intake/run_compact_memory_queue_maintenance_v1.ps1'
  if(-not (Test-Path $runner)){ return [ordered]@{ status='SKIPPED_QUEUE_MAINTENANCE_RUNNER_MISSING'; runner=$runner } }
  $sources=@($cfg.allowed_source_kinds)
  if($sources.Count -lt 1){ $sources=@('AgentLife') }
  $limit=if($cfg.process_limit){ [int]$cfg.process_limit } else { 1 }
  $timeout=if($cfg.merge_timeout_seconds){ [int]$cfg.merge_timeout_seconds } else { 180 }
  $out=@(& powershell -NoProfile -ExecutionPolicy Bypass -File $runner -AllowedSourceKinds $sources -ProcessLimit $limit -MergeTimeoutSeconds $timeout *>&1 | ForEach-Object{[string]$_})
  $status=($out|Where-Object{$_ -match '^QUEUE_MAINTENANCE_STATUS='}|Select-Object -Last 1) -replace '^QUEUE_MAINTENANCE_STATUS=',''
  $proof=($out|Where-Object{$_ -match '^QUEUE_MAINTENANCE_PROOF='}|Select-Object -Last 1) -replace '^QUEUE_MAINTENANCE_PROOF=',''
  $processed=($out|Where-Object{$_ -match '^QUEUE_MAINTENANCE_PROCESSED='}|Select-Object -Last 1) -replace '^QUEUE_MAINTENANCE_PROCESSED=',''
  return [ordered]@{ status=$status; proof=$proof; processed_count=if($processed -match '^\d+$'){[int]$processed}else{0}; allowed_source_kinds=@($sources); process_limit=$limit; merge_timeout_seconds=$timeout; output=@($out|Select-Object -Last 80) }
}
if(-not (Test-Path $ProofPath)){ throw "PROOF_PATH_MISSING:$ProofPath" }
if(-not (Test-Path $PolicyPath)){ throw "POLICY_PATH_MISSING:$PolicyPath" }
$startedAt = Get-Date
$status = 'FINALIZER_NOT_RUN'
$actions = @()
$blockers = @()
$policy = Get-Content $PolicyPath -Raw | ConvertFrom-Json
$finalizer = $policy.finalizer
$proof = Get-Content $ProofPath -Raw | ConvertFrom-Json
$runId = if($proof.run_id){ [string]$proof.run_id } else { [IO.Path]::GetFileName((Split-Path $ProofPath -Parent)) }
$publicMode = [string]$proof.public_mode
$target = [int]$proof.target_accepted
$ready = [int]$proof.ready_atoms
$chunkCount = [int]@($proof.chunks).Count
$passStatus = ([string]$proof.status -match '^PASS_')
$manifestPath = '.runtime/active_compact_semantic_memory_v1/manifest.json'
$manifest = $null
if(Test-Path $manifestPath){ $manifest = Get-Content $manifestPath -Raw | ConvertFrom-Json }
$gitHead = (git rev-parse HEAD).Trim()
$branch = (git rev-parse --abbrev-ref HEAD).Trim()
$gitStatusBefore = @((git status --short --untracked-files=all) | ForEach-Object { [string]$_ })
$result=[ordered]@{
  schema='school_run_finalizer_result_v1'
  finalizer_status='STARTED'
  started_at=$startedAt.ToString('o')
  finished_at=$null
  repo_head_before=$gitHead
  branch=$branch
  proof_path=$ProofPath
  proof_status=$proof.status
  run_id=$runId
  public_mode=$publicMode
  target_accepted=$target
  ready_atoms=$ready
  chunk_count=$chunkCount
  runtime_ready=$proof.runtime_ready
  pass_status=$passStatus
  active_memory_after=if($manifest){[ordered]@{manifest_path=$manifestPath; run_id=$manifest.run_id; cell_count=$manifest.cell_count; merged_count=$manifest.merged_count; total_memory_bytes=$manifest.total_memory_bytes; cells_sha256=$manifest.cells_sha256; index_sha256=$manifest.index_sha256; runtime_ready=$manifest.runtime_ready}}else{$null}
  git_status_before=@($gitStatusBefore)
  actions=@()
  blockers=@()
  tracked_summary_path=$null
  commit=$null
  boundary=$finalizer.boundary
  intake_submission=$null
}
if($passStatus -and $manifest){
  $result.intake_submission = SubmitSchoolPacketToIntake $proof $runId $ProofPath $manifest $manifestPath
  $actions += "SUBMITTED_INTAKE:$($result.intake_submission.status)"
  $result.merge_queue_result = InvokeSchoolPacketMergeQueue $finalizer $result.intake_submission.queue_path
  $actions += "MERGE_QUEUE:$($result.merge_queue_result.status)"
  $result.queue_maintenance_result = InvokeQueueMaintenanceAfterSchoolMerge $finalizer $result.merge_queue_result
  $actions += "QUEUE_MAINTENANCE:$($result.queue_maintenance_result.status)"
  if($result.queue_maintenance_result.status -like 'FAIL_*'){ $blockers += $result.queue_maintenance_result.status }
}
if(-not [bool]$finalizer.enabled){
  $status='FINALIZER_DISABLED_BY_POLICY'
  $blockers += $status
} elseif(-not $passStatus){
  $status='FINALIZER_SKIPPED_NON_PASS_PROOF'
  $blockers += "NON_PASS_STATUS:$($proof.status)"
} else {
  if([bool]$finalizer.runtime_record_enabled){
    $runtimeRoot=[string]$finalizer.runtime_report_root
    New-Item -ItemType Directory -Force -Path $runtimeRoot | Out-Null
    $runtimeJson=Join-Path $runtimeRoot ("SCHOOL_RUN_FINALIZER_{0}.json" -f (Slug $runId))
    $result.finalizer_status='RUNTIME_RECORD_WRITING'
    WriteJson $runtimeJson $result 50
    $actions += "WROTE_RUNTIME_RECORD:$runtimeJson"
  }
  $modeAllowed = @($finalizer.commit_modes) -contains $publicMode
  if(-not [bool]$finalizer.tracked_summary_enabled){
    $status='FINALIZER_RUNTIME_ONLY_TRACKED_DISABLED'
    $blockers += 'TRACKED_SUMMARY_DISABLED'
  } elseif(-not $modeAllowed){
    $status='FINALIZER_RUNTIME_ONLY_MODE_NOT_COMMITTABLE'
    $blockers += "MODE_NOT_COMMITTABLE:$publicMode"
  } elseif([bool]$finalizer.require_repo_clean_before_commit -and $gitStatusBefore.Count -gt 0){
    $status='FINALIZER_RUNTIME_ONLY_REPO_DIRTY_BEFORE_SUMMARY'
    $blockers += 'REPO_DIRTY_BEFORE_FINALIZER'
  } else {
    $root=[string]$finalizer.tracked_summary_root
    New-Item -ItemType Directory -Force -Path $root | Out-Null
    $date=Get-Date -Format 'yyyyMMdd_HHmmss'
    $summaryPath=Join-Path $root ("SCHOOL_RUN_RESULT_{0}_{1}_{2}_{3}.md" -f $date,(Slug $publicMode),$target,(Slug $runId))
    $md=@"
# School Run Result - $runId

Status: PROVEN_LIVE

## Result

- School status: $($proof.status)
- Public mode: $publicMode
- Target accepted: $target
- Ready atoms: $ready
- Chunks: $chunkCount
- Runtime ready: $($proof.runtime_ready)

## Proof refs

- Canonical proof: $ProofPath
- Active memory manifest: $manifestPath
- Intake growth signal: $($result.intake_submission.growth_signal_path)

## Active compact memory after run

- run_id: $($manifest.run_id)
- cell_count: $($manifest.cell_count)
- merged_count: $($manifest.merged_count)
- total_memory_bytes: $($manifest.total_memory_bytes)
- cells_sha256: $($manifest.cells_sha256)
- index_sha256: $($manifest.index_sha256)
- runtime_ready: $($manifest.runtime_ready)

## Boundary

This finalizer records compact school evidence only. It does not commit raw `.runtime` files and does not change the three-field owner launch contract. The current school uses the local cursor-guided Codex-curriculum candidate factory unless a separate governed Codex-source lane is wired and proven. School PASS also submits a compact knowledge packet to multi-source compact memory intake so autonomous life can react to new knowledge.
"@
    Set-Content -LiteralPath $summaryPath -Value $md -Encoding UTF8
    $check = Get-Content $summaryPath -Raw
    foreach($must in @('Status: PROVEN_LIVE', [string]$proof.status, 'Target accepted:', 'Ready atoms:', 'Boundary')){ if($check -notmatch [regex]::Escape($must)){ throw "TRACKED_SUMMARY_VALIDATION_MISSING:$must" } }
    $result.tracked_summary_path=$summaryPath
    $actions += "WROTE_TRACKED_SUMMARY:$summaryPath"
    if([bool]$finalizer.auto_commit_tracked_summary){
      git add -- $summaryPath
      $msg = "{0}: {1} {2}" -f ([string]$finalizer.commit_message_prefix),$publicMode,$target
      git commit -m $msg | Out-Host
      $commit=(git rev-parse HEAD).Trim()
      $result.commit=$commit
      $actions += "COMMITTED:$commit"
      $status='FINALIZER_COMMITTED_TRACKED_SUMMARY'
    } else {
      $status='FINALIZER_TRACKED_SUMMARY_WRITTEN_NO_COMMIT'
      $blockers += 'AUTO_COMMIT_DISABLED'
    }
  }
}
$result.finalizer_status=$status
$result.actions=@($actions)
$result.blockers=@($blockers)
$result.finished_at=(Get-Date).ToString('o')
$runtimeRoot=[string]$finalizer.runtime_report_root
if(-not $runtimeRoot){ $runtimeRoot='operations/reports' }
New-Item -ItemType Directory -Force -Path $runtimeRoot | Out-Null
$finalRuntimeJson=Join-Path $runtimeRoot ("SCHOOL_RUN_FINALIZER_{0}.json" -f (Slug $runId))
WriteJson $finalRuntimeJson $result 50
Write-Host "FINALIZER_STATUS=$($result.finalizer_status)"
Write-Host "FINALIZER_RUNTIME_RECORD=$finalRuntimeJson"
if($result.intake_submission){ Write-Host "FINALIZER_INTAKE_STATUS=$($result.intake_submission.status)"; Write-Host "FINALIZER_INTAKE_QUEUE=$($result.intake_submission.queue_path)"; Write-Host "FINALIZER_GROWTH_SIGNAL=$($result.intake_submission.growth_signal_path)" }
if($result.merge_queue_result){ Write-Host "FINALIZER_MERGE_QUEUE_STATUS=$($result.merge_queue_result.status)"; if($result.merge_queue_result.proof){ Write-Host "FINALIZER_MERGE_QUEUE_PROOF=$($result.merge_queue_result.proof)" } }
if($result.queue_maintenance_result){ Write-Host "FINALIZER_QUEUE_MAINTENANCE_STATUS=$($result.queue_maintenance_result.status)"; Write-Host "FINALIZER_QUEUE_MAINTENANCE_PROCESSED=$($result.queue_maintenance_result.processed_count)"; if($result.queue_maintenance_result.proof){ Write-Host "FINALIZER_QUEUE_MAINTENANCE_PROOF=$($result.queue_maintenance_result.proof)" } }
if($result.tracked_summary_path){ Write-Host "FINALIZER_TRACKED_SUMMARY=$($result.tracked_summary_path)" }
if($result.commit){ Write-Host "FINALIZER_COMMIT=$($result.commit)" }
if($result.blockers.Count -gt 0){ Write-Host "FINALIZER_BLOCKERS=$($result.blockers -join ',')" }