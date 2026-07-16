# CODEX_TASK_BODY_SELF_INSPECTION_SLICE_A

Status: READY_FOR_CODEX / NOT_RUN
Task type: bounded implementation slice
Target organ/circuit: BODY_SELF_INSPECTION_CIRCUIT_V1
Slice: A - scan policy + repo inventory + validator smoke

## 0. Mandatory primary spec

Before doing anything else, read:

    operations/body_self_inspection/BODY_SELF_INSPECTION_CIRCUIT_V1_PLAN.md

Primary plan sections for this slice:

    0. Core decision
    1. Goal, mode, inputs/outputs, boundary
    2. Boundaries, protected surfaces, scan policy, denylist
    3. Repo Inventory Cell
    14. Validator Layer
    16. Codex Implementation Pack

The plan is the architecture spec. This task pack is the enforcement boundary.

## 1. Role and boundary

You are implementing one bounded read-only slice of BODY_SELF_INSPECTION_CIRCUIT_V1.

You are not the Builder brain. You are an implementation tool.

Do not redesign the organ. Do not expand beyond Slice A.

Slice A builds only:

    scan policy loader / builder
    bounded metadata-first repo inventory
    skipped surfaces report
    minimal Slice A invoker
    Slice A validator smoke
    Slice A proof JSON

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
    plan file exists
    existing operations/body_self_inspection files
    whether target files already exist
    protected surfaces observed

If repo is dirty before changes, return BLOCKED_PREFLIGHT unless dirt is explicitly expected and explained.

## 3. Allowed files

Allowed new files:

    operations/body_self_inspection/build_body_scan_policy_v1.ps1
    operations/body_self_inspection/build_body_repo_inventory_v1.ps1
    operations/body_self_inspection/invoke_body_self_inspection_slice_a_v1.ps1
    validators/validate_body_self_inspection_slice_a_v1.ps1
    tests/self_development/BODY_SELF_INSPECTION_SLICE_A_V1_PROOF.json

Allowed runtime outputs:

    .runtime/body_self_inspection_v1/scan_policy_effective.json
    .runtime/body_self_inspection_v1/scan_skipped_surfaces.json
    .runtime/body_self_inspection_v1/repo_inventory.json
    .runtime/body_self_inspection_v1/BODY_SELF_INSPECTION_SLICE_A_PROOF.json

Do not edit the plan file unless a contradiction blocks implementation. If edited, explain why.

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
    implement nervous system
    implement broad repo proof lookup executor
    implement slices B-E

## 5. Required scan policy output

Implement:

    operations/body_self_inspection/build_body_scan_policy_v1.ps1

It must produce/write:

    .runtime/body_self_inspection_v1/scan_policy_effective.json

Required top-level fields:

    schema = body_scan_policy_v1
    status = PASS_BODY_SCAN_POLICY_V1
    scan_policy_version
    generated_at
    repo_root
    denied_dirs
    denied_file_patterns
    allowed_content_roles
    max_content_read_bytes
    runtime_read_policy
    protected_surfaces
    git_command_allowlist
    git_command_denylist
    stale_after
    boundary

Initial max_content_read_bytes:

    262144

Hard denied dirs/patterns must include at least:

    .git
    node_modules
    .venv
    env
    __pycache__
    .pytest_cache
    .mypy_cache
    dist
    build
    cache
    tmp
    temp
    large archives
    generated streaming chunks
    old raw school run bodies
    stale raw runtime chunks

Runtime read policy:

    read manifests/latest summaries/selected proof refs only
    do not bulk-read raw runtime chunks

Git allowlist must be observe-only:

    git status
    git rev-parse
    git rev-list
    git log

Git denylist must include:

    git add
    git commit
    git push
    git clean
    git checkout
    git reset

Implementation scripts must not run denied git commands.

## 6. Required repo inventory output

Implement:

    operations/body_self_inspection/build_body_repo_inventory_v1.ps1

It must be metadata-first. No full repo text dump.

It must write:

    .runtime/body_self_inspection_v1/repo_inventory.json
    .runtime/body_self_inspection_v1/scan_skipped_surfaces.json

repo_inventory.json required top-level fields:

    schema
    status
    scan_started_at
    scan_finished_at
    repo_root
    repo_head
    branch
    scan_policy_ref
    root_markers
    records
    aggregates
    stale_after
    boundary
    errors

PASS status:

    PASS_BODY_REPO_INVENTORY_V1

Each record must include:

    path
    normalized_path
    kind
    extension
    size_bytes
    mtime_utc
    depth
    parent_dir
    scan_status
    skipped_reason
    role_guess
    confidence
    evidence
    content_read_status
    content_summary_ref
    risk_flags

