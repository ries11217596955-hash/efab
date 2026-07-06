[CmdletBinding()]
param(
  [string]$SourceScaleTrialProofPath = "proofs/self_development/SCALE_TRIAL_10_30_100_ITEM_SIMULATION_V1.json",
  [string]$SourceScaleTrialResultPath = "self_build_batch/scale_trials/BATCH_PLAN_EXAMPLE_V1_SCALE_TRIAL_RESULT.json",
  [string]$PriorRouteLockPath = "AGENT_BUILDER_NEXT_15_STEPS_LOCK_V2_R2.md",
  [string]$SchemaPath = "contracts/self_development/scale_trial_promotion_gate_and_route_lock_refresh_v1.schema.json",
  [string]$RouteLockV3Path = "route_locks/AGENT_BUILDER_NEXT_15_STEPS_LOCK_V3_SELF_PACK_AUTHOR.md",
  [string]$RouteTransitionReportPath = "reports/route_locks/ROUTE_V2_R2_TO_V3_SELF_PACK_AUTHOR_REPORT.json",
  [string]$RouteTransitionProofPath = "proofs/route_locks/ROUTE_V2_R2_TO_V3_SELF_PACK_AUTHOR_PROOF.json",
  [string]$ReportPath = "reports/self_development/SCALE_TRIAL_PROMOTION_GATE_AND_ROUTE_LOCK_REFRESH_V1_REPORT.json",
  [string]$ProofPath = "proofs/self_development/SCALE_TRIAL_PROMOTION_GATE_AND_ROUTE_LOCK_REFRESH_V1.json",
  [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
)

$ErrorActionPreference = "Stop"

$TaskId = "TASK_SCALE_TRIAL_PROMOTION_GATE_AND_ROUTE_LOCK_REFRESH_V1_001"
$Phase = "PHASE106_SCALE_TRIAL_PROMOTION_GATE_AND_ROUTE_LOCK_REFRESH_V1"
$ActiveLine = "AGENT_BUILDER / SELF_BUILD"
$BaselineCommit = "e66cf8e"
$PriorPhase = "PHASE105_SCALE_TRIAL_10_30_100_ITEM_SIMULATION_V1"
$ScaleTrialPromotedAs = "SIMULATION_PROVEN"
$NextAllowedStep = "PHASE107_BUILDER_SELF_PACK_AUTHOR_V1"
$RouteLockId = "AGENT_BUILDER_NEXT_15_STEPS_LOCK_V3_SELF_PACK_AUTHOR"
$Supersedes = "AGENT_BUILDER_NEXT_15_STEPS_LOCK_V2_R2"

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

function Assert-Integer {
  param(
    [object]$Object,
    [string]$Name,
    [int]$Expected
  )

  $actual = [int](Get-PropertyValue -Object $Object -Name $Name)
  if ($actual -ne $Expected) {
    throw "$($Name.ToUpperInvariant())_MISMATCH expected=$Expected actual=$actual"
  }
}

function Assert-ScaleTrialEvidence {
  param(
    [object]$Proof,
    [object]$Result
  )

  Assert-Equals -Object $Proof -Name "status" -Expected "PASS"
  Assert-Equals -Object $Proof -Name "phase" -Expected $PriorPhase
  Assert-Boolean -Object $Proof -Name "simulation_performed" -Expected $true
  Assert-Boolean -Object $Proof -Name "real_items_executed" -Expected $false
  Assert-Integer -Object $Proof -Name "tier_count" -Expected 3
  Assert-Integer -Object $Proof -Name "total_simulated_item_count" -Expected 140
  Assert-Boolean -Object $Proof -Name "no_fake_pass" -Expected $true
  Assert-Boolean -Object $Proof -Name "no_hidden_failures" -Expected $true
  Assert-Boolean -Object $Proof -Name "external_fetch_performed" -Expected $false
  Assert-Boolean -Object $Proof -Name "external_install_performed" -Expected $false
  Assert-Boolean -Object $Proof -Name "external_agent_production_performed" -Expected $false

  Assert-Equals -Object $Result -Name "status" -Expected "SCALE_TRIAL_SIMULATION_COMPLETED"
  Assert-Boolean -Object $Result -Name "simulation_performed" -Expected $true
  Assert-Boolean -Object $Result -Name "real_items_executed" -Expected $false
  Assert-Integer -Object $Result -Name "tier_count" -Expected 3
  Assert-Integer -Object $Result -Name "total_simulated_item_count" -Expected 140
  Assert-Boolean -Object $Result -Name "no_fake_pass" -Expected $true
  Assert-Boolean -Object $Result -Name "no_hidden_failures" -Expected $true
  Assert-Boolean -Object $Result -Name "external_fetch_performed" -Expected $false
  Assert-Boolean -Object $Result -Name "external_install_performed" -Expected $false
  Assert-Boolean -Object $Result -Name "external_agent_production_performed" -Expected $false
  Assert-Equals -Object $Result -Name "scale_trial_result" -Expected "PASS"

  $tierCounts = @(As-Array (Get-PropertyValue -Object $Result -Name "tier_results") | ForEach-Object {
    [int](Get-PropertyValue -Object $_ -Name "item_count")
  })
  $sortedTierCounts = @($tierCounts | Sort-Object)
  if (($sortedTierCounts -join ",") -ne "10,30,100") {
    throw "TIER_RESULT_ITEM_COUNTS_NOT_EXACTLY_10_30_100 actual=$($sortedTierCounts -join ',')"
  }
}

Write-Host "SCALE_TRIAL_PROMOTION_GATE_AND_ROUTE_LOCK_REFRESH_V1_START"

foreach ($marker in @("CAPABILITY_ROADMAP.json", "GENESIS_STATE.json", "TASK_QUEUE.json", "packs/registry.json", "orchestrator/run.ps1")) {
  if (-not (Test-Path -LiteralPath (Join-RepoPath $marker))) {
    throw "STOP=WRONG_AGENT_BUILDER_REPO missing $marker"
  }
}
if (-not (Test-Path -LiteralPath (Join-RepoPath $PriorRouteLockPath))) {
  throw "MISSING_PRIOR_ROUTE_LOCK=$PriorRouteLockPath"
}

$scaleTrialProof = Read-JsonRequired $SourceScaleTrialProofPath
$scaleTrialResult = Read-JsonRequired $SourceScaleTrialResultPath
Assert-ScaleTrialEvidence -Proof $scaleTrialProof -Result $scaleTrialResult

$generatedAt = Get-UtcStamp

$schema = [ordered]@{
  '$schema' = "https://json-schema.org/draft/2020-12/schema"
  schema_id = "scale_trial_promotion_gate_and_route_lock_refresh_v1"
  title = "Scale Trial Promotion Gate And Route Lock Refresh V1"
  type = "object"
  required = @(
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
    "no_external_agent_production",
    "no_external_fetch",
    "no_external_install",
    "phase107_not_executed",
    "next_allowed_step"
  )
  properties = [ordered]@{
    status = [ordered]@{ const = "PASS" }
    phase = [ordered]@{ const = $Phase }
    active_line = [ordered]@{ const = $ActiveLine }
    baseline_commit = [ordered]@{ const = $BaselineCommit }
    scale_trial_promoted_as = [ordered]@{ const = $ScaleTrialPromotedAs }
    full_autonomy_claimed = [ordered]@{ const = $false }
    codex_dependency_risk_recorded = [ordered]@{ const = $true }
    route_correction_created = [ordered]@{ const = $true }
    route_lock_v3_created = [ordered]@{ type = @("boolean", "string") }
    builder_self_pack_author_required_next = [ordered]@{ const = $true }
    codex_fallback_not_primary = [ordered]@{ const = $true }
    no_external_agent_production = [ordered]@{ const = $true }
    no_external_fetch = [ordered]@{ const = $true }
    no_external_install = [ordered]@{ const = $true }
    phase107_not_executed = [ordered]@{ const = $true }
    next_allowed_step = [ordered]@{ const = $NextAllowedStep }
  }
  additionalProperties = $true
}

$routeLockLines = @(
  "# AGENT_BUILDER_NEXT_15_STEPS_LOCK_V3_SELF_PACK_AUTHOR",
  "",
  "route_lock_id: $RouteLockId",
  "status: ACTIVE_ROUTE_LOCK",
  "supersedes: $Supersedes",
  "active_line: $ActiveLine",
  "proven_baseline_commit: $BaselineCommit",
  "proven_baseline_phase: $PriorPhase",
  "",
  "## Strategic Correction",
  "",
  "- Codex has been bootstrap author too often.",
  "- Builder must author next self-build packs.",
  "- Codex becomes fallback only.",
  "- Codex fallback, not primary.",
  "",
  "## Scale Trial Promotion Gate",
  "",
  "- PHASE105 is promoted only as SIMULATION_PROVEN.",
  "- Full autonomy is not claimed.",
  "- The next move must prove Builder self-pack authorship before external agents or material acquisition.",
  "",
  "## Next Steps",
  "",
  "1. PHASE107_BUILDER_SELF_PACK_AUTHOR_V1",
  "2. PHASE108_BUILDER_GENERATED_PACK_ADMISSION_V1",
  "3. PHASE109_BUILDER_EXECUTES_OWN_GENERATED_NEXT_PACK_V1",
  "4. PHASE110_CODEX_FALLBACK_LIMITER_V1",
  "5. PHASE111_SELF_PACK_AUTHOR_SCALE_TRIAL_V1",
  "",
  "## Forbidden",
  "",
  "- external agent production before self-pack author gate",
  "- material acquisition runtime without policy/admission",
  "- Codex as primary author for every next pack",
  "- fake autonomy claims"
)
$routeLockContent = ($routeLockLines -join "`n")

$routeReport = [ordered]@{
  status = "PASS"
  phase = $Phase
  active_line = $ActiveLine
  generated_at = $generatedAt
  baseline_commit = $BaselineCommit
  route_lock_created = $RouteLockV3Path
  route_lock_id = $RouteLockId
  route_lock_version = "V3_SELF_PACK_AUTHOR"
  supersedes = $Supersedes
  proven_baseline_phase = $PriorPhase
  scale_trial_promoted_as = $ScaleTrialPromotedAs
  full_autonomy_claimed = $false
  codex_dependency_risk_recorded = $true
  route_correction_created = $true
  builder_self_pack_author_required_next = $true
  codex_fallback_not_primary = $true
  no_external_agent_production = $true
  no_external_fetch = $true
  no_external_install = $true
  phase107_not_executed = $true
  next_allowed_step = $NextAllowedStep
}

$routeProof = [ordered]@{
  status = "PASS"
  phase = $Phase
  task_id = $TaskId
  runtime_mode = "SELF_BUILD"
  generated_at = $generatedAt
  route_lock_path = $RouteLockV3Path
  route_lock_id = $RouteLockId
  route_lock_version = "V3_SELF_PACK_AUTHOR"
  baseline_commit = $BaselineCommit
  supersedes = $Supersedes
  scale_trial_promoted_as = $ScaleTrialPromotedAs
  codex_dependency_risk_recorded = $true
  route_correction_created = $true
  builder_self_pack_author_required_next = $true
  codex_fallback_not_primary = $true
  no_external_agent_production = $true
  no_external_install = $true
  no_external_fetch = $true
  phase107_not_executed = $true
  queue_returned_to_none = $true
  next_allowed_step = $NextAllowedStep
  evidence_files = @(
    $SourceScaleTrialProofPath,
    $SourceScaleTrialResultPath,
    $RouteLockV3Path,
    $RouteTransitionReportPath
  )
}

$report = [ordered]@{
  status = "PASS"
  phase = $Phase
  active_line = $ActiveLine
  generated_at = $generatedAt
  baseline_commit = $BaselineCommit
  source_scale_trial_proof = $SourceScaleTrialProofPath
  source_scale_trial_result = $SourceScaleTrialResultPath
  scale_trial_promoted_as = $ScaleTrialPromotedAs
  full_autonomy_claimed = $false
  codex_dependency_risk_recorded = $true
  route_correction_created = $true
  route_lock_v3_created = $RouteLockV3Path
  next_allowed_step = $NextAllowedStep
  phase107_not_executed = $true
}

$proof = [ordered]@{
  status = "PASS"
  phase = $Phase
  task_id = $TaskId
  runtime_mode = "SELF_BUILD"
  generated_at = $generatedAt
  baseline_commit = $BaselineCommit
  scale_trial_proof_verified = $true
  scale_trial_promoted_as = $ScaleTrialPromotedAs
  full_autonomy_claimed = $false
  codex_dependency_risk_recorded = $true
  route_correction_created = $true
  route_lock_v3_created = $true
  builder_self_pack_author_required_next = $true
  codex_fallback_not_primary = $true
  no_external_agent_production = $true
  no_external_fetch = $true
  no_external_install = $true
  phase107_not_executed = $true
  queue_returned_to_none = $true
  next_allowed_step = $NextAllowedStep
  evidence_files = @(
    $SchemaPath,
    $RouteLockV3Path,
    $RouteTransitionReportPath,
    $RouteTransitionProofPath,
    $ReportPath,
    $SourceScaleTrialProofPath,
    $SourceScaleTrialResultPath
  )
}

Write-JsonFile -Path $SchemaPath -Object $schema
Write-TextFile -Path $RouteLockV3Path -Content $routeLockContent
Write-JsonFile -Path $RouteTransitionReportPath -Object $routeReport
Write-JsonFile -Path $RouteTransitionProofPath -Object $routeProof
Write-JsonFile -Path $ReportPath -Object $report
Write-JsonFile -Path $ProofPath -Object $proof

Write-Host "SCALE_TRIAL_PROMOTED_AS=$ScaleTrialPromotedAs"
Write-Host "FULL_AUTONOMY_CLAIMED=FALSE"
Write-Host "CODEX_DEPENDENCY_RISK_RECORDED=TRUE"
Write-Host "ROUTE_LOCK_V3_CREATED=$RouteLockV3Path"
Write-Host "NEXT_ALLOWED_STEP=$NextAllowedStep"
Write-Host "PHASE107_NOT_EXECUTED=TRUE"
Write-Host "NO_EXTERNAL_AGENT_PRODUCTION=TRUE"
Write-Host "NO_EXTERNAL_FETCH=TRUE"
Write-Host "NO_EXTERNAL_INSTALL=TRUE"
Write-Host "SCALE_TRIAL_PROMOTION_GATE_AND_ROUTE_LOCK_REFRESH_V1_COMPLETE"

return [pscustomobject]$report
