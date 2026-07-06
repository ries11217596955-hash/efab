# Branch-agnostic map refresh contract

Status: ACTIVE_LOCAL_CONTRACT

Purpose: prevent map refresh from depending on one historical branch name or remote push-only workflow.

Rule:
- Do not hardcode branch names such as `thin-control` or `phase110-idempotent-autonomy-trial-runtime` inside the refresh decision.
- Read current branch from git at runtime.
- Read subject head from git at runtime.
- If the subject change touches structural code/organ paths, rebuild the derived self/body map.
- If it does not touch structural paths, write an explicit `MAP_REFRESH_SKIPPED` result with the changed paths and reason.

Canonical local output:
- `reports/self_development/SELF_MODEL_ACTIVE_MAP.json`
- `reports/self_development/agent_body_map.json`
- `reports/self_development/agent_body_map.md`
- `reports/self_development/branch_agnostic_map_refresh_result.json`

Boundary:
- No protected state mutation by default.
- No runtime session staging.
- No live SandboxTestLife stop action.
- No deletion of older map systems until a separate cleanup decision.

Acceptance:
- New organ/logic/module commits must either be visible in the derived map or produce `MAP_REFRESH_SKIPPED` with a reason.

## 2026-07-06 update - composition map boundary

Canonical composition/status map:
- `reports/self_development/SELF_MODEL_ACTIVE_MAP.json`
- schema: `AGENT_BODY_COMPOSITION_MAP_V1`

Derived human/compatibility views:
- `reports/self_development/agent_body_map.md`
- `reports/self_development/agent_body_map.json`

Refresh proof:
- `reports/self_development/branch_agnostic_map_refresh_result.json`

This map answers: what body parts exist, where they are, basic counts, required files, latest git/runtime signal.
It does not answer: how to invoke capabilities. Capability invocation belongs to a separate capability map.

Freshness rule:
- current composition map head must match `git rev-parse HEAD` before it is trusted for route decisions.
- structural/body changes must refresh the map or produce an explicit skip proof.
- stale map validation must fail, not pass with old head.

Duplicate rule:
- `self_knowledge/BUILDER_SELF_MODEL.json`, `self_knowledge/ROADMAP_STATE.json`, `CAPABILITY_ROADMAP.json`, and `GENESIS_STATE.json` are not the current body composition map.
- They may remain as legacy/reference/state surfaces, but they must not be treated as the canonical composition/status map.
## Fingerprint rule

The composition map freshness key is body_source_fingerprint. It must include structural body sources only. Generated map files, reports, runtime runs, proof outputs, and map validation JSON are excluded to avoid self-referential freshness loops.

## Validation proof location

Fresh validator proof is runtime evidence and is written under .runtime/map_control/validations/. Validation JSON must not be tracked, because every validation run updates timestamp/head and would dirty the repo.
