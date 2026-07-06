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
