param(
  [string]$RepoRoot,
  [string]$RunId,
  [switch]$InvokedByOrchestrator
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Convert-GhCreatedAtUtc {
    param(
        [Parameter(Mandatory = $true)]
        [object]$Value
    )

    if ($Value -is [datetime]) {
        return $Value.ToUniversalTime()
    }

    if ($Value -is [datetimeoffset]) {
        return $Value.UtcDateTime
    }

    $parsed = [System.DateTimeOffset]::Parse(
        [string]$Value,
        [System.Globalization.CultureInfo]::InvariantCulture,
        [System.Globalization.DateTimeStyles]::AssumeUniversal -bor [System.Globalization.DateTimeStyles]::AdjustToUniversal
    )

    return $parsed.UtcDateTime
}

function Copy-IfDifferentPath {
  param(
    [Parameter(Mandatory = $true)]
    [string]$SourcePath,

    [Parameter(Mandatory = $true)]
    [string]$DestinationPath
  )

  $resolvedSourcePath = (Resolve-Path -LiteralPath $SourcePath).Path

  if (Test-Path -LiteralPath $DestinationPath) {
    $resolvedDestinationPath = (Resolve-Path -LiteralPath $DestinationPath).Path
    if ([string]::Equals($resolvedSourcePath, $resolvedDestinationPath, [System.StringComparison]::OrdinalIgnoreCase)) {
      Write-Output "SKIP_COPY_SAME_PATH=$resolvedSourcePath"
      return
    }
  }

  Copy-Item -LiteralPath $resolvedSourcePath -Destination $DestinationPath -Force
}

function Read-JsonFile {
  param([string]$Path)
  return Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json
}

function Write-JsonFile {
  param([string]$Path, [object]$Value)
  $dir = Split-Path -Parent $Path
  if ($dir -and -not (Test-Path -LiteralPath $dir)) {
    New-Item -ItemType Directory -Force -Path $dir | Out-Null
  }
  $Value | ConvertTo-Json -Depth 100 | Set-Content -LiteralPath $Path -Encoding UTF8
}

function Invoke-NativeGitCommand {
  param(
    [string]$Label,
    [string[]]$Arguments
  )

  $previousPreference = $ErrorActionPreference
  $output = @()
  $exitCode = $null

  try {
    $ErrorActionPreference = "Continue"
    $output = @(& git @Arguments 2>&1)
    $exitCode = $LASTEXITCODE
  }
  finally {
    $ErrorActionPreference = $previousPreference
  }

  foreach ($line in $output) {
    Write-Host ($line.ToString())
  }

  if ($exitCode -ne 0) {
    throw "GIT_${Label}_FAILED_EXIT_CODE=$exitCode"
  }

  Write-Output "GIT_${Label}=PASS"
}

function Invoke-Gh {
  param(
    [string]$Label,
    [string[]]$Arguments
  )

  $previousPreference = $ErrorActionPreference
  $output = @()
  $exitCode = $null

  try {
    $ErrorActionPreference = "Continue"
    $output = @(& gh @Arguments 2>&1)
    $exitCode = $LASTEXITCODE
  }
  finally {
    $ErrorActionPreference = $previousPreference
  }

  foreach ($line in $output) {
    Write-Host ($line.ToString())
  }

  if ($exitCode -ne 0) {
    throw "GH_${Label}_FAILED_EXIT_CODE=$exitCode"
  }

  return $output
}

function Get-OneByProperty {
  param(
    [object[]]$Items,
    [string]$PropertyName,
    [string]$ExpectedValue,
    [string]$Label
  )

  $matches = @($Items | Where-Object { $_.$PropertyName -eq $ExpectedValue })
  if ($matches.Count -ne 1) {
    throw "$Label expected one item where $PropertyName = $ExpectedValue, found $($matches.Count)."
  }

  return $matches[0]
}

function Add-UniqueString {
  param(
    [object]$Object,
    [string]$PropertyName,
    [string]$Value
  )

  if (-not $Object.PSObject.Properties.Name.Contains($PropertyName)) {
    Add-Member -InputObject $Object -MemberType NoteProperty -Name $PropertyName -Value @()
  }

  $items = @($Object.$PropertyName)
  if ($items -notcontains $Value) {
    $items += $Value
  }

  $Object.$PropertyName = $items
}

if (-not $InvokedByOrchestrator) {
  throw "Pack must be invoked by orchestrator."
}

if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
  throw "RepoRoot is required."
}

