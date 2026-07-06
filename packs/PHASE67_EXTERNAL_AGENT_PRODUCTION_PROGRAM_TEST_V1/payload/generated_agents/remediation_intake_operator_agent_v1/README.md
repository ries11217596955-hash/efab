# Remediation Intake Operator Agent v1

Remediation Intake Operator Agent v1 turns a raw remediation or problem report into a consistent intake record. It is a standalone external operator agent package and does not depend on the Agent Builder internals at runtime.

## Inputs

The agent reads a JSON object with these required fields:

- `problem_title`
- `problem_description`
- `affected_system`
- `urgency`
- `observed_evidence`

`urgency` must be one of `low`, `medium`, `high`, or `critical`. `observed_evidence` should contain one or more evidence strings.

## Outputs

The agent writes a structured JSON object containing:

- `normalized_problem`
- `severity`
- `likely_area`
- `missing_information`
- `recommended_next_step`
- `operator_note`
- `validation_status`

`validation_status` is `PASS` only after the input has been parsed, required fields have been checked, and output has been written.

## Run

From this folder:

```powershell
pwsh -File .\run.ps1 -InputPath .\INPUT_EXAMPLE.json -OutputPath .\OUTPUT_EXAMPLE_RUNTIME.json
```

The script uses only local PowerShell and JSON processing. It does not call external APIs.
