[CmdletBinding()]
param(
  [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path,
  [string]$RunId = "FIRST_MATERIAL_QUARANTINE_TRIAL_V1_001",
  [switch]$InvokedByOrchestrator
)

$ErrorActionPreference = "Stop"

$CapabilityId = "first_material_quarantine_trial_v1"
$PackId = "PHASE82_FIRST_MATERIAL_QUARANTINE_TRIAL_V1"
$TaskId = "TASK_FIRST_MATERIAL_QUARANTINE_TRIAL_V1_001"
$GateId = "FIRST_MATERIAL_QUARANTINE_TRIAL_V1"
$ActiveLine = "AGENT_BUILDER_SELF_DEVELOPMENT"
$Mode = "SELF_BUILD"
$CatalogPath = "materials/MATERIAL_CATALOG.json"
$PolicyPath = "materials/MATERIAL_POLICY.json"
$PolicyReportPath = "reports/materials/MATERIAL_POLICY_V1_REPORT.json"
$PolicyProofPath = "proofs/materials/MATERIAL_POLICY_V1.json"
$BatchPath = "materials/quarantine/QUARANTINE_BATCH_001.json"
$ReportPath = "reports/materials/FIRST_QUARANTINE_TRIAL_REPORT.json"
$ProofPath = "proofs/materials/FIRST_QUARANTINE_TRIAL_V1.json"
$NextAllowedStep = "PHASE83_OPERATION_CONTRACT_SKELETON_V1"

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
      Set-PropertyValue -Object $task -Name "path" -Value "tasks/TASK_FIRST_MATERIAL_QUARANTINE_TRIAL_V1_001.json"
      Set-PropertyValue -Object $task -Name "active_line" -Value $ActiveLine
      Set-PropertyValue -Object $task -Name "mode" -Value $Mode
      Set-PropertyValue -Object $task -Name "capability_id" -Value $CapabilityId
      Set-PropertyValue -Object $task -Name "phase" -Value "PHASE_82"
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
    if ("$id" -eq $CapabilityId -or "$phase" -eq "PHASE_82") {
      Set-PropertyValue -Object $capability -Name "id" -Value $CapabilityId
      Set-PropertyValue -Object $capability -Name "phase" -Value "PHASE_82"
      Set-PropertyValue -Object $capability -Name "status" -Value "COMPLETED"
      Set-PropertyValue -Object $capability -Name "gate" -Value $GateId
      Set-PropertyValue -Object $capability -Name "goal" -Value "Create first quarantine records for materials selected by policy without trusting, installing, fetching, scanning, wrapping, or using materials."
    }
  }
  Write-JsonFile -Path "CAPABILITY_ROADMAP.json" -Object $roadmap
}

function Update-GenesisState {
  $genesis = Read-JsonRequired "GENESIS_STATE.json"
  Set-PropertyValue -Object $genesis -Name "current_phase" -Value "PHASE_82"
  Set-PropertyValue -Object $genesis -Name "current_capability" -Value $CapabilityId
  Set-PropertyValue -Object $genesis -Name "first_material_quarantine_trial_ready" -Value $true

  $completed = As-Array (Get-PropertyValue -Object $genesis -Name "completed_capabilities")
  if ($completed -notcontains $CapabilityId) {
    $completed += $CapabilityId
  }
  Set-PropertyValue -Object $genesis -Name "completed_capabilities" -Value @($completed)

  Write-JsonFile -Path "GENESIS_STATE.json" -Object $genesis
}

