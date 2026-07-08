# CODEX TASK: REBUILD BODY MAP FROM PRIMARY EVIDENCE V1

STATUS: READY_FOR_CODEX_PREFLIGHT

## Goal

Build a clean replacement for the current body-map generator so the canonical auto-refreshed map is built from primary repo/proof evidence, not from old/duplicate maps.

The current `SELF_MODEL_ACTIVE_MAP.json` must remain the single canonical output, but its generator must be redesigned to avoid using legacy maps as authority.

## Hard context budget

Read only these files before PREFLIGHT_PASS:

```text
AGENTS.md
codex_tasks/CODEX_TASK_REBUILD_BODY_MAP_PRIMARY_EVIDENCE_V1.md
modules/invoke_branch_agnostic_map_refresh_after_structural_change_001.ps1
validators/validate_agent_body_composition_map_current_v1.ps1
reports/self_development/MAP_AUTHORITY_DUPLICATE_AUDIT_V1.json
reports/self_development/EXPANDED_ORGAN_CANDIDATE_INVENTORY_AUDIT_V1.json
reports/self_development/MAP_AUTHORITY_REPAIR_V1.json
tests/self_development/MAP_AUTHORITY_REPAIR_V1_PROOF.json
self_model/ORGAN_PASSPORT_V1_CONTRACT.json
self_model/CAPABILITY_INVOCATION_MAP_V1_CONTRACT.json
```

Allowed bounded discovery after PREFLIGHT_PASS only:

```text
git ls-files operations modules validators self_model contracts living_learning_environment self_build_programs packs docs/operations reports/self_development tests/self_development
```

Forbidden:

```text
Do not read whole repo.
Do not use Get-ChildItem -Recurse from repo root.
Do not read `.runtime/**`.
Do not read `self_knowledge/BUILDER_SELF_MODEL.json`.
Do not read `reports/self_development/CURRENT_BODY_CAPABILITY_SNAPSHOT_V1.json` as authority.
Do not ingest all reports/tests/docs.
Do not delete files in this task.
```

If a broader read is needed, stop with `BLOCKED_PREFLIGHT` and request exact files.

## Required architecture

Create/modify generator behavior so canonical map has separated sections:

```text
confirmed_components
primary_evidence_candidates
legacy_unverified_hints
rejected_or_stale_hints
component_authority_summary
```

Rules:

```text
confirmed_components = only existing primary evidence surfaces with validators/proofs/contracts or explicit required components.
primary_evidence_candidates = repo-discovered candidates from bounded tracked-file discovery, with path, evidence counts, validator/proof refs if found, needs_triage=true.
legacy_unverified_hints = references to old maps or prior snapshots only as hints; they must not create confirmed components.
rejected_or_stale_hints = hints that lack primary evidence or conflict with current repo evidence.
```

Current old maps must not be authority:

```text
self_knowledge/BUILDER_SELF_MODEL.json = legacy hint/reference only; do not read it in this task.
reports/self_development/CURRENT_BODY_CAPABILITY_SNAPSHOT_V1.json = legacy snapshot hint/reference only; do not read it in this task.
```

## In scope

```text
1. Refactor `modules/invoke_branch_agnostic_map_refresh_after_structural_change_001.ps1` so it builds map from primary evidence and bounded tracked-file discovery.
2. Update `validators/validate_agent_body_composition_map_current_v1.ps1` if needed so it validates the new separated sections.
3. Add a dedicated validator: `operations/self_model/validate_body_map_primary_evidence_rebuild_v1.ps1`.
4. Add report/proof:
   - `reports/self_development/BODY_MAP_PRIMARY_EVIDENCE_REBUILD_V1.json`
   - `docs/operations/BODY_MAP_PRIMARY_EVIDENCE_REBUILD_V1.md`
   - `tests/self_development/BODY_MAP_PRIMARY_EVIDENCE_REBUILD_V1_PROOF.json`
5. Run map refresh and validators.
```

## Out of scope

```text
No deletion of old maps.
No passport generator.
No capability map generator.
No live AIMO hotswap/restart.
No child-agent readiness claim.
No `.runtime` mutation except existing map validation output if current validator already writes it.
No broad repo cleanup.
```

## Acceptance requirements

Validator must prove:

```text
canonical map exists and parses
canonical map is produced by auto-refresh generator
confirmed_components count >= 7
primary_evidence_candidates count > 0
legacy_unverified_hints exists
legacy maps are not raw authority
old maps are not read as authority
passport_generator_blocked_until_candidate_triage=true
child_agent_factory_readiness=NOT_PROVEN
current required components still present:
  school
  school_source_router
  compact_memory_intake
  autonomous_inner_motor
  knowledge_acquisition_port
  map_control
  gpt_handoff
live process count remains 1 if inspected
files changed before PREFLIGHT_PASS = NO
```

## Required final report

```text
CODEX_DELIVERY_REPORT
STATUS:
PREFLIGHT_DECISION:
Files changed before PREFLIGHT_PASS: YES/NO
FILES_READ:
FILES_CHANGED:
VALIDATION_RUNS:
PROOF_FILES:
CANONICAL_MAP_COUNTS:
LEGACY_MAP_AUTHORITY_STATUS:
BLOCKERS:
COMMIT_HASH_IF_COMMITTED:
```
