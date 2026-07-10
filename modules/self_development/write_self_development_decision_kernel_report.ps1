[CmdletBinding()]
param(
  [string]$OutputReportPath = "reports/self_development/SELF_DEVELOPMENT_DECISION_KERNEL_REPORT.json",
  [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path,
  [string]$OwnerMaterialInputPath = "self_build_batch/owner_material_inputs/ACTIVE_OWNER_MATERIAL_INPUT.json"
)

$ErrorActionPreference = "Stop"

$CurrentPhase = "PHASE87_SELF_DEVELOPMENT_DECISION_KERNEL_V1"
$LastProvenCommitExpected = "89a7b5b"
$RecommendedNextStepId = "PHASE88_SELF_BUILD_PROGRAM_GENERATOR_V1"

$RequiredCoreEvidence = @(
  @{ path = "CAPABILITY_ROADMAP.json"; kind = "json" },
  @{ path = "GENESIS_STATE.json"; kind = "json" },
  @{ path = "TASK_QUEUE.json"; kind = "json" },
  @{ path = "packs/registry.json"; kind = "json" },
  @{ path = "orchestrator/run.ps1"; kind = "text" }
)

$OptionalEvidence = @(
  @{ path = "self_knowledge/BUILDER_SELF_MODEL.json"; kind = "json" },
  @{ path = "self_knowledge/CAPABILITY_MANIFEST.json"; kind = "json" },
  @{ path = "self_knowledge/ROADMAP_STATE.json"; kind = "json" },
  @{ path = "reports/self_knowledge/BUILDER_SELF_DESCRIBE_REPORT.json"; kind = "json" },
  @{ path = "proofs/self_knowledge/AGENT_BUILDER_SELF_KNOWLEDGE_SYSTEM_FULL_CONTRACT_V1.json"; kind = "json" },
  @{ path = "reports/materials/MATERIAL_ACQUISITION_BOOTSTRAP_REPORT.json"; kind = "json" },
  @{ path = "proofs/materials/MATERIAL_ACQUISITION_BOOTSTRAP_V1.json"; kind = "json" },
  @{ path = "reports/materials/MANUAL_SCOUT_PASS_IMPORT_REPORT.json"; kind = "json" },
  @{ path = "proofs/materials/MANUAL_SCOUT_PASS_IMPORT_V1.json"; kind = "json" },
  @{ path = "reports/materials/MATERIAL_POLICY_V1_REPORT.json"; kind = "json" },
  @{ path = "proofs/materials/MATERIAL_POLICY_V1.json"; kind = "json" },
  @{ path = "reports/materials/FIRST_QUARANTINE_TRIAL_REPORT.json"; kind = "json" },
  @{ path = "proofs/materials/FIRST_QUARANTINE_TRIAL_V1.json"; kind = "json" },
  @{ path = "materials/MATERIAL_CATALOG.json"; kind = "json" },
  @{ path = "materials/MATERIAL_POLICY.json"; kind = "json" },
  @{ path = "materials/quarantine/QUARANTINE_BATCH_001.json"; kind = "json" },
  @{ path = "reports/planning/AGENT_BUILDER_NEXT_15_STEPS_LOCK_V1.md"; kind = "text" }
)

$script:EvidenceInputsRead = @()
$script:MissingOptionalEvidence = @()

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
    # PHASE164O_WRITE_JSON_CREATES_PARENT_DIR
  $dir = Split-Path -Parent $fullPath
  if ($dir -and -not (Test-Path -LiteralPath $dir)) {
    New-Item -ItemType Directory -Force -Path $dir | Out-Null
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

function Read-Evidence {
  param(
    [string]$Path,
    [string]$Kind,
    [bool]$Required
  )

  $fullPath = Join-RepoPath $Path
  if (-not (Test-Path -LiteralPath $fullPath)) {
    if ($Required) {
      throw "MISSING_REQUIRED_EVIDENCE=$Path"
    }
    $script:MissingOptionalEvidence += [ordered]@{
      path = $Path
      classification = "MISSING_OPTIONAL_EVIDENCE"
    }
    return $null
  }

  $entry = [ordered]@{
    path = $Path
    required = $Required
    kind = $Kind
    read_status = "READ"
    sha256 = Get-FileSha256 -Path $Path
    byte_length = (Get-Item -LiteralPath $fullPath).Length
  }

  if ($Kind -eq "json") {
    try {
      $json = Get-Content -LiteralPath $fullPath -Raw | ConvertFrom-Json
      $entry["parsed_json"] = $true
      $statusValue = Get-PropertyValue -Object $json -Name "status"
      if ($null -ne $statusValue) {
        $entry["reported_status"] = "$statusValue"
      }
      $script:EvidenceInputsRead += $entry
      return $json
    } catch {
      $entry["read_status"] = "READ_ERROR"
      $entry["parsed_json"] = $false
      $entry["error"] = $_.Exception.Message
      $script:EvidenceInputsRead += $entry
      if ($Required) {
        throw "INVALID_REQUIRED_JSON=$Path"
      }
      return $null
    }
  }

  $entry["parsed_json"] = $false
  $script:EvidenceInputsRead += $entry
  return (Get-Content -LiteralPath $fullPath -Raw)
}

function Get-ArrayProperty {
  param(
    [object]$Object,
    [string[]]$Names
  )

  foreach ($name in $Names) {
    $value = Get-PropertyValue -Object $Object -Name $name
    if ($null -ne $value) {
      return @(As-Array $value)
    }
  }
  return @()
}

function Count-TrustedMaterials {
  param([object[]]$Entries)

  $count = 0
  foreach ($entry in $Entries) {
    foreach ($field in @("status", "trust_status", "catalog_status")) {
      if ("$(Get-PropertyValue -Object $entry -Name $field)" -eq "TRUSTED") {
        $count++
        break
      }
    }
  }
  return $count
}


# PHASE164O_OWNER_MATERIAL_INPUT_V1
function Read-OwnerMaterialInput {
  param([string]$Path)

  $result = [ordered]@{
    available = $false
    path = $Path
    read_status = "NOT_FOUND"
    status = ""
    source_kind = ""
    source_candidate_id = ""
    source_candidate_path = ""
    source_request_path = ""
    target_real_process = ""
    not_a_parallel_conveyor = $true
  }

  $fullPath = Join-RepoPath $Path
  if (-not (Test-Path -LiteralPath $fullPath)) {
    return [pscustomobject]$result
  }

  try {
    $json = Get-Content -LiteralPath $fullPath -Raw | ConvertFrom-Json
    $result.available = $true
    $result.read_status = "READ"
    $result.status = "$(Get-PropertyValue -Object $json -Name "status")"
    $result.source_kind = "$(Get-PropertyValue -Object $json -Name "source_kind")"
    $result.source_candidate_id = "$(Get-PropertyValue -Object $json -Name "source_candidate_id")"
    $result.source_candidate_path = "$(Get-PropertyValue -Object $json -Name "source_candidate_path")"
    $result.source_request_path = "$(Get-PropertyValue -Object $json -Name "source_request_path")"
    $result.target_real_process = "$(Get-PropertyValue -Object $json -Name "target_real_process")"
    return [pscustomobject]$result
  } catch {
    $result.available = $false
    $result.read_status = "READ_ERROR"
    $result.error = $_.Exception.Message
    return [pscustomobject]$result
  }
}
Write-Host "SELF_DEVELOPMENT_DECISION_KERNEL_START"

$requiredObjects = @{}
foreach ($required in $RequiredCoreEvidence) {
  $requiredObjects[$required.path] = Read-Evidence -Path $required.path -Kind $required.kind -Required $true
}

$roadmap = $requiredObjects["CAPABILITY_ROADMAP.json"]
$genesis = $requiredObjects["GENESIS_STATE.json"]
$queue = $requiredObjects["TASK_QUEUE.json"]
$registry = $requiredObjects["packs/registry.json"]

$optionalObjects = @{}
foreach ($optional in $OptionalEvidence) {
  $optionalObjects[$optional.path] = Read-Evidence -Path $optional.path -Kind $optional.kind -Required $false
}

$ownerMaterialInput = Read-OwnerMaterialInput -Path $OwnerMaterialInputPath

$capabilities = Get-ArrayProperty -Object $roadmap -Names @("capabilities")
$tasks = Get-ArrayProperty -Object $queue -Names @("tasks")
$packs = Get-ArrayProperty -Object $registry -Names @("packs")
$completedCapabilities = @($capabilities | Where-Object { "$(Get-PropertyValue -Object $_ -Name "status")" -eq "COMPLETED" })
$activeCapabilities = @($capabilities | Where-Object { "$(Get-PropertyValue -Object $_ -Name "status")" -in @("ACTIVE", "PENDING", "IN_PROGRESS") })
$completedGenesisCapabilities = Get-ArrayProperty -Object $genesis -Names @("completed_capabilities")

$catalog = $optionalObjects["materials/MATERIAL_CATALOG.json"]
$catalogEntries = Get-ArrayProperty -Object $catalog -Names @("entries", "materials")
$policy = $optionalObjects["materials/MATERIAL_POLICY.json"]
$policyDecisions = Get-ArrayProperty -Object $policy -Names @("decisions", "materials")
$quarantineBatch = $optionalObjects["materials/quarantine/QUARANTINE_BATCH_001.json"]
$selectedMaterialIds = Get-ArrayProperty -Object $quarantineBatch -Names @("selected_material_ids")
$operations = Get-ArrayProperty -Object $operationRegistry -Names @("operations")
$trustedOperations = @($operations | Where-Object { "$(Get-PropertyValue -Object $_ -Name "status")" -eq "TRUSTED_OPERATION" })

$capabilitySummary = [ordered]@{
  roadmap_capability_count = @($capabilities).Count
  roadmap_completed_count = @($completedCapabilities).Count
  roadmap_active_count = @($activeCapabilities).Count
  genesis_completed_count = @($completedGenesisCapabilities).Count
  queue_task_count = @($tasks).Count
  pack_registry_count = @($packs).Count
  queue_active_task_id = "$(Get-PropertyValue -Object $queue -Name "active_task_id")"
  genesis_current_phase = "$(Get-PropertyValue -Object $genesis -Name "current_phase")"
  genesis_current_capability = "$(Get-PropertyValue -Object $genesis -Name "current_capability")"
}

$provenFoundationSummary = [ordered]@{
  phase86_proof_status = "$(Get-PropertyValue -Object $phase86Proof -Name "status")"
  phase86_next_allowed_step = "$(Get-PropertyValue -Object $phase86Proof -Name "next_allowed_step")"
  operation_runtime_report_status = "$(Get-PropertyValue -Object $phase86Report -Name "status")"
  material_catalog_entry_count = @($catalogEntries).Count
  material_trusted_count = Count-TrustedMaterials -Entries $catalogEntries
  material_policy_decision_count = @($policyDecisions).Count
  quarantine_selected_count = @($selectedMaterialIds).Count
  operation_registry_status = "$(Get-PropertyValue -Object $operationRegistry -Name "status")"
  operation_count = @($operations).Count
  trusted_operation_count = @($trustedOperations).Count
  route_lock_report_available = [bool]($optionalObjects["reports/planning/AGENT_BUILDER_NEXT_15_STEPS_LOCK_V1.md"])
  self_knowledge_model_available = [bool]($optionalObjects["self_knowledge/BUILDER_SELF_MODEL.json"])
}

$queueStateBefore = [ordered]@{
  active_task_id = "$(Get-PropertyValue -Object $queue -Name "active_task_id")"
  phase87_task_status = ""
}
foreach ($task in $tasks) {
  if ("$(Get-PropertyValue -Object $task -Name "task_id")" -eq "TASK_SELF_DEVELOPMENT_DECISION_KERNEL_V1_001") {
    $queueStateBefore["phase87_task_status"] = "$(Get-PropertyValue -Object $task -Name "status")"
  }
}

$report = [ordered]@{
  status = "PASS"
  generated_at = Get-UtcStamp
  active_line = "AGENT_BUILDER / SELF_BUILD"
  current_phase = $CurrentPhase
  last_proven_phase = $LastProvenPhase
  last_proven_commit_expected = $LastProvenCommitExpected
  queue_state_before = $queueStateBefore
  evidence_inputs_read = @($script:EvidenceInputsRead)
  missing_optional_evidence = @($script:MissingOptionalEvidence)
    owner_material_input = $ownerMaterialInput
  capability_summary = $capabilitySummary
  proven_foundation_summary = $provenFoundationSummary
  current_gap = [ordered]@{
      owner_material_considered = [bool]$ownerMaterialInput.available
      owner_material_source_candidate_id = "$($ownerMaterialInput.source_candidate_id)"
      owner_material_source_request_path = "$($ownerMaterialInput.source_request_path)"
    gap_id = "SELF_BUILD_PROGRAM_GENERATOR_MISSING"
    description = "Builder can now classify materials, quarantine safe candidates, define operation contracts, smoke a sandbox install, and create operation dry-run plans, but it does not yet synthesize a self-build program from a decision."
    gap_type = "SELF_DEVELOPMENT_PROGRAM_GENERATION"
  }
  recommended_next_step = "Create the first self-build program generator so a decision report can be transformed into a bounded self-build program plan without executing generated programs."
  recommended_next_step_id = $RecommendedNextStepId
  decision_reason = "PHASE79 through PHASE86 established material governance and operation runtime gates. The next internal bottleneck is converting evidence-backed decisions into self-build program generation while preserving queue, proof, and cut-list discipline."
  risks = @(
    "Decision output depends on repo evidence freshness and does not independently prove remote state.",
    "Optional evidence can be missing and is classified, but missing optional context can reduce decision richness.",
    "PHASE87 does not generate PHASE88 artifacts or execute any generated self-build program.",
    "Future PHASE88 must preserve the same no-install, no-external-agent, and proof-first boundaries."
  )
  cut_list = @(
    "Do not create PHASE88 yet.",
    "Do not generate self-build programs yet.",
    "Do not admit a generated program.",
    "Do not execute operation runtime.",
    "Do not install tools.",
    "Do not fetch external sources.",
    "Do not mark materials TRUSTED.",
    "Do not produce external agents.",
    "Do not change route lock.",
    "Do not commit."
  )
}

Write-JsonFile -Path $OutputReportPath -Object $report
Write-Host "DECISION_EVIDENCE_READ_COUNT=$(@($script:EvidenceInputsRead).Count)"
Write-Host "MISSING_OPTIONAL_EVIDENCE_COUNT=$(@($script:MissingOptionalEvidence).Count)"
Write-Host "RECOMMENDED_NEXT_STEP_ID=$RecommendedNextStepId"
Write-Host "SELF_DEVELOPMENT_DECISION_REPORT_WRITTEN=$OutputReportPath"
Write-Host "SELF_DEVELOPMENT_DECISION_KERNEL_COMPLETE"

return [pscustomobject]$report




