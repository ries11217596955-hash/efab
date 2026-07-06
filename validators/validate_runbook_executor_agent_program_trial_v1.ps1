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
        throw "$Label must not exist before PHASE72 runtime: $Path"
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

function Assert-Equals {
    param(
        [object]$Actual,
        [object]$Expected,
        [string]$Label
    )

    if ([string]$Actual -ne [string]$Expected) {
        throw "$Label expected '$Expected', got '$Actual'."
    }
}

function Assert-ArrayContainsAll {
    param(
        [object]$Actual,
        [string[]]$Expected,
        [string]$Label
    )

    $Values = @()
    if ($null -ne $Actual) {
        $Values = @($Actual | ForEach-Object { [string]$_ })
    }

    foreach ($Item in $Expected) {
        if ($Values -notcontains $Item) {
            throw "$Label missing required item: $Item"
        }
    }
}

function Assert-ObjectHasRequiredFields {
    param(
        [object]$Value,
        [string[]]$RequiredFields,
        [string]$Label
    )

    $PropertyNames = @($Value.PSObject.Properties.Name)
    foreach ($Field in $RequiredFields) {
        if ($PropertyNames -notcontains $Field) {
            throw "$Label missing required field: $Field"
        }
    }
}

function Assert-GitPathsClean {
    param(
        [string[]]$Paths,
        [string]$Label
    )

    $Arguments = @("status", "--short", "--") + $Paths
    $PreviousPreference = $ErrorActionPreference
    $Output = @()
    $ExitCode = $null

    try {
        $ErrorActionPreference = "Continue"
        $Output = @(& git @Arguments 2>&1)
        $ExitCode = $LASTEXITCODE
    }
    finally {
        $ErrorActionPreference = $PreviousPreference
    }

    if ($ExitCode -ne 0) {
        foreach ($Line in $Output) {
            Write-Host ($Line.ToString())
        }
        throw "$Label git status failed with exit code $ExitCode."
    }

    if ($Output.Count -gt 0) {
        foreach ($Line in $Output) {
            Write-Host ($Line.ToString())
        }
        throw "$Label must remain unchanged during PHASE72 runtime."
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
    throw "PHASE72 runbook executor program trial validator requires -FinalizePhase."
}

if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
    $RepoRoot = (Get-Location).Path
}
$RepoRoot = (Resolve-Path -LiteralPath $RepoRoot).Path
Set-Location $RepoRoot

$CapabilityId = "runbook_executor_agent_program_trial_v1"
$TaskId = "TASK_RUNBOOK_EXECUTOR_AGENT_PROGRAM_TRIAL_V1_001"
$AgentId = "runbook_executor_agent_v1"
$ProgramMarkdownPath = "agent_programs/runbook_executor_agent_v1/PROGRAM.md"
$ProgramJsonPath = "agent_programs/runbook_executor_agent_v1/PROGRAM.json"
$ExecutionPlanPath = "agent_program_runs/runbook_executor_agent_v1/EXECUTION_PLAN.json"
$ExecutionPlanMarkdownPath = "agent_program_runs/runbook_executor_agent_v1/EXECUTION_PLAN.md"
$ProofPath = "proofs/RUNBOOK_EXECUTOR_AGENT_PROGRAM_TRIAL_V1.json"
$ReportPath = "reports/external_agent_production/RUNBOOK_EXECUTOR_AGENT_PROGRAM_TRIAL_V1_REPORT.json"
$RequiredProgramFields = @(
    "program_id",
    "agent_id",
    "agent_name",
    "purpose",
    "owner_visible_goal",
    "input_contract",
    "output_contract",
    "required_files",
    "validation_requirements",
    "github_action_required",
    "github_action_name",
    "artifact_name",
    "acceptance_criteria",
    "forbidden_scope"
)
$RequiredProductionSteps = @(
    "create_agent_folder",
    "validate_local_runtime",
    "create_github_action",
    "register_agent_catalog"
)

Assert-PathMissing -Path (Join-Path $RepoRoot $ProofPath) -Label "PHASE72 proof"
Assert-PathMissing -Path (Join-Path $RepoRoot $ReportPath) -Label "PHASE72 report"

Assert-RequiredPath -Path (Join-Path $RepoRoot $ProgramMarkdownPath) -Label "PROGRAM.md"
Assert-RequiredPath -Path (Join-Path $RepoRoot $ProgramJsonPath) -Label "PROGRAM.json"
Assert-RequiredPath -Path (Join-Path $RepoRoot $ExecutionPlanPath) -Label "EXECUTION_PLAN.json"
Assert-RequiredPath -Path (Join-Path $RepoRoot $ExecutionPlanMarkdownPath) -Label "EXECUTION_PLAN.md"

$Program = Read-JsonFile -Path $ProgramJsonPath
$ExecutionPlan = Read-JsonFile -Path $ExecutionPlanPath

