param(
  [string]$RepoRoot,
  [string]$RunId,
  [switch]$InvokedByOrchestrator
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
    Write-Output ($line.ToString())
  }

  if ($exitCode -ne 0) {
    throw "GIT_${Label}_FAILED_EXIT_CODE=$exitCode"
  }

  Write-Output "GIT_${Label}=PASS"
}

if (-not $InvokedByOrchestrator) {
  throw "Pack must be invoked by orchestrator."
}

if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
  throw "RepoRoot is required."
}

$RepoRoot = (Resolve-Path -LiteralPath $RepoRoot).Path
Set-Location $RepoRoot

$CapId = "agent_production_closed_loop_standard_v1"
$TaskId = "TASK_AGENT_PRODUCTION_CLOSED_LOOP_STANDARD_V1_001"
$StandardId = "AGENT_PRODUCTION_CLOSED_LOOP_STANDARD_V1"
$BasedOnAgentId = "runbook_executor_agent_v1"
$BasedOnProofPath = "proofs/RUNBOOK_EXECUTOR_AGENT_GITHUB_ACTION_ACCEPTANCE_V1.json"
$NextRecommendedStep = "run_closed_loop_trial_with_third_agent_program_v1"

$PackRoot = Join-Path $RepoRoot "packs/PHASE76_AGENT_PRODUCTION_CLOSED_LOOP_STANDARD_V1"
$ContractPayloadPath = Join-Path $PackRoot "payload/contracts/AGENT_PRODUCTION_CLOSED_LOOP_CONTRACT_V1.md"
$StateMachinePayloadPath = Join-Path $PackRoot "payload/contracts/AGENT_PRODUCTION_CLOSED_LOOP_STATE_MACHINE_V1.json"
$GuidePayloadPath = Join-Path $PackRoot "payload/docs/AGENT_PRODUCTION_CLOSED_LOOP_OPERATOR_GUIDE_V1.md"
$ValidatorPayloadPath = Join-Path $PackRoot "payload/validators/validate_agent_production_closed_loop_standard_v1.ps1"

$ContractTargetPath = "contracts/AGENT_PRODUCTION_CLOSED_LOOP_CONTRACT_V1.md"
$StateMachineTargetPath = "contracts/AGENT_PRODUCTION_CLOSED_LOOP_STATE_MACHINE_V1.json"
$GuideTargetPath = "docs/AGENT_PRODUCTION_CLOSED_LOOP_OPERATOR_GUIDE_V1.md"
$ValidatorTargetPath = "validators/validate_agent_production_closed_loop_standard_v1.ps1"
$ProofPath = "proofs/AGENT_PRODUCTION_CLOSED_LOOP_STANDARD_V1.json"
$ReportPath = "reports/external_agent_production/AGENT_PRODUCTION_CLOSED_LOOP_STANDARD_V1_REPORT.json"

Write-Output "PHASE76_AGENT_PRODUCTION_CLOSED_LOOP_STANDARD=START"

Assert-RequiredPath $ContractPayloadPath "contract payload"
Assert-RequiredPath $StateMachinePayloadPath "state machine payload"
Assert-RequiredPath $GuidePayloadPath "operator guide payload"
Assert-RequiredPath $ValidatorPayloadPath "validator payload"
Assert-RequiredPath $BasedOnProofPath "second agent acceptance proof"

New-Item -ItemType Directory -Force -Path "contracts" | Out-Null
New-Item -ItemType Directory -Force -Path "docs" | Out-Null
New-Item -ItemType Directory -Force -Path "validators" | Out-Null
New-Item -ItemType Directory -Force -Path "proofs" | Out-Null
New-Item -ItemType Directory -Force -Path "reports/external_agent_production" | Out-Null

Copy-Item -LiteralPath $ContractPayloadPath -Destination $ContractTargetPath -Force
Copy-Item -LiteralPath $StateMachinePayloadPath -Destination $StateMachineTargetPath -Force
Copy-Item -LiteralPath $GuidePayloadPath -Destination $GuideTargetPath -Force
Copy-Item -LiteralPath $ValidatorPayloadPath -Destination $ValidatorTargetPath -Force

$stateMachine = Read-JsonFile $StateMachineTargetPath
$stages = @($stateMachine.stages)
$secondAgentProof = Read-JsonFile $BasedOnProofPath