Allowed role_guess values include:

    UNKNOWN
    MAP_FILE
    CAPABILITY_MAP_FILE
    ORGAN_REGISTRY_FILE
    ORGAN_CANDIDATE_SCRIPT
    ORGAN_CONTRACT_FILE
    ORGAN_PASSPORT_FILE
    AUTHORITY_PASSPORT_FILE
    VALIDATOR_FILE
    PROOF_JSON
    RUNTIME_SUMMARY
    REPAIR_DRAFT_BOARD
    BODY_PAIN_REGISTER
    HANDOFF_POINTER
    PLAN_FILE
    TRANSIENT_RUNTIME
    PROTECTED_SURFACE
    HEAVY_SKIPPED_SURFACE

Required root markers to check:

    CAPABILITY_ROADMAP.json
    GENESIS_STATE.json
    TASK_QUEUE.json
    packs/registry.json
    orchestrator/run.ps1

Root marker absence is recorded; do not invent missing markers.

## 7. Required skipped surfaces output

scan_skipped_surfaces.json must include:

    schema
    status
    generated_at
    skipped_surfaces
    aggregates
    boundary

Each skipped surface:

    path
    reason
    policy_rule
    metadata_seen
    summary_ref_if_any

## 8. Required aggregates

repo_inventory.json aggregates must include:

    total_files_seen
    total_dirs_seen
    files_skipped
    dirs_skipped
    content_files_read
    content_files_metadata_only
    role_counts
    organ_candidate_count
    passport_file_count
    contract_file_count
    validator_file_count
    proof_json_count
    runtime_summary_count
    heavy_skipped_count
    protected_skipped_count

## 9. Required boundary proof

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

## 10. Minimal invoker

Implement:

    operations/body_self_inspection/invoke_body_self_inspection_slice_a_v1.ps1

It must:

    create .runtime/body_self_inspection_v1 if missing
    call build_body_scan_policy_v1.ps1
    call build_body_repo_inventory_v1.ps1
    write .runtime/body_self_inspection_v1/BODY_SELF_INSPECTION_SLICE_A_PROOF.json

Proof status:

    PASS_BODY_SELF_INSPECTION_SLICE_A_RUNTIME_V1

## 11. Validator requirements

Implement:

    validators/validate_body_self_inspection_slice_a_v1.ps1

Validator must run the invoker and verify:

    scan_policy_effective.json exists and parses
    scan_skipped_surfaces.json exists and parses
    repo_inventory.json exists and parses
    BODY_SELF_INSPECTION_SLICE_A_PROOF.json exists and parses
    required root markers checked
    denied dirs appear in policy
    protected/runtime bulk areas are skipped or policy-denied
    records have required fields
    aggregates have required fields
    role_counts exist
    boundary flags are false
    stale_after exists
    no active memory mutation claimed
    no accepted-core mutation claimed
    no live process touched
    no Codex/web launched

Tracked validator proof path:

    tests/self_development/BODY_SELF_INSPECTION_SLICE_A_V1_PROOF.json

PASS status:

    PASS_BODY_SELF_INSPECTION_SLICE_A_V1

Failure statuses:

    FAIL_BODY_SELF_INSPECTION_SLICE_A_V1
    BLOCKED_BODY_SELF_INSPECTION_SLICE_A_V1

## 12. Negative/safety checks

Validator must fail if:

    scan policy omits .git deny
    repo_inventory has no boundary proof
    repo_inventory lacks root marker checks
    skipped surfaces output is missing
    runtime raw chunks are bulk-read
    required output is unparsable JSON
    runtime proof status is not PASS

Do not create huge fixtures. Prefer runtime temp fixtures if needed.

## 13. Commands to run before final report

Run at least:

    powershell -NoProfile -ExecutionPolicy Bypass -File validators/validate_body_self_inspection_slice_a_v1.ps1
    git diff --check
    git status --short --untracked-files=all

Do not commit/push unless explicitly instructed by GPT/operator.

## 14. Expected final report

Final report must include:

    PREFLIGHT_PASS or BLOCKED_PREFLIGHT
    files changed
    files created
    validators run
    proof paths
    skipped surfaces summary
    role counts summary
    boundary proof
    known gaps
    next recommended slice
    Files changed before PREFLIGHT_PASS: YES/NO

## 15. Cut list

Do not implement in Slice A:

    Body / Capability Map Reader Cell
    Organ Candidate Detector Cell beyond role_guess metadata
    Organ Similarity / Duplicate Detector Cell
    Passport / Contract Audit Cell
    Signal Readiness Audit Cell
    Reconciliation Cell
    Body Pain Register
    Repair Draft Board
    Next Logic Queue
    Self-Inspection Signal full schema
    Mind Logic Integration
    Nervous System

## 16. Acceptance boundary

This slice is accepted only if:

    validator PASS
    proof JSON PASS
    outputs parse
    denylist/protected scan proof exists
    role counts exist
    root markers checked
    mutation boundary false
    repo final status contains only intentional tracked changes and allowed runtime outputs are untracked/ignored

No claim that full BODY_SELF_INSPECTION_CIRCUIT_V1 is built.
Only claim Slice A readiness.
