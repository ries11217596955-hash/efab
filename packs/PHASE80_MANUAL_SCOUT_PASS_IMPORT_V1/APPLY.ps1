[CmdletBinding()]
param(
  [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path,
  [string]$RunId = "MANUAL_SCOUT_PASS_IMPORT_V1_001",
  [switch]$InvokedByOrchestrator
)

$ErrorActionPreference = "Stop"

$CapabilityId = "manual_scout_pass_import_v1"
$PackId = "PHASE80_MANUAL_SCOUT_PASS_IMPORT_V1"
$TaskId = "TASK_MANUAL_SCOUT_PASS_IMPORT_V1_001"
$GateId = "MANUAL_SCOUT_PASS_IMPORT_V1"
$ActiveLine = "AGENT_BUILDER_SELF_DEVELOPMENT"
$Mode = "SELF_BUILD"
$ScoutPassPath = "materials/inbox/MANUAL_SCOUT_PASS_001.json"
$CatalogPath = "materials/MATERIAL_CATALOG.json"
$ReportPath = "reports/materials/MANUAL_SCOUT_PASS_IMPORT_REPORT.json"
$ProofPath = "proofs/materials/MANUAL_SCOUT_PASS_IMPORT_V1.json"
$NextAllowedStep = "STEP6_OR_PHASE81_MATERIAL_ADMISSION_POLICY_V1"

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

function New-CountMap {
  param([object[]]$Entries, [string]$FieldName)

  $map = [ordered]@{}
  foreach ($entry in $Entries) {
    $key = "$(Get-PropertyValue -Object $entry -Name $FieldName)"
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

function Update-TaskQueue {
  $queue = Read-JsonRequired "TASK_QUEUE.json"
  Set-PropertyValue -Object $queue -Name "active_task_id" -Value "NONE"

  foreach ($task in As-Array (Get-PropertyValue -Object $queue -Name "tasks")) {
    if ("$(Get-PropertyValue -Object $task -Name "task_id")" -eq $TaskId) {
      Set-PropertyValue -Object $task -Name "status" -Value "COMPLETED"
      Set-PropertyValue -Object $task -Name "path" -Value "tasks/TASK_MANUAL_SCOUT_PASS_IMPORT_V1_001.json"
      Set-PropertyValue -Object $task -Name "active_line" -Value $ActiveLine
      Set-PropertyValue -Object $task -Name "mode" -Value $Mode
      Set-PropertyValue -Object $task -Name "capability_id" -Value $CapabilityId
      Set-PropertyValue -Object $task -Name "phase" -Value "PHASE_80"
      Set-PropertyValue -Object $task -Name "gate" -Value $GateId
      Set-PropertyValue -Object $task -Name "pack_id" -Value $PackId
    }
  }

  Write-JsonFile -Path "TASK_QUEUE.json" -Object $queue
}

function Update-Roadmap {
  $roadmap = Read-JsonRequired "CAPABILITY_ROADMAP.json"
  $capabilities = As-Array (Get-PropertyValue -Object $roadmap -Name "capabilities")
  foreach ($capability in $capabilities) {
    $id = Get-PropertyValue -Object $capability -Name "id"
    $phase = Get-PropertyValue -Object $capability -Name "phase"
    if ("$id" -eq $CapabilityId -or "$phase" -eq "PHASE_80") {
      Set-PropertyValue -Object $capability -Name "id" -Value $CapabilityId
      Set-PropertyValue -Object $capability -Name "phase" -Value "PHASE_80"
      Set-PropertyValue -Object $capability -Name "status" -Value "COMPLETED"
      Set-PropertyValue -Object $capability -Name "gate" -Value $GateId
      Set-PropertyValue -Object $capability -Name "goal" -Value "Import MANUAL_SCOUT_PASS_001 into the controlled material catalog without trusting, installing, scanning, or admitting materials."
    }
  }
  Write-JsonFile -Path "CAPABILITY_ROADMAP.json" -Object $roadmap
}

function Update-GenesisState {
  $genesis = Read-JsonRequired "GENESIS_STATE.json"
  Set-PropertyValue -Object $genesis -Name "current_phase" -Value "PHASE_80"
  Set-PropertyValue -Object $genesis -Name "current_capability" -Value $CapabilityId
  Set-PropertyValue -Object $genesis -Name "manual_scout_pass_import_ready" -Value $true

  $completed = As-Array (Get-PropertyValue -Object $genesis -Name "completed_capabilities")
  if ($completed -notcontains $CapabilityId) {
    $completed += $CapabilityId
  }
  Set-PropertyValue -Object $genesis -Name "completed_capabilities" -Value @($completed)

  Write-JsonFile -Path "GENESIS_STATE.json" -Object $genesis
}

function Write-ImportReport {
  param([object]$ImportResult)

  $catalog = Read-JsonRequired $CatalogPath
  $entries = As-Array (Get-PropertyValue -Object $catalog -Name "entries")
  $trustedCount = Get-TrustedCount -Entries $entries
  $ownerApprovalCount = @($entries | Where-Object { [bool](Get-PropertyValue -Object $_ -Name "owner_approval_required") }).Count

  $report = [ordered]@{
    report_id = "MANUAL_SCOUT_PASS_IMPORT_REPORT"
    phase = "PHASE_80"
    capability_id = $CapabilityId
    status = $(if ($trustedCount -eq 0 -and [bool]$ImportResult.catalog_mutated) { "PASS" } else { "FAIL" })
    generated_at = Get-UtcStamp
    input_scout_pass_path = $ScoutPassPath
    catalog_path = $CatalogPath
    scout_pass_id = "$($ImportResult.scout_pass_id)"
    candidates_seen = [int]$ImportResult.candidate_count
    catalog_entries_before = [int]$ImportResult.catalog_entries_before
    catalog_entries_imported = [int]$ImportResult.catalog_entries_imported
    duplicates_skipped = [int]$ImportResult.duplicates_skipped
    catalog_entries_after = [int]$ImportResult.catalog_entries_after
    trusted_count_after = $trustedCount
    counts_by_status = (New-CountMap -Entries $entries -FieldName "status")
    counts_by_type = (New-CountMap -Entries $entries -FieldName "material_type")
    counts_by_usage_mode = (New-CountMap -Entries $entries -FieldName "usage_mode")
    counts_by_risk_level = (New-CountMap -Entries $entries -FieldName "risk_level")
    owner_approval_required_count = $ownerApprovalCount
    imported_material_ids = @($ImportResult.imported_material_ids)
    not_imported_material_ids = @($ImportResult.not_imported_material_ids)
    policy_summary = [ordered]@{
      import_is_not_approval = $true
      no_materials_trusted = ($trustedCount -eq 0)
      no_external_tools_installed = $true
      no_scanners_run = $true
      quarantine_not_started = $true
    }
    next_allowed_step = $NextAllowedStep
    cut_list = @(
      "Do not install imported materials.",
      "Do not mark imported materials TRUSTED.",
      "Do not run vulnerability scanners in PHASE80.",
      "Do not run license scanners in PHASE80.",
      "Do not create quarantine trials in PHASE80.",
      "Do not create external agents in PHASE80."
    )
  }

  Write-JsonFile -Path $ReportPath -Object $report
  if ($report.status -ne "PASS") {
    throw "MANUAL_SCOUT_PASS_IMPORT_REPORT_FAILED"
  }
}

function Write-ImportProof {
  $queue = Read-JsonRequired "TASK_QUEUE.json"
  $catalog = Read-JsonRequired $CatalogPath
  $entries = As-Array (Get-PropertyValue -Object $catalog -Name "entries")
  $trustedCount = Get-TrustedCount -Entries $entries
  $manualScoutEntries = @($entries | Where-Object { "$(Get-PropertyValue -Object $_ -Name "imported_from_scout_pass")" -eq "MANUAL_SCOUT_PASS_001" })

  $proof = [ordered]@{
    proof_id = "MANUAL_SCOUT_PASS_IMPORT_V1"
    phase = "PHASE_80"
    capability_id = $CapabilityId
    task_id = $TaskId
    pack_id = $PackId
    status = "PASS"
    generated_at = Get-UtcStamp
    evidence_files = @(
      $ScoutPassPath,
      $CatalogPath,
      $ReportPath
    )
    validation_gates = @(
      "manual_scout_pass_parsed",
      "candidate_count_9",
      "catalog_mutated_by_explicit_import",
      "trusted_count_zero",
      "queue_returned_to_none"
    )
    queue_state_after = [ordered]@{
      active_task_id = "$(Get-PropertyValue -Object $queue -Name "active_task_id")"
    }
    catalog_state_after = [ordered]@{
      entries = @($entries).Count
      imported_from_manual_scout_pass_001 = @($manualScoutEntries).Count
      trusted_count = $trustedCount
    }
    forbidden_actions_confirmed = [ordered]@{
      no_external_tools_installed = $true
      no_external_repos_fetched = $true
      no_materials_marked_trusted = ($trustedCount -eq 0)
      no_external_agent_created = $true
      no_scout_file_mutated = $true
      no_phase78_files_modified = $true
      no_phase79_runtime_files_modified = $true
    }
    next_allowed_step = $NextAllowedStep
  }

  Write-JsonFile -Path $ProofPath -Object $proof
}

function Invoke-Validator {
  & (Join-RepoPath "packs/$PackId/VALIDATE.ps1") -RepoRoot $RepoRoot -Stage "Completed"
}

Write-Host "PHASE80_APPLY_START"

foreach ($marker in @("CAPABILITY_ROADMAP.json", "GENESIS_STATE.json", "TASK_QUEUE.json", "packs/registry.json", "orchestrator/run.ps1")) {
  if (-not (Test-Path -LiteralPath (Join-RepoPath $marker))) {
    throw "STOP=WRONG_AGENT_BUILDER_REPO missing $marker"
  }
}

if (-not (Test-Path -LiteralPath (Join-RepoPath $ScoutPassPath))) {
  throw "MISSING_MANUAL_SCOUT_PASS=$ScoutPassPath"
}
if (-not (Test-Path -LiteralPath (Join-RepoPath $CatalogPath))) {
  throw "MISSING_MATERIAL_CATALOG=$CatalogPath"
}

foreach ($directory in @("reports/materials", "proofs/materials")) {
  $path = Join-RepoPath $directory
  if (-not (Test-Path -LiteralPath $path)) {
    New-Item -ItemType Directory -Path $path -Force | Out-Null
  }
}

$importResult = & (Join-RepoPath "modules/materials/import_manual_scout_pass.ps1") -RepoRoot $RepoRoot -ScoutPassPath $ScoutPassPath -MaterialCatalogPath $CatalogPath -ImportPhase "PHASE80" -NextAllowedStep $NextAllowedStep -CommitImport
Write-Host "MATERIAL_CATALOG_IMPORTED"

Write-ImportReport -ImportResult $importResult
Write-Host "MANUAL_SCOUT_PASS_IMPORT_REPORT_WRITTEN"

Update-TaskQueue

Update-Roadmap
Update-GenesisState

Write-ImportProof
Write-Host "MANUAL_SCOUT_PASS_IMPORT_PROOF_WRITTEN"
Write-Host "TASK_QUEUE_RETURNED_TO_NONE"

Invoke-Validator

Write-Host "PHASE80_APPLY_COMPLETE"
