$ErrorActionPreference = "Stop"

function Read-Json($Path) {
  return Get-Content $Path -Raw | ConvertFrom-Json
}

function Assert-File($Path) {
  if (-not (Test-Path $Path)) {
    throw "REQUIRED_FILE_MISSING=$Path"
  }
}

$TaskId = "TASK_CAPABILITY_GAP_DETECTOR_V1_001"
$PackId = "PHASE93_CAPABILITY_GAP_DETECTOR_V1"

$SchemaPath = "contracts/self_development/capability_gap_detector_v1.schema.json"
$DetectorPath = "self_build_backlog/CAPABILITY_GAP_DETECTOR_V1.json"
$GapIndexPath = "self_build_backlog/CAPABILITY_GAP_INDEX_V1.json"
$ReportPath = "reports/self_development/CAPABILITY_GAP_DETECTOR_REPORT.json"
$ProofPath = "proofs/self_development/CAPABILITY_GAP_DETECTOR_V1.json"

$Phase92ProofPath = "proofs/self_development/SELF_BUILD_BACKLOG_CONTRACT_V1.json"
$BacklogContractPath = "self_build_backlog/SELF_BUILD_BACKLOG_CONTRACT_V1.json"
$RouteLockPath = "AGENT_BUILDER_NEXT_15_STEPS_LOCK_V2_R2.md"

$outputs = @($SchemaPath, $DetectorPath, $GapIndexPath, $ReportPath, $ProofPath)
$existingOutputs = @($outputs | Where-Object { Test-Path $_ })

if ($existingOutputs.Count -gt 0 -and $existingOutputs.Count -lt $outputs.Count) {
  throw "PARTIAL_OUTPUT_STATE=$($existingOutputs -join ',')"
}

if ($existingOutputs.Count -eq $outputs.Count) {
  Write-Output "VALIDATION_STAGE=Completed"

  foreach ($p in $outputs) {
    Assert-File $p
    Get-Content $p -Raw | ConvertFrom-Json | Out-Null
  }

  $Queue = Read-Json "TASK_QUEUE.json"
  $Detector = Read-Json $DetectorPath
  $GapIndex = Read-Json $GapIndexPath
  $Report = Read-Json $ReportPath
  $Proof = Read-Json $ProofPath

  if ($Detector.status -ne "ACTIVE_DETECTOR_CONTRACT") {
    throw "DETECTOR_STATUS_UNEXPECTED=$($Detector.status)"
  }

  if ($GapIndex.status -ne "ACTIVE_GAP_INDEX") {
    throw "GAP_INDEX_STATUS_UNEXPECTED=$($GapIndex.status)"
  }

  if ($GapIndex.detected_gap_count -lt 1) {
    throw "GAP_INDEX_DETECTED_GAP_COUNT_TOO_LOW=$($GapIndex.detected_gap_count)"
  }

  if ($GapIndex.next_primary_gap -ne "PHASE94_OWNER_ORDER_TO_GAP_MAP_V1") {
    throw "GAP_INDEX_NEXT_PRIMARY_GAP_UNEXPECTED=$($GapIndex.next_primary_gap)"
  }

  $gapIds = @($GapIndex.gaps | ForEach-Object { $_.gap_id })

  $requiredGaps = @(
    "PHASE94_OWNER_ORDER_TO_GAP_MAP_V1",
    "PHASE96_BATCH_PLANNER_V1",
    "PHASE98_ITEM_LEVEL_EXECUTION_LEDGER_V1",
    "PHASE100_QUARANTINE_AND_BLOCKER_REGISTRY_V1",
    "PHASE105_SCALE_TRIAL_10_TO_30_TO_100_TASKS_V1"
  )

  foreach ($g in $requiredGaps) {
    if (-not ($gapIds -contains $g)) {
      throw "GAP_INDEX_MISSING_GAP=$g"
    }
  }

  if ($Report.status -ne "PASS") { throw "REPORT_STATUS_NOT_PASS=$($Report.status)" }
  if ($Report.phase -ne $PackId) { throw "REPORT_PHASE_UNEXPECTED=$($Report.phase)" }
  if ($Report.next_allowed_step -ne "PHASE94_OWNER_ORDER_TO_GAP_MAP_V1") {
    throw "REPORT_NEXT_ALLOWED_STEP_UNEXPECTED=$($Report.next_allowed_step)"
  }

  if ($Proof.status -ne "PASS") { throw "PROOF_STATUS_NOT_PASS=$($Proof.status)" }
  if ($Proof.phase -ne $PackId) { throw "PROOF_PHASE_UNEXPECTED=$($Proof.phase)" }
  if ($Proof.task_id -ne $TaskId) { throw "PROOF_TASK_ID_UNEXPECTED=$($Proof.task_id)" }
  if ($Proof.runtime_mode -ne "SELF_BUILD") { throw "PROOF_RUNTIME_MODE_UNEXPECTED=$($Proof.runtime_mode)" }
  if ($Proof.route_lock_version -ne "V2_R2") { throw "PROOF_ROUTE_LOCK_VERSION_UNEXPECTED=$($Proof.route_lock_version)" }
  if ($Proof.no_external_agent_production -ne $true) { throw "PROOF_EXTERNAL_AGENT_PRODUCTION_NOT_BLOCKED" }
  if ($Proof.no_external_install -ne $true) { throw "PROOF_EXTERNAL_INSTALL_NOT_BLOCKED" }
  if ($Proof.no_external_fetch -ne $true) { throw "PROOF_EXTERNAL_FETCH_NOT_BLOCKED" }
  if ($Proof.queue_returned_to_none -ne $true) { throw "PROOF_QUEUE_RETURNED_TO_NONE_NOT_TRUE" }
  if ($Proof.next_allowed_step -ne "PHASE94_OWNER_ORDER_TO_GAP_MAP_V1") {
    throw "PROOF_NEXT_ALLOWED_STEP_UNEXPECTED=$($Proof.next_allowed_step)"
  }

  if ($Queue.active_task_id -ne "NONE") {
    throw "ACTIVE_TASK_ID_NOT_NONE=$($Queue.active_task_id)"
  }

  $task = @($Queue.tasks | Where-Object { $_.task_id -eq $TaskId })
  if ($task.Count -ne 1) {
    throw "TASK_COUNT_NOT_ONE=$($task.Count)"
  }
  if ($task[0].status -ne "COMPLETED") {
    throw "TASK_STATUS_NOT_COMPLETED=$($task[0].status)"
  }

  Write-Output "VALIDATION_RESULT=PASS"
  exit 0
}

