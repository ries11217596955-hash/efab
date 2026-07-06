[CmdletBinding()]
param(
  [ValidateSet("Auto", "Seed", "Completed")]
  [string]$Stage = "Auto",
  [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
)

$ErrorActionPreference = "Stop"

$TaskId = "TASK_BUILDER_SELF_PACK_AUTHOR_V1_001"
$PackId = "PHASE107_BUILDER_SELF_PACK_AUTHOR_V1"
$Phase = "PHASE107_BUILDER_SELF_PACK_AUTHOR_V1"
$EntryScript = "packs/PHASE107_BUILDER_SELF_PACK_AUTHOR_V1/APPLY.ps1"
$ValidateScript = "packs/PHASE107_BUILDER_SELF_PACK_AUTHOR_V1/VALIDATE.ps1"
$ModulePath = "modules/self_development/write_builder_self_pack_author_v1.ps1"
$TaskPath = "tasks/TASK_BUILDER_SELF_PACK_AUTHOR_V1_001.json"
$SourceRouteLockPath = "route_locks/AGENT_BUILDER_NEXT_15_STEPS_LOCK_V3_SELF_PACK_AUTHOR.md"
$SourceRouteCorrectionProofPath = "proofs/self_development/SCALE_TRIAL_PROMOTION_GATE_AND_ROUTE_LOCK_REFRESH_V1.json"
$SourceScaleTrialProofPath = "proofs/self_development/SCALE_TRIAL_10_30_100_ITEM_SIMULATION_V1.json"
$SchemaPath = "contracts/self_development/builder_self_pack_author_v1.schema.json"
$AuthorContractPath = "self_build_batch/self_pack_author/BUILDER_SELF_PACK_AUTHOR_V1.json"
$CandidateTarget = "self_build_batch/self_pack_author/generated_candidates/PHASE108_BUILDER_GENERATED_PACK_ADMISSION_V1_CANDIDATE"
$CandidatePackId = "PHASE108_BUILDER_GENERATED_PACK_ADMISSION_V1_CANDIDATE"
$CandidateTaskId = "TASK_BUILDER_GENERATED_PACK_ADMISSION_V1_001"
$CandidatePackPath = Join-Path $CandidateTarget "PACK.json"
$CandidateApplyPath = Join-Path $CandidateTarget "APPLY.ps1"
$CandidateValidatePath = Join-Path $CandidateTarget "VALIDATE.ps1"
$CandidateTaskPath = Join-Path $CandidateTarget "TASK_BUILDER_GENERATED_PACK_ADMISSION_V1_001.json"
$CandidateSpecPath = Join-Path $CandidateTarget "CANDIDATE_SPEC.json"
$CandidateManifestPath = Join-Path $CandidateTarget "GENERATION_MANIFEST.json"
$ReportPath = "reports/self_development/BUILDER_SELF_PACK_AUTHOR_V1_REPORT.json"
$ProofPath = "proofs/self_development/BUILDER_SELF_PACK_AUTHOR_V1.json"
$NextAllowedStep = "PHASE108_BUILDER_GENERATED_PACK_ADMISSION_V1"
$BaselineCommit = "835aa83"
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

function Assert-CandidateNotRegisteredLive {
  param([object]$Registry)

  foreach ($pack in As-Array (Get-PropertyValue -Object $Registry -Name "packs")) {
    if ("$(Get-PropertyValue -Object $pack -Name "pack_id")" -eq $CandidatePackId) {
      Add-Failure "CANDIDATE_REGISTERED_LIVE=$CandidatePackId"
    }
  }
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
  "packs/PHASE107_BUILDER_SELF_PACK_AUTHOR_V1/PACK.json",
  $EntryScript,
  $ValidateScript,
  $TaskPath
)) {
  Assert-FileExists $path
}

