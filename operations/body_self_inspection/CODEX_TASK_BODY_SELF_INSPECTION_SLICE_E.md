# CODEX_TASK_BODY_SELF_INSPECTION_SLICE_E

Status: READY_FOR_CODEX / NOT_RUN
Task type: bounded implementation slice
Target organ/circuit: BODY_SELF_INSPECTION_CIRCUIT_V1
Slice: E - Body Pain Register + Repair Draft Board + Next Logic Queue

## 0. Mandatory primary spec

Read first:

    operations/body_self_inspection/BODY_SELF_INSPECTION_CIRCUIT_V1_PLAN.md

Primary plan sections for this slice:

    10. Body Pain Register
    11. Repair Draft Board
    12. Next Logic Queue
    14. Validator Layer
    16. Codex Implementation Pack

Also read existing Slice A/B/C/D implementation and proofs:

    operations/body_self_inspection/invoke_body_self_inspection_slice_d_v1.ps1
    validators/validate_body_self_inspection_slice_d_v1.ps1
    tests/self_development/BODY_SELF_INSPECTION_SLICE_D_V1_PROOF.json

## 1. Role and boundary

Implement only Slice E.

You are not the Builder brain. You are an implementation tool.

Slice E converts reconciliation discrepancies into:

    pain candidates
    repair draft candidates
    next logic queue items

It must not execute repairs.
It must not mutate maps/passports/contracts/live/active memory.
It must not promote candidates to organs.
It must not implement self-signal, mind integration or nervous system.

## 2. PREFLIGHT rule

Before any file writes, produce exactly one:

    PREFLIGHT_PASS
    BLOCKED_PREFLIGHT

No file writes before PREFLIGHT_PASS.

Final report must include:

    Files changed before PREFLIGHT_PASS: YES/NO

Expected: NO

PREFLIGHT must check/report:

    repo root
    branch
    HEAD
    git status --short --untracked-files=all
    origin delta
    Slice D files/proof exist
    target Slice E files already exist or not

If repo is dirty before changes, return BLOCKED_PREFLIGHT unless dirt is explicitly expected and explained.

## 3. Allowed files

Allowed new files:

    operations/body_self_inspection/build_body_pain_register_v1.ps1
    operations/body_self_inspection/build_repair_draft_board_v1.ps1
    operations/body_self_inspection/build_next_logic_queue_v1.ps1
    operations/body_self_inspection/invoke_body_self_inspection_slice_e_v1.ps1
    validators/validate_body_self_inspection_slice_e_v1.ps1
    tests/self_development/BODY_SELF_INSPECTION_SLICE_E_V1_PROOF.json

Allowed runtime outputs:

    .runtime/body_self_inspection_v1/body_pain_register.json
    .runtime/body_self_inspection_v1/repair_draft_board.json
    .runtime/body_self_inspection_v1/next_logic_queue.json
    .runtime/body_self_inspection_v1/BODY_SELF_INSPECTION_SLICE_E_PROOF.json

Slice E may call Slice D invoker to refresh prior outputs.

## 4. Forbidden scope

