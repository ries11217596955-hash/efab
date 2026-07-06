# Owner Visible Factory Acceptance Loop v1

## Purpose

This acceptance loop makes the two core Agent Builder promises visible from GitHub Actions:

1. SELF_BUILD consumes the repo-defined task queue and pack registry.
2. BUILD_FROM_RAW_IDEA turns a raw idea request into a generated external agent package.

## A. Self-Build Action

Trigger workflow: `.github/workflows/agent-builder-self-build.yml`

Inputs:

- `run_id`: optional. Leave blank to use the GitHub Actions run id. Nonblank values are sanitized automatically for path and artifact-name safety.
- `max_packs`: use `1` for this acceptance run.

Expected runtime proof:

- `proofs/OWNER_VISIBLE_SELF_BUILD_ACCEPTANCE_V1.json`

Successful proof markers:

- `proof_id = OWNER_VISIBLE_SELF_BUILD_ACCEPTANCE_V1`
- `execution_mode = SELF_BUILD`
- `source_surface = GITHUB_ACTION_COMPATIBLE`
- `selected_pack = PHASE54_OWNER_VISIBLE_SELF_BUILD_ACCEPTANCE_V1`
- `status = PASS`
- `final_state.active_task_id = NONE`

This proves that the Builder consumed a repo-defined PHASE54 pack through the self-build execution path and advanced its own roadmap, state, and queue truth after validation.

## B. Build From Raw Idea Action

Trigger workflow: `.github/workflows/agent-builder-build-from-raw-idea.yml`

Default inputs:

- `raw_idea_path`: `specs/factory_acceptance/raw_ideas/OWNER_VISIBLE_EXTERNAL_AGENT_IDEA.json`
- `output_root`: `generated_agents/owner_visible_factory_acceptance`

Leaving `raw_idea_path` or `output_root` blank uses the canonical defaults. Entering literal `default` is also normalized to the same defaults for owner safety. The `run_id` field is sanitized automatically for path and artifact-name safety.

Expected generated artifacts:

- `runs/<run_id>/BUILD_FROM_RAW_IDEA_MODE_V1/BUILD_FROM_RAW_IDEA_REPORT.json`
- `runs/<run_id>/BUILD_FROM_RAW_IDEA_MODE_V1/DERIVED_AGENT_SPEC.json`
- `generated_agents/owner_visible_factory_acceptance/<derived_agent_id>/AGENT_PROFILE.json`
- `generated_agents/owner_visible_factory_acceptance/<derived_agent_id>/orchestrator/run.ps1`
- `generated_agents/owner_visible_factory_acceptance/<derived_agent_id>/validators/validate_package.ps1`
- `generated_agents/owner_visible_factory_acceptance/<derived_agent_id>/deployment/github_actions/run-generated-agent.workflow.yml`

The workflow uploads both the run directory and the generated agent output root as artifacts.

## C. Meaning and Limits

These proofs mean:

- the self-build Action can consume a repo-defined plan item and leave state truth updated by validator-backed execution;
- the raw-idea Action can launch the existing Agent Spec Architect handoff and package generator path;
- the generated external agent package includes its own runtime, validator, sample request, and GitHub Actions launch delivery artifact.

These proofs do not mean:

- every possible raw idea will classify or build successfully;
- the generated agent has domain-specialized reasoning beyond the current factory contour;
- production deployment, hosting, credentials, or external integrations are configured;
- chat text replaces `GENESIS_STATE.json`, `CAPABILITY_ROADMAP.json`, `TASK_QUEUE.json`, or runtime proof artifacts as source of truth.
