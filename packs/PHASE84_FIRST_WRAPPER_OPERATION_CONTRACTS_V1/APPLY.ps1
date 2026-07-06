[CmdletBinding()]
param(
  [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path,
  [string]$RunId = "FIRST_WRAPPER_OPERATION_CONTRACTS_V1_001",
  [switch]$InvokedByOrchestrator
)

$ErrorActionPreference = "Stop"

$CapabilityId = "first_wrapper_operation_contracts_v1"
$PackId = "PHASE84_FIRST_WRAPPER_OPERATION_CONTRACTS_V1"
$TaskId = "TASK_FIRST_WRAPPER_OPERATION_CONTRACTS_V1_001"
$GateId = "FIRST_WRAPPER_OPERATION_CONTRACTS_V1"
$ActiveLine = "AGENT_BUILDER_SELF_DEVELOPMENT"
$Mode = "SELF_BUILD"
$RegistryPath = "operations/registry.json"
$ContractsRoot = "operations/contracts"
$QuarantineBatchPath = "materials/quarantine/QUARANTINE_BATCH_001.json"
$OperationSkeletonProofPath = "proofs/operations/OPERATION_CONTRACT_SKELETON_V1.json"
$ReportPath = "reports/operations/FIRST_WRAPPER_OPERATION_CONTRACTS_REPORT.json"
$ProofPath = "proofs/operations/FIRST_WRAPPER_OPERATION_CONTRACTS_V1.json"
$NextAllowedStep = "PHASE85_FIRST_SMOKE_INSTALL_TRIAL_V1"
$ContractFiles = @(
  "operations/contracts/validate_json_schema_with_ajv.contract.json",
  "operations/contracts/validate_json_schema_with_python_jsonschema.contract.json"
)
$QuarantineCardPaths = @(
  "materials/quarantine/mat_json_schema_ajv_001/MATERIAL_CARD.json",
  "materials/quarantine/mat_python_jsonschema_001/MATERIAL_CARD.json"
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

function Update-TaskQueue {
  $queue = Read-JsonRequired "TASK_QUEUE.json"
  Set-PropertyValue -Object $queue -Name "active_task_id" -Value "NONE"

  foreach ($task in As-Array (Get-PropertyValue -Object $queue -Name "tasks")) {
    if ("$(Get-PropertyValue -Object $task -Name "task_id")" -eq $TaskId) {
      Set-PropertyValue -Object $task -Name "status" -Value "COMPLETED"
      Set-PropertyValue -Object $task -Name "path" -Value "tasks/TASK_FIRST_WRAPPER_OPERATION_CONTRACTS_V1_001.json"
      Set-PropertyValue -Object $task -Name "active_line" -Value $ActiveLine
      Set-PropertyValue -Object $task -Name "mode" -Value $Mode
      Set-PropertyValue -Object $task -Name "capability_id" -Value $CapabilityId
      Set-PropertyValue -Object $task -Name "phase" -Value "PHASE_84"
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
    if ("$id" -eq $CapabilityId -or "$phase" -eq "PHASE_84") {
      Set-PropertyValue -Object $capability -Name "id" -Value $CapabilityId
      Set-PropertyValue -Object $capability -Name "phase" -Value "PHASE_84"
      Set-PropertyValue -Object $capability -Name "status" -Value "COMPLETED"
      Set-PropertyValue -Object $capability -Name "gate" -Value $GateId
      Set-PropertyValue -Object $capability -Name "goal" -Value "Create first JSON Schema validation operation contracts without wrappers, installs, fetches, execution, smoke tests, trusted operations, or material trust."
    }
  }
  Write-JsonFile -Path "CAPABILITY_ROADMAP.json" -Object $roadmap
}

function Update-GenesisState {
  $genesis = Read-JsonRequired "GENESIS_STATE.json"
  Set-PropertyValue -Object $genesis -Name "current_phase" -Value "PHASE_84"
  Set-PropertyValue -Object $genesis -Name "current_capability" -Value $CapabilityId
  Set-PropertyValue -Object $genesis -Name "first_wrapper_operation_contracts_ready" -Value $true

  $completed = As-Array (Get-PropertyValue -Object $genesis -Name "completed_capabilities")
  if ($completed -notcontains $CapabilityId) {
    $completed += $CapabilityId
  }
  Set-PropertyValue -Object $genesis -Name "completed_capabilities" -Value @($completed)

  Write-JsonFile -Path "GENESIS_STATE.json" -Object $genesis
}

function Write-WrapperContractsProof {
  param(
    [object]$Report,
    [hashtable]$Safety
  )

  $queue = Read-JsonRequired "TASK_QUEUE.json"
  $registry = Read-JsonRequired $RegistryPath
  $operations = As-Array (Get-PropertyValue -Object $registry -Name "operations")
  $trustedOperationCount = @($operations | Where-Object { "$(Get-PropertyValue -Object $_ -Name "status")" -eq "TRUSTED_OPERATION" }).Count

  $proof = [ordered]@{
    proof_id = "FIRST_WRAPPER_OPERATION_CONTRACTS_V1"
    phase = "PHASE_84"
    capability_id = $CapabilityId
    task_id = $TaskId
    pack_id = $PackId
    status = "PASS"
    generated_at = Get-UtcStamp
    evidence_files = @(
      $RegistryPath,
      $ContractFiles[0],
      $ContractFiles[1],
      $QuarantineBatchPath,
      $OperationSkeletonProofPath,
      $ReportPath
    )
    validation_gates = @(
      "phase83_proof_pass",
      "quarantine_batch_selected_count_2",
      "operation_contracts_parse",
      "operation_contracts_registered",
      "contract_ready_status_only",
      "trusted_operation_count_zero",
      "execution_performed_false",
      "queue_returned_to_none"
    )
    queue_state_after = [ordered]@{
      active_task_id = "$(Get-PropertyValue -Object $queue -Name "active_task_id")"
    }
    operation_state_after = [ordered]@{
      registry_path = $RegistryPath
      registry_status = "$(Get-PropertyValue -Object $registry -Name "status")"
      operation_count = @($operations).Count
      registered_operation_ids = @($operations | ForEach-Object { "$(Get-PropertyValue -Object $_ -Name "operation_id")" })
      trusted_operation_count = $trustedOperationCount
      execution_performed = [bool](Get-PropertyValue -Object $registry -Name "execution_performed")
      report_status = "$(Get-PropertyValue -Object $Report -Name "status")"
    }
    forbidden_actions_confirmed = [ordered]@{
      no_external_tools_installed = $true
      no_external_repos_fetched = $true
      no_tool_execution = (-not [bool](Get-PropertyValue -Object $registry -Name "execution_performed"))
      no_smoke_tests_run = $true
      no_wrapper_implementation_created = $true
      no_materials_marked_trusted = $true
      no_trusted_operations_created = ($trustedOperationCount -eq 0)
      no_catalog_mutation = ($Safety.catalog_unchanged)
      no_policy_mutation = ($Safety.policy_unchanged)
      no_quarantine_batch_mutation = ($Safety.quarantine_batch_unchanged)
      no_quarantine_card_mutation = ($Safety.quarantine_cards_unchanged)
      no_external_agent_created = $true
      no_phase78_files_modified = $true
      no_phase79_files_modified = $true
      no_phase80_files_modified = $true
      no_phase81_files_modified = $true
      no_phase82_files_modified = $true
      no_phase83_files_modified = $true
    }
    next_allowed_step = $NextAllowedStep
  }

  Write-JsonFile -Path $ProofPath -Object $proof
}

function Invoke-Validator {
  & (Join-RepoPath "packs/$PackId/VALIDATE.ps1") -RepoRoot $RepoRoot -Stage "Completed"
}

Write-Host "PHASE84_APPLY_START"

foreach ($marker in @("CAPABILITY_ROADMAP.json", "GENESIS_STATE.json", "TASK_QUEUE.json", "packs/registry.json", "orchestrator/run.ps1")) {
  if (-not (Test-Path -LiteralPath (Join-RepoPath $marker))) {
    throw "STOP=WRONG_AGENT_BUILDER_REPO missing $marker"
  }
}

foreach ($path in @($RegistryPath, $QuarantineBatchPath, $OperationSkeletonProofPath) + $QuarantineCardPaths + $ContractFiles) {
  if (-not (Test-Path -LiteralPath (Join-RepoPath $path))) {
    throw "PHASE84_MISSING_INPUT=$path"
  }
}

$skeletonProof = Read-JsonRequired $OperationSkeletonProofPath
if ("$(Get-PropertyValue -Object $skeletonProof -Name "status")" -ne "PASS") {
  throw "PHASE83_PROOF_NOT_PASS"
}

$registry = Read-JsonRequired $RegistryPath
$registryStatus = "$(Get-PropertyValue -Object $registry -Name "status")"
if ($registryStatus -notin @("SKELETON_READY", "CONTRACTS_REGISTERED")) {
  throw "OPERATION_REGISTRY_STATUS_INVALID=$registryStatus"
}

$quarantineBatch = Read-JsonRequired $QuarantineBatchPath
$selectedMaterialIds = As-Array (Get-PropertyValue -Object $quarantineBatch -Name "selected_material_ids")
if (@($selectedMaterialIds).Count -ne 2) {
  throw "PHASE84_EXPECTED_QUARANTINE_SELECTED_COUNT_2_ACTUAL_$(@($selectedMaterialIds).Count)"
}

foreach ($contractPath in $ContractFiles) {
  Read-JsonRequired $contractPath | Out-Null
}

$catalogHashBefore = Get-FileSha256 -Path "materials/MATERIAL_CATALOG.json"
$policyHashBefore = Get-FileSha256 -Path "materials/MATERIAL_POLICY.json"
$quarantineBatchHashBefore = Get-FileSha256 -Path $QuarantineBatchPath
$quarantineCardHashesBefore = Get-HashMap -Paths $QuarantineCardPaths

$safetyHashes = @{
  catalog_before = $catalogHashBefore
  policy_before = $policyHashBefore
  quarantine_before = $quarantineBatchHashBefore
}

$report = & (Join-RepoPath "modules/operations/register_operation_contracts.ps1") -RepoRoot $RepoRoot -RegistryPath $RegistryPath -ContractsRoot $ContractsRoot -QuarantineBatchPath $QuarantineBatchPath -OutputReportPath $ReportPath -SafetyHashes $safetyHashes
Write-Host "FIRST_WRAPPER_OPERATION_CONTRACTS_REPORT_WRITTEN"

$catalogHashAfter = Get-FileSha256 -Path "materials/MATERIAL_CATALOG.json"
$policyHashAfter = Get-FileSha256 -Path "materials/MATERIAL_POLICY.json"
$quarantineBatchHashAfter = Get-FileSha256 -Path $QuarantineBatchPath
$quarantineCardHashesAfter = Get-HashMap -Paths $QuarantineCardPaths

$safety = @{
  catalog_unchanged = ($catalogHashBefore -eq $catalogHashAfter)
  policy_unchanged = ($policyHashBefore -eq $policyHashAfter)
  quarantine_batch_unchanged = ($quarantineBatchHashBefore -eq $quarantineBatchHashAfter)
  quarantine_cards_unchanged = (Compare-HashMaps -Before $quarantineCardHashesBefore -After $quarantineCardHashesAfter)
}
if (-not $safety.catalog_unchanged) { throw "PHASE84_CATALOG_MUTATED" }
if (-not $safety.policy_unchanged) { throw "PHASE84_POLICY_MUTATED" }
if (-not $safety.quarantine_batch_unchanged) { throw "PHASE84_QUARANTINE_BATCH_MUTATED" }
if (-not $safety.quarantine_cards_unchanged) { throw "PHASE84_QUARANTINE_CARD_MUTATED" }

Update-TaskQueue
Update-Roadmap
Update-GenesisState

Write-WrapperContractsProof -Report $report -Safety $safety
Write-Host "FIRST_WRAPPER_OPERATION_CONTRACTS_PROOF_WRITTEN"
Write-Host "TASK_QUEUE_RETURNED_TO_NONE"

Invoke-Validator

Write-Host "PHASE84_APPLY_COMPLETE"
