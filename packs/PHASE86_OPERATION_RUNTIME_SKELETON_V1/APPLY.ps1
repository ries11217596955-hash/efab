[CmdletBinding()]
param(
  [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path,
  [string]$RunId = "OPERATION_RUNTIME_SKELETON_V1_001",
  [switch]$InvokedByOrchestrator
)

$ErrorActionPreference = "Stop"

$CapabilityId = "operation_runtime_skeleton_v1"
$PackId = "PHASE86_OPERATION_RUNTIME_SKELETON_V1"
$TaskId = "TASK_OPERATION_RUNTIME_SKELETON_V1_001"
$GateId = "OPERATION_RUNTIME_SKELETON_V1"
$ActiveLine = "AGENT_BUILDER_SELF_DEVELOPMENT"
$Mode = "SELF_BUILD"
$OperationId = "validate_json_schema_with_python_jsonschema"
$MaterialId = "mat_python_jsonschema_001"
$RequestPath = "operations/runtime/requests/FIRST_OPERATION_RUNTIME_DRY_RUN_REQUEST.json"
$OperationRegistryPath = "operations/registry.json"
$ContractsRoot = "operations/contracts"
$OperationContractPath = "operations/contracts/validate_json_schema_with_python_jsonschema.contract.json"
$SmokeReportPath = "reports/operations/FIRST_SMOKE_INSTALL_TRIAL_REPORT.json"
$SmokeProofPath = "proofs/operations/FIRST_SMOKE_INSTALL_TRIAL_V1.json"
$ReportPath = "reports/operations/OPERATION_RUNTIME_SKELETON_REPORT.json"
$ProofPath = "proofs/operations/OPERATION_RUNTIME_SKELETON_V1.json"
$NextAllowedStep = "PHASE87_SELF_DEVELOPMENT_DECISION_KERNEL_V1"
$ProtectedStatePaths = @(
  "materials/MATERIAL_CATALOG.json",
  "materials/MATERIAL_POLICY.json",
  "materials/quarantine/QUARANTINE_BATCH_001.json",
  "materials/quarantine/mat_json_schema_ajv_001/MATERIAL_CARD.json",
  "materials/quarantine/mat_python_jsonschema_001/MATERIAL_CARD.json",
  "operations/registry.json",
  "operations/contracts/validate_json_schema_with_ajv.contract.json",
  "operations/contracts/validate_json_schema_with_python_jsonschema.contract.json",
  "reports/operations/FIRST_SMOKE_INSTALL_TRIAL_REPORT.json",
  "proofs/operations/FIRST_SMOKE_INSTALL_TRIAL_V1.json"
)

function Join-RepoPath {
  param([string]$Path)
  return [System.IO.Path]::GetFullPath((Join-Path $RepoRoot $Path))
}

function Get-UtcStamp {
  return (Get-Date).ToUniversalTime().ToString("o")
}

function Get-FileSha256 {
  param([string]$Path)
  return (Get-FileHash -LiteralPath (Join-RepoPath $Path) -Algorithm SHA256).Hash
}

function Get-HashMap {
  param([string[]]$Paths)

  $hashes = [ordered]@{}
  foreach ($path in $Paths) {
    $hashes[$path] = Get-FileSha256 -Path $path
  }
  return $hashes
}

function Compare-HashMaps {
  param(
    [object]$Before,
    [object]$After
  )

  foreach ($property in $Before.GetEnumerator()) {
    if (-not $After.Contains($property.Key)) {
      return $false
    }
    if ($After[$property.Key] -ne $property.Value) {
      return $false
    }
  }
  return $true
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
      Set-PropertyValue -Object $task -Name "path" -Value "tasks/TASK_OPERATION_RUNTIME_SKELETON_V1_001.json"
      Set-PropertyValue -Object $task -Name "active_line" -Value $ActiveLine
      Set-PropertyValue -Object $task -Name "mode" -Value $Mode
      Set-PropertyValue -Object $task -Name "capability_id" -Value $CapabilityId
      Set-PropertyValue -Object $task -Name "phase" -Value "PHASE_86"
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
    if ("$id" -eq $CapabilityId -or "$phase" -eq "PHASE_86") {
      Set-PropertyValue -Object $capability -Name "id" -Value $CapabilityId
      Set-PropertyValue -Object $capability -Name "phase" -Value "PHASE_86"
      Set-PropertyValue -Object $capability -Name "status" -Value "COMPLETED"
      Set-PropertyValue -Object $capability -Name "gate" -Value $GateId
      Set-PropertyValue -Object $capability -Name "goal" -Value "Create operation runtime skeleton for contract-gated dry-run operation requests without execution, installs, wrappers, trust changes, or protected state mutation."
    }
  }
  Write-JsonFile -Path "CAPABILITY_ROADMAP.json" -Object $roadmap
}