foreach ($path in @(
  "packs/PHASE107_BUILDER_SELF_PACK_AUTHOR_V1/PACK.json",
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

$phase106Proof = Read-JsonFile $SourceRouteCorrectionProofPath
if ($null -ne $phase106Proof) {
  Assert-Equals -Object $phase106Proof -Name "status" -Expected "PASS"
  Assert-Equals -Object $phase106Proof -Name "next_allowed_step" -Expected $Phase
  Assert-Boolean -Object $phase106Proof -Name "builder_self_pack_author_required_next" -Expected $true
  Assert-Boolean -Object $phase106Proof -Name "codex_fallback_not_primary" -Expected $true
}

$scaleTrialProof = Read-JsonFile $SourceScaleTrialProofPath
if ($null -ne $scaleTrialProof) {
  Assert-Equals -Object $scaleTrialProof -Name "status" -Expected "PASS"
}

Assert-FileExists $SourceRouteLockPath
$routeLockText = Read-TextFile $SourceRouteLockPath
Assert-TextContains -Text $routeLockText -Needle "PHASE107_BUILDER_SELF_PACK_AUTHOR_V1"
Assert-TextContains -Text $routeLockText -Needle "Builder must author next self-build packs."
Assert-TextContains -Text $routeLockText -Needle "Codex fallback, not primary."

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
  Add-Failure "REGISTRY_FIRST_PACK_NOT_PHASE107"
}
Assert-CandidateNotRegisteredLive -Registry $registry

Assert-FileAbsent "packs/PHASE108_BUILDER_GENERATED_PACK_ADMISSION_V1/PACK.json"
Assert-FileAbsent "tasks/TASK_BUILDER_GENERATED_PACK_ADMISSION_V1_001.json"

if ($Stage -eq "Seed") {
  Assert-Equals -Object $queue -Name "active_task_id" -Expected $TaskId
  if ($null -ne $task) {
    Assert-Equals -Object $task -Name "status" -Expected "READY"
  }
  if ($null -ne $taskFile) {
    Assert-Equals -Object $taskFile -Name "status" -Expected "READY"
    Assert-Equals -Object $taskFile -Name "mode" -Expected "SELF_BUILD"
    Assert-Equals -Object $taskFile -Name "baseline_commit" -Expected $BaselineCommit
    Assert-Equals -Object $taskFile -Name "source_route_lock" -Expected $SourceRouteLockPath
    Assert-Equals -Object $taskFile -Name "source_route_correction_proof" -Expected $SourceRouteCorrectionProofPath
    Assert-Equals -Object $taskFile -Name "generated_candidate_target" -Expected $CandidateTarget
    Assert-Equals -Object $taskFile -Name "next_allowed_step" -Expected $NextAllowedStep
  }
  Assert-FileAbsent $CandidateTarget
  foreach ($path in @(
    $SchemaPath,
    $AuthorContractPath,
    $ReportPath,
    $ProofPath
  )) {
    Assert-FileAbsent $path
  }
}

if ($Stage -eq "Completed") {
  foreach ($path in @(
    $SchemaPath,
    $AuthorContractPath,
    $CandidatePackPath,
    $CandidateApplyPath,
    $CandidateValidatePath,
    $CandidateTaskPath,
    $CandidateSpecPath,
    $CandidateManifestPath,
    $ReportPath,
    $ProofPath
  )) {
    Assert-FileExists $path
  }

  $schema = Read-JsonFile $SchemaPath
  $contract = Read-JsonFile $AuthorContractPath
  $candidatePack = Read-JsonFile $CandidatePackPath
  $candidateTask = Read-JsonFile $CandidateTaskPath
  $candidateSpec = Read-JsonFile $CandidateSpecPath
  $candidateManifest = Read-JsonFile $CandidateManifestPath
  $report = Read-JsonFile $ReportPath
  $proof = Read-JsonFile $ProofPath

  foreach ($script in @($CandidateApplyPath, $CandidateValidatePath)) {
    Assert-ParserPass $script
  }

  if ($null -ne $schema) {
    $required = As-Array (Get-PropertyValue -Object $schema -Name "required")
    foreach ($field in @(
      "author_id",
      "status",
      "active_line",
      "baseline_commit",
      "input_sources",
      "author_policy",
      "candidate_target",
      "next_allowed_step"
    )) {
      if ($required -notcontains $field) {
        Add-Failure "SCHEMA_REQUIRED_FIELD_MISSING=$field"
      }
    }
  }

  if ($null -ne $contract) {
    Assert-Equals -Object $contract -Name "author_id" -Expected "BUILDER_SELF_PACK_AUTHOR_V1"
    Assert-Equals -Object $contract -Name "status" -Expected "ACTIVE_SELF_PACK_AUTHOR"
    Assert-Equals -Object $contract -Name "active_line" -Expected "AGENT_BUILDER / SELF_BUILD"
    Assert-Equals -Object $contract -Name "baseline_commit" -Expected $BaselineCommit
    Assert-Equals -Object $contract -Name "candidate_target" -Expected $CandidateTarget
    Assert-Equals -Object $contract -Name "next_allowed_step" -Expected $NextAllowedStep
    $policy = Get-PropertyValue -Object $contract -Name "author_policy"
    foreach ($trueField in @(
      "builder_runtime_must_generate_candidate",
      "codex_is_bootstrap_only",
      "codex_is_fallback_not_primary",
      "candidate_must_not_be_registered_live",
      "candidate_must_not_be_executed_in_phase107",
      "admission_required_next",
      "no_external_agent_production",
      "no_external_fetch",
      "no_external_install",
      "no_fake_autonomy_claim"
    )) {
      Assert-Boolean -Object $policy -Name $trueField -Expected $true
    }
  }

  if ($null -ne $candidatePack) {
    Assert-Equals -Object $candidatePack -Name "pack_id" -Expected $CandidatePackId
    Assert-Equals -Object $candidatePack -Name "task_id" -Expected $CandidateTaskId
    Assert-Equals -Object $candidatePack -Name "phase" -Expected "PHASE108_CANDIDATE"
    Assert-Equals -Object $candidatePack -Name "mode" -Expected "SELF_BUILD"
    Assert-Equals -Object $candidatePack -Name "generated_by" -Expected "BUILDER_RUNTIME"
    Assert-Equals -Object $candidatePack -Name "generated_during_phase" -Expected $Phase
    Assert-Boolean -Object $candidatePack -Name "not_registered_live" -Expected $true
    Assert-Boolean -Object $candidatePack -Name "execution_allowed" -Expected $false
    Assert-Equals -Object $candidatePack -Name "next_allowed_step" -Expected $NextAllowedStep
  }

  if ($null -ne $candidateTask) {
    Assert-Equals -Object $candidateTask -Name "task_id" -Expected $CandidateTaskId
    Assert-Equals -Object $candidateTask -Name "pack_id" -Expected $CandidatePackId
    Assert-Boolean -Object $candidateTask -Name "execution_allowed" -Expected $false
  }

  if ($null -ne $candidateSpec) {
    Assert-Equals -Object $candidateSpec -Name "candidate_id" -Expected $CandidatePackId
    Assert-Boolean -Object $candidateSpec -Name "generated_by_builder_runtime" -Expected $true
    Assert-Equals -Object $candidateSpec -Name "source_author_contract" -Expected $AuthorContractPath
    Assert-Boolean -Object $candidateSpec -Name "execution_allowed" -Expected $false
    Assert-Equals -Object $candidateSpec -Name "next_allowed_step" -Expected $NextAllowedStep
    $checks = As-Array (Get-PropertyValue -Object $candidateSpec -Name "admission_checks_required")
    foreach ($check in @(
      "JSON parse",
      "PowerShell parse",
      "forbidden scope check",
      "not registered live",
      "not executed",
      "proof requirements present",
      "rollback/safety note present"
    )) {
      if ($checks -notcontains $check) {
        Add-Failure "CANDIDATE_SPEC_CHECK_MISSING=$check"
      }
    }
  }

  if ($null -ne $candidateManifest) {
    Assert-Equals -Object $candidateManifest -Name "generated_by" -Expected "BUILDER_RUNTIME"
    Assert-Equals -Object $candidateManifest -Name "generated_during_phase" -Expected $Phase
    Assert-Equals -Object $candidateManifest -Name "generator_pack_id" -Expected $PackId
    Assert-Equals -Object $candidateManifest -Name "generator_task_id" -Expected $TaskId
    Assert-Equals -Object $candidateManifest -Name "source_route_lock" -Expected $SourceRouteLockPath
    Assert-Boolean -Object $candidateManifest -Name "codex_authored_candidate" -Expected $false
    Assert-Boolean -Object $candidateManifest -Name "candidate_registered_live" -Expected $false
    Assert-Boolean -Object $candidateManifest -Name "candidate_executed" -Expected $false
    Assert-Boolean -Object $candidateManifest -Name "admission_required_next" -Expected $true
    Assert-Boolean -Object $candidateManifest -Name "no_external_fetch" -Expected $true
    Assert-Boolean -Object $candidateManifest -Name "no_external_install" -Expected $true
    Assert-Boolean -Object $candidateManifest -Name "no_external_agent_production" -Expected $true
  }

  if ($null -ne $report) {
    Assert-Equals -Object $report -Name "status" -Expected "PASS"
    Assert-Equals -Object $report -Name "phase" -Expected $Phase
    Assert-Equals -Object $report -Name "active_line" -Expected "AGENT_BUILDER / SELF_BUILD"
    Assert-Equals -Object $report -Name "baseline_commit" -Expected $BaselineCommit
    Assert-Equals -Object $report -Name "self_pack_author_contract_created" -Expected $AuthorContractPath
    Assert-Equals -Object $report -Name "schema_created" -Expected $SchemaPath
    Assert-Boolean -Object $report -Name "builder_generated_candidate_created" -Expected $true
    Assert-Equals -Object $report -Name "generated_candidate_path" -Expected $CandidateTarget
    Assert-Boolean -Object $report -Name "generated_by_builder_runtime" -Expected $true
    Assert-Boolean -Object $report -Name "codex_authored_candidate" -Expected $false
    Assert-Boolean -Object $report -Name "candidate_registered_live" -Expected $false
    Assert-Boolean -Object $report -Name "candidate_executed" -Expected $false
    Assert-Boolean -Object $report -Name "admission_required_next" -Expected $true
    Assert-Boolean -Object $report -Name "full_autonomy_claimed" -Expected $false
    Assert-Boolean -Object $report -Name "codex_fallback_not_primary" -Expected $true
    Assert-Boolean -Object $report -Name "phase108_required_next" -Expected $true
    Assert-Boolean -Object $report -Name "phase108_not_executed" -Expected $true
    Assert-Equals -Object $report -Name "next_allowed_step" -Expected $NextAllowedStep
  }

  if ($null -ne $proof) {
    Assert-Equals -Object $proof -Name "status" -Expected "PASS"
    Assert-Equals -Object $proof -Name "phase" -Expected $Phase
    Assert-Equals -Object $proof -Name "task_id" -Expected $TaskId
    Assert-Equals -Object $proof -Name "runtime_mode" -Expected "SELF_BUILD"
    Assert-Equals -Object $proof -Name "baseline_commit" -Expected $BaselineCommit
    Assert-Boolean -Object $proof -Name "self_pack_author_contract_created" -Expected $true
    Assert-Boolean -Object $proof -Name "schema_created" -Expected $true
    Assert-Boolean -Object $proof -Name "builder_generated_candidate_created" -Expected $true
    Assert-Equals -Object $proof -Name "generated_candidate_path" -Expected $CandidateTarget
    Assert-Boolean -Object $proof -Name "generated_by_builder_runtime" -Expected $true
    Assert-Boolean -Object $proof -Name "codex_bootstrap_only" -Expected $true
    Assert-Boolean -Object $proof -Name "codex_authored_candidate" -Expected $false
    Assert-Boolean -Object $proof -Name "candidate_registered_live" -Expected $false
    Assert-Boolean -Object $proof -Name "candidate_executed" -Expected $false
    Assert-Boolean -Object $proof -Name "admission_required_next" -Expected $true
    Assert-Boolean -Object $proof -Name "full_autonomy_claimed" -Expected $false
    Assert-Boolean -Object $proof -Name "codex_fallback_not_primary" -Expected $true
    Assert-Boolean -Object $proof -Name "no_external_agent_production" -Expected $true
    Assert-Boolean -Object $proof -Name "no_external_fetch" -Expected $true
    Assert-Boolean -Object $proof -Name "no_external_install" -Expected $true
    Assert-Boolean -Object $proof -Name "phase108_required_next" -Expected $true
    Assert-Boolean -Object $proof -Name "phase108_not_executed" -Expected $true
    Assert-Boolean -Object $proof -Name "queue_returned_to_none" -Expected $true
    Assert-Equals -Object $proof -Name "next_allowed_step" -Expected $NextAllowedStep
  }

  $roadmapPhase = Get-PropertyValue -Object $roadmap -Name "phase107_builder_self_pack_author_v1"
  if ($null -eq $roadmapPhase) {
    Add-Failure "ROADMAP_PHASE107_MISSING"
  } else {
    Assert-Equals -Object $roadmapPhase -Name "status" -Expected "COMPLETED"
    Assert-Equals -Object $roadmapPhase -Name "next_allowed_step" -Expected $NextAllowedStep
  }

  $genesisMarker = Get-PropertyValue -Object $genesis -Name "builder_self_pack_author_v1"
  if ($null -eq $genesisMarker) {
    Add-Failure "GENESIS_BUILDER_SELF_PACK_AUTHOR_MARKER_MISSING"
  } else {
    Assert-Equals -Object $genesisMarker -Name "status" -Expected "PROVEN"
    Assert-Equals -Object $genesisMarker -Name "next_allowed_step" -Expected $NextAllowedStep
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
  throw "PHASE107_VALIDATION_FAILED"
}

if ($Stage -eq "Seed") {
  Write-Host "VALIDATION_RESULT=PASS_SEED"
} else {
  Write-Host "VALIDATION_RESULT=PASS"
}
