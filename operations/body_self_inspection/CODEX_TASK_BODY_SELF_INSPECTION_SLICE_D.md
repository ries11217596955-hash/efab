# CODEX_TASK_BODY_SELF_INSPECTION_SLICE_D

Status: READY_FOR_CODEX / NOT_RUN
Task type: bounded implementation slice
Target organ/circuit: BODY_SELF_INSPECTION_CIRCUIT_V1
Slice: D - Reconciliation Cell

## 0. Mandatory primary spec

Before doing anything else, read:

    operations/body_self_inspection/BODY_SELF_INSPECTION_CIRCUIT_V1_PLAN.md

Primary plan sections for this slice:

    0. Core decision
    1. Goal, mode, inputs/outputs, boundary
    9. Reconciliation Cell
    14. Validator Layer
    16. Codex Implementation Pack

Also read existing Slice A/B/C implementation/proofs:

    operations/body_self_inspection/invoke_body_self_inspection_slice_a_v1.ps1
    operations/body_self_inspection/invoke_body_self_inspection_slice_b_v1.ps1
    operations/body_self_inspection/invoke_body_self_inspection_slice_c_v1.ps1
    validators/validate_body_self_inspection_slice_a_v1.ps1
    validators/validate_body_self_inspection_slice_b_v1.ps1
    validators/validate_body_self_inspection_slice_c_v1.ps1
    tests/self_development/BODY_SELF_INSPECTION_SLICE_A_V1_PROOF.json
    tests/self_development/BODY_SELF_INSPECTION_SLICE_B_V1_PROOF.json
    tests/self_development/BODY_SELF_INSPECTION_SLICE_C_V1_PROOF.json

The plan is the architecture spec. This task pack is the enforcement boundary.

## 1. Role and boundary

You are implementing one bounded read-only slice of BODY_SELF_INSPECTION_CIRCUIT_V1.

You are not the Builder brain. You are an implementation tool.

Do not redesign the organ. Do not expand beyond Slice D.

Slice D builds only:

    Reconciliation Cell
    cross-source consistency index
    discrepancy records
    declared-vs-present-vs-validated boundary report
    minimal Slice D invoker
    Slice D validator and proof

## 2. PREFLIGHT rule

Before any file writes, produce exactly one:

    PREFLIGHT_PASS
    BLOCKED_PREFLIGHT

No file writes before PREFLIGHT_PASS.

Final report must include:

    Files changed before PREFLIGHT_PASS: YES/NO

Expected:

    NO

PREFLIGHT must check/report:

    repo root
    branch
    HEAD
    git status --short --untracked-files=all
    origin delta
    main plan file exists
    Slice A/B/C files exist
    Slice A/B/C validator status if quick to run
    target Slice D files already exist or not

If repo is dirty before changes, return BLOCKED_PREFLIGHT unless dirt is explicitly expected and explained.

## 3. Allowed files

Allowed new files:

    operations/body_self_inspection/reconcile_body_state_v1.ps1
    operations/body_self_inspection/invoke_body_self_inspection_slice_d_v1.ps1
    validators/validate_body_self_inspection_slice_d_v1.ps1
    tests/self_development/BODY_SELF_INSPECTION_SLICE_D_V1_PROOF.json

Allowed existing files to read:

    operations/body_self_inspection/BODY_SELF_INSPECTION_CIRCUIT_V1_PLAN.md
    Slice A/B/C implementation files
    Slice A/B/C validator/proof files
    existing maps/passports/contracts/validators/proofs as read-only evidence

