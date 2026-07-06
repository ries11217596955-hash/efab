[CmdletBinding()]
param(
  [ValidateSet("Auto", "Seed", "Completed")]
  [string]$Stage = "Auto",
  [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
)

$ErrorActionPreference = "Stop"

$TaskId = "TASK_OWNER_ORDER_TO_GAP_MAP_V1_001"
$PackId = "PHASE94_OWNER_ORDER_TO_GAP_MAP_V1"
$EntryScript = "packs/PHASE94_OWNER_ORDER_TO_GAP_MAP_V1/APPLY.ps1"
$NextAllowedStep = "PHASE95_SELF_BUILD_PROGRAM_GENERATOR_V2"
$script:Failures = @()

function Join-RepoPath {
  param([string]$Path)

  if ([System.IO.Path]::IsPathRooted($Path)) {
    return [System.IO.Path]::GetFullPath($Path)
  }
  return [System.IO.Path]::GetFullPath((Join-Path $RepoRoot $Path))
}

function Add-Failure {
  param([string]$Message)
  $script:Failures += $Message
}

function Read-JsonFile {
  param([string]$Path)

  $fullPath = Join-RepoPath $Path
  if (-not (Test-Path -LiteralPath $fullPath)) {
    Add-Failure "MISSING_JSON=$Path"
    return $null
  }
  try {
    return (Get-Content -LiteralPath $fullPath -Raw | ConvertFrom-Json)
  } catch {
    Add-Failure "INVALID_JSON=$Path :: $($_.Exception.Message)"
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

function Assert-FileExists {
  param([string]$Path)

  if (-not (Test-Path -LiteralPath (Join-RepoPath $Path))) {
    Add-Failure "MISSING_FILE=$Path"
  }
}

function Assert-FileAbsent {
  param([string]$Path)

  if (Test-Path -LiteralPath (Join-RepoPath $Path)) {
    Add-Failure "UNEXPECTED_FILE=$Path"
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

function Resolve-Stage {
  param([string]$RequestedStage)

  if ($RequestedStage -ne "Auto") {
    return $RequestedStage
  }
  $queue = Read-JsonFile "TASK_QUEUE.json"
  if ("$(Get-PropertyValue -Object $queue -Name "active_task_id")" -eq $TaskId) {
    return "Seed"
  }
  return "Completed"
}

$Stage = Resolve-Stage -RequestedStage $Stage
Write-Host "VALIDATION_STAGE=$Stage"

foreach ($marker in @("CAPABILITY_ROADMAP.json", "GENESIS_STATE.json", "TASK_QUEUE.json", "packs/registry.json", "orchestrator/run.ps1")) {
  Assert-FileExists $marker
}

foreach ($path in @(
  "modules/self_development/write_owner_order_to_gap_map_v1.ps1",
  "packs/PHASE94_OWNER_ORDER_TO_GAP_MAP_V1/PACK.json",
  "packs/PHASE94_OWNER_ORDER_TO_GAP_MAP_V1/APPLY.ps1",
  "packs/PHASE94_OWNER_ORDER_TO_GAP_MAP_V1/VALIDATE.ps1",
  "tasks/TASK_OWNER_ORDER_TO_GAP_MAP_V1_001.json"
)) {
  Assert-FileExists $path
}

foreach ($path in @(
  "packs/PHASE94_OWNER_ORDER_TO_GAP_MAP_V1/PACK.json",
  "tasks/TASK_OWNER_ORDER_TO_GAP_MAP_V1_001.json",
  "TASK_QUEUE.json",
  "packs/registry.json",
  "CAPABILITY_ROADMAP.json",
  "GENESIS_STATE.json"
)) {
  Read-JsonFile $path | Out-Null
}

foreach ($script in @(
  "modules/self_development/write_owner_order_to_gap_map_v1.ps1",
  "packs/PHASE94_OWNER_ORDER_TO_GAP_MAP_V1/APPLY.ps1",
  "packs/PHASE94_OWNER_ORDER_TO_GAP_MAP_V1/VALIDATE.ps1"
)) {
  Assert-ParserPass $script
}

$phase93Proof = Read-JsonFile "proofs/self_development/CAPABILITY_GAP_DETECTOR_V1.json"
if ($null -ne $phase93Proof) {
  if ("$(Get-PropertyValue -Object $phase93Proof -Name "status")" -ne "PASS") {
    Add-Failure "PHASE93_PROOF_STATUS_NOT_PASS"
  }
  if ("$(Get-PropertyValue -Object $phase93Proof -Name "next_allowed_step")" -ne "PHASE94_OWNER_ORDER_TO_GAP_MAP_V1") {
    Add-Failure "PHASE93_PROOF_NEXT_STEP_MISMATCH"
  }
}

$queue = Read-JsonFile "TASK_QUEUE.json"
$registry = Read-JsonFile "packs/registry.json"
$task = Find-TaskEntry -Queue $queue
if ($null -eq $task) {
  Add-Failure "TASK_NOT_FOUND=$TaskId"
}
$selectedPacks = Get-MatchingRegistryPacks -Registry $registry
if (@($selectedPacks).Count -ne 1) {
  Add-Failure "REGISTRY_SELECTED_PACK_COUNT=$(@($selectedPacks).Count)"
} else {
  $selected = $selectedPacks[0]
  if ("$(Get-PropertyValue -Object $selected -Name "pack_id")" -ne $PackId) {
    Add-Failure "REGISTRY_SELECTED_PACK_ID_MISMATCH"
  }
  if ("$(Get-PropertyValue -Object $selected -Name "shell")" -ne "PowerShell") {
    Add-Failure "REGISTRY_SELECTED_SHELL_MISMATCH"
  }
  if ("$(Get-PropertyValue -Object $selected -Name "entry_script")" -ne $EntryScript) {
    Add-Failure "REGISTRY_SELECTED_ENTRY_SCRIPT_MISMATCH"
  }
}

if ($Stage -eq "Seed") {
  if ("$(Get-PropertyValue -Object $queue -Name "active_task_id")" -ne $TaskId) {
    $activeTaskId = Get-PropertyValue -Object $queue -Name "active_task_id"
    Add-Failure "SEED_ACTIVE_TASK_MISMATCH=$activeTaskId"
  }
  if ($null -ne $task -and "$(Get-PropertyValue -Object $task -Name "status")" -ne "READY") {
    Add-Failure "SEED_TASK_STATUS_NOT_READY"
  }
  foreach ($path in @(
    "packs/PHASE95_SELF_BUILD_PROGRAM_GENERATOR_V2",
    "tasks/TASK_SELF_BUILD_PROGRAM_GENERATOR_V2_001.json",
    "reports/self_development/SELF_BUILD_PROGRAM_GENERATOR_V2_REPORT.json",
    "proofs/self_development/SELF_BUILD_PROGRAM_GENERATOR_V2.json",
    "self_build_programs/generated/SELF_BUILD_PROGRAM_002.json"
  )) {
    Assert-FileAbsent $path
  }
}

if ($Stage -eq "Completed") {
  foreach ($path in @(
    "contracts/self_development/owner_order_to_gap_map_v1.schema.json",
    "owner_orders/OWNER_ORDER_CONTRACT_V1.json",
    "owner_orders/examples/OWNER_ORDER_BATCH_SELF_BUILD_100_TASKS_EXAMPLE.json",
    "self_build_backlog/OWNER_ORDER_TO_GAP_MAP_V1.json",
    "self_build_backlog/OWNER_ORDER_GAP_MAP_EXAMPLE_V1.json",
    "reports/self_development/OWNER_ORDER_TO_GAP_MAP_REPORT.json",
    "proofs/self_development/OWNER_ORDER_TO_GAP_MAP_V1.json"
  )) {
    Read-JsonFile $path | Out-Null
  }

  $proof = Read-JsonFile "proofs/self_development/OWNER_ORDER_TO_GAP_MAP_V1.json"
  if ($null -ne $proof) {
    if ("$(Get-PropertyValue -Object $proof -Name "status")" -ne "PASS") {
      Add-Failure "PROOF_STATUS_NOT_PASS"
    }
    if ("$(Get-PropertyValue -Object $proof -Name "phase")" -ne "PHASE94_OWNER_ORDER_TO_GAP_MAP_V1") {
      Add-Failure "PROOF_PHASE_MISMATCH"
    }
    if ("$(Get-PropertyValue -Object $proof -Name "task_id")" -ne $TaskId) {
      Add-Failure "PROOF_TASK_ID_MISMATCH"
    }
    if ("$(Get-PropertyValue -Object $proof -Name "runtime_mode")" -ne "SELF_BUILD") {
      Add-Failure "PROOF_RUNTIME_MODE_MISMATCH"
    }
    foreach ($field in @(
      "future_workflow_input_contract_defined",
      "no_external_agent_production",
      "no_external_install",
      "no_external_fetch",
      "phase95_not_executed",
      "queue_returned_to_none"
    )) {
      if (-not [bool](Get-PropertyValue -Object $proof -Name $field)) {
        Add-Failure "PROOF_$($field.ToUpperInvariant())_NOT_TRUE"
      }
    }
    if ([bool](Get-PropertyValue -Object $proof -Name "execution_performed")) {
      Add-Failure "PROOF_EXECUTION_PERFORMED_TRUE"
    }
    if ("$(Get-PropertyValue -Object $proof -Name "next_allowed_step")" -ne $NextAllowedStep) {
      Add-Failure "PROOF_NEXT_ALLOWED_STEP_MISMATCH"
    }
  }

  if ("$(Get-PropertyValue -Object $queue -Name "active_task_id")" -ne "NONE") {
    Add-Failure "COMPLETED_QUEUE_NOT_NONE"
  }
  if ($null -ne $task -and "$(Get-PropertyValue -Object $task -Name "status")" -ne "COMPLETED") {
    Add-Failure "COMPLETED_TASK_STATUS_NOT_COMPLETED"
  }
}

if (@($script:Failures).Count -gt 0) {
  foreach ($failure in $script:Failures) {
    Write-Host "FAIL=$failure"
  }
  Write-Host "VALIDATION_RESULT=FAIL"
  throw "PHASE94_VALIDATION_FAILED"
}

if ($Stage -eq "Seed") {
  Write-Host "VALIDATION_RESULT=PASS_SEED"
} else {
  Write-Host "VALIDATION_RESULT=PASS"
}
