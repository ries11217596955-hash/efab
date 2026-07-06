# Runbook Executor Agent v1

## Статус

GITHUB_ACTION_READY_PENDING_RUN.

## Что это за агент

Runbook Executor Agent v1 принимает инструкцию или регламент и описание задачи/инцидента. На выходе он создаёт операторский план действий.

## Что принимает

- runbook_title
- runbook_steps
- task_or_incident
- environment
- constraints

## Что выдаёт

- execution_checklist
- risk_flags
- required_evidence
- next_operator_action
- validation_status

## Где лежит

generated_agents/runbook_executor_agent_v1/

## Локальный запуск

pwsh -NoProfile -ExecutionPolicy Bypass -File generated_agents/runbook_executor_agent_v1/run.ps1 -InputPath generated_agents/runbook_executor_agent_v1/INPUT_EXAMPLE.json -OutputPath generated_agents/runbook_executor_agent_v1/OUTPUT_EXAMPLE_RUNTIME.json

## GitHub Actions запуск

Workflow:

Run Runbook Executor Agent v1

Workflow file:

.github/workflows/run-runbook-executor-agent-v1.yml

Artifact:

runbook-executor-agent-v1-output

## Текущий следующий шаг

Владелец должен открыть GitHub Actions, запустить workflow и проверить, что GitHub создаёт artifact.