$RepoRoot = (Resolve-Path -LiteralPath $RepoRoot).Path
Set-Location $RepoRoot

$CapId = "runbook_executor_agent_github_action_acceptance_v1"
$TaskId = "TASK_RUNBOOK_EXECUTOR_AGENT_GITHUB_ACTION_ACCEPTANCE_V1_001"
$AgentId = "runbook_executor_agent_v1"
$WorkflowFile = "run-runbook-executor-agent-v1.yml"
$WorkflowName = "Run Runbook Executor Agent v1"
$ArtifactName = "runbook-executor-agent-v1-output"
$ArtifactRoot = "runs/RUNBOOK_EXECUTOR_AGENT_GITHUB_ACTION_ACCEPTANCE_V1"
$ProofPath = "proofs/RUNBOOK_EXECUTOR_AGENT_GITHUB_ACTION_ACCEPTANCE_V1.json"
$ReportPath = "reports/external_agent_production/RUNBOOK_EXECUTOR_AGENT_GITHUB_ACTION_ACCEPTANCE_V1_REPORT.json"
$AcceptanceMdPath = "reports/external_agent_production/RUNBOOK_EXECUTOR_AGENT_V1_GITHUB_ACTION_ACCEPTANCE.md"
$ValidatorTargetPath = "validators/validate_runbook_executor_agent_github_action_acceptance_v1.ps1"
$ValidatorPayloadPath = "packs/PHASE75_RUNBOOK_EXECUTOR_AGENT_GITHUB_ACTION_ACCEPTANCE_V1/payload/validators/validate_runbook_executor_agent_github_action_acceptance_v1.ps1"

Write-Output "PHASE75_ACCEPTANCE_START=RUNBOOK_EXECUTOR_AGENT"

if (-not (Test-Path -LiteralPath ".github/workflows/$WorkflowFile")) {
  throw "Workflow missing: .github/workflows/$WorkflowFile"
}

if (-not (Test-Path -LiteralPath $ValidatorPayloadPath)) {
  throw "Validator payload missing: $ValidatorPayloadPath"
}

New-Item -ItemType Directory -Force -Path "validators" | Out-Null
Copy-Item -LiteralPath $ValidatorPayloadPath -Destination $ValidatorTargetPath -Force

Remove-Item -LiteralPath $ArtifactRoot -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force -Path $ArtifactRoot | Out-Null

$dispatchStartUtc = (Get-Date).ToUniversalTime().AddSeconds(-10)

Write-Output "PHASE75_DISPATCH_WORKFLOW=$WorkflowFile"
Invoke-Gh -Label "WORKFLOW_RUN" -Arguments @(
  "workflow",
  "run",
  $WorkflowFile,
  "--ref",
  "main"
) | Out-Null

$runId = $null
$runUrl = $null
$runConclusion = $null

Write-Output "PHASE75_WAIT_FOR_GITHUB_RUN=START"

for ($i = 0; $i -lt 60; $i++) {
  Start-Sleep -Seconds 10

  $runsJson = Invoke-Gh -Label "RUN_LIST" -Arguments @(
    "run",
    "list",
    "--workflow",
    $WorkflowFile,
    "--branch",
    "main",
    "--json",
    "databaseId,status,conclusion,createdAt,event,url",
    "--limit",
    "10"
  )

  $runs = $runsJson -join "`n" | ConvertFrom-Json
  $candidates = @(
    $runs | Where-Object {
      $_.event -eq "workflow_dispatch" -and
      ((Convert-GhCreatedAtUtc $_.createdAt) -ge $dispatchStartUtc)
    } | Sort-Object { Convert-GhCreatedAtUtc $_.createdAt } -Descending
  )

  if ($candidates.Count -eq 0) {
    Write-Output "PHASE75_WAITING_FOR_RUN_RECORD=$i"
    continue
  }

  $run = $candidates[0]
  $runId = [string]$run.databaseId
  $runUrl = [string]$run.url

  Write-Output "PHASE75_RUN_ID=$runId"
  Write-Output "PHASE75_RUN_STATUS=$($run.status)"

  if ([string]$run.status -eq "completed") {
    $runConclusion = [string]$run.conclusion
    break
  }
}

if ([string]::IsNullOrWhiteSpace($runId)) {
  throw "No new GitHub workflow_dispatch run found for $WorkflowFile."
}

