# CODEX_TASK_BODY_SELF_INSPECTION_SLICE_C

Status: READY_FOR_CODEX / NOT_RUN
Task type: bounded implementation slice
Target organ/circuit: BODY_SELF_INSPECTION_CIRCUIT_V1
Slice: C - passport/contract audit + signal readiness audit

## 0. Mandatory primary spec

Before doing anything else, read:

    operations/body_self_inspection/BODY_SELF_INSPECTION_CIRCUIT_V1_PLAN.md

Primary plan sections for this slice:

    0. Core decision
    1. Goal, mode, inputs/outputs, boundary
    7. Passport / Contract Audit Cell
    8. Signal Readiness Audit Cell
    14. Validator Layer
    16. Codex Implementation Pack

Also read existing Slice A/B implementation/proofs:

    operations/body_self_inspection/invoke_body_self_inspection_slice_a_v1.ps1
    operations/body_self_inspection/invoke_body_self_inspection_slice_b_v1.ps1
    validators/validate_body_self_inspection_slice_a_v1.ps1
    validators/validate_body_self_inspection_slice_b_v1.ps1
    tests/self_development/BODY_SELF_INSPECTION_SLICE_A_V1_PROOF.json
    tests/self_development/BODY_SELF_INSPECTION_SLICE_B_V1_PROOF.json

The plan is the architecture spec. This task pack is the enforcement boundary.

## 1. Role and boundary

You are implementing one bounded read-only slice of BODY_SELF_INSPECTION_CIRCUIT_V1.

You are not the Builder brain. You are an implementation tool.

Do not redesign the organ. Do not expand beyond Slice C.

Slice C builds only:

    passport / contract / authority audit
    validator/proof relationship audit for candidates
    signal readiness audit
    minimal Slice C invoker
    Slice C validator and proof

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
    Slice A/B files exist
    Slice A/B validator status if quick to run
    target Slice C files already exist or not

If repo is dirty before changes, return BLOCKED_PREFLIGHT unless dirt is explicitly expected and explained.

## 3. Allowed files

Allowed new files:

    operations/body_self_inspection/audit_passports_and_contracts_v1.ps1
    operations/body_self_inspection/audit_signal_readiness_v1.ps1
    operations/body_self_inspection/invoke_body_self_inspection_slice_c_v1.ps1
    validators/validate_body_self_inspection_slice_c_v1.ps1
    tests/self_development/BODY_SELF_INSPECTION_SLICE_C_V1_PROOF.json

Allowed existing files to read:

    operations/body_self_inspection/BODY_SELF_INSPECTION_CIRCUIT_V1_PLAN.md
    Slice A/B implementation files
    Slice A/B validator/proof
    existing passport/contract/validator/proof files