if ([string]$secondAgentProof.status -ne "PASS") {
  throw "Second agent acceptance proof status must be PASS."
}
if ([string]$secondAgentProof.catalog_status_after -ne "ACCEPTED") {
  throw "Second agent acceptance proof catalog_status_after must be ACCEPTED."
}
if ([string]$secondAgentProof.active_task_after -ne "NONE") {
  throw "Second agent acceptance proof active_task_after must be NONE."
}

$proof = [ordered]@{
  proof_id = $StandardId
  status = "PASS"
  standard_status = "ACTIVE"
  closed_loop_stage_count = $stages.Count
  based_on_accepted_agent_id = $BasedOnAgentId
  based_on_proof = $BasedOnProofPath
  required_final_agent_status = "ACCEPTED"
  required_queue_state_after = "NONE"
  active_task_after = "NONE"
  next_recommended_step = $NextRecommendedStep
}

$report = [ordered]@{
  report_id = "AGENT_PRODUCTION_CLOSED_LOOP_STANDARD_V1_REPORT"
  proof_id = $StandardId
  status = "PASS"
  standard_status = "ACTIVE"
  purpose = "Create a reusable factory standard for the proven external-agent closed loop."
  based_on_accepted_agent_id = $BasedOnAgentId
  based_on_proof = $BasedOnProofPath
  evidence_base = "Runbook Executor Agent v1 completed GitHub workflow acceptance with PASS evidence and catalog status ACCEPTED."
  mandatory_stages = $stages
  required_final_agent_status = "ACCEPTED"
  required_queue_state_after = "NONE"
  next_recommended_step = $NextRecommendedStep
  next_step_reason = "The standard must be proven against a third agent program before it becomes routine conveyor behavior."
}

Write-JsonFile -Path $ProofPath -Value $proof
Write-JsonFile -Path $ReportPath -Value $report

$state = Read-JsonFile "GENESIS_STATE.json"
$roadmap = Read-JsonFile "CAPABILITY_ROADMAP.json"
$queue = Read-JsonFile "TASK_QUEUE.json"

$capability = Get-OneByProperty -Items @($roadmap.capabilities) -PropertyName "id" -ExpectedValue $CapId -Label "PHASE76 capability"
$task = Get-OneByProperty -Items @($queue.tasks) -PropertyName "task_id" -ExpectedValue $TaskId -Label "PHASE76 task"

$capability.status = "COMPLETED"
$task.status = "COMPLETED"
$queue.active_task_id = "NONE"
$state.current_phase = "PHASE_76"
$state.current_capability = $CapId
$state.last_run_status = "PASS"
Add-UniqueString -Object $state -PropertyName "completed_capabilities" -Value $CapId

Write-JsonFile -Path "CAPABILITY_ROADMAP.json" -Value $roadmap
Write-JsonFile -Path "TASK_QUEUE.json" -Value $queue
Write-JsonFile -Path "GENESIS_STATE.json" -Value $state

& $ValidatorTargetPath -FinalizePhase -RunId $RunId -RepoRoot $RepoRoot

Invoke-NativeGitCommand -Label "ADD" -Arguments @(
  "add",
  ".\CAPABILITY_ROADMAP.json",
  ".\GENESIS_STATE.json",
  ".\TASK_QUEUE.json",
  ".\packs\registry.json",
  ".\tasks\TASK_AGENT_PRODUCTION_CLOSED_LOOP_STANDARD_V1_001.json",
  ".\packs\PHASE76_AGENT_PRODUCTION_CLOSED_LOOP_STANDARD_V1",
  ".\contracts\AGENT_PRODUCTION_CLOSED_LOOP_CONTRACT_V1.md",
  ".\contracts\AGENT_PRODUCTION_CLOSED_LOOP_STATE_MACHINE_V1.json",
  ".\docs\AGENT_PRODUCTION_CLOSED_LOOP_OPERATOR_GUIDE_V1.md",
  ".\validators\validate_agent_production_closed_loop_standard_v1.ps1",
  ".\proofs\AGENT_PRODUCTION_CLOSED_LOOP_STANDARD_V1.json",
  ".\reports\external_agent_production\AGENT_PRODUCTION_CLOSED_LOOP_STANDARD_V1_REPORT.json"
)

Invoke-NativeGitCommand -Label "COMMIT" -Arguments @(
  "commit",
  "-m",
  "Add agent production closed loop standard v1"
)

Invoke-NativeGitCommand -Label "PUSH" -Arguments @(
  "push",
  "origin",
  "main"
)

Write-Output "PACK_COMMIT_PUSH=PASS"
