[CmdletBinding()]
param(
  [ValidateSet("Auto", "Seed", "Completed")]
  [string]$Stage = "Auto",
  [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
)

$ErrorActionPreference = "Stop"

$TaskId = "TASK_ROUTE_V1_CLOSURE_AND_V2_R2_ACTIVATION_001"
$PackId = "PHASE91_ROUTE_V1_CLOSURE_AND_V2_R2_ACTIVATION"
$EntryScript = "packs/PHASE91_ROUTE_V1_CLOSURE_AND_V2_R2_ACTIVATION/APPLY.ps1"
$RouteLockPath = "AGENT_BUILDER_NEXT_15_STEPS_LOCK_V2_R2.md"
$ReportPath = "reports/route_locks/ROUTE_V1_CLOSURE_AND_V2_R2_ACTIVATION_REPORT.json"
$ProofPath = "proofs/route_locks/ROUTE_V1_CLOSURE_AND_V2_R2_ACTIVATION_PROOF.json"
$NextAllowedStep = "PHASE92_SELF_BUILD_BACKLOG_CONTRACT_V1"
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

function Is-RouteLockDecision {
  param([string]$Value)

  return $Value -in @(
    "CREATE_AGENT_BUILDER_NEXT_15_STEPS_LOCK_V2",
    "CREATE_AGENT_BUILDER_NEXT_15_STEPS_LOCK_V2_R2",
    "PHASE91_ROUTE_V1_CLOSURE_AND_V2_R2_ACTIVATION"
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
  "modules/route_locks/write_route_v1_closure_and_v2_r2_activation_report.ps1",
  "packs/PHASE91_ROUTE_V1_CLOSURE_AND_V2_R2_ACTIVATION/PACK.json",
  "packs/PHASE91_ROUTE_V1_CLOSURE_AND_V2_R2_ACTIVATION/APPLY.ps1",
  "packs/PHASE91_ROUTE_V1_CLOSURE_AND_V2_R2_ACTIVATION/VALIDATE.ps1",
  "tasks/TASK_ROUTE_V1_CLOSURE_AND_V2_R2_ACTIVATION_001.json"
)) {
  Assert-FileExists $path
}

foreach ($path in @(
  "packs/PHASE91_ROUTE_V1_CLOSURE_AND_V2_R2_ACTIVATION/PACK.json",
  "tasks/TASK_ROUTE_V1_CLOSURE_AND_V2_R2_ACTIVATION_001.json",
  "TASK_QUEUE.json",
  "packs/registry.json",
  "CAPABILITY_ROADMAP.json",
  "GENESIS_STATE.json"
)) {
  Read-JsonFile $path | Out-Null
}

foreach ($script in @(
  "modules/route_locks/write_route_v1_closure_and_v2_r2_activation_report.ps1",
  "packs/PHASE91_ROUTE_V1_CLOSURE_AND_V2_R2_ACTIVATION/APPLY.ps1",
  "packs/PHASE91_ROUTE_V1_CLOSURE_AND_V2_R2_ACTIVATION/VALIDATE.ps1"
)) {
  Assert-ParserPass $script
}

$phase90Proof = Read-JsonFile "proofs/self_development/GENERATED_SELF_BUILD_EXECUTION_V1.json"
$phase90Report = Read-JsonFile "reports/self_development/GENERATED_SELF_BUILD_EXECUTION_REPORT.json"

if ($null -ne $phase90Proof) {
  if ("$(Get-PropertyValue -Object $phase90Proof -Name "status")" -ne "PASS") {
    Add-Failure "PHASE90_PROOF_STATUS_NOT_PASS"
  }
  if (-not [bool](Get-PropertyValue -Object $phase90Proof -Name "execution_performed")) {
    Add-Failure "PHASE90_PROOF_EXECUTION_NOT_TRUE"
  }
  if (-not [bool](Get-PropertyValue -Object $phase90Proof -Name "completed_loop")) {
    Add-Failure "PHASE90_PROOF_COMPLETED_LOOP_NOT_TRUE"
  }
}

if ($null -ne $phase90Report) {
  if ("$(Get-PropertyValue -Object $phase90Report -Name "status")" -ne "PASS") {
    Add-Failure "PHASE90_REPORT_STATUS_NOT_PASS"
  }
}

$phase90Next = "$(Get-PropertyValue -Object $phase90Proof -Name "next_allowed_step")"
$phase90Recommended = "$(Get-PropertyValue -Object $phase90Report -Name "next_recommended_action")"
if (-not (Is-RouteLockDecision -Value $phase90Next) -and -not (Is-RouteLockDecision -Value $phase90Recommended)) {
  Add-Failure "PHASE90_ROUTE_LOCK_DECISION_MISSING"
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
  if ($null -ne $task -and "$(Get-PropertyValue -Object $task -Name "status")" -ne "PENDING") {
    Add-Failure "SEED_TASK_STATUS_NOT_PENDING"
  }
  foreach ($path in @(
    "packs/PHASE92_SELF_BUILD_BACKLOG_CONTRACT_V1",
    "tasks/TASK_SELF_BUILD_BACKLOG_CONTRACT_V1_001.json",
    "reports/self_development/SELF_BUILD_BACKLOG_CONTRACT_REPORT.json",
    "proofs/self_development/SELF_BUILD_BACKLOG_CONTRACT_V1.json"
  )) {
    Assert-FileAbsent $path
  }
}

if ($Stage -eq "Completed") {
  Assert-FileExists $RouteLockPath
  $report = Read-JsonFile $ReportPath
  $proof = Read-JsonFile $ProofPath

  if ($null -ne $report) {
    if ("$(Get-PropertyValue -Object $report -Name "status")" -ne "PASS") {
      Add-Failure "REPORT_STATUS_NOT_PASS"
    }
    if ("$(Get-PropertyValue -Object $report -Name "next_allowed_step")" -ne $NextAllowedStep) {
      Add-Failure "REPORT_NEXT_ALLOWED_STEP_MISMATCH"
    }
  }

  if ($null -ne $proof) {
    if ("$(Get-PropertyValue -Object $proof -Name "status")" -ne "PASS") {
      Add-Failure "PROOF_STATUS_NOT_PASS"
    }
    if ("$(Get-PropertyValue -Object $proof -Name "phase")" -ne "PHASE91_ROUTE_V1_CLOSURE_AND_V2_R2_ACTIVATION") {
      Add-Failure "PROOF_PHASE_MISMATCH"
    }
    if ("$(Get-PropertyValue -Object $proof -Name "route_lock_version")" -ne "V2_R2") {
      Add-Failure "PROOF_ROUTE_LOCK_VERSION_MISMATCH"
    }
    if (-not [bool](Get-PropertyValue -Object $proof -Name "no_external_agent_production")) {
      Add-Failure "PROOF_NO_EXTERNAL_AGENT_PRODUCTION_NOT_TRUE"
    }
    if (-not [bool](Get-PropertyValue -Object $proof -Name "batch_self_build_engine_route")) {
      Add-Failure "PROOF_BATCH_SELF_BUILD_ENGINE_ROUTE_NOT_TRUE"
    }
    if (-not [bool](Get-PropertyValue -Object $proof -Name "old_v2_superseded")) {
      Add-Failure "PROOF_OLD_V2_SUPERSEDED_NOT_TRUE"
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
  throw "PHASE91_VALIDATION_FAILED"
}

if ($Stage -eq "Seed") {
  Write-Host "VALIDATION_RESULT=PASS_SEED"
} else {
  Write-Host "VALIDATION_RESULT=PASS"
}
