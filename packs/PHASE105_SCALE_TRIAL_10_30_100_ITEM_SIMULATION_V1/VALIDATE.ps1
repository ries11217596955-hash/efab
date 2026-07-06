[CmdletBinding()]
param(
  [ValidateSet("Auto", "Seed", "Completed")]
  [string]$Stage = "Auto",
  [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
)

$ErrorActionPreference = "Stop"

$TaskId = "TASK_SCALE_TRIAL_10_30_100_ITEM_SIMULATION_V1_001"
$PackId = "PHASE105_SCALE_TRIAL_10_30_100_ITEM_SIMULATION_V1"
$Phase = "PHASE105_SCALE_TRIAL_10_30_100_ITEM_SIMULATION_V1"
$EntryScript = "packs/PHASE105_SCALE_TRIAL_10_30_100_ITEM_SIMULATION_V1/APPLY.ps1"
$ValidateScript = "packs/PHASE105_SCALE_TRIAL_10_30_100_ITEM_SIMULATION_V1/VALIDATE.ps1"
$ModulePath = "modules/self_development/write_scale_trial_10_30_100_item_simulation_v1.ps1"
$NextAllowedStep = "PHASE106_SCALE_TRIAL_PROMOTION_GATE_AND_ROUTE_LOCK_REFRESH_V1"
$SchemaPath = "contracts/self_development/scale_trial_10_30_100_item_simulation_v1.schema.json"
$ScaleTrialContractPath = "self_build_batch/scale_trials/SCALE_TRIAL_10_30_100_ITEM_SIMULATION_V1.json"
$ScaleTrialResultPath = "self_build_batch/scale_trials/BATCH_PLAN_EXAMPLE_V1_SCALE_TRIAL_RESULT.json"
$ReportPath = "reports/self_development/SCALE_TRIAL_10_30_100_ITEM_SIMULATION_V1_REPORT.json"
$ProofPath = "proofs/self_development/SCALE_TRIAL_10_30_100_ITEM_SIMULATION_V1.json"
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

  if ($null -eq $Object) {
    return $null
  }
  if ($Object -is [System.Collections.IDictionary]) {
    foreach ($key in $Object.Keys) {
      if ("$key" -ieq $Name) {
        return $Object[$key]
      }
    }
    return $null
  }

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
  if ((Get-SafeCount -Value $errors) -gt 0) {
    Add-Failure "POWERSHELL_PARSE_FAIL=$Path"
  }
}

function Assert-Equals {
  param(
    [object]$Object,
    [string]$Name,
    [object]$Expected
  )

  $actual = Get-PropertyValue -Object $Object -Name $Name
  if ("$actual" -ne "$Expected") {
    Add-Failure "$($Name.ToUpperInvariant())_MISMATCH expected=$Expected actual=$actual"
  }
}

function Assert-Boolean {
  param(
    [object]$Object,
    [string]$Name,
    [bool]$Expected
  )

  $actual = [bool](Get-PropertyValue -Object $Object -Name $Name)
  if ($actual -ne $Expected) {
    Add-Failure "$($Name.ToUpperInvariant())_MISMATCH expected=$Expected actual=$actual"
  }
}

function Assert-Integer {
  param(
    [object]$Object,
    [string]$Name,
    [int]$Expected
  )

  try {
    $actual = [int](Get-PropertyValue -Object $Object -Name $Name)
  } catch {
    Add-Failure "$($Name.ToUpperInvariant())_NOT_INTEGER"
    return
  }
  if ($actual -ne $Expected) {
    Add-Failure "$($Name.ToUpperInvariant())_MISMATCH expected=$Expected actual=$actual"
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
  $ModulePath,
  "packs/PHASE105_SCALE_TRIAL_10_30_100_ITEM_SIMULATION_V1/PACK.json",
  $EntryScript,
  $ValidateScript,
  "tasks/TASK_SCALE_TRIAL_10_30_100_ITEM_SIMULATION_V1_001.json"
)) {
  Assert-FileExists $path
}

