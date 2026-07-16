# CODEX_TASK_BODY_SELF_INSPECTION_SLICE_B

Status: READY_FOR_CODEX / NOT_RUN
Task type: bounded implementation slice
Target organ/circuit: BODY_SELF_INSPECTION_CIRCUIT_V1
Slice: B - map reader + organ candidate detector + similarity detector

## 0. Mandatory primary spec

Before doing anything else, read:

    operations/body_self_inspection/BODY_SELF_INSPECTION_CIRCUIT_V1_PLAN.md

Primary plan sections for this slice:

    0. Core decision
    1. Goal, mode, inputs/outputs, boundary
    4. Body / Capability Map Reader Cell
    5. Organ Candidate Detector Cell
    6. Organ Similarity / Duplicate Detector Cell
    14. Validator Layer
    16. Codex Implementation Pack

Also read existing Slice A implementation/proof:

    operations/body_self_inspection/build_body_scan_policy_v1.ps1
    operations/body_self_inspection/build_body_repo_inventory_v1.ps1
    operations/body_self_inspection/invoke_body_self_inspection_slice_a_v1.ps1
    validators/validate_body_self_inspection_slice_a_v1.ps1
    tests/self_development/BODY_SELF_INSPECTION_SLICE_A_V1_PROOF.json

The plan is the architecture spec. This task pack is the enforcement boundary.

## 1. Role and boundary

You are implementing one bounded read-only slice of BODY_SELF_INSPECTION_CIRCUIT_V1.

You are not the Builder brain. You are an implementation tool.

Do not redesign the organ. Do not expand beyond Slice B.

Slice B builds only:

    body/capability map reader
    organ candidate detector
    organ candidate family grouping
    organ similarity / duplicate detector
    minimal Slice B invoker
    Slice B validator and proof

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
    Slice A files exist
    Slice A validator status if quick to run
    target Slice B files already exist or not

If repo is dirty before changes, return BLOCKED_PREFLIGHT unless dirt is explicitly expected and explained.

## 3. Allowed files

Allowed new files:

    operations/body_self_inspection/read_body_maps_v1.ps1
    operations/body_self_inspection/detect_organ_candidates_v1.ps1
    operations/body_self_inspection/detect_organ_similarity_v1.ps1
    operations/body_self_inspection/invoke_body_self_inspection_slice_b_v1.ps1
    validators/validate_body_self_inspection_slice_b_v1.ps1
    tests/self_development/BODY_SELF_INSPECTION_SLICE_B_V1_PROOF.json

Allowed existing files to read:

    operations/body_self_inspection/BODY_SELF_INSPECTION_CIRCUIT_V1_PLAN.md
    Slice A implementation files
    Slice A validator/proof

Allowed existing files to edit only if strictly required for reuse bugfix:

    operations/body_self_inspection/build_body_scan_policy_v1.ps1
    operations/body_self_inspection/build_body_repo_inventory_v1.ps1
    operations/body_self_inspection/invoke_body_self_inspection_slice_a_v1.ps1
    validators/validate_body_self_inspection_slice_a_v1.ps1

If editing any Slice A file, explain exact reason and keep backward compatibility.

Allowed runtime outputs:

    .runtime/body_self_inspection_v1/body_map_read.json
    .runtime/body_self_inspection_v1/capability_map_read.json
    .runtime/body_self_inspection_v1/organ_candidates.json
    .runtime/body_self_inspection_v1/organ_similarity_index.json
    .runtime/body_self_inspection_v1/BODY_SELF_INSPECTION_SLICE_B_PROOF.json

Slice B may call Slice A invoker to produce/refresh:

    scan_policy_effective.json
    scan_skipped_surfaces.json
    repo_inventory.json

## 4. Forbidden scope

Do not edit or mutate:

    .runtime/active_compact_semantic_memory_v1
    accepted-core surfaces
    body maps directly
    capability maps directly
    organ passports/contracts
    unrelated validators
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
    implement passport audit
    implement signal readiness audit
    implement reconciliation
    implement pain register
    implement repair draft board
    implement next logic queue
    implement nervous system
    implement mind integration
    implement broad repo proof lookup executor

