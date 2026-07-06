[CmdletBinding()]
param(
  [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
)

$ErrorActionPreference = "Stop"

$CapabilityId = "agent_builder_self_knowledge_system_full_contract_v1"
$GateId = "AGENT_BUILDER_SELF_KNOWLEDGE_SYSTEM_FULL_CONTRACT_V1"
$SchemaVersion = "AGENT_BUILDER_SELF_KNOWLEDGE_SYSTEM_FULL_CONTRACT_V1"
$StatusTaxonomy = @(
  "proven",
  "completed",
  "active",
  "candidate",
  "planned",
  "failed",
  "unknown",
  "missing_surface"
)

function Get-UtcStamp {
  return (Get-Date).ToUniversalTime().ToString("o")
}

function Join-RepoPath {
  param([string]$Path)
  return [System.IO.Path]::GetFullPath((Join-Path $RepoRoot $Path))
}

function ConvertTo-RepoPath {
  param([string]$Path)

  $rootFull = ([System.IO.Path]::GetFullPath($RepoRoot)).TrimEnd([char[]]@("\", "/"))
  $fullPath = [System.IO.Path]::GetFullPath($Path)
  if ($fullPath.StartsWith($rootFull, [System.StringComparison]::OrdinalIgnoreCase)) {
    return ($fullPath.Substring($rootFull.Length).TrimStart([char[]]@("\", "/")) -replace "\\", "/")
  }

  return ($fullPath -replace "\\", "/")
}

function Read-JsonFile {
  param([string]$Path)

  if (-not (Test-Path -LiteralPath $Path)) {
    return $null
  }

  try {
    return (Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json)
  } catch {
    return [pscustomobject]@{
      parse_error = $_.Exception.Message
      path = ConvertTo-RepoPath $Path
    }
  }
}

function Write-JsonFile {
  param(
    [string]$Path,
    [object]$Object
  )

  $directory = Split-Path -Parent $Path
  if (-not (Test-Path -LiteralPath $directory)) {
    New-Item -ItemType Directory -Path $directory -Force | Out-Null
  }

  $json = ($Object | ConvertTo-Json -Depth 100) -replace "`r`n", "`n"
  if (-not $json.EndsWith("`n")) {
    $json += "`n"
  }
  [System.IO.File]::WriteAllText($Path, $json, [System.Text.UTF8Encoding]::new($false))
}

function Safe-PSObjectProperties {
  param([object]$Object)

  if ($null -eq $Object) {
    return @()
  }

  return @($Object.PSObject.Properties)
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
    if ($null -ne $property -and $null -ne $property.Value -and "$($property.Value)" -ne "") {
      return $property.Value
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

function Safe-Count {
  param([object]$Value)

  return @(As-Array $Value).Count
}

function Normalize-Status {
  param([object]$RawStatus)

  if ($null -eq $RawStatus) {
    return "unknown"
  }

  $status = "$RawStatus".Trim().ToLowerInvariant()
  if ($status -match "^(complete|completed|done|pass|passed|local pass|runtime pass|hosted pass)$") {
    return "completed"
  }
  if ($status -match "^(active|in_progress|running|current)$") {
    return "active"
  }
  if ($status -match "^(candidate|prepared|prepared, not run|claimed|codex claimed, proof required)$") {
    return "candidate"
  }
  if ($status -match "^(planned|pending|queued|todo)$") {
    return "planned"
  }
  if ($status -match "(fail|failed|blocked|partial|error|stop)") {
    return "failed"
  }
  if ($status -eq "missing_surface") {
    return "missing_surface"
  }
  if ($status -eq "proven") {
    return "proven"
  }

  return "unknown"
}

function Normalize-Key {
  param([object]$Value)

  if ($null -eq $Value) {
    return ""
  }

  return (("$Value").ToLowerInvariant() -replace "[^a-z0-9]+", "_").Trim("_")
}

function Get-FileEntries {
  param([string]$RelativePath)

  $directory = Join-RepoPath $RelativePath
  if (-not (Test-Path -LiteralPath $directory)) {
    return @()
  }

  return @(
    Get-ChildItem -LiteralPath $directory -Recurse -File -ErrorAction SilentlyContinue |
      Sort-Object FullName |
      ForEach-Object {
        [pscustomobject]@{
          path = ConvertTo-RepoPath $_.FullName
          name = $_.Name
          extension = $_.Extension
          bytes = $_.Length
          last_write_time_utc = $_.LastWriteTimeUtc.ToString("o")
        }
      }
  )
}

function Get-SurfaceStatus {
  param(
    [string]$Path,
    [string]$Area,
    [string]$Kind
  )

  $fullPath = Join-RepoPath $Path
  $exists = Test-Path -LiteralPath $fullPath
  return [pscustomobject]@{
    path = ($Path -replace "\\", "/")
    area = $Area
    kind = $Kind
    status = $(if ($exists) { "proven" } else { "missing_surface" })
  }
}

function Get-RoadmapEntries {
  param(
    [object]$Node,
    [string]$SourcePath = "CAPABILITY_ROADMAP.json"
  )

  $entries = @()
  if ($null -eq $Node) {
    return $entries
  }

  if ($Node -is [System.Array]) {
    foreach ($item in $Node) {
      $entries += Get-RoadmapEntries -Node $item -SourcePath $SourcePath
    }
    return $entries
  }

  if ($Node -isnot [pscustomobject]) {
    return $entries
  }

  $id = Get-PropertyValue -Object $Node -Names @("id", "capability_id", "capability", "name")
  $status = Get-PropertyValue -Object $Node -Names @("status", "state", "phase_status")
  $gate = Get-PropertyValue -Object $Node -Names @("gate", "validator_gate", "capability_gate")
  $phase = Get-PropertyValue -Object $Node -Names @("phase", "phase_id", "phase_name")

  if ($null -ne $id -and "$id" -ne "") {
    $entries += [pscustomobject]@{
      id = "$id"
      phase = $(if ($null -ne $phase) { "$phase" } else { $null })
      gate = $(if ($null -ne $gate) { "$gate" } else { $null })
      status = Normalize-Status $status
      raw_status = $(if ($null -ne $status) { "$status" } else { $null })
      source_path = $SourcePath
    }
  }

  foreach ($property in (Safe-PSObjectProperties $Node)) {
    if ($property.Value -is [pscustomobject] -or $property.Value -is [System.Array]) {
      $entries += Get-RoadmapEntries -Node $property.Value -SourcePath $SourcePath
    }
  }

  return $entries
}

function Select-UniqueEntries {
  param([object[]]$Entries)

  $seen = @{}
  $unique = @()
  foreach ($entry in $Entries) {
    $key = "$(Normalize-Key $entry.phase)|$(Normalize-Key $entry.id)|$(Normalize-Key $entry.gate)"
    if (-not $seen.ContainsKey($key)) {
      $seen[$key] = $true
      $unique += $entry
    }
  }

  return $unique
}

function Find-EvidencePaths {
  param(
    [string]$Id,
    [string]$Gate,
    [object[]]$ProofFiles,
    [object[]]$ReportFiles
  )

  $keys = @()
  foreach ($candidate in @($Id, $Gate)) {
    $normalized = Normalize-Key $candidate
    if ($normalized.Length -gt 3) {
      $keys += $normalized
    }
  }

  $matches = @()
  foreach ($file in @($ProofFiles + $ReportFiles)) {
    $pathKey = Normalize-Key $file.path
    foreach ($key in $keys) {
      if ($pathKey.Contains($key)) {
        $matches += $file.path
        break
      }
    }
  }

  return @($matches | Sort-Object -Unique)
}

function Get-AgentIdentity {
  param([object]$FileEntry)

  $fullPath = Join-RepoPath $FileEntry.path
  $agentId = [System.IO.Path]::GetFileNameWithoutExtension($FileEntry.name)
  $agentKind = $null
  $parseStatus = "unknown"

  if ($FileEntry.extension -ieq ".json") {
    $json = Read-JsonFile $fullPath
    if ($null -ne $json -and $null -eq (Get-PropertyValue -Object $json -Names @("parse_error"))) {
      $jsonAgentId = Get-PropertyValue -Object $json -Names @("agent_id", "id", "name", "target_agent_id", "normalized_target_agent_id")
      $jsonAgentKind = Get-PropertyValue -Object $json -Names @("agent_kind", "kind", "proposed_agent_kind")
      if ($null -ne $jsonAgentId) {
        $agentId = "$jsonAgentId"
      }
      if ($null -ne $jsonAgentKind) {
        $agentKind = "$jsonAgentKind"
      }
      $parseStatus = "proven"
    }
  }

  return [pscustomobject]@{
    agent_id = $agentId
    agent_kind = $agentKind
    status = "candidate"
    evidence_paths = @($FileEntry.path)
    source_path = $FileEntry.path
    parse_status = $parseStatus
  }
}

$utcNow = Get-UtcStamp
$outputRoot = Join-RepoPath "self_knowledge"
if (-not (Test-Path -LiteralPath $outputRoot)) {
  New-Item -ItemType Directory -Path $outputRoot -Force | Out-Null
}

$roadmapPath = Join-RepoPath "CAPABILITY_ROADMAP.json"
$genesisPath = Join-RepoPath "GENESIS_STATE.json"
$queuePath = Join-RepoPath "TASK_QUEUE.json"
$packRegistryPath = Join-RepoPath "packs/registry.json"

$roadmap = Read-JsonFile $roadmapPath
$genesis = Read-JsonFile $genesisPath
$queue = Read-JsonFile $queuePath
$packRegistry = Read-JsonFile $packRegistryPath

$proofFiles = Get-FileEntries "proofs"
$reportFiles = Get-FileEntries "reports"
$moduleFiles = Get-FileEntries "modules"
$validatorFiles = Get-FileEntries "validators"
$contractFiles = Get-FileEntries "contracts"
$workflowFiles = Get-FileEntries ".github/workflows"
$generatedProgramFiles = Get-FileEntries "self_build_programs/generated"
$agentFiles = Get-FileEntries "agents"
$generatedAgentFiles = Get-FileEntries "generated_agents"
$appliedAgentFiles = Get-FileEntries "applied_agents"

$repoMarkers = @(
  Get-SurfaceStatus -Path "CAPABILITY_ROADMAP.json" -Area "Repo Identity" -Kind "file"
  Get-SurfaceStatus -Path "GENESIS_STATE.json" -Area "Repo Identity" -Kind "file"
  Get-SurfaceStatus -Path "TASK_QUEUE.json" -Area "Repo Identity" -Kind "file"
  Get-SurfaceStatus -Path "packs/registry.json" -Area "Repo Identity" -Kind "file"
  Get-SurfaceStatus -Path "orchestrator/run.ps1" -Area "Repo Identity" -Kind "file"
)

$surfaceStatuses = @(
  $repoMarkers
  Get-SurfaceStatus -Path "proofs" -Area "Evidence" -Kind "directory"
  Get-SurfaceStatus -Path "reports" -Area "Evidence" -Kind "directory"
  Get-SurfaceStatus -Path "agents" -Area "Produced Agents" -Kind "directory"
  Get-SurfaceStatus -Path ".github/workflows" -Area "Launch Surfaces" -Kind "directory"
  Get-SurfaceStatus -Path "self_build_programs/generated" -Area "Generated Programs" -Kind "directory"
  Get-SurfaceStatus -Path "applied_agents" -Area "Produced Agents" -Kind "directory"
  Get-SurfaceStatus -Path "generated_agents" -Area "Produced Agents" -Kind "directory"
  Get-SurfaceStatus -Path "modules" -Area "Runtime Modules" -Kind "directory"
  Get-SurfaceStatus -Path "validators" -Area "Validators" -Kind "directory"
  Get-SurfaceStatus -Path "contracts" -Area "Contracts" -Kind "directory"
  Get-SurfaceStatus -Path "self_knowledge" -Area "Self-Knowledge System" -Kind "directory"
  Get-SurfaceStatus -Path "contracts/self_knowledge" -Area "Self-Knowledge System" -Kind "directory"
  Get-SurfaceStatus -Path "reports/self_knowledge" -Area "Self-Knowledge System" -Kind "directory"
  Get-SurfaceStatus -Path "proofs/self_knowledge" -Area "Self-Knowledge System" -Kind "directory"
  Get-SurfaceStatus -Path "operations" -Area "Operation System" -Kind "directory"
  Get-SurfaceStatus -Path "operation_registry.json" -Area "Operation System" -Kind "file"
  Get-SurfaceStatus -Path "contracts/operation.schema.json" -Area "Operation System" -Kind "file"
  Get-SurfaceStatus -Path "reports/operations" -Area "Operation System" -Kind "directory"
  Get-SurfaceStatus -Path "proofs/operations" -Area "Operation System" -Kind "directory"
  Get-SurfaceStatus -Path "agent_intents" -Area "Blueprint Compiler" -Kind "directory"
  Get-SurfaceStatus -Path "blueprints" -Area "Blueprint Compiler" -Kind "directory"
  Get-SurfaceStatus -Path "contracts/blueprint.schema.json" -Area "Blueprint Compiler" -Kind "file"
  Get-SurfaceStatus -Path "templates/agent_blueprint" -Area "Blueprint Compiler" -Kind "directory"
  Get-SurfaceStatus -Path "reports/blueprint_compiler" -Area "Blueprint Compiler" -Kind "directory"
  Get-SurfaceStatus -Path "proofs/blueprint_compiler" -Area "Blueprint Compiler" -Kind "directory"
)

$missingSurfaces = @($surfaceStatuses | Where-Object { $_.status -eq "missing_surface" })

$roadmapEntries = Select-UniqueEntries -Entries (Get-RoadmapEntries -Node $roadmap)
$phase78 = $roadmapEntries | Where-Object { $_.id -eq $CapabilityId -or $_.phase -eq "PHASE_78" -or $_.gate -eq $GateId } | Select-Object -First 1

$capabilities = @()
foreach ($entry in $roadmapEntries) {
  $evidencePaths = @(Find-EvidencePaths -Id $entry.id -Gate $entry.gate -ProofFiles $proofFiles -ReportFiles $reportFiles)
  $capabilities += [pscustomobject]@{
    id = $entry.id
    phase = $entry.phase
    gate = $entry.gate
    status = $entry.status
    raw_status = $entry.raw_status
    evidence_status = $(if ((Safe-Count $evidencePaths) -gt 0) { "proven" } else { "unknown" })
    evidence_paths = @(As-Array $evidencePaths)
    source_path = $entry.source_path
  }
}

$currentCapability = Get-PropertyValue -Object $genesis -Names @("current_capability", "capability", "active_capability")
$completedCapabilities = As-Array (Get-PropertyValue -Object $genesis -Names @("completed_capabilities", "completedCapabilities"))
$selfBuildReady = Get-PropertyValue -Object $genesis -Names @("SELF_BUILD_READY", "self_build_ready")
$activeTaskId = Get-PropertyValue -Object $queue -Names @("active_task_id", "activeTaskId")
if ($null -eq $activeTaskId -or "$activeTaskId" -eq "") {
  $activeTaskId = "UNKNOWN"
}

$capabilityCounts = [ordered]@{
  total = @($capabilities).Count
  completed = @($capabilities | Where-Object { $_.status -eq "completed" }).Count
  active = @($capabilities | Where-Object { $_.status -eq "active" }).Count
  candidate = @($capabilities | Where-Object { $_.status -eq "candidate" }).Count
  planned = @($capabilities | Where-Object { $_.status -eq "planned" }).Count
  failed = @($capabilities | Where-Object { $_.status -eq "failed" }).Count
  proven_by_evidence_file = @($capabilities | Where-Object { $_.evidence_status -eq "proven" }).Count
  unknown = @($capabilities | Where-Object { $_.status -eq "unknown" }).Count
}

$capabilityManifest = [ordered]@{
  schema_version = "AGENT_BUILDER_CAPABILITY_MANIFEST_V1"
  generated_at_utc = $utcNow
  collection_status = "collected"
  source_files = @("CAPABILITY_ROADMAP.json", "GENESIS_STATE.json", "proofs/", "reports/")
  capabilities = @($capabilities | Sort-Object phase, id)
  counts = $capabilityCounts
  evidence_policy = [ordered]@{
    no_proof_claim_without_file = $true
    completed_from_roadmap_requires_state_entry = $true
    proven_requires_existing_proof_or_report_path = $true
  }
}

$packDirectories = @()
if (Test-Path -LiteralPath (Join-RepoPath "packs")) {
  $packDirectories = @(
    Get-ChildItem -LiteralPath (Join-RepoPath "packs") -Directory -ErrorAction SilentlyContinue |
      Sort-Object FullName |
      ForEach-Object {
        [pscustomobject]@{
          path = ConvertTo-RepoPath $_.FullName
          name = $_.Name
          status = "candidate"
        }
      }
  )
}

$moduleInventory = [ordered]@{
  schema_version = "AGENT_BUILDER_MODULE_INVENTORY_V1"
  generated_at_utc = $utcNow
  collection_status = "collected"
  modules = $moduleFiles
  validators = $validatorFiles
  contracts = $contractFiles
  packs = $packDirectories
  workflows = $workflowFiles
  counts = [ordered]@{
    modules = @($moduleFiles).Count
    validators = @($validatorFiles).Count
    contracts = @($contractFiles).Count
    packs = @($packDirectories).Count
    workflows = @($workflowFiles).Count
  }
  missing_surfaces = @($missingSurfaces | Where-Object { $_.area -in @("Runtime Modules", "Validators", "Contracts", "Launch Surfaces") })
}

$evidenceIndex = [ordered]@{
  schema_version = "AGENT_BUILDER_EVIDENCE_INDEX_V1"
  generated_at_utc = $utcNow
  collection_status = "collected"
  proofs = $proofFiles
  reports = $reportFiles
  counts = [ordered]@{
    proofs = @($proofFiles).Count
    reports = @($reportFiles).Count
  }
  missing_surfaces = @($missingSurfaces | Where-Object { $_.area -eq "Evidence" })
  evidence_policy = [ordered]@{
    no_proof_claim_without_file = $true
    proof_index_is_file_inventory = $true
    report_index_is_file_inventory = $true
  }
}

$producedAgentSourceSurfaces = @(
  Get-SurfaceStatus -Path "agents" -Area "Produced Agents" -Kind "directory"
  Get-SurfaceStatus -Path "generated_agents" -Area "Produced Agents" -Kind "directory"
  Get-SurfaceStatus -Path "applied_agents" -Area "Produced Agents" -Kind "directory"
  Get-SurfaceStatus -Path "self_build_programs/generated" -Area "Generated Programs" -Kind "directory"
)
$producedAgentFiles = @($agentFiles + $generatedAgentFiles + $appliedAgentFiles + $generatedProgramFiles)
$producedAgents = @()
foreach ($file in $producedAgentFiles) {
  $producedAgents += Get-AgentIdentity -FileEntry $file
}

$producedAgentsIndex = [ordered]@{
  schema_version = "AGENT_BUILDER_PRODUCED_AGENTS_INDEX_V1"
  generated_at_utc = $utcNow
  collection_status = "collected"
  produced_agents = @($producedAgents | Sort-Object agent_id, source_path)
  source_surfaces = $producedAgentSourceSurfaces
  counts = [ordered]@{
    produced_agents = @($producedAgents).Count
    source_surfaces = @($producedAgentSourceSurfaces).Count
    missing_source_surfaces = @($producedAgentSourceSurfaces | Where-Object { $_.status -eq "missing_surface" }).Count
  }
  missing_surfaces = @($producedAgentSourceSurfaces | Where-Object { $_.status -eq "missing_surface" })
}

$queueClean = $false
if ("$activeTaskId" -eq "NONE") {
  $queueClean = $true
}

$roadmapSummary = [ordered]@{
  source_path = "CAPABILITY_ROADMAP.json"
  phase_78 = $(if ($null -ne $phase78) { $phase78 } else { [pscustomobject]@{ id = $CapabilityId; phase = "PHASE_78"; gate = $GateId; status = "missing_surface" } })
  counts = $capabilityCounts
  latest_active = @($capabilities | Where-Object { $_.status -eq "active" } | Select-Object -Last 5)
  latest_completed = @($capabilities | Where-Object { $_.status -eq "completed" } | Select-Object -Last 5)
}

$roadmapState = [ordered]@{
  schema_version = "AGENT_BUILDER_ROADMAP_STATE_V1"
  generated_at_utc = $utcNow
  collection_status = "collected"
  current_capability = $(if ($null -ne $currentCapability) { "$currentCapability" } else { "unknown" })
  active_task_id = "$activeTaskId"
  queue_clean = $queueClean
  phase_78 = $roadmapSummary.phase_78
  roadmap_summary = $roadmapSummary
}

$failedOrPartial = @(
  $capabilities |
    Where-Object { $_.status -eq "failed" -or "$($_.raw_status)" -match "(partial|blocked|fail|stop)" } |
    Sort-Object phase, id
)

$operationMissing = @($missingSurfaces | Where-Object { $_.area -eq "Operation System" })
$blueprintMissing = @($missingSurfaces | Where-Object { $_.area -eq "Blueprint Compiler" })

$nextRecommendation = "Complete PHASE78 self-knowledge validation and proof generation."
$nextStatus = "active"
$nextBasis = @("PHASE78 is the active self-development capability target.")
if ($queueClean -and @($operationMissing).Count -gt 0) {
  $nextRecommendation = "After PHASE78 is proven, define the Operation System as a full contract rather than marking it complete."
  $nextStatus = "candidate"
  $nextBasis = @("Operation System surfaces are missing and must remain missing_surface until created and proven.")
}
if (-not $queueClean) {
  $nextRecommendation = "Finish the active queue task before opening another capability line."
  $nextStatus = "active"
  $nextBasis = @("TASK_QUEUE.json active_task_id is $activeTaskId.")
}

$launchSurfaces = @(
  Get-SurfaceStatus -Path "orchestrator/run.ps1" -Area "Launch Surfaces" -Kind "file"
  Get-SurfaceStatus -Path "packs/registry.json" -Area "Launch Surfaces" -Kind "file"
  Get-SurfaceStatus -Path "packs" -Area "Launch Surfaces" -Kind "directory"
  Get-SurfaceStatus -Path ".github/workflows" -Area "Launch Surfaces" -Kind "directory"
)

$selfModel = [ordered]@{
  schema_version = $SchemaVersion
  generated_at_utc = $utcNow
  collection_status = "collected"
  status_taxonomy = $StatusTaxonomy
  builder_identity = [ordered]@{
    system = "Agent Builder"
    repo_name = Split-Path -Leaf $RepoRoot
    repo_root = (ConvertTo-RepoPath $RepoRoot)
    active_line = "AGENT_BUILDER_SELF_DEVELOPMENT"
    active_mode = "SELF_BUILD"
    product_target = "Build a verified operating contour first, then build other agents from formal specs."
  }
  repo_markers = $repoMarkers
  current_state = [ordered]@{
    source_path = "GENESIS_STATE.json"
    current_capability = $(if ($null -ne $currentCapability) { "$currentCapability" } else { "unknown" })
    completed_capabilities_count = @($completedCapabilities).Count
    self_build_ready = $(if ($null -ne $selfBuildReady) { "$selfBuildReady" } else { "unknown" })
  }
  queue_state = [ordered]@{
    source_path = "TASK_QUEUE.json"
    active_task_id = "$activeTaskId"
    clean = $queueClean
  }
  roadmap_summary = $roadmapSummary
  capability_manifest = $capabilityManifest
  module_inventory = $moduleInventory
  generated_programs = $generatedProgramFiles
  produced_agents = $producedAgentsIndex.produced_agents
  launch_surfaces = $launchSurfaces
  proof_index = $proofFiles
  report_index = $reportFiles
  missing_surfaces = $missingSurfaces
  failed_or_partial_items = $failedOrPartial
  next_strongest_move = [ordered]@{
    status = $nextStatus
    recommendation = $nextRecommendation
    basis = $nextBasis
  }
  cut_list = @(
    [pscustomobject]@{
      item = "Do not mark Operation System complete while operations/, operation_registry.json, reports/operations/, and proofs/operations/ are missing."
      status = "planned"
    }
    [pscustomobject]@{
      item = "Do not mark Blueprint Compiler complete while agent_intents/, blueprints/, templates/agent_blueprint/, reports/blueprint_compiler/, and proofs/blueprint_compiler/ are missing."
      status = "planned"
    }
    [pscustomobject]@{
      item = "Do not generate an external agent directly from this phase."
      status = "planned"
    }
  )
  evidence_policy = [ordered]@{
    no_proof_claim_without_file = $true
    state_files_require_validation_evidence = $true
    missing_directories_are_recorded_as_missing_surface = $true
    chat_is_not_source_of_truth = $true
    proof_and_report_paths_are_inventory_claims_only = $true
  }
}

Write-JsonFile -Path (Join-RepoPath "self_knowledge/CAPABILITY_MANIFEST.json") -Object $capabilityManifest
Write-JsonFile -Path (Join-RepoPath "self_knowledge/MODULE_INVENTORY.json") -Object $moduleInventory
Write-JsonFile -Path (Join-RepoPath "self_knowledge/EVIDENCE_INDEX.json") -Object $evidenceIndex
Write-JsonFile -Path (Join-RepoPath "self_knowledge/PRODUCED_AGENTS_INDEX.json") -Object $producedAgentsIndex
Write-JsonFile -Path (Join-RepoPath "self_knowledge/ROADMAP_STATE.json") -Object $roadmapState
Write-JsonFile -Path (Join-RepoPath "self_knowledge/BUILDER_SELF_MODEL.json") -Object $selfModel

Write-Host "SELF_KNOWLEDGE_BUILD=PASS"
Write-Host "OUTPUT=self_knowledge/BUILDER_SELF_MODEL.json"
