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
        throw "$Label must not exist before PHASE69 runtime: $Path"
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
    throw "PHASE69 agent catalog validator requires -FinalizePhase."
}

if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
    $RepoRoot = (Get-Location).Path
}
$RepoRoot = (Resolve-Path -LiteralPath $RepoRoot).Path
Set-Location $RepoRoot

$CapabilityId = "agent_catalog_v1"
$TaskId = "TASK_AGENT_CATALOG_V1_001"
$AgentId = "remediation_intake_operator_agent_v1"
$CatalogPath = "agent_catalog/AGENT_CATALOG.json"
$AgentCardPath = "agent_catalog/remediation_intake_operator_agent_v1.md"
$AgentRoot = "generated_agents/remediation_intake_operator_agent_v1"
$AgentRunScript = "generated_agents/remediation_intake_operator_agent_v1/run.ps1"
$WorkflowPath = ".github/workflows/run-remediation-intake-operator-agent-v1.yml"
$ProofPath = "proofs/AGENT_CATALOG_V1.json"
$ReportPath = "reports/external_agent_production/AGENT_CATALOG_V1_REPORT.json"
$ExpectedProofPaths = @(
    "proofs/EXTERNAL_AGENT_PRODUCTION_PROGRAM_TEST_V1.json",
    "proofs/AGENT_GITHUB_ACTION_LAUNCH_V1.json"
)
$ExpectedReportPaths = @(
    "reports/external_agent_production/EXTERNAL_AGENT_PRODUCTION_PROGRAM_TEST_V1_REPORT.json",
    "reports/external_agent_production/AGENT_GITHUB_ACTION_LAUNCH_V1_REPORT.json",
    "reports/external_agent_production/REMEDIATION_INTAKE_OPERATOR_AGENT_V1_GITHUB_ACTION_ACCEPTANCE.md"
)

Assert-PathMissing -Path (Join-Path $RepoRoot $ProofPath) -Label "PHASE69 proof"
Assert-PathMissing -Path (Join-Path $RepoRoot $ReportPath) -Label "PHASE69 report"

Assert-RequiredPath -Path (Join-Path $RepoRoot $CatalogPath) -Label "agent catalog JSON"
Assert-RequiredPath -Path (Join-Path $RepoRoot $AgentCardPath) -Label "agent markdown card"
Assert-RequiredPath -Path (Join-Path $RepoRoot $AgentRoot) -Label "registered agent folder"
Assert-RequiredPath -Path (Join-Path $RepoRoot $AgentRunScript) -Label "registered agent run.ps1"
Assert-RequiredPath -Path (Join-Path $RepoRoot $WorkflowPath) -Label "registered agent GitHub workflow"

foreach ($ExpectedProofPath in $ExpectedProofPaths) {
    Assert-RequiredPath -Path (Join-Path $RepoRoot $ExpectedProofPath) -Label "referenced proof"
}
foreach ($ExpectedReportPath in $ExpectedReportPaths) {
    Assert-RequiredPath -Path (Join-Path $RepoRoot $ExpectedReportPath) -Label "referenced report"
}

$Catalog = Read-JsonFile -Path $CatalogPath
if ([int]$Catalog.catalog_version -ne 1) { throw "catalog_version must be 1." }
Assert-Equals -Actual $Catalog.status -Expected "ACTIVE" -Label "catalog status"

$Agents = @($Catalog.agents)
if ($Agents.Count -ne 1) {
    throw "catalog must contain exactly one registered agent for AGENT_CATALOG_V1."
}
$Agent = Get-SingleByProperty -Items $Agents -PropertyName "agent_id" -ExpectedValue $AgentId -Label "agent catalog entry"

