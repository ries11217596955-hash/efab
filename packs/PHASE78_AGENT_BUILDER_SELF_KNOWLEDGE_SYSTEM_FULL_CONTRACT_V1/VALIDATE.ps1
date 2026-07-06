[CmdletBinding()]
param(
  [ValidateSet("Auto", "Seed", "PreRuntime", "PreCompletion", "Completed")]
  [string]$Stage = "Auto",
  [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
)

$ErrorActionPreference = "Stop"

$CapabilityId = "agent_builder_self_knowledge_system_full_contract_v1"
$GateId = "AGENT_BUILDER_SELF_KNOWLEDGE_SYSTEM_FULL_CONTRACT_V1"
$TaskId = "TASK_AGENT_BUILDER_SELF_KNOWLEDGE_SYSTEM_FULL_CONTRACT_V1_001"
$ProofPath = "proofs/self_knowledge/AGENT_BUILDER_SELF_KNOWLEDGE_SYSTEM_FULL_CONTRACT_V1.json"

$script:Failures = @()
$script:Warnings = @()

function Join-RepoPath {
  param([string]$Path)
  return [System.IO.Path]::GetFullPath((Join-Path $RepoRoot $Path))
}

function Add-Failure {
  param([string]$Message)
  $script:Failures += $Message
}

function Add-Warning {
  param([string]$Message)
  $script:Warnings += $Message
}

function Safe-PSObjectProperties {
  param([object]$Object)

  if ($null -eq $Object) {
    return @()
  }

  return @($Object.PSObject.Properties)
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
    $property = Safe-PSObjectProperties $Object | Where-Object { $_.Name -ieq $name } | Select-Object -First 1
    if ($null -ne $property) {
      return $property.Value
    }
  }

  return $null
}