## 5. Required map reader

Implement:

    operations/body_self_inspection/read_body_maps_v1.ps1

It must write:

    .runtime/body_self_inspection_v1/body_map_read.json
    .runtime/body_self_inspection_v1/capability_map_read.json

It must read repo_inventory.json from Slice A.

It must search for map-like surfaces and root markers:

    CAPABILITY_ROADMAP.json
    GENESIS_STATE.json
    TASK_QUEUE.json
    packs/registry.json
    orchestrator/run.ps1
    body map
    capability map
    composition map
    organ registry
    invocation map
    launch map
    passport index
    validator index
    proof index
    signal index
    draft board
    pain register

Map record required fields:

    path
    map_type
    parse_status
    schema
    status
    declared_organs
    declared_capabilities
    declared_invocation_paths
    declared_validators
    declared_proof_refs
    declared_passport_refs
    declared_signal_refs
    stale_after
    last_updated_if_present
    evidence_status
    errors

Boundary:

    DECLARED_ORGAN != PRESENT_ORGAN
    DECLARED_ORGAN != VALID_ORGAN
    DECLARED_ORGAN != MATURE_ORGAN
    DECLARED_CAPABILITY != USABLE_CAPABILITY

Do not mutate map files.

## 6. Required organ candidate detector

Implement:

    operations/body_self_inspection/detect_organ_candidates_v1.ps1

It must write:

    .runtime/body_self_inspection_v1/organ_candidates.json

It must read:

    repo_inventory.json
    body_map_read.json
    capability_map_read.json

Candidate boundary:

    ORGAN_CANDIDATE != ORGAN
    SCRIPT != ORGAN
    VALIDATOR != ORGAN
    PASSPORT != ORGAN
    PROOF PRODUCER != ORGAN

Candidate record required fields:

    candidate_id
    candidate_type
    primary_path
    related_paths
    family_root
    name_guess
    capability_guess
    role_guess
    evidence_refs
    confidence
    discovered_from
    declared_in_maps
    has_contract_ref
    has_passport_ref
    has_validator_ref
    has_proof_ref
    has_invocation_ref
    has_signal_ref
    state_touched_guess
    authority_guess
    maturity_guess
    warnings

Allowed candidate_type values include:

    ORGAN_SCRIPT_CANDIDATE
    ORGAN_FOLDER_CANDIDATE
    ORGAN_CONTRACT_CANDIDATE
    AUTHORITY_PASSPORT_CANDIDATE
    CAPABILITY_PASSPORT_CANDIDATE
    VALIDATOR_CLUSTER_CANDIDATE
    PROOF_PRODUCER_CANDIDATE
    MAP_TOOL_CANDIDATE
    MEMORY_TOOL_CANDIDATE
    RUNTIME_TOOL_CANDIDATE
    SIGNAL_TOOL_CANDIDATE
    UNKNOWN_BODY_SURFACE_CANDIDATE

Confidence values:

    HIGH_CONTRACT_BACKED
    MEDIUM_VALIDATOR_BACKED
    MEDIUM_MAP_DECLARED
    LOW_NAME_PATTERN_ONLY
    LOW_DIRECTORY_PATTERN_ONLY
    UNKNOWN

Must group related files into candidate families using directory root, normalized name stem, validator/proof/contract/passport/invocation refs when available.

## 7. Required similarity detector

Implement:

    operations/body_self_inspection/detect_organ_similarity_v1.ps1

It must write:

    .runtime/body_self_inspection_v1/organ_similarity_index.json

It must compare:

    repo organ candidates vs map-declared organs
    repo organ candidates vs repo organ candidates
    map-declared organs vs map-declared organs
    candidate families vs validator clusters
    candidate families vs proof producers
    capability declarations vs candidate capabilities

Similarity statuses:

    UNIQUE_ORGAN_CANDIDATE
    POSSIBLE_DUPLICATE
    FUNCTIONAL_OVERLAP
    OLDER_VERSION_CANDIDATE
    NEWER_VERSION_CANDIDATE
    SHADOW_ORGAN
    WRAPPER_AROUND_EXISTING_ORGAN
    MERGE_CANDIDATE
    CONFLICTING_ORGAN
    SAME_FAMILY
    UNKNOWN_SIMILARITY

