[CmdletBinding()]
param(
  [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path,
  [string]$RunId = "AGENT_BUILDER_SELF_KNOWLEDGE_SYSTEM_FULL_CONTRACT_V1_001",
  [switch]$InvokedByOrchestrator
)

$ErrorActionPreference = "Stop"

$CapabilityId = "agent_builder_self_knowledge_system_full_contract_v1"
$PackId = "PHASE78_AGENT_BUILDER_SELF_KNOWLEDGE_SYSTEM_FULL_CONTRACT_V1"
$GateId = "AGENT_BUILDER_SELF_KNOWLEDGE_SYSTEM_FULL_CONTRACT_V1"
$TaskId = "TASK_AGENT_BUILDER_SELF_KNOWLEDGE_SYSTEM_FULL_CONTRACT_V1_001"
$ActiveLine = "AGENT_BUILDER_SELF_DEVELOPMENT"
$Mode = "SELF_BUILD"
$ProofPath = "proofs/self_knowledge/AGENT_BUILDER_SELF_KNOWLEDGE_SYSTEM_FULL_CONTRACT_V1.json"

function Join-RepoPath {
  param([string]$Path)
  return [System.IO.Path]::GetFullPath((Join-Path $RepoRoot $Path))
}

function Get-UtcStamp {
  return (Get-Date).ToUniversalTime().ToString("o")
}

function Read-JsonRequired {
  param([string]$Path)

  $fullPath = Join-RepoPath $Path
  if (-not (Test-Path -LiteralPath $fullPath)) {
    throw "STOP=WRONG_AGENT_BUILDER_REPO missing $Path"
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

  $property = Safe-PSObjectProperties $Object | Where-Object { $_.Name -ieq $Name } | Select-Object -First 1
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

function Safe-Count {
  param([object]$Value)

  return @(As-Array $Value).Count
}

function New-PhaseEntry {
  param([string]$Status)

  return [pscustomobject][ordered]@{
    phase = "PHASE_78"
    id = $CapabilityId
    status = $Status
    gate = $GateId
  }
}

function Ensure-RoadmapPhase {
  param(
    [object]$Roadmap,
    [string]$Status
  )

  $topLevelPhase = Get-PropertyValue -Object $Roadmap -Names @("PHASE_78")
  if ($topLevelPhase -is [pscustomobject]) {
    Set-PropertyValue -Object $topLevelPhase -Name "phase" -Value "PHASE_78"
    Set-PropertyValue -Object $topLevelPhase -Name "id" -Value $CapabilityId
    Set-PropertyValue -Object $topLevelPhase -Name "status" -Value $Status
    Set-PropertyValue -Object $topLevelPhase -Name "gate" -Value $GateId
  }

  $containerProperty = Safe-PSObjectProperties $Roadmap | Where-Object { $_.Name -in @("phases", "capabilities", "roadmap") } | Select-Object -First 1
  if ($null -eq $containerProperty) {
    Set-PropertyValue -Object $Roadmap -Name "phases" -Value @()
    $containerProperty = Safe-PSObjectProperties $Roadmap | Where-Object { $_.Name -eq "phases" } | Select-Object -First 1
  }

  $container = $containerProperty.Value
  if ($container -is [pscustomobject]) {
    $phaseObject = Get-PropertyValue -Object $container -Names @("PHASE_78")
    if ($null -eq $phaseObject) {
      $phaseObject = [pscustomobject]@{}
      Set-PropertyValue -Object $container -Name "PHASE_78" -Value $phaseObject
    }
    Set-PropertyValue -Object $phaseObject -Name "phase" -Value "PHASE_78"
    Set-PropertyValue -Object $phaseObject -Name "id" -Value $CapabilityId
    Set-PropertyValue -Object $phaseObject -Name "status" -Value $Status
    Set-PropertyValue -Object $phaseObject -Name "gate" -Value $GateId
    return
  }

  $items = As-Array $container
  $found = $false
  foreach ($item in $items) {
    if ($item -is [pscustomobject]) {
      $id = Get-PropertyValue -Object $item -Names @("id", "capability_id", "capability")
      $phase = Get-PropertyValue -Object $item -Names @("phase", "phase_id", "phase_name")
      $gate = Get-PropertyValue -Object $item -Names @("gate", "validator_gate", "capability_gate")
      if ("$id" -eq $CapabilityId -or "$phase" -eq "PHASE_78" -or "$gate" -eq $GateId) {
        Set-PropertyValue -Object $item -Name "phase" -Value "PHASE_78"
        Set-PropertyValue -Object $item -Name "id" -Value $CapabilityId
        Set-PropertyValue -Object $item -Name "status" -Value $Status
        Set-PropertyValue -Object $item -Name "gate" -Value $GateId
        $found = $true
      }
    }
  }

  if (-not $found) {
    $items += New-PhaseEntry -Status $Status
  }

  Set-PropertyValue -Object $Roadmap -Name $containerProperty.Name -Value @($items)
}

function Ensure-GenesisState {
  param(
    [object]$Genesis,
    [bool]$Completed
  )

  Set-PropertyValue -Object $Genesis -Name "current_capability" -Value $CapabilityId

  if ($Completed) {
    $completedCapabilities = As-Array (Get-PropertyValue -Object $Genesis -Names @("completed_capabilities", "completedCapabilities"))
    if ($completedCapabilities -notcontains $CapabilityId) {
      $completedCapabilities += $CapabilityId
    }
    Set-PropertyValue -Object $Genesis -Name "completed_capabilities" -Value @($completedCapabilities)
  }
}

function New-TaskEntry {
  param([string]$Status)

  return [pscustomobject][ordered]@{
    task_id = $TaskId
    status = $Status
    active_line = $ActiveLine
    mode = $Mode
    capability_id = $CapabilityId
    phase = "PHASE_78"
    gate = $GateId
    pack_id = $PackId
    objective = "Seed and execute Agent Builder Self-Knowledge System full contract."
  }
}

function Ensure-TaskQueue {
  param(
    [object]$TaskQueue,
    [string]$Status,
    [string]$ActiveTaskId
  )

  Set-PropertyValue -Object $TaskQueue -Name "active_task_id" -Value $ActiveTaskId

  $topLevelTask = Get-PropertyValue -Object $TaskQueue -Names @("phase78_active_task_entry")
  if ($topLevelTask -is [pscustomobject]) {
    foreach ($property in (Safe-PSObjectProperties (New-TaskEntry -Status $Status))) {
      Set-PropertyValue -Object $topLevelTask -Name $property.Name -Value $property.Value
    }
    Set-PropertyValue -Object $topLevelTask -Name "path" -Value "tasks/TASK_AGENT_BUILDER_SELF_KNOWLEDGE_SYSTEM_FULL_CONTRACT_V1_001.json"
  }

  $tasks = As-Array (Get-PropertyValue -Object $TaskQueue -Names @("tasks"))
  $found = $false
  foreach ($task in $tasks) {
    if ($task -is [pscustomobject]) {
      $id = Get-PropertyValue -Object $task -Names @("task_id", "id")
      if ("$id" -eq $TaskId) {
        Set-PropertyValue -Object $task -Name "task_id" -Value $TaskId
        Set-PropertyValue -Object $task -Name "status" -Value $Status
        Set-PropertyValue -Object $task -Name "active_line" -Value $ActiveLine
        Set-PropertyValue -Object $task -Name "mode" -Value $Mode
        Set-PropertyValue -Object $task -Name "capability_id" -Value $CapabilityId
        Set-PropertyValue -Object $task -Name "phase" -Value "PHASE_78"
        Set-PropertyValue -Object $task -Name "gate" -Value $GateId
        Set-PropertyValue -Object $task -Name "pack_id" -Value $PackId
        $found = $true
      }
    }
  }

  if (-not $found) {
    $tasks += New-TaskEntry -Status $Status
  }

  Set-PropertyValue -Object $TaskQueue -Name "tasks" -Value @($tasks)
}

function New-PackRegistryEntry {
  param([string]$Status)

  return [pscustomobject][ordered]@{
    pack_id = $PackId
    capability_id = $CapabilityId
    phase = "PHASE_78"
    gate = $GateId
    status = $Status
    active_line = $ActiveLine
    mode = $Mode
    path = "packs/$PackId"
    task_id = $TaskId
    pack_contract_path = "packs/$PackId/PACK.json"
    entry_script = "packs/$PackId/APPLY.ps1"
    shell = "PowerShell"
    apply = "APPLY.ps1"
    validate = "VALIDATE.ps1"
  }
}

function Ensure-PackRegistry {
  param(
    [object]$Registry,
    [string]$Status
  )

  $topLevelPack = Get-PropertyValue -Object $Registry -Names @($PackId)
  if ($topLevelPack -is [pscustomobject]) {
    foreach ($property in (Safe-PSObjectProperties (New-PackRegistryEntry -Status $Status))) {
      Set-PropertyValue -Object $topLevelPack -Name $property.Name -Value $property.Value
    }
  }

  $packsProperty = Safe-PSObjectProperties $Registry | Where-Object { $_.Name -in @("packs", "registry") } | Select-Object -First 1
  if ($null -eq $packsProperty) {
    Set-PropertyValue -Object $Registry -Name "packs" -Value @()
    $packsProperty = Safe-PSObjectProperties $Registry | Where-Object { $_.Name -eq "packs" } | Select-Object -First 1
  }

  $container = $packsProperty.Value
  if ($container -is [pscustomobject]) {
    $entry = Get-PropertyValue -Object $container -Names @($PackId)
    if ($null -eq $entry) {
      $entry = [pscustomobject]@{}
      Set-PropertyValue -Object $container -Name $PackId -Value $entry
    }
    foreach ($property in (Safe-PSObjectProperties (New-PackRegistryEntry -Status $Status))) {
      Set-PropertyValue -Object $entry -Name $property.Name -Value $property.Value
    }
    return
  }

  $packs = As-Array $container
  $found = $false
  foreach ($pack in $packs) {
    if ($pack -is [pscustomobject]) {
      $id = Get-PropertyValue -Object $pack -Names @("pack_id", "id", "name")
      if ("$id" -eq $PackId) {
        foreach ($property in (Safe-PSObjectProperties (New-PackRegistryEntry -Status $Status))) {
          Set-PropertyValue -Object $pack -Name $property.Name -Value $property.Value
        }
        $found = $true
      }
    }
  }

  if (-not $found) {
    $packs += New-PackRegistryEntry -Status $Status
  }

  Set-PropertyValue -Object $Registry -Name $packsProperty.Name -Value @($packs)
}

function Find-PackRegistryEntry {
  param([object]$Registry)

  if ($null -eq $Registry) {
    return $null
  }

  $topLevelPack = Get-PropertyValue -Object $Registry -Names @($PackId)
  if ($topLevelPack -is [pscustomobject]) {
    return $topLevelPack
  }

  $container = Get-PropertyValue -Object $Registry -Names @("packs", "registry")
  if ($container -is [pscustomobject]) {
    return Get-PropertyValue -Object $container -Names @($PackId)
  }

  foreach ($pack in As-Array $container) {
    if ($pack -is [pscustomobject]) {
      $id = Get-PropertyValue -Object $pack -Names @("pack_id", "id", "name")
      if ("$id" -eq $PackId) {
        return $pack
      }
    }
  }

  return $null
}

function Test-PackRegistryContract {
  param([object]$Registry)

  $entry = Find-PackRegistryEntry -Registry $Registry
  if ($null -eq $entry) {
    return $false
  }

  $expected = [ordered]@{
    task_id = $TaskId
    pack_contract_path = "packs/$PackId/PACK.json"
    entry_script = "packs/$PackId/APPLY.ps1"
    shell = "PowerShell"
  }

  foreach ($key in $expected.Keys) {
    $actual = Get-PropertyValue -Object $entry -Names @($key)
    if ("$actual" -ne "$($expected[$key])") {
      return $false
    }
  }

  return $true
}

function Save-StateFiles {
  param(
    [string]$PhaseStatus,
    [string]$TaskStatus,
    [string]$ActiveTaskId,
    [bool]$Completed
  )

  $roadmap = Read-JsonRequired "CAPABILITY_ROADMAP.json"
  $genesis = Read-JsonRequired "GENESIS_STATE.json"
  $queue = Read-JsonRequired "TASK_QUEUE.json"
  $registry = Read-JsonRequired "packs/registry.json"

  Ensure-RoadmapPhase -Roadmap $roadmap -Status $PhaseStatus
  Ensure-GenesisState -Genesis $genesis -Completed $Completed
  Ensure-TaskQueue -TaskQueue $queue -Status $TaskStatus -ActiveTaskId $ActiveTaskId

  Write-JsonFile -Path "CAPABILITY_ROADMAP.json" -Object $roadmap
  Write-JsonFile -Path "GENESIS_STATE.json" -Object $genesis
  Write-JsonFile -Path "TASK_QUEUE.json" -Object $queue

  if (-not (Test-PackRegistryContract -Registry $registry)) {
    Ensure-PackRegistry -Registry $registry -Status $PhaseStatus
    Write-JsonFile -Path "packs/registry.json" -Object $registry
  }
}

function Invoke-SelfKnowledgeBuild {
  & (Join-RepoPath "modules/build_builder_self_knowledge.ps1") -RepoRoot $RepoRoot
  & (Join-RepoPath "modules/write_builder_self_describe_report.ps1") -RepoRoot $RepoRoot
}

function Invoke-Validator {
  param([string]$Stage)
  & (Join-RepoPath "packs/$PackId/VALIDATE.ps1") -RepoRoot $RepoRoot -Stage $Stage
}

function Write-Proof {
  param(
    [string]$Status,
    [string[]]$ValidationStages
  )

  $proof = [ordered]@{
    proof_id = $GateId
    capability_id = $CapabilityId
    phase = "PHASE_78"
    pack_id = $PackId
    task_id = $TaskId
    status = $Status
    generated_at_utc = Get-UtcStamp
    validation_stages = $ValidationStages
    outputs = @(
      "self_knowledge/BUILDER_SELF_MODEL.json",
      "self_knowledge/CAPABILITY_MANIFEST.json",
      "self_knowledge/MODULE_INVENTORY.json",
      "self_knowledge/EVIDENCE_INDEX.json",
      "self_knowledge/PRODUCED_AGENTS_INDEX.json",
      "self_knowledge/ROADMAP_STATE.json",
      "reports/self_knowledge/BUILDER_SELF_DESCRIBE_REPORT.json",
      "reports/self_knowledge/BUILDER_SELF_DESCRIBE_SUMMARY.md"
    )
    forbidden_drift_checks = [ordered]@{
      operation_system_not_marked_completed = $true
      blueprint_compiler_not_marked_completed = $true
      no_external_agent_created = $true
      orchestrator_not_modified_by_pack = $true
    }
    evidence_policy = [ordered]@{
      no_proof_claim_without_file = $true
      proof_written_by_apply_after_validation = $true
      task_closed_only_after_validation = $true
    }
  }

  Write-JsonFile -Path $ProofPath -Object $proof
}

function Capture-StateFileSnapshots {
  $snapshots = @{}
  foreach ($path in @("CAPABILITY_ROADMAP.json", "GENESIS_STATE.json", "TASK_QUEUE.json", "packs/registry.json")) {
    $fullPath = Join-RepoPath $path
    if (Test-Path -LiteralPath $fullPath) {
      $snapshots[$path] = [System.IO.File]::ReadAllBytes($fullPath)
    }
  }

  return $snapshots
}

function Restore-StateFileSnapshots {
  param([hashtable]$Snapshots)

  foreach ($path in $Snapshots.Keys) {
    $fullPath = Join-RepoPath $path
    [System.IO.File]::WriteAllBytes($fullPath, [byte[]]$Snapshots[$path])
  }
}

function Write-FailureDiagnostic {
  param(
    [object]$ErrorRecord,
    [string]$Stage,
    [bool]$StateRestored
  )

  $diagnosticPath = "reports/phase78/PHASE78_FAILURE_DIAGNOSTIC.json"
  $diagnostic = [ordered]@{
    diagnostic_id = "PHASE78_FAILURE_DIAGNOSTIC"
    status = "FAIL"
    generated_at_utc = Get-UtcStamp
    run_id = $RunId
    invoked_by_orchestrator = [bool]$InvokedByOrchestrator
    stage = $Stage
    state_restored = $StateRestored
    error_message = "$($ErrorRecord.Exception.Message)"
    script_stack = "$($ErrorRecord.ScriptStackTrace)"
    protected_state_files = @(
      "CAPABILITY_ROADMAP.json",
      "GENESIS_STATE.json",
      "TASK_QUEUE.json",
      "packs/registry.json"
    )
  }

  Write-JsonFile -Path $diagnosticPath -Object $diagnostic
  Write-Host "FAILURE_DIAGNOSTIC=$diagnosticPath"
}

Write-Host "PHASE78_APPLY=START"

$markers = @(
  "CAPABILITY_ROADMAP.json",
  "GENESIS_STATE.json",
  "TASK_QUEUE.json",
  "packs/registry.json",
  "orchestrator/run.ps1"
)
foreach ($marker in $markers) {
  if (-not (Test-Path -LiteralPath (Join-RepoPath $marker))) {
    throw "STOP=WRONG_AGENT_BUILDER_REPO missing $marker"
  }
}
Write-Host "REPO_IDENTITY_GATE=PASS"

$directories = @(
  "contracts/self_knowledge",
  "self_knowledge",
  "reports/self_knowledge",
  "reports/phase78",
  "proofs/self_knowledge",
  "tasks",
  "packs/$PackId"
)
foreach ($directory in $directories) {
  $fullPath = Join-RepoPath $directory
  if (-not (Test-Path -LiteralPath $fullPath)) {
    New-Item -ItemType Directory -Path $fullPath -Force | Out-Null
  }
}

$stateSnapshots = Capture-StateFileSnapshots
$script:Phase78Stage = "STATE_SNAPSHOT_CAPTURED"

try {
  $script:Phase78Stage = "SET_ACTIVE_STATE"
  Save-StateFiles -PhaseStatus "ACTIVE" -TaskStatus "ACTIVE" -ActiveTaskId $TaskId -Completed $false

  $script:Phase78Stage = "BUILD_SELF_KNOWLEDGE_PRE_COMPLETION"
  Invoke-SelfKnowledgeBuild

  $script:Phase78Stage = "VALIDATE_PRE_COMPLETION"
  Invoke-Validator -Stage "PreCompletion"

  $script:Phase78Stage = "WRITE_PRE_COMPLETION_PROOF"
  Write-Proof -Status "LOCAL PASS" -ValidationStages @("PreCompletion")

  $script:Phase78Stage = "SET_COMPLETED_STATE"
  Save-StateFiles -PhaseStatus "COMPLETED" -TaskStatus "COMPLETED" -ActiveTaskId "NONE" -Completed $true

  $script:Phase78Stage = "BUILD_SELF_KNOWLEDGE_COMPLETED"
  Invoke-SelfKnowledgeBuild

  $script:Phase78Stage = "VALIDATE_COMPLETED"
  Invoke-Validator -Stage "Completed"

  $script:Phase78Stage = "WRITE_COMPLETED_PROOF"
  Write-Proof -Status "LOCAL PASS" -ValidationStages @("PreCompletion", "Completed")

  $script:Phase78Stage = "REBUILD_SELF_KNOWLEDGE_WITH_PROOF_INDEX"
  Invoke-SelfKnowledgeBuild

  $script:Phase78Stage = "FINAL_VALIDATE_COMPLETED"
  Invoke-Validator -Stage "Completed"

  Write-Host "PHASE78_APPLY=PASS"
  Write-Host "COMMIT_PUSH=NOT_ATTEMPTED_NO_PACK_CONVENTION_ASSUMED"
} catch {
  Restore-StateFileSnapshots -Snapshots $stateSnapshots
  Write-FailureDiagnostic -ErrorRecord $_ -Stage $script:Phase78Stage -StateRestored $true
  Write-Host "PHASE78_APPLY=FAIL"
  throw
}