function Test-PropertyExists {
  param(
    [object]$Object,
    [string[]]$Names
  )

  if ($null -eq $Object) {
    return $false
  }

  foreach ($name in $Names) {
    $property = Safe-PSObjectProperties $Object | Where-Object { $_.Name -ieq $name } | Select-Object -First 1
    if ($null -ne $property) {
      return $true
    }
  }

  return $false
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

function Safe-Count {
  param([object]$Value)

  return @(As-Array $Value).Count
}

function Assert-Path {
  param(
    [string]$Path,
    [string]$Kind,
    [bool]$Required = $true
  )

  $fullPath = Join-RepoPath $Path
  $exists = Test-Path -LiteralPath $fullPath
  if (-not $exists) {
    if ($Required) {
      Add-Failure "MISSING_$($Kind.ToUpperInvariant())=$Path"
    } else {
      Add-Warning "EXPECTED_PRE_RUNTIME_LIMITATION_MISSING_$($Kind.ToUpperInvariant())=$Path"
    }
  }
}

function Normalize-Status {
  param([object]$Value)

  if ($null -eq $Value) {
    return "unknown"
  }

  $status = "$Value".Trim().ToLowerInvariant()
  if ($status -match "^(complete|completed|done|pass|passed|local pass|runtime pass|hosted pass)$") {
    return "completed"
  }
  if ($status -match "^(active|in_progress|running|current)$") {
    return "active"
  }
  if ($status -match "^(planned|pending|queued|todo)$") {
    return "planned"
  }
  if ($status -match "^(candidate|prepared|prepared, not run|claimed|codex claimed, proof required)$") {
    return "candidate"
  }
  if ($status -match "(fail|failed|blocked|partial|error|stop)") {
    return "failed"
  }
  if ($status -eq "proven") {
    return "proven"
  }

  return "unknown"
}

function Find-PhaseStatus {
  param([object]$Node)

  if ($null -eq $Node) {
    return $null
  }

  if ($Node -is [System.Array]) {
    foreach ($item in $Node) {
      $found = Find-PhaseStatus -Node $item
      if ($null -ne $found) {
        return $found
      }
    }
    return $null
  }

  if ($Node -isnot [pscustomobject]) {
    return $null
  }

  $id = Get-PropertyValue -Object $Node -Names @("id", "capability_id", "capability", "name")
  $phase = Get-PropertyValue -Object $Node -Names @("phase", "phase_id", "phase_name")
  $gate = Get-PropertyValue -Object $Node -Names @("gate", "validator_gate", "capability_gate")
  $status = Get-PropertyValue -Object $Node -Names @("status", "state", "phase_status")

  if ("$id" -eq $CapabilityId -or "$phase" -eq "PHASE_78" -or "$gate" -eq $GateId) {
    return [pscustomobject]@{
      id = "$id"
      phase = "$phase"
      gate = "$gate"
      status = Normalize-Status $status
      raw_status = "$status"
    }
  }

  foreach ($property in (Safe-PSObjectProperties $Node)) {
    if ($property.Value -is [System.Array] -or $property.Value -is [pscustomobject]) {
      $found = Find-PhaseStatus -Node $property.Value
      if ($null -ne $found) {
        return $found
      }
    }
  }

  return $null
}

function Find-CanonicalPhaseStatus {
  param([object]$Roadmap)

  $capabilities = As-Array (Get-PropertyValue -Object $Roadmap -Names @("capabilities"))
  foreach ($capability in $capabilities) {
    if ($capability -is [pscustomobject]) {
      $id = Get-PropertyValue -Object $capability -Names @("id", "capability_id", "capability", "name")
      $phase = Get-PropertyValue -Object $capability -Names @("phase", "phase_id", "phase_name")
      $gate = Get-PropertyValue -Object $capability -Names @("gate", "validator_gate", "capability_gate")
      $status = Get-PropertyValue -Object $capability -Names @("status", "state", "phase_status")
      if ("$id" -eq $CapabilityId -or "$phase" -eq "PHASE_78" -or "$gate" -eq $GateId) {
        return [pscustomobject]@{
          id = "$id"
          phase = "$phase"
          gate = "$gate"
          status = Normalize-Status $status
          raw_status = "$status"
        }
      }
    }
  }

  return $null
}

function Find-CanonicalTaskEntry {
  param([object]$TaskQueue)

  $tasks = As-Array (Get-PropertyValue -Object $TaskQueue -Names @("tasks"))
  foreach ($task in $tasks) {
    if ($task -is [pscustomobject]) {
      $id = Get-PropertyValue -Object $task -Names @("task_id", "id")
      if ("$id" -eq $TaskId) {
        return $task
      }
    }
  }

  return $null
}

function Find-CanonicalPackEntry {
  param([object]$Registry)

  $packs = As-Array (Get-PropertyValue -Object $Registry -Names @("packs"))
  foreach ($pack in $packs) {
    if ($pack -is [pscustomobject]) {
      $id = Get-PropertyValue -Object $pack -Names @("pack_id", "id", "name")
      if ("$id" -eq "PHASE78_AGENT_BUILDER_SELF_KNOWLEDGE_SYSTEM_FULL_CONTRACT_V1") {
        return $pack
      }
    }
  }

  return $null
}

function Resolve-ValidationStage {
  param([string]$RequestedStage)

  if ($RequestedStage -ne "Auto") {
    return $RequestedStage
  }

  $queue = Read-JsonFile "TASK_QUEUE.json"
  $activeTaskId = Get-PropertyValue -Object $queue -Names @("active_task_id", "activeTaskId")
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

$seedMode = $Stage -in @("Seed", "PreRuntime")

$requiredDirectories = @(
  "contracts/self_knowledge",
  "self_knowledge",
  "modules",
  "tasks",
  "packs/PHASE78_AGENT_BUILDER_SELF_KNOWLEDGE_SYSTEM_FULL_CONTRACT_V1"
)

if (-not $seedMode) {
  $requiredDirectories += @(
    "reports/self_knowledge",
    "proofs/self_knowledge"
  )
}

foreach ($directory in $requiredDirectories) {
  Assert-Path -Path $directory -Kind "directory" -Required $true
}

$contractFiles = @(
  "contracts/self_knowledge/builder_self_model.schema.json",
  "contracts/self_knowledge/capability_manifest.schema.json",
  "contracts/self_knowledge/module_inventory.schema.json",
  "contracts/self_knowledge/evidence_index.schema.json",
  "contracts/self_knowledge/produced_agents_index.schema.json",
  "contracts/self_knowledge/self_describe_report.schema.json"
)

$selfKnowledgeFiles = @(
  "self_knowledge/BUILDER_SELF_MODEL.json",
  "self_knowledge/CAPABILITY_MANIFEST.json",
  "self_knowledge/MODULE_INVENTORY.json",
  "self_knowledge/EVIDENCE_INDEX.json",
  "self_knowledge/PRODUCED_AGENTS_INDEX.json",
  "self_knowledge/ROADMAP_STATE.json"
)

$runtimeFiles = @(
  "modules/build_builder_self_knowledge.ps1",
  "modules/write_builder_self_describe_report.ps1",
  "tasks/$TaskId.json",
  "packs/PHASE78_AGENT_BUILDER_SELF_KNOWLEDGE_SYSTEM_FULL_CONTRACT_V1/PACK.json",
  "packs/PHASE78_AGENT_BUILDER_SELF_KNOWLEDGE_SYSTEM_FULL_CONTRACT_V1/APPLY.ps1",
  "packs/PHASE78_AGENT_BUILDER_SELF_KNOWLEDGE_SYSTEM_FULL_CONTRACT_V1/VALIDATE.ps1",
  "packs/PHASE78_AGENT_BUILDER_SELF_KNOWLEDGE_SYSTEM_FULL_CONTRACT_V1/README.md"
)

foreach ($file in @($contractFiles + $selfKnowledgeFiles + $runtimeFiles)) {
  Assert-Path -Path $file -Kind "file" -Required $true
}

$reportFiles = @(
  "reports/self_knowledge/BUILDER_SELF_DESCRIBE_REPORT.json",
  "reports/self_knowledge/BUILDER_SELF_DESCRIBE_SUMMARY.md"
)

foreach ($file in $reportFiles) {
  Assert-Path -Path $file -Kind "file" -Required (-not $seedMode)
}

Assert-Path -Path $ProofPath -Kind "file" -Required ($Stage -eq "Completed")

$packContract = Read-JsonFile "packs/PHASE78_AGENT_BUILDER_SELF_KNOWLEDGE_SYSTEM_FULL_CONTRACT_V1/PACK.json"
if ($null -ne $packContract) {
  $packContractExpected = [ordered]@{
    pack_id = "PHASE78_AGENT_BUILDER_SELF_KNOWLEDGE_SYSTEM_FULL_CONTRACT_V1"
    task_id = $TaskId
    capability_id = $CapabilityId
    phase = "PHASE_78"
    gate = $GateId
    active_line = "AGENT_BUILDER_SELF_DEVELOPMENT"
    mode = "SELF_BUILD"
    entry_script = "packs/PHASE78_AGENT_BUILDER_SELF_KNOWLEDGE_SYSTEM_FULL_CONTRACT_V1/APPLY.ps1"
    validate_script = "packs/PHASE78_AGENT_BUILDER_SELF_KNOWLEDGE_SYSTEM_FULL_CONTRACT_V1/VALIDATE.ps1"
    shell = "PowerShell"
  }

  foreach ($key in $packContractExpected.Keys) {
    $actual = Get-PropertyValue -Object $packContract -Names @($key)
    if ("$actual" -ne "$($packContractExpected[$key])") {
      Add-Failure "PACK_CONTRACT_FIELD_MISMATCH=$($key)::$actual"
    }
  }

  $purpose = Get-PropertyValue -Object $packContract -Names @("purpose")
  if ($null -eq $purpose -or "$purpose" -eq "") {
    Add-Failure "PACK_CONTRACT_MISSING_PURPOSE"
  }
}

$selfModel = Read-JsonFile "self_knowledge/BUILDER_SELF_MODEL.json"
if ($null -ne $selfModel) {
  $requiredSections = @(
    "builder_identity",
    "repo_markers",
    "current_state",
    "queue_state",
    "roadmap_summary",
    "capability_manifest",
    "module_inventory",
    "generated_programs",
    "produced_agents",
    "launch_surfaces",
    "proof_index",
    "report_index",
    "missing_surfaces",
    "failed_or_partial_items",
    "next_strongest_move",
    "cut_list",
    "evidence_policy"
  )

  foreach ($section in $requiredSections) {
    if (-not (Test-PropertyExists -Object $selfModel -Names @($section))) {
      Add-Failure "SELF_MODEL_MISSING_SECTION=$section"
    }
  }

  $missingPaths = @(
    As-Array (Get-PropertyValue -Object $selfModel -Names @("missing_surfaces")) |
      ForEach-Object { $_.path }
  )
  $missingRequiredWhenAbsent = @(
    "operations",
    "operation_registry.json",
    "contracts/operation.schema.json",
    "reports/operations",
    "proofs/operations",
    "agent_intents",
    "blueprints",
    "contracts/blueprint.schema.json",
    "templates/agent_blueprint",
    "reports/blueprint_compiler",
    "proofs/blueprint_compiler"
  )
  foreach ($path in $missingRequiredWhenAbsent) {
    if (-not (Test-Path -LiteralPath (Join-RepoPath $path))) {
      $canonical = ($path -replace "\\", "/")
      if ($missingPaths -notcontains $canonical) {
        Add-Failure "MISSING_SURFACE_NOT_RECORDED=$canonical"
      }
    }
  }

  foreach ($proof in As-Array (Get-PropertyValue -Object $selfModel -Names @("proof_index"))) {
    $proofPath = Get-PropertyValue -Object $proof -Names @("path")
    if ($null -ne $proofPath -and "$proofPath" -ne "" -and -not (Test-Path -LiteralPath (Join-RepoPath $proofPath))) {
      Add-Failure "FAKE_PROOF_INDEX_PATH=$proofPath"
    }
  }

  foreach ($report in As-Array (Get-PropertyValue -Object $selfModel -Names @("report_index"))) {
    $reportPath = Get-PropertyValue -Object $report -Names @("path")
    if ($null -ne $reportPath -and "$reportPath" -ne "" -and -not (Test-Path -LiteralPath (Join-RepoPath $reportPath))) {
      Add-Failure "FAKE_REPORT_INDEX_PATH=$reportPath"
    }
  }

  $capabilityManifest = Get-PropertyValue -Object $selfModel -Names @("capability_manifest")
  $capabilities = As-Array (Get-PropertyValue -Object $capabilityManifest -Names @("capabilities"))
  foreach ($capability in $capabilities) {
    foreach ($evidencePath in As-Array (Get-PropertyValue -Object $capability -Names @("evidence_paths"))) {
      if (-not (Test-Path -LiteralPath (Join-RepoPath $evidencePath))) {
        $capabilityId = Get-PropertyValue -Object $capability -Names @("id")
        Add-Failure "FAKE_CAPABILITY_EVIDENCE_PATH=$($capabilityId)::$evidencePath"
      }
    }

    $capabilityIdText = Get-PropertyValue -Object $capability -Names @("id")
    $capabilityGateText = Get-PropertyValue -Object $capability -Names @("gate")
    $idText = "$capabilityIdText $capabilityGateText"
    $status = Normalize-Status (Get-PropertyValue -Object $capability -Names @("status"))
    $identityKey = (($idText).ToLowerInvariant() -replace "[^a-z0-9]+", "_").Trim("_")
    $claimsOperationSystem = $identityKey -match "(^|_)operation_system($|_)"
    $claimsBlueprintCompiler = $identityKey -match "(^|_)blueprint_compiler($|_)"
    if (($claimsOperationSystem -or $claimsBlueprintCompiler) -and $status -in @("completed", "proven")) {
      $area = $(if ($claimsOperationSystem) { "Operation System" } else { "Blueprint Compiler" })
      $areaMissing = @(
        As-Array (Get-PropertyValue -Object $selfModel -Names @("missing_surfaces")) |
          Where-Object { $_.area -eq $area }
      )
      if ((Safe-Count $areaMissing) -gt 0) {
        Add-Failure "FORBIDDEN_FALSE_COMPLETED_SYSTEM=$idText"
      }
    }
  }
}

if (-not $seedMode) {
  $report = Read-JsonFile "reports/self_knowledge/BUILDER_SELF_DESCRIBE_REPORT.json"
  if ($null -ne $report) {
    $answers = Get-PropertyValue -Object $report -Names @("answers")
    $answerSections = @(
      "who_is_builder",
      "what_repo_is_this",
      "current_capability",
      "queue_state",
      "major_systems_exist",
      "major_systems_missing",
      "agent_like_products_evidenced",
      "proofs_reports_supporting_claims",
      "what_should_be_built_next",
      "what_should_not_be_done_next"
    )
    foreach ($section in $answerSections) {
      if (-not (Test-PropertyExists -Object $answers -Names @($section))) {
        Add-Failure "SELF_DESCRIBE_REPORT_MISSING_ANSWER=$section"
      }
    }
  }
}

if ($seedMode) {
  $queue = Read-JsonFile "TASK_QUEUE.json"
  $activeTaskId = Get-PropertyValue -Object $queue -Names @("active_task_id", "activeTaskId")
  if ("$activeTaskId" -ne $TaskId) {
    Add-Failure "SEED_ACTIVE_TASK_MISMATCH=$activeTaskId"
  }
  if (Test-PropertyExists -Object $queue -Names @("phase78_active_task_entry")) {
    Add-Failure "NON_CANONICAL_TOP_LEVEL_TASK_KEY_PRESENT=phase78_active_task_entry"
  }
  $taskEntry = Find-CanonicalTaskEntry -TaskQueue $queue
  if ($null -eq $taskEntry) {
    Add-Failure "SEED_TASK_NOT_IN_TASKS_ARRAY=$TaskId"
  } else {
    $taskPath = Get-PropertyValue -Object $taskEntry -Names @("path", "task_path", "file")
    if ("$taskPath" -ne "tasks/TASK_AGENT_BUILDER_SELF_KNOWLEDGE_SYSTEM_FULL_CONTRACT_V1_001.json") {
      Add-Failure "SEED_TASK_ENTRY_PATH_MISMATCH=$taskPath"
    }
  }

  $roadmap = Read-JsonFile "CAPABILITY_ROADMAP.json"
  if (Test-PropertyExists -Object $roadmap -Names @("PHASE_78")) {
    Add-Failure "NON_CANONICAL_TOP_LEVEL_PHASE_KEY_PRESENT=PHASE_78"
  }
  $phase = Find-CanonicalPhaseStatus -Roadmap $roadmap
  $roadmapText = ($roadmap | ConvertTo-Json -Depth 100)
  if ($null -eq $phase) {
    Add-Failure "SEED_PHASE_78_NOT_IN_CAPABILITIES_ARRAY"
  } elseif ($phase.status -ne "active") {
    Add-Failure "SEED_PHASE_78_NOT_ACTIVE=$($phase.raw_status)"
  }
  if ($roadmapText -notmatch "Establish repo-native self-knowledge system for Agent Builder with evidence-indexed owner-readable self-description") {
    Add-Failure "SEED_PHASE_78_GOAL_MISSING"
  }

  $genesis = Read-JsonFile "GENESIS_STATE.json"
  $currentCapability = Get-PropertyValue -Object $genesis -Names @("current_capability", "capability", "active_capability")
  if ("$currentCapability" -ne $CapabilityId) {
    Add-Failure "SEED_GENESIS_CURRENT_CAPABILITY_MISMATCH=$currentCapability"
  }

  $completedCapabilities = As-Array (Get-PropertyValue -Object $genesis -Names @("completed_capabilities", "completedCapabilities"))
  if ($completedCapabilities -contains $CapabilityId) {
    Add-Failure "SEED_COMPLETED_CAPABILITY_PREMATURE=$CapabilityId"
  }

  $registry = Read-JsonFile "packs/registry.json"
  if (Test-PropertyExists -Object $registry -Names @("PHASE78_AGENT_BUILDER_SELF_KNOWLEDGE_SYSTEM_FULL_CONTRACT_V1")) {
    Add-Failure "NON_CANONICAL_TOP_LEVEL_PACK_KEY_PRESENT=PHASE78_AGENT_BUILDER_SELF_KNOWLEDGE_SYSTEM_FULL_CONTRACT_V1"
  }
  $packEntry = Find-CanonicalPackEntry -Registry $registry
  if ($null -eq $packEntry) {
    Add-Failure "SEED_PACK_NOT_IN_PACKS_ARRAY=PHASE78_AGENT_BUILDER_SELF_KNOWLEDGE_SYSTEM_FULL_CONTRACT_V1"
  } else {
    $registryExpected = [ordered]@{
      path = "packs/PHASE78_AGENT_BUILDER_SELF_KNOWLEDGE_SYSTEM_FULL_CONTRACT_V1"
      task_id = $TaskId
      pack_contract_path = "packs/PHASE78_AGENT_BUILDER_SELF_KNOWLEDGE_SYSTEM_FULL_CONTRACT_V1/PACK.json"
      entry_script = "packs/PHASE78_AGENT_BUILDER_SELF_KNOWLEDGE_SYSTEM_FULL_CONTRACT_V1/APPLY.ps1"
      shell = "PowerShell"
    }
    foreach ($key in $registryExpected.Keys) {
      $actual = Get-PropertyValue -Object $packEntry -Names @($key)
      if ("$actual" -ne "$($registryExpected[$key])") {
        Add-Failure "SEED_PACK_REGISTRY_FIELD_MISMATCH=$($key)::$actual"
      }
    }
  }
}

if ($Stage -eq "Completed") {
  $queue = Read-JsonFile "TASK_QUEUE.json"
  $activeTaskId = Get-PropertyValue -Object $queue -Names @("active_task_id", "activeTaskId")
  if ("$activeTaskId" -ne "NONE") {
    Add-Failure "ACTIVE_TASK_NOT_CLOSED=$activeTaskId"
  }
  $taskEntry = Find-CanonicalTaskEntry -TaskQueue $queue
  if ($null -eq $taskEntry) {
    Add-Failure "COMPLETED_TASK_ENTRY_MISSING=$TaskId"
  } else {
    $taskStatus = Normalize-Status (Get-PropertyValue -Object $taskEntry -Names @("status"))
    if ($taskStatus -ne "completed") {
      Add-Failure "TASK_STATUS_NOT_COMPLETED=$taskStatus"
    }
  }

  $roadmap = Read-JsonFile "CAPABILITY_ROADMAP.json"
  $phase = Find-PhaseStatus -Node $roadmap
  if ($null -eq $phase) {
    Add-Failure "PHASE_78_NOT_REGISTERED"
  } elseif ($phase.status -ne "completed") {
    Add-Failure "PHASE_78_NOT_COMPLETED=$($phase.raw_status)"
  }

  $genesis = Read-JsonFile "GENESIS_STATE.json"
  $currentCapability = Get-PropertyValue -Object $genesis -Names @("current_capability", "capability", "active_capability")
  if ("$currentCapability" -ne $CapabilityId) {
    Add-Failure "GENESIS_CURRENT_CAPABILITY_MISMATCH=$currentCapability"
  }
  $completedCapabilities = As-Array (Get-PropertyValue -Object $genesis -Names @("completed_capabilities", "completedCapabilities"))
  if ($completedCapabilities -notcontains $CapabilityId) {
    Add-Failure "GENESIS_COMPLETED_CAPABILITY_MISSING=$CapabilityId"
  }
}

foreach ($warning in $script:Warnings) {
  Write-Host "WARNING=$warning"
}

if ((Safe-Count $script:Failures) -gt 0) {
  foreach ($failure in $script:Failures) {
    Write-Host "FAIL=$failure"
  }
  Write-Host "VALIDATION_RESULT=FAIL"
  throw "PHASE78_VALIDATION_FAILED"
}

if ($seedMode) {
  Write-Host "VALIDATION_RESULT=PASS_SEED"
  Write-Host "SEED_READY=TRUE"
} else {
  Write-Host "VALIDATION_RESULT=PASS"
}
if ((Safe-Count $script:Warnings) -gt 0) {
  Write-Host "VALIDATION_LIMITATIONS=$(Safe-Count $script:Warnings)"
}
