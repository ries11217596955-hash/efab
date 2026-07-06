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

$PackRoot = Join-Path $RepoRoot "packs\PHASE70_AGENT_PROGRAM_INPUT_FORMAT_V1"
$ValidatorPayloadPath = Join-Path $PackRoot "payload\validators\validate_agent_program_input_format_v1.ps1"
$ValidatorTargetPath = Join-Path $RepoRoot "validators\validate_agent_program_input_format_v1.ps1"
$ProgramRoot = Join-Path $RepoRoot "agent_programs"
$ExampleProgramRoot = Join-Path $ProgramRoot "remediation_intake_operator_agent_v1"

Assert-RequiredPath -Path $ValidatorPayloadPath -Label "validator payload"
Assert-RequiredPath -Path (Join-Path $RepoRoot "agent_catalog\AGENT_CATALOG.json") -Label "agent catalog"
Assert-RequiredPath -Path (Join-Path $RepoRoot "generated_agents\remediation_intake_operator_agent_v1") -Label "remediation intake operator agent folder"
Assert-RequiredPath -Path (Join-Path $RepoRoot "generated_agents\remediation_intake_operator_agent_v1\run.ps1") -Label "remediation intake operator agent run.ps1"

New-Item -ItemType Directory -Force -Path $ProgramRoot | Out-Null
New-Item -ItemType Directory -Force -Path $ExampleProgramRoot | Out-Null
New-Item -ItemType Directory -Force -Path (Split-Path -Parent $ValidatorTargetPath) | Out-Null

$Readme = @'
# Agent Programs

`agent_programs/` is the standard input surface for future external-agent production.

A program is an owner-visible production request. It says what agent should be built, why it should exist, what it accepts, what it returns, which files must be produced, how it must be validated, and which scope boundaries must not be crossed.

## Files

- `AGENT_PROGRAM_SCHEMA.json` defines the required machine-readable fields.
- `AGENT_PROGRAM_TEMPLATE.md` is the human-facing writing template.
- `AGENT_PROGRAM_TEMPLATE.json` is the machine-facing JSON template.
- `<agent_id>/PROGRAM.md` explains one concrete production program.
- `<agent_id>/PROGRAM.json` is the corresponding structured program input.

## Required Fields

Every `PROGRAM.json` must include:

- `program_id`
- `agent_id`
- `agent_name`
- `purpose`
- `owner_visible_goal`
- `input_contract`
- `output_contract`
- `required_files`
- `validation_requirements`
- `github_action_required`
- `github_action_name`
- `artifact_name`
- `acceptance_criteria`
- `forbidden_scope`

## First Example

The first example program describes the accepted `remediation_intake_operator_agent_v1` package. It is a reference for future agent production requests; it does not create another agent by itself.
'@

$TemplateMarkdown = @'
# <Agent Name>

## Program Identity

- Program ID: `<program_id>`
- Agent ID: `<agent_id>`
- Agent name: `<agent_name>`

## Purpose

Describe why this agent should exist and what operator-visible problem it solves.

## Owner-Visible Goal

State the concrete human outcome expected after the agent is produced.

## Input Contract

List required input fields, allowed values, and any validation rules.

## Output Contract

List required output fields, expected status fields, and any routing or handoff structure.

## Required Files

List every file the generated agent package must contain.

## Validation Requirements

List local validation, runtime validation, proof, report, and GitHub Actions checks.

## GitHub Actions

- Required: `<true|false>`
- Workflow name: `<github_action_name>`
- Artifact name: `<artifact_name>`

## Acceptance Criteria

Define what must be true before Builder can mark the agent as accepted.

## Forbidden Scope

List what Builder must not create, edit, delete, or claim during this production program.
'@

$ExampleProgramMarkdown = @'
# Remediation Intake Operator Agent v1 Production Program

## Зачем он создан

`remediation_intake_operator_agent_v1` создан как первый принятый внешний агент Builder. Он нужен, чтобы принимать сырое описание проблемы, дефекта, инцидента или remediation-запроса и превращать его в структурированную карточку для оператора.

