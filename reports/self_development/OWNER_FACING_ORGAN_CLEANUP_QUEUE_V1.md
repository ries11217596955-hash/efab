# Owner-facing organ cleanup queue V1

STATUS: PASS_OWNER_FACING_ORGAN_CLEANUP_QUEUE_V1

This queue does not delete files, promote passports, or downclassify passports. It only converts audit findings into Owner decisions and safe next actions.

## Summary
- Total items: 5
- Owner decision required: 2
- Safe keep/proof actions: 3
- Delete candidates without deletion: 1

## Queue
### operations_contracts
- Classification: CONTRACT_MATERIAL_AGGREGATOR_NOT_ORGAN
- Current audit decision: DOWNCLASSIFY_CANDIDATE
- Owner decision needed: True
- Owner decision prompt: OWNER_APPROVE_DOWNCLASSIFY_TO_REFERENCE_OR_KEEP_AS_DRAFT
- Safe action now: mark as downclassify candidate in queue only
- Next no-delete action: create follow-up patch to set passport_kind=GOVERNANCE_MATERIAL_REFERENCE or merge under existing contracts_* passports after Owner approval
- Delete risk: do not delete: may hold useful contract material and duplicate-map evidence
- Evidence reason: validator refs are .contract.json documents, not executable validators; multiple specific contracts_* passports already exist

### operations_smoke_trials
- Classification: TEST_FIXTURE_MATERIAL_NOT_ORGAN
- Current audit decision: DOWNCLASSIFY_CANDIDATE
- Owner decision needed: True
- Owner decision prompt: OWNER_APPROVE_DELETE_CANDIDATE_OR_KEEP_AS_TEST_REFERENCE
- Safe action now: mark as delete/downclassify candidate in queue only
- Next no-delete action: classify as TEST_FIXTURE_REFERENCE; deletion only after dependency scan and Owner approval
- Delete risk: do not delete yet: fixtures may still support validators/tests
- Evidence reason: validator refs are fixture JSON files, not executable validators; root contains plan plus fixtures

### operations_active_behavior
- Classification: REAL_ORGAN_DRAFT_WITH_EXECUTABLE_VALIDATORS
- Current audit decision: KEEP_AS_ORGAN_DRAFT
- Owner decision needed: False
- Owner decision prompt: NO_DELETE_KEEP_DRAFT
- Safe action now: run existing executable validators in later proof-run packet, or leave DRAFT
- Next no-delete action: run validators and attach proof_refs if they pass; otherwise keep draft with blockers
- Delete risk: deleting would remove plausible organ surface
- Evidence reason: two executable validators exist, but passport has no proof_refs

### operations_organ_promotion_lanes
- Classification: GOVERNANCE_OR_META_ORGAN_DRAFT
- Current audit decision: KEEP_AS_GOVERNANCE_DRAFT
- Owner decision needed: False
- Owner decision prompt: NO_DELETE_KEEP_GOVERNANCE_DRAFT
- Safe action now: add second independent validator surface before promotion
- Next no-delete action: build/read-only second-surface validator that cross-checks lanes against passport index and body map
- Delete risk: deleting would break passport maturity/governance flow
- Evidence reason: has executable builder/validator/report/proof, but only one independent validator surface

### operations_overnight_school
- Classification: LONG_RUNTIME_SCHOOL_DRAFT
- Current audit decision: REPAIR_PASSPORT_LINK_KEEP_DRAFT
- Owner decision needed: False
- Owner decision prompt: NO_DELETE_KEEP_LONG_RUNTIME_DRAFT
- Safe action now: keep corrected validator link; require long-runtime boundary before promotion
- Next no-delete action: run only bounded validator/proof or create long-runtime boundary gate; no overnight/live run by default
- Delete risk: deleting could remove useful long-school process; promoting too early is also unsafe
- Evidence reason: validator path is duplicated/concatenated and does not exist; corrected path exists

## Boundaries
- No files deleted.
- No passport promoted.
- No passport downclassified.
- No PASSPORT_ACTIVE created.
- No live runtime touched.