Write-Output "VALIDATION_STAGE=Seed"

$requiredSeed = @(
  "packs/PHASE93_CAPABILITY_GAP_DETECTOR_V1/PACK.json",
  "packs/PHASE93_CAPABILITY_GAP_DETECTOR_V1/APPLY.ps1",
  "packs/PHASE93_CAPABILITY_GAP_DETECTOR_V1/VALIDATE.ps1",
  "tasks/TASK_CAPABILITY_GAP_DETECTOR_V1_001.json",
  "modules/self_development/write_capability_gap_detector_v1.ps1",
  "TASK_QUEUE.json",
  "packs/registry.json",
  "CAPABILITY_ROADMAP.json",
  "GENESIS_STATE.json",
  $RouteLockPath,
  $Phase92ProofPath,
  $BacklogContractPath
)

foreach ($p in $requiredSeed) {
  Assert-File $p
}

$Phase92Proof = Read-Json $Phase92ProofPath
if ($Phase92Proof.status -ne "PASS") {
  throw "PHASE92_PROOF_STATUS_NOT_PASS=$($Phase92Proof.status)"
}
if ($Phase92Proof.next_allowed_step -ne "PHASE93_CAPABILITY_GAP_DETECTOR_V1") {
  throw "PHASE92_NEXT_ALLOWED_STEP_UNEXPECTED=$($Phase92Proof.next_allowed_step)"
}

$Queue = Read-Json "TASK_QUEUE.json"
$Registry = Read-Json "packs/registry.json"

if ($Queue.active_task_id -ne $TaskId) {
  throw "ACTIVE_TASK_ID_NOT_PHASE93=$($Queue.active_task_id)"
}

$selected = @($Registry.packs | Where-Object {
  ($_.PSObject.Properties.Name -contains "task_id") -and
  ($_.task_id -eq $Queue.active_task_id)
})

if ($selected.Count -ne 1) {
  throw "SELECTED_PACK_COUNT_NOT_ONE=$($selected.Count)"
}

if ($selected[0].pack_id -ne $PackId) {
  throw "SELECTED_PACK_NOT_PHASE93=$($selected[0].pack_id)"
}

Write-Output "VALIDATION_RESULT=PASS_SEED"
exit 0
