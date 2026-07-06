# Remediation Intake Operator Agent v1 Runbook

## When To Use

Use this agent when an operator has a raw remediation, incident, defect, or problem report and needs a normalized intake record before routing work to engineering, support, or remediation planning.

## Input

Prepare a JSON file with:

- `problem_title`: short human-readable title.
- `problem_description`: clear description of the observed problem.
- `affected_system`: service, workflow, repository, environment, or component involved.
- `urgency`: one of `low`, `medium`, `high`, or `critical`.
- `observed_evidence`: one or more evidence strings, such as logs, alerts, screenshots, run IDs, or observed timestamps.

## Run

```powershell
pwsh -File .\run.ps1 -InputPath .\INPUT_EXAMPLE.json -OutputPath .\OUTPUT_EXAMPLE_RUNTIME.json
```

On success, the script prints:

```text
REMEDIATION_INTAKE_OPERATOR_STATUS=PASS
```

## Read The Result

Open the output JSON and review:

- `normalized_problem` for the cleaned intake record.
- `severity` for the local severity estimate.
- `likely_area` for the probable routing area.
- `missing_information` for facts the operator should request.
- `recommended_next_step` for the next action.
- `operator_note` for runtime constraints and context.

## Limits

The agent does not diagnose root cause, call external services, query production systems, or create tickets. It structures intake data and provides a local routing recommendation from the supplied JSON only.
