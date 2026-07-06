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

$PackRoot = Join-Path $RepoRoot "packs\PHASE73_RUNBOOK_EXECUTOR_AGENT_PRODUCTION_V1"
$ValidatorPayloadPath = Join-Path $PackRoot "payload\validators\validate_runbook_executor_agent_production_v1.ps1"
$ValidatorTargetPath = Join-Path $RepoRoot "validators\validate_runbook_executor_agent_production_v1.ps1"
$ProgramPath = "agent_programs/runbook_executor_agent_v1/PROGRAM.json"
$ExecutionPlanPath = "agent_program_runs/runbook_executor_agent_v1/EXECUTION_PLAN.json"
$AgentRootPath = "generated_agents/runbook_executor_agent_v1"
$AgentRoot = Join-Path $RepoRoot $AgentRootPath
$CatalogPath = "agent_catalog/AGENT_CATALOG.json"
$CatalogCardPath = "agent_catalog/runbook_executor_agent_v1.md"

Assert-RequiredPath -Path $ValidatorPayloadPath -Label "validator payload"
Assert-RequiredPath -Path (Join-Path $RepoRoot $ProgramPath) -Label "source PROGRAM.json"
Assert-RequiredPath -Path (Join-Path $RepoRoot $ExecutionPlanPath) -Label "source EXECUTION_PLAN.json"
Assert-RequiredPath -Path (Join-Path $RepoRoot $CatalogPath) -Label "agent catalog"

$Program = Read-JsonFile -Path $ProgramPath
$ExecutionPlan = Read-JsonFile -Path $ExecutionPlanPath
Assert-ObjectHasRequiredFields -Value $Program -RequiredFields @(
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
) -Label "PROGRAM.json"

if ([string]$Program.agent_id -ne "runbook_executor_agent_v1") {
    throw "PROGRAM.json agent_id must be runbook_executor_agent_v1."
}
if ([string]$ExecutionPlan.status -ne "READY") {
    throw "Execution plan status must be READY."
}

New-Item -ItemType Directory -Force -Path $AgentRoot | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $AgentRoot "proofs") | Out-Null

$AgentSpec = [ordered]@{
    agent_id = "runbook_executor_agent_v1"
    agent_name = "Runbook Executor Agent v1"
    agent_kind = "external_operator_agent"
    purpose = $Program.purpose
    source_program_path = $ProgramPath
    source_execution_plan_path = $ExecutionPlanPath
    github_action_required = $Program.github_action_required
    github_action_name = $Program.github_action_name
    artifact_name = $Program.artifact_name
    runtime = [ordered]@{
        entrypoint = "run.ps1"
        parameters = @(
            "-InputPath",
            "-OutputPath"
        )
        external_api_usage = $false
    }
    input_contract = $Program.input_contract
    output_contract = $Program.output_contract
    validation_contract = [ordered]@{
        required_status = "PASS"
        runtime_example_output = "generated_agents/runbook_executor_agent_v1/OUTPUT_EXAMPLE_RUNTIME.json"
        checks = @(
            "required files present",
            "JSON examples valid",
            "run.ps1 parser check passes",
            "runtime output contains checklist, risks, evidence, next action",
            "validation_status is PASS"
        )
    }
}

$InputExample = [ordered]@{
    runbook_title = "Restart stuck background worker"
    runbook_steps = @(
        "Confirm the current incident scope and affected environment.",
        "Check worker queue depth and last successful job timestamp.",
        "Restart the worker service using the approved operational command.",
        "Verify queue depth decreases and no new critical errors appear.",
        "Record evidence and hand off unresolved symptoms to engineering."
    )
    task_or_incident = "Background worker is stuck and queued remediation jobs are not progressing."
    environment = "staging"
    constraints = @(
        "Do not change production systems.",
        "Do not delete queued jobs.",
        "Collect evidence before and after restart."
    )
}

$OutputExample = [ordered]@{
    execution_checklist = @(
        "Confirm the current incident scope and affected environment.",
        "Check worker queue depth and last successful job timestamp.",
        "Restart the worker service using the approved operational command.",
        "Verify queue depth decreases and no new critical errors appear.",
        "Record evidence and hand off unresolved symptoms to engineering."
    )
    risk_flags = @(
        "Constraint: Do not change production systems.",
        "Constraint: Do not delete queued jobs.",
        "Constraint: Collect evidence before and after restart."
    )
    required_evidence = @(
        "Original runbook title and step list",
        "Task or incident description",
        "Environment where the runbook is applied",
        "Before and after observations for each executed step",
        "Final operator note with unresolved symptoms"
    )
    next_operator_action = "Execute the checklist in staging, collect evidence for each step, and escalate if validation does not pass."
    validation_status = "PASS"
}

