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
  throw "PHASE77 validator requires -FinalizePhase."
}

if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
  $RepoRoot = (Get-Location).Path
}

$RepoRoot = (Resolve-Path -LiteralPath $RepoRoot).Path
Set-Location $RepoRoot

$CapId = "evidence_packager_agent_closed_loop_trial_v1"
$TaskId = "TASK_EVIDENCE_PACKAGER_AGENT_CLOSED_LOOP_TRIAL_V1_001"
$AgentId = "evidence_packager_agent_v1"
$AgentRoot = "generated_agents/evidence_packager_agent_v1"
$WorkflowPath = ".github/workflows/run-evidence-packager-agent-v1.yml"
$RunRoot = "runs/EVIDENCE_PACKAGER_AGENT_CLOSED_LOOP_TRIAL_V1"
$ProofPath = "proofs/EVIDENCE_PACKAGER_AGENT_CLOSED_LOOP_TRIAL_V1.json"
$ReportPath = "reports/external_agent_production/EVIDENCE_PACKAGER_AGENT_CLOSED_LOOP_TRIAL_V1_REPORT.json"

Assert-RequiredPath $AgentRoot "generated agent directory"
Assert-RequiredPath "$AgentRoot/AGENT_SPEC.json" "AGENT_SPEC.json"
Assert-RequiredPath "$AgentRoot/run.ps1" "agent run.ps1"
Assert-RequiredPath "$AgentRoot/INPUT_EXAMPLE.json" "INPUT_EXAMPLE.json"
Assert-RequiredPath "$AgentRoot/OUTPUT_EXAMPLE_RUNTIME.json" "OUTPUT_EXAMPLE_RUNTIME.json"
Assert-RequiredPath $WorkflowPath "GitHub workflow"
Assert-RequiredPath "$RunRoot/GITHUB_ACTION_OUTPUT.json" "downloaded GitHub action output"
Assert-RequiredPath "$RunRoot/AGENT_SPEC.json" "downloaded AGENT_SPEC"
Assert-RequiredPath "agent_catalog/AGENT_CATALOG.json" "agent catalog"
Assert-RequiredPath $ProofPath "proof"
Assert-RequiredPath $ReportPath "report"

$spec = Read-JsonFile "$AgentRoot/AGENT_SPEC.json"
if ([string]$spec.agent_id -ne $AgentId) {
  throw "AGENT_SPEC agent_id must be $AgentId."
}

Read-JsonFile "$AgentRoot/INPUT_EXAMPLE.json" | Out-Null
$runtimeOutput = Read-JsonFile "$AgentRoot/OUTPUT_EXAMPLE_RUNTIME.json"
if ([string]$runtimeOutput.validation_status -ne "PASS") {
  throw "OUTPUT_EXAMPLE_RUNTIME validation_status must be PASS."
}

$workflowText = Get-Content -LiteralPath $WorkflowPath -Raw
foreach ($requiredText in @("workflow_dispatch", "upload-artifact", "EVIDENCE_PACKAGER_GITHUB_ACTION_STATUS=PASS")) {
  if ($workflowText -notmatch [regex]::Escape($requiredText)) {
    throw "Workflow missing required text: $requiredText"
  }
}

$artifactOutput = Read-JsonFile "$RunRoot/GITHUB_ACTION_OUTPUT.json"
if ([string]$artifactOutput.validation_status -ne "PASS") {
  throw "Artifact output validation_status must be PASS."
}

$catalog = Read-JsonFile "agent_catalog/AGENT_CATALOG.json"
$agent = Get-OneByProperty -Items @($catalog.agents) -PropertyName "agent_id" -ExpectedValue $AgentId -Label "agent catalog"
if ([string]$agent.status -ne "ACCEPTED") {
  throw "Agent catalog status must be ACCEPTED."
}

$proof = Read-JsonFile $ProofPath
if ([string]$proof.status -ne "PASS") {
  throw "Proof status must be PASS."
}
if ([string]$proof.github_run_conclusion -ne "success") {
  throw "GitHub run conclusion must be success."
}
if ([string]$proof.artifact_validation_status -ne "PASS") {
  throw "Artifact validation status must be PASS."
}
if ([string]$proof.catalog_status_after -ne "ACCEPTED") {
  throw "Proof catalog_status_after must be ACCEPTED."
}

$state = Read-JsonFile "GENESIS_STATE.json"
$roadmap = Read-JsonFile "CAPABILITY_ROADMAP.json"
$queue = Read-JsonFile "TASK_QUEUE.json"

$capability = Get-OneByProperty -Items @($roadmap.capabilities) -PropertyName "id" -ExpectedValue $CapId -Label "PHASE77 capability"
$task = Get-OneByProperty -Items @($queue.tasks) -PropertyName "task_id" -ExpectedValue $TaskId -Label "PHASE77 task"

if ([string]$queue.active_task_id -ne "NONE") {
  throw "TASK_QUEUE active_task_id must be NONE."
}
if ([string]$capability.status -ne "COMPLETED") {
  throw "Capability status must be COMPLETED."
}
if ([string]$task.status -ne "COMPLETED") {
  throw "Task status must be COMPLETED."
}
if ([string]$state.current_phase -ne "PHASE_77") {
  throw "GENESIS_STATE current_phase must be PHASE_77."
}
if ([string]$state.current_capability -ne $CapId) {
  throw "GENESIS_STATE current_capability mismatch."
}

Write-Output "EVIDENCE_PACKAGER_AGENT_CLOSED_LOOP_TRIAL_V1_VALIDATOR=PASS"
