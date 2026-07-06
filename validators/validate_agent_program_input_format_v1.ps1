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
        throw "$Label must not exist before PHASE70 runtime: $Path"
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
        throw "$Label must remain unchanged during PHASE70 runtime."
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
    throw "PHASE70 agent program input format validator requires -FinalizePhase."
}

if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
    $RepoRoot = (Get-Location).Path
}
$RepoRoot = (Resolve-Path -LiteralPath $RepoRoot).Path
Set-Location $RepoRoot

$CapabilityId = "agent_program_input_format_v1"
$TaskId = "TASK_AGENT_PROGRAM_INPUT_FORMAT_V1_001"
$AgentId = "remediation_intake_operator_agent_v1"
$ProgramRoot = "agent_programs/"
$ReadmePath = "agent_programs/README.md"
$SchemaPath = "agent_programs/AGENT_PROGRAM_SCHEMA.json"
$TemplateMarkdownPath = "agent_programs/AGENT_PROGRAM_TEMPLATE.md"
$TemplateJsonPath = "agent_programs/AGENT_PROGRAM_TEMPLATE.json"
$ProgramMarkdownPath = "agent_programs/remediation_intake_operator_agent_v1/PROGRAM.md"
$ProgramJsonPath = "agent_programs/remediation_intake_operator_agent_v1/PROGRAM.json"
$CatalogPath = "agent_catalog/AGENT_CATALOG.json"
$ProofPath = "proofs/AGENT_PROGRAM_INPUT_FORMAT_V1.json"
$ReportPath = "reports/external_agent_production/AGENT_PROGRAM_INPUT_FORMAT_V1_REPORT.json"
$ExpectedRequiredFields = @(
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

Assert-PathMissing -Path (Join-Path $RepoRoot $ProofPath) -Label "PHASE70 proof"
Assert-PathMissing -Path (Join-Path $RepoRoot $ReportPath) -Label "PHASE70 report"

Assert-RequiredPath -Path (Join-Path $RepoRoot $ReadmePath) -Label "agent_programs README"
Assert-RequiredPath -Path (Join-Path $RepoRoot $SchemaPath) -Label "agent program schema"
Assert-RequiredPath -Path (Join-Path $RepoRoot $TemplateMarkdownPath) -Label "agent program markdown template"
Assert-RequiredPath -Path (Join-Path $RepoRoot $TemplateJsonPath) -Label "agent program JSON template"
Assert-RequiredPath -Path (Join-Path $RepoRoot $ProgramMarkdownPath) -Label "remediation intake operator PROGRAM.md"
Assert-RequiredPath -Path (Join-Path $RepoRoot $ProgramJsonPath) -Label "remediation intake operator PROGRAM.json"
Assert-RequiredPath -Path (Join-Path $RepoRoot $CatalogPath) -Label "existing agent catalog"
Assert-RequiredPath -Path (Join-Path $RepoRoot "generated_agents/remediation_intake_operator_agent_v1") -Label "existing remediation intake operator agent"
Assert-RequiredPath -Path (Join-Path $RepoRoot "generated_agents/remediation_intake_operator_agent_v1/run.ps1") -Label "existing remediation intake operator run.ps1"

$Schema = Read-JsonFile -Path $SchemaPath
$TemplateJson = Read-JsonFile -Path $TemplateJsonPath
$ProgramJson = Read-JsonFile -Path $ProgramJsonPath
$Catalog = Read-JsonFile -Path $CatalogPath

Assert-ArrayContainsAll -Actual $Schema.required -Expected $ExpectedRequiredFields -Label "AGENT_PROGRAM_SCHEMA required fields"
foreach ($RequiredField in $ExpectedRequiredFields) {
    if (-not ($Schema.properties.PSObject.Properties.Name -contains $RequiredField)) {
        throw "AGENT_PROGRAM_SCHEMA properties missing required field: $RequiredField"
    }
    if (-not ($ProgramJson.PSObject.Properties.Name -contains $RequiredField)) {
        throw "PROGRAM.json missing required field: $RequiredField"
    }
    if (-not ($TemplateJson.PSObject.Properties.Name -contains $RequiredField)) {
        throw "AGENT_PROGRAM_TEMPLATE.json missing required field: $RequiredField"
    }
}

Assert-Equals -Actual $ProgramJson.agent_id -Expected $AgentId -Label "PROGRAM.json agent_id"
Assert-Equals -Actual $ProgramJson.github_action_required -Expected $true -Label "PROGRAM.json github_action_required"
Assert-Equals -Actual $ProgramJson.artifact_name -Expected "remediation-intake-operator-agent-v1-output" -Label "PROGRAM.json artifact_name"
Assert-Equals -Actual $ProgramJson.github_action_name -Expected "Run Remediation Intake Operator Agent v1" -Label "PROGRAM.json github_action_name"
Assert-ArrayContainsAll -Actual $ProgramJson.proof_paths -Expected @(
    "proofs/EXTERNAL_AGENT_PRODUCTION_PROGRAM_TEST_V1.json",
    "proofs/AGENT_GITHUB_ACTION_LAUNCH_V1.json",
    "proofs/AGENT_CATALOG_V1.json"
) -Label "PROGRAM.json proof_paths"
Assert-ArrayContainsAll -Actual $ProgramJson.report_paths -Expected @(
    "reports/external_agent_production/EXTERNAL_AGENT_PRODUCTION_PROGRAM_TEST_V1_REPORT.json",
    "reports/external_agent_production/AGENT_GITHUB_ACTION_LAUNCH_V1_REPORT.json",
    "reports/external_agent_production/REMEDIATION_INTAKE_OPERATOR_AGENT_V1_GITHUB_ACTION_ACCEPTANCE.md",
    "reports/external_agent_production/AGENT_CATALOG_V1_REPORT.json"
) -Label "PROGRAM.json report_paths"

$ProgramMarkdown = Get-Content -LiteralPath $ProgramMarkdownPath -Raw
Assert-TextContains -Text $ProgramMarkdown -Needle "Зачем он создан" -Label "PROGRAM.md"
Assert-TextContains -Text $ProgramMarkdown -Needle "Что принимает" -Label "PROGRAM.md"
Assert-TextContains -Text $ProgramMarkdown -Needle "Что выдаёт" -Label "PROGRAM.md"
Assert-TextContains -Text $ProgramMarkdown -Needle ".github/workflows/run-remediation-intake-operator-agent-v1.yml" -Label "PROGRAM.md"
Assert-TextContains -Text $ProgramMarkdown -Needle "remediation-intake-operator-agent-v1-output" -Label "PROGRAM.md"

$CatalogAgents = @($Catalog.agents)
$CatalogAgent = Get-SingleByProperty -Items $CatalogAgents -PropertyName "agent_id" -ExpectedValue $AgentId -Label "agent catalog entry"
Assert-Equals -Actual $CatalogAgent.status -Expected "ACCEPTED" -Label "catalog agent status"
Assert-Equals -Actual $CatalogAgent.artifact_name -Expected "remediation-intake-operator-agent-v1-output" -Label "catalog artifact_name"

Assert-GitPathsClean -Paths @(
    "generated_agents",
    "agent_catalog",
    ".github/workflows",
    "orchestrator/run.ps1"
) -Label "existing agent, catalog, workflows, and orchestrator"

$State = Read-JsonFile ".\GENESIS_STATE.json"
$Roadmap = Read-JsonFile ".\CAPABILITY_ROADMAP.json"
$Queue = Read-JsonFile ".\TASK_QUEUE.json"

Assert-Equals -Actual $State.current_phase -Expected "PHASE_70" -Label "state current_phase"
Assert-Equals -Actual $State.current_capability -Expected $CapabilityId -Label "state current_capability"
Assert-Equals -Actual $Queue.active_task_id -Expected $TaskId -Label "TASK_QUEUE active_task_id before runtime"

$Capability = Get-SingleByProperty -Items @($Roadmap.capabilities) -PropertyName "id" -ExpectedValue $CapabilityId -Label "PHASE70 capability"
$Task = Get-SingleByProperty -Items @($Queue.tasks) -PropertyName "task_id" -ExpectedValue $TaskId -Label "PHASE70 task"
Assert-Equals -Actual $Capability.phase -Expected "PHASE_70" -Label "PHASE70 capability phase"
Assert-Equals -Actual $Task.capability_id -Expected $CapabilityId -Label "PHASE70 task capability_id"
Assert-Equals -Actual $Task.status -Expected "ACTIVE" -Label "PHASE70 task status before runtime"
Assert-Equals -Actual $Capability.status -Expected "ACTIVE" -Label "PHASE70 capability status before runtime"

$Proof = [ordered]@{
    proof_id = "AGENT_PROGRAM_INPUT_FORMAT_V1"
    status = "PASS"
    program_root = $ProgramRoot
    schema_path = $SchemaPath
    template_json_path = $TemplateJsonPath
    example_program_agent_id = $AgentId
    active_task_after = "NONE"
    next_recommended_step = "agent_program_executor_v1"
}

$Report = [ordered]@{
    report_id = "AGENT_PROGRAM_INPUT_FORMAT_V1_REPORT"
    proof_id = "AGENT_PROGRAM_INPUT_FORMAT_V1"
    status = "PASS"
    program_root = $ProgramRoot
    schema_path = $SchemaPath
    template_markdown_path = $TemplateMarkdownPath
    template_json_path = $TemplateJsonPath
    example_program_markdown_path = $ProgramMarkdownPath
    example_program_json_path = $ProgramJsonPath
    example_program_agent_id = $AgentId
    validation_summary = @(
        "agent_programs/README.md exists",
        "AGENT_PROGRAM_SCHEMA.json exists, parses, and declares required fields",
        "AGENT_PROGRAM_TEMPLATE.md and AGENT_PROGRAM_TEMPLATE.json exist",
        "remediation_intake_operator_agent_v1 PROGRAM.md and PROGRAM.json exist",
        "PROGRAM.json parses and declares the accepted remediation intake operator agent",
        "PROGRAM.json requires GitHub Action and expected artifact",
        "existing agent_catalog/AGENT_CATALOG.json exists",
        "existing agent, catalog, workflows, and orchestrator remained unchanged",
        "PHASE70 task and capability completed",
        "TASK_QUEUE active_task_id returned to NONE"
    )
    created_runtime_outputs = @(
        $ReadmePath,
        $SchemaPath,
        $TemplateMarkdownPath,
        $TemplateJsonPath,
        $ProgramMarkdownPath,
        $ProgramJsonPath,
        "validators/validate_agent_program_input_format_v1.ps1",
        $ProofPath,
        $ReportPath
    )
    next_recommended_step = "agent_program_executor_v1"
}

Write-JsonFile -Path $ProofPath -Value $Proof
Write-JsonFile -Path $ReportPath -Value $Report

$Capability.status = "COMPLETED"
$Task.status = "COMPLETED"
$Queue.active_task_id = "NONE"
Add-CompletedCapability -State $State -CompletedCapabilityId $CapabilityId
$State.current_phase = "PHASE_70"
$State.current_capability = $CapabilityId
$State.last_run_status = "PASS"

Write-JsonFile -Path ".\CAPABILITY_ROADMAP.json" -Value $Roadmap
Write-JsonFile -Path ".\TASK_QUEUE.json" -Value $Queue
Write-JsonFile -Path ".\GENESIS_STATE.json" -Value $State

$FinalState = Read-JsonFile ".\GENESIS_STATE.json"
$FinalRoadmap = Read-JsonFile ".\CAPABILITY_ROADMAP.json"
$FinalQueue = Read-JsonFile ".\TASK_QUEUE.json"
$FinalCapability = Get-SingleByProperty -Items @($FinalRoadmap.capabilities) -PropertyName "id" -ExpectedValue $CapabilityId -Label "PHASE70 capability after runtime"
$FinalTask = Get-SingleByProperty -Items @($FinalQueue.tasks) -PropertyName "task_id" -ExpectedValue $TaskId -Label "PHASE70 task after runtime"
Assert-Equals -Actual $FinalCapability.status -Expected "COMPLETED" -Label "PHASE70 capability status after runtime"
Assert-Equals -Actual $FinalTask.status -Expected "COMPLETED" -Label "PHASE70 task status after runtime"
Assert-Equals -Actual $FinalQueue.active_task_id -Expected "NONE" -Label "TASK_QUEUE active_task_id after runtime"
if (@($FinalState.completed_capabilities) -notcontains $CapabilityId) {
    throw "GENESIS_STATE completed_capabilities missing $CapabilityId."
}

$FinalProof = Read-JsonFile -Path $ProofPath
Assert-Equals -Actual $FinalProof.status -Expected "PASS" -Label "AGENT_PROGRAM_INPUT_FORMAT_V1 proof status"
Assert-Equals -Actual $FinalProof.active_task_after -Expected "NONE" -Label "AGENT_PROGRAM_INPUT_FORMAT_V1 proof active_task_after"

Write-Host "AGENT_PROGRAM_INPUT_FORMAT_V1_STATUS=PASS"
Write-Host "AGENT_PROGRAM_INPUT_FORMAT_V1_ROOT=$ProgramRoot"
Write-Host "AGENT_PROGRAM_INPUT_FORMAT_V1_EXAMPLE_AGENT=$AgentId"
Write-Host "AGENT_PROGRAM_INPUT_FORMAT_V1_ACTIVE_TASK_AFTER=NONE"