$Readme = @'
# Runbook Executor Agent v1

Runbook Executor Agent v1 turns a runbook and a concrete task or incident into an operator-facing execution plan. It is a standalone external operator agent package and does not depend on Agent Builder internals at runtime.

## Inputs

The agent reads a JSON object with these required fields:

- `runbook_title`
- `runbook_steps`
- `task_or_incident`
- `environment`
- `constraints`

`runbook_steps` is an ordered list of instructions. `constraints` is a list of operational boundaries that should be surfaced as risks.

## Outputs

The agent writes a structured JSON object containing:

- `execution_checklist`
- `risk_flags`
- `required_evidence`
- `next_operator_action`
- `validation_status`

`validation_status` is `PASS` only after the input has been parsed, required fields have been checked, and output has been written.

## Run

From this folder:

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File .\run.ps1 -InputPath .\INPUT_EXAMPLE.json -OutputPath .\OUTPUT_EXAMPLE_RUNTIME.json
```

The script uses only local PowerShell and JSON processing. It does not call external APIs.
'@

$Runbook = @'
# Runbook Executor Agent v1 Runbook

## When To Use

Use this agent when an operator has a runbook or procedure and needs a concrete execution checklist for a specific task, incident, or environment.

## Input

Prepare a JSON file with:

- `runbook_title`: short title of the runbook or instruction.
- `runbook_steps`: ordered list of runbook steps.
- `task_or_incident`: the concrete task or incident to apply the runbook to.
- `environment`: environment, system, repository, workflow, or service involved.
- `constraints`: operational boundaries, cautions, or restrictions.

## Run

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File .\run.ps1 -InputPath .\INPUT_EXAMPLE.json -OutputPath .\OUTPUT_EXAMPLE_RUNTIME.json
```

On success, the script prints:

```text
RUNBOOK_EXECUTOR_AGENT_STATUS=PASS
```

## Read The Result

Review:

- `execution_checklist` for the concrete action sequence.
- `risk_flags` for constraints and likely operational hazards.
- `required_evidence` for proof the operator should collect.
- `next_operator_action` for the immediate next step.

## Limits

The agent does not execute the runbook, call external services, change infrastructure, or create tickets. It structures the operator plan from supplied JSON only.
'@

$ProofsReadme = @'
# Runbook Executor Agent v1 Proofs

Runtime proof is produced by the Builder PHASE73 self-build pack.

Expected proof:

```text
proofs/RUNBOOK_EXECUTOR_AGENT_PRODUCTION_V1.json
```

This folder is reserved for agent-local proof notes and future generated proof artifacts.
'@