Assert-Equals -Actual $Agent.agent_name -Expected "Remediation Intake Operator Agent v1" -Label "agent_name"
Assert-Equals -Actual $Agent.purpose -Expected "принимает описание проблемы и превращает его в структурированную карточку для оператора" -Label "purpose"
Assert-Equals -Actual $Agent.location -Expected "generated_agents/remediation_intake_operator_agent_v1/" -Label "location"
Assert-Equals -Actual $Agent.run_script -Expected $AgentRunScript -Label "run_script"
Assert-Equals -Actual $Agent.github_workflow -Expected $WorkflowPath -Label "github_workflow"
Assert-Equals -Actual $Agent.github_workflow_name -Expected "Run Remediation Intake Operator Agent v1" -Label "github_workflow_name"
Assert-Equals -Actual $Agent.artifact_name -Expected "remediation-intake-operator-agent-v1-output" -Label "artifact_name"
Assert-Equals -Actual $Agent.status -Expected "ACCEPTED" -Label "agent status"
Assert-Equals -Actual $Agent.local_validation -Expected "PASS" -Label "local_validation"
Assert-Equals -Actual $Agent.github_action_validation -Expected "PASS" -Label "github_action_validation"
Assert-ArrayContainsAll -Actual $Agent.proof_paths -Expected $ExpectedProofPaths -Label "proof_paths"
Assert-ArrayContainsAll -Actual $Agent.report_paths -Expected $ExpectedReportPaths -Label "report_paths"

$CardText = Get-Content -LiteralPath $AgentCardPath -Raw
Assert-TextContains -Text $CardText -Needle "Что это за агент" -Label "agent markdown card"
Assert-TextContains -Text $CardText -Needle "Как запустить локально" -Label "agent markdown card"
Assert-TextContains -Text $CardText -Needle "Как запустить через GitHub Actions" -Label "agent markdown card"
Assert-TextContains -Text $CardText -Needle 'Статус агента: `ACCEPTED`' -Label "agent markdown card"

$WorkflowText = Get-Content -LiteralPath $WorkflowPath -Raw
Assert-TextContains -Text $WorkflowText -Needle "name: Run Remediation Intake Operator Agent v1" -Label "workflow"
Assert-TextContains -Text $WorkflowText -Needle "workflow_dispatch:" -Label "workflow"
Assert-TextContains -Text $WorkflowText -Needle "remediation-intake-operator-agent-v1-output" -Label "workflow"

$AgentSpec = Read-JsonFile -Path (Join-Path $RepoRoot "generated_agents/remediation_intake_operator_agent_v1/AGENT_SPEC.json")
Assert-Equals -Actual $AgentSpec.agent_id -Expected $AgentId -Label "AGENT_SPEC agent_id"

$State = Read-JsonFile ".\GENESIS_STATE.json"
$Roadmap = Read-JsonFile ".\CAPABILITY_ROADMAP.json"
$Queue = Read-JsonFile ".\TASK_QUEUE.json"

Assert-Equals -Actual $State.current_phase -Expected "PHASE_69" -Label "state current_phase"
Assert-Equals -Actual $State.current_capability -Expected $CapabilityId -Label "state current_capability"
Assert-Equals -Actual $Queue.active_task_id -Expected $TaskId -Label "TASK_QUEUE active_task_id before runtime"

$Capability = Get-SingleByProperty -Items @($Roadmap.capabilities) -PropertyName "id" -ExpectedValue $CapabilityId -Label "PHASE69 capability"
$Task = Get-SingleByProperty -Items @($Queue.tasks) -PropertyName "task_id" -ExpectedValue $TaskId -Label "PHASE69 task"
Assert-Equals -Actual $Capability.phase -Expected "PHASE_69" -Label "PHASE69 capability phase"
Assert-Equals -Actual $Task.capability_id -Expected $CapabilityId -Label "PHASE69 task capability_id"
Assert-Equals -Actual $Task.status -Expected "ACTIVE" -Label "PHASE69 task status before runtime"
Assert-Equals -Actual $Capability.status -Expected "ACTIVE" -Label "PHASE69 capability status before runtime"

$Proof = [ordered]@{
    proof_id = "AGENT_CATALOG_V1"
    status = "PASS"
    catalog_path = $CatalogPath
    registered_agents_count = 1
    registered_agent_ids = @($AgentId)
    active_task_after = "NONE"
    next_recommended_step = "agent_program_input_format_v1"
}

