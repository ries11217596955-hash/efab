[CmdletBinding()]
param(
  [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path,
  [string]$RunId = "SELF_DEVELOPMENT_DECISION_KERNEL_V1_001",
  [switch]$InvokedByOrchestrator
)

$ErrorActionPreference = "Stop"

$CapabilityId = "self_development_decision_kernel_v1"
$PackId = "PHASE87_SELF_DEVELOPMENT_DECISION_KERNEL_V1"
$TaskId = "TASK_SELF_DEVELOPMENT_DECISION_KERNEL_V1_001"
$GateId = "SELF_DEVELOPMENT_DECISION_KERNEL_V1"
$ActiveLine = "AGENT_BUILDER_SELF_DEVELOPMENT"
$Mode = "SELF_BUILD"
$ReportPath = "reports/self_development/SELF_DEVELOPMENT_DECISION_KERNEL_REPORT.json"
$ProofPath = "proofs/self_development/SELF_DEVELOPMENT_DECISION_KERNEL_V1.json"
$NextAllowedStep = "PHASE88_SELF_BUILD_PROGRAM_GENERATOR_V1"

function Join-RepoPath {
  param([string]$Path)
  return [System.IO.Path]::GetFullPath((Join-Path $RepoRoot $Path))
}

function Get-UtcStamp {
  return (Get-Date).ToUniversalTime().ToString("o")
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

function Read-JsonRequired {
  param([string]$Path)

  $fullPath = Join-RepoPath $Path
  if (-not (Test-Path -LiteralPath $fullPath)) {
    throw "MISSING_JSON=$Path"
  }
  return (Get-Content -LiteralPath $fullPath -Raw | ConvertFrom-Json)
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
      Set-PropertyValue -Object $task -Name "path" -Value "tasks/TASK_SELF_DEVELOPMENT_DECISION_KERNEL_V1_001.json"
      Set-PropertyValue -Object $task -Name "active_line" -Value $ActiveLine
      Set-PropertyValue -Object $task -Name "mode" -Value $Mode
      Set-PropertyValue -Object $task -Name "capability_id" -Value $CapabilityId
      Set-PropertyValue -Object $task -Name "phase" -Value "PHASE_87"
      Set-PropertyValue -Object $task -Name "gate" -Value $GateId
      Set-PropertyValue -Object $task -Name "pack_id" -Value $PackId
    }
  }
  Write-JsonFile -Path "TASK_QUEUE.json" -Object $queue
}

function Update-Roadmap {
  $roadmap = Read-JsonRequired "CAPABILITY_ROADMAP.json"
  foreach ($capability in As-Array (Get-PropertyValue -Object $roadmap -Name "capabilities")) {
    $id = Get-PropertyValue -Object $capability -Name "id"
    $phase = Get-PropertyValue -Object $capability -Name "phase"
    if ("$id" -eq $CapabilityId -or "$phase" -eq "PHASE_87") {
      Set-PropertyValue -Object $capability -Name "id" -Value $CapabilityId
      Set-PropertyValue -Object $capability -Name "phase" -Value "PHASE_87"
      Set-PropertyValue -Object $capability -Name "status" -Value "COMPLETED"
      Set-PropertyValue -Object $capability -Name "gate" -Value $GateId
      Set-PropertyValue -Object $capability -Name "goal" -Value "Create a self-development decision kernel that reads repo evidence and recommends the next self-development gap without generating programs or external agents."
    }
  }
  Write-JsonFile -Path "CAPABILITY_ROADMAP.json" -Object $roadmap
}

function Update-GenesisState {
  $genesis = Read-JsonRequired "GENESIS_STATE.json"
  Set-PropertyValue -Object $genesis -Name "current_phase" -Value "PHASE_87"
  Set-PropertyValue -Object $genesis -Name "current_capability" -Value $CapabilityId
  Set-PropertyValue -Object $genesis -Name "self_development_decision_kernel_ready" -Value $true

  $completed = As-Array (Get-PropertyValue -Object $genesis -Name "completed_capabilities")
  if ($completed -notcontains $CapabilityId) {
    $completed += $CapabilityId
  }
  Set-PropertyValue -Object $genesis -Name "completed_capabilities" -Value @($completed)
  Write-JsonFile -Path "GENESIS_STATE.json" -Object $genesis
}

