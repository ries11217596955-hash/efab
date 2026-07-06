param(
    [switch]$FinalizePhase,
    [string]$RunId,
    [string]$RepoRoot = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Assert-RequiredPath {
    param(
        [string]$Path,
        [string]$Label
    )

    if ([string]::IsNullOrWhiteSpace($Path)) {
        throw "$Label path must not be empty."
    }
    if (-not (Test-Path -LiteralPath $Path)) {
        throw "$Label missing: $Path"
    }
}

function Assert-PathMissing {
    param(
        [string]$Path,
        [string]$Label
    )

    if (Test-Path -LiteralPath $Path) {
        throw "$Label must not exist before PHASE68 runtime: $Path"
    }
}

function Assert-TextContains {
    param(
        [string]$Text,
        [string]$Needle,
        [string]$Label
    )

    if ($Text -notmatch [regex]::Escape($Needle)) {
        throw "$Label missing text: $Needle"
    }
}

function Read-JsonFile {
    param([string]$Path)
    return Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json
}

function Write-JsonFile {
    param(
        [string]$Path,
        [object]$Value
    )

    $Directory = Split-Path -Parent $Path
    if (-not [string]::IsNullOrWhiteSpace($Directory) -and -not (Test-Path -LiteralPath $Directory)) {
        New-Item -ItemType Directory -Force -Path $Directory | Out-Null
    }

    $Value | ConvertTo-Json -Depth 100 | Set-Content -LiteralPath $Path -Encoding UTF8
}

function Add-CompletedCapability {
    param(
        [object]$State,
        [string]$CompletedCapabilityId
    )

    if (@($State.completed_capabilities) -notcontains $CompletedCapabilityId) {
        $State.completed_capabilities += $CompletedCapabilityId
    }
}

function Get-SingleByProperty {
    param(
        [object[]]$Items,
        [string]$PropertyName,
        [string]$ExpectedValue,
        [string]$Label
    )

    $Matches = @($Items | Where-Object { $_.$PropertyName -eq $ExpectedValue })
    if ($Matches.Count -ne 1) {
        throw "$Label expected exactly one item where $PropertyName = $ExpectedValue, found $($Matches.Count)."
    }

    return $Matches[0]
}

if (-not $FinalizePhase) {
    throw "PHASE68 GitHub Action launch validator requires -FinalizePhase."
}

if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
    $RepoRoot = (Get-Location).Path
}
$RepoRoot = (Resolve-Path -LiteralPath $RepoRoot).Path
Set-Location $RepoRoot

$CapabilityId = "agent_github_action_launch_v1"
$TaskId = "TASK_AGENT_GITHUB_ACTION_LAUNCH_V1_001"
$AgentId = "remediation_intake_operator_agent_v1"
$WorkflowPath = ".github/workflows/run-remediation-intake-operator-agent-v1.yml"
$WorkflowFullPath = Join-Path $RepoRoot $WorkflowPath
$AgentRoot = Join-Path $RepoRoot "generated_agents/remediation_intake_operator_agent_v1"
$ProofPath = "proofs/AGENT_GITHUB_ACTION_LAUNCH_V1.json"
$ReportPath = "reports/external_agent_production/AGENT_GITHUB_ACTION_LAUNCH_V1_REPORT.json"
$WorkflowVisibleName = "Run Remediation Intake Operator Agent v1"

Assert-PathMissing -Path (Join-Path $RepoRoot $ProofPath) -Label "PHASE68 proof"
Assert-PathMissing -Path (Join-Path $RepoRoot $ReportPath) -Label "PHASE68 report"

Assert-RequiredPath -Path $WorkflowFullPath -Label "workflow file"
Assert-RequiredPath -Path $AgentRoot -Label "agent folder"
Assert-RequiredPath -Path (Join-Path $AgentRoot "run.ps1") -Label "agent run.ps1"
Assert-RequiredPath -Path (Join-Path $AgentRoot "INPUT_EXAMPLE.json") -Label "agent INPUT_EXAMPLE.json"
Assert-RequiredPath -Path (Join-Path $AgentRoot "AGENT_SPEC.json") -Label "agent AGENT_SPEC.json"

$WorkflowText = Get-Content -LiteralPath $WorkflowFullPath -Raw
Assert-TextContains -Text $WorkflowText -Needle "workflow_dispatch:" -Label "workflow"
Assert-TextContains -Text $WorkflowText -Needle "pwsh" -Label "workflow"
Assert-TextContains -Text $WorkflowText -Needle "actions/upload-artifact" -Label "workflow"
Assert-TextContains -Text $WorkflowText -Needle "REMEDIATION_INTAKE_GITHUB_ACTION_STATUS=PASS" -Label "workflow"
Assert-TextContains -Text $WorkflowText -Needle $WorkflowVisibleName -Label "workflow"
Assert-TextContains -Text $WorkflowText -Needle "remediation-intake-operator-agent-v1-output" -Label "workflow"

$Spec = Read-JsonFile -Path (Join-Path $AgentRoot "AGENT_SPEC.json")
if ([string]$Spec.agent_id -ne $AgentId) {
    throw "AGENT_SPEC agent_id must be $AgentId."
}

