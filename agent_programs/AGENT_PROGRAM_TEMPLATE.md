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
