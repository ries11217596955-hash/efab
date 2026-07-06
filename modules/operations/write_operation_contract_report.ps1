[CmdletBinding()]
param(
  [string]$RegistryPath = "operations/registry.json",
  [string]$ContractSchemaPath = "contracts/operations/operation_contract.schema.json",
  [string]$RegistrySchemaPath = "contracts/operations/operation_registry.schema.json",
  [string]$QuarantineBatchPath = "materials/quarantine/QUARANTINE_BATCH_001.json",
  [string]$OutputPath = "reports/operations/OPERATION_CONTRACT_SKELETON_REPORT.json",
  [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
)

$ErrorActionPreference = "Stop"

$CapabilityId = "operation_contract_skeleton_v1"
$NextAllowedStep = "PHASE84_FIRST_WRAPPER_OPERATION_CONTRACTS_V1"

function Join-RepoPath {
  param([string]$Path)

  if ([System.IO.Path]::IsPathRooted($Path)) {
    return [System.IO.Path]::GetFullPath($Path)
  }

  return [System.IO.Path]::GetFullPath((Join-Path $RepoRoot $Path))
}

function Get-UtcStamp {
  return (Get-Date).ToUniversalTime().ToString("o")
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

Write-Host "OPERATION_CONTRACT_REPORT_START"

$registry = Read-JsonRequired $RegistryPath
Write-Host "OPERATION_REGISTRY_READY"

$contractSchema = Read-JsonRequired $ContractSchemaPath
$contractSchema | Out-Null
Write-Host "OPERATION_CONTRACT_SCHEMA_READY"

$registrySchema = Read-JsonRequired $RegistrySchemaPath
$registrySchema | Out-Null
Write-Host "OPERATION_REGISTRY_SCHEMA_READY"

$quarantineBatch = Read-JsonRequired $QuarantineBatchPath
$selectedMaterials = As-Array (Get-PropertyValue -Object $quarantineBatch -Name "selected_material_ids")
$operations = As-Array (Get-PropertyValue -Object $registry -Name "operations")

$trustedOperations = @($operations | Where-Object { "$(Get-PropertyValue -Object $_ -Name "status")" -eq "TRUSTED_OPERATION" })
$executionPerformed = $false
foreach ($operation in $operations) {
  $executionMode = "$(Get-PropertyValue -Object $operation -Name "execution_mode")"
  if ($executionMode -notin @("NO_EXECUTION", "DRY_RUN_ONLY", "")) {
    $executionPerformed = $true
  }
}

$installPerformed = $false
$externalFetchPerformed = $false

$report = [ordered]@{
  report_id = "OPERATION_CONTRACT_SKELETON_REPORT"
  phase = "PHASE_83"
  capability_id = $CapabilityId
  status = $(if (@($trustedOperations).Count -eq 0 -and -not $executionPerformed -and -not $installPerformed -and -not $externalFetchPerformed) { "PASS" } else { "FAIL" })
  generated_at = Get-UtcStamp
  operation_contract_schema_path = $ContractSchemaPath
  operation_registry_schema_path = $RegistrySchemaPath
  operation_registry_path = $RegistryPath
  quarantine_batch_path = $QuarantineBatchPath
  quarantine_selected_count = @($selectedMaterials).Count
  operation_count = @($operations).Count
  trusted_operation_count = @($trustedOperations).Count
  execution_performed = $executionPerformed
  install_performed = $installPerformed
  external_fetch_performed = $externalFetchPerformed
  registry_status = "$(Get-PropertyValue -Object $registry -Name "status")"
  policy_summary = [ordered]@{
    skeleton_only = $true
    operations_empty_by_default = (@($operations).Count -eq 0)
    no_trusted_operations = (@($trustedOperations).Count -eq 0)
    no_execution_performed = (-not $executionPerformed)
    no_install_performed = (-not $installPerformed)
    no_external_fetch_performed = (-not $externalFetchPerformed)
    quarantine_material_ids_are_data = @($selectedMaterials)
  }
  next_allowed_step = $NextAllowedStep
  cut_list = @(
    "Do not create real wrapper contracts in PHASE83.",
    "Do not install tools.",
    "Do not fetch external repositories.",
    "Do not run candidate tools.",
    "Do not run smoke tests.",
    "Do not create TRUSTED_OPERATION entries.",
    "Do not create external agents."
  )
}

Write-JsonFile -Path $OutputPath -Object $report

Write-Host "QUARANTINE_BATCH_SELECTED_COUNT=$(@($selectedMaterials).Count)"
Write-Host "OPERATION_REGISTRY_OPERATION_COUNT=$(@($operations).Count)"
Write-Host "TRUSTED_OPERATION_COUNT=$(@($trustedOperations).Count)"
Write-Host "OPERATION_EXECUTION_PERFORMED=FALSE"
Write-Host "OPERATION_CONTRACT_REPORT_WRITTEN=$OutputPath"
Write-Host "OPERATION_CONTRACT_REPORT_COMPLETE"

if ($report.status -ne "PASS") {
  throw "OPERATION_CONTRACT_REPORT_FAILED"
}

return [pscustomobject]$report
