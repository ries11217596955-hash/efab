[CmdletBinding()]
param(
  [ValidateSet("Auto", "Seed", "Completed")]
  [string]$Stage = "Auto",
  [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
)

$ErrorActionPreference = "Stop"

$TaskId = "TASK_BUILDER_EXECUTES_OWN_GENERATED_SELF_BUILD_PROGRAM_V1_001"
$PackId = "PHASE90_BUILDER_EXECUTES_OWN_GENERATED_SELF_BUILD_PROGRAM_V1"
$EntryScript = "packs/PHASE90_BUILDER_EXECUTES_OWN_GENERATED_SELF_BUILD_PROGRAM_V1/APPLY.ps1"
$ExecutionPath = "self_build_programs/executions/SELF_BUILD_PROGRAM_001_EXECUTION.json"
$ReportPath = "reports/self_development/GENERATED_SELF_BUILD_EXECUTION_REPORT.json"
$ProofPath = "proofs/self_development/GENERATED_SELF_BUILD_EXECUTION_V1.json"
$NextAllowedStep = "CREATE_AGENT_BUILDER_NEXT_15_STEPS_LOCK_V2"
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
  "contracts/self_development/generated_self_build_execution.schema.json",
  "modules/self_development/execute_admitted_self_build_program.ps1",
  "packs/PHASE90_BUILDER_EXECUTES_OWN_GENERATED_SELF_BUILD_PROGRAM_V1/PACK.json",
  "packs/PHASE90_BUILDER_EXECUTES_OWN_GENERATED_SELF_BUILD_PROGRAM_V1/APPLY.ps1",
  "packs/PHASE90_BUILDER_EXECUTES_OWN_GENERATED_SELF_BUILD_PROGRAM_V1/VALIDATE.ps1",
  "tasks/TASK_BUILDER_EXECUTES_OWN_GENERATED_SELF_BUILD_PROGRAM_V1_001.json"
)) {
  Assert-FileExists $path
}

foreach ($path in @(
  "contracts/self_development/generated_self_build_execution.schema.json",
  "packs/PHASE90_BUILDER_EXECUTES_OWN_GENERATED_SELF_BUILD_PROGRAM_V1/PACK.json",
  "tasks/TASK_BUILDER_EXECUTES_OWN_GENERATED_SELF_BUILD_PROGRAM_V1_001.json",
  "TASK_QUEUE.json",
  "packs/registry.json",
  "CAPABILITY_ROADMAP.json",
  "GENESIS_STATE.json"
)) {
  Read-JsonFile $path | Out-Null
}

foreach ($script in @(
  "modules/self_development/execute_admitted_self_build_program.ps1",
  "packs/PHASE90_BUILDER_EXECUTES_OWN_GENERATED_SELF_BUILD_PROGRAM_V1/APPLY.ps1",
  "packs/PHASE90_BUILDER_EXECUTES_OWN_GENERATED_SELF_BUILD_PROGRAM_V1/VALIDATE.ps1"
)) {
  Assert-ParserPass $script
}

$program = Read-JsonFile "self_build_programs/generated/SELF_BUILD_PROGRAM_001.json"
$admission = Read-JsonFile "self_build_programs/admission/SELF_BUILD_PROGRAM_001_ADMISSION.json"
$phase89Report = Read-JsonFile "reports/self_development/GENERATED_PROGRAM_ADMISSION_REPORT.json"
$phase89Proof = Read-JsonFile "proofs/self_development/GENERATED_PROGRAM_ADMISSION_V1.json"

if ($null -ne $program) {
  if ("$(Get-PropertyValue -Object $program -Name "status")" -ne "GENERATED_CANDIDATE") {
    Add-Failure "PROGRAM_STATUS_NOT_GENERATED_CANDIDATE"
  }
  if (-not [bool](Get-PropertyValue -Object $program -Name "admission_required")) {
    Add-Failure "PROGRAM_ADMISSION_REQUIRED_NOT_TRUE"
  }
}

