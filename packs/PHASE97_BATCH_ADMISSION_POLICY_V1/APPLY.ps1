[CmdletBinding()]
param(
  [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path,
  [string]$RunId = "BATCH_ADMISSION_POLICY_V1_001",
  [switch]$InvokedByOrchestrator
)

$ErrorActionPreference = "Stop"

$TaskId = "TASK_BATCH_ADMISSION_POLICY_V1_001"
$PackId = "PHASE97_BATCH_ADMISSION_POLICY_V1"
$NextAllowedStep = "PHASE98_ITEM_LEVEL_EXECUTION_LEDGER_V1"

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
    policy = "self_build_batch/admission/BATCH_ADMISSION_POLICY_V1.json"
    schema = "contracts/self_development/batch_admission_policy_v1.schema.json"
    admission = "self_build_batch/admission/BATCH_PLAN_EXAMPLE_V1_ADMISSION.json"
    proof = "proofs/self_development/BATCH_ADMISSION_POLICY_V1.json"
    report = "reports/self_development/BATCH_ADMISSION_POLICY_V1_REPORT.json"
    next_allowed_step = $NextAllowedStep
  }
  Set-PropertyValue -Object $roadmap -Name "phase97_batch_admission_policy_v1" -Value $value
  Write-JsonFile -Path "CAPABILITY_ROADMAP.json" -Object $roadmap
}

function Update-GenesisState {
  $genesis = Read-JsonRequired "GENESIS_STATE.json"
  $value = [ordered]@{
    status = "PROVEN"
    policy = "self_build_batch/admission/BATCH_ADMISSION_POLICY_V1.json"
    schema = "contracts/self_development/batch_admission_policy_v1.schema.json"
    proof = "proofs/self_development/BATCH_ADMISSION_POLICY_V1.json"
  }
  Set-PropertyValue -Object $genesis -Name "batch_admission_policy_v1" -Value $value
  Write-JsonFile -Path "GENESIS_STATE.json" -Object $genesis
}

Write-Host "PHASE97_APPLY_START"

foreach ($marker in @("CAPABILITY_ROADMAP.json", "GENESIS_STATE.json", "TASK_QUEUE.json", "packs/registry.json", "orchestrator/run.ps1")) {
  if (-not (Test-Path -LiteralPath (Join-RepoPath $marker))) {
    throw "STOP=WRONG_AGENT_BUILDER_REPO missing $marker"
  }
}

$phase96Proof = Read-JsonRequired "proofs/self_development/BATCH_PLANNER_V1.json"
if ("$(Get-PropertyValue -Object $phase96Proof -Name "status")" -ne "PASS") {
  throw "PHASE96_PROOF_NOT_PASS"
}
if ("$(Get-PropertyValue -Object $phase96Proof -Name "next_allowed_step")" -ne "PHASE97_BATCH_ADMISSION_POLICY_V1") {
  throw "PHASE96_PROOF_NEXT_STEP_MISMATCH"
}

$plan = Read-JsonRequired "self_build_batch/plans/BATCH_PLAN_EXAMPLE_V1.json"
if ("$(Get-PropertyValue -Object $plan -Name "status")" -ne "PLANNED") {
  throw "SOURCE_PLAN_NOT_PLANNED"
}
if ([bool](Get-PropertyValue -Object $plan -Name "execution_allowed")) {
  throw "SOURCE_PLAN_EXECUTION_ALLOWED_TRUE"
}

$report = & (Join-RepoPath "modules/self_development/write_batch_admission_policy_v1.ps1") -RepoRoot $RepoRoot
if ($null -eq $report) {
  $report = Read-JsonRequired "reports/self_development/BATCH_ADMISSION_POLICY_V1_REPORT.json"
}
if ("$(Get-PropertyValue -Object $report -Name "status")" -ne "PASS") {
  throw "BATCH_ADMISSION_POLICY_REPORT_NOT_PASS"
}
if ([bool](Get-PropertyValue -Object $report -Name "example_admission_execution_allowed")) {
  throw "EXAMPLE_ADMISSION_EXECUTION_ALLOWED_TRUE"
}
if (-not [bool](Get-PropertyValue -Object $report -Name "batch_execution_remains_blocked_until_runtime_exists")) {
  throw "BATCH_EXECUTION_BLOCK_GUARANTEE_MISSING"
}
if ("$(Get-PropertyValue -Object $report -Name "next_allowed_step")" -ne $NextAllowedStep) {
  throw "BATCH_ADMISSION_POLICY_NEXT_STEP_MISMATCH"
}

Update-TaskQueue
Update-Roadmap
Update-GenesisState

Write-Host "TASK_QUEUE_RETURNED_TO_NONE"
& (Join-RepoPath "packs/$PackId/VALIDATE.ps1") -RepoRoot $RepoRoot -Stage "Completed"
Write-Host "PHASE97_APPLY_COMPLETE"
