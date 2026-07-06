[CmdletBinding()]
param(
  [ValidateSet("Auto", "Seed", "Completed")]
  [string]$Stage = "Auto",
  [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
)

$ErrorActionPreference = "Stop"

$TaskId = "TASK_CONTROLLED_MULTI_CYCLE_SELF_BUILD_RUN_V1_001"
$PackId = "PHASE104_CONTROLLED_MULTI_CYCLE_SELF_BUILD_RUN_V1"
$Phase = "PHASE104_CONTROLLED_MULTI_CYCLE_SELF_BUILD_RUN_V1"
$EntryScript = "packs/PHASE104_CONTROLLED_MULTI_CYCLE_SELF_BUILD_RUN_V1/APPLY.ps1"
$ValidateScript = "packs/PHASE104_CONTROLLED_MULTI_CYCLE_SELF_BUILD_RUN_V1/VALIDATE.ps1"
$ModulePath = "modules/self_development/write_controlled_multi_cycle_self_build_run_v1.ps1"
$SelectedProgram = "REPAIR_PROGRAM_SELF_BUILD_REQUIRED_MODULES_001"
$SelectedProgramType = "SELF_BUILD_REQUIRED_MODULES_PROGRAM"
$NextAllowedStep = "PHASE105_SCALE_TRIAL_10_30_100_ITEM_SIMULATION_V1"
$SchemaPath = "contracts/self_development/controlled_multi_cycle_self_build_run_v1.schema.json"
$ControlledRunContractPath = "self_build_batch/controlled_runs/CONTROLLED_MULTI_CYCLE_SELF_BUILD_RUN_V1.json"
$ControlledRunResultPath = "self_build_batch/controlled_runs/BATCH_PLAN_EXAMPLE_V1_CONTROLLED_MULTI_CYCLE_RUN_RESULT.json"
$ReportPath = "reports/self_development/CONTROLLED_MULTI_CYCLE_SELF_BUILD_RUN_V1_REPORT.json"
$ProofPath = "proofs/self_development/CONTROLLED_MULTI_CYCLE_SELF_BUILD_RUN_V1.json"
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
  "packs/PHASE104_CONTROLLED_MULTI_CYCLE_SELF_BUILD_RUN_V1/PACK.json",
  $EntryScript,
  $ValidateScript,
  "tasks/TASK_CONTROLLED_MULTI_CYCLE_SELF_BUILD_RUN_V1_001.json"
)) {
  Assert-FileExists $path
}

foreach ($path in @(
  "packs/PHASE104_CONTROLLED_MULTI_CYCLE_SELF_BUILD_RUN_V1/PACK.json",
  "tasks/TASK_CONTROLLED_MULTI_CYCLE_SELF_BUILD_RUN_V1_001.json",
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

$phase103Proof = Read-JsonFile "proofs/self_development/REPAIR_LOOP_GENERATOR_V1.json"
if ($null -ne $phase103Proof) {
  Assert-Equals -Object $phase103Proof -Name "status" -Expected "PASS"
  Assert-Equals -Object $phase103Proof -Name "next_allowed_step" -Expected $Phase
}

$phase103Bundle = Read-JsonFile "self_build_batch/repair_loop/BATCH_PLAN_EXAMPLE_V1_REPAIR_LOOP_PROGRAMS_DRY_RUN.json"
if ($null -ne $phase103Bundle) {
  Assert-Equals -Object $phase103Bundle -Name "selected_program_for_next_cycle" -Expected $SelectedProgram
}

$queue = Read-JsonFile "TASK_QUEUE.json"
$registry = Read-JsonFile "packs/registry.json"
$task = Find-TaskEntry -Queue $queue
$taskFile = Read-JsonFile "tasks/TASK_CONTROLLED_MULTI_CYCLE_SELF_BUILD_RUN_V1_001.json"
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
  Add-Failure "REGISTRY_FIRST_PACK_NOT_PHASE104"
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
    $ControlledRunContractPath,
    $ControlledRunResultPath,
    $ReportPath,
    $ProofPath
  )) {
    Assert-FileAbsent $path
  }
}

