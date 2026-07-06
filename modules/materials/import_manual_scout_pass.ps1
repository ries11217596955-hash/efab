[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)]
  [string]$ScoutPassPath,
  [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path,
  [string]$MaterialCatalogPath = "materials/MATERIAL_CATALOG.json",
  [string]$ImportPhase = "PHASE80",
  [string]$NextAllowedStep = "STEP6_OR_PHASE81_MATERIAL_ADMISSION_POLICY_V1",
  [switch]$CommitImport,
  [switch]$AllowCatalogMutation
)

$ErrorActionPreference = "Stop"

$RequiredScoutPassFields = @(
  "scout_pass_id",
  "created_at",
  "created_by",
  "purpose",
  "candidates",
  "cut_list"
)

$RequiredCandidateFields = @(
  "material_id",
  "name",
  "material_type",
  "source_url",
  "source_origin",
  "provenance_status",
  "license_status",
  "security_status",
  "usage_mode",
  "status",
  "risk_level",
  "owner_approval_required",
  "notes"
)

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

function Copy-Candidate {
  param(
    [object]$Candidate,
    [string]$ScoutPassId,
    [string]$ImportedAt
  )

  if ("$(Get-PropertyValue -Object $Candidate -Name "status")" -eq "TRUSTED") {
    $materialId = Get-PropertyValue -Object $Candidate -Name "material_id"
    throw "TRUSTED_CANDIDATE_FORBIDDEN=$materialId"
  }

  $entry = [ordered]@{}
  foreach ($property in $Candidate.PSObject.Properties) {
    $entry[$property.Name] = $property.Value
  }
  $entry["imported_from_scout_pass"] = $ScoutPassId
  $entry["imported_at"] = $ImportedAt
  $entry["admission_status"] = "NOT_ADMITTED"
  $entry["quarantine_status"] = "NOT_QUARANTINED"
  $entry["trust_status"] = "NOT_TRUSTED"

  return [pscustomobject]$entry
}

function Get-TrustedCount {
  param([object[]]$Entries)

  return @(
    $Entries |
      Where-Object {
        "$(Get-PropertyValue -Object $_ -Name "status")" -eq "TRUSTED" -or
        "$(Get-PropertyValue -Object $_ -Name "trust_status")" -eq "TRUSTED"
      }
  ).Count
}

$doImport = [bool]($CommitImport -or $AllowCatalogMutation)

Write-Host "MANUAL_SCOUT_PASS_IMPORT_START"

$scoutPass = Read-JsonRequired $ScoutPassPath
Assert-RequiredFields -Object $scoutPass -Fields $RequiredScoutPassFields -Context "MANUAL_SCOUT_PASS"

$scoutPassId = "$(Get-PropertyValue -Object $scoutPass -Name "scout_pass_id")"
$candidates = As-Array (Get-PropertyValue -Object $scoutPass -Name "candidates")

foreach ($candidate in $candidates) {
  $materialId = Get-PropertyValue -Object $candidate -Name "material_id"
  Assert-RequiredFields -Object $candidate -Fields $RequiredCandidateFields -Context "MATERIAL_CANDIDATE_$materialId"
}

$catalogPath = $MaterialCatalogPath
$catalog = Read-JsonRequired $catalogPath
$entriesProperty = Get-PropertyInfo -Object $catalog -Name "entries"
if ($null -eq $entriesProperty) {
  Set-PropertyValue -Object $catalog -Name "entries" -Value @()
  $entries = @()
} else {
  $entries = As-Array $entriesProperty.Value
}

$existingIds = @{}
foreach ($entry in $entries) {
  $id = Get-PropertyValue -Object $entry -Name "material_id"
  if ($null -ne $id -and "$id" -ne "") {
    $existingIds["$id"] = $true
  }
}

$importedEntries = @()
$duplicateIds = @()
$importedAt = Get-UtcStamp
foreach ($candidate in $candidates) {
  $materialId = "$(Get-PropertyValue -Object $candidate -Name "material_id")"
  if ($existingIds.ContainsKey($materialId)) {
    $duplicateIds += $materialId
    continue
  }

  $importedEntries += Copy-Candidate -Candidate $candidate -ScoutPassId $scoutPassId -ImportedAt $importedAt
  $existingIds[$materialId] = $true
}