Allowed existing files to edit only if strictly required for compatibility bugfix:

    operations/body_self_inspection/*slice_a*.ps1
    operations/body_self_inspection/*slice_b*.ps1
    validators/validate_body_self_inspection_slice_a_v1.ps1
    validators/validate_body_self_inspection_slice_b_v1.ps1

If editing any existing Slice A/B file, explain exact reason and keep backward compatibility.

Allowed runtime outputs:

    .runtime/body_self_inspection_v1/passport_audit.json
    .runtime/body_self_inspection_v1/signal_readiness_audit.json
    .runtime/body_self_inspection_v1/BODY_SELF_INSPECTION_SLICE_C_PROOF.json

Slice C may call Slice B invoker to produce/refresh prior outputs.

## 4. Forbidden scope

Do not edit or mutate:

    .runtime/active_compact_semantic_memory_v1
    accepted-core surfaces
    body maps directly
    capability maps directly
    organ passports/contracts
    authority passports
    validators unrelated to Slice C
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
    implement reconciliation
    implement body pain register
    implement repair draft board
    implement next logic queue
    implement nervous system
    implement mind integration
    rewrite passport law
    auto-create missing passports
    auto-create missing signal contracts
    promote candidates to organs

## 5. Existing passport/contract refs to audit

Known law/reference surfaces to read/check when present:

    contracts/accepted_atom_retention_organ/passports/ORGAN_PASSPORT.json
    contracts/accepted_atom_retention_organ/passports/PASSPORT_INDEX.json
    contracts/accepted_atom_retention_organ/passports/CAPABILITY_PASSPORT.json
    operations/autonomous_inner_motor/organ_contract.json
    operations/autonomous_inner_motor/execution_authority_passport_v1.json
    validators/validate_accepted_atom_retention_passports_v1.ps1
    validators/validate_autonomous_inner_motor_organ_contract.ps1

These are reference surfaces, not proof that every candidate complies.

## 6. Required passport/contract audit

Implement:

    operations/body_self_inspection/audit_passports_and_contracts_v1.ps1

It must write:

    .runtime/body_self_inspection_v1/passport_audit.json

It must read:

    repo_inventory.json
    body_map_read.json
    capability_map_read.json
    organ_candidates.json
    organ_similarity_index.json

Audit targets come from:

    map-declared organs
    repo organ candidates
    candidate families
    organ_contract files
    authority passport files
    capability passport files
    validator clusters claiming organ validation
    known active organs from maps

Every target must receive passport_status, contract_status, authority_status, validator_status, proof_status.

Allowed passport_status values:

    PASSPORT_PRESENT_VALIDATED
    PASSPORT_PRESENT_UNVALIDATED
    PASSPORT_PRESENT_PARSE_FAILED
    PASSPORT_MISSING
    PASSPORT_INDEX_ONLY
    CONTRACT_PRESENT_PASSPORT_MISSING
    PASSPORT_PRESENT_CONTRACT_MISSING
    AUTHORITY_PASSPORT_MISSING
    CAPABILITY_PASSPORT_MISSING
    PASSPORT_REQUIRED_FIELD_MISSING
    PASSPORT_SCHEMA_UNKNOWN
    NOT_ORGAN_NO_PASSPORT_REQUIRED_YET

Boundary:

    PASSPORT_PRESENT != PASSPORT_VALIDATED
    PASSPORT_VALIDATED != ORGAN_MATURE
    CONTRACT_PRESENT != ORGAN_WIRED

Each audit record must include:

    audit_id
    target_id
    target_kind
    target_refs
    passport_status
    contract_status
    authority_status
    capability_passport_status
    validator_status
    proof_status
    required_fields_checked
    missing_fields
    parse_errors
    evidence_refs
    pain_candidates
    recommended_logic_action
    forbidden_now

## 7. Required signal readiness audit

Implement:

    operations/body_self_inspection/audit_signal_readiness_v1.ps1

It must write:

    .runtime/body_self_inspection_v1/signal_readiness_audit.json

It must read:

    repo_inventory.json
    body_map_read.json
    capability_map_read.json
    organ_candidates.json
    passport_audit.json

Every target must receive:

    signal_contract_status
    expected_signals_emitted
    expected_signals_consumed
    signal_schema_ref
    signal_validator_ref
    signal_emission_proof_ref
    signal_sink_status
    signal_adapter_status
    nervous_system_dependency_status

Allowed signal_contract_status values:

    NATIVE_SIGNAL_EMITTER
    LEGACY_SIGNAL_ADAPTED
    SIGNAL_MISSING
    SIGNAL_UNKNOWN
    SIGNAL_CONTRACT_WITHOUT_VALIDATOR
    SIGNAL_VALIDATOR_WITHOUT_CONTRACT
    SIGNAL_SCHEMA_REF_BROKEN
    SIGNAL_PROOF_REF_BROKEN
    SIGNAL_EMITS_TO_PLACEHOLDER
    SIGNAL_NOT_REQUIRED_FOR_NON_ORGAN

Boundary:

    SIGNAL_FIELD_PRESENT != SIGNAL_READY
    SIGNAL_READY != NERVOUS_SYSTEM_CONNECTED
    EMITS_TO_PLACEHOLDER is allowed but must be explicit

Each signal audit record must include:

    audit_id
    target_id
    target_kind
    signal_contract_status
    expected_signals_emitted
    expected_signals_consumed
    signal_schema_ref
    signal_validator_ref
    signal_emission_proof_ref
    signal_sink_status
    signal_adapter_status
    nervous_system_dependency_status
    evidence_refs
    pain_candidates
    recommended_logic_action
    forbidden_now

## 8. Minimal invoker

Implement:

    operations/body_self_inspection/invoke_body_self_inspection_slice_c_v1.ps1

It must:

    create .runtime/body_self_inspection_v1 if missing
    call Slice B invoker or verify Slice A/B outputs exist/fresh enough
    call audit_passports_and_contracts_v1.ps1
    call audit_signal_readiness_v1.ps1
    write BODY_SELF_INSPECTION_SLICE_C_PROOF.json

Runtime proof status:

    PASS_BODY_SELF_INSPECTION_SLICE_C_RUNTIME_V1

## 9. Validator requirements

Implement:

    validators/validate_body_self_inspection_slice_c_v1.ps1

Validator must run the Slice C invoker and verify:

    Slice A/B outputs exist and parse
    passport_audit.json exists and parses
    signal_readiness_audit.json exists and parses
    BODY_SELF_INSPECTION_SLICE_C_PROOF.json exists and parses
    audit targets are derived from candidates/maps/contracts
    every passport audit target has required fields
    every signal audit target has required fields
    passport presence is not treated as maturity
    signal field presence is not treated as nervous-system connection
    pain_candidates exist for missing passport/validator/proof/signal cases when evidence supports them
    forbidden_now is present on audit records
    no tracked map/passport/contract mutation
    no active memory mutation
    no accepted-core mutation
    no live process touched
    no Codex/web launched

Tracked validator proof path:

    tests/self_development/BODY_SELF_INSPECTION_SLICE_C_V1_PROOF.json

PASS status:

    PASS_BODY_SELF_INSPECTION_SLICE_C_V1

Failure statuses:

    FAIL_BODY_SELF_INSPECTION_SLICE_C_V1
    BLOCKED_BODY_SELF_INSPECTION_SLICE_C_V1

## 10. Negative/safety checks

Validator must fail if:

    candidate is promoted to organ
    passport presence is claimed as maturity
    contract presence is claimed as wiring
    signal field is claimed as nervous system connection
    required output is unparsable JSON
    audit record lacks forbidden_now
    audit record lacks evidence_refs
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

    powershell -NoProfile -ExecutionPolicy Bypass -File validators/validate_body_self_inspection_slice_c_v1.ps1
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
    passport audit summary
    signal readiness summary
    boundary proof
    known gaps
    next recommended slice
    Files changed before PREFLIGHT_PASS: YES/NO

## 14. Cut list

Do not implement in Slice C:

    Reconciliation Cell
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
    passport audit distinguishes present/unvalidated/missing
    signal audit distinguishes readiness from nervous-system wiring
    candidates are not promoted to organs
    mutation boundary false
    repo final status contains only intentional tracked changes and allowed runtime outputs are untracked/ignored

No claim that full BODY_SELF_INSPECTION_CIRCUIT_V1 is built.
Only claim Slice C readiness.
