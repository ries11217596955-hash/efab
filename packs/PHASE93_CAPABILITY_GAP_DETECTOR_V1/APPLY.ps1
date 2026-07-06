$ErrorActionPreference = "Stop"

Write-Output "PHASE93_APPLY_START"

function Read-Json($Path) {
  return Get-Content $Path -Raw | ConvertFrom-Json
}

function Write-Json($Path, $Obj) {
  $dir = Split-Path $Path -Parent
  if ($dir -and -not (Test-Path $dir)) {
    New-Item -ItemType Directory -Force -Path $dir | Out-Null
  }
  $Obj | ConvertTo-Json -Depth 80 | Set-Content -Path $Path -Encoding UTF8
}

function Set-Prop($Obj, $Name, $Value) {
  if ($Obj.PSObject.Properties[$Name]) {
    $Obj.$Name = $Value
  } else {
    $Obj | Add-Member -NotePropertyName $Name -NotePropertyValue $Value
  }
}

$TaskId = "TASK_CAPABILITY_GAP_DETECTOR_V1_001"
$ModulePath = "modules/self_development/write_capability_gap_detector_v1.ps1"

$SchemaPath = "contracts/self_development/capability_gap_detector_v1.schema.json"
$DetectorPath = "self_build_backlog/CAPABILITY_GAP_DETECTOR_V1.json"
$GapIndexPath = "self_build_backlog/CAPABILITY_GAP_INDEX_V1.json"
$ReportPath = "reports/self_development/CAPABILITY_GAP_DETECTOR_REPORT.json"
$ProofPath = "proofs/self_development/CAPABILITY_GAP_DETECTOR_V1.json"
$Phase92ProofPath = "proofs/self_development/SELF_BUILD_BACKLOG_CONTRACT_V1.json"
$BacklogContractPath = "self_build_backlog/SELF_BUILD_BACKLOG_CONTRACT_V1.json"
$RouteLockPath = "AGENT_BUILDER_NEXT_15_STEPS_LOCK_V2_R2.md"

. $ModulePath

Write-Output "CAPABILITY_GAP_DETECTOR_START"

Write-CapabilityGapDetectorArtifacts `
  -SchemaPath $SchemaPath `
  -DetectorPath $DetectorPath `
  -GapIndexPath $GapIndexPath `
  -ReportPath $ReportPath `
  -ProofPath $ProofPath `
  -Phase92ProofPath $Phase92ProofPath `
  -BacklogContractPath $BacklogContractPath `
  -RouteLockPath $RouteLockPath

$Queue = Read-Json "TASK_QUEUE.json"
Set-Prop $Queue "active_task_id" "NONE"

$tasks = @()
if ($Queue.PSObject.Properties["tasks"] -and $null -ne $Queue.tasks) {
  $tasks = @($Queue.tasks)
}

$found = $false
for ($i = 0; $i -lt $tasks.Count; $i++) {
  if ($tasks[$i].task_id -eq $TaskId) {
    $tasks[$i].status = "COMPLETED"
    $tasks[$i] | Add-Member -NotePropertyName "completed_by" -NotePropertyValue "Builder runtime" -Force
    $tasks[$i] | Add-Member -NotePropertyName "proof_path" -NotePropertyValue $ProofPath -Force
    $found = $true
  }
}

if (-not $found) {
  $tasks += [pscustomobject][ordered]@{
    task_id = $TaskId
    phase = "PHASE93_CAPABILITY_GAP_DETECTOR_V1"
    status = "COMPLETED"
    completed_by = "Builder runtime"
    proof_path = $ProofPath
  }
}

Set-Prop $Queue "tasks" @($tasks)
Write-Json "TASK_QUEUE.json" $Queue
Write-Output "TASK_QUEUE_RETURNED_TO_NONE"

$Roadmap = Read-Json "CAPABILITY_ROADMAP.json"
Set-Prop $Roadmap "phase93_capability_gap_detector_v1" ([ordered]@{
  status = "COMPLETED"
  detector = $DetectorPath
  gap_index = $GapIndexPath
  proof = $ProofPath
  report = $ReportPath
  next_allowed_step = "PHASE94_OWNER_ORDER_TO_GAP_MAP_V1"
})
Write-Json "CAPABILITY_ROADMAP.json" $Roadmap

$Genesis = Read-Json "GENESIS_STATE.json"
Set-Prop $Genesis "capability_gap_detector_v1" ([ordered]@{
  status = "PROVEN"
  detector = $DetectorPath
  gap_index = $GapIndexPath
  proof = $ProofPath
})
Write-Json "GENESIS_STATE.json" $Genesis

Write-Output "CAPABILITY_GAP_DETECTOR_COMPLETE"

& "$PSScriptRoot/VALIDATE.ps1"
if ($LASTEXITCODE -ne 0) {
  exit $LASTEXITCODE
}

Write-Output "PHASE93_APPLY_COMPLETE"
exit 0
