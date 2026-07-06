[CmdletBinding()]
param(
  [ValidateSet("Auto", "Seed", "Completed")]
  [string]$Stage = "Auto",
  [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
)

$ErrorActionPreference = "Stop"

$TaskId = "TASK_AUTO_NEXT_GAP_DECISION_V1_001"
$PackId = "PHASE102_AUTO_NEXT_GAP_DECISION_V1"
$EntryScript = "packs/PHASE102_AUTO_NEXT_GAP_DECISION_V1/APPLY.ps1"
$NextAllowedStep = "PHASE103_REPAIR_LOOP_GENERATOR_V1"
$SchemaPath = "contracts/self_development/auto_next_gap_decision_v1.schema.json"
$DecisionKernelPath = "self_build_batch/next_actions/AUTO_NEXT_GAP_DECISION_KERNEL_V1.json"
$DryRunActionPlanPath = "self_build_batch/next_actions/BATCH_PLAN_EXAMPLE_V1_NEXT_ACTION_PLAN_DRY_RUN.json"
$ReportPath = "reports/self_development/AUTO_NEXT_GAP_DECISION_V1_REPORT.json"
$ProofPath = "proofs/self_development/AUTO_NEXT_GAP_DECISION_V1.json"
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

function Get-SafeCount {
  param([object]$Value)

  return @($Value).Count
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

function Assert-CountAtLeast {
  param(
    [object]$Object,
    [string]$Name,
    [int]$Minimum
  )

  $value = Get-PropertyValue -Object $Object -Name $Name
  if ($null -eq $value) {
    Add-Failure "COUNT_FIELD_MISSING=$Name"
    return
  }
  try {
    $countValue = [int]$value
  } catch {
    Add-Failure "COUNT_FIELD_NOT_INTEGER=$Name"
    return
  }
  if ($countValue -lt $Minimum) {
    Add-Failure "$($Name.ToUpperInvariant())_LT_$Minimum"
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
  "modules/self_development/write_auto_next_gap_decision_v1.ps1",
  "packs/PHASE102_AUTO_NEXT_GAP_DECISION_V1/PACK.json",
  "packs/PHASE102_AUTO_NEXT_GAP_DECISION_V1/APPLY.ps1",
  "packs/PHASE102_AUTO_NEXT_GAP_DECISION_V1/VALIDATE.ps1",
  "tasks/TASK_AUTO_NEXT_GAP_DECISION_V1_001.json"
)) {
  Assert-FileExists $path
}

foreach ($path in @(
  "packs/PHASE102_AUTO_NEXT_GAP_DECISION_V1/PACK.json",
  "tasks/TASK_AUTO_NEXT_GAP_DECISION_V1_001.json",
  "TASK_QUEUE.json",
  "packs/registry.json",
  "CAPABILITY_ROADMAP.json",
  "GENESIS_STATE.json"
)) {
  Read-JsonFile $path | Out-Null
}

foreach ($script in @(
  "modules/self_development/write_auto_next_gap_decision_v1.ps1",
  "packs/PHASE102_AUTO_NEXT_GAP_DECISION_V1/APPLY.ps1",
  "packs/PHASE102_AUTO_NEXT_GAP_DECISION_V1/VALIDATE.ps1"
)) {
  Assert-ParserPass $script
}

$phase101Proof = Read-JsonFile "proofs/self_development/BATCH_PROOF_AGGREGATOR_V1.json"
if ($null -ne $phase101Proof) {
  if ("$(Get-PropertyValue -Object $phase101Proof -Name "status")" -ne "PASS") {
    Add-Failure "PHASE101_PROOF_STATUS_NOT_PASS"
  }
  if ("$(Get-PropertyValue -Object $phase101Proof -Name "next_allowed_step")" -ne "PHASE102_AUTO_NEXT_GAP_DECISION_V1") {
    Add-Failure "PHASE101_PROOF_NEXT_STEP_MISMATCH"
  }
}

$phase101Summary = Read-JsonFile "self_build_batch/proof_aggregation/BATCH_PLAN_EXAMPLE_V1_PROOF_SUMMARY_DRY_RUN.json"
if ($null -ne $phase101Summary) {
  Assert-CountAtLeast -Object $phase101Summary -Name "unresolved_record_count" -Minimum 4
}

$phase100Registry = Read-JsonFile "self_build_batch/quarantine/BATCH_PLAN_EXAMPLE_V1_QUARANTINE_BLOCKER_DRY_RUN.json"
if ($null -ne $phase100Registry) {
  Assert-CountAtLeast -Object $phase100Registry -Name "record_count" -Minimum 4
}

$queue = Read-JsonFile "TASK_QUEUE.json"
$registry = Read-JsonFile "packs/registry.json"
$task = Find-TaskEntry -Queue $queue
if ($null -eq $task) {
  Add-Failure "TASK_NOT_FOUND=$TaskId"
}
$selectedPacks = Get-MatchingRegistryPacks -Registry $registry
if ((Get-SafeCount -Value $selectedPacks) -ne 1) {
  Add-Failure "REGISTRY_SELECTED_PACK_COUNT=$(Get-SafeCount -Value $selectedPacks)"
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
    $SchemaPath,
    $DecisionKernelPath,
    $DryRunActionPlanPath,
    $ReportPath,
    $ProofPath,
    "packs/PHASE103_REPAIR_LOOP_GENERATOR_V1",
    "tasks/TASK_REPAIR_LOOP_GENERATOR_V1_001.json",
    "proofs/self_development/REPAIR_LOOP_GENERATOR_V1.json",
    "reports/self_development/REPAIR_LOOP_GENERATOR_V1_REPORT.json"
  )) {
    Assert-FileAbsent $path
  }
}

