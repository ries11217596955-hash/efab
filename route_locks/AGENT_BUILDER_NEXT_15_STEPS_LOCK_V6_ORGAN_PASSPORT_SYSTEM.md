# AGENT_BUILDER_NEXT_15_STEPS_LOCK_V6_ORGAN_PASSPORT_SYSTEM

status: ACTIVE_ROUTE_LOCK
version: V6_ORGAN_PASSPORT_SYSTEM
active_line: AGENT_BUILDER / SELF_BUILD / ORGAN_PASSPORT_SYSTEM / REPEATABLE_DRAFT_PIPELINE
created_reason: Owner confirmed the next pass should combine route reality alignment and auto-map-refresh proof without over-fragmenting the work. The previous completed pass made the fast-lane passport draft generator repeatable and processed operations_organ_promotion_lanes.
supersedes_for_route: route_locks/AGENT_BUILDER_NEXT_15_STEPS_LOCK_V4_IDENTITY_BASED_SELECTION.md
current_repo_baseline: 4b1d260
proof_boundary: ROUTE_POINTER_ALIGNMENT_ONLY / PASSPORT_SYSTEM_ROUTE_ACTIVE. No PASSPORT_ACTIVE, PROVEN_LIVE, live runtime mutation, child-agent readiness, or lifecycle-contract activation is claimed by this file.

## Current proven baseline

- Passport Draft Generator has a repeatable build command: operations/self_model/build_organ_passport_draft_generator_fast_lane_v1.ps1.
- operations_organ_promotion_lanes has a draft passport.
- Passport generator validator, review/index gate, promotion lanes validator, map refresh, and composition map validator passed in the previous pass.
- Repo commit 4b1d260 was pushed to main.

## Active route goal

Make the organ passport system a normal repeatable Builder self-build capability:

1. Keep generating draft passports only for candidates whose lane allows draft passport creation.
2. Keep review/index gate scan-based, not static-count based.
3. Keep ACTIVE and PROVEN_LIVE claims blocked until separate runtime proof and owner route acceptance.
4. Keep promotion lanes as routing/gating evidence, not organ activation.
5. Keep canonical body map refreshed/validated after structural changes.
6. Record each pass in GPT Operator Journal for migration continuity.

## Current blockers / boundaries

- Lifecycle-contract V5 work exists only as preserved stash material and is not active route in this lock.
- Live runtime was not touched.
- Full organ maturity is not claimed.
- Auto-map refresh is proven for local git pre-commit via core.hooksPath=.githooks, not via .git/hooks.

## Next few steps

1. ROUTE_REALITY_ALIGNMENT_V1
   - Point ACTIVE_ROUTE_LOCK.json to this V6 passport-system route.
   - Preserve the lifecycle-contract stash as backlog material, not current route.
   - Validate active route pointer and hook reality.

2. PASSPORT_REPEATABILITY_SECOND_SAMPLE_V1
   - Select the next FAST_LANE_PASSPORT_DRAFT candidate from ORGAN_PROMOTION_LANES_V1.
   - Run the repeatable generator.
   - Validate generator, review/index gate, promotion lanes, map refresh, and map currentness.

3. PASSPORT_STATIC_COUNT_REGRESSION_GUARD_V1
   - Add or strengthen a guard against hard-coded two-passport generator/index validators.
   - Prove the passport pipeline remains scan-based / target-presence based.

4. LIFECYCLE_CONTRACT_STASH_DECISION_V1
   - Inspect preserved stash read-only.
   - Decide whether it becomes a future route, separate branch, or archive/backlog material.
   - Do not apply it into the passport route without owner decision.

## Must not do in this route

- Do not create a new architecture organ.
- Do not reactivate Cortex terminology.
- Do not claim PASSPORT_ACTIVE.
- Do not claim PROVEN_LIVE.
- Do not apply lifecycle-contract stash into this commit.
- Do not mutate live runtime.
