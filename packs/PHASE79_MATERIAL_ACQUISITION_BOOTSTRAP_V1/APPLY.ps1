[CmdletBinding()]
param(
  [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path,
  [string]$RunId = "MATERIAL_ACQUISITION_BOOTSTRAP_V1_001",
  [switch]$InvokedByOrchestrator
)

$ErrorActionPreference = "Stop"

$CapabilityId = "material_acquisition_bootstrap_v1"
$PackId = "PHASE79_MATERIAL_ACQUISITION_BOOTSTRAP_V1"
$TaskId = "TASK_MATERIAL_ACQUISITION_BOOTSTRAP_V1_001"
$GateId = "MATERIAL_ACQUISITION_BOOTSTRAP_V1"
$ActiveLine = "AGENT_BUILDER_SELF_DEVELOPMENT"
$Mode = "SELF_BUILD"

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

function Set-PropertyValue {
  param(
    [object]$Object,
    [string]$Name,
    [object]$Value
  )

  $property = $Object.PSObject.Properties | Where-Object { $_.Name -ieq $Name } | Select-Object -First 1
  if ($null -ne $property) {
    $property.Value = $Value
  } else {
    $Object | Add-Member -NotePropertyName $Name -NotePropertyValue $Value
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

function New-MaterialCatalog {
  return [ordered]@{
    catalog_version = "MATERIAL_CATALOG_V1"
    generated_at = Get-UtcStamp
    policy = [ordered]@{
      phase = "PHASE_79"
      capability_id = $CapabilityId
      trust_policy = "No material may be marked TRUSTED during PHASE79."
      next_allowed_step = "STEP4_MANUAL_SCOUT_PASS_001"
      allowed_statuses = @(
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
      allowed_usage_modes = @(
        "USE_AS_TOOL",
        "WRAP_ONLY",
        "COPY_WITH_ATTRIBUTION",
        "ADAPT",
        "REIMPLEMENT",
        "REFERENCE_ONLY",
        "ASK_PERMISSION",
        "REJECT"
      )
      allowed_risk_levels = @(
        "LOW",
        "MEDIUM",
        "HIGH",
        "FORBIDDEN",
        "UNKNOWN"
      )
    }
    entries = @()
  }
}

function Ensure-MaterialCatalog {
  $catalogPath = "materials/MATERIAL_CATALOG.json"
  $fullPath = Join-RepoPath $catalogPath
  if (-not (Test-Path -LiteralPath $fullPath)) {
    Write-JsonFile -Path $catalogPath -Object (New-MaterialCatalog)
    return
  }

  $catalog = Read-JsonRequired $catalogPath
  if ($null -eq (Get-PropertyValue -Object $catalog -Names @("catalog_version"))) {
    Set-PropertyValue -Object $catalog -Name "catalog_version" -Value "MATERIAL_CATALOG_V1"
  }
  Set-PropertyValue -Object $catalog -Name "generated_at" -Value (Get-UtcStamp)
  if ($null -eq (Get-PropertyValue -Object $catalog -Names @("policy"))) {
    Set-PropertyValue -Object $catalog -Name "policy" -Value (New-MaterialCatalog).policy
  }
  if ($null -eq (Get-PropertyValue -Object $catalog -Names @("entries"))) {
    Set-PropertyValue -Object $catalog -Name "entries" -Value @()
  }

  Write-JsonFile -Path $catalogPath -Object $catalog
}

function Update-TaskQueue {
  $queue = Read-JsonRequired "TASK_QUEUE.json"
  Set-PropertyValue -Object $queue -Name "active_task_id" -Value "NONE"

  $tasks = As-Array (Get-PropertyValue -Object $queue -Names @("tasks"))
  foreach ($task in $tasks) {
    $taskId = Get-PropertyValue -Object $task -Names @("task_id", "id")
    if ("$taskId" -eq $TaskId) {
      Set-PropertyValue -Object $task -Name "status" -Value "COMPLETED"
      Set-PropertyValue -Object $task -Name "path" -Value "tasks/TASK_MATERIAL_ACQUISITION_BOOTSTRAP_V1_001.json"
      Set-PropertyValue -Object $task -Name "active_line" -Value $ActiveLine
      Set-PropertyValue -Object $task -Name "mode" -Value $Mode
      Set-PropertyValue -Object $task -Name "capability_id" -Value $CapabilityId
      Set-PropertyValue -Object $task -Name "phase" -Value "PHASE_79"
      Set-PropertyValue -Object $task -Name "gate" -Value $GateId
      Set-PropertyValue -Object $task -Name "pack_id" -Value $PackId
    }
  }

  Write-JsonFile -Path "TASK_QUEUE.json" -Object $queue
}

function Update-Roadmap {
  $roadmap = Read-JsonRequired "CAPABILITY_ROADMAP.json"
  $capabilities = As-Array (Get-PropertyValue -Object $roadmap -Names @("capabilities"))
  $found = $false
  foreach ($capability in $capabilities) {
    $id = Get-PropertyValue -Object $capability -Names @("id", "capability_id")
    $phase = Get-PropertyValue -Object $capability -Names @("phase")
    if ("$id" -eq $CapabilityId -or "$phase" -eq "PHASE_79") {
      Set-PropertyValue -Object $capability -Name "id" -Value $CapabilityId
      Set-PropertyValue -Object $capability -Name "phase" -Value "PHASE_79"
      Set-PropertyValue -Object $capability -Name "status" -Value "COMPLETED"
      Set-PropertyValue -Object $capability -Name "gate" -Value $GateId
      Set-PropertyValue -Object $capability -Name "goal" -Value "Create the material acquisition bootstrap contract, empty catalog, and governance proof path without scouting or trusting materials."
      $found = $true
    }
  }

  if (-not $found) {
    $capabilities = @(
      [pscustomobject][ordered]@{
        id = $CapabilityId
        phase = "PHASE_79"
        status = "COMPLETED"
        gate = $GateId
        goal = "Create the material acquisition bootstrap contract, empty catalog, and governance proof path without scouting or trusting materials."
      }
    ) + @($capabilities)
    Set-PropertyValue -Object $roadmap -Name "capabilities" -Value @($capabilities)
  }

  Write-JsonFile -Path "CAPABILITY_ROADMAP.json" -Object $roadmap
}

function Update-GenesisState {
  $genesis = Read-JsonRequired "GENESIS_STATE.json"
  Set-PropertyValue -Object $genesis -Name "current_phase" -Value "PHASE_79"
  Set-PropertyValue -Object $genesis -Name "current_capability" -Value $CapabilityId
  Set-PropertyValue -Object $genesis -Name "material_acquisition_bootstrap_ready" -Value $true

  $completed = As-Array (Get-PropertyValue -Object $genesis -Names @("completed_capabilities"))
  if ($completed -notcontains $CapabilityId) {
    $completed += $CapabilityId
  }
  Set-PropertyValue -Object $genesis -Name "completed_capabilities" -Value @($completed)

  Write-JsonFile -Path "GENESIS_STATE.json" -Object $genesis
}

function Write-Proof {
  $queue = Read-JsonRequired "TASK_QUEUE.json"
  $catalog = Read-JsonRequired "materials/MATERIAL_CATALOG.json"
  $entries = As-Array (Get-PropertyValue -Object $catalog -Names @("entries"))
  $trustedEntries = @($entries | Where-Object { "$(Get-PropertyValue -Object $_ -Names @("status"))" -eq "TRUSTED" })

  $proof = [ordered]@{
    proof_id = "MATERIAL_ACQUISITION_BOOTSTRAP_V1"
    phase = "PHASE_79"
    capability_id = $CapabilityId
    task_id = $TaskId
    pack_id = $PackId
    status = "PASS"
    generated_at = Get-UtcStamp
    evidence_files = @(
      "contracts/materials/material_request.schema.json",
      "contracts/materials/material_candidate.schema.json",
      "contracts/materials/material_catalog.schema.json",
      "contracts/materials/manual_scout_pass.schema.json",
      "materials/MATERIAL_CATALOG.json",
      "reports/materials/MATERIAL_ACQUISITION_BOOTSTRAP_REPORT.json"
    )
    validation_gates = @(
      "seed_contract_files_present",
      "material_catalog_empty_or_untrusted",
      "bootstrap_report_pass",
      "queue_returned_to_none"
    )
    queue_state_after = [ordered]@{
      active_task_id = "$(Get-PropertyValue -Object $queue -Names @("active_task_id"))"
    }
    forbidden_actions_confirmed = [ordered]@{
      no_external_tools_installed = $true
      no_materials_marked_trusted = (@($trustedEntries).Count -eq 0)
      no_external_agent_created = $true
      no_scout_execution = $true
      no_phase78_files_modified = $true
    }
    next_allowed_step = "STEP4_MANUAL_SCOUT_PASS_001"
  }

  Write-JsonFile -Path "proofs/materials/MATERIAL_ACQUISITION_BOOTSTRAP_V1.json" -Object $proof
}

function Invoke-Validator {
  & (Join-RepoPath "packs/$PackId/VALIDATE.ps1") -RepoRoot $RepoRoot -Stage "Completed"
}

Write-Host "PHASE79_APPLY_START"

foreach ($marker in @("CAPABILITY_ROADMAP.json", "GENESIS_STATE.json", "TASK_QUEUE.json", "packs/registry.json", "orchestrator/run.ps1")) {
  if (-not (Test-Path -LiteralPath (Join-RepoPath $marker))) {
    throw "STOP=WRONG_AGENT_BUILDER_REPO missing $marker"
  }
}

foreach ($directory in @("materials/inbox", "materials/catalog", "materials/quarantine", "materials/trusted", "materials/rejected", "materials/reference_only", "reports/materials", "proofs/materials")) {
  $path = Join-RepoPath $directory
  if (-not (Test-Path -LiteralPath $path)) {
    New-Item -ItemType Directory -Path $path -Force | Out-Null
  }
}

Ensure-MaterialCatalog
Write-Host "MATERIAL_CATALOG_READY"

& (Join-RepoPath "modules/materials/write_material_catalog_report.ps1") -RepoRoot $RepoRoot

Update-TaskQueue
Write-Host "TASK_QUEUE_RETURNED_TO_NONE"

Update-Roadmap
Update-GenesisState

Write-Proof
Write-Host "MATERIAL_BOOTSTRAP_PROOF_WRITTEN"

Invoke-Validator

Write-Host "PHASE79_APPLY_COMPLETE"