if ($Stage -eq "Completed") {
  $schema = Read-JsonFile $SchemaPath
  $decisionKernel = Read-JsonFile $DecisionKernelPath
  $actionPlan = Read-JsonFile $DryRunActionPlanPath
  $report = Read-JsonFile $ReportPath
  $proof = Read-JsonFile $ProofPath

  if ($null -ne $schema) {
    $required = As-Array (Get-PropertyValue -Object $schema -Name "required")
    foreach ($field in @(
      "decision_kernel_id",
      "version",
      "status",
      "active_line",
      "input_sources",
      "decision_priority",
      "decision_policy",
      "action_plan_contract",
      "self_resolution_first",
      "assistance_is_fallback",
      "execution_allowed",
      "next_allowed_step"
    )) {
      if ($required -notcontains $field) {
        Add-Failure "SCHEMA_REQUIRED_FIELD_MISSING=$field"
      }
    }
  }

  if ($null -ne $decisionKernel) {
    if ("$(Get-PropertyValue -Object $decisionKernel -Name "status")" -ne "ACTIVE_DECISION_KERNEL") {
      Add-Failure "DECISION_KERNEL_STATUS_NOT_ACTIVE"
    }
    foreach ($trueField in @("self_resolution_first", "assistance_is_fallback")) {
      if (-not [bool](Get-PropertyValue -Object $decisionKernel -Name $trueField)) {
        Add-Failure "DECISION_KERNEL_$($trueField.ToUpperInvariant())_NOT_TRUE"
      }
    }
    if ([bool](Get-PropertyValue -Object $decisionKernel -Name "execution_allowed")) {
      Add-Failure "DECISION_KERNEL_EXECUTION_ALLOWED_TRUE"
    }
  }

  if ($null -ne $actionPlan) {
    if ("$(Get-PropertyValue -Object $actionPlan -Name "status")" -ne "DRY_RUN_NEXT_ACTIONS_READY") {
      Add-Failure "ACTION_PLAN_STATUS_NOT_READY"
    }
    foreach ($trueField in @("self_resolution_first", "assistance_is_fallback", "program_generation_required_next")) {
      if (-not [bool](Get-PropertyValue -Object $actionPlan -Name $trueField)) {
        Add-Failure "ACTION_PLAN_$($trueField.ToUpperInvariant())_NOT_TRUE"
      }
    }
    if ([bool](Get-PropertyValue -Object $actionPlan -Name "execution_allowed")) {
      Add-Failure "ACTION_PLAN_EXECUTION_ALLOWED_TRUE"
    }
    Assert-CountAtLeast -Object $actionPlan -Name "decision_count" -Minimum 4
    Assert-CountAtLeast -Object $actionPlan -Name "self_resolvable_count" -Minimum 2
    Assert-CountAtLeast -Object $actionPlan -Name "material_acquisition_candidate_count" -Minimum 1
    Assert-CountAtLeast -Object $actionPlan -Name "safe_patch_candidate_count" -Minimum 1
    Assert-CountAtLeast -Object $actionPlan -Name "fallback_count" -Minimum 1
    $selectedStep = "$(Get-PropertyValue -Object $actionPlan -Name "selected_next_executable_step")"
    if ([string]::IsNullOrWhiteSpace($selectedStep)) {
      Add-Failure "ACTION_PLAN_SELECTED_NEXT_EXECUTABLE_STEP_MISSING"
    }
    if ($selectedStep -match "CODEX|OWNER") {
      Add-Failure "ACTION_PLAN_SELECTED_NEXT_EXECUTABLE_STEP_IS_FALLBACK"
    }
    $decisions = @(As-Array (Get-PropertyValue -Object $actionPlan -Name "decisions"))
    $decisionValues = @($decisions | ForEach-Object { "$(Get-PropertyValue -Object $_ -Name "decision")" })
    foreach ($requiredDecision in @("SELF_BUILD_REQUIRED_MODULES", "SELF_ACQUIRE_MATERIAL_UNDER_POLICY", "SELF_PATCH_SAFE_LOCAL_SCOPE")) {
      if ($decisionValues -notcontains $requiredDecision) {
        Add-Failure "ACTION_PLAN_DECISION_MISSING=$requiredDecision"
      }
    }
    foreach ($decision in $decisions) {
      $decisionValue = "$(Get-PropertyValue -Object $decision -Name "decision")"
      $canSelfResolveNow = [bool](Get-PropertyValue -Object $decision -Name "can_self_resolve_now")
      $fallbackAllowed = [bool](Get-PropertyValue -Object $decision -Name "fallback_allowed_only_if_self_blocked")
      if ($decisionValue -in @("CODEX_REPAIR_REQUIRED_FALLBACK", "OWNER_DECISION_REQUIRED_FALLBACK")) {
        if ($canSelfResolveNow) {
          Add-Failure "FALLBACK_DECISION_SELF_RESOLVABLE_TRUE=$decisionValue"
        }
        if (-not $fallbackAllowed) {
          Add-Failure "FALLBACK_DECISION_NOT_MARKED_SELF_BLOCKED=$decisionValue"
        }
        if ([string]::IsNullOrWhiteSpace("$(Get-PropertyValue -Object $decision -Name "fallback_reason")")) {
          Add-Failure "FALLBACK_DECISION_REASON_MISSING=$decisionValue"
        }
      }
      if ($canSelfResolveNow -and $decisionValue -match "FALLBACK") {
        Add-Failure "SELF_RESOLVABLE_DECISION_USES_FALLBACK=$decisionValue"
      }
    }
  }

  if ($null -ne $report -and "$(Get-PropertyValue -Object $report -Name "status")" -ne "PASS") {
    Add-Failure "REPORT_STATUS_NOT_PASS"
  }

  if ($null -ne $proof) {
    if ("$(Get-PropertyValue -Object $proof -Name "status")" -ne "PASS") {
      Add-Failure "PROOF_STATUS_NOT_PASS"
    }
    if ("$(Get-PropertyValue -Object $proof -Name "phase")" -ne "PHASE102_AUTO_NEXT_GAP_DECISION_V1") {
      Add-Failure "PROOF_PHASE_MISMATCH"
    }
    if ("$(Get-PropertyValue -Object $proof -Name "task_id")" -ne $TaskId) {
      Add-Failure "PROOF_TASK_ID_MISMATCH"
    }
    if ("$(Get-PropertyValue -Object $proof -Name "runtime_mode")" -ne "SELF_BUILD") {
      Add-Failure "PROOF_RUNTIME_MODE_MISMATCH"
    }
    foreach ($field in @(
      "decision_kernel_created",
      "schema_created",
      "dry_run_action_plan_created",
      "self_resolution_first",
      "assistance_is_fallback",
      "codex_is_fallback_not_primary",
      "owner_is_fallback_not_primary",
      "program_generation_required_next",
      "phase103_required_next",
      "no_external_agent_production",
      "no_external_install",
      "no_external_fetch",
      "phase103_not_executed",
      "queue_returned_to_none"
    )) {
      if (-not [bool](Get-PropertyValue -Object $proof -Name $field)) {
        Add-Failure "PROOF_$($field.ToUpperInvariant())_NOT_TRUE"
      }
    }
    if ([bool](Get-PropertyValue -Object $proof -Name "execution_allowed")) {
      Add-Failure "PROOF_EXECUTION_ALLOWED_TRUE"
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

if ((Get-SafeCount -Value $script:Failures) -gt 0) {
  foreach ($failure in $script:Failures) {
    Write-Host "FAIL=$failure"
  }
  Write-Host "VALIDATION_RESULT=FAIL"
  throw "PHASE102_VALIDATION_FAILED"
}

if ($Stage -eq "Seed") {
  Write-Host "VALIDATION_RESULT=PASS_SEED"
} else {
  Write-Host "VALIDATION_RESULT=PASS"
}
