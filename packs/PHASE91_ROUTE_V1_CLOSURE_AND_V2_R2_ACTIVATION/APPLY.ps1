[CmdletBinding()]
param(
  [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path,
  [string]$RunId = "ROUTE_V1_CLOSURE_AND_V2_R2_ACTIVATION_001",
  [switch]$InvokedByOrchestrator
)

$ErrorActionPreference = "Stop"

$TaskId = "TASK_ROUTE_V1_CLOSURE_AND_V2_R2_ACTIVATION_001"
$PackId = "PHASE91_ROUTE_V1_CLOSURE_AND_V2_R2_ACTIVATION"
$NextAllowedStep = "PHASE92_SELF_BUILD_BACKLOG_CONTRACT_V1"

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

function Is-RouteLockDecision {
  param([string]$Value)

  return $Value -in @(
    "CREATE_AGENT_BUILDER_NEXT_15_STEPS_LOCK_V2",
    "CREATE_AGENT_BUILDER_NEXT_15_STEPS_LOCK_V2_R2",
    "PHASE91_ROUTE_V1_CLOSURE_AND_V2_R2_ACTIVATION"
  )
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
  Set-PropertyValue -Object $roadmap -Name "phase91_route_v1_closure_and_v2_r2_activation" -Value "COMPLETED"
  Write-JsonFile -Path "CAPABILITY_ROADMAP.json" -Object $roadmap
}

function Update-GenesisState {
  $genesis = Read-JsonRequired "GENESIS_STATE.json"
  Set-PropertyValue -Object $genesis -Name "route_lock_v2_r2_active" -Value "PROVEN"
  Write-JsonFile -Path "GENESIS_STATE.json" -Object $genesis
}

Write-Host "PHASE91_APPLY_START"

foreach ($marker in @("CAPABILITY_ROADMAP.json", "GENESIS_STATE.json", "TASK_QUEUE.json", "packs/registry.json", "orchestrator/run.ps1")) {
  if (-not (Test-Path -LiteralPath (Join-RepoPath $marker))) {
    throw "STOP=WRONG_AGENT_BUILDER_REPO missing $marker"
  }
}

$phase90Proof = Read-JsonRequired "proofs/self_development/GENERATED_SELF_BUILD_EXECUTION_V1.json"
$phase90Report = Read-JsonRequired "reports/self_development/GENERATED_SELF_BUILD_EXECUTION_REPORT.json"
if ("$(Get-PropertyValue -Object $phase90Proof -Name "status")" -ne "PASS") {
  throw "PHASE90_PROOF_NOT_PASS"
}
if (-not [bool](Get-PropertyValue -Object $phase90Proof -Name "execution_performed")) {
  throw "PHASE90_EXECUTION_NOT_TRUE"
}
if (-not [bool](Get-PropertyValue -Object $phase90Proof -Name "completed_loop")) {
  throw "PHASE90_COMPLETED_LOOP_NOT_TRUE"
}
if ("$(Get-PropertyValue -Object $phase90Report -Name "status")" -ne "PASS") {
  throw "PHASE90_REPORT_NOT_PASS"
}

$phase90Next = "$(Get-PropertyValue -Object $phase90Proof -Name "next_allowed_step")"
$phase90Recommended = "$(Get-PropertyValue -Object $phase90Report -Name "next_recommended_action")"
if (-not (Is-RouteLockDecision -Value $phase90Next) -and -not (Is-RouteLockDecision -Value $phase90Recommended)) {
  throw "PHASE90_ROUTE_LOCK_DECISION_MISSING"
}

$report = & (Join-RepoPath "modules/route_locks/write_route_v1_closure_and_v2_r2_activation_report.ps1") -RepoRoot $RepoRoot
if ($null -eq $report) {
  $report = Read-JsonRequired "reports/route_locks/ROUTE_V1_CLOSURE_AND_V2_R2_ACTIVATION_REPORT.json"
}
if ("$(Get-PropertyValue -Object $report -Name "status")" -ne "PASS") {
  throw "ROUTE_LOCK_REPORT_NOT_PASS"
}
if (-not [bool](Get-PropertyValue -Object $report -Name "batch_self_build_engine_route")) {
  throw "ROUTE_LOCK_BATCH_ROUTE_NOT_TRUE"
}
if ("$(Get-PropertyValue -Object $report -Name "next_allowed_step")" -ne $NextAllowedStep) {
  throw "ROUTE_LOCK_NEXT_STEP_MISMATCH"
}

Update-TaskQueue
Update-Roadmap
Update-GenesisState

Write-Host "TASK_QUEUE_RETURNED_TO_NONE"
& (Join-RepoPath "packs/$PackId/VALIDATE.ps1") -RepoRoot $RepoRoot -Stage "Completed"
Write-Host "PHASE91_APPLY_COMPLETE"
