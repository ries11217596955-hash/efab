[CmdletBinding()]
param(
  [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
)

$ErrorActionPreference = "Stop"

$StatusValues = @(
  "DISCOVERED",
  "CANDIDATE",
  "QUARANTINED",
  "WRAPPED",
  "TESTED",
  "TRUSTED",
  "REJECTED",
  "REFERENCE_ONLY",
  "OWNER_APPROVAL_REQUIRED"
)

$UsageModes = @(
  "USE_AS_TOOL",
  "WRAP_ONLY",
  "COPY_WITH_ATTRIBUTION",
  "ADAPT",
  "REIMPLEMENT",
  "REFERENCE_ONLY",
  "ASK_PERMISSION",
  "REJECT"
)

$RiskLevels = @(
  "LOW",
  "MEDIUM",
  "HIGH",
  "FORBIDDEN",
  "UNKNOWN"
)

$MaterialTypes = @(
  "CLI",
  "LIBRARY",
  "TEMPLATE",
  "WORKFLOW",
  "DOCKER_IMAGE",
  "POLICY",
  "SCHEMA",
  "EXAMPLE",
  "RESEARCH_REFERENCE",
  "SERVICE"
)

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

  $directory = Split-Path -Parent $Path
  if (-not (Test-Path -LiteralPath $directory)) {
    New-Item -ItemType Directory -Path $directory -Force | Out-Null
  }

  $json = ($Object | ConvertTo-Json -Depth 100) -replace "`r`n", "`n"
  if (-not $json.EndsWith("`n")) {
    $json += "`n"
  }
  [System.IO.File]::WriteAllText($Path, $json, [System.Text.UTF8Encoding]::new($false))
}

function Read-JsonRequired {
  param([string]$RelativePath)

  $path = Join-RepoPath $RelativePath
  if (-not (Test-Path -LiteralPath $path)) {
    throw "MISSING_JSON=$RelativePath"
  }

  return (Get-Content -LiteralPath $path -Raw | ConvertFrom-Json)
}

function Get-PropertyValue {
  param(
    [object]$Object,
    [string]$Name
  )

  if ($null -eq $Object) {
    return $null
  }

  $property = $Object.PSObject.Properties | Where-Object { $_.Name -ieq $Name } | Select-Object -First 1
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

function New-CountMap {
  param([string[]]$Keys)

  $map = [ordered]@{}
  foreach ($key in $Keys) {
    $map[$key] = 0
  }
  return $map
}

function Add-Count {
  param(
    [object]$Map,
    [object]$Key
  )

  $name = $(if ($null -ne $Key -and "$Key" -ne "") { "$Key" } else { "UNKNOWN" })
  if (-not $Map.Contains($name)) {
    $Map[$name] = 0
  }
  $Map[$name] = [int]$Map[$name] + 1
}

function Get-PathStatus {
  param(
    [string]$Path,
    [string]$Kind
  )

  return [ordered]@{
    path = $Path
    kind = $Kind
    exists = (Test-Path -LiteralPath (Join-RepoPath $Path))
  }
}

$CatalogPath = "materials/MATERIAL_CATALOG.json"
$catalog = Read-JsonRequired $CatalogPath
$entries = As-Array (Get-PropertyValue -Object $catalog -Name "entries")

$countsByStatus = New-CountMap -Keys $StatusValues
$countsByType = New-CountMap -Keys $MaterialTypes
$countsByUsageMode = New-CountMap -Keys $UsageModes
$countsByRiskLevel = New-CountMap -Keys $RiskLevels

$trustedCount = 0
foreach ($entry in $entries) {
  $status = Get-PropertyValue -Object $entry -Name "status"
  $type = Get-PropertyValue -Object $entry -Name "material_type"
  $usageMode = Get-PropertyValue -Object $entry -Name "usage_mode"
  $riskLevel = Get-PropertyValue -Object $entry -Name "risk_level"

  Add-Count -Map $countsByStatus -Key $status
  Add-Count -Map $countsByType -Key $type
  Add-Count -Map $countsByUsageMode -Key $usageMode
  Add-Count -Map $countsByRiskLevel -Key $riskLevel

  if ("$status" -eq "TRUSTED") {
    $trustedCount++
  }
}

$schemaPaths = @(
  "contracts/materials/material_request.schema.json",
  "contracts/materials/material_candidate.schema.json",
  "contracts/materials/material_catalog.schema.json",
  "contracts/materials/manual_scout_pass.schema.json"
)

$materialDirectories = @(
  "materials/inbox",
  "materials/catalog",
  "materials/quarantine",
  "materials/trusted",
  "materials/rejected",
  "materials/reference_only"
)

$schemaStatuses = @($schemaPaths | ForEach-Object { Get-PathStatus -Path $_ -Kind "schema" })
$directoryStatuses = @($materialDirectories | ForEach-Object { Get-PathStatus -Path $_ -Kind "directory" })
$missingRequired = @(
  @($schemaStatuses + $directoryStatuses) |
    Where-Object { -not $_.exists } |
    ForEach-Object { $_.path }
)

$status = $(if (@($missingRequired).Count -eq 0 -and $trustedCount -eq 0) { "PASS" } else { "FAIL" })
$report = [ordered]@{
  report_id = "MATERIAL_ACQUISITION_BOOTSTRAP_REPORT"
  phase = "PHASE_79"
  capability_id = "material_acquisition_bootstrap_v1"
  status = $status
  generated_at = Get-UtcStamp
  catalog_path = $CatalogPath
  schema_paths = $schemaStatuses
  material_directories = $directoryStatuses
  catalog_entry_count = @($entries).Count
  counts_by_status = $countsByStatus
  counts_by_type = $countsByType
  counts_by_usage_mode = $countsByUsageMode
  counts_by_risk_level = $countsByRiskLevel
  policy_summary = [ordered]@{
    no_trusted_materials_in_phase79 = ($trustedCount -eq 0)
    trusted_entry_count = $trustedCount
    no_external_tools_required = $true
    full_contract_first = $true
    phased_execution_second = $true
  }
  missing_required_paths = $missingRequired
  next_allowed_step = "STEP4_MANUAL_SCOUT_PASS_001"
  cut_list = @(
    "Do not install external tools in PHASE79.",
    "Do not discover or scout materials in PHASE79.",
    "Do not mark materials TRUSTED in PHASE79.",
    "Do not create external agents in PHASE79.",
    "Do not modify PHASE78 files in PHASE79."
  )
}

$reportPath = Join-RepoPath "reports/materials/MATERIAL_ACQUISITION_BOOTSTRAP_REPORT.json"
Write-JsonFile -Path $reportPath -Object $report

Write-Host "MATERIAL_BOOTSTRAP_REPORT_WRITTEN"
Write-Host "OUTPUT=reports/materials/MATERIAL_ACQUISITION_BOOTSTRAP_REPORT.json"
if ($status -ne "PASS") {
  throw "MATERIAL_BOOTSTRAP_REPORT_FAILED"
}