$State = Read-JsonFile ".\GENESIS_STATE.json"
$Roadmap = Read-JsonFile ".\CAPABILITY_ROADMAP.json"
$Queue = Read-JsonFile ".\TASK_QUEUE.json"

if ([string]$State.current_phase -ne "PHASE_68") { throw "State current_phase must be PHASE_68 before runtime." }
if ([string]$State.current_capability -ne $CapabilityId) { throw "State current_capability must be $CapabilityId before runtime." }
if ([string]$Queue.active_task_id -ne $TaskId) { throw "TASK_QUEUE active_task_id must be $TaskId before runtime." }

$Capability = Get-SingleByProperty -Items @($Roadmap.capabilities) -PropertyName "id" -ExpectedValue $CapabilityId -Label "PHASE68 capability"
$Task = Get-SingleByProperty -Items @($Queue.tasks) -PropertyName "task_id" -ExpectedValue $TaskId -Label "PHASE68 task"
if ([string]$Capability.status -ne "ACTIVE") { throw "PHASE68 capability must be ACTIVE before runtime." }
if ([string]$Task.status -ne "ACTIVE") { throw "PHASE68 task must be ACTIVE before runtime." }

$Proof = [ordered]@{
    proof_id = "AGENT_GITHUB_ACTION_LAUNCH_V1"
    status = "PASS"
    produced_workflow_path = $WorkflowPath
    launched_agent_id = $AgentId
    github_action_visible_name = $WorkflowVisibleName
    workflow_dispatch_present = $true
    artifact_upload_present = $true
    active_task_after = "NONE"
    next_recommended_step = "run_github_action_and_verify_artifact"
}

$Report = [ordered]@{
    report_id = "AGENT_GITHUB_ACTION_LAUNCH_V1_REPORT"
    proof_id = "AGENT_GITHUB_ACTION_LAUNCH_V1"
    status = "PASS"
    launched_agent_id = $AgentId
    agent_package_path = "generated_agents/remediation_intake_operator_agent_v1"
    produced_workflow_path = $WorkflowPath
    github_action_visible_name = $WorkflowVisibleName
    owner_run_instructions = "In GitHub, open Actions, choose 'Run Remediation Intake Operator Agent v1', select 'Run workflow', and wait for the run to complete."
    expected_artifact = "remediation-intake-operator-agent-v1-output"
    expected_artifact_files = @(
        "generated_agents/remediation_intake_operator_agent_v1/GITHUB_ACTION_OUTPUT.json",
        "generated_agents/remediation_intake_operator_agent_v1/AGENT_SPEC.json",
        "generated_agents/remediation_intake_operator_agent_v1/README.md",
        "generated_agents/remediation_intake_operator_agent_v1/RUNBOOK.md"
    )
    validation_summary = @(
        "workflow file copied into .github/workflows",
        "workflow_dispatch present",
        "PowerShell run command present",
        "artifact upload present",
        "agent package and required runtime files present",
        "PHASE68 task and capability completed",
        "TASK_QUEUE active_task_id returned to NONE"
    )
    next_recommended_step = "run_github_action_and_verify_artifact"
}

Write-JsonFile -Path $ProofPath -Value $Proof
Write-JsonFile -Path $ReportPath -Value $Report

$Capability.status = "COMPLETED"
$Task.status = "COMPLETED"
$Queue.active_task_id = "NONE"
Add-CompletedCapability -State $State -CompletedCapabilityId $CapabilityId
$State.current_phase = "PHASE_68"
$State.current_capability = $CapabilityId
$State.last_run_status = "PASS"

Write-JsonFile -Path ".\CAPABILITY_ROADMAP.json" -Value $Roadmap
Write-JsonFile -Path ".\TASK_QUEUE.json" -Value $Queue
Write-JsonFile -Path ".\GENESIS_STATE.json" -Value $State

$FinalState = Read-JsonFile ".\GENESIS_STATE.json"
$FinalRoadmap = Read-JsonFile ".\CAPABILITY_ROADMAP.json"
$FinalQueue = Read-JsonFile ".\TASK_QUEUE.json"
$FinalCapability = Get-SingleByProperty -Items @($FinalRoadmap.capabilities) -PropertyName "id" -ExpectedValue $CapabilityId -Label "PHASE68 capability after runtime"
$FinalTask = Get-SingleByProperty -Items @($FinalQueue.tasks) -PropertyName "task_id" -ExpectedValue $TaskId -Label "PHASE68 task after runtime"
if ([string]$FinalCapability.status -ne "COMPLETED") { throw "PHASE68 capability must be COMPLETED after runtime." }
if ([string]$FinalTask.status -ne "COMPLETED") { throw "PHASE68 task must be COMPLETED after runtime." }
if ([string]$FinalQueue.active_task_id -ne "NONE") { throw "TASK_QUEUE active_task_id must be NONE after runtime." }
if (@($FinalState.completed_capabilities) -notcontains $CapabilityId) { throw "GENESIS_STATE completed_capabilities missing $CapabilityId." }

Write-Host "AGENT_GITHUB_ACTION_LAUNCH_V1_STATUS=PASS"
Write-Host "AGENT_GITHUB_ACTION_LAUNCH_V1_WORKFLOW=$WorkflowPath"
Write-Host "AGENT_GITHUB_ACTION_LAUNCH_V1_ACTIVE_TASK_AFTER=NONE"
