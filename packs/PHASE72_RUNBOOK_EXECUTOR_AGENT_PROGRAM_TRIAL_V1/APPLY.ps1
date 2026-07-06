param(
    [string]$RepoRoot,
    [string]$RunId,
    [switch]$InvokedByOrchestrator
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Invoke-NativeGitCommand {
    param(
        [string]$Label,
        [string[]]$Arguments
    )

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

    foreach ($Line in $Output) {
        Write-Host ($Line.ToString())
    }

    if ($ExitCode -ne 0) {
        throw "GIT_${Label}_FAILED_EXIT_CODE=$ExitCode"
    }

    Write-Host "GIT_${Label}=PASS"
}

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

if (-not $InvokedByOrchestrator) { throw "Pack must be invoked by orchestrator." }
if ([string]::IsNullOrWhiteSpace($RepoRoot)) { throw "RepoRoot is required." }

$RepoRoot = (Resolve-Path -LiteralPath $RepoRoot).Path
Set-Location $RepoRoot

$PackRoot = Join-Path $RepoRoot "packs\PHASE72_RUNBOOK_EXECUTOR_AGENT_PROGRAM_TRIAL_V1"
$ValidatorPayloadPath = Join-Path $PackRoot "payload\validators\validate_runbook_executor_agent_program_trial_v1.ps1"
$ValidatorTargetPath = Join-Path $RepoRoot "validators\validate_runbook_executor_agent_program_trial_v1.ps1"
$SourceProgramPath = "agent_programs/runbook_executor_agent_v1/PROGRAM.json"
$RunRootPath = "agent_program_runs/runbook_executor_agent_v1"
$ExecutionPlanJsonPath = "$RunRootPath/EXECUTION_PLAN.json"
$ExecutionPlanMarkdownPath = "$RunRootPath/EXECUTION_PLAN.md"

Assert-RequiredPath -Path $ValidatorPayloadPath -Label "validator payload"
Assert-RequiredPath -Path (Join-Path $RepoRoot $SourceProgramPath) -Label "source PROGRAM.json"

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

$Program = Read-JsonFile -Path $SourceProgramPath
Assert-ObjectHasRequiredFields -Value $Program -RequiredFields $RequiredProgramFields -Label "PROGRAM.json"

$ProductionSteps = @(
    "create_agent_folder",
    "create_agent_spec",
    "create_readme",
    "create_runbook",
    "create_input_example",
    "create_output_example",
    "create_run_script",
    "validate_local_runtime",
    "create_github_action",
    "validate_github_artifact",
    "register_agent_catalog"
)

$ExecutionPlan = [ordered]@{
    plan_id = "RUNBOOK_EXECUTOR_AGENT_PROGRAM_EXECUTION_PLAN_V1"
    status = "READY"
    source_program_path = $SourceProgramPath
    agent_id = $Program.agent_id
    agent_name = $Program.agent_name
    production_steps = $ProductionSteps
    required_files = @($Program.required_files)
    validation_requirements = @($Program.validation_requirements)
    github_action_required = [bool]$Program.github_action_required
    github_action_name = $Program.github_action_name
    artifact_name = $Program.artifact_name
    acceptance_criteria = @($Program.acceptance_criteria)
    forbidden_scope = @($Program.forbidden_scope)
    conclusion = "Builder can read a new external agent program and prepare a production plan."
}

$ExecutionPlanMarkdown = @"
# План производства Runbook Executor Agent v1

## Какую программу Builder прочитал

Builder прочитал программу:

```text
$SourceProgramPath
```

## Какого агента она описывает

Программа описывает агента `$($Program.agent_id)` - $($Program.agent_name).

Назначение агента:

```text
$($Program.purpose)
```

Цель для владельца:

```text
$($Program.owner_visible_goal)
```

## Какие шаги производства нужны

План производства:

1. `create_agent_folder`
2. `create_agent_spec`
3. `create_readme`
4. `create_runbook`
5. `create_input_example`
6. `create_output_example`
7. `create_run_script`
8. `validate_local_runtime`
9. `create_github_action`
10. `validate_github_artifact`
11. `register_agent_catalog`

## Какие проверки нужны

Проверки из программы:

```text
$(@($Program.validation_requirements) -join "`n")
```

## Какой GitHub Action нужен

```text
$($Program.github_action_name)
```

GitHub Action обязателен:

```text
$($Program.github_action_required)
```

## Какой artifact ожидается

```text
$($Program.artifact_name)
```

## Что это доказывает

Это доказывает, что Builder может прочитать новую программу внешнего агента и подготовить production plan без создания самого агента, пакета агента или GitHub workflow.
"@

New-Item -ItemType Directory -Force -Path (Join-Path $RepoRoot $RunRootPath) | Out-Null
New-Item -ItemType Directory -Force -Path (Split-Path -Parent $ValidatorTargetPath) | Out-Null
Write-JsonFile -Path (Join-Path $RepoRoot $ExecutionPlanJsonPath) -Value $ExecutionPlan
$ExecutionPlanMarkdown | Set-Content -LiteralPath (Join-Path $RepoRoot $ExecutionPlanMarkdownPath) -Encoding UTF8
Copy-Item -LiteralPath $ValidatorPayloadPath -Destination $ValidatorTargetPath -Force

& $ValidatorTargetPath -FinalizePhase -RunId $RunId -RepoRoot $RepoRoot

Invoke-NativeGitCommand -Label "ADD" -Arguments @(
    "add",
    ".\CAPABILITY_ROADMAP.json",
    ".\GENESIS_STATE.json",
    ".\TASK_QUEUE.json",
    ".\packs\registry.json",
    ".\tasks\TASK_RUNBOOK_EXECUTOR_AGENT_PROGRAM_TRIAL_V1_001.json",
    ".\packs\PHASE72_RUNBOOK_EXECUTOR_AGENT_PROGRAM_TRIAL_V1",
    ".\agent_programs\runbook_executor_agent_v1",
    ".\agent_program_runs\runbook_executor_agent_v1",
    ".\validators\validate_runbook_executor_agent_program_trial_v1.ps1",
    ".\proofs\RUNBOOK_EXECUTOR_AGENT_PROGRAM_TRIAL_V1.json",
    ".\reports\external_agent_production\RUNBOOK_EXECUTOR_AGENT_PROGRAM_TRIAL_V1_REPORT.json"
)
Invoke-NativeGitCommand -Label "COMMIT" -Arguments @(
    "commit",
    "-m",
    "Add runbook executor agent program trial v1"
)
Invoke-NativeGitCommand -Label "PUSH" -Arguments @(
    "push",
    "origin",
    "main"
)

Write-Host "PACK_COMMIT_PUSH=PASS"
