[CmdletBinding()]
param(
  [ValidateSet("Auto", "Seed", "Completed")]
  [string]$Stage = "Auto",
  [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
)

$ErrorActionPreference = "Stop"

$PackId = "PHASE82_FIRST_MATERIAL_QUARANTINE_TRIAL_V1"
$TaskId = "TASK_FIRST_MATERIAL_QUARANTINE_TRIAL_V1_001"
$CatalogPath = "materials/MATERIAL_CATALOG.json"
$PolicyPath = "materials/MATERIAL_POLICY.json"
$PolicyReportPath = "reports/materials/MATERIAL_POLICY_V1_REPORT.json"
$PolicyProofPath = "proofs/materials/MATERIAL_POLICY_V1.json"
$QuarantineSchemaPath = "contracts/materials/material_quarantine_card.schema.json"
$BatchPath = "materials/quarantine/QUARANTINE_BATCH_001.json"
$ReportPath = "reports/materials/FIRST_QUARANTINE_TRIAL_REPORT.json"
$ProofPath = "proofs/materials/FIRST_QUARANTINE_TRIAL_V1.json"
$NextAllowedStep = "PHASE83_OPERATION_CONTRACT_SKELETON_V1"

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

function Assert-ProtectedClean {
  $protectedPaths = @(
    "orchestrator/run.ps1",
    "materials/MATERIAL_CATALOG.json",
    "materials/MATERIAL_POLICY.json",
    "packs/PHASE78_AGENT_BUILDER_SELF_KNOWLEDGE_SYSTEM_FULL_CONTRACT_V1",
    "packs/PHASE79_MATERIAL_ACQUISITION_BOOTSTRAP_V1",
    "packs/PHASE80_MANUAL_SCOUT_PASS_IMPORT_V1",
    "packs/PHASE81_MATERIAL_ADMISSION_POLICY_V1",
    "generated_agents",
    "applied_agents",
    ".github/workflows"
  )

  foreach ($path in $protectedPaths) {
    $status = @(git -C $RepoRoot status --short -- $path)
    if (@($status).Count -gt 0) {
      Add-Failure "PROTECTED_PATH_MODIFIED=$path :: $($status -join '; ')"
    }
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

function Get-CatalogEntry {
  param(
    [object[]]$Entries,
    [string]$MaterialId
  )

  return $Entries | Where-Object { "$(Get-PropertyValue -Object $_ -Name "material_id")" -eq $MaterialId } | Select-Object -First 1
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

foreach ($marker in @("CAPABILITY_ROADMAP.json", "GENESIS_STATE.json", "TASK_QUEUE.json", "packs/registry.json", "orchestrator/run.ps1")) {
  if (-not (Test-Path -LiteralPath (Join-RepoPath $marker))) {
    Add-Failure "STOP=WRONG_AGENT_BUILDER_REPO missing $marker"
  }
}

Assert-ProtectedClean

foreach ($script in @(
  "modules/materials/create_quarantine_trial.ps1",
  "packs/PHASE82_FIRST_MATERIAL_QUARANTINE_TRIAL_V1/APPLY.ps1",
  "packs/PHASE82_FIRST_MATERIAL_QUARANTINE_TRIAL_V1/VALIDATE.ps1"
)) {
  Assert-ParserPass -Path $script
}

Assert-Path -Path "packs/PHASE82_FIRST_MATERIAL_QUARANTINE_TRIAL_V1/PACK.json" -Kind "file"
Read-JsonFile "packs/PHASE82_FIRST_MATERIAL_QUARANTINE_TRIAL_V1/PACK.json" | Out-Null
Read-JsonFile "tasks/TASK_FIRST_MATERIAL_QUARANTINE_TRIAL_V1_001.json" | Out-Null
Read-JsonFile $QuarantineSchemaPath | Out-Null
Read-JsonFile $PolicyPath | Out-Null
Read-JsonFile $PolicyProofPath | Out-Null

$catalog = Read-JsonFile $CatalogPath
$catalogEntries = @()
if ($null -ne $catalog) {
  if ($null -eq (Get-PropertyInfo -Object $catalog -Name "entries")) {
    Add-Failure "CATALOG_ENTRIES_MISSING"
  } else {
    $catalogEntries = As-Array (Get-PropertyValue -Object $catalog -Name "entries")
  }
  if (@($catalogEntries).Count -ne 9) {
    Add-Failure "CATALOG_ENTRY_COUNT=$(@($catalogEntries).Count)"
  }
  $trustedCount = Get-TrustedCount -Entries $catalogEntries
  if ($trustedCount -ne 0) {
    Add-Failure "CATALOG_TRUSTED_COUNT=$trustedCount"
  }
}

$policyReport = Read-JsonFile $PolicyReportPath
$candidateDecisionCount = 0
if ($null -ne $policyReport) {
  $policyReportStatus = Get-PropertyValue -Object $policyReport -Name "status"
  if ("$policyReportStatus" -ne "PASS") {
    Add-Failure "POLICY_REPORT_STATUS_NOT_PASS=$policyReportStatus"
  }
  $policyDecisions = As-Array (Get-PropertyValue -Object $policyReport -Name "decisions")
  $candidateDecisionCount = @($policyDecisions | Where-Object { "$(Get-PropertyValue -Object $_ -Name "decision")" -eq "CANDIDATE_FOR_QUARANTINE" }).Count
  if ($candidateDecisionCount -ne 2) {
    Add-Failure "POLICY_CANDIDATE_FOR_QUARANTINE_COUNT=$candidateDecisionCount"
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
  $batch = Read-JsonFile $BatchPath
  $report = Read-JsonFile $ReportPath
  $proof = Read-JsonFile $ProofPath

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

  if ($null -ne $batch) {
    $selectedIds = As-Array (Get-PropertyValue -Object $batch -Name "selected_material_ids")
    if (@($selectedIds).Count -ne 2) {
      Add-Failure "BATCH_SELECTED_MATERIAL_COUNT=$(@($selectedIds).Count)"
    }

    $cardCount = 0
    $notesCount = 0
    $checklistCount = 0
    foreach ($selectedId in $selectedIds) {
      $entry = Get-CatalogEntry -Entries $catalogEntries -MaterialId "$selectedId"
      if ($null -eq $entry) {
        Add-Failure "SELECTED_ID_NOT_IN_CATALOG=$selectedId"
      } elseif ("$(Get-PropertyValue -Object $entry -Name "status")" -eq "TRUSTED" -or "$(Get-PropertyValue -Object $entry -Name "trust_status")" -eq "TRUSTED") {
        Add-Failure "SELECTED_ID_TRUSTED=$selectedId"
      }

      if (Test-Path -LiteralPath (Join-RepoPath "materials/quarantine/$selectedId/MATERIAL_CARD.json")) {
        $cardCount += 1
        Read-JsonFile "materials/quarantine/$selectedId/MATERIAL_CARD.json" | Out-Null
      }
      if (Test-Path -LiteralPath (Join-RepoPath "materials/quarantine/$selectedId/SOURCE_NOTES.md")) {
        $notesCount += 1
      }
      if (Test-Path -LiteralPath (Join-RepoPath "materials/quarantine/$selectedId/ADMISSION_CHECKLIST.json")) {
        $checklistCount += 1
        Read-JsonFile "materials/quarantine/$selectedId/ADMISSION_CHECKLIST.json" | Out-Null
      }
    }

    if ($cardCount -ne 2) {
      Add-Failure "MATERIAL_CARD_COUNT=$cardCount"
    }
    if ($notesCount -ne 2) {
      Add-Failure "SOURCE_NOTES_COUNT=$notesCount"
    }
    if ($checklistCount -ne 2) {
      Add-Failure "ADMISSION_CHECKLIST_COUNT=$checklistCount"
    }

    $allCards = @(Get-ChildItem -LiteralPath (Join-RepoPath "materials/quarantine") -Recurse -Filter "MATERIAL_CARD.json" -ErrorAction SilentlyContinue)
    $allNotes = @(Get-ChildItem -LiteralPath (Join-RepoPath "materials/quarantine") -Recurse -Filter "SOURCE_NOTES.md" -ErrorAction SilentlyContinue)
    $allChecklists = @(Get-ChildItem -LiteralPath (Join-RepoPath "materials/quarantine") -Recurse -Filter "ADMISSION_CHECKLIST.json" -ErrorAction SilentlyContinue)
    if (@($allCards).Count -ne 2) {
      Add-Failure "TOTAL_MATERIAL_CARD_COUNT=$(@($allCards).Count)"
    }
    if (@($allNotes).Count -ne 2) {
      Add-Failure "TOTAL_SOURCE_NOTES_COUNT=$(@($allNotes).Count)"
    }
    if (@($allChecklists).Count -ne 2) {
      Add-Failure "TOTAL_ADMISSION_CHECKLIST_COUNT=$(@($allChecklists).Count)"
    }
  }

  if ($null -ne $report) {
    $reportStatus = Get-PropertyValue -Object $report -Name "status"
    if ("$reportStatus" -ne "PASS") {
      Add-Failure "REPORT_STATUS_NOT_PASS=$reportStatus"
    }
    if (-not [bool](Get-PropertyValue -Object $report -Name "catalog_unchanged")) {
      Add-Failure "REPORT_CATALOG_UNCHANGED_FALSE"
    }
  }

  if ($null -ne $proof) {
    $proofStatus = Get-PropertyValue -Object $proof -Name "status"
    if ("$proofStatus" -ne "PASS") {
      Add-Failure "PROOF_STATUS_NOT_PASS=$proofStatus"
    }
    $nextAllowed = Get-PropertyValue -Object $proof -Name "next_allowed_step"
    if ("$nextAllowed" -ne $NextAllowedStep) {
      Add-Failure "PROOF_NEXT_ALLOWED_STEP_MISMATCH=$nextAllowed"
    }
    $catalogStateAfter = Get-PropertyValue -Object $proof -Name "catalog_state_after"
    if (-not [bool](Get-PropertyValue -Object $catalogStateAfter -Name "unchanged")) {
      Add-Failure "PROOF_CATALOG_UNCHANGED_FALSE"
    }
    $forbidden = Get-PropertyValue -Object $proof -Name "forbidden_actions_confirmed"
    foreach ($field in @("no_external_tools_installed", "no_external_repos_fetched", "no_materials_marked_trusted", "no_catalog_mutation", "no_policy_mutation", "no_tool_execution", "no_external_agent_created", "no_phase78_files_modified", "no_phase79_files_modified", "no_phase80_files_modified", "no_phase81_files_modified")) {
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
  throw "PHASE82_VALIDATION_FAILED"
}

if ($Stage -eq "Seed") {
  Write-Host "VALIDATION_RESULT=PASS_SEED"
} else {
  Write-Host "VALIDATION_RESULT=PASS"
}
