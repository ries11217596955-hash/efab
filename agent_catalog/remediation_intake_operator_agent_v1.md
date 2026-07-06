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
