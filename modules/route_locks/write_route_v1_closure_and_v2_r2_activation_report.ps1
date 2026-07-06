[CmdletBinding()]
param(
  [string]$Phase90ProofPath = "proofs/self_development/GENERATED_SELF_BUILD_EXECUTION_V1.json",
  [string]$Phase90ReportPath = "reports/self_development/GENERATED_SELF_BUILD_EXECUTION_REPORT.json",
  [string]$RouteLockPath = "AGENT_BUILDER_NEXT_15_STEPS_LOCK_V2_R2.md",
  [string]$ReportPath = "reports/route_locks/ROUTE_V1_CLOSURE_AND_V2_R2_ACTIVATION_REPORT.json",
  [string]$ProofPath = "proofs/route_locks/ROUTE_V1_CLOSURE_AND_V2_R2_ACTIVATION_PROOF.json",
  [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
)

$ErrorActionPreference = "Stop"

$Phase = "PHASE91_ROUTE_V1_CLOSURE_AND_V2_R2_ACTIVATION"
$TaskId = "TASK_ROUTE_V1_CLOSURE_AND_V2_R2_ACTIVATION_001"
$RouteVersion = "V2_R2"
$BaselineCommit = "77a8839"
$NextAllowedStep = "PHASE92_SELF_BUILD_BACKLOG_CONTRACT_V1"
$Supersedes = "AGENT_BUILDER_NEXT_15_STEPS_LOCK_V2.md"
$Reason = "Previous V2 moved toward external agent production too early."

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

function Write-TextFile {
  param(
    [string]$Path,
    [string]$Content
  )

  $fullPath = Join-RepoPath $Path
  $directory = Split-Path -Parent $fullPath
  if ($directory -and -not (Test-Path -LiteralPath $directory)) {
    New-Item -ItemType Directory -Path $directory -Force | Out-Null
  }
  [System.IO.File]::WriteAllText($fullPath, $Content, [System.Text.UTF8Encoding]::new($false))
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

function Is-RouteLockDecision {
  param([string]$Value)

  return $Value -in @(
    "CREATE_AGENT_BUILDER_NEXT_15_STEPS_LOCK_V2",
    "CREATE_AGENT_BUILDER_NEXT_15_STEPS_LOCK_V2_R2",
    "PHASE91_ROUTE_V1_CLOSURE_AND_V2_R2_ACTIVATION"
  )
}

Write-Host "ROUTE_V1_CLOSURE_AND_V2_R2_ACTIVATION_START"

$phase90Proof = Read-JsonRequired $Phase90ProofPath
$phase90Report = Read-JsonRequired $Phase90ReportPath

if ("$(Get-PropertyValue -Object $phase90Proof -Name "status")" -ne "PASS") {
  throw "PHASE90_PROOF_STATUS_NOT_PASS"
}
if (-not [bool](Get-PropertyValue -Object $phase90Proof -Name "execution_performed")) {
  throw "PHASE90_PROOF_EXECUTION_NOT_TRUE"
}
if (-not [bool](Get-PropertyValue -Object $phase90Proof -Name "completed_loop")) {
  throw "PHASE90_PROOF_COMPLETED_LOOP_NOT_TRUE"
}
if ("$(Get-PropertyValue -Object $phase90Report -Name "status")" -ne "PASS") {
  throw "PHASE90_REPORT_STATUS_NOT_PASS"
}

$phase90Next = "$(Get-PropertyValue -Object $phase90Proof -Name "next_allowed_step")"
$phase90Recommended = "$(Get-PropertyValue -Object $phase90Report -Name "next_recommended_action")"
if (-not (Is-RouteLockDecision -Value $phase90Next) -and -not (Is-RouteLockDecision -Value $phase90Recommended)) {
  throw "PHASE90_ROUTE_LOCK_DECISION_MISSING"
}

$generatedAt = Get-UtcStamp
$routeLockContent = @"
# Agent Builder Next 15 Steps Lock V2_R2

Status: ACTIVE_ROUTE_LOCK
Version: V2_R2
Active line: AGENT_BUILDER / SELF_BUILD
Supersedes: AGENT_BUILDER_NEXT_15_STEPS_LOCK_V2.md
Reason: previous V2 moved toward external agent production too early.
Baseline: PHASE90 completed at commit 77a8839.

## Main Doctrine

The next 15 steps are not for external agent production.
They are for building a batch self-build engine.

## Batch Meaning

Builder must eventually accept a large program of many requested items.
It must attempt items one by one or in safe batches.
It must continue after item-level failure when safe.
It must produce item-level evidence.
Successful items are proven.
Failed items are quarantined or blocked with reason.
The whole run must produce a batch report.

## Required Item Statuses

- PLANNED
- RUNNING
- PASS
- FAILED
- QUARANTINED
- BLOCKED
- NEEDS_OWNER_DECISION
- NEEDS_CODEX_REPAIR
- NEEDS_MATERIAL
- SKIPPED_BY_POLICY

## Locked Next 15 Steps

1. PHASE91 - Route V1 Closure And V2_R2 Activation
2. PHASE92 - Self-Build Backlog Contract V1
3. PHASE93 - Capability Gap Detector V1
4. PHASE94 - Owner Order To Gap Map V1
5. PHASE95 - Self-Build Program Generator V2
6. PHASE96 - Batch Planner V1
7. PHASE97 - Batch Admission Policy V1
8. PHASE98 - Item-Level Execution Ledger V1
9. PHASE99 - Continue-On-Failure Runtime V1
10. PHASE100 - Quarantine And Blocker Registry V1
11. PHASE101 - Batch Proof Aggregator V1
12. PHASE102 - Auto Next-Gap Decision V1
13. PHASE103 - Repair Loop Generator V1
14. PHASE104 - Controlled Multi-Cycle Self-Build Run V1
15. PHASE105 - Scale Trial 10 To 30 To 100 Tasks V1

## Hard Prohibitions

- No external agents in PHASE91-PHASE105.
- No unbounded autonomous loop.
- No destructive changes without approval.
- No trust without proof.
- No batch commit if validation fails.
- No hiding failed items.
- No stopping the whole batch on a safe item-level failure.
- No Codex replacing Builder runtime.
"@

$report = [ordered]@{
  status = "PASS"
  phase = $Phase
  active_line = "AGENT_BUILDER / SELF_BUILD"
  generated_at = $generatedAt
  baseline_commit = $BaselineCommit
  route_lock_created = $RouteLockPath
  route_lock_version = $RouteVersion
  supersedes = $Supersedes
  reason_for_supersession = $Reason
  no_external_agents_in_next_15_steps = $true
  batch_self_build_engine_route = $true
  phase90_proof_path = $Phase90ProofPath
  phase90_report_path = $Phase90ReportPath
  phase90_proof_status = "$(Get-PropertyValue -Object $phase90Proof -Name "status")"
  phase90_completed_loop = [bool](Get-PropertyValue -Object $phase90Proof -Name "completed_loop")
  old_v2_superseded = $true
  next_allowed_step = $NextAllowedStep
}

$proof = [ordered]@{
  status = "PASS"
  phase = $Phase
  task_id = $TaskId
  runtime_mode = "SELF_BUILD"
  generated_at = $generatedAt
  route_lock_path = $RouteLockPath
  route_lock_version = $RouteVersion
  baseline_commit = $BaselineCommit
  no_external_agent_production = $true
  no_external_install = $true
  no_external_fetch = $true
  batch_self_build_engine_route = $true
  old_v2_superseded = $true
  queue_returned_to_none = $true
  next_allowed_step = $NextAllowedStep
  evidence_files = @(
    $Phase90ProofPath,
    $Phase90ReportPath,
    $RouteLockPath,
    $ReportPath
  )
}

Write-TextFile -Path $RouteLockPath -Content $routeLockContent
Write-JsonFile -Path $ReportPath -Object $report
Write-JsonFile -Path $ProofPath -Object $proof

Write-Host "ROUTE_LOCK_CREATED=$RouteLockPath"
Write-Host "ROUTE_LOCK_VERSION=V2_R2"
Write-Host "ROUTE_LOCK_SUPERSEDES=$Supersedes"
Write-Host "BATCH_SELF_BUILD_ENGINE_ROUTE=TRUE"
Write-Host "NO_EXTERNAL_AGENT_PRODUCTION=TRUE"
Write-Host "ROUTE_LOCK_REPORT_WRITTEN=$ReportPath"
Write-Host "ROUTE_LOCK_PROOF_WRITTEN=$ProofPath"
Write-Host "ROUTE_V1_CLOSURE_AND_V2_R2_ACTIVATION_COMPLETE"

return [pscustomobject]$report
