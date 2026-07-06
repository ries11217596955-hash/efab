[CmdletBinding()]
param(
  [ValidateSet("Auto", "Seed", "Completed")]
  [string]$Stage = "Auto",
  [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
)

$ErrorActionPreference = "Stop"

$CapabilityId = "manual_scout_pass_import_v1"
$PackId = "PHASE80_MANUAL_SCOUT_PASS_IMPORT_V1"
$TaskId = "TASK_MANUAL_SCOUT_PASS_IMPORT_V1_001"
$ScoutPassPath = "materials/inbox/MANUAL_SCOUT_PASS_001.json"
$CatalogPath = "materials/MATERIAL_CATALOG.json"
$ReportPath = "reports/materials/MANUAL_SCOUT_PASS_IMPORT_REPORT.json"
$ProofPath = "proofs/materials/MANUAL_SCOUT_PASS_IMPORT_V1.json"
$NextAllowedStep = "STEP6_OR_PHASE81_MATERIAL_ADMISSION_POLICY_V1"

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

function Assert-Path {
  param([string]$Path, [string]$Kind)

  if (-not (Test-Path -LiteralPath (Join-RepoPath $Path))) {
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

  foreach ($task in As-Array (Get-PropertyValue -Object $Queue -Name "tasks")) {
    if ("$(Get-PropertyValue -Object $task -Name "task_id")" -eq $TaskId) {
      return $task
    }
  }
  return $null
}

function Get-MatchingRegistryPacks {
  param([object]$Registry)

  return @(
    As-Array (Get-PropertyValue -Object $Registry -Name "packs") |
      Where-Object { "$(Get-PropertyValue -Object $_ -Name "task_id")" -eq $TaskId }
  )
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

function Resolve-ValidationStage {
  param([string]$RequestedStage)

  if ($RequestedStage -ne "Auto") {
    return $RequestedStage
  }

  $queue = Read-JsonFile "TASK_QUEUE.json"
  $activeTaskId = Get-PropertyValue -Object $queue -Name "active_task_id"
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

foreach ($script in @(
  "modules/materials/import_manual_scout_pass.ps1",
  "packs/PHASE80_MANUAL_SCOUT_PASS_IMPORT_V1/APPLY.ps1",
  "packs/PHASE80_MANUAL_SCOUT_PASS_IMPORT_V1/VALIDATE.ps1"
)) {
  Assert-ParserPass -Path $script
}

Assert-Path -Path "packs/PHASE80_MANUAL_SCOUT_PASS_IMPORT_V1/PACK.json" -Kind "file"
Read-JsonFile "packs/PHASE80_MANUAL_SCOUT_PASS_IMPORT_V1/PACK.json" | Out-Null
Read-JsonFile "tasks/TASK_MANUAL_SCOUT_PASS_IMPORT_V1_001.json" | Out-Null

$scoutPass = Read-JsonFile $ScoutPassPath
if ($null -ne $scoutPass) {
  $candidates = As-Array (Get-PropertyValue -Object $scoutPass -Name "candidates")
  if (@($candidates).Count -ne 9) {
    Add-Failure "SCOUT_PASS_CANDIDATE_COUNT=$(@($candidates).Count)"
  }
}

$catalog = Read-JsonFile $CatalogPath
$catalogEntries = @()
if ($null -ne $catalog) {
  if ($null -eq (Get-PropertyInfo -Object $catalog -Name "entries")) {
    Add-Failure "CATALOG_ENTRIES_MISSING"
  } else {
    $catalogEntries = As-Array (Get-PropertyValue -Object $catalog -Name "entries")
  }
  $trustedCount = Get-TrustedCount -Entries $catalogEntries
  if ($trustedCount -ne 0) {
    Add-Failure "CATALOG_TRUSTED_COUNT=$trustedCount"
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
  $packId = Get-PropertyValue -Object $matchingPacks[0] -Name "pack_id"
  if ("$packId" -ne $PackId) {
    Add-Failure "REGISTRY_PACK_ID_MISMATCH=$packId"
  }
}

if ($Stage -eq "Seed") {
  $activeTaskId = Get-PropertyValue -Object $queue -Name "active_task_id"
  if ("$activeTaskId" -ne $TaskId) {
    Add-Failure "SEED_ACTIVE_TASK_MISMATCH=$activeTaskId"
  }
  if ($null -ne $taskEntry) {
    $status = Get-PropertyValue -Object $taskEntry -Name "status"
    if ("$status" -notin @("PENDING", "READY", "ACTIVE")) {
      Add-Failure "SEED_TASK_STATUS_INVALID=$status"
    }
  }
}

if ($Stage -eq "Completed") {
  $activeTaskId = Get-PropertyValue -Object $queue -Name "active_task_id"
  if ("$activeTaskId" -ne "NONE") {
    Add-Failure "ACTIVE_TASK_NOT_CLOSED=$activeTaskId"
  }
  if ($null -ne $taskEntry) {
    $status = Get-PropertyValue -Object $taskEntry -Name "status"
    if ("$status" -ne "COMPLETED") {
      Add-Failure "TASK_STATUS_NOT_COMPLETED=$status"
    }
  }

  $manualScoutEntries = @(
    $catalogEntries |
      Where-Object { "$(Get-PropertyValue -Object $_ -Name "imported_from_scout_pass")" -eq "MANUAL_SCOUT_PASS_001" }
  )
  if (@($manualScoutEntries).Count -ne 9) {
    Add-Failure "IMPORTED_MANUAL_SCOUT_ENTRY_COUNT=$(@($manualScoutEntries).Count)"
  }

  $report = Read-JsonFile $ReportPath
  if ($null -ne $report) {
    $reportStatus = Get-PropertyValue -Object $report -Name "status"
    if ("$reportStatus" -ne "PASS") {
      Add-Failure "REPORT_STATUS_NOT_PASS=$reportStatus"
    }
  }

  $proof = Read-JsonFile $ProofPath
  if ($null -ne $proof) {
    $proofStatus = Get-PropertyValue -Object $proof -Name "status"
    if ("$proofStatus" -ne "PASS") {
      Add-Failure "PROOF_STATUS_NOT_PASS=$proofStatus"
    }
    $nextAllowed = Get-PropertyValue -Object $proof -Name "next_allowed_step"
    if ("$nextAllowed" -ne $NextAllowedStep) {
      Add-Failure "PROOF_NEXT_ALLOWED_STEP_MISMATCH=$nextAllowed"
    }
    $forbidden = Get-PropertyValue -Object $proof -Name "forbidden_actions_confirmed"
    foreach ($field in @("no_external_tools_installed", "no_external_repos_fetched", "no_materials_marked_trusted", "no_external_agent_created", "no_scout_file_mutated", "no_phase78_files_modified", "no_phase79_runtime_files_modified")) {
      if (-not [bool](Get-PropertyValue -Object $forbidden -Name $field)) {
        Add-Failure "FORBIDDEN_ACTION_CONFIRMATION_FALSE=$field"
      }
    }
  }
}

if (@($script:Failures).Count -gt 0) {
  foreach ($failure in $script:Failures) {
    Write-Host "FAIL=$failure"
  }
  Write-Host "VALIDATION_RESULT=FAIL"
  throw "PHASE80_VALIDATION_FAILED"
}

if ($Stage -eq "Seed") {
  Write-Host "VALIDATION_RESULT=PASS_SEED"
} else {
  Write-Host "VALIDATION_RESULT=PASS"
}
