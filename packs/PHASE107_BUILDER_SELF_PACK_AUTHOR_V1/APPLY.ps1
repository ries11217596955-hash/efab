[CmdletBinding()]
param(
  [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path,
  [string]$RunId = "BUILDER_SELF_PACK_AUTHOR_V1_001",
  [switch]$InvokedByOrchestrator
)

$ErrorActionPreference = "Stop"

$TaskId = "TASK_BUILDER_SELF_PACK_AUTHOR_V1_001"
$PackId = "PHASE107_BUILDER_SELF_PACK_AUTHOR_V1"
$Phase = "PHASE107_BUILDER_SELF_PACK_AUTHOR_V1"
$NextAllowedStep = "PHASE108_BUILDER_GENERATED_PACK_ADMISSION_V1"
$BaselineCommit = "835aa83"
$SourceRouteLockPath = "route_locks/AGENT_BUILDER_NEXT_15_STEPS_LOCK_V3_SELF_PACK_AUTHOR.md"
$SourceRouteCorrectionProofPath = "proofs/self_development/SCALE_TRIAL_PROMOTION_GATE_AND_ROUTE_LOCK_REFRESH_V1.json"
$SchemaPath = "contracts/self_development/builder_self_pack_author_v1.schema.json"
$AuthorContractPath = "self_build_batch/self_pack_author/BUILDER_SELF_PACK_AUTHOR_V1.json"
$CandidateTarget = "self_build_batch/self_pack_author/generated_candidates/PHASE108_BUILDER_GENERATED_PACK_ADMISSION_V1_CANDIDATE"
$CandidatePackId = "PHASE108_BUILDER_GENERATED_PACK_ADMISSION_V1_CANDIDATE"
$ReportPath = "reports/self_development/BUILDER_SELF_PACK_AUTHOR_V1_REPORT.json"
$ProofPath = "proofs/self_development/BUILDER_SELF_PACK_AUTHOR_V1.json"

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

function Assert-CandidateNotRegisteredLive {
  $registry = Read-JsonRequired "packs/registry.json"
  foreach ($pack in As-Array (Get-PropertyValue -Object $registry -Name "packs")) {
    if ("$(Get-PropertyValue -Object $pack -Name "pack_id")" -eq $CandidatePackId) {
      throw "CANDIDATE_REGISTERED_LIVE=$CandidatePackId"
    }
  }
}

function Verify-Phase106Evidence {
  $proof = Read-JsonRequired $SourceRouteCorrectionProofPath
  Assert-Equals -Object $proof -Name "status" -Expected "PASS"
  Assert-Equals -Object $proof -Name "next_allowed_step" -Expected $Phase
  Assert-Boolean -Object $proof -Name "builder_self_pack_author_required_next" -Expected $true
  Assert-Boolean -Object $proof -Name "codex_fallback_not_primary" -Expected $true

  if (-not (Test-Path -LiteralPath (Join-RepoPath $SourceRouteLockPath))) {
    throw "MISSING_ROUTE_LOCK_V3=$SourceRouteLockPath"
  }
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
  $task = Read-JsonRequired "tasks/TASK_BUILDER_SELF_PACK_AUTHOR_V1_001.json"
  Set-PropertyValue -Object $task -Name "status" -Value "COMPLETED"
  Set-PropertyValue -Object $task -Name "completed_by" -Value "Builder runtime"
  Set-PropertyValue -Object $task -Name "proof_path" -Value $ProofPath
  Set-PropertyValue -Object $task -Name "completed_at" -Value ((Get-Date).ToUniversalTime().ToString("o"))
  Write-JsonFile -Path "tasks/TASK_BUILDER_SELF_PACK_AUTHOR_V1_001.json" -Object $task
}

function Update-Roadmap {
  $roadmap = Read-JsonRequired "CAPABILITY_ROADMAP.json"
  $value = [ordered]@{
    status = "COMPLETED"
    schema = $SchemaPath
    self_pack_author_contract = $AuthorContractPath
    generated_candidate_path = $CandidateTarget
    proof = $ProofPath
    report = $ReportPath
    generated_by_builder_runtime = $true
    codex_authored_candidate = $false
    candidate_registered_live = $false
    candidate_executed = $false
    next_allowed_step = $NextAllowedStep
  }
  Set-PropertyValue -Object $roadmap -Name "phase107_builder_self_pack_author_v1" -Value $value
  Write-JsonFile -Path "CAPABILITY_ROADMAP.json" -Object $roadmap
}

function Update-GenesisState {
  $genesis = Read-JsonRequired "GENESIS_STATE.json"
  $value = [ordered]@{
    status = "PROVEN"
    schema = $SchemaPath
    self_pack_author_contract = $AuthorContractPath
    generated_candidate_path = $CandidateTarget
    proof = $ProofPath
    generated_by_builder_runtime = $true
    candidate_registered_live = $false
    candidate_executed = $false
    next_allowed_step = $NextAllowedStep
  }
  Set-PropertyValue -Object $genesis -Name "builder_self_pack_author_v1" -Value $value
  Set-PropertyValue -Object $genesis -Name "last_run_status" -Value "PASS"
  Write-JsonFile -Path "GENESIS_STATE.json" -Object $genesis
}

Write-Host "PHASE107_APPLY_START"

foreach ($marker in @("CAPABILITY_ROADMAP.json", "GENESIS_STATE.json", "TASK_QUEUE.json", "packs/registry.json", "orchestrator/run.ps1")) {
  if (-not (Test-Path -LiteralPath (Join-RepoPath $marker))) {
    throw "STOP=WRONG_AGENT_BUILDER_REPO missing $marker"
  }
}

Verify-Phase106Evidence
Assert-CandidateNotRegisteredLive

$report = & (Join-RepoPath "modules/self_development/write_builder_self_pack_author_v1.ps1") -RepoRoot $RepoRoot
if ($null -eq $report) {
  $report = Read-JsonRequired $ReportPath
}

Assert-Equals -Object $report -Name "status" -Expected "PASS"
Assert-Boolean -Object $report -Name "builder_generated_candidate_created" -Expected $true
Assert-Equals -Object $report -Name "generated_candidate_path" -Expected $CandidateTarget
Assert-Boolean -Object $report -Name "generated_by_builder_runtime" -Expected $true
Assert-Boolean -Object $report -Name "codex_authored_candidate" -Expected $false
Assert-Boolean -Object $report -Name "candidate_registered_live" -Expected $false
Assert-Boolean -Object $report -Name "candidate_executed" -Expected $false
Assert-Boolean -Object $report -Name "admission_required_next" -Expected $true
Assert-Boolean -Object $report -Name "phase108_not_executed" -Expected $true
Assert-Equals -Object $report -Name "next_allowed_step" -Expected $NextAllowedStep

$manifest = Read-JsonRequired (Join-Path $CandidateTarget "GENERATION_MANIFEST.json")
Assert-Boolean -Object $manifest -Name "candidate_registered_live" -Expected $false
Assert-Boolean -Object $manifest -Name "candidate_executed" -Expected $false
Assert-Boolean -Object $manifest -Name "codex_authored_candidate" -Expected $false

Assert-CandidateNotRegisteredLive
Update-TaskQueue
Update-TaskFile
Update-Roadmap
Update-GenesisState

Write-Host "TASK_QUEUE_RETURNED_TO_NONE"
& (Join-RepoPath "packs/$PackId/VALIDATE.ps1") -RepoRoot $RepoRoot -Stage "Completed"
Write-Host "PHASE107_APPLY_COMPLETE"
