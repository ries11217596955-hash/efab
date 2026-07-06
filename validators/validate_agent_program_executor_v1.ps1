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
        throw "$Label must not exist before PHASE71 runtime: $Path"
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
        throw "$Label must remain unchanged during PHASE71 runtime."
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
    throw "PHASE71 agent program executor validator requires -FinalizePhase."
}

if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
    $RepoRoot = (Get-Location).Path
}
$RepoRoot = (Resolve-Path -LiteralPath $RepoRoot).Path
Set-Location $RepoRoot

$CapabilityId = "agent_program_executor_v1"
$TaskId = "TASK_AGENT_PROGRAM_EXECUTOR_V1_001"
$AgentId = "remediation_intake_operator_agent_v1"
$SourceProgramPath = "agent_programs/remediation_intake_operator_agent_v1/PROGRAM.json"
$ExecutionPlanPath = "agent_program_runs/remediation_intake_operator_agent_v1/EXECUTION_PLAN.json"
$ExecutionPlanMarkdownPath = "agent_program_runs/remediation_intake_operator_agent_v1/EXECUTION_PLAN.md"
$ProofPath = "proofs/AGENT_PROGRAM_EXECUTOR_V1.json"
$ReportPath = "reports/external_agent_production/AGENT_PROGRAM_EXECUTOR_V1_REPORT.json"
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

Assert-PathMissing -Path (Join-Path $RepoRoot $ProofPath) -Label "PHASE71 proof"
Assert-PathMissing -Path (Join-Path $RepoRoot $ReportPath) -Label "PHASE71 report"

Assert-RequiredPath -Path (Join-Path $RepoRoot $SourceProgramPath) -Label "source PROGRAM.json"
Assert-RequiredPath -Path (Join-Path $RepoRoot $ExecutionPlanPath) -Label "EXECUTION_PLAN.json"
Assert-RequiredPath -Path (Join-Path $RepoRoot $ExecutionPlanMarkdownPath) -Label "EXECUTION_PLAN.md"

$Program = Read-JsonFile -Path $SourceProgramPath
$ExecutionPlan = Read-JsonFile -Path $ExecutionPlanPath

Assert-ObjectHasRequiredFields -Value $Program -RequiredFields $RequiredProgramFields -Label "PROGRAM.json"
Assert-Equals -Actual $Program.agent_id -Expected $AgentId -Label "PROGRAM.json agent_id"
Assert-Equals -Actual $Program.github_action_required -Expected $true -Label "PROGRAM.json github_action_required"
Assert-Equals -Actual $Program.artifact_name -Expected "remediation-intake-operator-agent-v1-output" -Label "PROGRAM.json artifact_name"

Assert-Equals -Actual $ExecutionPlan.plan_id -Expected "AGENT_PROGRAM_EXECUTION_PLAN_REMEDIATION_INTAKE_OPERATOR_AGENT_V1" -Label "EXECUTION_PLAN plan_id"
Assert-Equals -Actual $ExecutionPlan.status -Expected "READY" -Label "EXECUTION_PLAN status"
Assert-Equals -Actual $ExecutionPlan.source_program_path -Expected $SourceProgramPath -Label "EXECUTION_PLAN source_program_path"
Assert-Equals -Actual $ExecutionPlan.agent_id -Expected $AgentId -Label "EXECUTION_PLAN agent_id"
Assert-Equals -Actual $ExecutionPlan.agent_name -Expected "Remediation Intake Operator Agent v1" -Label "EXECUTION_PLAN agent_name"
Assert-ArrayContainsAll -Actual $ExecutionPlan.production_steps -Expected $RequiredProductionSteps -Label "EXECUTION_PLAN production_steps"
Assert-Equals -Actual $ExecutionPlan.github_action_required -Expected $true -Label "EXECUTION_PLAN github_action_required"
Assert-Equals -Actual $ExecutionPlan.github_action_name -Expected "Run Remediation Intake Operator Agent v1" -Label "EXECUTION_PLAN github_action_name"
Assert-Equals -Actual $ExecutionPlan.artifact_name -Expected "remediation-intake-operator-agent-v1-output" -Label "EXECUTION_PLAN artifact_name"
Assert-Equals -Actual $ExecutionPlan.conclusion -Expected "Builder can read the agent production program and prepare an execution plan." -Label "EXECUTION_PLAN conclusion"
Assert-ArrayContainsAll -Actual $ExecutionPlan.required_files -Expected @($Program.required_files) -Label "EXECUTION_PLAN required_files"
Assert-ArrayContainsAll -Actual $ExecutionPlan.validation_requirements -Expected @($Program.validation_requirements) -Label "EXECUTION_PLAN validation_requirements"
Assert-ArrayContainsAll -Actual $ExecutionPlan.forbidden_scope -Expected @($Program.forbidden_scope) -Label "EXECUTION_PLAN forbidden_scope"

