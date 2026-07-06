[CmdletBinding()]
param(
  [ValidateSet("Auto", "Seed", "Completed")]
  [string]$Stage = "Auto",
  [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
)

$ErrorActionPreference = "Stop"

$CapabilityId = "material_acquisition_bootstrap_v1"
$PackId = "PHASE79_MATERIAL_ACQUISITION_BOOTSTRAP_V1"
$TaskId = "TASK_MATERIAL_ACQUISITION_BOOTSTRAP_V1_001"
$GateId = "MATERIAL_ACQUISITION_BOOTSTRAP_V1"
$ProofPath = "proofs/materials/MATERIAL_ACQUISITION_BOOTSTRAP_V1.json"
$ReportPath = "reports/materials/MATERIAL_ACQUISITION_BOOTSTRAP_REPORT.json"

$script:Failures = @()

function Join-RepoPath {
  param([string]$Path)
  return [System.IO.Path]::GetFullPath((Join-Path $RepoRoot $Path))
}

function Add-Failure {
  param([string]$Message)
  $script:Failures += $Message
}

function Read-JsonFile {
  param([string]$RelativePath)

  $path = Join-RepoPath $RelativePath
  if (-not (Test-Path -LiteralPath $path)) {
    Add-Failure "MISSING_JSON=$RelativePath"
    return $null
  }

  try {
    return (Get-Content -LiteralPath $path -Raw | ConvertFrom-Json)
  } catch {
    Add-Failure "INVALID_JSON=$RelativePath :: $($_.Exception.Message)"
    return $null
  }
}

function Get-PropertyValue {
  param(
    [object]$Object,
    [string[]]$Names
  )

  if ($null -eq $Object) {
    return $null
  }

  foreach ($name in $Names) {
    $property = $Object.PSObject.Properties | Where-Object { $_.Name -ieq $name } | Select-Object -First 1
    if ($null -ne $property) {
      return $property.Value
    }
  }

  return $null
}

function Get-PropertyInfo {
  param(
    [object]$Object,
    [string[]]$Names
  )

  if ($null -eq $Object) {
    return $null
  }

  foreach ($name in $Names) {
    $property = $Object.PSObject.Properties | Where-Object { $_.Name -ieq $name } | Select-Object -First 1
    if ($null -ne $property) {
      return $property
    }
  }

  return $null
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

function Assert-Path {
  param(
    [string]$Path,
    [string]$Kind,
    [bool]$Required = $true
  )

  if (-not (Test-Path -LiteralPath (Join-RepoPath $Path)) -and $Required) {
    Add-Failure "MISSING_$($Kind.ToUpperInvariant())=$Path"
  }
}

function Assert-ParserPass {
  param([string]$Path)

  $fullPath = Join-RepoPath $Path
  if (-not (Test-Path -LiteralPath $fullPath)) {
    Add-Failure "MISSING_SCRIPT=$Path"
    return
  }

  $tokens = $null
  $errors = $null
  [System.Management.Automation.Language.Parser]::ParseFile($fullPath, [ref]$tokens, [ref]$errors) | Out-Null
  if (@($errors).Count -gt 0) {
    Add-Failure "POWERSHELL_PARSE_FAIL=$Path"
  }
}

function Find-TaskEntry {
  param([object]$Queue)

  foreach ($task in As-Array (Get-PropertyValue -Object $Queue -Names @("tasks"))) {
    $id = Get-PropertyValue -Object $task -Names @("task_id", "id")
    if ("$id" -eq $TaskId) {
      return $task
    }
  }

  return $null
}

function Get-MatchingRegistryPacks {
  param([object]$Registry)

  return @(
    As-Array (Get-PropertyValue -Object $Registry -Names @("packs")) |
      Where-Object { "$(Get-PropertyValue -Object $_ -Names @("task_id"))" -eq $TaskId }
  )
}

function Resolve-ValidationStage {
  param([string]$RequestedStage)

  if ($RequestedStage -ne "Auto") {
    return $RequestedStage
  }

  $queue = Read-JsonFile "TASK_QUEUE.json"
  $activeTaskId = Get-PropertyValue -Object $queue -Names @("active_task_id", "activeTaskId")
  if ("$activeTaskId" -eq $TaskId) {
    return "Seed"
  }
  if ("$activeTaskId" -eq "NONE") {
    return "Completed"
  }
  return "Seed"
}

$requestedStage = $Stage
$Stage = Resolve-ValidationStage -RequestedStage $requestedStage

Write-Host "VALIDATION_STAGE=$Stage"
if ($requestedStage -eq "Auto") {
  Write-Host "VALIDATION_STAGE_AUTO_RESOLVED=$Stage"
}

foreach ($directory in @("materials/inbox", "materials/catalog", "materials/quarantine", "materials/trusted", "materials/rejected", "materials/reference_only")) {
  Assert-Path -Path $directory -Kind "directory" -Required $true
}

foreach ($schema in @("contracts/materials/material_request.schema.json", "contracts/materials/material_candidate.schema.json", "contracts/materials/material_catalog.schema.json", "contracts/materials/manual_scout_pass.schema.json")) {
  Assert-Path -Path $schema -Kind "schema" -Required $true
  Read-JsonFile $schema | Out-Null
}

foreach ($script in @("modules/materials/import_manual_scout_pass.ps1", "modules/materials/write_material_catalog_report.ps1", "packs/PHASE79_MATERIAL_ACQUISITION_BOOTSTRAP_V1/APPLY.ps1", "packs/PHASE79_MATERIAL_ACQUISITION_BOOTSTRAP_V1/VALIDATE.ps1")) {
  Assert-ParserPass -Path $script
}

$catalog = Read-JsonFile "materials/MATERIAL_CATALOG.json"
if ($null -ne $catalog) {
  $entriesProperty = Get-PropertyInfo -Object $catalog -Names @("entries")
  if ($null -eq $entriesProperty) {
    Add-Failure "CATALOG_ENTRIES_MISSING"
  }
  $entriesValue = $(if ($null -ne $entriesProperty) { $entriesProperty.Value } else { @() })
  $trustedEntries = @(
    As-Array $entriesValue |
      Where-Object { "$(Get-PropertyValue -Object $_ -Names @("status"))" -eq "TRUSTED" }
  )
  if (@($trustedEntries).Count -gt 0) {
    Add-Failure "CATALOG_HAS_TRUSTED_ENTRIES=$(@($trustedEntries).Count)"
  }
}

$queue = Read-JsonFile "TASK_QUEUE.json"
$taskEntry = Find-TaskEntry -Queue $queue
if ($null -eq $taskEntry) {
  Add-Failure "TASK_NOT_FOUND=$TaskId"
}

$registry = Read-JsonFile "packs/registry.json"
$matchingPacks = Get-MatchingRegistryPacks -Registry $registry
if (@($matchingPacks).Count -ne 1) {
  Add-Failure "REGISTRY_MATCH_COUNT=$(@($matchingPacks).Count)"
} else {
  $pack = $matchingPacks[0]
  $packId = Get-PropertyValue -Object $pack -Names @("pack_id", "id")
  $entryScript = Get-PropertyValue -Object $pack -Names @("entry_script")
  $shell = Get-PropertyValue -Object $pack -Names @("shell")
  if ("$packId" -ne $PackId) {
    Add-Failure "REGISTRY_PACK_ID_MISMATCH=$packId"
  }
  if ("$entryScript" -ne "packs/PHASE79_MATERIAL_ACQUISITION_BOOTSTRAP_V1/APPLY.ps1") {
    Add-Failure "REGISTRY_ENTRY_SCRIPT_MISMATCH=$entryScript"
  }
  if ("$shell" -ne "PowerShell") {
    Add-Failure "REGISTRY_SHELL_MISMATCH=$shell"
  }
}

Read-JsonFile "packs/PHASE79_MATERIAL_ACQUISITION_BOOTSTRAP_V1/PACK.json" | Out-Null
Read-JsonFile "tasks/TASK_MATERIAL_ACQUISITION_BOOTSTRAP_V1_001.json" | Out-Null

if ($Stage -eq "Seed") {
  $activeTaskId = Get-PropertyValue -Object $queue -Names @("active_task_id", "activeTaskId")
  if ("$activeTaskId" -ne $TaskId) {
    Add-Failure "SEED_ACTIVE_TASK_MISMATCH=$activeTaskId"
  }
  if ($null -ne $taskEntry) {
    $taskStatus = Get-PropertyValue -Object $taskEntry -Names @("status")
    if ("$taskStatus" -notin @("PENDING", "READY", "ACTIVE")) {
      Add-Failure "SEED_TASK_STATUS_INVALID=$taskStatus"
    }
  }
}

if ($Stage -eq "Completed") {
  Assert-Path -Path $ReportPath -Kind "file" -Required $true
  Assert-Path -Path $ProofPath -Kind "file" -Required $true

  $report = Read-JsonFile $ReportPath
  if ($null -ne $report) {
    $reportStatus = Get-PropertyValue -Object $report -Names @("status")
    if ("$reportStatus" -ne "PASS") {
      Add-Failure "REPORT_STATUS_NOT_PASS=$reportStatus"
    }
  }

  $proof = Read-JsonFile $ProofPath
  if ($null -ne $proof) {
    $proofStatus = Get-PropertyValue -Object $proof -Names @("status")
    if ("$proofStatus" -ne "PASS") {
      Add-Failure "PROOF_STATUS_NOT_PASS=$proofStatus"
    }
  }

  $activeTaskId = Get-PropertyValue -Object $queue -Names @("active_task_id", "activeTaskId")
  if ("$activeTaskId" -ne "NONE") {
    Add-Failure "ACTIVE_TASK_NOT_CLOSED=$activeTaskId"
  }
  if ($null -ne $taskEntry) {
    $taskStatus = Get-PropertyValue -Object $taskEntry -Names @("status")
    if ("$taskStatus" -ne "COMPLETED") {
      Add-Failure "TASK_STATUS_NOT_COMPLETED=$taskStatus"
    }
  }
}

if (@($script:Failures).Count -gt 0) {
  foreach ($failure in $script:Failures) {
    Write-Host "FAIL=$failure"
  }
  Write-Host "VALIDATION_RESULT=FAIL"
  throw "PHASE79_VALIDATION_FAILED"
}

if ($Stage -eq "Seed") {
  Write-Host "VALIDATION_RESULT=PASS_SEED"
} else {
  Write-Host "VALIDATION_RESULT=PASS"
}