## Что принимает

Агент принимает JSON-файл с полями:

- `problem_title`
- `problem_description`
- `affected_system`
- `urgency`
- `observed_evidence`

`urgency` принимает значения `low`, `medium`, `high` или `critical`. `observed_evidence` содержит список наблюдений, логов, ссылок или других фактов.

## Что выдаёт

Агент создаёт JSON-результат:

- `normalized_problem`
- `severity`
- `likely_area`
- `missing_information`
- `recommended_next_step`
- `operator_note`
- `validation_status`

Успешный результат содержит `validation_status = PASS`.

## Где лежит

```text
generated_agents/remediation_intake_operator_agent_v1/
```

Точка запуска:

```text
generated_agents/remediation_intake_operator_agent_v1/run.ps1
```

## Какой GitHub Action запускает

Workflow:

```text
.github/workflows/run-remediation-intake-operator-agent-v1.yml
```

Название в GitHub Actions:

```text
Run Remediation Intake Operator Agent v1
```

## Какой artifact создаёт

```text
remediation-intake-operator-agent-v1-output
```

## Какие proof/report подтверждают результат

```text
proofs/EXTERNAL_AGENT_PRODUCTION_PROGRAM_TEST_V1.json
proofs/AGENT_GITHUB_ACTION_LAUNCH_V1.json
proofs/AGENT_CATALOG_V1.json
reports/external_agent_production/EXTERNAL_AGENT_PRODUCTION_PROGRAM_TEST_V1_REPORT.json
reports/external_agent_production/AGENT_GITHUB_ACTION_LAUNCH_V1_REPORT.json
reports/external_agent_production/REMEDIATION_INTAKE_OPERATOR_AGENT_V1_GITHUB_ACTION_ACCEPTANCE.md
reports/external_agent_production/AGENT_CATALOG_V1_REPORT.json
```

## Статус

Агент принят как первый внешний агент Builder: `ACCEPTED`.
'@

