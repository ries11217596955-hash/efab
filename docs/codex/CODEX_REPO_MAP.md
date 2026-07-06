# Codex Repository Map

Generated UTC: 2026-06-11T08:25:08.6188651Z

## Current Git State

- Branch: `phase110-idempotent-autonomy-trial-runtime`
- Generated from HEAD: `26db309ea883e65e9c90dfc66e8c43fb347f9ae4`
- Origin ref: `origin/phase110-idempotent-autonomy-trial-runtime`
- Generated from origin: `26db309ea883e65e9c90dfc66e8c43fb347f9ae4`
- Generated HEAD equals origin: `true`
- Generator worktree status: `DIRTY`
- Last orientation refresh commit: `5a6bed5650fcff59b7deb0a86b2a1b2675b2ec78`
- Active route lock: `route_locks/AGENT_BUILDER_NEXT_15_STEPS_LOCK_V2.md`

## Freshness Semantics

The orientation model is `generated_from_repo_state_not_self_referential`. It is fresh when generated from current HEAD, or when generated from the parent of the latest commit and that latest commit is an accepted Codex orientation refresh or repair.

Manual refresh is required when:
- active route changes
- protected state changes
- registry/roadmap/self-model changes
- proof index changes
- before starting a major Codex task

## Read First

- `AGENTS.md`
- `docs/codex/CODEX_CURRENT_STATE_THIN.json`
- `docs/codex/CODEX_REPO_MAP.md`
- `docs/codex/CODEX_EVIDENCE_INDEX.md`
- `README.md`
- `route_locks/AGENT_BUILDER_NEXT_15_STEPS_LOCK_V2.md`
- `CAPABILITY_ROADMAP.json`
- `GENESIS_STATE.json`
- `TASK_QUEUE.json`
- `packs/registry.json`
- `orchestrator/run.ps1`

## Do Not Read By Default

These zones require an active task, Owner instruction, route requirement, or exact validator reference.
- `reports/**`
- `proofs/**`
- `self_build_programs/**/canonical_trials/**`
- `self_build_programs/**/dry_runs/**`
- `self_build_programs/**/promotions/**`
- `runtime_sessions/**`
- `zz_MUSORKA_DO_NOT_READ_BY_CODEX/**`

## Protected Files

Do not mutate these files for Codex orientation refresh work.
- `TASK_QUEUE.json`
- `GENESIS_STATE.json`
- `CAPABILITY_ROADMAP.json`
- `packs/registry.json`
- `route_locks/AGENT_BUILDER_NEXT_15_STEPS_LOCK_V2.md`
- `orchestrator/run.ps1`

## Typical Task Inspection

- Orientation or planning: read the thin state, this map, the evidence index, AGENTS.md, and the active route lock.
- Module implementation: inspect only the named module and its directly related contracts or callers.
- Validation work: inspect only the named validator, generated outputs, and exact evidence paths.
- State or queue work: inspect the protected state files only when the task explicitly authorizes mutation.
- Runtime work: inspect `orchestrator/run.ps1` and only the modules reached by the requested mode or phase.

## Exact-Path Evidence Rule

Do not read `reports/**` or `proofs/**` recursively. Read only an exact proof or report path named by the route lock, proof chain, Owner, task, or validator.

