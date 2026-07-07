# AGENT_BUILDER_NEXT_15_STEPS_LOCK_V4_IDENTITY_BASED_SELECTION

status: ACTIVE_ROUTE_LOCK
version: V4
active_line: AGENT_BUILDER / SELF_BUILD / IDENTITY_BASED_PATH_SELECTION
created_reason: Owner corrected the route: AIMO must not choose the next step by the latest source packet, School output, AgentLife residue, or any single external/internal source. AIMO must choose by Builder identity, current body/capability/gap/proof map, mission priority, and source evidence.
supersedes_for_route: route_locks/AGENT_BUILDER_NEXT_15_STEPS_LOCK_V3_PHASE161_BATCH_SCHOOL_PREP.md
previous_live_baseline_commit: 7a2e798
previous_live_baseline_proof: tests/live_start/AIMO_CONCRETE_GROWTH_TASK_SELECTION_LIVE_V1_PROOF.json
previous_live_boundary: Proven live only that AIMO escaped meta/residue to a concrete fresh-school-memory task. Not proven: source-agnostic selection, Builder identity scoring, or provenance carry-over.

## End Goal After This 10-15 Step Slice

After this slice, AIMO must have a proven source-agnostic Builder path selector:

- It knows it is Agent Builder, not a chatbot, School follower, AgentLife follower, or latest-signal follower.
- It chooses next work from Builder mission, body map, capability map, gap map, proof map, and memory/signals as evidence.
- It treats School, AgentLife, episodic memory, active memory delta, validators, reports, and Owner directives as candidate sources, not as the brain.
- It can ignore the latest signal when it does not close the highest-value Builder gap.
- It can continue when School is missing, stale, failed, or irrelevant.
- It emits a selected next action with identity alignment, gap closed, proof_needed, validator_needed, source_refs_used, source_refs_rejected, and why_not_latest_signal.
- It has lab validators and at least one controlled live proof showing AIMO selects by Builder identity/gap logic rather than latest source.

Review gate after this slice: stop, summarize proofs/failures, and ask Owner whether to continue with child-agent factory readiness, deeper self-model, or runtime autonomy hardening.

## Doctrine

AIMO next-step selection must follow this order:

1. Builder identity and mission.
2. Current self/body/capability map.
3. Known gaps and maturity blockers.
4. Proof/validator availability.
5. Memory and episodic lessons.
6. Current source signals as evidence.
7. Safety, rollback, and live/lab boundary.

Latest signal is never enough.
School is never required as a brain.
AgentLife residue is never enough.
A source without proof can suggest, not command.
No proof, no claim.
No validator, no maturity.

## Primary Mission

Build, repair, verify, and improve self as an independent action machine.

## Secondary Mission

Learn to build child agents only after self-build selection, proof discipline, and source-agnostic planning are mature enough.

## Source Roles

- Owner directive: strong route signal, still must become bounded task/proof plan.
- Builder self-map/body map: primary internal source.
- Capability map: primary internal source.
- Gap map: primary internal source.
- Validator failures/reports: high-value proof source.
- Episodic memory: lesson source, not proof by itself.
- Active compact memory delta: material source, not brain.
- School packet: optional material source, not required.
- AgentLife packet: self-observation source, often residue; must be filtered.
- Latest source packet: freshness modifier only.

## Locked Next 15 Steps

1. PHASE_A - Route V4 activation and old-school-specific route boundary
   Goal: make this file the active route for the next slice; explicitly mark the current School-specific live proof as useful but too narrow.
   Proof: route lock file committed and synced.

2. PHASE_B - Builder identity contract V1
   Goal: create a compact machine-readable identity contract for AIMO: self-build first, child-agent factory second, no latest-signal following, no School dependency.
   Validator: rejects contracts that define Builder as chatbot, tool wrapper, School follower, or latest-signal follower.

3. PHASE_C - Current body/capability snapshot reader V1
   Goal: produce a bounded snapshot of current organs, helpers, validators, live/lab proofs, and known capabilities.
   Validator: snapshot distinguishes built vs wired vs live-proven.

4. PHASE_D - Builder gap map V1
   Goal: generate a gap map from current body/capability/proof state: missing organs, weak validators, false-proof risks, source dependency risks, child-agent blockers.
   Validator: gap map includes severity, mission relevance, proof need, and validator need.

