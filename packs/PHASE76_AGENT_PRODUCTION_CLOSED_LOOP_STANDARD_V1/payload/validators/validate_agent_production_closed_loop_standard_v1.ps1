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

function Assert-NoGitStatusChanges {
  param([string[]]$Paths)

  $previousPreference = $ErrorActionPreference
  $output = @()
  $exitCode = $null

  try {
    $ErrorActionPreference = "Continue"
    $output = @(& git status --porcelain -- @Paths 2>&1)
    $exitCode = $LASTEXITCODE
  }
  finally {
    $ErrorActionPreference = $previousPreference
  }

  if ($exitCode -ne 0) {
    throw "GIT_STATUS_FORBIDDEN_PATHS_FAILED: $($output -join "`n")"
  }

  $changes = @($output | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) })
  if ($changes.Count -gt 0) {
    throw "Forbidden path changes detected: $($changes -join '; ')"
  }
}

if (-not $FinalizePhase) {
  throw "PHASE76 validator requires -FinalizePhase."
}

if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
  $RepoRoot = (Get-Location).Path
}

$RepoRoot = (Resolve-Path -LiteralPath $RepoRoot).Path
Set-Location $RepoRoot

$CapId = "agent_production_closed_loop_standard_v1"
$TaskId = "TASK_AGENT_PRODUCTION_CLOSED_LOOP_STANDARD_V1_001"
$StandardId = "AGENT_PRODUCTION_CLOSED_LOOP_STANDARD_V1"
$ContractPath = "contracts/AGENT_PRODUCTION_CLOSED_LOOP_CONTRACT_V1.md"
$StateMachinePath = "contracts/AGENT_PRODUCTION_CLOSED_LOOP_STATE_MACHINE_V1.json"
$GuidePath = "docs/AGENT_PRODUCTION_CLOSED_LOOP_OPERATOR_GUIDE_V1.md"
$ProofPath = "proofs/AGENT_PRODUCTION_CLOSED_LOOP_STANDARD_V1.json"
$ReportPath = "reports/external_agent_production/AGENT_PRODUCTION_CLOSED_LOOP_STANDARD_V1_REPORT.json"
$SecondAgentProofPath = "proofs/RUNBOOK_EXECUTOR_AGENT_GITHUB_ACTION_ACCEPTANCE_V1.json"

$requiredStages = @(
  "PROGRAM_ADMISSION",
  "AGENT_PACKAGE_BUILD",
  "LOCAL_RUNTIME_VALIDATION",
  "AGENT_CATALOG_REGISTRATION",
  "GITHUB_WORKFLOW_LAUNCH",
  "GITHUB_RUN_DISPATCH",
  "ARTIFACT_DOWNLOAD",
  "ARTIFACT_VALIDATION",
  "ACCEPTANCE_PROOF_REPORT",
  "CLEAN_QUEUE_RETURN"
)

Assert-RequiredPath $ContractPath "contract file"
Assert-RequiredPath $StateMachinePath "state machine JSON"
Assert-RequiredPath $GuidePath "operator guide"
Assert-RequiredPath $ProofPath "standard proof"
Assert-RequiredPath $ReportPath "standard report"
Assert-RequiredPath $SecondAgentProofPath "second agent acceptance proof"

$stateMachine = Read-JsonFile $StateMachinePath
if ([string]$stateMachine.standard_id -ne $StandardId) {
  throw "State machine standard_id must be $StandardId."
}
if ([string]$stateMachine.status -ne "ACTIVE") {
  throw "State machine status must be ACTIVE."
}

$actualStages = @($stateMachine.stages)
if ($actualStages.Count -ne $requiredStages.Count) {
  throw "State machine must contain exactly $($requiredStages.Count) stages."
}

foreach ($stage in $requiredStages) {
  if ($actualStages -notcontains $stage) {
    throw "State machine missing stage: $stage"
  }
}

if ([string]$stateMachine.required_final_agent_status -ne "ACCEPTED") {
  throw "required_final_agent_status must be ACCEPTED."
}
if ([string]$stateMachine.required_queue_state_after -ne "NONE") {
  throw "required_queue_state_after must be NONE."
}
if ([string]$stateMachine.required_artifact_validation -ne "PASS") {
  throw "required_artifact_validation must be PASS."
}
if ([string]$stateMachine.required_github_run_conclusion -ne "success") {
  throw "required_github_run_conclusion must be success."
}

$secondAgentProof = Read-JsonFile $SecondAgentProofPath
if ([string]$secondAgentProof.status -ne "PASS") {
  throw "Second agent proof status must be PASS."
}
if ([string]$secondAgentProof.catalog_status_after -ne "ACCEPTED") {
  throw "Second agent proof catalog_status_after must be ACCEPTED."
}
if ([string]$secondAgentProof.active_task_after -ne "NONE") {
  throw "Second agent proof active_task_after must be NONE."
}

$proof = Read-JsonFile $ProofPath
if ([string]$proof.status -ne "PASS") {
  throw "Standard proof status must be PASS."
}
if ([string]$proof.standard_status -ne "ACTIVE") {
  throw "Standard proof standard_status must be ACTIVE."
}
if ([int]$proof.closed_loop_stage_count -ne 10) {
  throw "Standard proof closed_loop_stage_count must be 10."
}
if ([string]$proof.active_task_after -ne "NONE") {
  throw "Standard proof active_task_after must be NONE."
}

$state = Read-JsonFile "GENESIS_STATE.json"
$roadmap = Read-JsonFile "CAPABILITY_ROADMAP.json"
$queue = Read-JsonFile "TASK_QUEUE.json"

$capability = Get-OneByProperty -Items @($roadmap.capabilities) -PropertyName "id" -ExpectedValue $CapId -Label "PHASE76 capability"
$task = Get-OneByProperty -Items @($queue.tasks) -PropertyName "task_id" -ExpectedValue $TaskId -Label "PHASE76 task"

if ([string]$queue.active_task_id -ne "NONE") {
  throw "TASK_QUEUE active_task_id must be NONE."
}
if ([string]$capability.status -ne "COMPLETED") {
  throw "Capability status must be COMPLETED."
}
if ([string]$task.status -ne "COMPLETED") {
  throw "Task status must be COMPLETED."
}
if ([string]$state.current_phase -ne "PHASE_76") {
  throw "GENESIS_STATE current_phase must be PHASE_76."
}
if ([string]$state.current_capability -ne $CapId) {
  throw "GENESIS_STATE current_capability mismatch."
}

Assert-NoGitStatusChanges -Paths @("generated_agents", ".github/workflows")

Write-Output "AGENT_PRODUCTION_CLOSED_LOOP_STANDARD_V1_STATUS=PASS"
Write-Output "AGENT_PRODUCTION_CLOSED_LOOP_STANDARD_READY=PASS"
