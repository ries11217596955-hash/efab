[CmdletBinding()]
param(
  [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path,
  [string]$RunId = "SELF_BUILD_PROGRAM_GENERATOR_V2_001",
  [switch]$InvokedByOrchestrator
)

$ErrorActionPreference = "Stop"

$TaskId = "TASK_SELF_BUILD_PROGRAM_GENERATOR_V2_001"
$PackId = "PHASE95_SELF_BUILD_PROGRAM_GENERATOR_V2"
$NextAllowedStep = "PHASE96_BATCH_PLANNER_V1"

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
    generator = "self_build_programs/generator/SELF_BUILD_PROGRAM_GENERATOR_V2.json"
    schema = "contracts/self_development/self_build_program_v2.schema.json"
    example_program = "self_build_programs/generated/SELF_BUILD_PROGRAM_V2_EXAMPLE_001.json"
    proof = "proofs/self_development/SELF_BUILD_PROGRAM_GENERATOR_V2.json"
    report = "reports/self_development/SELF_BUILD_PROGRAM_GENERATOR_V2_REPORT.json"
    next_allowed_step = $NextAllowedStep
  }
  Set-PropertyValue -Object $roadmap -Name "phase95_self_build_program_generator_v2" -Value $value
  Write-JsonFile -Path "CAPABILITY_ROADMAP.json" -Object $roadmap
}

function Update-GenesisState {
  $genesis = Read-JsonRequired "GENESIS_STATE.json"
  $value = [ordered]@{
    status = "PROVEN"
    generator = "self_build_programs/generator/SELF_BUILD_PROGRAM_GENERATOR_V2.json"
    schema = "contracts/self_development/self_build_program_v2.schema.json"
    proof = "proofs/self_development/SELF_BUILD_PROGRAM_GENERATOR_V2.json"
  }
  Set-PropertyValue -Object $genesis -Name "self_build_program_generator_v2" -Value $value
  Write-JsonFile -Path "GENESIS_STATE.json" -Object $genesis
}

Write-Host "PHASE95_APPLY_START"

foreach ($marker in @("CAPABILITY_ROADMAP.json", "GENESIS_STATE.json", "TASK_QUEUE.json", "packs/registry.json", "orchestrator/run.ps1")) {
  if (-not (Test-Path -LiteralPath (Join-RepoPath $marker))) {
    throw "STOP=WRONG_AGENT_BUILDER_REPO missing $marker"
  }
}

$phase94Proof = Read-JsonRequired "proofs/self_development/OWNER_ORDER_TO_GAP_MAP_V1.json"
if ("$(Get-PropertyValue -Object $phase94Proof -Name "status")" -ne "PASS") {
  throw "PHASE94_PROOF_NOT_PASS"
}
if ("$(Get-PropertyValue -Object $phase94Proof -Name "next_allowed_step")" -ne "PHASE95_SELF_BUILD_PROGRAM_GENERATOR_V2") {
  throw "PHASE94_PROOF_NEXT_STEP_MISMATCH"
}

$report = & (Join-RepoPath "modules/self_development/write_self_build_program_generator_v2.ps1") -RepoRoot $RepoRoot
if ($null -eq $report) {
  $report = Read-JsonRequired "reports/self_development/SELF_BUILD_PROGRAM_GENERATOR_V2_REPORT.json"
}
if ("$(Get-PropertyValue -Object $report -Name "status")" -ne "PASS") {
  throw "SELF_BUILD_PROGRAM_GENERATOR_V2_REPORT_NOT_PASS"
}
if (-not [bool](Get-PropertyValue -Object $report -Name "generator_does_not_execute_program")) {
  throw "GENERATOR_EXECUTION_GUARANTEE_MISSING"
}
if ([bool](Get-PropertyValue -Object $report -Name "example_program_execution_allowed")) {
  throw "EXAMPLE_PROGRAM_EXECUTION_ALLOWED_TRUE"
}
if ("$(Get-PropertyValue -Object $report -Name "next_allowed_step")" -ne $NextAllowedStep) {
  throw "SELF_BUILD_PROGRAM_GENERATOR_V2_NEXT_STEP_MISMATCH"
}

Update-TaskQueue
Update-Roadmap
Update-GenesisState

Write-Host "TASK_QUEUE_RETURNED_TO_NONE"
& (Join-RepoPath "packs/$PackId/VALIDATE.ps1") -RepoRoot $RepoRoot -Stage "Completed"
Write-Host "PHASE95_APPLY_COMPLETE"
