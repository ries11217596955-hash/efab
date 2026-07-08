# AIMO_DEFAULT_SOURCE_AGNOSTIC_SELECTION_V1_ROUTE_LOCK

status: ACTIVE_ROUTE_LOCK
created_from: AGENT_BUILDER_ROUTE_V4_EXECUTION_REPORT_PHASE_M
active_line: AGENT_BUILDER / RUNTIME_AUTONOMY_HARDENING / DEFAULT_SOURCE_AGNOSTIC_AIMO_SELECTION

## Owner decision

Owner selected the next sequence:

1. Runtime autonomy hardening.
2. Deeper self-model.
3. Memory/provenance hardening.
4. Child-agent factory deferred.

This route covers only step 1. Steps 2 and 3 require separate later route locks. Child-agent factory remains out of scope.

## Starting proof boundary

PROVEN_LAB:
- Builder identity/gap/source evidence/candidate/scoring/source-agnostic selection chain exists.
- AIMO can use source-agnostic selection behind explicit lab gate.
- Negative cases prove School/AgentLife/latest packet are not required.
- Provenance/rejection trace is non-empty and carries fallback.

PROVEN_LIVE:
- Controlled live hotswap replaced old AIMO with exactly one gated source-agnostic AIMO.
- Live selected `build_source_agnostic_path_selector_v1` for `source_agnostic_path_selector_missing`.
- School was not alive and was not required.

NOT_PROVEN:
- Ungated/default live AIMO path uses source-agnostic selector.
- Explicit gate can be removed or demoted safely.
- Child-agent factory readiness.

## Current health audit summary

- Repo is clean/synced at route creation.
- Tracked repo is not bloated; tracked files are about 10.72 MB and git objects about 4.77 MiB.
- `.runtime` is large, about 4.57 GB, mainly School 1,000,000 run checkpoints.
- Latest School 1,000,000 run is `PASS_REAL_FACTORY_DIGEST_RECALL_USE_V1`, 1,000,000 ready atoms, 200 chunks.
- School process is not alive now. Evidence indicates completed run, not crash.
- School `runtime_ready=False` remains a boundary and should not be misread as failure of source-agnostic AIMO.

## Goal

Make source-agnostic identity/gap/scoring selection the normal AIMO default path, not an explicit lab/live gate.

## Success criteria

- Default AIMO selection path uses Builder identity + gap + mission scoring + trace.
- Legacy/static/School-shaped selector is demoted to bounded fallback, not default authority.
- Lab proof shows default path chooses source-agnostic selection without `-UseSourceAgnosticPathSelectionLabGate`.
- Negative lab tests show default path works when School is missing/stale/failed and latest signal is residue.
- Controlled live hotswap proves live AIMO runs without explicit source-agnostic gate and still selects source-agnostic task.
- Exactly one live AIMO remains after hotswap.
- stderr=0.
- Report and Owner review gate are written before moving to deeper self-model.

## Locked steps

1. PHASE_A - Route activation and health audit commit
   - Write route lock and health audit.
   - Do not touch live.

2. PHASE_B - Default selector contract V1
   - Define contract for default source-agnostic AIMO selection.
   - Require fallback boundary for legacy selector.

3. PHASE_C - AIMO default path lab implementation
   - Wire source-agnostic path as default in lab mode.
   - Keep explicit gate temporarily for compatibility but not required for default proof.

4. PHASE_D - Legacy selector demotion validator
   - Prove old School/latest/growth-signal path cannot override identity/gap selector.
   - Legacy path may suggest fallback only.

5. PHASE_E - Default no-gate lab proof
   - Run AIMO SandboxTestLife without source-agnostic gate.
   - Prove selected task is source-agnostic and trace is complete.

6. PHASE_F - Default negative source dependency tests
   - School missing/stale/failed.
   - AgentLife residue fresh/stale.
   - latest packet low-value.
   - optional memories missing.

7. PHASE_G - Runtime health and repo hygiene guard
   - Validate repo not bloated by tracked runtime artifacts.
   - Validate `.runtime` large directories are reported but not committed.
   - No cleanup deletion without separate owner authority unless route explicitly approves quarantine.

8. PHASE_H - Controlled live hotswap without explicit source-agnostic gate
   - Stop current gated live AIMO with checkpoint.
   - Start default live AIMO without `-UseSourceAgnosticPathSelectionLabGate`.
   - Prove one live PID, source-agnostic selection, stderr=0.

9. PHASE_I - Explicit gate demotion report
   - Keep gate as emergency/debug switch or mark deprecated; do not silently delete without proof.

10. PHASE_J - Route execution report
    - Summarize proofs, failures, boundaries, remaining gaps.

11. PHASE_K - Owner review gate
    - Stop and ask Owner whether to proceed to deeper self-model route.

12. PHASE_L - Next route draft only after Owner decision
    - No automatic child-agent jump.

## Hard prohibitions

- Do not claim child-agent readiness.
- Do not make School required for selection.
- Do not delete `.runtime` checkpoint mass without explicit cleanup authority.
- Do not leave duplicate live AIMO processes.
- Do not hotswap live before lab no-gate proof passes.
- Do not treat `runtime_ready=False` as School crash without proof.
- Do not continue into deeper self-model until this route reports and Owner reviews.
