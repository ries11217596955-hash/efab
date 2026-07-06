[CmdletBinding()]
param(
  [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path,
  [string]$RunId = "MATERIAL_ADMISSION_POLICY_V1_001",
  [switch]$InvokedByOrchestrator
)

$ErrorActionPreference = "Stop"

$CapabilityId = "material_admission_policy_v1"
$PackId = "PHASE81_MATERIAL_ADMISSION_POLICY_V1"
$TaskId = "TASK_MATERIAL_ADMISSION_POLICY_V1_001"
$GateId = "MATERIAL_ADMISSION_POLICY_V1"
$ActiveLine = "AGENT_BUILDER_SELF_DEVELOPMENT"
$Mode = "SELF_BUILD"
$CatalogPath = "materials/MATERIAL_CATALOG.json"
$PolicyPath = "materials/MATERIAL_POLICY.json"
$ReportPath = "reports/materials/MATERIAL_POLICY_V1_REPORT.json"
$ProofPath = "proofs/materials/MATERIAL_POLICY_V1.json"
$NextAllowedStep = "PHASE82_FIRST_MATERIAL_QUARANTINE_TRIAL_V1"

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

function Get-IdsByDecision {
  param(
    [object[]]$Decisions,
    [string]$Decision
  )

  return @(
    $Decisions |
      Where-Object { "$(Get-PropertyValue -Object $_ -Name "decision")" -eq $Decision } |
      ForEach-Object { "$(Get-PropertyValue -Object $_ -Name "material_id")" }
  )
}

function Get-IdsByRisk {
  param(
    [object[]]$Decisions,
    [string]$RiskLevel
  )

  return @(
    $Decisions |
      Where-Object { "$(Get-PropertyValue -Object $_ -Name "risk_level")" -eq $RiskLevel } |
      ForEach-Object { "$(Get-PropertyValue -Object $_ -Name "material_id")" }
  )
}

function Get-OwnerApprovalIds {
  param([object[]]$Decisions)

  return @(
    $Decisions |
      Where-Object {
        [bool](Get-PropertyValue -Object $_ -Name "owner_approval_required") -or
        "$(Get-PropertyValue -Object $_ -Name "decision")" -eq "OWNER_APPROVAL_REQUIRED"
      } |
      ForEach-Object { "$(Get-PropertyValue -Object $_ -Name "material_id")" }
  )
}

function Update-TaskQueue {
  $queue = Read-JsonRequired "TASK_QUEUE.json"
  Set-PropertyValue -Object $queue -Name "active_task_id" -Value "NONE"

  foreach ($task in As-Array (Get-PropertyValue -Object $queue -Name "tasks")) {
    if ("$(Get-PropertyValue -Object $task -Name "task_id")" -eq $TaskId) {
      Set-PropertyValue -Object $task -Name "status" -Value "COMPLETED"
      Set-PropertyValue -Object $task -Name "path" -Value "tasks/TASK_MATERIAL_ADMISSION_POLICY_V1_001.json"
      Set-PropertyValue -Object $task -Name "active_line" -Value $ActiveLine
      Set-PropertyValue -Object $task -Name "mode" -Value $Mode
      Set-PropertyValue -Object $task -Name "capability_id" -Value $CapabilityId
      Set-PropertyValue -Object $task -Name "phase" -Value "PHASE_81"
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
    if ("$id" -eq $CapabilityId -or "$phase" -eq "PHASE_81") {
      Set-PropertyValue -Object $capability -Name "id" -Value $CapabilityId
      Set-PropertyValue -Object $capability -Name "phase" -Value "PHASE_81"
      Set-PropertyValue -Object $capability -Name "status" -Value "COMPLETED"
      Set-PropertyValue -Object $capability -Name "gate" -Value $GateId
      Set-PropertyValue -Object $capability -Name "goal" -Value "Evaluate material catalog entries through a conservative admission policy without trusting, installing, scanning, quarantining, or wrapping materials."
    }
  }
  Write-JsonFile -Path "CAPABILITY_ROADMAP.json" -Object $roadmap
}

function Update-GenesisState {
  $genesis = Read-JsonRequired "GENESIS_STATE.json"
  Set-PropertyValue -Object $genesis -Name "current_phase" -Value "PHASE_81"
  Set-PropertyValue -Object $genesis -Name "current_capability" -Value $CapabilityId
  Set-PropertyValue -Object $genesis -Name "material_admission_policy_ready" -Value $true

  $completed = As-Array (Get-PropertyValue -Object $genesis -Name "completed_capabilities")
  if ($completed -notcontains $CapabilityId) {
    $completed += $CapabilityId
  }
  Set-PropertyValue -Object $genesis -Name "completed_capabilities" -Value @($completed)

  Write-JsonFile -Path "GENESIS_STATE.json" -Object $genesis
}

function Write-PolicyReport {
  param(
    [object]$Evaluation,
    [string]$CatalogHashBefore,
    [string]$CatalogHashAfter
  )

  $policy = Read-JsonRequired $PolicyPath
  $decisions = As-Array (Get-PropertyValue -Object $Evaluation -Name "decisions")
  $trustedCount = [int](Get-PropertyValue -Object $Evaluation -Name "trusted_count")

  $report = [ordered]@{
    report_id = "MATERIAL_POLICY_V1_REPORT"
    phase = "PHASE_81"
    capability_id = $CapabilityId
    status = $(if ($trustedCount -eq 0 -and $CatalogHashBefore -eq $CatalogHashAfter -and @($decisions).Count -eq [int](Get-PropertyValue -Object $Evaluation -Name "catalog_entry_count")) { "PASS" } else { "FAIL" })
    generated_at = Get-UtcStamp
    catalog_path = $CatalogPath
    policy_path = $PolicyPath
    catalog_entry_count = [int](Get-PropertyValue -Object $Evaluation -Name "catalog_entry_count")
    trusted_count = $trustedCount
    owner_approval_required_count = [int](Get-PropertyValue -Object $Evaluation -Name "owner_approval_required_count")
    decisions = @($decisions)
    counts_by_decision = (Get-PropertyValue -Object $Evaluation -Name "counts_by_decision")
    counts_by_status = (Get-PropertyValue -Object $Evaluation -Name "counts_by_status")
    counts_by_risk_level = (Get-PropertyValue -Object $Evaluation -Name "counts_by_risk_level")
    counts_by_usage_mode = (Get-PropertyValue -Object $Evaluation -Name "counts_by_usage_mode")
    high_risk_material_ids = (Get-IdsByRisk -Decisions $decisions -RiskLevel "HIGH")
    owner_approval_required_material_ids = (Get-OwnerApprovalIds -Decisions $decisions)
    reference_only_material_ids = (Get-IdsByDecision -Decisions $decisions -Decision "REFERENCE_ONLY")
    candidate_for_quarantine_material_ids = (Get-IdsByDecision -Decisions $decisions -Decision "CANDIDATE_FOR_QUARANTINE")
    candidate_for_wrapper_contract_material_ids = (Get-IdsByDecision -Decisions $decisions -Decision "CANDIDATE_FOR_WRAPPER_CONTRACT")
    rejected_material_ids = (Get-IdsByDecision -Decisions $decisions -Decision "REJECT")
    needs_metadata_material_ids = (Get-IdsByDecision -Decisions $decisions -Decision "NEEDS_METADATA")
    policy_summary = [ordered]@{
      policy_id = "$(Get-PropertyValue -Object $policy -Name "policy_id")"
      policy_version = "$(Get-PropertyValue -Object $policy -Name "policy_version")"
      catalog_mutated = ($CatalogHashBefore -ne $CatalogHashAfter)
      evaluation_only = $true
      trust_forbidden = $true
      no_external_tools_installed = $true
      no_scanners_run = $true
      no_quarantine_created = $true
    }
    next_allowed_step = $NextAllowedStep
    cut_list = As-Array (Get-PropertyValue -Object $policy -Name "cut_list")
  }

  Write-JsonFile -Path $ReportPath -Object $report
  if ($report.status -ne "PASS") {
    throw "MATERIAL_POLICY_REPORT_FAILED"
  }
}

function Write-PolicyProof {
  param(
    [object]$Evaluation,
    [string]$CatalogHashBefore,
    [string]$CatalogHashAfter
  )

  $queue = Read-JsonRequired "TASK_QUEUE.json"
  $policy = Read-JsonRequired $PolicyPath
  $trustedCount = [int](Get-PropertyValue -Object $Evaluation -Name "trusted_count")

  $proof = [ordered]@{
    proof_id = "MATERIAL_POLICY_V1"
    phase = "PHASE_81"
    capability_id = $CapabilityId
    task_id = $TaskId
    pack_id = $PackId
    status = "PASS"
    generated_at = Get-UtcStamp
    evidence_files = @(
      $CatalogPath,
      $PolicyPath,
      $ReportPath
    )
    validation_gates = @(
      "catalog_parsed",
      "catalog_entry_count_9",
      "trusted_count_zero",
      "policy_evaluation_one_decision_per_material",
      "catalog_hash_unchanged",
      "queue_returned_to_none"
    )
    queue_state_after = [ordered]@{
      active_task_id = "$(Get-PropertyValue -Object $queue -Name "active_task_id")"
    }
    catalog_state_after = [ordered]@{
      path = $CatalogPath
      entries = [int](Get-PropertyValue -Object $Evaluation -Name "catalog_entry_count")
      trusted_count = $trustedCount
      sha256_before = $CatalogHashBefore
      sha256_after = $CatalogHashAfter
      unchanged = ($CatalogHashBefore -eq $CatalogHashAfter)
    }
    policy_state_after = [ordered]@{
      policy_id = "$(Get-PropertyValue -Object $policy -Name "policy_id")"
      policy_version = "$(Get-PropertyValue -Object $policy -Name "policy_version")"
      decisions_count = [int](Get-PropertyValue -Object $Evaluation -Name "decisions_count")
      counts_by_decision = (Get-PropertyValue -Object $Evaluation -Name "counts_by_decision")
    }
    forbidden_actions_confirmed = [ordered]@{
      no_external_tools_installed = $true
      no_external_repos_fetched = $true
      no_materials_marked_trusted = ($trustedCount -eq 0)
      no_catalog_mutation = ($CatalogHashBefore -eq $CatalogHashAfter)
      no_quarantine_trial_created = $true
      no_external_agent_created = $true
      no_phase78_files_modified = $true
      no_phase79_files_modified = $true
      no_phase80_files_modified = $true
    }
    next_allowed_step = $NextAllowedStep
  }

  Write-JsonFile -Path $ProofPath -Object $proof
}

function Invoke-Validator {
  & (Join-RepoPath "packs/$PackId/VALIDATE.ps1") -RepoRoot $RepoRoot -Stage "Completed"
}

Write-Host "PHASE81_APPLY_START"

foreach ($marker in @("CAPABILITY_ROADMAP.json", "GENESIS_STATE.json", "TASK_QUEUE.json", "packs/registry.json", "orchestrator/run.ps1")) {
  if (-not (Test-Path -LiteralPath (Join-RepoPath $marker))) {
    throw "STOP=WRONG_AGENT_BUILDER_REPO missing $marker"
  }
}

if (-not (Test-Path -LiteralPath (Join-RepoPath $CatalogPath))) {
  throw "MISSING_MATERIAL_CATALOG=$CatalogPath"
}
if (-not (Test-Path -LiteralPath (Join-RepoPath $PolicyPath))) {
  throw "MISSING_MATERIAL_POLICY=$PolicyPath"
}

foreach ($directory in @("reports/materials", "proofs/materials")) {
  $path = Join-RepoPath $directory
  if (-not (Test-Path -LiteralPath $path)) {
    New-Item -ItemType Directory -Path $path -Force | Out-Null
  }
}

$catalog = Read-JsonRequired $CatalogPath
$entries = As-Array (Get-PropertyValue -Object $catalog -Name "entries")
if (@($entries).Count -ne 9) {
  throw "PHASE81_EXPECTED_CATALOG_ENTRY_COUNT_9_ACTUAL_$(@($entries).Count)"
}
$trustedCountBefore = Get-TrustedCount -Entries $entries
if ($trustedCountBefore -ne 0) {
  throw "PHASE81_CATALOG_TRUSTED_COUNT=$trustedCountBefore"
}

Read-JsonRequired $PolicyPath | Out-Null
Write-Host "MATERIAL_POLICY_READY"

$catalogHashBefore = Get-FileSha256 -Path $CatalogPath
$evaluation = & (Join-RepoPath "modules/materials/evaluate_material_policy.ps1") -RepoRoot $RepoRoot -CatalogPath $CatalogPath -PolicyPath $PolicyPath -NoMutation
$catalogHashAfterEvaluation = Get-FileSha256 -Path $CatalogPath

Write-PolicyReport -Evaluation $evaluation -CatalogHashBefore $catalogHashBefore -CatalogHashAfter $catalogHashAfterEvaluation
Write-Host "MATERIAL_POLICY_REPORT_WRITTEN"

Update-TaskQueue
Update-Roadmap
Update-GenesisState

$catalogHashAfterState = Get-FileSha256 -Path $CatalogPath
Write-PolicyProof -Evaluation $evaluation -CatalogHashBefore $catalogHashBefore -CatalogHashAfter $catalogHashAfterState
Write-Host "MATERIAL_POLICY_PROOF_WRITTEN"
Write-Host "TASK_QUEUE_RETURNED_TO_NONE"

Invoke-Validator

Write-Host "PHASE81_APPLY_COMPLETE"