function Write-DecisionKernelProof {
  param([object]$Report)

  $queue = Read-JsonRequired "TASK_QUEUE.json"
  $proof = [ordered]@{
    proof_id = "SELF_DEVELOPMENT_DECISION_KERNEL_V1"
    status = "PASS"
    phase = "PHASE87_SELF_DEVELOPMENT_DECISION_KERNEL_V1"
    capability_id = $CapabilityId
    task_id = $TaskId
    pack_id = $PackId
    runtime_mode = $Mode
    generated_at = Get-UtcStamp
    report_path = $ReportPath
    proof_path = $ProofPath
    decision_kernel_created = $true
    recommended_next_step_id = "$(Get-PropertyValue -Object $Report -Name "recommended_next_step_id")"
    next_allowed_step = $NextAllowedStep
    no_external_agent_production = $true
    no_external_install = $true
    no_trusted_material_changes = $true
    no_operation_execution = $true
    queue_returned_to_none = ("$(Get-PropertyValue -Object $queue -Name "active_task_id")" -eq "NONE")
    evidence_files = @(
      "contracts/self_development/self_development_decision_kernel_report.schema.json",
      "modules/self_development/write_self_development_decision_kernel_report.ps1",
      $ReportPath
    )
  }

  Write-JsonFile -Path $ProofPath -Object $proof
}

Write-Host "PHASE87_APPLY_START"

foreach ($marker in @("CAPABILITY_ROADMAP.json", "GENESIS_STATE.json", "TASK_QUEUE.json", "packs/registry.json", "orchestrator/run.ps1")) {
  if (-not (Test-Path -LiteralPath (Join-RepoPath $marker))) {
    throw "STOP=WRONG_AGENT_BUILDER_REPO missing $marker"
  }
}

$phase86Proof = Read-JsonRequired "proofs/operations/OPERATION_RUNTIME_SKELETON_V1.json"
if ("$(Get-PropertyValue -Object $phase86Proof -Name "status")" -ne "PASS") {
  throw "PHASE86_PROOF_NOT_PASS"
}
if ("$(Get-PropertyValue -Object $phase86Proof -Name "next_allowed_step")" -ne "PHASE87_SELF_DEVELOPMENT_DECISION_KERNEL_V1") {
  throw "PHASE86_NEXT_ALLOWED_STEP_MISMATCH"
}

foreach ($path in @(
  "contracts/self_development/self_development_decision_kernel_report.schema.json",
  "modules/self_development/write_self_development_decision_kernel_report.ps1",
  "packs/PHASE87_SELF_DEVELOPMENT_DECISION_KERNEL_V1/PACK.json"
)) {
  if (-not (Test-Path -LiteralPath (Join-RepoPath $path))) {
    throw "PHASE87_MISSING_INPUT=$path"
  }
}

$report = & (Join-RepoPath "modules/self_development/write_self_development_decision_kernel_report.ps1") -RepoRoot $RepoRoot -OutputReportPath $ReportPath
if ($null -eq $report) {
  $report = Read-JsonRequired $ReportPath
}
if ("$(Get-PropertyValue -Object $report -Name "status")" -ne "PASS") {
  throw "SELF_DEVELOPMENT_DECISION_REPORT_STATUS_NOT_PASS"
}
if ("$(Get-PropertyValue -Object $report -Name "recommended_next_step_id")" -ne $NextAllowedStep) {
  throw "SELF_DEVELOPMENT_DECISION_NEXT_STEP_MISMATCH"
}

Update-TaskQueue
Update-Roadmap
Update-GenesisState
Write-DecisionKernelProof -Report $report

Write-Host "SELF_DEVELOPMENT_DECISION_PROOF_WRITTEN=$ProofPath"
Write-Host "TASK_QUEUE_RETURNED_TO_NONE"

& (Join-RepoPath "packs/$PackId/VALIDATE.ps1") -RepoRoot $RepoRoot -Stage "Completed"

Write-Host "PHASE87_APPLY_COMPLETE"

# PHASE165E_DYNAMIC_GAP_SELECTION_PATCH_START
try {
  $__phase165eSelector = "self_build_batch/decision_kernel/SELECT_DYNAMIC_SELF_BUILD_NEXT_GAP_V1.ps1"
  $__phase165eOutput = "self_build_batch/decision_kernel/PHASE165E_DYNAMIC_GAP_DECISION_V1.json"
  if (Test-Path $__phase165eSelector) {
    & powershell -NoProfile -ExecutionPolicy Bypass -File $__phase165eSelector -OutputPath $__phase165eOutput | Out-Null
  }
} catch {
  Write-Warning ("PHASE165E dynamic gap selection patch failed: " + $_.Exception.Message)
}
# PHASE165E_DYNAMIC_GAP_SELECTION_PATCH_END
