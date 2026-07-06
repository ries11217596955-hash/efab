[CmdletBinding()]
param(
  [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path,
  [string]$RunId = "AUTO_NEXT_GAP_DECISION_V1_001",
  [switch]$InvokedByOrchestrator
)

$ErrorActionPreference = "Stop"

$TaskId = "TASK_AUTO_NEXT_GAP_DECISION_V1_001"
$PackId = "PHASE102_AUTO_NEXT_GAP_DECISION_V1"
$NextAllowedStep = "PHASE103_REPAIR_LOOP_GENERATOR_V1"

function Join-RepoPath {
  param([string]$Path)
  return [System.IO.Path]::GetFullPath((Join-Path $RepoRoot $Path))
}

function Read-JsonRequired {
  param([string]$Path)

  $fullPath = Join-RepoPath $Path
  if (-not (Test-Path -LiteralPath $fullPath)) {
    throw "MISSING_JSON=$Path"
  }
  return (Get-Content -LiteralPath $fullPath -Raw | ConvertFrom-Json)
}

function Write-JsonFile {
  param(
    [string]$Path,
    [object]$Object
  )

  $fullPath = Join-RepoPath $Path
  $directory = Split-Path -Parent $fullPath
  if (-not (Test-Path -LiteralPath $directory)) {
    New-Item -ItemType Directory -Path $directory -Force | Out-Null
  }
  $json = ($Object | ConvertTo-Json -Depth 100) -replace "`r`n", "`n"
  if (-not $json.EndsWith("`n")) {
    $json += "`n"
  }
  [System.IO.File]::WriteAllText($fullPath, $json, [System.Text.UTF8Encoding]::new($false))
}

function Get-PropertyInfo {
  param(
    [object]$Object,
    [string]$Name
  )

  if ($null -eq $Object) {
    return $null
  }
  return $Object.PSObject.Properties | Where-Object { $_.Name -ieq $Name } | Select-Object -First 1
}

function Get-PropertyValue {
  param(
    [object]$Object,
    [string]$Name
  )

  $property = Get-PropertyInfo -Object $Object -Name $Name
  if ($null -eq $property) {
    return $null
  }
  return $property.Value
}

function Set-PropertyValue {
  param(
    [object]$Object,
    [string]$Name,
    [object]$Value
  )

  $property = Get-PropertyInfo -Object $Object -Name $Name
  if ($null -eq $property) {
    $Object | Add-Member -NotePropertyName $Name -NotePropertyValue $Value
  } else {
    $property.Value = $Value
  }
}

function As-Array {
  param([object]$Value)

  if ($null -eq $Value) {
    return @()
  }
  if ($Value -is [System.Array]) {
    return $Value
  }
  return @($Value)
}

function Update-TaskQueue {
  $queue = Read-JsonRequired "TASK_QUEUE.json"
  Set-PropertyValue -Object $queue -Name "active_task_id" -Value "NONE"
  foreach ($task in As-Array (Get-PropertyValue -Object $queue -Name "tasks")) {
    if ("$(Get-PropertyValue -Object $task -Name "task_id")" -eq $TaskId) {
      Set-PropertyValue -Object $task -Name "status" -Value "COMPLETED"
      Set-PropertyValue -Object $task -Name "completed_at" -Value ((Get-Date).ToUniversalTime().ToString("o"))
    }
  }
  Write-JsonFile -Path "TASK_QUEUE.json" -Object $queue
}

function Update-Roadmap {
  $roadmap = Read-JsonRequired "CAPABILITY_ROADMAP.json"
  $value = [ordered]@{
    status = "COMPLETED"
    decision_kernel = "self_build_batch/next_actions/AUTO_NEXT_GAP_DECISION_KERNEL_V1.json"
    schema = "contracts/self_development/auto_next_gap_decision_v1.schema.json"
    dry_run_action_plan = "self_build_batch/next_actions/BATCH_PLAN_EXAMPLE_V1_NEXT_ACTION_PLAN_DRY_RUN.json"
    proof = "proofs/self_development/AUTO_NEXT_GAP_DECISION_V1.json"
    report = "reports/self_development/AUTO_NEXT_GAP_DECISION_V1_REPORT.json"
    next_allowed_step = $NextAllowedStep
  }
  Set-PropertyValue -Object $roadmap -Name "phase102_auto_next_gap_decision_v1" -Value $value
  Write-JsonFile -Path "CAPABILITY_ROADMAP.json" -Object $roadmap
}

function Update-GenesisState {
  $genesis = Read-JsonRequired "GENESIS_STATE.json"
  $value = [ordered]@{
    status = "PROVEN"
    decision_kernel = "self_build_batch/next_actions/AUTO_NEXT_GAP_DECISION_KERNEL_V1.json"
    schema = "contracts/self_development/auto_next_gap_decision_v1.schema.json"
    proof = "proofs/self_development/AUTO_NEXT_GAP_DECISION_V1.json"
  }
  Set-PropertyValue -Object $genesis -Name "auto_next_gap_decision_v1" -Value $value
  Write-JsonFile -Path "GENESIS_STATE.json" -Object $genesis
}

Write-Host "PHASE102_APPLY_START"

foreach ($marker in @("CAPABILITY_ROADMAP.json", "GENESIS_STATE.json", "TASK_QUEUE.json", "packs/registry.json", "orchestrator/run.ps1")) {
  if (-not (Test-Path -LiteralPath (Join-RepoPath $marker))) {
    throw "STOP=WRONG_AGENT_BUILDER_REPO missing $marker"
  }
}

$phase101Proof = Read-JsonRequired "proofs/self_development/BATCH_PROOF_AGGREGATOR_V1.json"
if ("$(Get-PropertyValue -Object $phase101Proof -Name "status")" -ne "PASS") {
  throw "PHASE101_PROOF_NOT_PASS"
}
if ("$(Get-PropertyValue -Object $phase101Proof -Name "next_allowed_step")" -ne "PHASE102_AUTO_NEXT_GAP_DECISION_V1") {
  throw "PHASE101_PROOF_NEXT_STEP_MISMATCH"
}

$summary = Read-JsonRequired "self_build_batch/proof_aggregation/BATCH_PLAN_EXAMPLE_V1_PROOF_SUMMARY_DRY_RUN.json"
if ([int](Get-PropertyValue -Object $summary -Name "unresolved_record_count") -lt 4) {
  throw "PHASE101_SUMMARY_UNRESOLVED_RECORD_COUNT_LT_4"
}
if (-not [bool](Get-PropertyValue -Object $summary -Name "no_hidden_failures")) {
  throw "PHASE101_SUMMARY_NO_HIDDEN_FAILURES_NOT_TRUE"
}

$report = & (Join-RepoPath "modules/self_development/write_auto_next_gap_decision_v1.ps1") -RepoRoot $RepoRoot
if ($null -eq $report) {
  $report = Read-JsonRequired "reports/self_development/AUTO_NEXT_GAP_DECISION_V1_REPORT.json"
}
if ("$(Get-PropertyValue -Object $report -Name "status")" -ne "PASS") {
  throw "AUTO_NEXT_GAP_DECISION_REPORT_NOT_PASS"
}
if (-not [bool](Get-PropertyValue -Object $report -Name "self_resolution_first")) {
  throw "SELF_RESOLUTION_FIRST_NOT_TRUE"
}
if (-not [bool](Get-PropertyValue -Object $report -Name "assistance_is_fallback")) {
  throw "ASSISTANCE_IS_FALLBACK_NOT_TRUE"
}
if ([bool](Get-PropertyValue -Object $report -Name "execution_allowed")) {
  throw "EXECUTION_ALLOWED_TRUE"
}
if ([string]::IsNullOrWhiteSpace("$(Get-PropertyValue -Object $report -Name "selected_next_executable_step")")) {
  throw "SELECTED_NEXT_EXECUTABLE_STEP_MISSING"
}
if ("$(Get-PropertyValue -Object $report -Name "next_allowed_step")" -ne $NextAllowedStep) {
  throw "AUTO_NEXT_GAP_DECISION_NEXT_STEP_MISMATCH"
}

Update-TaskQueue
Update-Roadmap
Update-GenesisState

Write-Host "TASK_QUEUE_RETURNED_TO_NONE"
& (Join-RepoPath "packs/$PackId/VALIDATE.ps1") -RepoRoot $RepoRoot -Stage "Completed"
Write-Host "PHASE102_APPLY_COMPLETE"