$Report = [ordered]@{
    report_id = "AGENT_CATALOG_V1_REPORT"
    proof_id = "AGENT_CATALOG_V1"
    status = "PASS"
    catalog_path = $CatalogPath
    agent_card_path = $AgentCardPath
    registered_agents_count = 1
    registered_agent_ids = @($AgentId)
    registered_agent = [ordered]@{
        agent_id = $AgentId
        agent_name = "Remediation Intake Operator Agent v1"
        location = "generated_agents/remediation_intake_operator_agent_v1/"
        github_workflow = $WorkflowPath
        artifact_name = "remediation-intake-operator-agent-v1-output"
        status = "ACCEPTED"
    }
    validation_summary = @(
        "agent_catalog/AGENT_CATALOG.json exists and parses as JSON",
        "agent markdown card exists and documents local and GitHub Actions usage",
        "remediation_intake_operator_agent_v1 is registered exactly once",
        "registered agent folder and run.ps1 exist",
        "registered GitHub workflow exists",
        "catalog proof/report references are present and point to existing evidence",
        "PHASE69 task and capability completed",
        "TASK_QUEUE active_task_id returned to NONE"
    )
    created_runtime_outputs = @(
        $CatalogPath,
        $AgentCardPath,
        $ProofPath,
        $ReportPath,
        "validators/validate_agent_catalog_v1.ps1"
    )
    next_recommended_step = "agent_program_input_format_v1"
}

Write-JsonFile -Path $ProofPath -Value $Proof
Write-JsonFile -Path $ReportPath -Value $Report

$Capability.status = "COMPLETED"
$Task.status = "COMPLETED"
$Queue.active_task_id = "NONE"
Add-CompletedCapability -State $State -CompletedCapabilityId $CapabilityId
$State.current_phase = "PHASE_69"
$State.current_capability = $CapabilityId
$State.last_run_status = "PASS"

Write-JsonFile -Path ".\CAPABILITY_ROADMAP.json" -Value $Roadmap
Write-JsonFile -Path ".\TASK_QUEUE.json" -Value $Queue
Write-JsonFile -Path ".\GENESIS_STATE.json" -Value $State

$FinalState = Read-JsonFile ".\GENESIS_STATE.json"
$FinalRoadmap = Read-JsonFile ".\CAPABILITY_ROADMAP.json"
$FinalQueue = Read-JsonFile ".\TASK_QUEUE.json"
$FinalCapability = Get-SingleByProperty -Items @($FinalRoadmap.capabilities) -PropertyName "id" -ExpectedValue $CapabilityId -Label "PHASE69 capability after runtime"
$FinalTask = Get-SingleByProperty -Items @($FinalQueue.tasks) -PropertyName "task_id" -ExpectedValue $TaskId -Label "PHASE69 task after runtime"
Assert-Equals -Actual $FinalCapability.status -Expected "COMPLETED" -Label "PHASE69 capability status after runtime"
Assert-Equals -Actual $FinalTask.status -Expected "COMPLETED" -Label "PHASE69 task status after runtime"
Assert-Equals -Actual $FinalQueue.active_task_id -Expected "NONE" -Label "TASK_QUEUE active_task_id after runtime"
if (@($FinalState.completed_capabilities) -notcontains $CapabilityId) {
    throw "GENESIS_STATE completed_capabilities missing $CapabilityId."
}

$FinalProof = Read-JsonFile -Path $ProofPath
Assert-Equals -Actual $FinalProof.status -Expected "PASS" -Label "AGENT_CATALOG_V1 proof status"
Assert-Equals -Actual $FinalProof.active_task_after -Expected "NONE" -Label "AGENT_CATALOG_V1 proof active_task_after"

Write-Host "AGENT_CATALOG_V1_STATUS=PASS"
Write-Host "AGENT_CATALOG_V1_CATALOG=$CatalogPath"
Write-Host "AGENT_CATALOG_V1_REGISTERED_AGENT_COUNT=1"
Write-Host "AGENT_CATALOG_V1_ACTIVE_TASK_AFTER=NONE"
