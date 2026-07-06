param(
  [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path,
  [string]$RunId = "PHASE164K_OWNER_CANDIDATE_SELF_GROWTH_ADAPTER_V1",
  [switch]$InvokedByOrchestrator
)

$ErrorActionPreference = "Stop"

$PackId = "PHASE164K_OWNER_CANDIDATE_SELF_GROWTH_ADAPTER_V1"
$TaskId = "PHASE164G_SELF_GROWTH_FROM_OWNER_CANDIDATE_CODEX_ARCHIVE_BOUNDARY_CHECKER_001"

if (-not $InvokedByOrchestrator) {
  throw "Pack must be invoked by orchestrator."
}

function Write-JsonFile {
  param([string]$Path, [object]$Object, [int]$Depth = 80)
  $Dir = Split-Path -Parent $Path
  if ($Dir -and -not (Test-Path -LiteralPath $Dir)) {
    New-Item -ItemType Directory -Force -Path $Dir | Out-Null
  }
  $Object | ConvertTo-Json -Depth $Depth | Set-Content -LiteralPath $Path -Encoding UTF8
}

function Get-Prop {
  param([object]$Object, [string]$Name)
  if ($null -eq $Object) { return $null }
  $Prop = $Object.PSObject.Properties | Where-Object { $_.Name -ieq $Name } | Select-Object -First 1
  if ($null -eq $Prop) { return $null }
  return $Prop.Value
}

function Set-Prop {
  param([object]$Object, [string]$Name, [object]$Value)
  $Prop = $Object.PSObject.Properties | Where-Object { $_.Name -ieq $Name } | Select-Object -First 1
  if ($null -eq $Prop) {
    $Object | Add-Member -NotePropertyName $Name -NotePropertyValue $Value
  } else {
    $Prop.Value = $Value
  }
}

function Get-TaskIdValue {
  param([object]$Task)
  $TaskIdValue = Get-Prop -Object $Task -Name "task_id"
  if ([string]::IsNullOrWhiteSpace([string]$TaskIdValue)) {
    $TaskIdValue = Get-Prop -Object $Task -Name "id"
  }
  return [string]$TaskIdValue
}

Set-Location -LiteralPath $RepoRoot

Write-Host "PHASE164K_ADAPTER_APPLY_START"
Write-Host "RUN_ID=$RunId"

$Queue = Get-Content -LiteralPath "TASK_QUEUE.json" -Raw | ConvertFrom-Json

$ActiveTaskId = [string](Get-Prop -Object $Queue -Name "active_task_id")
if ($ActiveTaskId -ne $TaskId) {
  throw "ACTIVE_TASK_ID_NOT_PHASE164G_TASK=$ActiveTaskId"
}

$Task = $null
foreach ($Item in @($Queue.tasks)) {
  if ((Get-TaskIdValue -Task $Item) -eq $TaskId) {
    $Task = $Item
    break
  }
}

if ($null -eq $Task) { throw "PHASE164G_TASK_NOT_FOUND" }

$CandidatePath = [string](Get-Prop -Object $Task -Name "source_candidate_path")
if ([string]::IsNullOrWhiteSpace($CandidatePath)) { throw "TASK_SOURCE_CANDIDATE_PATH_EMPTY" }
if (-not (Test-Path -LiteralPath $CandidatePath)) { throw "SOURCE_CANDIDATE_NOT_FOUND=$CandidatePath" }

$Candidate = Get-Content -LiteralPath $CandidatePath -Raw | ConvertFrom-Json
$CandidateId = [string](Get-Prop -Object $Candidate -Name "candidate_id")
if ([string]::IsNullOrWhiteSpace($CandidateId)) { throw "CANDIDATE_ID_EMPTY" }

$OutRoot = "self_build_batch/owner_candidate_self_growth_adapter/$TaskId"
$RequestPath = "$OutRoot/OWNER_CANDIDATE_SELF_GROWTH_REQUEST.json"
$ReportPath = "reports/self_development/${PackId}_REPORT.json"
$ProofPath = "proofs/self_development/${PackId}.json"

$SelfGrowthRequest = [ordered]@{
  schema = "OWNER_CANDIDATE_SELF_GROWTH_REQUEST_V1"
  status = "READY_FOR_BUILDER_SELF_GROWTH"
  created_at = (Get-Date).ToUniversalTime().ToString("o")
  run_id = $RunId
  task_id = $TaskId
  source_candidate_id = $CandidateId
  source_candidate_path = $CandidatePath
  target_loop = "EXISTING_BUILDER_SELF_GROWTH_LOOP"
  requested_capability = [string](Get-Prop -Object $Candidate -Name "intended_capability")
  requested_action = "Builder should use existing self-growth organs to create an atom candidate, sandbox validate, prove, then accept or reject."
  atom_acceptance_allowed_by_adapter = $false
  accepted_core_mutation_by_adapter = $false
  route_lock_mutation_by_adapter = $false
  codex_execution_by_adapter = $false
  next_required_gate = "BUILDER_GENERATE_ATOM_CANDIDATE_AND_SANDBOX_VALIDATE"
}

$Report = [ordered]@{
  status = "PASS"
  report_id = "${PackId}_REPORT"
  phase = $PackId
  task_id = $TaskId
  source_candidate_id = $CandidateId
  self_growth_request_path = $RequestPath
  summary = "Owner candidate was adapted into a self-growth request for existing Builder organs."
  atom_accepted = $false
  candidate_promoted_directly = $false
  accepted_core_mutation = $false
  route_lock_mutation = $false
  codex_execution = $false
  next_allowed_step = "PHASE164M_CONSUME_SELF_GROWTH_REQUEST_WITH_EXISTING_BUILDER_ORGANS"
}

$Proof = [ordered]@{
  status = "PASS"
  proof_id = $PackId
  phase = $PackId
  run_id = $RunId
  task_id = $TaskId
  source_candidate_id = $CandidateId
  source_candidate_path = $CandidatePath
  self_growth_request_path = $RequestPath
  report_path = $ReportPath
  queue_returned_to_none = $true
  task_completed = $true
  atom_accepted = $false
  candidate_promoted_directly = $false
  accepted_core_mutation = $false
  route_lock_mutation = $false
  codex_execution = $false
  next_allowed_step = "PHASE164M_CONSUME_SELF_GROWTH_REQUEST_WITH_EXISTING_BUILDER_ORGANS"
}

Write-JsonFile -Path $RequestPath -Object $SelfGrowthRequest -Depth 100
Write-JsonFile -Path $ReportPath -Object $Report -Depth 100
Write-JsonFile -Path $ProofPath -Object $Proof -Depth 100

Set-Prop -Object $Task -Name "status" -Value "COMPLETED"
Set-Prop -Object $Task -Name "state" -Value "COMPLETED"
Set-Prop -Object $Task -Name "completed_at" -Value ((Get-Date).ToUniversalTime().ToString("o"))
Set-Prop -Object $Task -Name "proof_path" -Value $ProofPath
Set-Prop -Object $Task -Name "self_growth_request_path" -Value $RequestPath

Set-Prop -Object $Queue -Name "active_task_id" -Value "NONE"
Write-JsonFile -Path "TASK_QUEUE.json" -Object $Queue -Depth 100

& "packs/$PackId/VALIDATE.ps1" -RepoRoot $RepoRoot -Stage "Completed"

Write-Host "PHASE164K_ADAPTER_STATUS=PASS"
Write-Host "PHASE164K_SELF_GROWTH_REQUEST_PATH=$RequestPath"
Write-Host "TASK_QUEUE_RETURNED_TO_NONE=True"
Write-Host "NO_ATOM_ACCEPTED=True"
Write-Host "NO_ACCEPTED_CORE_MUTATION=True"
Write-Host "NO_ROUTE_LOCK_MUTATION=True"
Write-Host "NO_CODEX_EXECUTION=True"
Write-Host "PHASE164K_ADAPTER_APPLY_END"
