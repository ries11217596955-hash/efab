[CmdletBinding()]
param(
  [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path,
  [string]$RunId = "SCALE_TRIAL_10_30_100_ITEM_SIMULATION_V1_001",
  [switch]$InvokedByOrchestrator
)

$ErrorActionPreference = "Stop"

$TaskId = "TASK_SCALE_TRIAL_10_30_100_ITEM_SIMULATION_V1_001"
$PackId = "PHASE105_SCALE_TRIAL_10_30_100_ITEM_SIMULATION_V1"
$Phase = "PHASE105_SCALE_TRIAL_10_30_100_ITEM_SIMULATION_V1"
$NextAllowedStep = "PHASE106_SCALE_TRIAL_PROMOTION_GATE_AND_ROUTE_LOCK_REFRESH_V1"

function Join-RepoPath {
  param([string]$Path)

  if ([System.IO.Path]::IsPathRooted($Path)) {
    return [System.IO.Path]::GetFullPath($Path)
  }
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

function Update-TaskFile {
  $task = Read-JsonRequired "tasks/TASK_SCALE_TRIAL_10_30_100_ITEM_SIMULATION_V1_001.json"
  Set-PropertyValue -Object $task -Name "status" -Value "COMPLETED"
  Set-PropertyValue -Object $task -Name "completed_by" -Value "Builder runtime"
  Set-PropertyValue -Object $task -Name "proof_path" -Value "proofs/self_development/SCALE_TRIAL_10_30_100_ITEM_SIMULATION_V1.json"
  Set-PropertyValue -Object $task -Name "completed_at" -Value ((Get-Date).ToUniversalTime().ToString("o"))
  Write-JsonFile -Path "tasks/TASK_SCALE_TRIAL_10_30_100_ITEM_SIMULATION_V1_001.json" -Object $task
}

function Update-Roadmap {
  $roadmap = Read-JsonRequired "CAPABILITY_ROADMAP.json"
  $value = [ordered]@{
    status = "COMPLETED"
    scale_trial_contract = "self_build_batch/scale_trials/SCALE_TRIAL_10_30_100_ITEM_SIMULATION_V1.json"
    schema = "contracts/self_development/scale_trial_10_30_100_item_simulation_v1.schema.json"
    scale_trial_result = "self_build_batch/scale_trials/BATCH_PLAN_EXAMPLE_V1_SCALE_TRIAL_RESULT.json"
    proof = "proofs/self_development/SCALE_TRIAL_10_30_100_ITEM_SIMULATION_V1.json"
    report = "reports/self_development/SCALE_TRIAL_10_30_100_ITEM_SIMULATION_V1_REPORT.json"
    scale_tiers = @(10, 30, 100)
    total_simulated_item_count = 140
    next_allowed_step = $NextAllowedStep
  }
  Set-PropertyValue -Object $roadmap -Name "phase105_scale_trial_10_30_100_item_simulation_v1" -Value $value
  Write-JsonFile -Path "CAPABILITY_ROADMAP.json" -Object $roadmap
}

function Update-GenesisState {
  $genesis = Read-JsonRequired "GENESIS_STATE.json"
  $value = [ordered]@{
    status = "PROVEN"
    scale_trial_contract = "self_build_batch/scale_trials/SCALE_TRIAL_10_30_100_ITEM_SIMULATION_V1.json"
    schema = "contracts/self_development/scale_trial_10_30_100_item_simulation_v1.schema.json"
    scale_trial_result = "self_build_batch/scale_trials/BATCH_PLAN_EXAMPLE_V1_SCALE_TRIAL_RESULT.json"
    proof = "proofs/self_development/SCALE_TRIAL_10_30_100_ITEM_SIMULATION_V1.json"
  }
  Set-PropertyValue -Object $genesis -Name "scale_trial_10_30_100_item_simulation_v1" -Value $value
  Set-PropertyValue -Object $genesis -Name "last_run_status" -Value "PASS"
  Write-JsonFile -Path "GENESIS_STATE.json" -Object $genesis
}

Write-Host "PHASE105_APPLY_START"

foreach ($marker in @("CAPABILITY_ROADMAP.json", "GENESIS_STATE.json", "TASK_QUEUE.json", "packs/registry.json", "orchestrator/run.ps1")) {
  if (-not (Test-Path -LiteralPath (Join-RepoPath $marker))) {
    throw "STOP=WRONG_AGENT_BUILDER_REPO missing $marker"
  }
}

$phase104Proof = Read-JsonRequired "proofs/self_development/CONTROLLED_MULTI_CYCLE_SELF_BUILD_RUN_V1.json"
if ("$(Get-PropertyValue -Object $phase104Proof -Name "status")" -ne "PASS") {
  throw "PHASE104_PROOF_NOT_PASS"
}
if ("$(Get-PropertyValue -Object $phase104Proof -Name "next_allowed_step")" -ne $Phase) {
  throw "PHASE104_PROOF_NEXT_STEP_MISMATCH"
}
if (-not [bool](Get-PropertyValue -Object $phase104Proof -Name "controlled_execution_only")) {
  throw "PHASE104_PROOF_CONTROLLED_EXECUTION_ONLY_NOT_TRUE"
}

$controlledRunResult = Read-JsonRequired "self_build_batch/controlled_runs/BATCH_PLAN_EXAMPLE_V1_CONTROLLED_MULTI_CYCLE_RUN_RESULT.json"
if ("$(Get-PropertyValue -Object $controlledRunResult -Name "run_result")" -ne "PASS") {
  throw "PHASE104_CONTROLLED_RUN_RESULT_NOT_PASS"
}
if ("$(Get-PropertyValue -Object $controlledRunResult -Name "next_allowed_step")" -ne $Phase) {
  throw "PHASE104_CONTROLLED_RUN_RESULT_NEXT_STEP_MISMATCH"
}

$report = & (Join-RepoPath "modules/self_development/write_scale_trial_10_30_100_item_simulation_v1.ps1") -RepoRoot $RepoRoot
if ($null -eq $report) {
  $report = Read-JsonRequired "reports/self_development/SCALE_TRIAL_10_30_100_ITEM_SIMULATION_V1_REPORT.json"
}
if ("$(Get-PropertyValue -Object $report -Name "status")" -ne "PASS") {
  throw "SCALE_TRIAL_REPORT_NOT_PASS"
}
if (-not [bool](Get-PropertyValue -Object $report -Name "simulation_performed")) {
  throw "SCALE_TRIAL_SIMULATION_PERFORMED_NOT_TRUE"
}
if ([bool](Get-PropertyValue -Object $report -Name "real_items_executed")) {
  throw "SCALE_TRIAL_REAL_ITEMS_EXECUTED_TRUE"
}
foreach ($falseField in @("external_fetch_performed", "external_install_performed", "external_agent_production_performed")) {
  if ([bool](Get-PropertyValue -Object $report -Name $falseField)) {
    throw "REPORT_$($falseField.ToUpperInvariant())_TRUE"
  }
}
if ("$(Get-PropertyValue -Object $report -Name "next_allowed_step")" -ne $NextAllowedStep) {
  throw "SCALE_TRIAL_NEXT_STEP_MISMATCH"
}

Update-TaskQueue
Update-TaskFile
Update-Roadmap
Update-GenesisState

Write-Host "TASK_QUEUE_RETURNED_TO_NONE"
& (Join-RepoPath "packs/$PackId/VALIDATE.ps1") -RepoRoot $RepoRoot -Stage "Completed"
Write-Host "PHASE105_APPLY_COMPLETE"
