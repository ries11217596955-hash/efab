[CmdletBinding()]
param(
  [string]$CatalogPath = "materials/MATERIAL_CATALOG.json",
  [string]$PolicyReportPath = "reports/materials/MATERIAL_POLICY_V1_REPORT.json",
  [string]$OutputRoot = "materials/quarantine",
  [string]$BatchId = "QUARANTINE_BATCH_001",
  [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path,
  [switch]$NoMutation
)

$ErrorActionPreference = "Stop"

$NextAllowedStep = "PHASE83_OPERATION_CONTRACT_SKELETON_V1"
$CapabilityId = "first_material_quarantine_trial_v1"

function Join-RepoPath {
  param([string]$Path)

  if ([System.IO.Path]::IsPathRooted($Path)) {
    return [System.IO.Path]::GetFullPath($Path)
  }

  return [System.IO.Path]::GetFullPath((Join-Path $RepoRoot $Path))
}

function Get-RelativePath {
  param([string]$Path)

  $fullPath = Join-RepoPath $Path
  $root = [System.IO.Path]::GetFullPath($RepoRoot).TrimEnd([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar)
  if ($fullPath.StartsWith($root, [System.StringComparison]::OrdinalIgnoreCase)) {
    return $fullPath.Substring($root.Length + 1).Replace("\", "/")
  }
  return $fullPath.Replace("\", "/")
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

function Write-TextFile {
  param(
    [string]$Path,
    [string]$Content
  )

  $fullPath = Join-RepoPath $Path
  $directory = Split-Path -Parent $fullPath
  if (-not (Test-Path -LiteralPath $directory)) {
    New-Item -ItemType Directory -Path $directory -Force | Out-Null
  }
  $text = $Content -replace "`r`n", "`n"
  if (-not $text.EndsWith("`n")) {
    $text += "`n"
  }
  [System.IO.File]::WriteAllText($fullPath, $text, [System.Text.UTF8Encoding]::new($false))
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

function Get-CatalogEntryById {
  param(
    [object[]]$Entries,
    [string]$MaterialId
  )

  return $Entries | Where-Object { "$(Get-PropertyValue -Object $_ -Name "material_id")" -eq $MaterialId } | Select-Object -First 1
}

function New-Checklist {
  param([object]$Entry)

  $sourceUrl = "$(Get-PropertyValue -Object $Entry -Name "source_url")"
  $sourceOrigin = "$(Get-PropertyValue -Object $Entry -Name "source_origin")"
  $licenseStatus = "$(Get-PropertyValue -Object $Entry -Name "license_status")"
  $securityStatus = "$(Get-PropertyValue -Object $Entry -Name "security_status")"
  $ownerApprovalRequired = [bool](Get-PropertyValue -Object $Entry -Name "owner_approval_required")
  $catalogStatus = "$(Get-PropertyValue -Object $Entry -Name "status")"
  $trustStatus = "$(Get-PropertyValue -Object $Entry -Name "trust_status")"

  return @(
    [ordered]@{
      item_id = "source_url_present"
      status = $(if ($sourceUrl -ne "") { "PASS" } else { "FAIL" })
      notes = "Source URL must be present before any later admission work."
    },
    [ordered]@{
      item_id = "official_or_registry_source"
      status = $(if ($sourceOrigin.IndexOf("official", [System.StringComparison]::OrdinalIgnoreCase) -ge 0 -or $sourceOrigin.IndexOf("registry", [System.StringComparison]::OrdinalIgnoreCase) -ge 0) { "PASS" } else { "NOT_DONE" })
      notes = "Source origin is recorded as data for later review."
    },
    [ordered]@{
      item_id = "license_status_present"
      status = $(if ($licenseStatus -ne "") { "PASS" } else { "FAIL" })
      notes = "License status is recorded but not independently verified in PHASE82."
    },
    [ordered]@{
      item_id = "security_status_present"
      status = $(if ($securityStatus -ne "") { "PASS" } else { "FAIL" })
      notes = "Security status is recorded; no scanner has been run in PHASE82."
    },
    [ordered]@{
      item_id = "owner_approval_not_required_or_recorded"
      status = $(if ($ownerApprovalRequired) { "NOT_DONE" } else { "PASS" })
      notes = "Owner approval is not required for this selected quarantine batch unless explicitly recorded later."
    },
    [ordered]@{
      item_id = "smoke_test_plan_defined"
      status = "NOT_DONE"
      notes = "PHASE82 prepares records only; smoke test planning belongs to a later phase."
    },
    [ordered]@{
      item_id = "wrapper_plan_defined"
      status = "NOT_DONE"
      notes = "PHASE82 does not create wrapper plans or contracts."
    },
    [ordered]@{
      item_id = "no_trusted_status"
      status = $(if ($catalogStatus -ne "TRUSTED" -and $trustStatus -ne "TRUSTED") { "PASS" } else { "FAIL" })
      notes = "No material may be trusted by this quarantine record."
    },
    [ordered]@{
      item_id = "no_install_performed"
      status = "PASS"
      notes = "No install was performed."
    },
    [ordered]@{
      item_id = "no_external_fetch_performed"
      status = "PASS"
      notes = "No external fetch was performed."
    }
  )
}

function New-DeferredRecord {
  param([object]$Decision)

  $decisionValue = "$(Get-PropertyValue -Object $Decision -Name "decision")"
  $reason = switch ($decisionValue) {
    "CANDIDATE_FOR_WRAPPER_CONTRACT" { "wrapper_contract_before_quarantine_or_later_phase" }
    "OWNER_APPROVAL_REQUIRED" { "owner_approval_required_before_quarantine" }
    "REFERENCE_ONLY" { "reference_only_not_quarantine_candidate" }
    "NEEDS_METADATA" { "metadata_required_before_quarantine" }
    "HOLD" { "held_by_policy_default" }
    default { "not_selected_for_phase82_quarantine" }
  }

  return [ordered]@{
    material_id = "$(Get-PropertyValue -Object $Decision -Name "material_id")"
    decision = $decisionValue
    reason = $reason
  }
}

function New-SourceNotes {
  param(
    [object]$Entry,
    [object]$Decision
  )

  $name = "$(Get-PropertyValue -Object $Entry -Name "name")"
  $sourceUrl = "$(Get-PropertyValue -Object $Entry -Name "source_url")"
  $sourceOrigin = "$(Get-PropertyValue -Object $Entry -Name "source_origin")"
  $licenseStatus = "$(Get-PropertyValue -Object $Entry -Name "license_status")"
  $decisionValue = "$(Get-PropertyValue -Object $Decision -Name "decision")"
  $rationale = "$(Get-PropertyValue -Object $Decision -Name "rationale")"

  return @"
# Source Notes: $name

Material: $name
Source URL: $sourceUrl
Source origin: $sourceOrigin
License status: $licenseStatus

Why selected for quarantine:
$decisionValue from PHASE81 policy. $rationale

What is not yet proven:
- License has not been independently verified.
- Security has not been reviewed.
- No smoke test has been defined or executed.
- No wrapper or operation contract exists.

No install performed: true
No trust granted: true
"@
}

Write-Host "QUARANTINE_TRIAL_START"
Write-Host "QUARANTINE_SOURCE_POLICY_REPORT=$PolicyReportPath"

$catalog = Read-JsonRequired $CatalogPath
$policyReport = Read-JsonRequired $PolicyReportPath
$entries = As-Array (Get-PropertyValue -Object $catalog -Name "entries")
$decisions = As-Array (Get-PropertyValue -Object $policyReport -Name "decisions")
$createdAt = Get-UtcStamp

$trustedCount = Get-TrustedCount -Entries $entries
if ($trustedCount -ne 0) {
  throw "QUARANTINE_TRUSTED_COUNT=$trustedCount"
}

$selectedDecisions = @($decisions | Where-Object { "$(Get-PropertyValue -Object $_ -Name "decision")" -eq "CANDIDATE_FOR_QUARANTINE" })
$deferredDecisions = @($decisions | Where-Object { "$(Get-PropertyValue -Object $_ -Name "decision")" -in @("OWNER_APPROVAL_REQUIRED", "REFERENCE_ONLY", "NEEDS_METADATA", "CANDIDATE_FOR_WRAPPER_CONTRACT", "HOLD") })
$rejectedDecisions = @($decisions | Where-Object { "$(Get-PropertyValue -Object $_ -Name "decision")" -eq "REJECT" })

$seenSelected = @{}
foreach ($decision in $selectedDecisions) {
  $materialId = "$(Get-PropertyValue -Object $decision -Name "material_id")"
  if ($materialId -eq "") {
    throw "QUARANTINE_SELECTED_MISSING_MATERIAL_ID"
  }
  if ($seenSelected.ContainsKey($materialId)) {
    throw "QUARANTINE_DUPLICATE_SELECTED_MATERIAL_ID=$materialId"
  }
  $seenSelected[$materialId] = $true
}

$selectedMaterialIds = @()
$cardPaths = @()
$sourceNotesPaths = @()
$checklistPaths = @()

foreach ($decision in $selectedDecisions) {
  $materialId = "$(Get-PropertyValue -Object $decision -Name "material_id")"
  $entry = Get-CatalogEntryById -Entries $entries -MaterialId $materialId
  if ($null -eq $entry) {
    throw "QUARANTINE_SELECTED_NOT_IN_CATALOG=$materialId"
  }

  $catalogStatus = "$(Get-PropertyValue -Object $entry -Name "status")"
  $trustStatus = "$(Get-PropertyValue -Object $entry -Name "trust_status")"
  if ($catalogStatus -eq "TRUSTED" -or $trustStatus -eq "TRUSTED") {
    throw "QUARANTINE_SELECTED_TRUSTED_FORBIDDEN=$materialId"
  }

  $materialFolder = (Join-Path $OutputRoot $materialId).Replace("\", "/")
  $cardPath = (Join-Path $materialFolder "MATERIAL_CARD.json").Replace("\", "/")
  $notesPath = (Join-Path $materialFolder "SOURCE_NOTES.md").Replace("\", "/")
  $checklistPath = (Join-Path $materialFolder "ADMISSION_CHECKLIST.json").Replace("\", "/")

  $allowedNextActions = @(
    "review_source",
    "verify_license",
    "define_smoke_test_plan",
    "define_wrapper_candidate",
    "owner_review_if_needed"
  )
  $forbiddenActions = @(
    "install_tool",
    "fetch_repo",
    "run_tool",
    "mark_trusted",
    "use_in_external_agent",
    "modify_global_environment"
  )
  $requiredBeforeTrust = @(
    "license_verified",
    "source_verified",
    "security_reviewed",
    "smoke_test_passed",
    "wrapper_or_operation_contract_exists",
    "proof_recorded",
    "owner_approval_if_required"
  )

  $card = [ordered]@{
    material_id = $materialId
    name = "$(Get-PropertyValue -Object $entry -Name "name")"
    material_type = "$(Get-PropertyValue -Object $entry -Name "material_type")"
    source_url = "$(Get-PropertyValue -Object $entry -Name "source_url")"
    source_origin = "$(Get-PropertyValue -Object $entry -Name "source_origin")"
    license_status = "$(Get-PropertyValue -Object $entry -Name "license_status")"
    security_status = "$(Get-PropertyValue -Object $entry -Name "security_status")"
    usage_mode = "$(Get-PropertyValue -Object $entry -Name "usage_mode")"
    catalog_status = $catalogStatus
    policy_decision = "$(Get-PropertyValue -Object $decision -Name "decision")"
    risk_level = "$(Get-PropertyValue -Object $entry -Name "risk_level")"
    owner_approval_required = [bool](Get-PropertyValue -Object $entry -Name "owner_approval_required")
    quarantine_status = "QUARANTINE_RECORD_CREATED"
    created_at = $createdAt
    source_notes_path = (Get-RelativePath -Path $notesPath)
    admission_checklist_path = (Get-RelativePath -Path $checklistPath)
    allowed_next_actions = $allowedNextActions
    forbidden_actions = $forbiddenActions
    required_before_trust = $requiredBeforeTrust
    rollback_notes = "Delete this quarantine material folder and batch entry if PHASE82 acceptance fails. No catalog or policy rollback is required because neither is mutated."
  }

  $checklist = [ordered]@{
    material_id = $materialId
    created_at = $createdAt
    items = (New-Checklist -Entry $entry)
  }

  Write-JsonFile -Path $cardPath -Object $card
  Write-TextFile -Path $notesPath -Content (New-SourceNotes -Entry $entry -Decision $decision)
  Write-JsonFile -Path $checklistPath -Object $checklist

  $selectedMaterialIds += $materialId
  $cardPaths += (Get-RelativePath -Path $cardPath)
  $sourceNotesPaths += (Get-RelativePath -Path $notesPath)
  $checklistPaths += (Get-RelativePath -Path $checklistPath)
  Write-Host "QUARANTINE_CARD_CREATED=$materialId"
}

$deferredRecords = @($deferredDecisions | ForEach-Object { [pscustomobject](New-DeferredRecord -Decision $_) })
$rejectedMaterialIds = @($rejectedDecisions | ForEach-Object { "$(Get-PropertyValue -Object $_ -Name "material_id")" })
$batchPath = (Join-Path $OutputRoot "$BatchId.json").Replace("\", "/")
$trustedCountAfter = Get-TrustedCount -Entries $entries

$batch = [ordered]@{
  batch_id = $BatchId
  phase = "PHASE_82"
  capability_id = $CapabilityId
  created_at = $createdAt
  source_policy_report = $PolicyReportPath
  source_catalog = $CatalogPath
  selected_material_ids = @($selectedMaterialIds)
  deferred_material_ids = @($deferredRecords)
  rejected_material_ids = @($rejectedMaterialIds)
  quarantine_card_count = @($selectedMaterialIds).Count
  trusted_count = $trustedCountAfter
  install_performed = $false
  external_fetch_performed = $false
  next_allowed_step = $NextAllowedStep
  cut_list = @(
    "Do not install tools.",
    "Do not fetch external repositories.",
    "Do not run scanners.",
    "Do not create wrappers.",
    "Do not mark materials TRUSTED.",
    "Do not create external agents."
  )
}

Write-JsonFile -Path $batchPath -Object $batch

Write-Host "QUARANTINE_SELECTED_COUNT=$(@($selectedMaterialIds).Count)"
Write-Host "QUARANTINE_BATCH_WRITTEN=$(Get-RelativePath -Path $batchPath)"
Write-Host "QUARANTINE_TRUSTED_COUNT=$trustedCountAfter"
Write-Host "QUARANTINE_INSTALL_PERFORMED=FALSE"
Write-Host "QUARANTINE_EXTERNAL_FETCH_PERFORMED=FALSE"
Write-Host "QUARANTINE_TRIAL_COMPLETE"

return [pscustomobject][ordered]@{
  status = "PASS"
  batch_id = $BatchId
  batch_path = (Get-RelativePath -Path $batchPath)
  source_catalog_path = $CatalogPath
  source_policy_report_path = $PolicyReportPath
  selected_material_ids = @($selectedMaterialIds)
  selected_count = @($selectedMaterialIds).Count
  deferred_material_ids = @($deferredRecords)
  rejected_material_ids = @($rejectedMaterialIds)
  quarantine_card_count = @($selectedMaterialIds).Count
  quarantine_card_paths = @($cardPaths)
  source_notes_paths = @($sourceNotesPaths)
  admission_checklist_paths = @($checklistPaths)
  trusted_count = $trustedCountAfter
  install_performed = $false
  external_fetch_performed = $false
  next_allowed_step = $NextAllowedStep
}
