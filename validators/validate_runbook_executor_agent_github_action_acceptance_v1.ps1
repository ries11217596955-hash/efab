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

function Assert-RequiredPath {
  param([string]$Path, [string]$Label)
  if (-not (Test-Path -LiteralPath $Path)) {
    throw "$Label missing: $Path"
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
    throw "$Label expected one item where $PropertyName = $ExpectedValue, found $($matches.Count)."
  }

  return $matches[0]
}

if (-not $FinalizePhase) {
  throw "PHASE75 validator requires -FinalizePhase."
}

if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
  $RepoRoot = (Get-Location).Path
}

$RepoRoot = (Resolve-Path -LiteralPath $RepoRoot).Path
Set-Location $RepoRoot

$CapId = "runbook_executor_agent_github_action_acceptance_v1"
$TaskId = "TASK_RUNBOOK_EXECUTOR_AGENT_GITHUB_ACTION_ACCEPTANCE_V1_001"
$AgentId = "runbook_executor_agent_v1"
$ArtifactRoot = "runs/RUNBOOK_EXECUTOR_AGENT_GITHUB_ACTION_ACCEPTANCE_V1"
$ProofPath = "proofs/RUNBOOK_EXECUTOR_AGENT_GITHUB_ACTION_ACCEPTANCE_V1.json"
$ReportPath = "reports/external_agent_production/RUNBOOK_EXECUTOR_AGENT_GITHUB_ACTION_ACCEPTANCE_V1_REPORT.json"
$AcceptanceMdPath = "reports/external_agent_production/RUNBOOK_EXECUTOR_AGENT_V1_GITHUB_ACTION_ACCEPTANCE.md"

Assert-RequiredPath ".github/workflows/run-runbook-executor-agent-v1.yml" "workflow"
Assert-RequiredPath "$ArtifactRoot/GITHUB_ACTION_OUTPUT.json" "downloaded GitHub output"
Assert-RequiredPath "$ArtifactRoot/AGENT_SPEC.json" "downloaded agent spec"
Assert-RequiredPath $ProofPath "proof"
Assert-RequiredPath $ReportPath "report"
Assert-RequiredPath $AcceptanceMdPath "acceptance markdown"

$output = Read-JsonFile "$ArtifactRoot/GITHUB_ACTION_OUTPUT.json"
foreach ($field in @(
  "execution_checklist",
  "risk_flags",
  "required_evidence",
  "next_operator_action",
  "validation_status"
)) {
  if (-not $output.PSObject.Properties.Name.Contains($field)) {
    throw "GitHub output missing field: $field"
  }
}

if ([string]$output.validation_status -ne "PASS") {
  throw "GitHub output validation_status must be PASS."
}

$spec = Read-JsonFile "$ArtifactRoot/AGENT_SPEC.json"
if ([string]$spec.agent_id -ne $AgentId) {
  throw "Downloaded AGENT_SPEC agent_id must be $AgentId."
}

$proof = Read-JsonFile $ProofPath
if ([string]$proof.status -ne "PASS") {
  throw "Acceptance proof status must be PASS."
}
if ([string]$proof.accepted_agent_id -ne $AgentId) {
  throw "Acceptance proof accepted_agent_id mismatch."
}
if ([string]$proof.github_run_conclusion -ne "success") {
  throw "GitHub run conclusion must be success."
}
if ([string]$proof.artifact_validation_status -ne "PASS") {
  throw "Artifact validation status must be PASS."
}

$state = Read-JsonFile "GENESIS_STATE.json"
$roadmap = Read-JsonFile "CAPABILITY_ROADMAP.json"
$queue = Read-JsonFile "TASK_QUEUE.json"
$catalog = Read-JsonFile "agent_catalog/AGENT_CATALOG.json"

$capability = Get-OneByProperty -Items @($roadmap.capabilities) -PropertyName "id" -ExpectedValue $CapId -Label "PHASE75 capability"
$task = Get-OneByProperty -Items @($queue.tasks) -PropertyName "task_id" -ExpectedValue $TaskId -Label "PHASE75 task"
$agent = Get-OneByProperty -Items @($catalog.agents) -PropertyName "agent_id" -ExpectedValue $AgentId -Label "agent catalog"

if ([string]$capability.status -ne "COMPLETED") { throw "Capability must be COMPLETED." }
if ([string]$task.status -ne "COMPLETED") { throw "Task must be COMPLETED." }
if ([string]$queue.active_task_id -ne "NONE") { throw "TASK_QUEUE active_task_id must be NONE." }
if ([string]$agent.status -ne "ACCEPTED") { throw "Agent catalog status must be ACCEPTED." }
if ([string]$agent.github_action_validation -ne "PASS") { throw "Agent github_action_validation must be PASS." }

Write-Output "RUNBOOK_EXECUTOR_AGENT_GITHUB_ACTION_ACCEPTANCE_V1_STATUS=PASS"
Write-Output "RUNBOOK_EXECUTOR_AGENT_ACCEPTED=PASS"