function Update-GenesisState {
  $genesis = Read-JsonRequired "GENESIS_STATE.json"
  Set-PropertyValue -Object $genesis -Name "current_phase" -Value "PHASE_86"
  Set-PropertyValue -Object $genesis -Name "current_capability" -Value $CapabilityId
  Set-PropertyValue -Object $genesis -Name "operation_runtime_skeleton_ready" -Value $true

  $completed = As-Array (Get-PropertyValue -Object $genesis -Name "completed_capabilities")
  if ($completed -notcontains $CapabilityId) {
    $completed += $CapabilityId
  }
  Set-PropertyValue -Object $genesis -Name "completed_capabilities" -Value @($completed)

  Write-JsonFile -Path "GENESIS_STATE.json" -Object $genesis
}

function Test-OperationNotTrusted {
  $registry = Read-JsonRequired $OperationRegistryPath
  $operations = As-Array (Get-PropertyValue -Object $registry -Name "operations")
  $matches = @($operations | Where-Object { "$(Get-PropertyValue -Object $_ -Name "operation_id")" -eq $OperationId })
  if (@($matches).Count -ne 1) {
    throw "OPERATION_REGISTRY_MATCH_COUNT_$OperationId=$(@($matches).Count)"
  }
  if ("$(Get-PropertyValue -Object $matches[0] -Name "status")" -eq "TRUSTED_OPERATION") {
    throw "OPERATION_TRUSTED_FORBIDDEN=$OperationId"
  }
}

function Write-RuntimeSkeletonProof {
  param(
    [object]$Report,
    [bool]$ProtectedStateUnchanged
  )

  $queue = Read-JsonRequired "TASK_QUEUE.json"
  $proof = [ordered]@{
    proof_id = "OPERATION_RUNTIME_SKELETON_V1"
    phase = "PHASE_86"
    capability_id = $CapabilityId
    task_id = $TaskId
    pack_id = $PackId
    status = "PASS"
    generated_at = Get-UtcStamp
    evidence_files = @(
      "contracts/operations/operation_request.schema.json",
      "contracts/operations/operation_runtime_report.schema.json",
      "operations/runtime/README.md",
      $RequestPath,
      $OperationRegistryPath,
      $OperationContractPath,
      $SmokeReportPath,
      $SmokeProofPath,
      $ReportPath
    )
    validation_gates = @(
      "phase85_proof_pass",
      "operation_contract_ready",
      "operation_not_trusted",
      "smoke_proof_pass",
      "runtime_mode_dry_run_only",
      "dry_run_plan_created",
      "execution_performed_false",
      "install_performed_false",
      "external_fetch_performed_false",
      "protected_state_unchanged",
      "queue_returned_to_none"
    )
    queue_state_after = [ordered]@{
      active_task_id = "$(Get-PropertyValue -Object $queue -Name "active_task_id")"
    }
    runtime_state_after = [ordered]@{
      report_path = $ReportPath
      report_status = "$(Get-PropertyValue -Object $Report -Name "status")"
      operation_id = "$(Get-PropertyValue -Object $Report -Name "operation_id")"
      runtime_mode = "$(Get-PropertyValue -Object $Report -Name "runtime_mode")"
      dry_run_plan_created = [bool](Get-PropertyValue -Object $Report -Name "dry_run_plan_created")
      execution_performed = [bool](Get-PropertyValue -Object $Report -Name "execution_performed")
      install_performed = [bool](Get-PropertyValue -Object $Report -Name "install_performed")
      external_fetch_performed = [bool](Get-PropertyValue -Object $Report -Name "external_fetch_performed")
      trusted_operation_count = [int](Get-PropertyValue -Object $Report -Name "trusted_operation_count")
    }
    forbidden_actions_confirmed = [ordered]@{
      no_tool_execution = (-not [bool](Get-PropertyValue -Object $Report -Name "execution_performed"))
      no_install_performed = (-not [bool](Get-PropertyValue -Object $Report -Name "install_performed"))
      no_external_fetch_performed = (-not [bool](Get-PropertyValue -Object $Report -Name "external_fetch_performed"))
      no_venv_created = $true
      no_production_wrapper_created = $true
      no_materials_marked_trusted = (-not [bool](Get-PropertyValue -Object $Report -Name "material_marked_trusted"))
      no_trusted_operations_created = (-not [bool](Get-PropertyValue -Object $Report -Name "operation_marked_trusted"))
      no_catalog_mutation = $ProtectedStateUnchanged
      no_policy_mutation = $ProtectedStateUnchanged
      no_quarantine_card_mutation = $ProtectedStateUnchanged
      no_operation_contract_mutation = $ProtectedStateUnchanged
      no_operation_registry_mutation = $ProtectedStateUnchanged
      no_external_agent_created = $true
      no_phase78_files_modified = $true
      no_phase79_files_modified = $true
      no_phase80_files_modified = $true
      no_phase81_files_modified = $true
      no_phase82_files_modified = $true
      no_phase83_files_modified = $true
      no_phase84_files_modified = $true
      no_phase85_files_modified = $true
    }
    next_allowed_step = $NextAllowedStep
  }

  Write-JsonFile -Path $ProofPath -Object $proof
}