Assert-ObjectHasRequiredFields -Value $Program -RequiredFields $RequiredProgramFields -Label "PROGRAM.json"
Assert-Equals -Actual $Program.program_id -Expected "RUNBOOK_EXECUTOR_AGENT_PROGRAM_V1" -Label "PROGRAM.json program_id"
Assert-Equals -Actual $Program.agent_id -Expected $AgentId -Label "PROGRAM.json agent_id"
Assert-Equals -Actual $Program.agent_name -Expected "Runbook Executor Agent v1" -Label "PROGRAM.json agent_name"
Assert-Equals -Actual $Program.github_action_required -Expected $true -Label "PROGRAM.json github_action_required"
Assert-Equals -Actual $Program.artifact_name -Expected "runbook-executor-agent-v1-output" -Label "PROGRAM.json artifact_name"

Assert-Equals -Actual $ExecutionPlan.plan_id -Expected "RUNBOOK_EXECUTOR_AGENT_PROGRAM_EXECUTION_PLAN_V1" -Label "EXECUTION_PLAN plan_id"
Assert-Equals -Actual $ExecutionPlan.status -Expected "READY" -Label "EXECUTION_PLAN status"
Assert-Equals -Actual $ExecutionPlan.source_program_path -Expected $ProgramJsonPath -Label "EXECUTION_PLAN source_program_path"
Assert-Equals -Actual $ExecutionPlan.agent_id -Expected $AgentId -Label "EXECUTION_PLAN agent_id"
Assert-Equals -Actual $ExecutionPlan.agent_name -Expected "Runbook Executor Agent v1" -Label "EXECUTION_PLAN agent_name"
Assert-ArrayContainsAll -Actual $ExecutionPlan.production_steps -Expected $RequiredProductionSteps -Label "EXECUTION_PLAN production_steps"
Assert-Equals -Actual $ExecutionPlan.github_action_required -Expected $true -Label "EXECUTION_PLAN github_action_required"
Assert-Equals -Actual $ExecutionPlan.github_action_name -Expected "Run Runbook Executor Agent v1" -Label "EXECUTION_PLAN github_action_name"
Assert-Equals -Actual $ExecutionPlan.artifact_name -Expected "runbook-executor-agent-v1-output" -Label "EXECUTION_PLAN artifact_name"
Assert-Equals -Actual $ExecutionPlan.conclusion -Expected "Builder can read a new external agent program and prepare a production plan." -Label "EXECUTION_PLAN conclusion"

$ExecutionPlanMarkdown = Get-Content -LiteralPath $ExecutionPlanMarkdownPath -Raw
Assert-TextContains -Text $ExecutionPlanMarkdown -Needle "Какую программу Builder прочитал" -Label "EXECUTION_PLAN.md"
Assert-TextContains -Text $ExecutionPlanMarkdown -Needle "Runbook Executor Agent v1" -Label "EXECUTION_PLAN.md"
Assert-TextContains -Text $ExecutionPlanMarkdown -Needle "Run Runbook Executor Agent v1" -Label "EXECUTION_PLAN.md"
Assert-TextContains -Text $ExecutionPlanMarkdown -Needle "runbook-executor-agent-v1-output" -Label "EXECUTION_PLAN.md"
Assert-TextContains -Text $ExecutionPlanMarkdown -Needle "без создания самого агента" -Label "EXECUTION_PLAN.md"

Assert-GitPathsClean -Paths @(
    "generated_agents/remediation_intake_operator_agent_v1",
    "agent_catalog",
    ".github/workflows",
    "orchestrator/run.ps1"
) -Label "existing first agent, agent catalog, workflows, and orchestrator"

if (Test-Path -LiteralPath (Join-Path $RepoRoot "generated_agents/runbook_executor_agent_v1")) {
    throw "generated_agents/runbook_executor_agent_v1 must not exist in PHASE72 program trial."
}
if (Test-Path -LiteralPath (Join-Path $RepoRoot ".github/workflows/run-runbook-executor-agent-v1.yml")) {
    throw "Runbook executor GitHub workflow must not be created in PHASE72 program trial."
}

$State = Read-JsonFile ".\GENESIS_STATE.json"
$Roadmap = Read-JsonFile ".\CAPABILITY_ROADMAP.json"
$Queue = Read-JsonFile ".\TASK_QUEUE.json"

Assert-Equals -Actual $State.current_phase -Expected "PHASE_72" -Label "state current_phase"
Assert-Equals -Actual $State.current_capability -Expected $CapabilityId -Label "state current_capability"
Assert-Equals -Actual $Queue.active_task_id -Expected $TaskId -Label "TASK_QUEUE active_task_id before runtime"

$Capability = Get-SingleByProperty -Items @($Roadmap.capabilities) -PropertyName "id" -ExpectedValue $CapabilityId -Label "PHASE72 capability"
$Task = Get-SingleByProperty -Items @($Queue.tasks) -PropertyName "task_id" -ExpectedValue $TaskId -Label "PHASE72 task"
Assert-Equals -Actual $Capability.phase -Expected "PHASE_72" -Label "PHASE72 capability phase"
Assert-Equals -Actual $Task.capability_id -Expected $CapabilityId -Label "PHASE72 task capability_id"
Assert-Equals -Actual $Task.status -Expected "ACTIVE" -Label "PHASE72 task status before runtime"
Assert-Equals -Actual $Capability.status -Expected "ACTIVE" -Label "PHASE72 capability status before runtime"