if ([string]$runConclusion -ne "success") {
  throw "GitHub run did not finish with success. run_id=$runId conclusion=$runConclusion url=$runUrl"
}

Write-Output "PHASE75_GITHUB_RUN_SUCCESS=PASS"

Invoke-Gh -Label "RUN_DOWNLOAD" -Arguments @(
  "run",
  "download",
  $runId,
  "--name",
  $ArtifactName,
  "--dir",
  $ArtifactRoot
) | Out-Null

$outputPath = Get-ChildItem -LiteralPath $ArtifactRoot -Recurse -File -Filter "GITHUB_ACTION_OUTPUT.json" | Select-Object -First 1
$specPath = Get-ChildItem -LiteralPath $ArtifactRoot -Recurse -File -Filter "AGENT_SPEC.json" | Select-Object -First 1

if ($null -eq $outputPath) {
  throw "Downloaded artifact missing GITHUB_ACTION_OUTPUT.json"
}

if ($null -eq $specPath) {
  throw "Downloaded artifact missing AGENT_SPEC.json"
}

Copy-IfDifferentPath -SourcePath $outputPath.FullName -DestinationPath (Join-Path $ArtifactRoot "GITHUB_ACTION_OUTPUT.json")
Copy-IfDifferentPath -SourcePath $specPath.FullName -DestinationPath (Join-Path $ArtifactRoot "AGENT_SPEC.json")

$output = Read-JsonFile (Join-Path $ArtifactRoot "GITHUB_ACTION_OUTPUT.json")
foreach ($field in @(
  "execution_checklist",
  "risk_flags",
  "required_evidence",
  "next_operator_action",
  "validation_status"
)) {
  if (-not $output.PSObject.Properties.Name.Contains($field)) {
    throw "Artifact output missing field: $field"
  }
}

if ([string]$output.validation_status -ne "PASS") {
  throw "Artifact validation_status must be PASS."
}

$spec = Read-JsonFile (Join-Path $ArtifactRoot "AGENT_SPEC.json")
if ([string]$spec.agent_id -ne $AgentId) {
  throw "Artifact AGENT_SPEC agent_id must be $AgentId."
}

Write-Output "PHASE75_ARTIFACT_VALIDATION=PASS"

$state = Read-JsonFile "GENESIS_STATE.json"
$roadmap = Read-JsonFile "CAPABILITY_ROADMAP.json"
$queue = Read-JsonFile "TASK_QUEUE.json"
$catalog = Read-JsonFile "agent_catalog/AGENT_CATALOG.json"

$capability = Get-OneByProperty -Items @($roadmap.capabilities) -PropertyName "id" -ExpectedValue $CapId -Label "PHASE75 capability"
$task = Get-OneByProperty -Items @($queue.tasks) -PropertyName "task_id" -ExpectedValue $TaskId -Label "PHASE75 task"
$agent = Get-OneByProperty -Items @($catalog.agents) -PropertyName "agent_id" -ExpectedValue $AgentId -Label "agent catalog"

$agent.status = "ACCEPTED"
$agent.github_action_validation = "PASS"
$agent.github_workflow = ".github/workflows/$WorkflowFile"
$agent.github_workflow_name = $WorkflowName
$agent.artifact_name = $ArtifactName

Add-UniqueString -Object $agent -PropertyName "proof_paths" -Value $ProofPath
Add-UniqueString -Object $agent -PropertyName "report_paths" -Value $ReportPath
Add-UniqueString -Object $agent -PropertyName "report_paths" -Value $AcceptanceMdPath

$proof = [ordered]@{
  proof_id = "RUNBOOK_EXECUTOR_AGENT_GITHUB_ACTION_ACCEPTANCE_V1"
  status = "PASS"
  accepted_agent_id = $AgentId
  github_workflow_file = ".github/workflows/$WorkflowFile"
  github_workflow_name = $WorkflowName
  github_run_id = $runId
  github_run_url = $runUrl
  github_run_conclusion = $runConclusion
  artifact_name = $ArtifactName
  downloaded_artifact_dir = $ArtifactRoot
  artifact_validation_status = "PASS"
  output_validation_status = [string]$output.validation_status
  catalog_status_after = "ACCEPTED"
  active_task_after = "NONE"
  next_recommended_step = "generalize_closed_loop_agent_production_v1"
}

