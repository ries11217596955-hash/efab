[CmdletBinding()]
param(
  [ValidateSet("Auto", "Seed", "Completed")]
  [string]$Stage = "Auto",
  [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
)

$ErrorActionPreference = "Stop"

$TaskId = "TASK_SCALE_TRIAL_PROMOTION_GATE_AND_ROUTE_LOCK_REFRESH_V1_001"
$PackId = "PHASE106_SCALE_TRIAL_PROMOTION_GATE_AND_ROUTE_LOCK_REFRESH_V1"
$Phase = "PHASE106_SCALE_TRIAL_PROMOTION_GATE_AND_ROUTE_LOCK_REFRESH_V1"
$EntryScript = "packs/PHASE106_SCALE_TRIAL_PROMOTION_GATE_AND_ROUTE_LOCK_REFRESH_V1/APPLY.ps1"
$ValidateScript = "packs/PHASE106_SCALE_TRIAL_PROMOTION_GATE_AND_ROUTE_LOCK_REFRESH_V1/VALIDATE.ps1"
$ModulePath = "modules/self_development/write_scale_trial_promotion_gate_and_route_lock_refresh_v1.ps1"
$TaskPath = "tasks/TASK_SCALE_TRIAL_PROMOTION_GATE_AND_ROUTE_LOCK_REFRESH_V1_001.json"
$SourceScaleTrialProofPath = "proofs/self_development/SCALE_TRIAL_10_30_100_ITEM_SIMULATION_V1.json"
$SourceScaleTrialResultPath = "self_build_batch/scale_trials/BATCH_PLAN_EXAMPLE_V1_SCALE_TRIAL_RESULT.json"
$SchemaPath = "contracts/self_development/scale_trial_promotion_gate_and_route_lock_refresh_v1.schema.json"
$RouteLockV3Path = "route_locks/AGENT_BUILDER_NEXT_15_STEPS_LOCK_V3_SELF_PACK_AUTHOR.md"
$RouteTransitionReportPath = "reports/route_locks/ROUTE_V2_R2_TO_V3_SELF_PACK_AUTHOR_REPORT.json"
$RouteTransitionProofPath = "proofs/route_locks/ROUTE_V2_R2_TO_V3_SELF_PACK_AUTHOR_PROOF.json"
$ReportPath = "reports/self_development/SCALE_TRIAL_PROMOTION_GATE_AND_ROUTE_LOCK_REFRESH_V1_REPORT.json"
$ProofPath = "proofs/self_development/SCALE_TRIAL_PROMOTION_GATE_AND_ROUTE_LOCK_REFRESH_V1.json"
$NextAllowedStep = "PHASE107_BUILDER_SELF_PACK_AUTHOR_V1"
$BaselineCommit = "e66cf8e"
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

function Read-TextFile {
  param([string]$Path)

  $fullPath = Join-RepoPath $Path
  if (-not (Test-Path -LiteralPath $fullPath)) {
    Add-Failure "MISSING_TEXT=$Path"
    return ""
  }
  return (Get-Content -LiteralPath $fullPath -Raw)
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

function Assert-TextContains {
  param(
    [string]$Text,
    [string]$Needle
  )

  if ($Text -notmatch [regex]::Escape($Needle)) {
    Add-Failure "TEXT_MISSING=$Needle"
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
  "packs/PHASE106_SCALE_TRIAL_PROMOTION_GATE_AND_ROUTE_LOCK_REFRESH_V1/PACK.json",
  $EntryScript,
  $ValidateScript,
  $TaskPath
)) {
  Assert-FileExists $path
}

foreach ($path in @(
  "packs/PHASE106_SCALE_TRIAL_PROMOTION_GATE_AND_ROUTE_LOCK_REFRESH_V1/PACK.json",
  $TaskPath,
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

$scaleTrialProof = Read-JsonFile $SourceScaleTrialProofPath
if ($null -ne $scaleTrialProof) {
  Assert-Equals -Object $scaleTrialProof -Name "status" -Expected "PASS"
  Assert-Boolean -Object $scaleTrialProof -Name "simulation_performed" -Expected $true
  Assert-Boolean -Object $scaleTrialProof -Name "real_items_executed" -Expected $false
  Assert-Integer -Object $scaleTrialProof -Name "total_simulated_item_count" -Expected 140
  Assert-Boolean -Object $scaleTrialProof -Name "no_fake_pass" -Expected $true
  Assert-Boolean -Object $scaleTrialProof -Name "no_hidden_failures" -Expected $true
}

$scaleTrialResult = Read-JsonFile $SourceScaleTrialResultPath
if ($null -ne $scaleTrialResult) {
  Assert-Equals -Object $scaleTrialResult -Name "status" -Expected "SCALE_TRIAL_SIMULATION_COMPLETED"
  Assert-Integer -Object $scaleTrialResult -Name "total_simulated_item_count" -Expected 140
  Assert-Boolean -Object $scaleTrialResult -Name "no_fake_pass" -Expected $true
  Assert-Boolean -Object $scaleTrialResult -Name "no_hidden_failures" -Expected $true
}

$queue = Read-JsonFile "TASK_QUEUE.json"
$registry = Read-JsonFile "packs/registry.json"
$roadmap = Read-JsonFile "CAPABILITY_ROADMAP.json"
$genesis = Read-JsonFile "GENESIS_STATE.json"
$task = Find-TaskEntry -Queue $queue
$taskFile = Read-JsonFile $TaskPath
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
  Add-Failure "REGISTRY_FIRST_PACK_NOT_PHASE106"
}

Assert-FileAbsent "packs/PHASE107_BUILDER_SELF_PACK_AUTHOR_V1/PACK.json"
Assert-FileAbsent "tasks/TASK_BUILDER_SELF_PACK_AUTHOR_V1_001.json"

if ($Stage -eq "Seed") {
  Assert-Equals -Object $queue -Name "active_task_id" -Expected $TaskId
  if ($null -ne $task) {
    Assert-Equals -Object $task -Name "status" -Expected "READY"
  }
  if ($null -ne $taskFile) {
    Assert-Equals -Object $taskFile -Name "status" -Expected "READY"
    Assert-Equals -Object $taskFile -Name "mode" -Expected "SELF_BUILD"
    Assert-Equals -Object $taskFile -Name "baseline_commit" -Expected $BaselineCommit
    Assert-Equals -Object $taskFile -Name "source_scale_trial_proof" -Expected $SourceScaleTrialProofPath
    Assert-Equals -Object $taskFile -Name "source_scale_trial_result" -Expected $SourceScaleTrialResultPath
    Assert-Equals -Object $taskFile -Name "next_allowed_step" -Expected $NextAllowedStep
  }
  foreach ($path in @(
    $SchemaPath,
    $RouteLockV3Path,
    $RouteTransitionReportPath,
    $RouteTransitionProofPath,
    $ReportPath,
    $ProofPath
  )) {
    Assert-FileAbsent $path
  }
}

if ($Stage -eq "Completed") {
  $schema = Read-JsonFile $SchemaPath
  $routeLockText = Read-TextFile $RouteLockV3Path
  $routeReport = Read-JsonFile $RouteTransitionReportPath
  $routeProof = Read-JsonFile $RouteTransitionProofPath
  $report = Read-JsonFile $ReportPath
  $proof = Read-JsonFile $ProofPath

  if ($null -ne $schema) {
    $required = As-Array (Get-PropertyValue -Object $schema -Name "required")
    foreach ($field in @(
      "status",
      "phase",
      "active_line",
      "baseline_commit",
      "scale_trial_promoted_as",
      "full_autonomy_claimed",
      "codex_dependency_risk_recorded",
      "route_correction_created",
      "route_lock_v3_created",
      "builder_self_pack_author_required_next",
      "codex_fallback_not_primary",
      "phase107_not_executed",
      "next_allowed_step"
    )) {
      if ($required -notcontains $field) {
        Add-Failure "SCHEMA_REQUIRED_FIELD_MISSING=$field"
      }
    }
  }

  foreach ($needle in @(
    "route_lock_id: AGENT_BUILDER_NEXT_15_STEPS_LOCK_V3_SELF_PACK_AUTHOR",
    "status: ACTIVE_ROUTE_LOCK",
    "supersedes: AGENT_BUILDER_NEXT_15_STEPS_LOCK_V2_R2",
    "active_line: AGENT_BUILDER / SELF_BUILD",
    "proven_baseline_commit: e66cf8e",
    "proven_baseline_phase: PHASE105_SCALE_TRIAL_10_30_100_ITEM_SIMULATION_V1",
    "Codex has been bootstrap author too often.",
    "Builder must author next self-build packs.",
    "Codex becomes fallback only.",
    "Codex fallback, not primary.",
    "PHASE107_BUILDER_SELF_PACK_AUTHOR_V1",
    "PHASE108_BUILDER_GENERATED_PACK_ADMISSION_V1",
    "PHASE109_BUILDER_EXECUTES_OWN_GENERATED_NEXT_PACK_V1",
    "PHASE110_CODEX_FALLBACK_LIMITER_V1",
    "PHASE111_SELF_PACK_AUTHOR_SCALE_TRIAL_V1",
    "external agent production before self-pack author gate",
    "material acquisition runtime without policy/admission",
    "Codex as primary author for every next pack",
    "fake autonomy claims"
  )) {
    Assert-TextContains -Text $routeLockText -Needle $needle
  }

  if ($null -ne $routeReport) {
    Assert-Equals -Object $routeReport -Name "status" -Expected "PASS"
    Assert-Equals -Object $routeReport -Name "phase" -Expected $Phase
    Assert-Equals -Object $routeReport -Name "active_line" -Expected "AGENT_BUILDER / SELF_BUILD"
    Assert-Equals -Object $routeReport -Name "baseline_commit" -Expected $BaselineCommit
    Assert-Equals -Object $routeReport -Name "route_lock_created" -Expected $RouteLockV3Path
    Assert-Boolean -Object $routeReport -Name "codex_dependency_risk_recorded" -Expected $true
    Assert-Boolean -Object $routeReport -Name "builder_self_pack_author_required_next" -Expected $true
    Assert-Boolean -Object $routeReport -Name "codex_fallback_not_primary" -Expected $true
    Assert-Equals -Object $routeReport -Name "next_allowed_step" -Expected $NextAllowedStep
  }

  if ($null -ne $routeProof) {
    Assert-Equals -Object $routeProof -Name "status" -Expected "PASS"
    Assert-Equals -Object $routeProof -Name "phase" -Expected $Phase
    Assert-Equals -Object $routeProof -Name "task_id" -Expected $TaskId
    Assert-Equals -Object $routeProof -Name "runtime_mode" -Expected "SELF_BUILD"
    Assert-Equals -Object $routeProof -Name "route_lock_path" -Expected $RouteLockV3Path
    Assert-Boolean -Object $routeProof -Name "codex_dependency_risk_recorded" -Expected $true
    Assert-Boolean -Object $routeProof -Name "builder_self_pack_author_required_next" -Expected $true
    Assert-Boolean -Object $routeProof -Name "codex_fallback_not_primary" -Expected $true
    Assert-Boolean -Object $routeProof -Name "phase107_not_executed" -Expected $true
    Assert-Equals -Object $routeProof -Name "next_allowed_step" -Expected $NextAllowedStep
  }

  if ($null -ne $report) {
    Assert-Equals -Object $report -Name "status" -Expected "PASS"
    Assert-Equals -Object $report -Name "phase" -Expected $Phase
    Assert-Equals -Object $report -Name "active_line" -Expected "AGENT_BUILDER / SELF_BUILD"
    Assert-Equals -Object $report -Name "baseline_commit" -Expected $BaselineCommit
    Assert-Equals -Object $report -Name "scale_trial_promoted_as" -Expected "SIMULATION_PROVEN"
    Assert-Boolean -Object $report -Name "full_autonomy_claimed" -Expected $false
    Assert-Boolean -Object $report -Name "codex_dependency_risk_recorded" -Expected $true
    Assert-Boolean -Object $report -Name "route_correction_created" -Expected $true
    Assert-Equals -Object $report -Name "route_lock_v3_created" -Expected $RouteLockV3Path
    Assert-Equals -Object $report -Name "next_allowed_step" -Expected $NextAllowedStep
    Assert-Boolean -Object $report -Name "phase107_not_executed" -Expected $true
  }

  if ($null -ne $proof) {
    Assert-Equals -Object $proof -Name "status" -Expected "PASS"
    Assert-Equals -Object $proof -Name "phase" -Expected $Phase
    Assert-Equals -Object $proof -Name "task_id" -Expected $TaskId
    Assert-Equals -Object $proof -Name "runtime_mode" -Expected "SELF_BUILD"
    Assert-Equals -Object $proof -Name "baseline_commit" -Expected $BaselineCommit
    Assert-Boolean -Object $proof -Name "scale_trial_proof_verified" -Expected $true
    Assert-Equals -Object $proof -Name "scale_trial_promoted_as" -Expected "SIMULATION_PROVEN"
    Assert-Boolean -Object $proof -Name "full_autonomy_claimed" -Expected $false
    Assert-Boolean -Object $proof -Name "codex_dependency_risk_recorded" -Expected $true
    Assert-Boolean -Object $proof -Name "route_correction_created" -Expected $true
    Assert-Boolean -Object $proof -Name "route_lock_v3_created" -Expected $true
    Assert-Boolean -Object $proof -Name "builder_self_pack_author_required_next" -Expected $true
    Assert-Boolean -Object $proof -Name "codex_fallback_not_primary" -Expected $true
    Assert-Boolean -Object $proof -Name "no_external_agent_production" -Expected $true
    Assert-Boolean -Object $proof -Name "no_external_fetch" -Expected $true
    Assert-Boolean -Object $proof -Name "no_external_install" -Expected $true
    Assert-Boolean -Object $proof -Name "phase107_not_executed" -Expected $true
    Assert-Boolean -Object $proof -Name "queue_returned_to_none" -Expected $true
    Assert-Equals -Object $proof -Name "next_allowed_step" -Expected $NextAllowedStep
  }

  $roadmapPhase = Get-PropertyValue -Object $roadmap -Name "phase106_scale_trial_promotion_gate_and_route_lock_refresh_v1"
  if ($null -eq $roadmapPhase) {
    Add-Failure "ROADMAP_PHASE106_MISSING"
  } else {
    Assert-Equals -Object $roadmapPhase -Name "status" -Expected "COMPLETED"
    Assert-Equals -Object $roadmapPhase -Name "next_allowed_step" -Expected $NextAllowedStep
  }

  $genesisRouteLock = Get-PropertyValue -Object $genesis -Name "route_lock_v3_self_pack_author"
  if ($null -eq $genesisRouteLock) {
    Add-Failure "GENESIS_ROUTE_LOCK_V3_MARKER_MISSING"
  } else {
    Assert-Equals -Object $genesisRouteLock -Name "status" -Expected "ACTIVE_ROUTE_LOCK"
    Assert-Equals -Object $genesisRouteLock -Name "route_lock" -Expected $RouteLockV3Path
    Assert-Equals -Object $genesisRouteLock -Name "next_allowed_step" -Expected $NextAllowedStep
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
  throw "PHASE106_VALIDATION_FAILED"
}

if ($Stage -eq "Seed") {
  Write-Host "VALIDATION_RESULT=PASS_SEED"
} else {
  Write-Host "VALIDATION_RESULT=PASS"
}
