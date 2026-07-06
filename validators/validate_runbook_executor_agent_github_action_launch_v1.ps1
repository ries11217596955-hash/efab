param(
  [switch]$FinalizePhase,
  [string]$RunId,
  [string]$RepoRoot = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

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

function Assert-RequiredPath {
  param([string]$Path, [string]$Label)
  if (-not (Test-Path -LiteralPath $Path)) {
    throw "$Label missing: $Path"
  }
}

function Assert-TextContains {
  param([string]$Text, [string]$Needle, [string]$Label)
  if ($Text -notmatch [regex]::Escape($Needle)) {
    throw "$Label missing text: $Needle"
  }
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
    throw "$Label expected exactly one item where $PropertyName = $ExpectedValue, found $($matches.Count)."
  }
  return $matches[0]
}

function Add-UniqueString {
  param(
    [object]$Object,
    [string]$PropertyName,
    [string]$Value
  )
  $items = @()
  if ($null -ne $Object.$PropertyName) {
    $items = @($Object.$PropertyName)
  }
  if ($items -notcontains $Value) {
    $items += $Value
  }
  $Object.$PropertyName = $items
}

if (-not $FinalizePhase) {
  throw "PHASE74 validator requires -FinalizePhase."
}

if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
  $RepoRoot = (Get-Location).Path
}

$RepoRoot = (Resolve-Path -LiteralPath $RepoRoot).Path
Set-Location $RepoRoot

$CapId = "runbook_executor_agent_github_action_launch_v1"
$TaskId = "TASK_RUNBOOK_EXECUTOR_AGENT_GITHUB_ACTION_LAUNCH_V1_001"
$AgentId = "runbook_executor_agent_v1"
$WorkflowPath = ".github/workflows/run-runbook-executor-agent-v1.yml"
$WorkflowName = "Run Runbook Executor Agent v1"
$ArtifactName = "runbook-executor-agent-v1-output"
$ProofPath = "proofs/RUNBOOK_EXECUTOR_AGENT_GITHUB_ACTION_LAUNCH_V1.json"
$ReportPath = "reports/external_agent_production/RUNBOOK_EXECUTOR_AGENT_GITHUB_ACTION_LAUNCH_V1_REPORT.json"

Assert-RequiredPath $WorkflowPath "workflow file"
Assert-RequiredPath "generated_agents/runbook_executor_agent_v1/run.ps1" "run script"
Assert-RequiredPath "generated_agents/runbook_executor_agent_v1/INPUT_EXAMPLE.json" "input example"
Assert-RequiredPath "generated_agents/runbook_executor_agent_v1/AGENT_SPEC.json" "agent spec"
Assert-RequiredPath "agent_catalog/AGENT_CATALOG.json" "agent catalog"
Assert-RequiredPath "agent_catalog/runbook_executor_agent_v1.md" "agent catalog card"

$workflowText = Get-Content -LiteralPath $WorkflowPath -Raw
Assert-TextContains $workflowText "workflow_dispatch:" "workflow"
Assert-TextContains $workflowText "pwsh" "workflow"
Assert-TextContains $workflowText "actions/upload-artifact" "workflow"
Assert-TextContains $workflowText "RUNBOOK_EXECUTOR_GITHUB_ACTION_STATUS=PASS" "workflow"
Assert-TextContains $workflowText $ArtifactName "workflow"
Assert-TextContains $workflowText $WorkflowName "workflow"

$spec = Read-JsonFile "generated_agents/runbook_executor_agent_v1/AGENT_SPEC.json"
if ([string]$spec.agent_id -ne $AgentId) {
  throw "AGENT_SPEC agent_id must be $AgentId."
}

$state = Read-JsonFile "GENESIS_STATE.json"
$roadmap = Read-JsonFile "CAPABILITY_ROADMAP.json"
$queue = Read-JsonFile "TASK_QUEUE.json"
$catalog = Read-JsonFile "agent_catalog/AGENT_CATALOG.json"

if ([string]$state.current_phase -ne "PHASE_74") {
  throw "GENESIS_STATE current_phase must be PHASE_74 before runtime."
}
if ([string]$state.current_capability -ne $CapId) {
  throw "GENESIS_STATE current_capability must be $CapId before runtime."
}
if ([string]$queue.active_task_id -ne $TaskId) {
  throw "TASK_QUEUE active_task_id must be $TaskId before runtime."
}

$capability = Get-OneByProperty -Items @($roadmap.capabilities) -PropertyName "id" -ExpectedValue $CapId -Label "PHASE74 capability"
$task = Get-OneByProperty -Items @($queue.tasks) -PropertyName "task_id" -ExpectedValue $TaskId -Label "PHASE74 task"
$agent = Get-OneByProperty -Items @($catalog.agents) -PropertyName "agent_id" -ExpectedValue $AgentId -Label "agent catalog"

if ([string]$capability.status -ne "ACTIVE") { throw "Capability must be ACTIVE before runtime." }
if ([string]$task.status -ne "ACTIVE") { throw "Task must be ACTIVE before runtime." }

$agent.github_workflow = $WorkflowPath
$agent.github_workflow_name = $WorkflowName
$agent.artifact_name = $ArtifactName
$agent.status = "GITHUB_ACTION_READY_PENDING_RUN"
$agent.github_action_validation = "READY_PENDING_RUN"

Add-UniqueString -Object $agent -PropertyName "proof_paths" -Value "proofs/RUNBOOK_EXECUTOR_AGENT_GITHUB_ACTION_LAUNCH_V1.json"
Add-UniqueString -Object $agent -PropertyName "report_paths" -Value "reports/external_agent_production/RUNBOOK_EXECUTOR_AGENT_GITHUB_ACTION_LAUNCH_V1_REPORT.json"

