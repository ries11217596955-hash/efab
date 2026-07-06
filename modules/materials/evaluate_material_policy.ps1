[CmdletBinding()]
param(
  [string]$CatalogPath = "materials/MATERIAL_CATALOG.json",
  [string]$PolicyPath = "materials/MATERIAL_POLICY.json",
  [string]$OutputPath = "",
  [switch]$NoMutation,
  [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
)

$ErrorActionPreference = "Stop"

function Join-RepoPath {
  param([string]$Path)

  if ([System.IO.Path]::IsPathRooted($Path)) {
    return [System.IO.Path]::GetFullPath($Path)
  }

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
  param(
    [object[]]$Items,
    [string]$FieldName
  )

  $map = [ordered]@{}
  foreach ($item in $Items) {
    $key = "$(Get-PropertyValue -Object $item -Name $FieldName)"
    if ($key -eq "") {
      $key = "UNKNOWN"
    }
    if (-not $map.Contains($key)) {
      $map[$key] = 0
    }
    $map[$key] = [int]$map[$key] + 1
  }
  return $map
}

function Test-StringIn {
  param(
    [object]$Value,
    [object]$ExpectedValues
  )

  $text = "$Value"
  foreach ($expected in As-Array $ExpectedValues) {
    if ($text.Equals("$expected", [System.StringComparison]::OrdinalIgnoreCase)) {
      return $true
    }
  }
  return $false
}

function Test-StringContainsAny {
  param(
    [object]$Value,
    [object]$Needles
  )

  $text = "$Value"
  foreach ($needle in As-Array $Needles) {
    if ($text.IndexOf("$needle", [System.StringComparison]::OrdinalIgnoreCase) -ge 0) {
      return $true
    }
  }
  return $false
}

function Test-PolicyCondition {
  param(
    [object]$Entry,
    [object]$Condition
  )

  $all = Get-PropertyValue -Object $Condition -Name "all"
  if ($null -ne $all) {
    foreach ($child in As-Array $all) {
      if (-not (Test-PolicyCondition -Entry $Entry -Condition $child)) {
        return $false
      }
    }
    return $true
  }

  $any = Get-PropertyValue -Object $Condition -Name "any"
  if ($null -ne $any) {
    foreach ($child in As-Array $any) {
      if (Test-PolicyCondition -Entry $Entry -Condition $child) {
        return $true
      }
    }
    return $false
  }

  $field = Get-PropertyValue -Object $Condition -Name "field"
  if ($null -eq $field -or "$field" -eq "") {
    return $false
  }

  $property = Get-PropertyInfo -Object $Entry -Name "$field"
  $value = $null
  if ($null -ne $property) {
    $value = $property.Value
  }

  $missingOrEmpty = Get-PropertyValue -Object $Condition -Name "missing_or_empty"
  if ([bool]$missingOrEmpty) {
    return ($null -eq $property -or $null -eq $value -or "$value" -eq "")
  }

  $booleanEquals = Get-PropertyInfo -Object $Condition -Name "boolean_equals"
  if ($null -ne $booleanEquals) {
    return ([bool]$value -eq [bool]$booleanEquals.Value)
  }

  $equalsAny = Get-PropertyValue -Object $Condition -Name "equals_any"
  if ($null -ne $equalsAny) {
    return Test-StringIn -Value $value -ExpectedValues $equalsAny
  }

  $containsAny = Get-PropertyValue -Object $Condition -Name "contains_any"
  if ($null -ne $containsAny) {
    return Test-StringContainsAny -Value $value -Needles $containsAny
  }

  return $false
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

function Get-MaterialDecision {
  param(
    [object]$Entry,
    [object[]]$Rules,
    [string]$DefaultDecision
  )

  foreach ($rule in $Rules) {
    $match = Get-PropertyValue -Object $rule -Name "match"
    if (Test-PolicyCondition -Entry $Entry -Condition $match) {
      return [pscustomobject][ordered]@{
        decision = "$(Get-PropertyValue -Object $rule -Name "decision")"
        matched_rule_id = "$(Get-PropertyValue -Object $rule -Name "rule_id")"
        rationale = "$(Get-PropertyValue -Object $rule -Name "rationale")"
      }
    }
  }

  return [pscustomobject][ordered]@{
    decision = $DefaultDecision
    matched_rule_id = "default_decision"
    rationale = "No higher-priority policy rule matched."
  }
}

Write-Host "MATERIAL_POLICY_EVALUATION_START"

$catalog = Read-JsonRequired $CatalogPath
$policy = Read-JsonRequired $PolicyPath
$entries = As-Array (Get-PropertyValue -Object $catalog -Name "entries")
$rules = @(As-Array (Get-PropertyValue -Object $policy -Name "rules") | Sort-Object { [int](Get-PropertyValue -Object $_ -Name "priority") })
$defaultDecision = "$(Get-PropertyValue -Object $policy -Name "default_decision")"

$trustedCount = Get-TrustedCount -Entries $entries
if ($trustedCount -ne 0) {
  throw "MATERIAL_POLICY_TRUSTED_COUNT=$trustedCount"
}

$seenIds = @{}
foreach ($entry in $entries) {
  $materialId = "$(Get-PropertyValue -Object $entry -Name "material_id")"
  if ($materialId -eq "") {
    throw "MATERIAL_POLICY_MISSING_MATERIAL_ID"
  }
  if ($seenIds.ContainsKey($materialId)) {
    throw "MATERIAL_POLICY_DUPLICATE_MATERIAL_ID=$materialId"
  }
  $seenIds[$materialId] = $true
}

$decisions = @()
foreach ($entry in $entries) {
  $decisionResult = Get-MaterialDecision -Entry $entry -Rules $rules -DefaultDecision $defaultDecision
  if ($decisionResult.decision -eq "TRUSTED") {
    $materialId = Get-PropertyValue -Object $entry -Name "material_id"
    throw "MATERIAL_POLICY_FORBIDDEN_TRUST_DECISION=$materialId"
  }

  $decisions += [pscustomobject][ordered]@{
    material_id = "$(Get-PropertyValue -Object $entry -Name "material_id")"
    name = "$(Get-PropertyValue -Object $entry -Name "name")"
    status = "$(Get-PropertyValue -Object $entry -Name "status")"
    usage_mode = "$(Get-PropertyValue -Object $entry -Name "usage_mode")"
    risk_level = "$(Get-PropertyValue -Object $entry -Name "risk_level")"
    owner_approval_required = [bool](Get-PropertyValue -Object $entry -Name "owner_approval_required")
    source_origin = "$(Get-PropertyValue -Object $entry -Name "source_origin")"
    source_url = "$(Get-PropertyValue -Object $entry -Name "source_url")"
    license_status = "$(Get-PropertyValue -Object $entry -Name "license_status")"
    security_status = "$(Get-PropertyValue -Object $entry -Name "security_status")"
    decision = $decisionResult.decision
    matched_rule_id = $decisionResult.matched_rule_id
    rationale = $decisionResult.rationale
  }
}

$ownerApprovalCount = @($entries | Where-Object { [bool](Get-PropertyValue -Object $_ -Name "owner_approval_required") }).Count

$evaluation = [pscustomobject][ordered]@{
  evaluation_id = "MATERIAL_POLICY_EVALUATION"
  policy_id = "$(Get-PropertyValue -Object $policy -Name "policy_id")"
  policy_version = "$(Get-PropertyValue -Object $policy -Name "policy_version")"
  catalog_path = $CatalogPath
  policy_path = $PolicyPath
  catalog_entry_count = @($entries).Count
  decisions_count = @($decisions).Count
  trusted_count = $trustedCount
  owner_approval_required_count = $ownerApprovalCount
  decisions = @($decisions)
  counts_by_decision = (New-CountMap -Items $decisions -FieldName "decision")
  counts_by_status = (New-CountMap -Items $entries -FieldName "status")
  counts_by_risk_level = (New-CountMap -Items $entries -FieldName "risk_level")
  counts_by_usage_mode = (New-CountMap -Items $entries -FieldName "usage_mode")
  next_allowed_step = "$(Get-PropertyValue -Object $policy -Name "next_allowed_step")"
}

if ($OutputPath -ne "") {
  Write-JsonFile -Path $OutputPath -Object $evaluation
}

Write-Host "MATERIAL_CATALOG_ENTRY_COUNT=$(@($entries).Count)"
Write-Host "MATERIAL_POLICY_DECISIONS_COUNT=$(@($decisions).Count)"
Write-Host "MATERIAL_POLICY_TRUSTED_COUNT=0"
Write-Host "MATERIAL_POLICY_OWNER_APPROVAL_REQUIRED_COUNT=$ownerApprovalCount"
Write-Host "MATERIAL_POLICY_EVALUATION_COMPLETE"

return $evaluation