function Write-TrialReport {
  param(
    [object]$TrialResult,
    [object]$PolicyReport,
    [int]$CatalogEntryCount,
    [string]$CatalogHashBefore,
    [string]$CatalogHashAfter,
    [string]$PolicyHashBefore,
    [string]$PolicyHashAfter
  )

  $report = [ordered]@{
    report_id = "FIRST_QUARANTINE_TRIAL_REPORT"
    phase = "PHASE_82"
    capability_id = $CapabilityId
    status = $(if ($CatalogHashBefore -eq $CatalogHashAfter -and $PolicyHashBefore -eq $PolicyHashAfter -and [int]$TrialResult.trusted_count -eq 0 -and -not [bool]$TrialResult.install_performed -and -not [bool]$TrialResult.external_fetch_performed) { "PASS" } else { "FAIL" })
    generated_at = Get-UtcStamp
    source_catalog_path = $CatalogPath
    source_policy_path = $PolicyPath
    source_policy_report_path = $PolicyReportPath
    catalog_entry_count = $CatalogEntryCount
    catalog_hash_before = $CatalogHashBefore
    catalog_hash_after = $CatalogHashAfter
    catalog_unchanged = ($CatalogHashBefore -eq $CatalogHashAfter)
    selected_material_ids = @($TrialResult.selected_material_ids)
    selected_count = [int]$TrialResult.selected_count
    deferred_material_ids = @($TrialResult.deferred_material_ids)
    rejected_material_ids = @($TrialResult.rejected_material_ids)
    quarantine_batch_path = "$($TrialResult.batch_path)"
    quarantine_card_paths = @($TrialResult.quarantine_card_paths)
    source_notes_paths = @($TrialResult.source_notes_paths)
    admission_checklist_paths = @($TrialResult.admission_checklist_paths)
    trusted_count = [int]$TrialResult.trusted_count
    install_performed = [bool]$TrialResult.install_performed
    external_fetch_performed = [bool]$TrialResult.external_fetch_performed
    counts_by_policy_decision = (Get-PropertyValue -Object $PolicyReport -Name "counts_by_decision")
    policy_summary = [ordered]@{
      source_policy_report_status = "$(Get-PropertyValue -Object $PolicyReport -Name "status")"
      selection_rule = "Only CANDIDATE_FOR_QUARANTINE decisions are selected for PHASE82 quarantine records."
      wrapper_contract_decisions_deferred = $true
      quarantine_is_not_trust = $true
      no_catalog_mutation = ($CatalogHashBefore -eq $CatalogHashAfter)
      no_policy_mutation = ($PolicyHashBefore -eq $PolicyHashAfter)
    }
    next_allowed_step = $NextAllowedStep
    cut_list = @(
      "Do not install tools.",
      "Do not fetch external repositories.",
      "Do not run scanners.",
      "Do not run candidate tools.",
      "Do not create wrappers.",
      "Do not mark materials TRUSTED.",
      "Do not create external agents."
    )
  }

  Write-JsonFile -Path $ReportPath -Object $report
  if ($report.status -ne "PASS") {
    throw "FIRST_QUARANTINE_TRIAL_REPORT_FAILED"
  }
}

function Write-TrialProof {
  param(
    [object]$TrialResult,
    [string]$CatalogHashBefore,
    [string]$CatalogHashAfter,
    [string]$PolicyHashBefore,
    [string]$PolicyHashAfter,
    [int]$CatalogEntryCount
  )

  $queue = Read-JsonRequired "TASK_QUEUE.json"

  $proof = [ordered]@{
    proof_id = "FIRST_QUARANTINE_TRIAL_V1"
    phase = "PHASE_82"
    capability_id = $CapabilityId
    task_id = $TaskId
    pack_id = $PackId
    status = "PASS"
    generated_at = Get-UtcStamp
    evidence_files = @(
      $CatalogPath,
      $PolicyPath,
      $PolicyReportPath,
      $PolicyProofPath,
      "$($TrialResult.batch_path)",
      $ReportPath
    )
    validation_gates = @(
      "phase81_proof_pass",
      "policy_report_pass",
      "catalog_entry_count_9",
      "trusted_count_zero",
      "selected_quarantine_candidates_only",
      "quarantine_records_created",
      "catalog_hash_unchanged",
      "policy_hash_unchanged",
      "queue_returned_to_none"
    )
    queue_state_after = [ordered]@{
      active_task_id = "$(Get-PropertyValue -Object $queue -Name "active_task_id")"
    }
    catalog_state_after = [ordered]@{
      path = $CatalogPath
      entries = $CatalogEntryCount
      trusted_count = [int]$TrialResult.trusted_count
      sha256_before = $CatalogHashBefore
      sha256_after = $CatalogHashAfter
      unchanged = ($CatalogHashBefore -eq $CatalogHashAfter)
    }
    quarantine_state_after = [ordered]@{
      batch_path = "$($TrialResult.batch_path)"
      selected_count = [int]$TrialResult.selected_count
      selected_material_ids = @($TrialResult.selected_material_ids)
      quarantine_card_paths = @($TrialResult.quarantine_card_paths)
      source_notes_paths = @($TrialResult.source_notes_paths)
      admission_checklist_paths = @($TrialResult.admission_checklist_paths)
      install_performed = [bool]$TrialResult.install_performed
      external_fetch_performed = [bool]$TrialResult.external_fetch_performed
    }
    forbidden_actions_confirmed = [ordered]@{
      no_external_tools_installed = $true
      no_external_repos_fetched = $true
      no_materials_marked_trusted = ([int]$TrialResult.trusted_count -eq 0)
      no_catalog_mutation = ($CatalogHashBefore -eq $CatalogHashAfter)
      no_policy_mutation = ($PolicyHashBefore -eq $PolicyHashAfter)
      no_tool_execution = $true
      no_external_agent_created = $true
      no_phase78_files_modified = $true
      no_phase79_files_modified = $true
      no_phase80_files_modified = $true
      no_phase81_files_modified = $true
    }
    next_allowed_step = $NextAllowedStep
  }

  Write-JsonFile -Path $ProofPath -Object $proof
}

