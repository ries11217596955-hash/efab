[CmdletBinding()]
param(
  [string]$RegistryPath = "operations/registry.json",
  [string]$ContractsRoot = "operations/contracts",
  [string]$QuarantineBatchPath = "materials/quarantine/QUARANTINE_BATCH_001.json",
  [string]$OutputReportPath = "reports/operations/FIRST_WRAPPER_OPERATION_CONTRACTS_REPORT.json",
  [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path,
  [string[]]$OperationContractFiles = @(
    "validate_json_schema_with_ajv.contract.json",
    "validate_json_schema_with_python_jsonschema.contract.json"
  ),
  [hashtable]$SafetyHashes = @{}
)

$ErrorActionPreference = "Stop"

$CapabilityId = "first_wrapper_operation_contracts_v1"
$NextAllowedStep = "PHASE85_FIRST_SMOKE_INSTALL_TRIAL_V1"
$RequiredContractFields = @(
  "operation_id",
  "operation_name",
  "operation_type",
  "status",
  "phase_created",
  "related_material_id",
  "related_quarantine_card_path",
  "purpose",
  "input_contract",
  "output_contract",
  "allowed_reads",
  "allowed_writes",
  "forbidden_actions",
  "execution_mode",
  "risk_level",
  "smoke_test_plan",
  "proof_requirements",
  "rollback_notes",
  "owner_approval_required",
  "created_at",
  "next_allowed_step"
)
$RequiredContractSpecs = @{
  "validate_json_schema_with_ajv.contract.json" = @{
    operation_id = "validate_json_schema_with_ajv"
    operation_name = "Validate JSON Schema with Ajv"
    operation_type = "VALIDATE_JSON_SCHEMA"
    status = "CONTRACT_READY"
    phase_created = "PHASE_84"
    related_material_id = "mat_json_schema_ajv_001"
    related_quarantine_card_path = "materials/quarantine/mat_json_schema_ajv_001/MATERIAL_CARD.json"
    execution_mode = "NO_EXECUTION"
    risk_level = "LOW"
    owner_approval_required = $false
    next_allowed_step = "PHASE85_FIRST_SMOKE_INSTALL_TRIAL_V1"
  }
  "validate_json_schema_with_python_jsonschema.contract.json" = @{
    operation_id = "validate_json_schema_with_python_jsonschema"
    operation_name = "Validate JSON Schema with python-jsonschema"
    operation_type = "VALIDATE_JSON_SCHEMA"
    status = "CONTRACT_READY"
    phase_created = "PHASE_84"
    related_material_id = "mat_python_jsonschema_001"
    related_quarantine_card_path = "materials/quarantine/mat_python_jsonschema_001/MATERIAL_CARD.json"
    execution_mode = "NO_EXECUTION"
    risk_level = "LOW"
    owner_approval_required = $false
    next_allowed_step = "PHASE85_FIRST_SMOKE_INSTALL_TRIAL_V1"
  }
}

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

function Assert-RequiredFields {
  param(
    [object]$Object,
    [string[]]$Fields,
    [string]$Context
  )

  $missing = @()
  foreach ($field in $Fields) {
    if ($null -eq (Get-PropertyInfo -Object $Object -Name $field)) {
      $missing += $field
    }
  }
  if (@($missing).Count -gt 0) {
    throw "$Context`_MISSING_FIELDS=$($missing -join ',')"
  }
}

function Assert-ExpectedContractSpec {
  param(
    [object]$Contract,
    [string]$FileName
  )

  if (-not $RequiredContractSpecs.ContainsKey($FileName)) {
    throw "UNEXPECTED_OPERATION_CONTRACT_FILE=$FileName"
  }

  $spec = $RequiredContractSpecs[$FileName]
  foreach ($key in $spec.Keys) {
    $actual = Get-PropertyValue -Object $Contract -Name $key
    $expected = $spec[$key]
    if ($expected -is [bool]) {
      if ([bool]$actual -ne $expected) {
        throw "OPERATION_CONTRACT_VALUE_MISMATCH=$FileName::$key"
      }
    } elseif ("$actual" -ne "$expected") {
      throw "OPERATION_CONTRACT_VALUE_MISMATCH=$FileName::$key"
    }
  }
}

function Get-FileHashIfProvided {
  param([string]$Key)

  if ($SafetyHashes.ContainsKey($Key)) {
    return "$($SafetyHashes[$Key])"
  }
  return ""
}

function New-OperationSummary {
  param([object]$Contract)

  return [ordered]@{
    operation_id = "$(Get-PropertyValue -Object $Contract -Name "operation_id")"
    operation_name = "$(Get-PropertyValue -Object $Contract -Name "operation_name")"
    operation_type = "$(Get-PropertyValue -Object $Contract -Name "operation_type")"
    status = "$(Get-PropertyValue -Object $Contract -Name "status")"
    related_material_id = "$(Get-PropertyValue -Object $Contract -Name "related_material_id")"
    related_quarantine_card_path = "$(Get-PropertyValue -Object $Contract -Name "related_quarantine_card_path")"
    contract_path = "operations/contracts/$([System.IO.Path]::GetFileName($Contract.__contract_file_name))"
    execution_mode = "$(Get-PropertyValue -Object $Contract -Name "execution_mode")"
    risk_level = "$(Get-PropertyValue -Object $Contract -Name "risk_level")"
    owner_approval_required = [bool](Get-PropertyValue -Object $Contract -Name "owner_approval_required")
    next_allowed_step = "$(Get-PropertyValue -Object $Contract -Name "next_allowed_step")"
  }
}

Write-Host "FIRST_WRAPPER_OPERATION_CONTRACTS_START"

$registry = Read-JsonRequired $RegistryPath
$quarantineBatch = Read-JsonRequired $QuarantineBatchPath
$selectedMaterialIds = As-Array (Get-PropertyValue -Object $quarantineBatch -Name "selected_material_ids")
foreach ($requiredMaterialId in @("mat_json_schema_ajv_001", "mat_python_jsonschema_001")) {
  if ($selectedMaterialIds -notcontains $requiredMaterialId) {
    throw "QUARANTINE_SELECTED_MISSING=$requiredMaterialId"
  }
}

$contracts = @()
foreach ($fileName in $OperationContractFiles) {
  $contractPath = (Join-Path $ContractsRoot $fileName).Replace("\", "/")
  $contract = Read-JsonRequired $contractPath
  $contract | Add-Member -NotePropertyName "__contract_file_name" -NotePropertyValue $fileName -Force
  Assert-RequiredFields -Object $contract -Fields $RequiredContractFields -Context "OPERATION_CONTRACT_$fileName"
  Assert-ExpectedContractSpec -Contract $contract -FileName $fileName

  $operationId = "$(Get-PropertyValue -Object $contract -Name "operation_id")"
  Write-Host "OPERATION_CONTRACT_FOUND=$operationId"

  if ("$(Get-PropertyValue -Object $contract -Name "status")" -ne "CONTRACT_READY") {
    throw "OPERATION_CONTRACT_STATUS_NOT_READY=$operationId"
  }
  if ("$(Get-PropertyValue -Object $contract -Name "execution_mode")" -ne "NO_EXECUTION") {
    throw "OPERATION_CONTRACT_EXECUTION_MODE_NOT_NO_EXECUTION=$operationId"
  }
  if ("$(Get-PropertyValue -Object $contract -Name "status")" -eq "TRUSTED_OPERATION") {
    throw "TRUSTED_OPERATION_FORBIDDEN=$operationId"
  }

  $contracts += $contract
}

$existingOperations = As-Array (Get-PropertyValue -Object $registry -Name "operations")
$operationById = [ordered]@{}
foreach ($operation in $existingOperations) {
  $operationId = "$(Get-PropertyValue -Object $operation -Name "operation_id")"
  if ($operationId -ne "") {
    $operationById[$operationId] = $operation
  }
}

foreach ($contract in $contracts) {
  $summary = [pscustomobject](New-OperationSummary -Contract $contract)
  $operationId = "$(Get-PropertyValue -Object $summary -Name "operation_id")"
  $operationById[$operationId] = $summary
  Write-Host "OPERATION_CONTRACT_REGISTERED=$operationId"
}

$operations = @($operationById.Values | Sort-Object { "$(Get-PropertyValue -Object $_ -Name "operation_id")" })
$trustedOperationCount = @($operations | Where-Object { "$(Get-PropertyValue -Object $_ -Name "status")" -eq "TRUSTED_OPERATION" }).Count
if ($trustedOperationCount -ne 0) {
  throw "TRUSTED_OPERATION_COUNT=$trustedOperationCount"
}

Set-PropertyValue -Object $registry -Name "status" -Value "CONTRACTS_REGISTERED"
Set-PropertyValue -Object $registry -Name "generated_at" -Value (Get-UtcStamp)
Set-PropertyValue -Object $registry -Name "operations" -Value @($operations)
Set-PropertyValue -Object $registry -Name "policy" -Value ([ordered]@{
  phase = "PHASE_84"
  capability_id = $CapabilityId
  trust_policy = "PHASE84 cannot create TRUSTED_OPERATION entries or mark materials trusted."
  execution_policy = "PHASE84 creates operation contracts only; execution_mode must remain NO_EXECUTION and no candidate tools may run."
  install_performed = $false
  external_fetch_performed = $false
  smoke_tests_run = $false
  wrapper_implementations_created = $false
})
Set-PropertyValue -Object $registry -Name "trusted_operation_count" -Value 0
Set-PropertyValue -Object $registry -Name "execution_performed" -Value $false
Set-PropertyValue -Object $registry -Name "next_allowed_step" -Value $NextAllowedStep
Write-JsonFile -Path $RegistryPath -Object $registry

$registeredIds = @($operations | ForEach-Object { "$(Get-PropertyValue -Object $_ -Name "operation_id")" })
$relatedMaterialIds = @($contracts | ForEach-Object { "$(Get-PropertyValue -Object $_ -Name "related_material_id")" })
$contractPaths = @($OperationContractFiles | ForEach-Object { "operations/contracts/$_" })

$report = [ordered]@{
  report_id = "FIRST_WRAPPER_OPERATION_CONTRACTS_REPORT"
  phase = "PHASE_84"
  capability_id = $CapabilityId
  status = "PASS"
  generated_at = Get-UtcStamp
  operation_registry_path = $RegistryPath
  contract_paths = @($contractPaths)
  registered_operation_ids = @($registeredIds)
  operation_count = @($operations).Count
  trusted_operation_count = $trustedOperationCount
  execution_performed = $false
  install_performed = $false
  external_fetch_performed = $false
  quarantine_batch_path = $QuarantineBatchPath
  related_material_ids = @($relatedMaterialIds)
  registry_status_after = "CONTRACTS_REGISTERED"
  catalog_unchanged = $true
  policy_unchanged = $true
  quarantine_unchanged = $true
  quarantine_cards_unchanged = $true
  safety_hashes = [ordered]@{
    catalog_before = (Get-FileHashIfProvided -Key "catalog_before")
    catalog_after = (Get-FileHashIfProvided -Key "catalog_after")
    policy_before = (Get-FileHashIfProvided -Key "policy_before")
    policy_after = (Get-FileHashIfProvided -Key "policy_after")
    quarantine_before = (Get-FileHashIfProvided -Key "quarantine_before")
    quarantine_after = (Get-FileHashIfProvided -Key "quarantine_after")
  }
  next_allowed_step = $NextAllowedStep
  cut_list = @(
    "Do not create executable wrapper implementations.",
    "Do not install tools.",
    "Do not fetch external repositories.",
    "Do not run candidate tools.",
    "Do not run smoke tests.",
    "Do not create TRUSTED_OPERATION entries.",
    "Do not create external agents."
  )
}

Write-JsonFile -Path $OutputReportPath -Object $report

Write-Host "OPERATION_REGISTRY_UPDATED=$RegistryPath"
Write-Host "OPERATION_CONTRACT_COUNT=$(@($operations).Count)"
Write-Host "TRUSTED_OPERATION_COUNT=0"
Write-Host "OPERATION_EXECUTION_PERFORMED=FALSE"
Write-Host "FIRST_WRAPPER_OPERATION_CONTRACTS_REPORT_WRITTEN=$OutputReportPath"
Write-Host "FIRST_WRAPPER_OPERATION_CONTRACTS_COMPLETE"

return [pscustomobject]$report