$RunScript = @'
param(
    [string]$InputPath,
    [string]$OutputPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Read-JsonFile {
    param([string]$Path)

    if ([string]::IsNullOrWhiteSpace($Path)) {
        throw "JSON path is required."
    }
    if (-not (Test-Path -LiteralPath $Path)) {
        throw "JSON file missing: $Path"
    }

    return Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json
}

function Write-JsonFile {
    param(
        [string]$Path,
        [object]$Value
    )

    if ([string]::IsNullOrWhiteSpace($Path)) {
        throw "OutputPath is required."
    }

    $Directory = Split-Path -Parent $Path
    if (-not [string]::IsNullOrWhiteSpace($Directory) -and -not (Test-Path -LiteralPath $Directory)) {
        New-Item -ItemType Directory -Force -Path $Directory | Out-Null
    }

    $Value | ConvertTo-Json -Depth 100 | Set-Content -LiteralPath $Path -Encoding UTF8
}

function Assert-RequiredField {
    param(
        [object]$Value,
        [string]$FieldName
    )

    if ($Value.PSObject.Properties.Name -notcontains $FieldName) {
        throw "Input missing required field: $FieldName"
    }
    if ($null -eq $Value.$FieldName) {
        throw "Input field must not be null: $FieldName"
    }
    if ($Value.$FieldName -is [string] -and [string]::IsNullOrWhiteSpace([string]$Value.$FieldName)) {
        throw "Input field must not be empty: $FieldName"
    }
}

$Input = Read-JsonFile -Path $InputPath
$RequiredFields = @(
    "runbook_title",
    "runbook_steps",
    "task_or_incident",
    "environment",
    "constraints"
)

foreach ($Field in $RequiredFields) {
    Assert-RequiredField -Value $Input -FieldName $Field
}

$RunbookSteps = @($Input.runbook_steps)
if ($RunbookSteps.Count -lt 1) {
    throw "runbook_steps must contain at least one step."
}

$Constraints = @($Input.constraints)
$ExecutionChecklist = @()
$StepNumber = 1
foreach ($Step in $RunbookSteps) {
    $StepText = [string]$Step
    if ([string]::IsNullOrWhiteSpace($StepText)) {
        throw "runbook_steps contains an empty step."
    }

    $ExecutionChecklist += [ordered]@{
        step_number = $StepNumber
        action = $StepText
        operator_context = "Apply to '$($Input.task_or_incident)' in '$($Input.environment)'."
    }
    $StepNumber += 1
}

$RiskFlags = @()
foreach ($Constraint in $Constraints) {
    $ConstraintText = [string]$Constraint
    if (-not [string]::IsNullOrWhiteSpace($ConstraintText)) {
        $RiskFlags += "Constraint: $ConstraintText"
    }
}
if ($RiskFlags.Count -eq 0) {
    $RiskFlags += "No explicit constraints supplied; operator must confirm operational boundaries before execution."
}

$RequiredEvidence = @(
    "Original runbook title: $($Input.runbook_title)",
    "Task or incident: $($Input.task_or_incident)",
    "Environment: $($Input.environment)",
    "Before and after observation for each checklist step",
    "Final operator note with unresolved symptoms or confirmation of completion"
)

$Result = [ordered]@{
    execution_checklist = $ExecutionChecklist
    risk_flags = $RiskFlags
    required_evidence = $RequiredEvidence
    next_operator_action = "Review risks, execute the checklist in order, collect the required evidence, and escalate if any step cannot be completed safely."
    validation_status = "PASS"
}

Write-JsonFile -Path $OutputPath -Value $Result
Write-Output "RUNBOOK_EXECUTOR_AGENT_STATUS=PASS"
'@

Write-JsonFile -Path (Join-Path $AgentRoot "AGENT_SPEC.json") -Value $AgentSpec
Write-JsonFile -Path (Join-Path $AgentRoot "INPUT_EXAMPLE.json") -Value $InputExample
Write-JsonFile -Path (Join-Path $AgentRoot "OUTPUT_EXAMPLE.json") -Value $OutputExample
$Readme | Set-Content -LiteralPath (Join-Path $AgentRoot "README.md") -Encoding UTF8
$Runbook | Set-Content -LiteralPath (Join-Path $AgentRoot "RUNBOOK.md") -Encoding UTF8
$ProofsReadme | Set-Content -LiteralPath (Join-Path $AgentRoot "proofs\README.md") -Encoding UTF8
$RunScript | Set-Content -LiteralPath (Join-Path $AgentRoot "run.ps1") -Encoding UTF8

$RuntimeOutputPath = Join-Path $AgentRoot "OUTPUT_EXAMPLE_RUNTIME.json"
$RunOutput = @(& pwsh -NoProfile -ExecutionPolicy Bypass -File (Join-Path $AgentRoot "run.ps1") -InputPath (Join-Path $AgentRoot "INPUT_EXAMPLE.json") -OutputPath $RuntimeOutputPath 2>&1)
$RunExitCode = $LASTEXITCODE
foreach ($Line in $RunOutput) {
    Write-Host ($Line.ToString())
}
if ($RunExitCode -ne 0) {
    throw "RUNBOOK_EXECUTOR_AGENT_RUNTIME_FAILED_EXIT_CODE=$RunExitCode"
}
if (@($RunOutput | ForEach-Object { $_.ToString() }) -notcontains "RUNBOOK_EXECUTOR_AGENT_STATUS=PASS") {
    throw "RUNBOOK_EXECUTOR_AGENT_STATUS marker missing."
}

$Catalog = Read-JsonFile -Path $CatalogPath
$ExistingAgents = @($Catalog.agents | Where-Object { $_.agent_id -ne "runbook_executor_agent_v1" })
$RunbookCatalogEntry = [ordered]@{
    agent_id = "runbook_executor_agent_v1"
    agent_name = "Runbook Executor Agent v1"
    purpose = "превращает runbook и задачу в операторский план действий"
    location = "generated_agents/runbook_executor_agent_v1/"
    run_script = "generated_agents/runbook_executor_agent_v1/run.ps1"
    github_workflow = ""
    github_workflow_name = "Run Runbook Executor Agent v1"
    artifact_name = "runbook-executor-agent-v1-output"
    status = "PRODUCED_LOCAL_PENDING_GITHUB_ACTION"
    local_validation = "PASS"
    github_action_validation = "PENDING"
    proof_paths = @(
        "proofs/RUNBOOK_EXECUTOR_AGENT_PROGRAM_TRIAL_V1.json",
        "proofs/RUNBOOK_EXECUTOR_AGENT_PRODUCTION_V1.json"
    )
    report_paths = @(
        "reports/external_agent_production/RUNBOOK_EXECUTOR_AGENT_PROGRAM_TRIAL_V1_REPORT.json",
        "reports/external_agent_production/RUNBOOK_EXECUTOR_AGENT_PRODUCTION_V1_REPORT.json"
    )
    source_program_path = $ProgramPath
    execution_plan_path = $ExecutionPlanPath
}
$Catalog.agents = @($ExistingAgents + $RunbookCatalogEntry)
Write-JsonFile -Path $CatalogPath -Value $Catalog

$CatalogCard = @'
# Runbook Executor Agent v1

## Что это за агент

Runbook Executor Agent v1 - второй внешний агент, произведённый Builder из программы-заказа. Он принимает runbook, описание задачи или инцидента и превращает их в операторский план действий.

## Зачем он создан

Агент нужен, чтобы оператор мог быстрее перейти от инструкции к конкретному безопасному плану выполнения: чеклисту, рискам, доказательствам и следующему шагу.

## Что принимает

Агент принимает JSON-файл с обязательными полями:

- `runbook_title`
- `runbook_steps`
- `task_or_incident`
- `environment`
- `constraints`

## Что выдаёт

Агент создаёт JSON-результат:

- `execution_checklist`
- `risk_flags`
- `required_evidence`
- `next_operator_action`
- `validation_status`

При успешной локальной проверке `validation_status` равен `PASS`.

## Где лежит

```text
generated_agents/runbook_executor_agent_v1/
```

Точка запуска:

```text
generated_agents/runbook_executor_agent_v1/run.ps1
```

## Как запустить локально

Из корня репозитория:

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File generated_agents/runbook_executor_agent_v1/run.ps1 -InputPath generated_agents/runbook_executor_agent_v1/INPUT_EXAMPLE.json -OutputPath generated_agents/runbook_executor_agent_v1/OUTPUT_EXAMPLE_RUNTIME.json
```

## GitHub-кнопка

GitHub-кнопка для этого агента ещё не создана. Workflow `.github/workflows/run-runbook-executor-agent-v1.yml` должен быть добавлен отдельным следующим этапом.

## Какие доказательства есть

Программа и план производства:

```text
proofs/RUNBOOK_EXECUTOR_AGENT_PROGRAM_TRIAL_V1.json
reports/external_agent_production/RUNBOOK_EXECUTOR_AGENT_PROGRAM_TRIAL_V1_REPORT.json
```

Локальное производство агента:

```text
proofs/RUNBOOK_EXECUTOR_AGENT_PRODUCTION_V1.json
reports/external_agent_production/RUNBOOK_EXECUTOR_AGENT_PRODUCTION_V1_REPORT.json
```

## Текущий статус

Статус агента: `PRODUCED_LOCAL_PENDING_GITHUB_ACTION`.

Локальная validation: `PASS`.

GitHub Action validation: `PENDING`.

## Следующий шаг

Добавить GitHub Actions запуск для Runbook Executor Agent v1.
'@
$CatalogCard | Set-Content -LiteralPath (Join-Path $RepoRoot $CatalogCardPath) -Encoding UTF8

New-Item -ItemType Directory -Force -Path (Split-Path -Parent $ValidatorTargetPath) | Out-Null
Copy-Item -LiteralPath $ValidatorPayloadPath -Destination $ValidatorTargetPath -Force

& $ValidatorTargetPath -FinalizePhase -RunId $RunId -RepoRoot $RepoRoot

Invoke-NativeGitCommand -Label "ADD" -Arguments @(
    "add",
    ".\CAPABILITY_ROADMAP.json",
    ".\GENESIS_STATE.json",
    ".\TASK_QUEUE.json",
    ".\packs\registry.json",
    ".\tasks\TASK_RUNBOOK_EXECUTOR_AGENT_PRODUCTION_V1_001.json",
    ".\packs\PHASE73_RUNBOOK_EXECUTOR_AGENT_PRODUCTION_V1",
    ".\generated_agents\runbook_executor_agent_v1",
    ".\agent_catalog\AGENT_CATALOG.json",
    ".\agent_catalog\runbook_executor_agent_v1.md",
    ".\validators\validate_runbook_executor_agent_production_v1.ps1",
    ".\proofs\RUNBOOK_EXECUTOR_AGENT_PRODUCTION_V1.json",
    ".\reports\external_agent_production\RUNBOOK_EXECUTOR_AGENT_PRODUCTION_V1_REPORT.json"
)
Invoke-NativeGitCommand -Label "COMMIT" -Arguments @(
    "commit",
    "-m",
    "Produce runbook executor agent from program v1"
)
Invoke-NativeGitCommand -Label "PUSH" -Arguments @(
    "push",
    "origin",
    "main"
)

Write-Host "PACK_COMMIT_PUSH=PASS"