$entriesBefore = @($entries).Count
$entriesImported = @($importedEntries).Count
$entriesAfterIfCommitted = $entriesBefore + $entriesImported
$reportedEntriesAfter = $(if ($doImport) { $entriesAfterIfCommitted } else { $entriesBefore })

Write-Host "MANUAL_SCOUT_PASS_ID=$scoutPassId"
Write-Host "MANUAL_SCOUT_PASS_CANDIDATE_COUNT=$(@($candidates).Count)"
Write-Host "CATALOG_ENTRIES_BEFORE=$entriesBefore"
Write-Host "CATALOG_ENTRIES_IMPORTED=$entriesImported"
Write-Host "CATALOG_DUPLICATES_SKIPPED=$(@($duplicateIds).Count)"
Write-Host "CATALOG_ENTRIES_AFTER=$reportedEntriesAfter"

if (-not $doImport) {
  Write-Host "CATALOG_TRUSTED_COUNT=$(Get-TrustedCount -Entries $entries)"
  Write-Host "CATALOG_MUTATED=FALSE"
  Write-Host "FULL_IMPORT_PHASE=$ImportPhase"
  Write-Host "MANUAL_SCOUT_PASS_IMPORT_COMPLETE"
  return [pscustomobject][ordered]@{
    status = "DRY_RUN_ONLY"
    phase = $ImportPhase
    scout_pass_id = $scoutPassId
    candidate_count = @($candidates).Count
    catalog_entries_before = $entriesBefore
    catalog_entries_imported = $entriesImported
    duplicates_skipped = @($duplicateIds).Count
    duplicate_material_ids = @($duplicateIds)
    catalog_entries_after = $entriesBefore
    trusted_count_after = (Get-TrustedCount -Entries $entries)
    imported_material_ids = @($importedEntries | ForEach-Object { Get-PropertyValue -Object $_ -Name "material_id" })
    not_imported_material_ids = @($duplicateIds)
    catalog_mutated = $false
    catalog_path = $catalogPath
    next_allowed_step = $NextAllowedStep
    full_import_phase = $ImportPhase
  }
}

$newEntries = @($entries + $importedEntries) |
  Sort-Object { "$(Get-PropertyValue -Object $_ -Name "material_id")" }

if ((Get-TrustedCount -Entries $newEntries) -gt 0) {
  throw "CATALOG_TRUSTED_COUNT_NOT_ZERO"
}

Set-PropertyValue -Object $catalog -Name "entries" -Value @($newEntries)
Set-PropertyValue -Object $catalog -Name "last_imported_scout_pass_id" -Value $scoutPassId
Set-PropertyValue -Object $catalog -Name "last_imported_at" -Value $importedAt

Write-JsonFile -Path (Join-RepoPath $catalogPath) -Object $catalog

Write-Host "CATALOG_TRUSTED_COUNT=0"
Write-Host "CATALOG_MUTATED=TRUE"
Write-Host "FULL_IMPORT_PHASE=$ImportPhase"
Write-Host "MANUAL_SCOUT_PASS_IMPORT_COMPLETE"

return [pscustomobject][ordered]@{
  status = "PASS"
  phase = $ImportPhase
  scout_pass_id = $scoutPassId
  candidate_count = @($candidates).Count
  catalog_entries_before = $entriesBefore
  catalog_entries_imported = $entriesImported
  duplicates_skipped = @($duplicateIds).Count
  duplicate_material_ids = @($duplicateIds)
  catalog_entries_after = @($newEntries).Count
  trusted_count_after = 0
  imported_material_ids = @($importedEntries | ForEach-Object { Get-PropertyValue -Object $_ -Name "material_id" })
  not_imported_material_ids = @($duplicateIds)
  catalog_mutated = $true
  catalog_path = $catalogPath
  next_allowed_step = $NextAllowedStep
  full_import_phase = $ImportPhase
}
