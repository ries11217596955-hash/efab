[CmdletBinding()]
param(
  [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path,
  [string]$RunId = "SCALE_TRIAL_PROMOTION_GATE_AND_ROUTE_LOCK_REFRESH_V1_001",
  [switch]$InvokedByOrchestrator
)

$ErrorActionPreference = "Stop"

$TaskId = "TASK_SCALE_TRIAL_PROMOTION_GATE_AND_ROUTE_LOCK_REFRESH_V1_001"
$PackId = "PHASE106_SCALE_TRIAL_PROMOTION_GATE_AND_ROUTE_LOCK_REFRESH_V1"
$Phase = "PHASE106_SCALE_TRIAL_PROMOTION_GATE_AND_ROUTE_LOCK_REFRESH_V1"
$NextAllowedStep = "PHASE107_BUILDER_SELF_PACK_AUTHOR_V1"
$BaselineCommit = "e66cf8e"
$SourceScaleTrialProofPath = "proofs/self_development/SCALE_TRIAL_10_30_100_ITEM_SIMULATION_V1.json"
$SourceScaleTrialResultPath = "self_build_batch/scale_trials/BATCH_PLAN_EXAMPLE_V1_SCALE_TRIAL_RESULT.json"
$SchemaPath = "contracts/self_development/scale_trial_promotion_gate_and_route_lock_refresh_v1.schema.json"
$RouteLockV3Path = "route_locks/AGENT_BUILDER_NEXT_15_STEPS_LOCK_V3_SELF_PACK_AUTHOR.md"
$RouteTransitionReportPath = "reports/route_locks/ROUTE_V2_R2_TO_V3_SELF_PACK_AUTHOR_REPORT.json"
$RouteTransitionProofPath = "proofs/route_locks/ROUTE_V2_R2_TO_V3_SELF_PACK_AUTHOR_PROOF.json"
$ReportPath = "reports/self_development/SCALE_TRIAL_PROMOTION_GATE_AND_ROUTE_LOCK_REFRESH_V1_REPORT.json"
$ProofPath = "proofs/self_development/SCALE_TRIAL_PROMOTION_GATE_AND_ROUTE_LOCK_REFRESH_V1.json"

function Join-RepoPath {
  param([string]$Path)

  if ([System.IO.Path]::IsPathRooted($Path)) {
    return [System.IO.Path]::GetFullPath($Path)
  }
  return [System.IO.Path]::GetFullPath((Join-Path $RepoRoot $Path))
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

function Set-PropertyValue {
  param(
    [object]$Object,
    [string]$Name,
    [object]$Value
  )

  $property = Get-PropertyInfo -Object $Object -Name $Name
  if ($null -eq $property) {
    $Object | Add-Member -NotePropertyName $Name -NotePropertyValue $Value
  } else {
    $property.Value = $Value
  }
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

function Verify-SourceScaleTrialEvidence {
  $proof = Read-JsonRequired $SourceScaleTrialProofPath
  $result = Read-JsonRequired $SourceScaleTrialResultPath

  Assert-Equals -Object $proof -Name "status" -Expected "PASS"
  Assert-Boolean -Object $proof -Name "simulation_performed" -Expected $true
  Assert-Boolean -Object $proof -Name "real_items_executed" -Expected $false
  Assert-Integer -Object $proof -Name "total_simulated_item_count" -Expected 140
  Assert-Boolean -Object $proof -Name "no_fake_pass" -Expected $true
  Assert-Boolean -Object $proof -Name "no_hidden_failures" -Expected $true
  Assert-Boolean -Object $proof -Name "external_fetch_performed" -Expected $false
  Assert-Boolean -Object $proof -Name "external_install_performed" -Expected $false
  Assert-Boolean -Object $proof -Name "external_agent_production_performed" -Expected $false

  Assert-Equals -Object $result -Name "status" -Expected "SCALE_TRIAL_SIMULATION_COMPLETED"
  Assert-Integer -Object $result -Name "total_simulated_item_count" -Expected 140
  Assert-Boolean -Object $result -Name "no_fake_pass" -Expected $true
  Assert-Boolean -Object $result -Name "no_hidden_failures" -Expected $true
  Assert-Boolean -Object $result -Name "external_fetch_performed" -Expected $false
  Assert-Boolean -Object $result -Name "external_install_performed" -Expected $false
  Assert-Boolean -Object $result -Name "external_agent_production_performed" -Expected $false
}

function Update-TaskQueue {
  $queue = Read-JsonRequired "TASK_QUEUE.json"
  Set-PropertyValue -Object $queue -Name "active_task_id" -Value "NONE"
  $found = $false
  foreach ($task in As-Array (Get-PropertyValue -Object $queue -Name "tasks")) {
    if ("$(Get-PropertyValue -Object $task -Name "task_id")" -eq $TaskId) {
      Set-PropertyValue -Object $task -Name "status" -Value "COMPLETED"
      Set-PropertyValue -Object $task -Name "completed_at" -Value ((Get-Date).ToUniversalTime().ToString("o"))
      $found = $true
    }
  }
  if (-not $found) {
    throw "TASK_NOT_FOUND_IN_QUEUE=$TaskId"
  }
  Write-JsonFile -Path "TASK_QUEUE.json" -Object $queue
}

function Update-TaskFile {
  $task = Read-JsonRequired "tasks/TASK_SCALE_TRIAL_PROMOTION_GATE_AND_ROUTE_LOCK_REFRESH_V1_001.json"
  Set-PropertyValue -Object $task -Name "status" -Value "COMPLETED"
  Set-PropertyValue -Object $task -Name "completed_by" -Value "Builder runtime"
  Set-PropertyValue -Object $task -Name "proof_path" -Value $ProofPath
  Set-PropertyValue -Object $task -Name "completed_at" -Value ((Get-Date).ToUniversalTime().ToString("o"))
  Write-JsonFile -Path "tasks/TASK_SCALE_TRIAL_PROMOTION_GATE_AND_ROUTE_LOCK_REFRESH_V1_001.json" -Object $task
}

function Update-Roadmap {
  $roadmap = Read-JsonRequired "CAPABILITY_ROADMAP.json"
  $value = [ordered]@{
    status = "COMPLETED"
    schema = $SchemaPath
    route_lock_v3 = $RouteLockV3Path
    route_transition_report = $RouteTransitionReportPath
    route_transition_proof = $RouteTransitionProofPath
    proof = $ProofPath
    report = $ReportPath
    source_scale_trial_proof = $SourceScaleTrialProofPath
    source_scale_trial_result = $SourceScaleTrialResultPath
    scale_trial_promoted_as = "SIMULATION_PROVEN"
    full_autonomy_claimed = $false
    codex_dependency_risk_recorded = $true
    next_allowed_step = $NextAllowedStep
  }
  Set-PropertyValue -Object $roadmap -Name "phase106_scale_trial_promotion_gate_and_route_lock_refresh_v1" -Value $value
  Write-JsonFile -Path "CAPABILITY_ROADMAP.json" -Object $roadmap
}

function Update-GenesisState {
  $genesis = Read-JsonRequired "GENESIS_STATE.json"
  $routeLockMarker = [ordered]@{
    status = "ACTIVE_ROUTE_LOCK"
    route_lock = $RouteLockV3Path
    supersedes = "AGENT_BUILDER_NEXT_15_STEPS_LOCK_V2_R2"
    active_line = "AGENT_BUILDER / SELF_BUILD"
    proven_baseline_commit = $BaselineCommit
    proven_baseline_phase = "PHASE105_SCALE_TRIAL_10_30_100_ITEM_SIMULATION_V1"
    proof = $RouteTransitionProofPath
    next_allowed_step = $NextAllowedStep
  }
  $capabilityMarker = [ordered]@{
    status = "PROVEN"
    schema = $SchemaPath
    route_lock_v3 = $RouteLockV3Path
    proof = $ProofPath
    scale_trial_promoted_as = "SIMULATION_PROVEN"
  }
  Set-PropertyValue -Object $genesis -Name "route_lock_v3_self_pack_author" -Value $routeLockMarker
  Set-PropertyValue -Object $genesis -Name "scale_trial_promotion_gate_and_route_lock_refresh_v1" -Value $capabilityMarker
  Set-PropertyValue -Object $genesis -Name "last_run_status" -Value "PASS"
  Write-JsonFile -Path "GENESIS_STATE.json" -Object $genesis
}

Write-Host "PHASE106_APPLY_START"

foreach ($marker in @("CAPABILITY_ROADMAP.json", "GENESIS_STATE.json", "TASK_QUEUE.json", "packs/registry.json", "orchestrator/run.ps1")) {
  if (-not (Test-Path -LiteralPath (Join-RepoPath $marker))) {
    throw "STOP=WRONG_AGENT_BUILDER_REPO missing $marker"
  }
}

Verify-SourceScaleTrialEvidence

$report = & (Join-RepoPath "modules/self_development/write_scale_trial_promotion_gate_and_route_lock_refresh_v1.ps1") -RepoRoot $RepoRoot
if ($null -eq $report) {
  $report = Read-JsonRequired $ReportPath
}
Assert-Equals -Object $report -Name "status" -Expected "PASS"
Assert-Equals -Object $report -Name "scale_trial_promoted_as" -Expected "SIMULATION_PROVEN"
Assert-Boolean -Object $report -Name "full_autonomy_claimed" -Expected $false
Assert-Boolean -Object $report -Name "codex_dependency_risk_recorded" -Expected $true
Assert-Boolean -Object $report -Name "route_correction_created" -Expected $true
Assert-Equals -Object $report -Name "route_lock_v3_created" -Expected $RouteLockV3Path
Assert-Boolean -Object $report -Name "phase107_not_executed" -Expected $true
Assert-Equals -Object $report -Name "next_allowed_step" -Expected $NextAllowedStep

Update-TaskQueue
Update-TaskFile
Update-Roadmap
Update-GenesisState

Write-Host "TASK_QUEUE_RETURNED_TO_NONE"
& (Join-RepoPath "packs/$PackId/VALIDATE.ps1") -RepoRoot $RepoRoot -Stage "Completed"
Write-Host "PHASE106_APPLY_COMPLETE"
