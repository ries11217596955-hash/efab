[CmdletBinding()]
param(
  [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path,
  [string]$RunId = "BUILDER_EXECUTES_OWN_GENERATED_SELF_BUILD_PROGRAM_V1_001",
  [switch]$InvokedByOrchestrator
)

$ErrorActionPreference = "Stop"

$TaskId = "TASK_BUILDER_EXECUTES_OWN_GENERATED_SELF_BUILD_PROGRAM_V1_001"
$PackId = "PHASE90_BUILDER_EXECUTES_OWN_GENERATED_SELF_BUILD_PROGRAM_V1"
$NextAllowedStep = "CREATE_AGENT_BUILDER_NEXT_15_STEPS_LOCK_V2"

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
  Set-PropertyValue -Object $roadmap -Name "phase90_builder_executes_own_generated_self_build_program_v1" -Value "COMPLETED"
  Write-JsonFile -Path "CAPABILITY_ROADMAP.json" -Object $roadmap
}

function Update-GenesisState {
  $genesis = Read-JsonRequired "GENESIS_STATE.json"
  Set-PropertyValue -Object $genesis -Name "generated_self_build_execution_v1" -Value "PROVEN"
  Write-JsonFile -Path "GENESIS_STATE.json" -Object $genesis
}

Write-Host "PHASE90_APPLY_START"

foreach ($marker in @("CAPABILITY_ROADMAP.json", "GENESIS_STATE.json", "TASK_QUEUE.json", "packs/registry.json", "orchestrator/run.ps1")) {
  if (-not (Test-Path -LiteralPath (Join-RepoPath $marker))) {
    throw "STOP=WRONG_AGENT_BUILDER_REPO missing $marker"
  }
}

$__phase165oIdentityDir = "self_build_programs/identity"
$__phase165oIdentityFile = Get-ChildItem -Path $__phase165oIdentityDir -Filter "*.json" | Sort-Object LastWriteTimeUtc -Descending | Select-Object -First 1
if ($null -eq $__phase165oIdentityFile) { throw "No runtime identity json found" }
$__phase165oIdentity = Read-JsonRequired $__phase165oIdentityFile.FullName
$__phase165oProgramId = [string]$__phase165oIdentity.program_id
if ([string]::IsNullOrWhiteSpace($__phase165oProgramId)) { throw "Resolved runtime program_id is empty" }
$__phase165oProgramPath = "self_build_programs/generated/$__phase165oProgramId.json"
$program = Read-JsonRequired $__phase165oProgramPath
if ("$(Get-PropertyValue -Object $program -Name "status")" -ne "GENERATED_CANDIDATE") {
  throw "PROGRAM_STATUS_NOT_GENERATED_CANDIDATE"
}
if (-not [bool](Get-PropertyValue -Object $program -Name "admission_required")) {
  throw "PROGRAM_ADMISSION_REQUIRED_NOT_TRUE"
}

$__phase165oAdmissionPath = "self_build_programs/admission/$__phase165oProgramId`_ADMISSION.json"
$admission = Read-JsonRequired $__phase165oAdmissionPath
if ("$(Get-PropertyValue -Object $admission -Name "status")" -ne "PASS") {
  throw "ADMISSION_STATUS_NOT_PASS"
}
if ("$(Get-PropertyValue -Object $admission -Name "admission_decision")" -ne "ADMIT_CANDIDATE_FOR_CONTROLLED_EXECUTION") {
  throw "ADMISSION_DECISION_MISMATCH"
}
if ([bool](Get-PropertyValue -Object $admission -Name "execution_performed")) {
  throw "ADMISSION_EXECUTION_PERFORMED_TRUE"
}

$phase89Proof = Read-JsonRequired "proofs/self_development/GENERATED_PROGRAM_ADMISSION_V1.json"
if ("$(Get-PropertyValue -Object $phase89Proof -Name "status")" -ne "PASS") {
  throw "PHASE89_PROOF_NOT_PASS"
}
if ("$(Get-PropertyValue -Object $phase89Proof -Name "next_allowed_step")" -ne "PHASE90_BUILDER_EXECUTES_OWN_GENERATED_SELF_BUILD_PROGRAM_V1") {
  throw "PHASE89_PROOF_NEXT_STEP_MISMATCH"
}

$report = & (Join-RepoPath "modules/self_development/execute_admitted_self_build_program.ps1") -RepoRoot $RepoRoot
if ($null -eq $report) {
  $report = Read-JsonRequired "reports/self_development/GENERATED_SELF_BUILD_EXECUTION_REPORT.json"
}
if ("$(Get-PropertyValue -Object $report -Name "status")" -ne "PASS") {
  throw "GENERATED_SELF_BUILD_EXECUTION_REPORT_NOT_PASS"
}
if (-not [bool](Get-PropertyValue -Object $report -Name "execution_performed")) {
  throw "GENERATED_SELF_BUILD_EXECUTION_NOT_PERFORMED"
}
if (-not [bool](Get-PropertyValue -Object $report -Name "completed_loop")) {
  throw "GENERATED_SELF_BUILD_LOOP_NOT_COMPLETED"
}
if ("$(Get-PropertyValue -Object $report -Name "next_recommended_action")" -ne $NextAllowedStep) {
  throw "GENERATED_SELF_BUILD_EXECUTION_NEXT_STEP_MISMATCH"
}

Update-TaskQueue
Update-Roadmap
Update-GenesisState

Write-Host "TASK_QUEUE_RETURNED_TO_NONE"
& (Join-RepoPath "packs/$PackId/VALIDATE.ps1") -RepoRoot $RepoRoot -Stage "Completed"
Write-Host "PHASE90_APPLY_COMPLETE"

# PHASE165H_DYNAMIC_SELF_BUILD_PROGRAM_EXECUTION_PATCH_START
try {
  $__phase165hExecution = "self_build_programs/executions/EXECUTE_DYNAMIC_SELF_BUILD_PROGRAM_V1.ps1"
  if (Test-Path $__phase165hExecution) {
    & powershell -NoProfile -ExecutionPolicy Bypass -File $__phase165hExecution | Out-Null
  }
} catch {
  Write-Warning ("PHASE165H dynamic self-build program execution failed: " + $_.Exception.Message)
}
# PHASE165H_DYNAMIC_SELF_BUILD_PROGRAM_EXECUTION_PATCH_END



