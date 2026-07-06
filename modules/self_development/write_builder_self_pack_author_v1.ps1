[CmdletBinding()]
param(
  [string]$SourceRouteLockPath = "route_locks/AGENT_BUILDER_NEXT_15_STEPS_LOCK_V3_SELF_PACK_AUTHOR.md",
  [string]$SourceRouteCorrectionProofPath = "proofs/self_development/SCALE_TRIAL_PROMOTION_GATE_AND_ROUTE_LOCK_REFRESH_V1.json",
  [string]$SourceScaleTrialProofPath = "proofs/self_development/SCALE_TRIAL_10_30_100_ITEM_SIMULATION_V1.json",
  [string]$SchemaPath = "contracts/self_development/builder_self_pack_author_v1.schema.json",
  [string]$AuthorContractPath = "self_build_batch/self_pack_author/BUILDER_SELF_PACK_AUTHOR_V1.json",
  [string]$CandidateTarget = "self_build_batch/self_pack_author/generated_candidates/PHASE108_BUILDER_GENERATED_PACK_ADMISSION_V1_CANDIDATE",
  [string]$ReportPath = "reports/self_development/BUILDER_SELF_PACK_AUTHOR_V1_REPORT.json",
  [string]$ProofPath = "proofs/self_development/BUILDER_SELF_PACK_AUTHOR_V1.json",
  [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
)

$ErrorActionPreference = "Stop"

$TaskId = "TASK_BUILDER_SELF_PACK_AUTHOR_V1_001"
$PackId = "PHASE107_BUILDER_SELF_PACK_AUTHOR_V1"
$Phase = "PHASE107_BUILDER_SELF_PACK_AUTHOR_V1"
$ActiveLine = "AGENT_BUILDER / SELF_BUILD"
$BaselineCommit = "835aa83"
$NextAllowedStep = "PHASE108_BUILDER_GENERATED_PACK_ADMISSION_V1"
$CandidateId = "PHASE108_BUILDER_GENERATED_PACK_ADMISSION_V1_CANDIDATE"
$CandidateTaskId = "TASK_BUILDER_GENERATED_PACK_ADMISSION_V1_001"

function Join-RepoPath {
  param([string]$Path)

  if ([System.IO.Path]::IsPathRooted($Path)) {
    return [System.IO.Path]::GetFullPath($Path)
  }
  return [System.IO.Path]::GetFullPath((Join-Path $RepoRoot $Path))
}

function Get-UtcStamp {
  return (Get-Date).ToUniversalTime().ToString("o")
}

function Read-JsonRequired {
  param([string]$Path)

  $fullPath = Join-RepoPath $Path
  if (-not (Test-Path -LiteralPath $fullPath)) {
    throw "MISSING_JSON=$Path"
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

function Write-TextFile {
  param(
    [string]$Path,
    [string]$Content
  )

  $fullPath = Join-RepoPath $Path
  $directory = Split-Path -Parent $fullPath
  if (-not (Test-Path -LiteralPath $directory)) {
    New-Item -ItemType Directory -Path $directory -Force | Out-Null
  }
  if (-not $Content.EndsWith("`n")) {
    $Content += "`n"
  }
  [System.IO.File]::WriteAllText($fullPath, $Content, [System.Text.UTF8Encoding]::new($false))
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

function Assert-Equals {
  param(
    [object]$Object,
    [string]$Name,
    [object]$Expected
  )

  $actual = Get-PropertyValue -Object $Object -Name $Name
  if ("$actual" -ne "$Expected") {
    throw "$($Name.ToUpperInvariant())_MISMATCH expected=$Expected actual=$actual"
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
    throw "$($Name.ToUpperInvariant())_MISMATCH expected=$Expected actual=$actual"
  }
}

function Assert-TextContains {
  param(
    [string]$Text,
    [string]$Needle
  )

  if ($Text -notmatch [regex]::Escape($Needle)) {
    throw "TEXT_MISSING=$Needle"
  }
}

function Assert-CandidateNotRegisteredLive {
  $registry = Read-JsonRequired "packs/registry.json"
  foreach ($pack in As-Array (Get-PropertyValue -Object $registry -Name "packs")) {
    if ("$(Get-PropertyValue -Object $pack -Name "pack_id")" -eq $CandidateId) {
      throw "CANDIDATE_REGISTERED_LIVE=$CandidateId"
    }
  }
}

Write-Host "BUILDER_SELF_PACK_AUTHOR_V1_START"

foreach ($marker in @("CAPABILITY_ROADMAP.json", "GENESIS_STATE.json", "TASK_QUEUE.json", "packs/registry.json", "orchestrator/run.ps1")) {
  if (-not (Test-Path -LiteralPath (Join-RepoPath $marker))) {
    throw "STOP=WRONG_AGENT_BUILDER_REPO missing $marker"
  }
}

$routeCorrectionProof = Read-JsonRequired $SourceRouteCorrectionProofPath
Assert-Equals -Object $routeCorrectionProof -Name "status" -Expected "PASS"
Assert-Equals -Object $routeCorrectionProof -Name "next_allowed_step" -Expected "PHASE107_BUILDER_SELF_PACK_AUTHOR_V1"
Assert-Boolean -Object $routeCorrectionProof -Name "builder_self_pack_author_required_next" -Expected $true
Assert-Boolean -Object $routeCorrectionProof -Name "codex_fallback_not_primary" -Expected $true

$scaleTrialProof = Read-JsonRequired $SourceScaleTrialProofPath
Assert-Equals -Object $scaleTrialProof -Name "status" -Expected "PASS"

$routeLockFullPath = Join-RepoPath $SourceRouteLockPath
if (-not (Test-Path -LiteralPath $routeLockFullPath)) {
  throw "MISSING_ROUTE_LOCK_V3=$SourceRouteLockPath"
}
$routeLockText = Get-Content -LiteralPath $routeLockFullPath -Raw
Assert-TextContains -Text $routeLockText -Needle "route_lock_id: AGENT_BUILDER_NEXT_15_STEPS_LOCK_V3_SELF_PACK_AUTHOR"
Assert-TextContains -Text $routeLockText -Needle "PHASE107_BUILDER_SELF_PACK_AUTHOR_V1"
Assert-TextContains -Text $routeLockText -Needle "Builder must author next self-build packs."
Assert-TextContains -Text $routeLockText -Needle "Codex fallback, not primary."

Assert-CandidateNotRegisteredLive

$generatedAt = Get-UtcStamp
$inputSources = @(
  $SourceRouteLockPath,
  $SourceRouteCorrectionProofPath,
  $SourceScaleTrialProofPath
)

$authorPolicy = [ordered]@{
  builder_runtime_must_generate_candidate = $true
  codex_is_bootstrap_only = $true
  codex_is_fallback_not_primary = $true
  candidate_must_not_be_registered_live = $true
  candidate_must_not_be_executed_in_phase107 = $true
  admission_required_next = $true
  no_external_agent_production = $true
  no_external_fetch = $true
  no_external_install = $true
  no_fake_autonomy_claim = $true
}

$schema = [ordered]@{
  '$schema' = "https://json-schema.org/draft/2020-12/schema"
  schema_id = "builder_self_pack_author_v1"
  title = "Builder Self-Pack Author V1"
  type = "object"
  required = @(
    "author_id",
    "status",
    "active_line",
    "baseline_commit",
    "input_sources",
    "author_policy",
    "candidate_target",
    "next_allowed_step"
  )
  properties = [ordered]@{
    author_id = [ordered]@{ const = "BUILDER_SELF_PACK_AUTHOR_V1" }
    status = [ordered]@{ const = "ACTIVE_SELF_PACK_AUTHOR" }
    active_line = [ordered]@{ const = $ActiveLine }
    baseline_commit = [ordered]@{ const = $BaselineCommit }
    input_sources = [ordered]@{ type = "array"; minItems = 3 }
    author_policy = [ordered]@{ type = "object" }
    candidate_target = [ordered]@{ const = $CandidateTarget }
    next_allowed_step = [ordered]@{ const = $NextAllowedStep }
  }
  additionalProperties = $true
}

$contract = [ordered]@{
  author_id = "BUILDER_SELF_PACK_AUTHOR_V1"
  status = "ACTIVE_SELF_PACK_AUTHOR"
  phase = $Phase
  active_line = $ActiveLine
  baseline_commit = $BaselineCommit
  generated_at = $generatedAt
  input_sources = $inputSources
  author_policy = $authorPolicy
  candidate_target = $CandidateTarget
  next_allowed_step = $NextAllowedStep
}

$candidatePackPath = Join-Path $CandidateTarget "PACK.json"
$candidateApplyPath = Join-Path $CandidateTarget "APPLY.ps1"
$candidateValidatePath = Join-Path $CandidateTarget "VALIDATE.ps1"
$candidateTaskPath = Join-Path $CandidateTarget "TASK_BUILDER_GENERATED_PACK_ADMISSION_V1_001.json"
$candidateSpecPath = Join-Path $CandidateTarget "CANDIDATE_SPEC.json"
$candidateManifestPath = Join-Path $CandidateTarget "GENERATION_MANIFEST.json"

$candidatePack = [ordered]@{
  pack_id = $CandidateId
  task_id = $CandidateTaskId
  phase = "PHASE108_CANDIDATE"
  status = "CANDIDATE_DRAFT"
  path = $CandidateTarget
  shell = "PowerShell"
  entry_script = $candidateApplyPath
  validate_script = $candidateValidatePath
  active_line = $ActiveLine
  mode = "SELF_BUILD"
  generated_by = "BUILDER_RUNTIME"
  generated_during_phase = $Phase
  not_registered_live = $true
  execution_allowed = $false
  next_allowed_step = $NextAllowedStep
}

$candidateTask = [ordered]@{
  task_id = $CandidateTaskId
  status = "CANDIDATE_DRAFT"
  path = $candidateTaskPath
  active_line = $ActiveLine
  mode = "SELF_BUILD"
  capability_id = "builder_generated_pack_admission_v1"
  phase = "PHASE108_CANDIDATE"
  gate = "BUILDER_GENERATED_PACK_ADMISSION_V1"
  pack_id = $CandidateId
  generated_by = "BUILDER_RUNTIME"
  generated_during_phase = $Phase
  source_author_contract = $AuthorContractPath
  execution_allowed = $false
  next_allowed_step = $NextAllowedStep
}

$candidateSpec = [ordered]@{
  candidate_id = $CandidateId
  purpose = "Admit Builder-generated self-build pack candidate safely before execution."
  generated_by_builder_runtime = $true
  source_author_contract = $AuthorContractPath
  admission_checks_required = @(
    "JSON parse",
    "PowerShell parse",
    "forbidden scope check",
    "not registered live",
    "not executed",
    "proof requirements present",
    "rollback/safety note present"
  )
  execution_allowed = $false
  next_allowed_step = $NextAllowedStep
}

$generationManifest = [ordered]@{
  manifest_id = "PHASE108_BUILDER_GENERATED_PACK_ADMISSION_V1_CANDIDATE_GENERATION_MANIFEST"
  generated_at = $generatedAt
  generated_by = "BUILDER_RUNTIME"
  generated_during_phase = $Phase
  generator_pack_id = $PackId
  generator_task_id = $TaskId
  source_route_lock = $SourceRouteLockPath
  codex_authored_candidate = $false
  candidate_registered_live = $false
  candidate_executed = $false
  admission_required_next = $true
  no_external_fetch = $true
  no_external_install = $true
  no_external_agent_production = $true
  candidate_files = @(
    $candidatePackPath,
    $candidateApplyPath,
    $candidateValidatePath,
    $candidateTaskPath,
    $candidateSpecPath,
    $candidateManifestPath
  )
}

$candidateApply = @'
[CmdletBinding()]
param(
  [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..\..\..")).Path
)

$ErrorActionPreference = "Stop"
throw "PHASE108_CANDIDATE_NOT_ADMITTED_FOR_EXECUTION"
'@

$candidateValidate = @'
[CmdletBinding()]
param(
  [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..\..\..")).Path
)

$ErrorActionPreference = "Stop"
Write-Host "PHASE108_CANDIDATE_PRE_ADMISSION_VALIDATION_PLACEHOLDER"
Write-Host "EXECUTION_ALLOWED=FALSE"
'@

$report = [ordered]@{
  status = "PASS"
  phase = $Phase
  active_line = $ActiveLine
  generated_at = $generatedAt
  baseline_commit = $BaselineCommit
  self_pack_author_contract_created = $AuthorContractPath
  schema_created = $SchemaPath
  builder_generated_candidate_created = $true
  generated_candidate_path = $CandidateTarget
  generated_by_builder_runtime = $true
  codex_authored_candidate = $false
  candidate_registered_live = $false
  candidate_executed = $false
  admission_required_next = $true
  full_autonomy_claimed = $false
  codex_fallback_not_primary = $true
  phase108_required_next = $true
  phase108_not_executed = $true
  next_allowed_step = $NextAllowedStep
}

$proof = [ordered]@{
  status = "PASS"
  phase = $Phase
  task_id = $TaskId
  runtime_mode = "SELF_BUILD"
  generated_at = $generatedAt
  baseline_commit = $BaselineCommit
  self_pack_author_contract_created = $true
  schema_created = $true
  builder_generated_candidate_created = $true
  generated_candidate_path = $CandidateTarget
  generated_by_builder_runtime = $true
  codex_bootstrap_only = $true
  codex_authored_candidate = $false
  candidate_registered_live = $false
  candidate_executed = $false
  admission_required_next = $true
  full_autonomy_claimed = $false
  codex_fallback_not_primary = $true
  no_external_agent_production = $true
  no_external_fetch = $true
  no_external_install = $true
  phase108_required_next = $true
  phase108_not_executed = $true
  queue_returned_to_none = $true
  next_allowed_step = $NextAllowedStep
  evidence_files = @(
    $SchemaPath,
    $AuthorContractPath,
    $candidatePackPath,
    $candidateApplyPath,
    $candidateValidatePath,
    $candidateTaskPath,
    $candidateSpecPath,
    $candidateManifestPath,
    $ReportPath,
    $SourceRouteLockPath,
    $SourceRouteCorrectionProofPath
  )
}

Write-JsonFile -Path $SchemaPath -Object $schema
Write-JsonFile -Path $AuthorContractPath -Object $contract
Write-JsonFile -Path $candidatePackPath -Object $candidatePack
Write-TextFile -Path $candidateApplyPath -Content $candidateApply
Write-TextFile -Path $candidateValidatePath -Content $candidateValidate
Write-JsonFile -Path $candidateTaskPath -Object $candidateTask
Write-JsonFile -Path $candidateSpecPath -Object $candidateSpec
Write-JsonFile -Path $candidateManifestPath -Object $generationManifest
Write-JsonFile -Path $ReportPath -Object $report
Write-JsonFile -Path $ProofPath -Object $proof

Assert-CandidateNotRegisteredLive

Write-Host "SELF_PACK_AUTHOR_CONTRACT_CREATED=$AuthorContractPath"
Write-Host "BUILDER_GENERATED_CANDIDATE_CREATED=TRUE"
Write-Host "GENERATED_CANDIDATE_PATH=$CandidateTarget"
Write-Host "GENERATED_BY_BUILDER_RUNTIME=TRUE"
Write-Host "CODEX_AUTHORED_CANDIDATE=FALSE"
Write-Host "CANDIDATE_REGISTERED_LIVE=FALSE"
Write-Host "CANDIDATE_EXECUTED=FALSE"
Write-Host "ADMISSION_REQUIRED_NEXT=TRUE"
Write-Host "PHASE108_NOT_EXECUTED=TRUE"
Write-Host "BUILDER_SELF_PACK_AUTHOR_V1_COMPLETE"

return [pscustomobject]$report