$Proof = [ordered]@{
    proof_id = "RUNBOOK_EXECUTOR_AGENT_PROGRAM_TRIAL_V1"
    status = "PASS"
    source_program_path = $ProgramJsonPath
    execution_plan_path = $ExecutionPlanPath
    agent_id = $AgentId
    program_read_status = "PASS"
    execution_plan_status = "READY"
    active_task_after = "NONE"
    next_recommended_step = "produce_runbook_executor_agent_from_program_v1"
}

$Report = [ordered]@{
    report_id = "RUNBOOK_EXECUTOR_AGENT_PROGRAM_TRIAL_V1_REPORT"
    proof_id = "RUNBOOK_EXECUTOR_AGENT_PROGRAM_TRIAL_V1"
    status = "PASS"
    source_program_path = $ProgramJsonPath
    execution_plan_path = $ExecutionPlanPath
    execution_plan_markdown_path = $ExecutionPlanMarkdownPath
    agent_id = $AgentId
    program_read_status = "PASS"
    execution_plan_status = "READY"
    validation_summary = @(
        "PROGRAM.md exists",
        "PROGRAM.json exists, parses, and declares runbook_executor_agent_v1",
        "PROGRAM.json requires GitHub Action and expected artifact",
        "EXECUTION_PLAN.json exists and parses",
        "EXECUTION_PLAN.md exists",
        "execution plan status is READY",
        "required production steps are present",
        "existing remediation intake agent and agent_catalog remained unchanged",
        "PHASE72 task and capability completed",
        "TASK_QUEUE active_task_id returned to NONE"
    )
    created_runtime_outputs = @(
        $ExecutionPlanPath,
        $ExecutionPlanMarkdownPath,
        "validators/validate_runbook_executor_agent_program_trial_v1.ps1",
        $ProofPath,
        $ReportPath
    )
    next_recommended_step = "produce_runbook_executor_agent_from_program_v1"
}

Write-JsonFile -Path $ProofPath -Value $Proof
Write-JsonFile -Path $ReportPath -Value $Report

$Capability.status = "COMPLETED"
$Task.status = "COMPLETED"
$Queue.active_task_id = "NONE"
Add-CompletedCapability -State $State -CompletedCapabilityId $CapabilityId
$State.current_phase = "PHASE_72"
$State.current_capability = $CapabilityId
$State.last_run_status = "PASS"

Write-JsonFile -Path ".\CAPABILITY_ROADMAP.json" -Value $Roadmap
Write-JsonFile -Path ".\TASK_QUEUE.json" -Value $Queue
Write-JsonFile -Path ".\GENESIS_STATE.json" -Value $State

$FinalState = Read-JsonFile ".\GENESIS_STATE.json"
$FinalRoadmap = Read-JsonFile ".\CAPABILITY_ROADMAP.json"
$FinalQueue = Read-JsonFile ".\TASK_QUEUE.json"
$FinalCapability = Get-SingleByProperty -Items @($FinalRoadmap.capabilities) -PropertyName "id" -ExpectedValue $CapabilityId -Label "PHASE72 capability after runtime"
$FinalTask = Get-SingleByProperty -Items @($FinalQueue.tasks) -PropertyName "task_id" -ExpectedValue $TaskId -Label "PHASE72 task after runtime"
Assert-Equals -Actual $FinalCapability.status -Expected "COMPLETED" -Label "PHASE72 capability status after runtime"
Assert-Equals -Actual $FinalTask.status -Expected "COMPLETED" -Label "PHASE72 task status after runtime"
Assert-Equals -Actual $FinalQueue.active_task_id -Expected "NONE" -Label "TASK_QUEUE active_task_id after runtime"
if (@($FinalState.completed_capabilities) -notcontains $CapabilityId) {
    throw "GENESIS_STATE completed_capabilities missing $CapabilityId."
}

$FinalProof = Read-JsonFile -Path $ProofPath
Assert-Equals -Actual $FinalProof.status -Expected "PASS" -Label "RUNBOOK_EXECUTOR_AGENT_PROGRAM_TRIAL_V1 proof status"
Assert-Equals -Actual $FinalProof.active_task_after -Expected "NONE" -Label "RUNBOOK_EXECUTOR_AGENT_PROGRAM_TRIAL_V1 proof active_task_after"

Write-Host "RUNBOOK_EXECUTOR_AGENT_PROGRAM_TRIAL_V1_STATUS=PASS"
Write-Host "RUNBOOK_EXECUTOR_AGENT_PROGRAM_TRIAL_V1_PLAN=$ExecutionPlanPath"
Write-Host "RUNBOOK_EXECUTOR_AGENT_PROGRAM_TRIAL_V1_AGENT=$AgentId"
Write-Host "RUNBOOK_EXECUTOR_AGENT_PROGRAM_TRIAL_V1_ACTIVE_TASK_AFTER=NONE"
