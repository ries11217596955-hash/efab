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