$report = [ordered]@{
  report_id = "RUNBOOK_EXECUTOR_AGENT_GITHUB_ACTION_ACCEPTANCE_V1_REPORT"
  proof_id = "RUNBOOK_EXECUTOR_AGENT_GITHUB_ACTION_ACCEPTANCE_V1"
  status = "PASS"
  accepted_agent_id = $AgentId
  github_workflow_name = $WorkflowName
  github_run_id = $runId
  github_run_url = $runUrl
  artifact_name = $ArtifactName
  artifact_validation_summary = @(
    "GitHub workflow dispatched by Builder",
    "GitHub run completed with success",
    "artifact downloaded by Builder",
    "GITHUB_ACTION_OUTPUT.json found",
    "AGENT_SPEC.json found",
    "validation_status is PASS",
    "agent catalog updated to ACCEPTED"
  )
  next_recommended_step = "generalize_closed_loop_agent_production_v1"
}

$acceptanceMd = @"
# Runbook Executor Agent v1 — GitHub Action Acceptance

## Status

ACCEPTED.

## What was verified

Builder dispatched the GitHub Actions workflow for Runbook Executor Agent v1, waited for completion, downloaded the artifact, checked the output JSON, and updated the agent catalog.

## Workflow

$WorkflowName

## Workflow file

.github/workflows/$WorkflowFile

## GitHub run

$runUrl

## Artifact

$ArtifactName

## Artifact validation

PASS.

The artifact contained:

- GITHUB_ACTION_OUTPUT.json
- AGENT_SPEC.json

The output contained:

- execution_checklist
- risk_flags
- required_evidence
- next_operator_action
- validation_status

validation_status = PASS.

## Decision

Runbook Executor Agent v1 is accepted as a GitHub-runnable external agent.
"@

Write-JsonFile -Path $ProofPath -Value $proof
Write-JsonFile -Path $ReportPath -Value $report
Set-Content -LiteralPath $AcceptanceMdPath -Value $acceptanceMd -Encoding UTF8

$capability.status = "COMPLETED"
$task.status = "COMPLETED"
$queue.active_task_id = "NONE"
$state.current_phase = "PHASE_75"
$state.current_capability = $CapId
$state.last_run_status = "PASS"

if (-not $state.PSObject.Properties.Name.Contains("completed_capabilities")) {
  Add-Member -InputObject $state -MemberType NoteProperty -Name "completed_capabilities" -Value @()
}

if (@($state.completed_capabilities) -notcontains $CapId) {
  $state.completed_capabilities += $CapId
}

Write-JsonFile -Path "agent_catalog/AGENT_CATALOG.json" -Value $catalog
Write-JsonFile -Path "CAPABILITY_ROADMAP.json" -Value $roadmap
Write-JsonFile -Path "TASK_QUEUE.json" -Value $queue
Write-JsonFile -Path "GENESIS_STATE.json" -Value $state

& ".\$ValidatorTargetPath" -FinalizePhase -RunId $RunId -RepoRoot $RepoRoot

Invoke-NativeGitCommand -Label "ADD" -Arguments @(
  "add",
  ".\CAPABILITY_ROADMAP.json",
  ".\GENESIS_STATE.json",
  ".\TASK_QUEUE.json",
  ".\agent_catalog\AGENT_CATALOG.json",
  ".\agent_catalog\runbook_executor_agent_v1.md",
  ".\validators\validate_runbook_executor_agent_github_action_acceptance_v1.ps1",
  ".\proofs\RUNBOOK_EXECUTOR_AGENT_GITHUB_ACTION_ACCEPTANCE_V1.json",
  ".\reports\external_agent_production\RUNBOOK_EXECUTOR_AGENT_GITHUB_ACTION_ACCEPTANCE_V1_REPORT.json",
  ".\reports\external_agent_production\RUNBOOK_EXECUTOR_AGENT_V1_GITHUB_ACTION_ACCEPTANCE.md"
)

Invoke-NativeGitCommand -Label "COMMIT" -Arguments @(
  "commit",
  "-m",
  "Accept runbook executor GitHub Action artifact v1"
)

Invoke-NativeGitCommand -Label "PUSH" -Arguments @(
  "push",
  "origin",
  "main"
)

Write-Output "PACK_COMMIT_PUSH=PASS"
Write-Output "RUNBOOK_EXECUTOR_AGENT_ACCEPTED=PASS"