foreach ($path in @(
  "packs/PHASE105_SCALE_TRIAL_10_30_100_ITEM_SIMULATION_V1/PACK.json",
  "tasks/TASK_SCALE_TRIAL_10_30_100_ITEM_SIMULATION_V1_001.json",
  "TASK_QUEUE.json",
  "packs/registry.json",
  "CAPABILITY_ROADMAP.json",
  "GENESIS_STATE.json"
)) {
  Read-JsonFile $path | Out-Null
}

foreach ($script in @($ModulePath, $EntryScript, $ValidateScript)) {
  Assert-ParserPass $script
}

$phase104Proof = Read-JsonFile "proofs/self_development/CONTROLLED_MULTI_CYCLE_SELF_BUILD_RUN_V1.json"
if ($null -ne $phase104Proof) {
  Assert-Equals -Object $phase104Proof -Name "status" -Expected "PASS"
  Assert-Equals -Object $phase104Proof -Name "next_allowed_step" -Expected $Phase
}

$phase104Result = Read-JsonFile "self_build_batch/controlled_runs/BATCH_PLAN_EXAMPLE_V1_CONTROLLED_MULTI_CYCLE_RUN_RESULT.json"
if ($null -ne $phase104Result) {
  Assert-Equals -Object $phase104Result -Name "run_result" -Expected "PASS"
}

$queue = Read-JsonFile "TASK_QUEUE.json"
$registry = Read-JsonFile "packs/registry.json"
$task = Find-TaskEntry -Queue $queue
$taskFile = Read-JsonFile "tasks/TASK_SCALE_TRIAL_10_30_100_ITEM_SIMULATION_V1_001.json"
if ($null -eq $task) {
  Add-Failure "TASK_NOT_FOUND=$TaskId"
}
$selectedPacks = Get-MatchingRegistryPacks -Registry $registry
if ((Get-SafeCount -Value $selectedPacks) -ne 1) {
  Add-Failure "REGISTRY_SELECTED_PACK_COUNT=$(Get-SafeCount -Value $selectedPacks)"
} else {
  $selected = $selectedPacks[0]
  Assert-Equals -Object $selected -Name "pack_id" -Expected $PackId
  Assert-Equals -Object $selected -Name "shell" -Expected "PowerShell"
  Assert-Equals -Object $selected -Name "entry_script" -Expected $EntryScript
  Assert-Equals -Object $selected -Name "validate_script" -Expected $ValidateScript
  Assert-Equals -Object $selected -Name "next_allowed_step" -Expected $NextAllowedStep
}

$registryPacks = @(As-Array (Get-PropertyValue -Object $registry -Name "packs"))
if ($registryPacks.Count -gt 0 -and "$(Get-PropertyValue -Object $registryPacks[0] -Name "pack_id")" -ne $PackId) {
  Add-Failure "REGISTRY_FIRST_PACK_NOT_PHASE105"
}

if ($Stage -eq "Seed") {
  Assert-Equals -Object $queue -Name "active_task_id" -Expected $TaskId
  if ($null -ne $task) {
    Assert-Equals -Object $task -Name "status" -Expected "READY"
  }
  if ($null -ne $taskFile) {
    Assert-Equals -Object $taskFile -Name "status" -Expected "READY"
  }
  foreach ($path in @(
    $SchemaPath,
    $ScaleTrialContractPath,
    $ScaleTrialResultPath,
    $ReportPath,
    $ProofPath
  )) {
    Assert-FileAbsent $path
  }
}

