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

$PackRoot = Join-Path $RepoRoot "packs\PHASE69_AGENT_CATALOG_V1"
$ValidatorPayloadPath = Join-Path $PackRoot "payload\validators\validate_agent_catalog_v1.ps1"
$ValidatorTargetPath = Join-Path $RepoRoot "validators\validate_agent_catalog_v1.ps1"
$CatalogDirectory = Join-Path $RepoRoot "agent_catalog"
$CatalogPath = Join-Path $CatalogDirectory "AGENT_CATALOG.json"
$AgentCardPath = Join-Path $CatalogDirectory "remediation_intake_operator_agent_v1.md"
$AgentRoot = Join-Path $RepoRoot "generated_agents\remediation_intake_operator_agent_v1"
$WorkflowPath = Join-Path $RepoRoot ".github\workflows\run-remediation-intake-operator-agent-v1.yml"

Assert-RequiredPath -Path $ValidatorPayloadPath -Label "validator payload"
Assert-RequiredPath -Path $AgentRoot -Label "remediation intake operator agent folder"
Assert-RequiredPath -Path (Join-Path $AgentRoot "run.ps1") -Label "remediation intake operator agent run.ps1"
Assert-RequiredPath -Path $WorkflowPath -Label "remediation intake operator GitHub workflow"

New-Item -ItemType Directory -Force -Path $CatalogDirectory | Out-Null
New-Item -ItemType Directory -Force -Path (Split-Path -Parent $ValidatorTargetPath) | Out-Null

$Catalog = [ordered]@{
    catalog_version = 1
    status = "ACTIVE"
    agents = @(
        [ordered]@{
            agent_id = "remediation_intake_operator_agent_v1"
            agent_name = "Remediation Intake Operator Agent v1"
            purpose = "принимает описание проблемы и превращает его в структурированную карточку для оператора"
            location = "generated_agents/remediation_intake_operator_agent_v1/"
            run_script = "generated_agents/remediation_intake_operator_agent_v1/run.ps1"
            github_workflow = ".github/workflows/run-remediation-intake-operator-agent-v1.yml"
            github_workflow_name = "Run Remediation Intake Operator Agent v1"
            artifact_name = "remediation-intake-operator-agent-v1-output"
            status = "ACCEPTED"
            local_validation = "PASS"
            github_action_validation = "PASS"
            proof_paths = @(
                "proofs/EXTERNAL_AGENT_PRODUCTION_PROGRAM_TEST_V1.json",
                "proofs/AGENT_GITHUB_ACTION_LAUNCH_V1.json"
            )
            report_paths = @(
                "reports/external_agent_production/EXTERNAL_AGENT_PRODUCTION_PROGRAM_TEST_V1_REPORT.json",
                "reports/external_agent_production/AGENT_GITHUB_ACTION_LAUNCH_V1_REPORT.json",
                "reports/external_agent_production/REMEDIATION_INTAKE_OPERATOR_AGENT_V1_GITHUB_ACTION_ACCEPTANCE.md"
            )
        }
    )
}

$AgentCard = @'
# Remediation Intake Operator Agent v1

## Что это за агент

Remediation Intake Operator Agent v1 - первый принятый внешний агент Builder. Он работает как операторский intake-агент: принимает описание проблемы и превращает его в структурированную карточку для дальнейшей обработки человеком.

## Зачем он создан

Агент нужен, чтобы у оператора был повторяемый первый шаг для входящих проблем, дефектов, инцидентов или remediation-запросов. Он не чинит систему сам и не делает root cause analysis; его задача - нормализовать входные данные и подготовить понятную карточку.

## Что принимает на вход

Агент принимает JSON-файл с обязательными полями:

- `problem_title`
- `problem_description`
- `affected_system`
- `urgency`
- `observed_evidence`

Поле `urgency` принимает значения `low`, `medium`, `high` или `critical`. Поле `observed_evidence` содержит список наблюдений, логов, ссылок, run ID или других фактов.

## Что выдаёт

Агент создаёт JSON-результат со структурированной карточкой:

- `normalized_problem`
- `severity`
- `likely_area`
- `missing_information`
- `recommended_next_step`
- `operator_note`
- `validation_status`

При успешной локальной проверке `validation_status` равен `PASS`.

## Где лежит

Пакет агента находится здесь:

```text
generated_agents/remediation_intake_operator_agent_v1/
```

Точка запуска:

```text
generated_agents/remediation_intake_operator_agent_v1/run.ps1
```

## Как запустить локально

Из корня репозитория:

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File generated_agents/remediation_intake_operator_agent_v1/run.ps1 -InputPath generated_agents/remediation_intake_operator_agent_v1/INPUT_EXAMPLE.json -OutputPath generated_agents/remediation_intake_operator_agent_v1/OUTPUT_EXAMPLE_RUNTIME.json
```

## Как запустить через GitHub Actions

В GitHub нужно открыть Actions, выбрать workflow `Run Remediation Intake Operator Agent v1` и нажать `Run workflow`.

Workflow-файл:

```text
.github/workflows/run-remediation-intake-operator-agent-v1.yml
```

Ожидаемый artifact:

```text
remediation-intake-operator-agent-v1-output
```

## Какие доказательства есть

Локальная production-проверка:

```text
proofs/EXTERNAL_AGENT_PRODUCTION_PROGRAM_TEST_V1.json
reports/external_agent_production/EXTERNAL_AGENT_PRODUCTION_PROGRAM_TEST_V1_REPORT.json
```

GitHub Actions launch-проверка:

```text
proofs/AGENT_GITHUB_ACTION_LAUNCH_V1.json
reports/external_agent_production/AGENT_GITHUB_ACTION_LAUNCH_V1_REPORT.json
reports/external_agent_production/REMEDIATION_INTAKE_OPERATOR_AGENT_V1_GITHUB_ACTION_ACCEPTANCE.md
```

## Текущий статус

Статус агента: `ACCEPTED`.

Локальная validation: `PASS`.

GitHub Action validation: `PASS`.
'@

Write-JsonFile -Path $CatalogPath -Value $Catalog
$AgentCard | Set-Content -LiteralPath $AgentCardPath -Encoding UTF8
Copy-Item -LiteralPath $ValidatorPayloadPath -Destination $ValidatorTargetPath -Force

& $ValidatorTargetPath -FinalizePhase -RunId $RunId -RepoRoot $RepoRoot

Invoke-NativeGitCommand -Label "ADD" -Arguments @(
    "add",
    ".\CAPABILITY_ROADMAP.json",
    ".\GENESIS_STATE.json",
    ".\TASK_QUEUE.json",
    ".\packs\registry.json",
    ".\tasks\TASK_AGENT_CATALOG_V1_001.json",
    ".\packs\PHASE69_AGENT_CATALOG_V1",
    ".\agent_catalog\AGENT_CATALOG.json",
    ".\agent_catalog\remediation_intake_operator_agent_v1.md",
    ".\validators\validate_agent_catalog_v1.ps1",
    ".\proofs\AGENT_CATALOG_V1.json",
    ".\reports\external_agent_production\AGENT_CATALOG_V1_REPORT.json"
)
Invoke-NativeGitCommand -Label "COMMIT" -Arguments @(
    "commit",
    "-m",
    "Add Builder agent catalog v1"
)
Invoke-NativeGitCommand -Label "PUSH" -Arguments @(
    "push",
    "origin",
    "main"
)

Write-Host "PACK_COMMIT_PUSH=PASS"