if ($Stage -eq "Completed") {
  $schema = Read-JsonFile $SchemaPath
  $contract = Read-JsonFile $ControlledRunContractPath
  $result = Read-JsonFile $ControlledRunResultPath
  $report = Read-JsonFile $ReportPath
  $proof = Read-JsonFile $ProofPath

  if ($null -ne $schema) {
    $required = As-Array (Get-PropertyValue -Object $schema -Name "required")
    foreach ($field in @(
      "controlled_run_id",
      "version",
      "status",
      "active_line",
      "input_sources",
      "run_policy",
      "cycle_contract",
      "selected_program",
      "max_cycles",
      "cycles",
      "cycle_count",
      "execution_performed",
      "next_allowed_step"
    )) {
      if ($required -notcontains $field) {
        Add-Failure "SCHEMA_REQUIRED_FIELD_MISSING=$field"
      }
    }
  }

  if ($null -ne $contract) {
    Assert-Equals -Object $contract -Name "controlled_run_id" -Expected "CONTROLLED_MULTI_CYCLE_SELF_BUILD_RUN_V1"
    Assert-Equals -Object $contract -Name "status" -Expected "ACTIVE_CONTROLLED_RUN_CONTRACT"
    Assert-Equals -Object $contract -Name "active_line" -Expected "AGENT_BUILDER / SELF_BUILD"
    Assert-Equals -Object $contract -Name "selected_program" -Expected $SelectedProgram
    Assert-Equals -Object $contract -Name "next_allowed_step" -Expected $NextAllowedStep
    $runPolicy = Get-PropertyValue -Object $contract -Name "run_policy"
    foreach ($trueField in @(
      "bounded_run_required",
      "selected_program_only",
      "self_resolution_first",
      "assistance_is_fallback",
      "execute_self_build_program_only",
      "material_acquisition_forbidden_in_phase104",
      "safe_patch_execution_forbidden_in_phase104",
      "external_fetch_forbidden",
      "external_install_forbidden",
      "external_agent_production_forbidden",
      "stop_on_policy_violation",
      "stop_on_missing_proof_requirement",
      "proof_required_after_cycle",
      "queue_must_return_to_none"
    )) {
      Assert-Boolean -Object $runPolicy -Name $trueField -Expected $true
    }
    Assert-Integer -Object $runPolicy -Name "max_cycles" -Expected 2
    Assert-Integer -Object $runPolicy -Name "max_programs_executed" -Expected 1
  }

  if ($null -ne $result) {
    Assert-Equals -Object $result -Name "status" -Expected "CONTROLLED_RUN_COMPLETED"
    Assert-Equals -Object $result -Name "selected_program" -Expected $SelectedProgram
    Assert-Equals -Object $result -Name "selected_program_type" -Expected $SelectedProgramType
    Assert-Boolean -Object $result -Name "execution_performed" -Expected $true
    Assert-Boolean -Object $result -Name "controlled_execution_only" -Expected $true
    Assert-Integer -Object $result -Name "max_cycles" -Expected 2
    Assert-Integer -Object $result -Name "cycle_count" -Expected 2
    Assert-Integer -Object $result -Name "cycles_attempted_count" -Expected 2
    Assert-Integer -Object $result -Name "programs_selected_count" -Expected 1
    Assert-Integer -Object $result -Name "programs_executed_count" -Expected 1
    Assert-Integer -Object $result -Name "material_acquisition_executed_count" -Expected 0
    Assert-Integer -Object $result -Name "safe_patch_executed_count" -Expected 0
    Assert-Boolean -Object $result -Name "external_fetch_performed" -Expected $false
    Assert-Boolean -Object $result -Name "external_install_performed" -Expected $false
    Assert-Boolean -Object $result -Name "external_agent_production_performed" -Expected $false
    Assert-Equals -Object $result -Name "stop_reason" -Expected "MAX_CYCLES_REACHED"
    Assert-Equals -Object $result -Name "run_result" -Expected "PASS"
    Assert-Boolean -Object $result -Name "phase105_required_next" -Expected $true
    Assert-Equals -Object $result -Name "next_allowed_step" -Expected $NextAllowedStep

    $cycles = @(As-Array (Get-PropertyValue -Object $result -Name "cycles"))
    if ($cycles.Count -ne 2) {
      Add-Failure "RESULT_CYCLE_COUNT_NOT_2"
    } else {
      Assert-Equals -Object $cycles[0] -Name "cycle_id" -Expected "CYCLE_001_SELECT_AND_ADMIT_SELF_BUILD_PROGRAM"
      Assert-Equals -Object $cycles[0] -Name "status" -Expected "PASS"
      Assert-Equals -Object $cycles[0] -Name "selected_program" -Expected $SelectedProgram
      Assert-Equals -Object $cycles[0] -Name "admission_result" -Expected "ADMITTED_FOR_CONTROLLED_INTERNAL_RUN"
      Assert-Equals -Object $cycles[1] -Name "cycle_id" -Expected "CYCLE_002_EXECUTE_CONTROLLED_SELF_BUILD_PROGRAM"
      Assert-Equals -Object $cycles[1] -Name "status" -Expected "PASS"
      Assert-Equals -Object $cycles[1] -Name "program_type" -Expected $SelectedProgramType
      Assert-Equals -Object $cycles[1] -Name "execution_scope" -Expected "CONTROLLED_INTERNAL_SELF_BUILD_ONLY"
      Assert-Boolean -Object $cycles[1] -Name "proof_recorded" -Expected $true
      Assert-Boolean -Object $cycles[1] -Name "material_acquisition_performed" -Expected $false
      Assert-Boolean -Object $cycles[1] -Name "external_fetch_performed" -Expected $false
      Assert-Boolean -Object $cycles[1] -Name "external_install_performed" -Expected $false
      Assert-Boolean -Object $cycles[1] -Name "external_agent_production_performed" -Expected $false
    }
  }

  if ($null -ne $report) {
    Assert-Equals -Object $report -Name "status" -Expected "PASS"
    Assert-Equals -Object $report -Name "phase" -Expected $Phase
    Assert-Equals -Object $report -Name "active_line" -Expected "AGENT_BUILDER / SELF_BUILD"
    Assert-Equals -Object $report -Name "baseline_commit" -Expected "fdf079d"
    Assert-Equals -Object $report -Name "controlled_run_status" -Expected "CONTROLLED_RUN_COMPLETED"
    Assert-Equals -Object $report -Name "selected_program" -Expected $SelectedProgram
    Assert-Equals -Object $report -Name "selected_program_type" -Expected $SelectedProgramType
    Assert-Boolean -Object $report -Name "execution_performed" -Expected $true
    Assert-Boolean -Object $report -Name "controlled_execution_only" -Expected $true
    Assert-Integer -Object $report -Name "max_cycles" -Expected 2
    Assert-Integer -Object $report -Name "cycle_count" -Expected 2
    Assert-Integer -Object $report -Name "programs_executed_count" -Expected 1
    Assert-Integer -Object $report -Name "material_acquisition_executed_count" -Expected 0
    Assert-Integer -Object $report -Name "safe_patch_executed_count" -Expected 0
    Assert-Boolean -Object $report -Name "external_fetch_performed" -Expected $false
    Assert-Boolean -Object $report -Name "external_install_performed" -Expected $false
    Assert-Boolean -Object $report -Name "external_agent_production_performed" -Expected $false
    Assert-Equals -Object $report -Name "stop_reason" -Expected "MAX_CYCLES_REACHED"
    Assert-Equals -Object $report -Name "run_result" -Expected "PASS"
    Assert-Boolean -Object $report -Name "phase105_required_next" -Expected $true
    Assert-Boolean -Object $report -Name "no_external_agent_production" -Expected $true
    Assert-Boolean -Object $report -Name "no_external_install" -Expected $true
    Assert-Boolean -Object $report -Name "no_external_fetch" -Expected $true
    Assert-Boolean -Object $report -Name "phase105_not_executed" -Expected $true
    Assert-Equals -Object $report -Name "next_allowed_step" -Expected $NextAllowedStep
  }

  if ($null -ne $proof) {
    Assert-Equals -Object $proof -Name "status" -Expected "PASS"
    Assert-Equals -Object $proof -Name "phase" -Expected $Phase
    Assert-Equals -Object $proof -Name "task_id" -Expected $TaskId
    Assert-Equals -Object $proof -Name "runtime_mode" -Expected "SELF_BUILD"
    Assert-Equals -Object $proof -Name "route_lock_version" -Expected "V2_R2"
    Assert-Equals -Object $proof -Name "baseline_commit" -Expected "fdf079d"
    Assert-Boolean -Object $proof -Name "controlled_run_contract_created" -Expected $true
    Assert-Boolean -Object $proof -Name "schema_created" -Expected $true
    Assert-Boolean -Object $proof -Name "controlled_run_result_created" -Expected $true
    Assert-Equals -Object $proof -Name "controlled_run_status" -Expected "CONTROLLED_RUN_COMPLETED"
    Assert-Equals -Object $proof -Name "selected_program" -Expected $SelectedProgram
    Assert-Equals -Object $proof -Name "selected_program_type" -Expected $SelectedProgramType
    Assert-Boolean -Object $proof -Name "self_resolution_first" -Expected $true
    Assert-Boolean -Object $proof -Name "assistance_is_fallback" -Expected $true
    Assert-Boolean -Object $proof -Name "execution_performed" -Expected $true
    Assert-Boolean -Object $proof -Name "controlled_execution_only" -Expected $true
    Assert-Integer -Object $proof -Name "max_cycles" -Expected 2
    Assert-Integer -Object $proof -Name "cycle_count" -Expected 2
    Assert-Integer -Object $proof -Name "programs_executed_count" -Expected 1
    Assert-Integer -Object $proof -Name "material_acquisition_executed_count" -Expected 0
    Assert-Integer -Object $proof -Name "safe_patch_executed_count" -Expected 0
    Assert-Boolean -Object $proof -Name "external_fetch_performed" -Expected $false
    Assert-Boolean -Object $proof -Name "external_install_performed" -Expected $false
    Assert-Boolean -Object $proof -Name "external_agent_production_performed" -Expected $false
    Assert-Equals -Object $proof -Name "stop_reason" -Expected "MAX_CYCLES_REACHED"
    Assert-Equals -Object $proof -Name "run_result" -Expected "PASS"
    Assert-Boolean -Object $proof -Name "phase105_required_next" -Expected $true
    Assert-Boolean -Object $proof -Name "no_external_agent_production" -Expected $true
    Assert-Boolean -Object $proof -Name "no_external_install" -Expected $true
    Assert-Boolean -Object $proof -Name "no_external_fetch" -Expected $true
    Assert-Boolean -Object $proof -Name "phase105_not_executed" -Expected $true
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
  throw "PHASE104_VALIDATION_FAILED"
}

if ($Stage -eq "Seed") {
  Write-Host "VALIDATION_RESULT=PASS_SEED"
} else {
  Write-Host "VALIDATION_RESULT=PASS"
}