Do not edit or mutate:

    .runtime/active_compact_semantic_memory_v1
    accepted-core surfaces
    body maps directly
    capability maps directly
    organ passports/contracts
    authority passports
    operations/autonomous_inner_motor/*
    operations/reasoning/*
    live runtime launch scripts
    school runtime scripts
    git metadata
    credentials/secrets/env files

Do not:

    run live runtime
    delete or cleanup runtime
    launch Codex recursively
    browse web
    execute repair drafts
    patch files based on drafts
    create missing passports/contracts/signals
    merge/delete duplicate candidates
    promote candidates to organs
    implement Self-Inspection Signal
    implement Mind Logic Integration
    implement Nervous System

## 5. Required pain register

Implement:

    operations/body_self_inspection/build_body_pain_register_v1.ps1

It must read:

    .runtime/body_self_inspection_v1/body_reconciliation.json

It must write:

    .runtime/body_self_inspection_v1/body_pain_register.json

Pain record required fields:

    pain_id
    source_discrepancy_id
    subject_id
    pain_type
    severity
    evidence_refs
    source_refs
    why_it_matters
    blocked_capability
    recommended_repair_class
    next_cell
    acceptance_boundary
    forbidden_now

Allowed pain_type values include:

    MISSING_PASSPORT_PAIN
    MISSING_CONTRACT_PAIN
    MISSING_VALIDATOR_PAIN
    MISSING_PROOF_PAIN
    MISSING_SIGNAL_PAIN
    POSSIBLE_DUPLICATE_PAIN
    FUNCTIONAL_OVERLAP_PAIN
    BROKEN_REFERENCE_PAIN
    MAP_AMBIGUITY_PAIN
    UNKNOWN_BODY_PAIN

Boundary:

    pain record != repair
    pain record != accepted defect
    pain record != permission to mutate

## 6. Required repair draft board

Implement:

    operations/body_self_inspection/build_repair_draft_board_v1.ps1

It must read:

    body_pain_register.json
    body_reconciliation.json

It must write:

    repair_draft_board.json

Repair draft record required fields:

    draft_id
    source_pain_id
    subject_id
    repair_class
    proposed_scope
    files_in_scope
    files_forbidden
    validators_required
    proof_required
    risk
    authority_required
    estimated_slice
    execution_allowed
    recommended_operator
    acceptance_boundary
    forbidden_now

Allowed repair_class values include:

    CREATE_OR_REPAIR_PASSPORT_DRAFT
    CREATE_OR_REPAIR_CONTRACT_DRAFT
    ADD_OR_REPAIR_VALIDATOR_DRAFT
    ADD_OR_REPAIR_PROOF_DRAFT
    ADD_SIGNAL_CONTRACT_DRAFT
    REVIEW_DUPLICATE_DRAFT
    REVIEW_FUNCTIONAL_OVERLAP_DRAFT
    REPAIR_BROKEN_REFERENCE_DRAFT
    MAP_REFRESH_REVIEW_DRAFT
    HUMAN_REVIEW_DRAFT

Boundary:

    execution_allowed must be false
    draft != patch
    draft != accepted repair
    draft != Codex task unless later promoted by operator

## 7. Required next logic queue

Implement:

    operations/body_self_inspection/build_next_logic_queue_v1.ps1

It must read:

    repair_draft_board.json
    body_pain_register.json

It must write:

    next_logic_queue.json

Queue item required fields:

    queue_id
    source_draft_id
    subject_id
    priority
    queue_type
    reason
    proposed_next_slice
    dependencies
    validators_required
    proof_required
    execution_allowed
    owner_decision_required
    recommended_operator
    forbidden_now

Allowed queue_type values include:

    OPERATOR_REVIEW
    CODEX_TASK_CANDIDATE
    VALIDATOR_REPAIR_CANDIDATE
    PASSPORT_REPAIR_CANDIDATE
    SIGNAL_REPAIR_CANDIDATE
    MAP_REVIEW_CANDIDATE
    DUPLICATE_REVIEW_CANDIDATE
    HUMAN_DECISION_REQUIRED

Boundary:

    queue item != execution
    queue item != Owner approval
    queue item != accepted task

## 8. Minimal invoker

Implement:

    operations/body_self_inspection/invoke_body_self_inspection_slice_e_v1.ps1

It must:

    create .runtime/body_self_inspection_v1 if missing
    call Slice D invoker or verify Slice A-D outputs exist/fresh enough
    call build_body_pain_register_v1.ps1
    call build_repair_draft_board_v1.ps1
    call build_next_logic_queue_v1.ps1
    write BODY_SELF_INSPECTION_SLICE_E_PROOF.json

Runtime proof status:

    PASS_BODY_SELF_INSPECTION_SLICE_E_RUNTIME_V1

## 9. Validator requirements

Implement:

    validators/validate_body_self_inspection_slice_e_v1.ps1

Validator must run Slice E invoker and verify:

    Slice D outputs exist and parse
    body_pain_register.json exists and parses
    repair_draft_board.json exists and parses
    next_logic_queue.json exists and parses
    BODY_SELF_INSPECTION_SLICE_E_PROOF.json exists and parses
    pain records exist when reconciliation discrepancies exist
    repair draft records exist when pain records exist
    next logic queue items exist when repair drafts exist
    required fields exist on all record types
    execution_allowed is false on all drafts and queue items
    no repair execution happened
    no tracked map/passport/contract mutation
    no active memory mutation
    no accepted-core mutation
    no live process touched
    no Codex/web launched

Tracked validator proof path:

    tests/self_development/BODY_SELF_INSPECTION_SLICE_E_V1_PROOF.json

PASS status:

    PASS_BODY_SELF_INSPECTION_SLICE_E_V1

Failure statuses:

    FAIL_BODY_SELF_INSPECTION_SLICE_E_V1
    BLOCKED_BODY_SELF_INSPECTION_SLICE_E_V1

## 10. Required boundary proof

Every output/proof must state:

    repo_mutated = false
    active_memory_mutated = false
    accepted_core_mutated = false
    body_map_mutated = false
    capability_map_mutated = false
    passports_mutated = false
    contracts_mutated = false
    repair_executed = false
    live_process_touched = false
    codex_launched = false
    web_launched = false
    cleanup_performed = false

Runtime outputs under .runtime/body_self_inspection_v1 are allowed.

## 11. Commands before final report

Run at least:

    powershell -NoProfile -ExecutionPolicy Bypass -File validators/validate_body_self_inspection_slice_e_v1.ps1
    git diff --check
    git status --short --untracked-files=all

Do not commit/push unless explicitly instructed by GPT/operator.

## 12. Acceptance boundary

This slice is accepted only if:

    validator PASS
    proof JSON PASS
    outputs parse
    pain/draft/queue records exist
    execution_allowed false everywhere
    mutation boundary false

No claim that full BODY_SELF_INSPECTION_CIRCUIT_V1 is built.
Only claim Slice E readiness.