$card = @"
# Runbook Executor Agent v1

## Статус

GITHUB_ACTION_READY_PENDING_RUN.

## Что это за агент

Runbook Executor Agent v1 принимает инструкцию или регламент и описание задачи/инцидента. На выходе он создаёт операторский план действий.

## Что принимает

- runbook_title
- runbook_steps
- task_or_incident
- environment
- constraints

## Что выдаёт

- execution_checklist
- risk_flags
- required_evidence
- next_operator_action
- validation_status

## Где лежит

generated_agents/runbook_executor_agent_v1/

## Локальный запуск

pwsh -NoProfile -ExecutionPolicy Bypass -File generated_agents/runbook_executor_agent_v1/run.ps1 -InputPath generated_agents/runbook_executor_agent_v1/INPUT_EXAMPLE.json -OutputPath generated_agents/runbook_executor_agent_v1/OUTPUT_EXAMPLE_RUNTIME.json

## GitHub Actions запуск

Workflow:

$WorkflowName

Workflow file:

$WorkflowPath

Artifact:

$ArtifactName

## Текущий следующий шаг

Владелец должен открыть GitHub Actions, запустить workflow и проверить, что GitHub создаёт artifact.
"@

Set-Content -LiteralPath "agent_catalog/runbook_executor_agent_v1.md" -Value $card -Encoding UTF8

$proof = [ordered]@{
  proof_id = "RUNBOOK_EXECUTOR_AGENT_GITHUB_ACTION_LAUNCH_V1"
  status = "PASS"
  produced_workflow_path = $WorkflowPath
  launched_agent_id = $AgentId
  github_action_visible_name = $WorkflowName
  workflow_dispatch_present = $true
  artifact_upload_present = $true
  catalog_status_after = "GITHUB_ACTION_READY_PENDING_RUN"
  active_task_after = "NONE"
  next_recommended_step = "run_runbook_executor_github_action_and_verify_artifact"
}

$report = [ordered]@{
  report_id = "RUNBOOK_EXECUTOR_AGENT_GITHUB_ACTION_LAUNCH_V1_REPORT"
  proof_id = "RUNBOOK_EXECUTOR_AGENT_GITHUB_ACTION_LAUNCH_V1"
  status = "PASS"
  launched_agent_id = $AgentId
  produced_workflow_path = $WorkflowPath
  github_action_visible_name = $WorkflowName
  expected_artifact = $ArtifactName
  owner_run_instructions = "In GitHub, open Actions, choose 'Run Runbook Executor Agent v1', select 'Run workflow', and wait for the run to complete."
  validation_summary = @(
    "workflow_dispatch present",
    "PowerShell runtime command present",
    "artifact upload present",
    "agent package files present",
    "agent catalog updated to GITHUB_ACTION_READY_PENDING_RUN",
    "TASK_QUEUE active_task_id returned to NONE"
  )
  github_run_status = "PENDING_OWNER_RUN"
  next_recommended_step = "run_runbook_executor_github_action_and_verify_artifact"
}

Write-JsonFile -Path $ProofPath -Value $proof
Write-JsonFile -Path $ReportPath -Value $report

$capability.status = "COMPLETED"
$task.status = "COMPLETED"
$queue.active_task_id = "NONE"
$state.current_phase = "PHASE_74"
$state.current_capability = $CapId
$state.last_run_status = "PASS"

if (@($state.completed_capabilities) -notcontains $CapId) {
  $state.completed_capabilities += $CapId
}

Write-JsonFile -Path "agent_catalog/AGENT_CATALOG.json" -Value $catalog
Write-JsonFile -Path "CAPABILITY_ROADMAP.json" -Value $roadmap
Write-JsonFile -Path "TASK_QUEUE.json" -Value $queue
Write-JsonFile -Path "GENESIS_STATE.json" -Value $state

$finalState = Read-JsonFile "GENESIS_STATE.json"
$finalRoadmap = Read-JsonFile "CAPABILITY_ROADMAP.json"
$finalQueue = Read-JsonFile "TASK_QUEUE.json"
$finalCatalog = Read-JsonFile "agent_catalog/AGENT_CATALOG.json"
$finalCapability = Get-OneByProperty -Items @($finalRoadmap.capabilities) -PropertyName "id" -ExpectedValue $CapId -Label "PHASE74 capability after runtime"
$finalTask = Get-OneByProperty -Items @($finalQueue.tasks) -PropertyName "task_id" -ExpectedValue $TaskId -Label "PHASE74 task after runtime"
$finalAgent = Get-OneByProperty -Items @($finalCatalog.agents) -PropertyName "agent_id" -ExpectedValue $AgentId -Label "agent catalog after runtime"

if ([string]$finalCapability.status -ne "COMPLETED") { throw "Capability must be COMPLETED after runtime." }
if ([string]$finalTask.status -ne "COMPLETED") { throw "Task must be COMPLETED after runtime." }
if ([string]$finalQueue.active_task_id -ne "NONE") { throw "TASK_QUEUE active_task_id must be NONE after runtime." }
if ([string]$finalAgent.status -ne "GITHUB_ACTION_READY_PENDING_RUN") { throw "Catalog agent status not updated." }

Write-Output "RUNBOOK_EXECUTOR_AGENT_GITHUB_ACTION_LAUNCH_V1_STATUS=PASS"
Write-Output "RUNBOOK_EXECUTOR_AGENT_GITHUB_ACTION_LAUNCH_V1_WORKFLOW=$WorkflowPath"
Write-Output "RUNBOOK_EXECUTOR_AGENT_GITHUB_ACTION_LAUNCH_V1_ACTIVE_TASK_AFTER=NONE"