if ($Stage -eq "Completed") {
  $schema = Read-JsonFile $SchemaPath
  $contract = Read-JsonFile $ScaleTrialContractPath
  $result = Read-JsonFile $ScaleTrialResultPath
  $report = Read-JsonFile $ReportPath
  $proof = Read-JsonFile $ProofPath

  if ($null -ne $schema) {
    $required = As-Array (Get-PropertyValue -Object $schema -Name "required")
    foreach ($field in @(
      "scale_trial_id",
      "version",
      "status",
      "active_line",
      "input_sources",
      "trial_policy",
      "scale_tiers",
      "result_contract",
      "simulation_performed",
      "real_items_executed",
      "next_allowed_step"
    )) {
      if ($required -notcontains $field) {
        Add-Failure "SCHEMA_REQUIRED_FIELD_MISSING=$field"
      }
    }
  }

  if ($null -ne $contract) {
    Assert-Equals -Object $contract -Name "scale_trial_id" -Expected "SCALE_TRIAL_10_30_100_ITEM_SIMULATION_V1"
    Assert-Equals -Object $contract -Name "status" -Expected "ACTIVE_SCALE_TRIAL_CONTRACT"
    Assert-Equals -Object $contract -Name "active_line" -Expected "AGENT_BUILDER / SELF_BUILD"
    Assert-Boolean -Object $contract -Name "simulation_performed" -Expected $false
    Assert-Boolean -Object $contract -Name "real_items_executed" -Expected $false
    Assert-Equals -Object $contract -Name "next_allowed_step" -Expected $NextAllowedStep
    $trialPolicy = Get-PropertyValue -Object $contract -Name "trial_policy"
    foreach ($trueField in @(
      "simulation_only",
      "no_real_item_execution",
      "no_external_agent_production",
      "no_external_fetch",
      "no_external_install",
      "no_fake_pass",
      "no_hidden_failures",
      "continue_after_safe_item_failure",
      "quarantine_and_blockers_must_be_counted",
      "systemic_failure_must_stop_tier",
      "promotion_gate_required_next"
    )) {
      Assert-Boolean -Object $trialPolicy -Name $trueField -Expected $true
    }
  }

  if ($null -ne $result) {
    Assert-Equals -Object $result -Name "status" -Expected "SCALE_TRIAL_SIMULATION_COMPLETED"
    Assert-Boolean -Object $result -Name "simulation_performed" -Expected $true
    Assert-Boolean -Object $result -Name "real_items_executed" -Expected $false
    Assert-Boolean -Object $result -Name "external_fetch_performed" -Expected $false
    Assert-Boolean -Object $result -Name "external_install_performed" -Expected $false
    Assert-Boolean -Object $result -Name "external_agent_production_performed" -Expected $false
    Assert-Integer -Object $result -Name "tier_count" -Expected 3
    Assert-Integer -Object $result -Name "total_simulated_item_count" -Expected 140
    Assert-Integer -Object $result -Name "max_item_count_simulated" -Expected 100
    foreach ($tierSize in @(10, 30, 100)) {
      if (@(As-Array (Get-PropertyValue -Object $result -Name "scale_tiers")) -notcontains $tierSize) {
        Add-Failure "SCALE_TIER_MISSING=$tierSize"
      }
    }
    Assert-Boolean -Object $result -Name "no_fake_pass" -Expected $true
    Assert-Boolean -Object $result -Name "no_hidden_failures" -Expected $true
    Assert-Boolean -Object $result -Name "continue_after_safe_failure_simulated" -Expected $true
    Assert-Boolean -Object $result -Name "quarantine_counted" -Expected $true
    Assert-Boolean -Object $result -Name "blockers_counted" -Expected $true
    Assert-Boolean -Object $result -Name "systemic_stop_simulated" -Expected $true
    Assert-Equals -Object $result -Name "scale_trial_result" -Expected "PASS"
    Assert-Boolean -Object $result -Name "promotion_gate_required_next" -Expected $true
    Assert-Equals -Object $result -Name "next_allowed_step" -Expected $NextAllowedStep

    $tiers = @(As-Array (Get-PropertyValue -Object $result -Name "tier_results"))
    if ($tiers.Count -ne 3) {
      Add-Failure "TIER_RESULTS_COUNT_NOT_3"
    }
    $tierCounts = @($tiers | ForEach-Object { [int](Get-PropertyValue -Object $_ -Name "item_count") })
    $sortedTierCounts = @($tierCounts | Sort-Object)
    if (($sortedTierCounts -join ",") -ne "10,30,100") {
      Add-Failure "TIER_RESULT_ITEM_COUNTS_NOT_EXACTLY_10_30_100 actual=$($sortedTierCounts -join ',')"
    }
    $tierItemSum = 0
    foreach ($tierCount in $tierCounts) {
      $tierItemSum += [int]$tierCount
    }
    if ($tierItemSum -ne [int](Get-PropertyValue -Object $result -Name "total_simulated_item_count")) {
      Add-Failure "TIER_ITEM_COUNT_SUM_MISMATCH sum=$tierItemSum total=$(Get-PropertyValue -Object $result -Name "total_simulated_item_count")"
    }
    foreach ($tierSize in @(10, 30, 100)) {
      if ($tierCounts -notcontains $tierSize) {
        Add-Failure "TIER_RESULT_ITEM_COUNT_MISSING=$tierSize"
      }
    }
    $hasSafeFailureContinuation = $false
    $hasQuarantine = $false
    $hasBlocker = $false
    $hasSystemicStop100 = $false
    foreach ($tier in $tiers) {
      Assert-Equals -Object $tier -Name "status" -Expected "TIER_SIMULATION_COMPLETED"
      Assert-Boolean -Object $tier -Name "simulation_performed" -Expected $true
      Assert-Boolean -Object $tier -Name "real_items_executed" -Expected $false
      Assert-Integer -Object $tier -Name "hidden_failure_count" -Expected 0
      Assert-Integer -Object $tier -Name "fake_pass_count" -Expected 0
      Assert-Equals -Object $tier -Name "tier_result" -Expected "PASS"
      if ([bool](Get-PropertyValue -Object $tier -Name "continue_after_safe_failure_used")) {
        $hasSafeFailureContinuation = $true
      }
      if ([int](Get-PropertyValue -Object $tier -Name "simulated_quarantined_count") -gt 0) {
        $hasQuarantine = $true
      }
      if ([int](Get-PropertyValue -Object $tier -Name "simulated_blocked_count") -gt 0) {
        $hasBlocker = $true
      }
      if ([int](Get-PropertyValue -Object $tier -Name "item_count") -eq 100 -and "$(Get-PropertyValue -Object $tier -Name "stop_condition_tested")" -eq "SYSTEMIC_RISK_STOP_SIMULATED") {
        $hasSystemicStop100 = $true
      }
    }
    if (-not $hasSafeFailureContinuation) { Add-Failure "SAFE_FAILURE_CONTINUATION_NOT_SIMULATED" }
    if (-not $hasQuarantine) { Add-Failure "QUARANTINE_NOT_SIMULATED" }
    if (-not $hasBlocker) { Add-Failure "BLOCKER_NOT_SIMULATED" }
    if (-not $hasSystemicStop100) { Add-Failure "SYSTEMIC_STOP_100_TIER_NOT_SIMULATED" }
  }

  if ($null -ne $report) {
    Assert-Equals -Object $report -Name "status" -Expected "PASS"
    Assert-Equals -Object $report -Name "phase" -Expected $Phase
    Assert-Equals -Object $report -Name "active_line" -Expected "AGENT_BUILDER / SELF_BUILD"
    Assert-Equals -Object $report -Name "baseline_commit" -Expected "8606986"
    Assert-Equals -Object $report -Name "scale_trial_status" -Expected "SCALE_TRIAL_SIMULATION_COMPLETED"
    Assert-Boolean -Object $report -Name "simulation_performed" -Expected $true
    Assert-Boolean -Object $report -Name "real_items_executed" -Expected $false
    Assert-Integer -Object $report -Name "tier_count" -Expected 3
    Assert-Integer -Object $report -Name "total_simulated_item_count" -Expected 140
    Assert-Integer -Object $report -Name "max_item_count_simulated" -Expected 100
    Assert-Boolean -Object $report -Name "no_fake_pass" -Expected $true
    Assert-Boolean -Object $report -Name "no_hidden_failures" -Expected $true
    Assert-Boolean -Object $report -Name "external_fetch_performed" -Expected $false
    Assert-Boolean -Object $report -Name "external_install_performed" -Expected $false
    Assert-Boolean -Object $report -Name "external_agent_production_performed" -Expected $false
    Assert-Equals -Object $report -Name "scale_trial_result" -Expected "PASS"
    Assert-Boolean -Object $report -Name "promotion_gate_required_next" -Expected $true
    Assert-Boolean -Object $report -Name "phase106_required_next" -Expected $true
    Assert-Boolean -Object $report -Name "phase106_not_executed" -Expected $true
    Assert-Equals -Object $report -Name "next_allowed_step" -Expected $NextAllowedStep
  }

  if ($null -ne $proof) {
    Assert-Equals -Object $proof -Name "status" -Expected "PASS"
    Assert-Equals -Object $proof -Name "phase" -Expected $Phase
    Assert-Equals -Object $proof -Name "task_id" -Expected $TaskId
    Assert-Equals -Object $proof -Name "runtime_mode" -Expected "SELF_BUILD"
    Assert-Equals -Object $proof -Name "route_lock_version" -Expected "V2_R2"
    Assert-Equals -Object $proof -Name "baseline_commit" -Expected "8606986"
    Assert-Boolean -Object $proof -Name "scale_trial_contract_created" -Expected $true
    Assert-Boolean -Object $proof -Name "schema_created" -Expected $true
    Assert-Boolean -Object $proof -Name "scale_trial_result_created" -Expected $true
    Assert-Equals -Object $proof -Name "scale_trial_status" -Expected "SCALE_TRIAL_SIMULATION_COMPLETED"
    Assert-Boolean -Object $proof -Name "simulation_performed" -Expected $true
    Assert-Boolean -Object $proof -Name "real_items_executed" -Expected $false
    Assert-Integer -Object $proof -Name "tier_count" -Expected 3
    Assert-Integer -Object $proof -Name "total_simulated_item_count" -Expected 140
    Assert-Integer -Object $proof -Name "max_item_count_simulated" -Expected 100
    Assert-Boolean -Object $proof -Name "no_fake_pass" -Expected $true
    Assert-Boolean -Object $proof -Name "no_hidden_failures" -Expected $true
    Assert-Boolean -Object $proof -Name "continue_after_safe_failure_simulated" -Expected $true
    Assert-Boolean -Object $proof -Name "quarantine_counted" -Expected $true
    Assert-Boolean -Object $proof -Name "blockers_counted" -Expected $true
    Assert-Boolean -Object $proof -Name "systemic_stop_simulated" -Expected $true
    Assert-Boolean -Object $proof -Name "external_fetch_performed" -Expected $false
    Assert-Boolean -Object $proof -Name "external_install_performed" -Expected $false
    Assert-Boolean -Object $proof -Name "external_agent_production_performed" -Expected $false
    Assert-Equals -Object $proof -Name "scale_trial_result" -Expected "PASS"
    Assert-Boolean -Object $proof -Name "promotion_gate_required_next" -Expected $true
    Assert-Boolean -Object $proof -Name "phase106_required_next" -Expected $true
    Assert-Boolean -Object $proof -Name "phase106_not_executed" -Expected $true
    Assert-Boolean -Object $proof -Name "queue_returned_to_none" -Expected $true
    Assert-Equals -Object $proof -Name "next_allowed_step" -Expected $NextAllowedStep
  }

  Assert-Equals -Object $queue -Name "active_task_id" -Expected "NONE"
  if ($null -ne $task) {
    Assert-Equals -Object $task -Name "status" -Expected "COMPLETED"
  }
  if ($null -ne $taskFile) {
    Assert-Equals -Object $taskFile -Name "status" -Expected "COMPLETED"
  }
}

if ((Get-SafeCount -Value $script:Failures) -gt 0) {
  foreach ($failure in $script:Failures) {
    Write-Host "FAIL=$failure"
  }
  Write-Host "VALIDATION_RESULT=FAIL"
  throw "PHASE105_VALIDATION_FAILED"
}

if ($Stage -eq "Seed") {
  Write-Host "VALIDATION_RESULT=PASS_SEED"
} else {
  Write-Host "VALIDATION_RESULT=PASS"
}
