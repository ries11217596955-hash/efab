# E-Factory Agent Builder

## Purpose

Canonical repository for the Agent Builder line.

This system has two sequential functions:

1. **SELF_BUILD**  
   Build itself from a repo-defined genesis plan through validated staged capability packs.

2. **BUILD_EXTERNAL_AGENT**  
   After self-build readiness is proven, construct other agents from formal specifications.

## Product boundary

This repository is not an extension of Site Auditor V3.  
It is a separate AGENTOPS product line that reuses proven architectural discipline:

- orchestrator-first;
- contract-first;
- module-owned logic;
- validator-gated releases;
- artifact truth;
- serial execution packs.

## Current stage

Agent Builder has already proven the baseline readiness gates recorded in repo truth:

- `SELF_BUILD_READY = PASS`
- `EXTERNAL_AGENT_BUILD_READY = PASS`
- `FIRST_EXTERNAL_AGENT_PROOF = PASS`
- GitHub Actions self-build surface exists.
- Generated external agents carry a GitHub Actions launch delivery artifact.

Current owner-facing truth:

- PHASE54 owner-visible self-build acceptance is completed.
- Task queue: `active_task_id = NONE`
- Committed proof artifact: `proofs/OWNER_VISIBLE_SELF_BUILD_ACCEPTANCE_V1.json`
- GitHub Actions owner-visible self-build acceptance is proven.

The Build From Raw Idea owner-visible GitHub Action has passed runtime acceptance in the latest owner verification run, producing a generated external agent package from the canonical raw idea fixture. This README does not claim a committed repo proof file for that second runtime unless such an artifact exists in repo truth.

The owner-visible factory loop is now proven at the interaction layer. The next product frontier is reducing external pack-authoring dependence by allowing generated self-build programs to be admitted into the live Builder execution contour.

## Source of truth

- `AGENT_MISSION.md`
- `GENESIS_MASTER_PLAN.md`
- `CAPABILITY_ROADMAP.json`
- `GENESIS_STATE.json`
- `TASK_QUEUE.json`

## Absolute rule

The agent must not transition into external-agent generation unless:

`SELF_BUILD_READY = PASS`

That gate is currently true in `GENESIS_STATE.json`; runtime proof artifacts remain the source of truth for each later acceptance claim.
