# Agent Production Closed Loop Contract v1

## Purpose

This contract defines the required closed loop for producing an external agent as an inspectable factory asset and accepting it only after Builder-controlled evidence exists.

The created agent does not accept itself. Builder owns acceptance because Builder owns queue state, proof generation, catalog state, GitHub run observation, and final PASS or FAIL reporting.

## Required Stages

1. PROGRAM_ADMISSION
2. AGENT_PACKAGE_BUILD
3. LOCAL_RUNTIME_VALIDATION
4. AGENT_CATALOG_REGISTRATION
5. GITHUB_WORKFLOW_LAUNCH
6. GITHUB_RUN_DISPATCH
7. ARTIFACT_DOWNLOAD
8. ARTIFACT_VALIDATION
9. ACCEPTANCE_PROOF_REPORT
10. CLEAN_QUEUE_RETURN

## Stage Requirements

### PROGRAM_ADMISSION

Builder must accept a formal agent production program before any package is created.

### AGENT_PACKAGE_BUILD

Builder must materialize the generated agent as files that can be inspected and versioned.

### LOCAL_RUNTIME_VALIDATION

Builder must run local validation before a generated agent can move toward GitHub acceptance.

### AGENT_CATALOG_REGISTRATION

Builder must register the agent in the catalog with a non-final state until hosted acceptance is proven.

### GITHUB_WORKFLOW_LAUNCH

Builder must provide or verify a GitHub Actions workflow that can run the generated agent.

### GITHUB_RUN_DISPATCH

Builder must dispatch the workflow and identify the run created by that dispatch.

### ARTIFACT_DOWNLOAD

Builder must download the workflow artifact emitted by the agent run.

### ARTIFACT_VALIDATION

Builder must validate the downloaded artifact against the expected output and spec contract.

### ACCEPTANCE_PROOF_REPORT

Builder must write proof and report artifacts that show the accepted agent, GitHub run, artifact validation, and catalog result.

### CLEAN_QUEUE_RETURN

Builder must return `TASK_QUEUE.active_task_id` to `NONE` only after acceptance evidence exists.

## Final Acceptance Rule

An agent is truly accepted only when:

- final agent status is `ACCEPTED`;
- GitHub run conclusion is `success`;
- artifact validation is `PASS`;
- proof and report are written;
- Builder queue returns to `NONE`.
