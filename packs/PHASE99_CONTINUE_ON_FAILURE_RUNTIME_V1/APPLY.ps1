[CmdletBinding()]
param(
  [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path,
  [string]$RunId = "CONTINUE_ON_FAILURE_RUNTIME_V1_001",
  [switch]$InvokedByOrchestrator
)

$ErrorActionPreference = "Stop"

$TaskId = "TASK_CONTINUE_ON_FAILURE_RUNTIME_V1_001"
$PackId = "PHASE99_CONTINUE_ON_FAILURE_RUNTIME_V1"
$NextAllowedStep = "PHASE100_QUARANTINE_AND_BLOCKER_REGISTRY_V1"

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
    runtime_contract = "self_build_batch/runtime/CONTINUE_ON_FAILURE_RUNTIME_V1.json"
    schema = "contracts/self_development/continue_on_failure_runtime_v1.schema.json"
    simulation = "self_build_batch/runtime/CONTINUE_ON_FAILURE_SIMULATION_V1.json"
    proof = "proofs/self_development/CONTINUE_ON_FAILURE_RUNTIME_V1.json"
    report = "reports/self_development/CONTINUE_ON_FAILURE_RUNTIME_V1_REPORT.json"
    next_allowed_step = $NextAllowedStep
  }
  Set-PropertyValue -Object $roadmap -Name "phase99_continue_on_failure_runtime_v1" -Value $value
  Write-JsonFile -Path "CAPABILITY_ROADMAP.json" -Object $roadmap
}

function Update-GenesisState {
  $genesis = Read-JsonRequired "GENESIS_STATE.json"
  $value = [ordered]@{
    status = "PROVEN"
    runtime_contract = "self_build_batch/runtime/CONTINUE_ON_FAILURE_RUNTIME_V1.json"
    schema = "contracts/self_development/continue_on_failure_runtime_v1.schema.json"
    proof = "proofs/self_development/CONTINUE_ON_FAILURE_RUNTIME_V1.json"
  }
  Set-PropertyValue -Object $genesis -Name "continue_on_failure_runtime_v1" -Value $value
  Write-JsonFile -Path "GENESIS_STATE.json" -Object $genesis
}

Write-Host "PHASE99_APPLY_START"

foreach ($marker in @("CAPABILITY_ROADMAP.json", "GENESIS_STATE.json", "TASK_QUEUE.json", "packs/registry.json", "orchestrator/run.ps1")) {
  if (-not (Test-Path -LiteralPath (Join-RepoPath $marker))) {
    throw "STOP=WRONG_AGENT_BUILDER_REPO missing $marker"
  }
}

$phase98Proof = Read-JsonRequired "proofs/self_development/ITEM_LEVEL_EXECUTION_LEDGER_V1.json"
if ("$(Get-PropertyValue -Object $phase98Proof -Name "status")" -ne "PASS") {
  throw "PHASE98_PROOF_NOT_PASS"
}
if ("$(Get-PropertyValue -Object $phase98Proof -Name "next_allowed_step")" -ne "PHASE99_CONTINUE_ON_FAILURE_RUNTIME_V1") {
  throw "PHASE98_PROOF_NEXT_STEP_MISMATCH"
}

$dryRunLedger = Read-JsonRequired "self_build_batch/ledger/BATCH_PLAN_EXAMPLE_V1_LEDGER_DRY_RUN.json"
if ([bool](Get-PropertyValue -Object $dryRunLedger -Name "execution_attempted")) {
  throw "DRY_RUN_LEDGER_EXECUTION_ATTEMPTED_TRUE"
}

$report = & (Join-RepoPath "modules/self_development/write_continue_on_failure_runtime_v1.ps1") -RepoRoot $RepoRoot
if ($null -eq $report) {
  $report = Read-JsonRequired "reports/self_development/CONTINUE_ON_FAILURE_RUNTIME_V1_REPORT.json"
}
if ("$(Get-PropertyValue -Object $report -Name "status")" -ne "PASS") {
  throw "CONTINUE_ON_FAILURE_RUNTIME_REPORT_NOT_PASS"
}
if ([bool](Get-PropertyValue -Object $report -Name "execution_performed")) {
  throw "EXECUTION_PERFORMED_TRUE"
}
if ([bool](Get-PropertyValue -Object $report -Name "real_items_marked_pass")) {
  throw "REAL_ITEMS_MARKED_PASS_TRUE"
}
if (-not [bool](Get-PropertyValue -Object $report -Name "no_real_ledger_mutation")) {
  throw "NO_REAL_LEDGER_MUTATION_GUARANTEE_MISSING"
}
if ("$(Get-PropertyValue -Object $report -Name "next_allowed_step")" -ne $NextAllowedStep) {
  throw "CONTINUE_ON_FAILURE_RUNTIME_NEXT_STEP_MISMATCH"
}

Update-TaskQueue
Update-Roadmap
Update-GenesisState

Write-Host "TASK_QUEUE_RETURNED_TO_NONE"
& (Join-RepoPath "packs/$PackId/VALIDATE.ps1") -RepoRoot $RepoRoot -Stage "Completed"
Write-Host "PHASE99_APPLY_COMPLETE"