$ExecutionPlanMarkdown = Get-Content -LiteralPath $ExecutionPlanMarkdownPath -Raw
Assert-TextContains -Text $ExecutionPlanMarkdown -Needle "Какую программу Builder прочитал" -Label "EXECUTION_PLAN.md"
Assert-TextContains -Text $ExecutionPlanMarkdown -Needle "Какого агента она описывает" -Label "EXECUTION_PLAN.md"
Assert-TextContains -Text $ExecutionPlanMarkdown -Needle "Какие шаги производства нужны" -Label "EXECUTION_PLAN.md"
Assert-TextContains -Text $ExecutionPlanMarkdown -Needle "Какие проверки нужны" -Label "EXECUTION_PLAN.md"
Assert-TextContains -Text $ExecutionPlanMarkdown -Needle "Run Remediation Intake Operator Agent v1" -Label "EXECUTION_PLAN.md"
Assert-TextContains -Text $ExecutionPlanMarkdown -Needle "remediation-intake-operator-agent-v1-output" -Label "EXECUTION_PLAN.md"

Assert-GitPathsClean -Paths @(
    "generated_agents",
    "agent_catalog",
    "agent_programs",
    ".github/workflows",
    "orchestrator/run.ps1"
) -Label "existing agent, catalog, program inputs, workflows, and orchestrator"

$State = Read-JsonFile ".\GENESIS_STATE.json"
$Roadmap = Read-JsonFile ".\CAPABILITY_ROADMAP.json"
$Queue = Read-JsonFile ".\TASK_QUEUE.json"

Assert-Equals -Actual $State.current_phase -Expected "PHASE_71" -Label "state current_phase"
Assert-Equals -Actual $State.current_capability -Expected $CapabilityId -Label "state current_capability"
Assert-Equals -Actual $Queue.active_task_id -Expected $TaskId -Label "TASK_QUEUE active_task_id before runtime"

$Capability = Get-SingleByProperty -Items @($Roadmap.capabilities) -PropertyName "id" -ExpectedValue $CapabilityId -Label "PHASE71 capability"
$Task = Get-SingleByProperty -Items @($Queue.tasks) -PropertyName "task_id" -ExpectedValue $TaskId -Label "PHASE71 task"
Assert-Equals -Actual $Capability.phase -Expected "PHASE_71" -Label "PHASE71 capability phase"
Assert-Equals -Actual $Task.capability_id -Expected $CapabilityId -Label "PHASE71 task capability_id"
Assert-Equals -Actual $Task.status -Expected "ACTIVE" -Label "PHASE71 task status before runtime"
Assert-Equals -Actual $Capability.status -Expected "ACTIVE" -Label "PHASE71 capability status before runtime"

$Proof = [ordered]@{
    proof_id = "AGENT_PROGRAM_EXECUTOR_V1"
    status = "PASS"
    source_program_path = $SourceProgramPath
    execution_plan_path = $ExecutionPlanPath
    example_agent_id = $AgentId
    program_read_status = "PASS"
    execution_plan_status = "READY"
    active_task_after = "NONE"
    next_recommended_step = "produce_second_agent_from_program_v1"
}

