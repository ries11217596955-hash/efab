[CmdletBinding()]
param(
  [ValidateSet("Auto", "Seed", "Completed")]
  [string]$Stage = "Auto",
  [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
)

$ErrorActionPreference = "Stop"

$PackId = "PHASE87_SELF_DEVELOPMENT_DECISION_KERNEL_V1"
$TaskId = "TASK_SELF_DEVELOPMENT_DECISION_KERNEL_V1_001"
$ReportPath = "reports/self_development/SELF_DEVELOPMENT_DECISION_KERNEL_REPORT.json"
$ProofPath = "proofs/self_development/SELF_DEVELOPMENT_DECISION_KERNEL_V1.json"
$NextAllowedStep = "PHASE88_SELF_BUILD_PROGRAM_GENERATOR_V1"

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

foreach ($path in @(
  "contracts/self_development/self_development_decision_kernel_report.schema.json",
  "packs/PHASE87_SELF_DEVELOPMENT_DECISION_KERNEL_V1/PACK.json",
  "tasks/TASK_SELF_DEVELOPMENT_DECISION_KERNEL_V1_001.json",
  "TASK_QUEUE.json",
  "CAPABILITY_ROADMAP.json",
  "GENESIS_STATE.json",
  "packs/registry.json"
)) {
  Read-JsonFile $path | Out-Null
}

foreach ($script in @(
  "modules/self_development/write_self_development_decision_kernel_report.ps1",
  "packs/PHASE87_SELF_DEVELOPMENT_DECISION_KERNEL_V1/APPLY.ps1",
  "packs/PHASE87_SELF_DEVELOPMENT_DECISION_KERNEL_V1/VALIDATE.ps1"
)) {
  Assert-ParserPass -Path $script
}

if (-not (Test-Path -LiteralPath (Join-RepoPath "packs/PHASE87_SELF_DEVELOPMENT_DECISION_KERNEL_V1"))) {
  Add-Failure "MISSING_PACK_DIRECTORY=packs/PHASE87_SELF_DEVELOPMENT_DECISION_KERNEL_V1"
}

$queue = Read-JsonFile "TASK_QUEUE.json"
$taskEntry = Find-TaskEntry -Queue $queue
if ($null -eq $taskEntry) {
  Add-Failure "TASK_NOT_FOUND=$TaskId"
}

$packRegistry = Read-JsonFile "packs/registry.json"
$matchingPacks = Get-MatchingRegistryPacks -Registry $packRegistry
if (@($matchingPacks).Count -ne 1) {
  Add-Failure "REGISTRY_MATCH_COUNT=$(@($matchingPacks).Count)"
} else {
  $selectedPackId = Get-PropertyValue -Object $matchingPacks[0] -Name "pack_id"
  if ("$selectedPackId" -ne $PackId) {
    Add-Failure "REGISTRY_PACK_ID_MISMATCH=$selectedPackId"
  }
}

$phase86Proof = Read-JsonFile "proofs/operations/OPERATION_RUNTIME_SKELETON_V1.json"
if ($null -ne $phase86Proof) {
  if ("$(Get-PropertyValue -Object $phase86Proof -Name "status")" -ne "PASS") {
    Add-Failure "PHASE86_PROOF_STATUS_NOT_PASS"
  }
  if ("$(Get-PropertyValue -Object $phase86Proof -Name "next_allowed_step")" -ne "PHASE87_SELF_DEVELOPMENT_DECISION_KERNEL_V1") {
    Add-Failure "PHASE86_NEXT_ALLOWED_STEP_MISMATCH"
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
  $report = Read-JsonFile $ReportPath
  $proof = Read-JsonFile $ProofPath
  $activeTaskId = Get-PropertyValue -Object $queue -Name "active_task_id"
  if ("$activeTaskId" -ne "NONE") {
    Add-Failure "ACTIVE_TASK_NOT_CLOSED=$activeTaskId"
  }
  if ($null -ne $taskEntry) {
    $taskStatus = Get-PropertyValue -Object $taskEntry -Name "status"
    if ("$taskStatus" -ne "COMPLETED") {
      Add-Failure "TASK_STATUS_NOT_COMPLETED=$taskStatus"
    }
  }
  if ($null -ne $report) {
    if ("$(Get-PropertyValue -Object $report -Name "status")" -ne "PASS") {
      Add-Failure "REPORT_STATUS_NOT_PASS"
    }
    if ("$(Get-PropertyValue -Object $report -Name "recommended_next_step_id")" -ne $NextAllowedStep) {
      Add-Failure "REPORT_NEXT_STEP_MISMATCH"
    }
  }
  if ($null -ne $proof) {
    if ("$(Get-PropertyValue -Object $proof -Name "status")" -ne "PASS") {
      Add-Failure "PROOF_STATUS_NOT_PASS"
    }
    if ("$(Get-PropertyValue -Object $proof -Name "next_allowed_step")" -ne $NextAllowedStep) {
      Add-Failure "PROOF_NEXT_ALLOWED_STEP_MISMATCH"
    }
  }
}

if (@($script:Failures).Count -gt 0) {
  foreach ($failure in $script:Failures) {
    Write-Host "FAIL=$failure"
  }
  Write-Host "VALIDATION_RESULT=FAIL"
  throw "PHASE87_VALIDATION_FAILED"
}

if ($Stage -eq "Seed") {
  Write-Host "VALIDATION_RESULT=PASS_SEED"
} else {
  Write-Host "VALIDATION_RESULT=PASS"
}