5. PHASE_E - Source evidence inventory V1
   Goal: inventory candidate sources without giving any source authority: Owner route, validators, reports, episodic recall, active memory delta, School, AgentLife, runtime proof.
   Validator: School missing/stale/failed case does not block inventory.

6. PHASE_F - Candidate action generator V1
   Goal: generate bounded next-step candidates from identity + gap map + evidence sources.
   Validator: generates at least one self-build candidate even when all external/current source packets are missing.

7. PHASE_G - Builder mission scoring V1
   Goal: score candidates by self_build_leverage, child_agent_future_value, closes_known_gap, proof_path, validator_path, dependency_reduction, source_confidence, live_risk, false_proof_risk, overfitting_to_latest_signal.
   Validator: latest signal loses when it is fresh but low mission relevance.

8. PHASE_H - Source-agnostic path selection V1
   Goal: select one next action from scored candidates and emit identity_alignment, selected_gap, proof_needed, validator_needed, source_refs_used, source_refs_rejected, why_not_latest_signal.
   Validator: handles School available, School missing, AgentLife residue, validator failure, and Owner directive cases.

9. PHASE_I - AIMO integration behind lab gate
   Goal: wire source-agnostic selector into AIMO task selection in lab only.
   Validator: existing growth-directed selector regressions still pass; no live process touched.

10. PHASE_J - Negative tests for source dependency
    Goal: prove AIMO selection does not require School, AgentLife, or any single current packet.
    Validator: missing/stale/failed School and stale AgentLife still produce bounded self-build fallback.

11. PHASE_K - Provenance and rejection trace V1
    Goal: selected next action carries source_refs_used, source_refs_rejected, and why latest/rejected source was not chosen.
    Validator: rejection reasons are explicit and not empty.

12. PHASE_L - Controlled live hotswap V1
    Goal: restart AIMO only after lab pass and prove live AIMO selects by identity/gap logic, not latest signal.
    Proof: controlled AIMO-only hotswap, School observed but not required, no duplicate runtime, stderr 0, live proof JSON.

13. PHASE_M - Route execution report V1
    Goal: write a report comparing planned steps vs completed steps, proof refs, failures, and remaining gaps.
    Validator: report cannot claim child-agent readiness unless proven.

14. PHASE_N - Owner review gate
    Goal: stop after this slice and return to Owner with proof summary and decision options.
    Output: continue self-model, child-agent factory readiness, runtime autonomy hardening, or memory/provenance hardening.

15. PHASE_O - Next small route lock draft only after Owner decision
    Goal: do not silently continue beyond this plan. Draft the next 10-15 step lock only after Owner review.
    Boundary: no background continuation and no automatic child-agent jump.

## Hard Prohibitions For This Slice

- Do not make School the brain.
- Do not require School for AIMO to choose a next step.
- Do not follow latest packet by default.
- Do not promote AgentLife residue to Builder direction.
- Do not claim child-agent readiness in this slice.
- Do not accept memory recall as proof.
- Do not hotswap live before lab validators pass.
- Do not mutate live School during AIMO selector work.
- Do not erase old route locks; classify/supersede instead.
- Do not continue past step 15 without Owner review.

## Acceptance Criteria For The Whole Slice

- A route lock exists and is committed.
- AIMO has identity-based, source-agnostic next-step selection in lab.
- AIMO live proof shows selection by Builder identity/gap logic.
- School missing/stale/failed is validated as non-blocking.
- Latest signal overfitting is validated as rejected.
- Final route execution report is written.
- Owner review happens before a new plan.

## Current Known Gaps Entering This Slice

- Current live active task is concrete but still too source-shaped: select_one_fresh_school_memory_delta_and_convert_to_bounded_builder_task.
- Source-agnostic selector is not implemented.
- Identity scoring is not implemented.
- Provenance/rejection trace is incomplete.
- Child-agent factory remains future work, not current acceptance target.

## Current Proof Boundary Entering This Slice

PROVEN_LIVE: AIMO escaped meta/residue to a concrete fresh-school-memory task.
NOT_PROVEN: AIMO can choose by Builder identity and gap map.
NOT_PROVEN: School-independent source-agnostic selection.
NOT_PROVEN: child-agent factory readiness.