if ($null -ne $admission) {
  if ("$(Get-PropertyValue -Object $admission -Name "status")" -ne "PASS") {
    Add-Failure "ADMISSION_STATUS_NOT_PASS"
  }
  if ("$(Get-PropertyValue -Object $admission -Name "admission_decision")" -ne "ADMIT_CANDIDATE_FOR_CONTROLLED_EXECUTION") {
    Add-Failure "ADMISSION_DECISION_MISMATCH"
  }
}

if ($null -ne $phase89Report) {
  if ("$(Get-PropertyValue -Object $phase89Report -Name "status")" -ne "PASS") {
    Add-Failure "PHASE89_REPORT_STATUS_NOT_PASS"
  }
}

if ($null -ne $phase89Proof) {
  if ("$(Get-PropertyValue -Object $phase89Proof -Name "status")" -ne "PASS") {
    Add-Failure "PHASE89_PROOF_STATUS_NOT_PASS"
  }
  if ("$(Get-PropertyValue -Object $phase89Proof -Name "next_allowed_step")" -ne "PHASE90_BUILDER_EXECUTES_OWN_GENERATED_SELF_BUILD_PROGRAM_V1") {
    Add-Failure "PHASE89_PROOF_NEXT_STEP_MISMATCH"
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
  if ($null -ne $task -and "$(Get-PropertyValue -Object $task -Name "status")" -ne "PENDING") {
    Add-Failure "SEED_TASK_STATUS_NOT_PENDING"
  }
}

if ($Stage -eq "Completed") {
  $execution = Read-JsonFile $ExecutionPath
  $report = Read-JsonFile $ReportPath
  $proof = Read-JsonFile $ProofPath
  if ($null -ne $execution) {
    if ("$(Get-PropertyValue -Object $execution -Name "status")" -ne "PASS") {
      Add-Failure "EXECUTION_STATUS_NOT_PASS"
    }
    if (-not [bool](Get-PropertyValue -Object $execution -Name "execution_performed")) {
      Add-Failure "EXECUTION_PERFORMED_NOT_TRUE"
    }
    if (-not [bool](Get-PropertyValue -Object $execution -Name "completed_loop")) {
      Add-Failure "EXECUTION_COMPLETED_LOOP_NOT_TRUE"
    }
    if ([bool](Get-PropertyValue -Object $execution -Name "external_agent_production")) {
      Add-Failure "EXECUTION_EXTERNAL_AGENT_PRODUCTION_TRUE"
    }
  }
  if ($null -ne $report) {
    if ("$(Get-PropertyValue -Object $report -Name "status")" -ne "PASS") {
      Add-Failure "REPORT_STATUS_NOT_PASS"
    }
    if (-not [bool](Get-PropertyValue -Object $report -Name "execution_performed")) {
      Add-Failure "REPORT_EXECUTION_PERFORMED_NOT_TRUE"
    }
    if (-not [bool](Get-PropertyValue -Object $report -Name "completed_loop")) {
      Add-Failure "REPORT_COMPLETED_LOOP_NOT_TRUE"
    }
  }
  if ($null -ne $proof) {
    if ("$(Get-PropertyValue -Object $proof -Name "status")" -ne "PASS") {
      Add-Failure "PROOF_STATUS_NOT_PASS"
    }
    if (-not [bool](Get-PropertyValue -Object $proof -Name "execution_performed")) {
      Add-Failure "PROOF_EXECUTION_PERFORMED_NOT_TRUE"
    }
    if (-not [bool](Get-PropertyValue -Object $proof -Name "completed_loop")) {
      Add-Failure "PROOF_COMPLETED_LOOP_NOT_TRUE"
    }
    if (-not [bool](Get-PropertyValue -Object $proof -Name "queue_returned_to_none")) {
      Add-Failure "PROOF_QUEUE_RETURNED_TO_NONE_NOT_TRUE"
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
  throw "PHASE90_VALIDATION_FAILED"
}

if ($Stage -eq "Seed") {
  Write-Host "VALIDATION_RESULT=PASS_SEED"
} else {
  Write-Host "VALIDATION_RESULT=PASS"
}