$RequiredFields = @(
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

$Schema = [ordered]@{
    '$schema' = "https://json-schema.org/draft/2020-12/schema"
    schema_id = "AGENT_PROGRAM_SCHEMA_V1"
    title = "Agent Production Program Schema v1"
    type = "object"
    additionalProperties = $true
    required = $RequiredFields
    properties = [ordered]@{
        program_id = [ordered]@{ type = "string"; minLength = 1 }
        agent_id = [ordered]@{ type = "string"; minLength = 1 }
        agent_name = [ordered]@{ type = "string"; minLength = 1 }
        purpose = [ordered]@{ type = "string"; minLength = 1 }
        owner_visible_goal = [ordered]@{ type = "string"; minLength = 1 }
        input_contract = [ordered]@{ type = "object"; description = "Required input shape, fields, allowed values, and validation notes." }
        output_contract = [ordered]@{ type = "object"; description = "Required output shape, fields, status markers, and handoff notes." }
        required_files = [ordered]@{ type = "array"; items = [ordered]@{ type = "string" }; minItems = 1 }
        validation_requirements = [ordered]@{ type = "array"; items = [ordered]@{ type = "string" }; minItems = 1 }
        github_action_required = [ordered]@{ type = "boolean" }
        github_action_name = [ordered]@{ type = "string" }
        artifact_name = [ordered]@{ type = "string" }
        acceptance_criteria = [ordered]@{ type = "array"; items = [ordered]@{ type = "string" }; minItems = 1 }
        forbidden_scope = [ordered]@{ type = "array"; items = [ordered]@{ type = "string" }; minItems = 1 }
    }
}

$TemplateJson = [ordered]@{
    program_id = "PROGRAM_<AGENT_ID>_V1"
    agent_id = "<agent_id>"
    agent_name = "<Agent Name>"
    purpose = "<Short purpose statement>"
    owner_visible_goal = "<Human outcome expected from the produced agent>"
    input_contract = [ordered]@{
        type = "object"
        required = @("<field_name>")
        fields = [ordered]@{
            field_name = [ordered]@{
                type = "string"
                description = "<What the field means>"
            }
        }
    }
    output_contract = [ordered]@{
        type = "object"
        required = @("<output_field>")
        fields = [ordered]@{
            output_field = [ordered]@{
                type = "string"
                description = "<What the output means>"
            }
        }
    }
    required_files = @(
        "generated_agents/<agent_id>/AGENT_SPEC.json",
        "generated_agents/<agent_id>/README.md",
        "generated_agents/<agent_id>/RUNBOOK.md",
        "generated_agents/<agent_id>/run.ps1"
    )
    validation_requirements = @(
        "required files exist",
        "runtime script passes parser check",
        "example input produces valid output",
        "proof and report are written only after validation"
    )
    github_action_required = $true
    github_action_name = "<GitHub Actions workflow visible name>"
    artifact_name = "<artifact-name>"
    acceptance_criteria = @(
        "local validation PASS",
        "GitHub Action validation PASS",
        "agent catalog entry present"
    )
    forbidden_scope = @(
        "do not create unrelated agents",
        "do not modify old proofs or reports",
        "do not claim PASS without validator evidence"
    )
}

$ExampleProgramJson = [ordered]@{
    program_id = "PROGRAM_REMEDIATION_INTAKE_OPERATOR_AGENT_V1"
    agent_id = "remediation_intake_operator_agent_v1"
    agent_name = "Remediation Intake Operator Agent v1"
    purpose = "принимает описание проблемы и превращает его в структурированную карточку для оператора"
    owner_visible_goal = "Оператор получает нормализованную карточку проблемы с severity, likely_area, missing_information и recommended_next_step."
    input_contract = [ordered]@{
        type = "object"
        required = @(
            "problem_title",
            "problem_description",
            "affected_system",
            "urgency",
            "observed_evidence"
        )
        fields = [ordered]@{
            problem_title = [ordered]@{ type = "string"; min_length = 1 }
            problem_description = [ordered]@{ type = "string"; min_length = 1 }
            affected_system = [ordered]@{ type = "string"; min_length = 1 }
            urgency = [ordered]@{ type = "string"; allowed_values = @("low", "medium", "high", "critical") }
            observed_evidence = [ordered]@{ type = "array"; min_items = 1; items = "string" }
        }
    }
    output_contract = [ordered]@{
        type = "object"
        required = @(
            "normalized_problem",
            "severity",
            "likely_area",
            "missing_information",
            "recommended_next_step",
            "operator_note",
            "validation_status"
        )
        fields = [ordered]@{
            normalized_problem = [ordered]@{ type = "object" }
            severity = [ordered]@{ type = "string"; allowed_values = @("SEV-1", "SEV-2", "SEV-3", "SEV-4") }
            likely_area = [ordered]@{ type = "string" }
            missing_information = [ordered]@{ type = "array" }
            recommended_next_step = [ordered]@{ type = "string" }
            operator_note = [ordered]@{ type = "string" }
            validation_status = [ordered]@{ type = "string"; required_value = "PASS" }
        }
    }
    required_files = @(
        "generated_agents/remediation_intake_operator_agent_v1/AGENT_SPEC.json",
        "generated_agents/remediation_intake_operator_agent_v1/INPUT_EXAMPLE.json",
        "generated_agents/remediation_intake_operator_agent_v1/README.md",
        "generated_agents/remediation_intake_operator_agent_v1/RUNBOOK.md",
        "generated_agents/remediation_intake_operator_agent_v1/run.ps1"
    )
    validation_requirements = @(
        "agent package required files exist",
        "run.ps1 passes PowerShell parser check",
        "INPUT_EXAMPLE.json produces OUTPUT_EXAMPLE_RUNTIME.json",
        "runtime output contains validation_status PASS",
        "GitHub Actions workflow can run manually and upload expected artifact",
        "agent is registered in agent_catalog/AGENT_CATALOG.json"
    )
    github_action_required = $true
    github_action_name = "Run Remediation Intake Operator Agent v1"
    github_workflow = ".github/workflows/run-remediation-intake-operator-agent-v1.yml"
    artifact_name = "remediation-intake-operator-agent-v1-output"
    agent_location = "generated_agents/remediation_intake_operator_agent_v1/"
    run_script = "generated_agents/remediation_intake_operator_agent_v1/run.ps1"
    proof_paths = @(
        "proofs/EXTERNAL_AGENT_PRODUCTION_PROGRAM_TEST_V1.json",
        "proofs/AGENT_GITHUB_ACTION_LAUNCH_V1.json",
        "proofs/AGENT_CATALOG_V1.json"
    )
    report_paths = @(
        "reports/external_agent_production/EXTERNAL_AGENT_PRODUCTION_PROGRAM_TEST_V1_REPORT.json",
        "reports/external_agent_production/AGENT_GITHUB_ACTION_LAUNCH_V1_REPORT.json",
        "reports/external_agent_production/REMEDIATION_INTAKE_OPERATOR_AGENT_V1_GITHUB_ACTION_ACCEPTANCE.md",
        "reports/external_agent_production/AGENT_CATALOG_V1_REPORT.json"
    )
    acceptance_criteria = @(
        "local_validation PASS",
        "github_action_validation PASS",
        "agent catalog status ACCEPTED",
        "proof and report paths exist"
    )
    forbidden_scope = @(
        "do not create a second agent",
        "do not change generated_agents/remediation_intake_operator_agent_v1 files",
        "do not change the existing GitHub workflow",
        "do not change old proofs or reports",
        "do not claim acceptance without validator evidence"
    )
}

$Readme | Set-Content -LiteralPath (Join-Path $ProgramRoot "README.md") -Encoding UTF8
$TemplateMarkdown | Set-Content -LiteralPath (Join-Path $ProgramRoot "AGENT_PROGRAM_TEMPLATE.md") -Encoding UTF8
$ExampleProgramMarkdown | Set-Content -LiteralPath (Join-Path $ExampleProgramRoot "PROGRAM.md") -Encoding UTF8
Write-JsonFile -Path (Join-Path $ProgramRoot "AGENT_PROGRAM_SCHEMA.json") -Value $Schema
Write-JsonFile -Path (Join-Path $ProgramRoot "AGENT_PROGRAM_TEMPLATE.json") -Value $TemplateJson
Write-JsonFile -Path (Join-Path $ExampleProgramRoot "PROGRAM.json") -Value $ExampleProgramJson
Copy-Item -LiteralPath $ValidatorPayloadPath -Destination $ValidatorTargetPath -Force

& $ValidatorTargetPath -FinalizePhase -RunId $RunId -RepoRoot $RepoRoot

Invoke-NativeGitCommand -Label "ADD" -Arguments @(
    "add",
    ".\CAPABILITY_ROADMAP.json",
    ".\GENESIS_STATE.json",
    ".\TASK_QUEUE.json",
    ".\packs\registry.json",
    ".\tasks\TASK_AGENT_PROGRAM_INPUT_FORMAT_V1_001.json",
    ".\packs\PHASE70_AGENT_PROGRAM_INPUT_FORMAT_V1",
    ".\agent_programs",
    ".\validators\validate_agent_program_input_format_v1.ps1",
    ".\proofs\AGENT_PROGRAM_INPUT_FORMAT_V1.json",
    ".\reports\external_agent_production\AGENT_PROGRAM_INPUT_FORMAT_V1_REPORT.json"
)
Invoke-NativeGitCommand -Label "COMMIT" -Arguments @(
    "commit",
    "-m",
    "Add agent production program input format v1"
)
Invoke-NativeGitCommand -Label "PUSH" -Arguments @(
    "push",
    "origin",
    "main"
)

Write-Host "PACK_COMMIT_PUSH=PASS"
