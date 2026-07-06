# Evidence Packager Agent v1 Runbook

## Purpose

Use this agent when an operator needs a compact evidence package for a task, incident, acceptance review, or failure investigation.

## Required Input

- `task_id`
- `task_summary`
- `evidence_items`

## Operator Flow

1. Prepare an input JSON file with the task and evidence items.
2. Run `run.ps1` with `-InputPath` and `-OutputPath`.
3. Review `missing_evidence` and `risk_flags`.
4. Follow `next_operator_action`.

## Acceptance

The output is acceptable when `validation_status` is `PASS` and the JSON is readable by downstream validators.