$Report = [ordered]@{
    report_id = "AGENT_PROGRAM_EXECUTOR_V1_REPORT"
    proof_id = "AGENT_PROGRAM_EXECUTOR_V1"
    status = "PASS"
    source_program_path = $SourceProgramPath
    execution_plan_path = $ExecutionPlanPath
    execution_plan_markdown_path = $ExecutionPlanMarkdownPath
    example_agent_id = $AgentId
    program_read_status = "PASS"
    execution_plan_status = "READY"
    production_steps = @($ExecutionPlan.production_steps)
    validation_summary = @(
        "source PROGRAM.json exists and parses",
        "PROGRAM.json contains all required production fields",
        "EXECUTION_PLAN.json exists and parses",
        "EXECUTION_PLAN.md exists and explains the plan in Russian",
        "execution plan status is READY",
        "required production steps are present",
        "GitHub Action requirement and artifact name are copied from the program",
        "PHASE71 task and capability completed",
        "TASK_QUEUE active_task_id returned to NONE"
    )
    created_runtime_outputs = @(
        $ExecutionPlanPath,
        $ExecutionPlanMarkdownPath,
        "validators/validate_agent_program_executor_v1.ps1",
        $ProofPath,
        $ReportPath
    )
    next_recommended_step = "produce_second_agent_from_program_v1"
}

Write-JsonFile -Path $ProofPath -Value $Proof
Write-JsonFile -Path $ReportPath -Value $Report

$Capability.status = "COMPLETED"
$Task.status = "COMPLETED"
$Queue.active_task_id = "NONE"
Add-CompletedCapability -State $State -CompletedCapabilityId $CapabilityId
$State.current_phase = "PHASE_71"
$State.current_capability = $CapabilityId
$State.last_run_status = "PASS"

Write-JsonFile -Path ".\CAPABILITY_ROADMAP.json" -Value $Roadmap
Write-JsonFile -Path ".\TASK_QUEUE.json" -Value $Queue
Write-JsonFile -Path ".\GENESIS_STATE.json" -Value $State

$FinalState = Read-JsonFile ".\GENESIS_STATE.json"
$FinalRoadmap = Read-JsonFile ".\CAPABILITY_ROADMAP.json"
$FinalQueue = Read-JsonFile ".\TASK_QUEUE.json"
$FinalCapability = Get-SingleByProperty -Items @($FinalRoadmap.capabilities) -PropertyName "id" -ExpectedValue $CapabilityId -Label "PHASE71 capability after runtime"
$FinalTask = Get-SingleByProperty -Items @($FinalQueue.tasks) -PropertyName "task_id" -ExpectedValue $TaskId -Label "PHASE71 task after runtime"
Assert-Equals -Actual $FinalCapability.status -Expected "COMPLETED" -Label "PHASE71 capability status after runtime"
Assert-Equals -Actual $FinalTask.status -Expected "COMPLETED" -Label "PHASE71 task status after runtime"
Assert-Equals -Actual $FinalQueue.active_task_id -Expected "NONE" -Label "TASK_QUEUE active_task_id after runtime"
if (@($FinalState.completed_capabilities) -notcontains $CapabilityId) {
    throw "GENESIS_STATE completed_capabilities missing $CapabilityId."
}

$FinalProof = Read-JsonFile -Path $ProofPath
Assert-Equals -Actual $FinalProof.status -Expected "PASS" -Label "AGENT_PROGRAM_EXECUTOR_V1 proof status"
Assert-Equals -Actual $FinalProof.active_task_after -Expected "NONE" -Label "AGENT_PROGRAM_EXECUTOR_V1 proof active_task_after"

Write-Host "AGENT_PROGRAM_EXECUTOR_V1_STATUS=PASS"
Write-Host "AGENT_PROGRAM_EXECUTOR_V1_PLAN=$ExecutionPlanPath"
Write-Host "AGENT_PROGRAM_EXECUTOR_V1_EXAMPLE_AGENT=$AgentId"
Write-Host "AGENT_PROGRAM_EXECUTOR_V1_ACTIVE_TASK_AFTER=NONE"
