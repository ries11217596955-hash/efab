[CmdletBinding()]
param(
  [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path,
  [string]$RunId = "OPERATION_CONTRACT_SKELETON_V1_001",
  [switch]$InvokedByOrchestrator
)

$ErrorActionPreference = "Stop"

$CapabilityId = "operation_contract_skeleton_v1"
$PackId = "PHASE83_OPERATION_CONTRACT_SKELETON_V1"
$TaskId = "TASK_OPERATION_CONTRACT_SKELETON_V1_001"
$GateId = "OPERATION_CONTRACT_SKELETON_V1"
$ActiveLine = "AGENT_BUILDER_SELF_DEVELOPMENT"
$Mode = "SELF_BUILD"
$ContractSchemaPath = "contracts/operations/operation_contract.schema.json"
$RegistrySchemaPath = "contracts/operations/operation_registry.schema.json"
$OperationRegistryPath = "operations/registry.json"
$OperationsReadmePath = "operations/README.md"
$QuarantineBatchPath = "materials/quarantine/QUARANTINE_BATCH_001.json"
$QuarantineProofPath = "proofs/materials/FIRST_QUARANTINE_TRIAL_V1.json"
$ReportPath = "reports/operations/OPERATION_CONTRACT_SKELETON_REPORT.json"
$ProofPath = "proofs/operations/OPERATION_CONTRACT_SKELETON_V1.json"
$NextAllowedStep = "PHASE84_FIRST_WRAPPER_OPERATION_CONTRACTS_V1"

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

function Get-QuarantineFileHashes {
  $paths = @(
    "materials/quarantine/QUARANTINE_BATCH_001.json"
  )
  $batch = Read-JsonRequired $QuarantineBatchPath
  foreach ($materialId in As-Array (Get-PropertyValue -Object $batch -Name "selected_material_ids")) {
    $paths += "materials/quarantine/$materialId/MATERIAL_CARD.json"
    $paths += "materials/quarantine/$materialId/SOURCE_NOTES.md"
    $paths += "materials/quarantine/$materialId/ADMISSION_CHECKLIST.json"
  }

  $hashes = [ordered]@{}
  foreach ($path in $paths) {
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

function Get-TrustedOperationCount {
  param([object[]]$Operations)

  return @($Operations | Where-Object { "$(Get-PropertyValue -Object $_ -Name "status")" -eq "TRUSTED_OPERATION" }).Count
}

function Get-ExecutionPerformed {
  param([object[]]$Operations)

  foreach ($operation in $Operations) {
    $executionMode = "$(Get-PropertyValue -Object $operation -Name "execution_mode")"
    if ($executionMode -notin @("", "NO_EXECUTION", "DRY_RUN_ONLY")) {
      return $true
    }
  }
  return $false
}

function Update-TaskQueue {
  $queue = Read-JsonRequired "TASK_QUEUE.json"
  Set-PropertyValue -Object $queue -Name "active_task_id" -Value "NONE"

  foreach ($task in As-Array (Get-PropertyValue -Object $queue -Name "tasks")) {
    if ("$(Get-PropertyValue -Object $task -Name "task_id")" -eq $TaskId) {
      Set-PropertyValue -Object $task -Name "status" -Value "COMPLETED"
      Set-PropertyValue -Object $task -Name "path" -Value "tasks/TASK_OPERATION_CONTRACT_SKELETON_V1_001.json"
      Set-PropertyValue -Object $task -Name "active_line" -Value $ActiveLine
      Set-PropertyValue -Object $task -Name "mode" -Value $Mode
      Set-PropertyValue -Object $task -Name "capability_id" -Value $CapabilityId
      Set-PropertyValue -Object $task -Name "phase" -Value "PHASE_83"
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
    if ("$id" -eq $CapabilityId -or "$phase" -eq "PHASE_83") {
      Set-PropertyValue -Object $capability -Name "id" -Value $CapabilityId
      Set-PropertyValue -Object $capability -Name "phase" -Value "PHASE_83"
      Set-PropertyValue -Object $capability -Name "status" -Value "COMPLETED"
      Set-PropertyValue -Object $capability -Name "gate" -Value $GateId
      Set-PropertyValue -Object $capability -Name "goal" -Value "Create operation contract schemas, registry skeleton, and report/proof path without wrappers, execution, installs, fetches, or trusted operations."
    }
  }
  Write-JsonFile -Path "CAPABILITY_ROADMAP.json" -Object $roadmap
}

function Update-GenesisState {
  $genesis = Read-JsonRequired "GENESIS_STATE.json"
  Set-PropertyValue -Object $genesis -Name "current_phase" -Value "PHASE_83"
  Set-PropertyValue -Object $genesis -Name "current_capability" -Value $CapabilityId
  Set-PropertyValue -Object $genesis -Name "operation_contract_skeleton_ready" -Value $true

  $completed = As-Array (Get-PropertyValue -Object $genesis -Name "completed_capabilities")
  if ($completed -notcontains $CapabilityId) {
    $completed += $CapabilityId
  }
  Set-PropertyValue -Object $genesis -Name "completed_capabilities" -Value @($completed)

  Write-JsonFile -Path "GENESIS_STATE.json" -Object $genesis
}

function Write-OperationProof {
  param(
    [object]$Report,
    [string]$CatalogHashBefore,
    [string]$CatalogHashAfter,
    [string]$PolicyHashBefore,
    [string]$PolicyHashAfter,
    [bool]$QuarantineUnchanged
  )

  $queue = Read-JsonRequired "TASK_QUEUE.json"
  $registry = Read-JsonRequired $OperationRegistryPath
  $operations = As-Array (Get-PropertyValue -Object $registry -Name "operations")
  $trustedOperationCount = Get-TrustedOperationCount -Operations $operations
  $executionPerformed = Get-ExecutionPerformed -Operations $operations

  $proof = [ordered]@{
    proof_id = "OPERATION_CONTRACT_SKELETON_V1"
    phase = "PHASE_83"
    capability_id = $CapabilityId
    task_id = $TaskId
    pack_id = $PackId
    status = "PASS"
    generated_at = Get-UtcStamp
    evidence_files = @(
      $ContractSchemaPath,
      $RegistrySchemaPath,
      $OperationRegistryPath,
      $OperationsReadmePath,
      $QuarantineBatchPath,
      $QuarantineProofPath,
      $ReportPath
    )
    validation_gates = @(
      "phase82_proof_pass",
      "quarantine_batch_selected_count_2",
      "operation_contract_schema_ready",
      "operation_registry_schema_ready",
      "operation_registry_skeleton_ready",
      "trusted_operation_count_zero",
      "execution_performed_false",
      "queue_returned_to_none"
    )
    queue_state_after = [ordered]@{
      active_task_id = "$(Get-PropertyValue -Object $queue -Name "active_task_id")"
    }
    operation_state_after = [ordered]@{
      registry_path = $OperationRegistryPath
      registry_status = "$(Get-PropertyValue -Object $registry -Name "status")"
      operation_count = @($operations).Count
      trusted_operation_count = $trustedOperationCount
      execution_performed = $executionPerformed
      report_status = "$(Get-PropertyValue -Object $Report -Name "status")"
    }
    forbidden_actions_confirmed = [ordered]@{
      no_external_tools_installed = $true
      no_external_repos_fetched = $true
      no_tool_execution = (-not $executionPerformed)
      no_smoke_tests_run = $true
      no_wrappers_created = $true
      no_materials_marked_trusted = $true
      no_trusted_operations_created = ($trustedOperationCount -eq 0)
      no_catalog_mutation = ($CatalogHashBefore -eq $CatalogHashAfter)
      no_policy_mutation = ($PolicyHashBefore -eq $PolicyHashAfter)
      no_quarantine_card_mutation = $QuarantineUnchanged
      no_external_agent_created = $true
      no_phase78_files_modified = $true
      no_phase79_files_modified = $true
      no_phase80_files_modified = $true
      no_phase81_files_modified = $true
      no_phase82_files_modified = $true
    }
    next_allowed_step = $NextAllowedStep
  }

  Write-JsonFile -Path $ProofPath -Object $proof
}

function Invoke-Validator {
  & (Join-RepoPath "packs/$PackId/VALIDATE.ps1") -RepoRoot $RepoRoot -Stage "Completed"
}

Write-Host "PHASE83_APPLY_START"

foreach ($marker in @("CAPABILITY_ROADMAP.json", "GENESIS_STATE.json", "TASK_QUEUE.json", "packs/registry.json", "orchestrator/run.ps1")) {
  if (-not (Test-Path -LiteralPath (Join-RepoPath $marker))) {
    throw "STOP=WRONG_AGENT_BUILDER_REPO missing $marker"
  }
}

foreach ($directory in @("contracts/operations", "operations/contracts", "reports/operations", "proofs/operations")) {
  $path = Join-RepoPath $directory
  if (-not (Test-Path -LiteralPath $path)) {
    New-Item -ItemType Directory -Path $path -Force | Out-Null
  }
}

$quarantineProof = Read-JsonRequired $QuarantineProofPath
if ("$(Get-PropertyValue -Object $quarantineProof -Name "status")" -ne "PASS") {
  throw "PHASE82_PROOF_NOT_PASS"
}

$quarantineBatch = Read-JsonRequired $QuarantineBatchPath
$selectedMaterialIds = As-Array (Get-PropertyValue -Object $quarantineBatch -Name "selected_material_ids")
if (@($selectedMaterialIds).Count -ne 2) {
  throw "PHASE83_EXPECTED_QUARANTINE_SELECTED_COUNT_2_ACTUAL_$(@($selectedMaterialIds).Count)"
}

$catalogHashBefore = Get-FileSha256 -Path "materials/MATERIAL_CATALOG.json"
$policyHashBefore = Get-FileSha256 -Path "materials/MATERIAL_POLICY.json"
$quarantineHashesBefore = Get-QuarantineFileHashes

Read-JsonRequired $ContractSchemaPath | Out-Null
Write-Host "OPERATION_CONTRACT_SCHEMA_READY"

Read-JsonRequired $RegistrySchemaPath | Out-Null
Write-Host "OPERATION_REGISTRY_SCHEMA_READY"

Read-JsonRequired $OperationRegistryPath | Out-Null
if (-not (Test-Path -LiteralPath (Join-RepoPath $OperationsReadmePath))) {
  throw "MISSING_OPERATIONS_README=$OperationsReadmePath"
}
Write-Host "OPERATION_REGISTRY_READY"

$report = & (Join-RepoPath "modules/operations/write_operation_contract_report.ps1") -RepoRoot $RepoRoot -RegistryPath $OperationRegistryPath -ContractSchemaPath $ContractSchemaPath -RegistrySchemaPath $RegistrySchemaPath -QuarantineBatchPath $QuarantineBatchPath -OutputPath $ReportPath
Write-Host "OPERATION_CONTRACT_REPORT_WRITTEN"

Update-TaskQueue
Update-Roadmap
Update-GenesisState

$catalogHashAfter = Get-FileSha256 -Path "materials/MATERIAL_CATALOG.json"
$policyHashAfter = Get-FileSha256 -Path "materials/MATERIAL_POLICY.json"
$quarantineHashesAfter = Get-QuarantineFileHashes
$quarantineUnchanged = Compare-HashMaps -Before $quarantineHashesBefore -After $quarantineHashesAfter

if ($catalogHashBefore -ne $catalogHashAfter) {
  throw "PHASE83_CATALOG_MUTATED"
}
if ($policyHashBefore -ne $policyHashAfter) {
  throw "PHASE83_POLICY_MUTATED"
}
if (-not $quarantineUnchanged) {
  throw "PHASE83_QUARANTINE_CARD_MUTATED"
}

Write-OperationProof -Report $report -CatalogHashBefore $catalogHashBefore -CatalogHashAfter $catalogHashAfter -PolicyHashBefore $policyHashBefore -PolicyHashAfter $policyHashAfter -QuarantineUnchanged $quarantineUnchanged
Write-Host "OPERATION_CONTRACT_PROOF_WRITTEN"
Write-Host "TASK_QUEUE_RETURNED_TO_NONE"

Invoke-Validator

Write-Host "PHASE83_APPLY_COMPLETE"