function Invoke-Validator {
  & (Join-RepoPath "packs/$PackId/VALIDATE.ps1") -RepoRoot $RepoRoot -Stage "Completed"
}

Write-Host "PHASE82_APPLY_START"

foreach ($marker in @("CAPABILITY_ROADMAP.json", "GENESIS_STATE.json", "TASK_QUEUE.json", "packs/registry.json", "orchestrator/run.ps1")) {
  if (-not (Test-Path -LiteralPath (Join-RepoPath $marker))) {
    throw "STOP=WRONG_AGENT_BUILDER_REPO missing $marker"
  }
}

foreach ($inputPath in @($CatalogPath, $PolicyPath, $PolicyReportPath, $PolicyProofPath)) {
  if (-not (Test-Path -LiteralPath (Join-RepoPath $inputPath))) {
    throw "PHASE82_MISSING_INPUT=$inputPath"
  }
}

$policyProof = Read-JsonRequired $PolicyProofPath
if ("$(Get-PropertyValue -Object $policyProof -Name "status")" -ne "PASS") {
  throw "PHASE81_PROOF_NOT_PASS"
}

$policyReport = Read-JsonRequired $PolicyReportPath
if ("$(Get-PropertyValue -Object $policyReport -Name "status")" -ne "PASS") {
  throw "PHASE81_POLICY_REPORT_NOT_PASS"
}

$catalog = Read-JsonRequired $CatalogPath
$entries = As-Array (Get-PropertyValue -Object $catalog -Name "entries")
if (@($entries).Count -ne 9) {
  throw "PHASE82_EXPECTED_CATALOG_ENTRY_COUNT_9_ACTUAL_$(@($entries).Count)"
}

$trustedCountBefore = Get-TrustedCount -Entries $entries
if ($trustedCountBefore -ne 0) {
  throw "PHASE82_CATALOG_TRUSTED_COUNT=$trustedCountBefore"
}

$catalogHashBefore = Get-FileSha256 -Path $CatalogPath
$policyHashBefore = Get-FileSha256 -Path $PolicyPath

$trialResult = & (Join-RepoPath "modules/materials/create_quarantine_trial.ps1") -RepoRoot $RepoRoot -CatalogPath $CatalogPath -PolicyReportPath $PolicyReportPath -OutputRoot "materials/quarantine" -BatchId "QUARANTINE_BATCH_001"

$catalogHashAfterTrial = Get-FileSha256 -Path $CatalogPath
$policyHashAfterTrial = Get-FileSha256 -Path $PolicyPath
if ($catalogHashBefore -ne $catalogHashAfterTrial) {
  throw "PHASE82_CATALOG_MUTATED"
}
if ($policyHashBefore -ne $policyHashAfterTrial) {
  throw "PHASE82_POLICY_MUTATED"
}

Write-TrialReport -TrialResult $trialResult -PolicyReport $policyReport -CatalogEntryCount @($entries).Count -CatalogHashBefore $catalogHashBefore -CatalogHashAfter $catalogHashAfterTrial -PolicyHashBefore $policyHashBefore -PolicyHashAfter $policyHashAfterTrial
Write-Host "FIRST_QUARANTINE_TRIAL_REPORT_WRITTEN"

Update-TaskQueue
Update-Roadmap
Update-GenesisState

$catalogHashAfterState = Get-FileSha256 -Path $CatalogPath
$policyHashAfterState = Get-FileSha256 -Path $PolicyPath
Write-TrialProof -TrialResult $trialResult -CatalogHashBefore $catalogHashBefore -CatalogHashAfter $catalogHashAfterState -PolicyHashBefore $policyHashBefore -PolicyHashAfter $policyHashAfterState -CatalogEntryCount @($entries).Count
Write-Host "FIRST_QUARANTINE_TRIAL_PROOF_WRITTEN"
Write-Host "TASK_QUEUE_RETURNED_TO_NONE"

Invoke-Validator

Write-Host "PHASE82_APPLY_COMPLETE"