Allowed existing files to edit only if strictly required for compatibility bugfix:

    operations/body_self_inspection/*slice_a*.ps1
    operations/body_self_inspection/*slice_b*.ps1
    operations/body_self_inspection/*slice_c*.ps1
    validators/validate_body_self_inspection_slice_a_v1.ps1
    validators/validate_body_self_inspection_slice_b_v1.ps1
    validators/validate_body_self_inspection_slice_c_v1.ps1

If editing any existing Slice A/B/C file, explain exact reason and keep backward compatibility.

Allowed runtime outputs:

    .runtime/body_self_inspection_v1/body_reconciliation.json
    .runtime/body_self_inspection_v1/BODY_SELF_INSPECTION_SLICE_D_PROOF.json

Slice D may call Slice C invoker to produce/refresh prior outputs.

## 4. Forbidden scope

Do not edit or mutate:

    .runtime/active_compact_semantic_memory_v1
    accepted-core surfaces
    body maps directly
    capability maps directly
    organ passports/contracts
    authority passports
    validators unrelated to Slice D
    operations/autonomous_inner_motor/*
    operations/reasoning/*
    live runtime launch scripts
    school runtime scripts
    git metadata
    credentials/secrets/env files

Do not:

    delete or cleanup runtime
    run live runtime
    launch Codex recursively
    browse web
    implement Body Pain Register
    implement Repair Draft Board
    implement Next Logic Queue
    implement Self-Inspection Signal full schema
    implement Mind Logic Integration
    implement Nervous System
    auto-create missing passports
    auto-create missing signal contracts
    auto-merge duplicate organs
    auto-delete duplicate candidates
    promote candidates to organs

## 5. Required reconciliation input sources

Implement reconciliation from these prior outputs:

    .runtime/body_self_inspection_v1/repo_inventory.json
    .runtime/body_self_inspection_v1/body_map_read.json
    .runtime/body_self_inspection_v1/capability_map_read.json
    .runtime/body_self_inspection_v1/organ_candidates.json
    .runtime/body_self_inspection_v1/organ_similarity_index.json
    .runtime/body_self_inspection_v1/passport_audit.json
    .runtime/body_self_inspection_v1/signal_readiness_audit.json

Reconciliation must distinguish:

    declared_in_map
    present_in_repo
    grouped_as_candidate
    passport_audited
    signal_audited
    validator_backed
    proof_backed
    similarity_flagged
    missing_reference
    stale_reference
    broken_reference
    ambiguous_duplicate

Boundary:

    DECLARED != PRESENT
    PRESENT != VALIDATED
    VALIDATED != MATURE
    SIMILAR != DUPLICATE_PROVEN
    AUDIT_RECORD != PAIN_REGISTER
    DISCREPANCY != REPAIR_DRAFT

## 6. Required reconciliation implementation

Implement:

    operations/body_self_inspection/reconcile_body_state_v1.ps1

It must write:

    .runtime/body_self_inspection_v1/body_reconciliation.json

Required output top-level fields:

    schema
    status
    version
    generated_at
    repo_root
    input_refs
    reconciliation_records
    discrepancy_records
    reference_status_index
    aggregates
    boundary_claims
    boundary

PASS runtime status:

    PASS_BODY_RECONCILIATION_V1

Reconciliation record required fields:

    reconciliation_id
    subject_id
    subject_kind
    subject_name
    source_refs
    declared_in_map
    present_in_repo
    candidate_detected
    passport_audited
    signal_audited
    validator_backed
    proof_backed
    similarity_statuses
    reference_statuses
    maturity_boundary
    evidence_status
    confidence
    recommended_next_cell
    forbidden_now

Discrepancy record required fields:

    discrepancy_id
    subject_id
    discrepancy_type
    severity
    source_refs
    evidence_refs
    explanation
    recommended_next_cell
    forbidden_now

Allowed discrepancy_type values include:

    DECLARED_NOT_FOUND_IN_REPO
    PRESENT_NOT_DECLARED
    CANDIDATE_WITHOUT_PASSPORT
    CANDIDATE_WITHOUT_CONTRACT
    CANDIDATE_WITHOUT_VALIDATOR
    CANDIDATE_WITHOUT_PROOF
    CANDIDATE_WITHOUT_SIGNAL
    PASSPORT_WITHOUT_CONTRACT
    CONTRACT_WITHOUT_PASSPORT
    SIGNAL_CONTRACT_WITHOUT_VALIDATOR
    SIGNAL_VALIDATOR_WITHOUT_CONTRACT
    POSSIBLE_DUPLICATE_NEEDS_REVIEW
    FUNCTIONAL_OVERLAP_NEEDS_REVIEW
    BROKEN_REFERENCE
    STALE_REFERENCE
    MAP_DECLARATION_AMBIGUOUS
    UNKNOWN_RECONCILIATION_GAP

Allowed severity values:

    INFO
    LOW
    MEDIUM
    HIGH
    BLOCKER_CANDIDATE

Recommended next cells must only point forward:

    BODY_PAIN_REGISTER
    REPAIR_DRAFT_BOARD
    NEXT_LOGIC_QUEUE
    PASSPORT_AUDIT
    SIGNAL_READINESS_AUDIT
    ORGAN_SIMILARITY_REVIEW
    MAP_REFRESH_REVIEW
    HUMAN_REVIEW
    NONE

Do not implement those next cells in Slice D.

## 7. Reference status index

The reference_status_index must include entries for paths/refs discovered from maps, candidates, passport audit and signal audit.

Reference status values:

    REF_PRESENT
    REF_MISSING
    REF_PARSE_FAILED
    REF_DECLARED_ONLY
    REF_RUNTIME_ONLY
    REF_UNKNOWN

Each reference status entry must include:

    ref
    ref_kind
    status
    discovered_from
    evidence_refs

## 8. Minimal invoker

Implement:

    operations/body_self_inspection/invoke_body_self_inspection_slice_d_v1.ps1

It must:

    create .runtime/body_self_inspection_v1 if missing
    call Slice C invoker or verify Slice A/B/C outputs exist/fresh enough
    call reconcile_body_state_v1.ps1
    write BODY_SELF_INSPECTION_SLICE_D_PROOF.json

Runtime proof status:

    PASS_BODY_SELF_INSPECTION_SLICE_D_RUNTIME_V1

## 9. Validator requirements

Implement:

    validators/validate_body_self_inspection_slice_d_v1.ps1

Validator must run the Slice D invoker and verify:

    Slice A/B/C outputs exist and parse
    body_reconciliation.json exists and parses
    BODY_SELF_INSPECTION_SLICE_D_PROOF.json exists and parses
    reconciliation_records exist
    discrepancy_records exist when prior audits provide missing passport/signal/validator/proof evidence
    required fields exist on reconciliation records
    required fields exist on discrepancy records
    reference_status_index exists and has required fields
    declared/present/validated/mature boundaries are explicit
    candidates are not promoted to organs
    discrepancies are not treated as repair drafts
    no tracked map/passport/contract mutation
    no active memory mutation
    no accepted-core mutation
    no live process touched
    no Codex/web launched

Tracked validator proof path:

    tests/self_development/BODY_SELF_INSPECTION_SLICE_D_V1_PROOF.json

PASS status:

    PASS_BODY_SELF_INSPECTION_SLICE_D_V1

Failure statuses:

    FAIL_BODY_SELF_INSPECTION_SLICE_D_V1
    BLOCKED_BODY_SELF_INSPECTION_SLICE_D_V1

## 10. Negative/safety checks

Validator must fail if:

    candidate is promoted to organ
    declared is treated as present
    present is treated as validated
    validated is treated as mature
    similarity is treated as duplicate proof
    discrepancy is treated as repair draft
    required output is unparsable JSON
    record lacks forbidden_now
    record lacks evidence_refs/source_refs
    runtime proof status is not PASS
    boundary flags are missing or not false

Do not create huge fixtures. Prefer runtime temp fixtures if needed.

## 11. Required boundary proof

Every output/proof must state:

    repo_mutated = false
    active_memory_mutated = false
    accepted_core_mutated = false
    body_map_mutated = false
    capability_map_mutated = false
    passports_mutated = false
    contracts_mutated = false
    live_process_touched = false
    codex_launched = false
    web_launched = false
    cleanup_performed = false

Runtime outputs under .runtime/body_self_inspection_v1 are allowed.

## 12. Commands to run before final report

Run at least:

    powershell -NoProfile -ExecutionPolicy Bypass -File validators/validate_body_self_inspection_slice_d_v1.ps1
    git diff --check
    git status --short --untracked-files=all

Do not commit/push unless explicitly instructed by GPT/operator.

## 13. Expected final report

Final report must include:

    PREFLIGHT_PASS or BLOCKED_PREFLIGHT
    files changed
    files created
    validators run
    proof paths
    reconciliation summary
    discrepancy summary
    reference status summary
    boundary proof
    known gaps
    next recommended slice
    Files changed before PREFLIGHT_PASS: YES/NO

## 14. Cut list

Do not implement in Slice D:

    Body Pain Register
    Repair Draft Board
    Next Logic Queue
    Self-Inspection Signal full schema
    Mind Logic Integration
    Nervous System

## 15. Acceptance boundary

This slice is accepted only if:

    validator PASS
    proof JSON PASS
    outputs parse
    reconciliation distinguishes declared/present/validated/mature
    discrepancies are produced but not promoted to repair drafts
    reference status index exists
    mutation boundary false
    repo final status contains only intentional tracked changes and allowed runtime outputs are untracked/ignored

No claim that full BODY_SELF_INSPECTION_CIRCUIT_V1 is built.
Only claim Slice D readiness.