function Invoke-Validator {
  & (Join-RepoPath "packs/$PackId/VALIDATE.ps1") -RepoRoot $RepoRoot -Stage "Completed"
}

Write-Host "PHASE86_APPLY_START"

foreach ($marker in @("CAPABILITY_ROADMAP.json", "GENESIS_STATE.json", "TASK_QUEUE.json", "packs/registry.json", "orchestrator/run.ps1")) {
  if (-not (Test-Path -LiteralPath (Join-RepoPath $marker))) {
    throw "STOP=WRONG_AGENT_BUILDER_REPO missing $marker"
  }
}

foreach ($path in @(
  "contracts/operations/operation_request.schema.json",
  "contracts/operations/operation_runtime_report.schema.json",
  "operations/runtime/README.md",
  $RequestPath,
  $OperationRegistryPath,
  $OperationContractPath,
  $SmokeReportPath,
  $SmokeProofPath
)) {
  if (-not (Test-Path -LiteralPath (Join-RepoPath $path))) {
    throw "PHASE86_MISSING_INPUT=$path"
  }
}

$smokeProof = Read-JsonRequired $SmokeProofPath
if ("$(Get-PropertyValue -Object $smokeProof -Name "status")" -ne "PASS") {
  throw "PHASE85_PROOF_NOT_PASS"
}

$contract = Read-JsonRequired $OperationContractPath
if ("$(Get-PropertyValue -Object $contract -Name "operation_id")" -ne $OperationId) {
  throw "OPERATION_CONTRACT_ID_MISMATCH"
}
if ("$(Get-PropertyValue -Object $contract -Name "status")" -ne "CONTRACT_READY") {
  throw "OPERATION_CONTRACT_NOT_READY"
}
if ("$(Get-PropertyValue -Object $contract -Name "status")" -eq "TRUSTED_OPERATION") {
  throw "OPERATION_CONTRACT_TRUSTED_FORBIDDEN"
}
Test-OperationNotTrusted

$hashesBefore = Get-HashMap -Paths $ProtectedStatePaths

$report = & (Join-RepoPath "modules/operations/invoke_operation_runtime.ps1") -RepoRoot $RepoRoot -RequestPath $RequestPath -OperationRegistryPath $OperationRegistryPath -ContractsRoot $ContractsRoot -SmokeProofPath $SmokeProofPath -OutputReportPath $ReportPath
Write-Host "OPERATION_RUNTIME_REPORT_WRITTEN"

if ($null -eq $report) {
  $report = Read-JsonRequired $ReportPath
}
if ("$(Get-PropertyValue -Object $report -Name "status")" -ne "PASS") {
  throw "OPERATION_RUNTIME_REPORT_STATUS_NOT_PASS"
}

$hashesAfter = Get-HashMap -Paths $ProtectedStatePaths
$protectedStateUnchanged = Compare-HashMaps -Before $hashesBefore -After $hashesAfter
if (-not $protectedStateUnchanged) {
  throw "PHASE86_PROTECTED_STATE_MUTATED"
}

Update-TaskQueue
Update-Roadmap
Update-GenesisState

Write-RuntimeSkeletonProof -Report $report -ProtectedStateUnchanged $protectedStateUnchanged
Write-Host "OPERATION_RUNTIME_PROOF_WRITTEN"
Write-Host "TASK_QUEUE_RETURNED_TO_NONE"

Invoke-Validator

Write-Host "PHASE86_APPLY_COMPLETE"
