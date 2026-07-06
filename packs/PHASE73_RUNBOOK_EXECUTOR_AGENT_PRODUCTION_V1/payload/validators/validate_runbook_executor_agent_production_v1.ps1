param(
    [switch]$FinalizePhase,
    [string]$RunId = "",
    [string]$RepoRoot = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Resolve-RepoRoot {
    param([string]$RequestedRoot)

    if ([string]::IsNullOrWhiteSpace($RequestedRoot)) {
        return (Get-Location).Path
    }

    return (Resolve-Path -LiteralPath $RequestedRoot).Path
}

function Get-RelativePath {
    param(
        [string]$Root,
        [string]$Path
    )

    return [System.IO.Path]::GetRelativePath($Root, $Path).Replace("\", "/")
}

function Assert-RequiredPath {
    param(
        [string]$Path,
        [string]$Label
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "Missing required path: $Label ($Path)"
    }
}

function Assert-PathMissing {
    param(
        [string]$Path,
        [string]$Label
    )

    if (Test-Path -LiteralPath $Path) {
        throw "Forbidden path exists: $Label ($Path)"
    }
}

function Assert-Equals {
    param(
        [object]$Actual,
        [object]$Expected,
        [string]$Label
    )

    if ($Actual -ne $Expected) {
        throw "$Label mismatch. Expected '$Expected', got '$Actual'."
    }
}

function Assert-ArrayContainsAll {
    param(
        [object[]]$Actual,
        [string[]]$Expected,
        [string]$Label
    )

    foreach ($Item in $Expected) {
        if ($Actual -notcontains $Item) {
            throw "$Label missing required item: $Item"
        }
    }
}

function Assert-ObjectHasRequiredFields {
    param(
        [object]$Object,
        [string[]]$Fields,
        [string]$Label
    )

    foreach ($Field in $Fields) {
        if ($Object.PSObject.Properties.Name -notcontains $Field) {
            throw "$Label missing required field: $Field"
        }
    }
}

function Assert-GitPathsClean {
    param(
        [string]$Root,
        [string[]]$Paths,
        [string]$Label
    )

    $Output = & git -C $Root status --short -- @Paths
    if ($LASTEXITCODE -ne 0) {
        throw "git status failed while checking $Label"
    }

    if (@($Output).Count -gt 0) {
        throw "$Label changed unexpectedly: $($Output -join '; ')"
    }
}

function Assert-PowerShellParserPass {
    param(
        [string]$Path,
        [string]$Label
    )

    $Tokens = $null
    $Errors = $null
    [System.Management.Automation.Language.Parser]::ParseFile($Path, [ref]$Tokens, [ref]$Errors) | Out-Null
    if (@($Errors).Count -gt 0) {
        throw "$Label parser check failed: $($Errors | ForEach-Object { $_.Message } | Out-String)"
    }
}

function Read-JsonFile {
    param(
        [string]$Path,
        [string]$Label
    )

    try {
        return Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json
    } catch {
        throw "$Label is not valid JSON: $($_.Exception.Message)"
    }
}

function Write-JsonFile {
    param(
        [string]$Path,
        [object]$Value
    )

    $Parent = Split-Path -Parent $Path
    if (-not [string]::IsNullOrWhiteSpace($Parent)) {
        New-Item -ItemType Directory -Force -Path $Parent | Out-Null
    }

    $Value | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $Path -Encoding UTF8
}

function Get-SingleByProperty {
    param(
        [object[]]$Items,
        [string]$Property,
        [string]$Value,
        [string]$Label
    )

    $Matches = @($Items | Where-Object { $_.$Property -eq $Value })
    if ($Matches.Count -ne 1) {
        throw "$Label expected exactly one item with $Property=$Value, found $($Matches.Count)."
    }

    return $Matches[0]
}

function Add-CompletedCapability {
    param(
        [object]$GenesisState,
        [string]$CapabilityId
    )

    $Existing = @()
    if ($GenesisState.PSObject.Properties.Name -contains "completed_capabilities") {
        $Existing = @($GenesisState.completed_capabilities)
    } else {
        $GenesisState | Add-Member -NotePropertyName "completed_capabilities" -NotePropertyValue @()
    }

    if ($Existing -notcontains $CapabilityId) {
        $GenesisState.completed_capabilities = @($Existing + $CapabilityId)
    }
}

if (-not $FinalizePhase) {
    throw "validate_runbook_executor_agent_production_v1.ps1 requires -FinalizePhase."
}

$ResolvedRoot = Resolve-RepoRoot -RequestedRoot $RepoRoot
Set-Location -LiteralPath $ResolvedRoot

$RequiredRepoFiles = @(
    "CAPABILITY_ROADMAP.json",
    "GENESIS_STATE.json",
    "TASK_QUEUE.json",
    "packs/registry.json",
    "orchestrator/run.ps1"
)
foreach ($RequiredRepoFile in $RequiredRepoFiles) {
    Assert-RequiredPath -Path (Join-Path $ResolvedRoot $RequiredRepoFile) -Label $RequiredRepoFile
}

$CapabilityId = "runbook_executor_agent_production_v1"
$TaskId = "TASK_RUNBOOK_EXECUTOR_AGENT_PRODUCTION_V1_001"
$AgentId = "runbook_executor_agent_v1"
$ExpectedArtifactName = "runbook-executor-agent-v1-output"
$ExpectedStatus = "PRODUCED_LOCAL_PENDING_GITHUB_ACTION"

$ProgramPath = Join-Path $ResolvedRoot "agent_programs/runbook_executor_agent_v1/PROGRAM.json"
$PlanPath = Join-Path $ResolvedRoot "agent_program_runs/runbook_executor_agent_v1/EXECUTION_PLAN.json"
$AgentRoot = Join-Path $ResolvedRoot "generated_agents/runbook_executor_agent_v1"
$AgentSpecPath = Join-Path $AgentRoot "AGENT_SPEC.json"
$InputExamplePath = Join-Path $AgentRoot "INPUT_EXAMPLE.json"
$OutputExamplePath = Join-Path $AgentRoot "OUTPUT_EXAMPLE.json"
$RuntimeOutputPath = Join-Path $AgentRoot "OUTPUT_EXAMPLE_RUNTIME.json"
$RunScriptPath = Join-Path $AgentRoot "run.ps1"
$CatalogPath = Join-Path $ResolvedRoot "agent_catalog/AGENT_CATALOG.json"
$CatalogCardPath = Join-Path $ResolvedRoot "agent_catalog/runbook_executor_agent_v1.md"
$SecondWorkflowPath = Join-Path $ResolvedRoot ".github/workflows/run-runbook-executor-agent-v1.yml"
$ProofPath = Join-Path $ResolvedRoot "proofs/RUNBOOK_EXECUTOR_AGENT_PRODUCTION_V1.json"
$ReportPath = Join-Path $ResolvedRoot "reports/external_agent_production/RUNBOOK_EXECUTOR_AGENT_PRODUCTION_V1_REPORT.json"

Assert-PathMissing -Path $SecondWorkflowPath -Label "Runbook Executor Agent GitHub workflow"
Assert-PathMissing -Path $ProofPath -Label "RUNBOOK_EXECUTOR_AGENT_PRODUCTION_V1 proof before validator"
Assert-PathMissing -Path $ReportPath -Label "RUNBOOK_EXECUTOR_AGENT_PRODUCTION_V1 report before validator"

$Program = Read-JsonFile -Path $ProgramPath -Label "PROGRAM.json"
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
Assert-ObjectHasRequiredFields -Object $Program -Fields $RequiredProgramFields -Label "PROGRAM.json"
Assert-Equals -Actual $Program.agent_id -Expected $AgentId -Label "PROGRAM.json agent_id"
Assert-Equals -Actual $Program.github_action_required -Expected $true -Label "PROGRAM.json github_action_required"
Assert-Equals -Actual $Program.artifact_name -Expected $ExpectedArtifactName -Label "PROGRAM.json artifact_name"

$Plan = Read-JsonFile -Path $PlanPath -Label "EXECUTION_PLAN.json"
Assert-Equals -Actual $Plan.agent_id -Expected $AgentId -Label "EXECUTION_PLAN.json agent_id"
Assert-Equals -Actual $Plan.status -Expected "READY" -Label "EXECUTION_PLAN.json status"
Assert-Equals -Actual $Plan.github_action_required -Expected $true -Label "EXECUTION_PLAN.json github_action_required"
Assert-Equals -Actual $Plan.artifact_name -Expected $ExpectedArtifactName -Label "EXECUTION_PLAN.json artifact_name"
Assert-ArrayContainsAll -Actual @($Plan.production_steps) -Expected @(
    "create_agent_folder",
    "validate_local_runtime",
    "create_github_action",
    "register_agent_catalog"
) -Label "EXECUTION_PLAN.json production_steps"

Assert-RequiredPath -Path $AgentRoot -Label "generated Runbook Executor Agent folder"
$RequiredAgentFiles = @(
    "README.md",
    "AGENT_SPEC.json",
    "RUNBOOK.md",
    "INPUT_EXAMPLE.json",
    "OUTPUT_EXAMPLE.json",
    "run.ps1",
    "proofs/README.md"
)
foreach ($RelativeAgentFile in $RequiredAgentFiles) {
    Assert-RequiredPath -Path (Join-Path $AgentRoot $RelativeAgentFile) -Label "generated agent file $RelativeAgentFile"
}

$AgentSpec = Read-JsonFile -Path $AgentSpecPath -Label "AGENT_SPEC.json"
Assert-Equals -Actual $AgentSpec.agent_id -Expected $AgentId -Label "AGENT_SPEC.json agent_id"
Assert-Equals -Actual $AgentSpec.artifact_name -Expected $ExpectedArtifactName -Label "AGENT_SPEC.json artifact_name"

$InputExample = Read-JsonFile -Path $InputExamplePath -Label "INPUT_EXAMPLE.json"
Assert-ObjectHasRequiredFields -Object $InputExample -Fields @(
    "runbook_title",
    "runbook_steps",
    "task_or_incident",
    "environment",
    "constraints"
) -Label "INPUT_EXAMPLE.json"

$OutputExample = Read-JsonFile -Path $OutputExamplePath -Label "OUTPUT_EXAMPLE.json"
Assert-ObjectHasRequiredFields -Object $OutputExample -Fields @(
    "execution_checklist",
    "risk_flags",
    "required_evidence",
    "next_operator_action",
    "validation_status"
) -Label "OUTPUT_EXAMPLE.json"

Assert-PowerShellParserPass -Path $RunScriptPath -Label "generated agent run.ps1"

if (Test-Path -LiteralPath $RuntimeOutputPath) {
    Remove-Item -LiteralPath $RuntimeOutputPath -Force
}

$RuntimeOutput = & pwsh -NoProfile -ExecutionPolicy Bypass -File $RunScriptPath -InputPath $InputExamplePath -OutputPath $RuntimeOutputPath
if ($LASTEXITCODE -ne 0) {
    throw "Runbook Executor Agent local runtime failed with exit code $LASTEXITCODE."
}

if (@($RuntimeOutput | ForEach-Object { $_.ToString() }) -notcontains "RUNBOOK_EXECUTOR_AGENT_STATUS=PASS") {
    throw "Runbook Executor Agent local runtime did not print RUNBOOK_EXECUTOR_AGENT_STATUS=PASS."
}

Assert-RequiredPath -Path $RuntimeOutputPath -Label "OUTPUT_EXAMPLE_RUNTIME.json"
$RuntimeResult = Read-JsonFile -Path $RuntimeOutputPath -Label "OUTPUT_EXAMPLE_RUNTIME.json"
Assert-ObjectHasRequiredFields -Object $RuntimeResult -Fields @(
    "execution_checklist",
    "risk_flags",
    "required_evidence",
    "next_operator_action",
    "validation_status"
) -Label "OUTPUT_EXAMPLE_RUNTIME.json"
Assert-Equals -Actual $RuntimeResult.validation_status -Expected "PASS" -Label "runtime validation_status"

$Catalog = Read-JsonFile -Path $CatalogPath -Label "AGENT_CATALOG.json"
$CatalogEntry = Get-SingleByProperty -Items @($Catalog.agents) -Property "agent_id" -Value $AgentId -Label "AGENT_CATALOG.json agents"
Assert-Equals -Actual $CatalogEntry.status -Expected $ExpectedStatus -Label "catalog status for runbook_executor_agent_v1"
Assert-Equals -Actual $CatalogEntry.local_validation -Expected "PASS" -Label "catalog local_validation for runbook_executor_agent_v1"
Assert-Equals -Actual $CatalogEntry.github_action_validation -Expected "PENDING" -Label "catalog github_action_validation for runbook_executor_agent_v1"
Assert-Equals -Actual $CatalogEntry.artifact_name -Expected $ExpectedArtifactName -Label "catalog artifact_name for runbook_executor_agent_v1"
Assert-RequiredPath -Path $CatalogCardPath -Label "runbook executor catalog markdown card"

$FirstAgentEntry = Get-SingleByProperty -Items @($Catalog.agents) -Property "agent_id" -Value "remediation_intake_operator_agent_v1" -Label "AGENT_CATALOG.json agents"
Assert-Equals -Actual $FirstAgentEntry.status -Expected "ACCEPTED" -Label "first agent catalog status"

Assert-GitPathsClean -Root $ResolvedRoot -Paths @(
    "generated_agents/remediation_intake_operator_agent_v1"
) -Label "first generated agent"
Assert-GitPathsClean -Root $ResolvedRoot -Paths @(
    ".github/workflows"
) -Label "GitHub workflows"
Assert-GitPathsClean -Root $ResolvedRoot -Paths @(
    "agent_programs",
    "agent_program_runs",
    "orchestrator/run.ps1"
) -Label "forbidden PHASE73 source paths"

$RoadmapPath = Join-Path $ResolvedRoot "CAPABILITY_ROADMAP.json"
$GenesisPath = Join-Path $ResolvedRoot "GENESIS_STATE.json"
$QueuePath = Join-Path $ResolvedRoot "TASK_QUEUE.json"

$Roadmap = Read-JsonFile -Path $RoadmapPath -Label "CAPABILITY_ROADMAP.json"
$Genesis = Read-JsonFile -Path $GenesisPath -Label "GENESIS_STATE.json"
$Queue = Read-JsonFile -Path $QueuePath -Label "TASK_QUEUE.json"

Assert-Equals -Actual $Genesis.current_phase -Expected "PHASE_73" -Label "GENESIS_STATE current_phase before finalization"
Assert-Equals -Actual $Genesis.current_capability -Expected $CapabilityId -Label "GENESIS_STATE current_capability before finalization"
Assert-Equals -Actual $Queue.active_task_id -Expected $TaskId -Label "TASK_QUEUE active_task_id before finalization"

$Capability = Get-SingleByProperty -Items @($Roadmap.capabilities) -Property "id" -Value $CapabilityId -Label "CAPABILITY_ROADMAP capabilities"
Assert-Equals -Actual $Capability.status -Expected "ACTIVE" -Label "capability status before finalization"
$Task = Get-SingleByProperty -Items @($Queue.tasks) -Property "task_id" -Value $TaskId -Label "TASK_QUEUE tasks"
Assert-Equals -Actual $Task.status -Expected "ACTIVE" -Label "task status before finalization"

$Proof = [ordered]@{
    proof_id = "RUNBOOK_EXECUTOR_AGENT_PRODUCTION_V1"
    status = "PASS"
    source_program_path = "agent_programs/runbook_executor_agent_v1/PROGRAM.json"
    execution_plan_path = "agent_program_runs/runbook_executor_agent_v1/EXECUTION_PLAN.json"
    produced_agent_id = $AgentId
    produced_agent_path = "generated_agents/runbook_executor_agent_v1"
    local_runtime_status = "PASS"
    catalog_registration_status = $ExpectedStatus
    github_action_created = $false
    active_task_after = "NONE"
    next_recommended_step = "runbook_executor_agent_github_action_launch_v1"
}

$Report = [ordered]@{
    report_id = "RUNBOOK_EXECUTOR_AGENT_PRODUCTION_V1_REPORT"
    status = "PASS"
    agent_created = "Runbook Executor Agent v1"
    agent_id = $AgentId
    source_program_path = "agent_programs/runbook_executor_agent_v1/PROGRAM.json"
    execution_plan_path = "agent_program_runs/runbook_executor_agent_v1/EXECUTION_PLAN.json"
    produced_agent_path = "generated_agents/runbook_executor_agent_v1"
    local_run_command = "pwsh -NoProfile -ExecutionPolicy Bypass -File generated_agents/runbook_executor_agent_v1/run.ps1 -InputPath generated_agents/runbook_executor_agent_v1/INPUT_EXAMPLE.json -OutputPath generated_agents/runbook_executor_agent_v1/OUTPUT_EXAMPLE_RUNTIME.json"
    checks_passed = @(
        "PROGRAM.json valid",
        "EXECUTION_PLAN.json valid",
        "required generated agent files present",
        "AGENT_SPEC.json valid",
        "INPUT_EXAMPLE.json valid",
        "OUTPUT_EXAMPLE.json valid",
        "run.ps1 parser check passed",
        "local runtime produced OUTPUT_EXAMPLE_RUNTIME.json",
        "runtime output contract present",
        "validation_status is PASS",
        "agent catalog contains runbook_executor_agent_v1",
        "catalog status is PRODUCED_LOCAL_PENDING_GITHUB_ACTION",
        "first generated agent unchanged",
        "GitHub workflow for second agent not created"
    )
    github_button_not_created_reason = "PHASE73 produces and validates the local generated agent only. GitHub Actions launch is intentionally reserved for the next phase."
    next_recommended_step = "runbook_executor_agent_github_action_launch_v1"
}

Write-JsonFile -Path $ProofPath -Value $Proof
Write-JsonFile -Path $ReportPath -Value $Report

$Capability.status = "COMPLETED"
$Task.status = "COMPLETED"
$Queue.active_task_id = "NONE"
Add-CompletedCapability -GenesisState $Genesis -CapabilityId $CapabilityId
$Genesis.current_phase = "PHASE_73"
$Genesis.current_capability = $CapabilityId
$Genesis.last_run_status = "PASS"

Write-JsonFile -Path $RoadmapPath -Value $Roadmap
Write-JsonFile -Path $QueuePath -Value $Queue
Write-JsonFile -Path $GenesisPath -Value $Genesis

$FinalRoadmap = Read-JsonFile -Path $RoadmapPath -Label "CAPABILITY_ROADMAP.json final"
$FinalQueue = Read-JsonFile -Path $QueuePath -Label "TASK_QUEUE.json final"
$FinalGenesis = Read-JsonFile -Path $GenesisPath -Label "GENESIS_STATE.json final"
$FinalProof = Read-JsonFile -Path $ProofPath -Label "RUNBOOK_EXECUTOR_AGENT_PRODUCTION_V1 proof"

$FinalCapability = Get-SingleByProperty -Items @($FinalRoadmap.capabilities) -Property "id" -Value $CapabilityId -Label "final capabilities"
$FinalTask = Get-SingleByProperty -Items @($FinalQueue.tasks) -Property "task_id" -Value $TaskId -Label "final tasks"
Assert-Equals -Actual $FinalCapability.status -Expected "COMPLETED" -Label "final capability status"
Assert-Equals -Actual $FinalTask.status -Expected "COMPLETED" -Label "final task status"
Assert-Equals -Actual $FinalQueue.active_task_id -Expected "NONE" -Label "final active_task_id"
Assert-Equals -Actual $FinalProof.status -Expected "PASS" -Label "final proof status"
Assert-Equals -Actual $FinalProof.active_task_after -Expected "NONE" -Label "final proof active_task_after"

Write-Output "RUNBOOK_EXECUTOR_AGENT_PRODUCTION_V1_VALIDATION=PASS"
