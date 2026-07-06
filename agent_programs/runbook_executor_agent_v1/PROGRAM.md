# Runbook Executor Agent v1 Production Program

## Зачем он нужен

`runbook_executor_agent_v1` нужен, чтобы оператор мог подать runbook, описание задачи или инцидента и получить практический план выполнения без ручного переписывания инструкции.

## Что принимает

Агент принимает JSON с полями:

- `runbook_title`
- `runbook_steps`
- `task_or_incident`
- `environment`
- `constraints`

`runbook_steps` содержит шаги инструкции. `task_or_incident` описывает конкретную ситуацию, к которой нужно применить runbook. `environment` фиксирует среду выполнения, а `constraints` задаёт ограничения и границы действий.

## Что выдаёт

Агент должен выдать:

- `execution_checklist`
- `risk_flags`
- `required_evidence`
- `next_operator_action`
- `validation_status`

Успешный результат должен содержать `validation_status = PASS`.

## Ожидаемый пакет агента

Пакет будущего агента должен содержать:

- `README.md`
- `AGENT_SPEC.json`
- `RUNBOOK.md`
- `INPUT_EXAMPLE.json`
- `OUTPUT_EXAMPLE.json`
- `run.ps1`
- `proofs/README.md`

## GitHub Actions

GitHub Action обязателен.

Название workflow:

```text
Run Runbook Executor Agent v1
```

Ожидаемый artifact:

```text
runbook-executor-agent-v1-output
```

## Критерии принятия

- Builder creates standalone agent package
- local runtime validation PASS
- GitHub Actions workflow exists
- GitHub Actions run produces artifact
- agent registered in catalog

## Запрещённый scope

- do not modify existing remediation intake agent
- do not modify existing GitHub workflow
- do not modify orchestrator/run.ps1

## Статус

Это seed-программа для проверки схемы `program -> Builder reads program -> Builder creates execution plan`. Она не создаёт самого агента.