Similarity record required fields:

    similarity_id
    subject_a
    subject_b
    cluster_id
    similarity_status
    similarity_score
    matching_features
    conflicting_features
    evidence_refs
    risk
    recommended_logic_action
    forbidden_now

Boundary:

    similarity_score is heuristic, not proof
    duplicate is not proven solely by filename
    no automatic deletion
    no automatic merge
    no map rewrite

## 8. Minimal invoker

Implement:

    operations/body_self_inspection/invoke_body_self_inspection_slice_b_v1.ps1

It must:

    create .runtime/body_self_inspection_v1 if missing
    call Slice A invoker or verify Slice A outputs exist/fresh enough
    call read_body_maps_v1.ps1
    call detect_organ_candidates_v1.ps1
    call detect_organ_similarity_v1.ps1
    write BODY_SELF_INSPECTION_SLICE_B_PROOF.json

Runtime proof status:

    PASS_BODY_SELF_INSPECTION_SLICE_B_RUNTIME_V1

## 9. Validator requirements

Implement:

    validators/validate_body_self_inspection_slice_b_v1.ps1

Validator must run the Slice B invoker and verify:

    Slice A outputs exist and parse
    body_map_read.json exists and parses
    capability_map_read.json exists and parses
    organ_candidates.json exists and parses
    organ_similarity_index.json exists and parses
    BODY_SELF_INSPECTION_SLICE_B_PROOF.json exists and parses
    map reader records root markers / map-like surfaces
    declared organs/capabilities are not claimed as mature
    organ_candidates records have required fields
    at least one candidate family grouping exists if repo evidence supports it
    similarity index has statuses and required fields
    duplicate/similarity detector records forbidden_now
    no tracked map/passport/contract mutation
    no active memory mutation
    no accepted-core mutation
    no live process touched
    no Codex/web launched

Tracked validator proof path:

    tests/self_development/BODY_SELF_INSPECTION_SLICE_B_V1_PROOF.json

PASS status:

    PASS_BODY_SELF_INSPECTION_SLICE_B_V1

Failure statuses:

    FAIL_BODY_SELF_INSPECTION_SLICE_B_V1
    BLOCKED_BODY_SELF_INSPECTION_SLICE_B_V1

## 10. Negative/safety checks

Validator must fail if:

    declared organ is labeled mature without proof
    candidate is promoted to organ
    similarity detector mutates files
    duplicate is proven only from filename
    required output is unparsable JSON
    candidate records lack evidence_refs
    similarity records lack forbidden_now
    runtime proof status is not PASS

Do not create huge fixtures. Prefer runtime temp fixtures if needed.

## 11. Required boundary proof

Every output/proof must state:

    repo_mutated = false
    active_memory_mutated = false
    accepted_core_mutated = false
    body_map_mutated = false
    capability_map_mutated = false
    live_process_touched = false
    codex_launched = false
    web_launched = false
    cleanup_performed = false

Runtime outputs under .runtime/body_self_inspection_v1 are allowed.

## 12. Commands to run before final report

Run at least:

    powershell -NoProfile -ExecutionPolicy Bypass -File validators/validate_body_self_inspection_slice_b_v1.ps1
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
    map records summary
    candidate families summary
    similarity statuses summary
    boundary proof
    known gaps
    next recommended slice
    Files changed before PREFLIGHT_PASS: YES/NO

## 14. Cut list

Do not implement in Slice B:

    Passport / Contract Audit Cell
    Signal Readiness Audit Cell
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
    map reader distinguishes declared from proven
    candidates are not promoted to organs
    candidate family grouping exists
    similarity/duplicate detector exists
    mutation boundary false
    repo final status contains only intentional tracked changes and allowed runtime outputs are untracked/ignored

No claim that full BODY_SELF_INSPECTION_CIRCUIT_V1 is built.
Only claim Slice B readiness.
