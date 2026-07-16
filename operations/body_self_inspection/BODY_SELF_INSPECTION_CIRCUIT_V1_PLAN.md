# BODY_SELF_INSPECTION_CIRCUIT_V1_PLAN

Status: ACTIVE_BUILD_PLAN / NOT_IMPLEMENTED
Repo: H:/efab
Branch: main
Owner decision: build robust Body Self-Inspection Circuit, not a plain repo proof lookup executor.

## 0. Core decision

This file is the build plan for one large organ/circuit:

    BODY_SELF_INSPECTION_CIRCUIT_V1

It is not a simple repo scanner, not a human report generator, and not a set of disconnected mini-organs.

The output is for the agent's own logic. Owner/GPT may read it, but the primary consumer is the agent.

Core formula:

    BODY_SELF_INSPECTION_CIRCUIT_V1
    = bounded repo inventory
    + body/capability map reading
    + organ discovery
    + organ similarity / duplicate detection
    + passport / contract audit
    + signal readiness audit
    + reconciliation
    + pain register
    + repair draft board
    + next logic queue
    + self-inspection signal

Principles:

    NO PAIN -> NO DRAFT
    NO DRAFT -> NO LOGIC REPAIR
    NO PROOF -> NO ACCEPTANCE
    NO SIGNAL CONTRACT -> NOT FUTURE-NERVOUS-SYSTEM READY
    NO SIMILARITY CHECK -> NO ORGAN PROMOTION
    Repo inventory is not truth.
    Map is not truth.
    Passport is not truth.
    Truth is reconciliation + proof boundary.

## 1. Goal, mode, inputs/outputs, boundary

### 1.1 Organ name

    BODY_SELF_INSPECTION_CIRCUIT_V1

Type:

    large organ / circuit

This is one organism-level self-inspection circuit with internal cells.

### 1.2 Main goal

The circuit must let the agent understand its own body:

    what exists in repo
    what exists in body map
    what exists in capability map
    which organs are recognized
    which organ candidates are forgotten
    which organs/candidates are similar or duplicates
    where passport is missing
    where validator is missing
    where signal contract is missing
    where map lies or is stale
    where proof exists but is not indexed
    where draft exists but is not being read
    what hurts
    what can be repaired at logic level
    what must be remembered for the next cycle

### 1.3 Role in organism

The circuit answers:

    What am I right now?
    Where do I not match myself?
    What hurts?
    What can I reason about next?

It reconciles:

    repo reality
    body map
    capability map
    organ registries
    passport/contracts
    validators
    proof refs
    runtime summaries
    repair drafts
    signal readiness

It produces agent-consumable internal state:

    CURRENT_BODY_REALITY
    BODY_PAIN_REGISTER
    REPAIR_DRAFT_BOARD
    NEXT_LOGIC_QUEUE
    SELF_INSPECTION_SIGNAL

### 1.4 First-stage mode

First stage is read-only over body/repo/live surfaces.

Allowed:

    read repo metadata
    read selected files
    read body/capability maps
    read passports/contracts
    read validators
    read proof refs
    read latest runtime summaries
    read existing repair drafts
    write circuit runtime outputs

Forbidden:

    mutate repo code
    mutate body map directly
    mutate capability map directly
    mutate active memory
    mutate accepted-core
    start or stop live runtime
    launch Codex
    browse web
    cleanup runtime
    wire organ
    rename/delete files
    claim mature organ

### 1.5 Inputs

Primary inputs:

    repo filesystem metadata
    body map files
    capability map files
    organ registries
    passport files
    organ contracts
    validator files
    proof JSON files
    runtime latest summaries
    existing repair drafts
    current route_request_packet

Secondary inputs:

    git status snapshot
    latest commits metadata
    known protected surfaces
    scan policy / denylist

### 1.6 Outputs

Required outputs:

    .runtime/body_self_inspection_v1/current_body_reality.json
    .runtime/body_self_inspection_v1/body_pain_register.jsonl
    .runtime/body_self_inspection_v1/repair_draft_board.jsonl
    .runtime/body_self_inspection_v1/next_logic_queue.json
    .runtime/body_self_inspection_v1/self_inspection_signal.json
    .runtime/body_self_inspection_v1/BODY_SELF_INSPECTION_PROOF.json

Useful intermediate outputs:

    .runtime/body_self_inspection_v1/repo_inventory.json
    .runtime/body_self_inspection_v1/map_reconciliation.json
    .runtime/body_self_inspection_v1/organ_similarity_index.json
    .runtime/body_self_inspection_v1/passport_audit.json
    .runtime/body_self_inspection_v1/signal_readiness_audit.json
    .runtime/body_self_inspection_v1/scan_skipped_surfaces.json

### 1.7 Success definition

Success is not "files created".

Success means:

    next agent cycle can read current_body_reality
    next agent cycle can read open pains
    next agent cycle can read active repair drafts
    next agent cycle can select next_logic_action
    agent does not need full repo reread every time
    agent sees similar/duplicate organs
    agent sees missing passport / validator / signal contract
    agent knows what can be repaired by logic and what is blocked

### 1.8 Non-success patterns

Not success:

    large markdown report only
    raw file list
    full repo dump
    one-off scan
    json without next_logic_queue
    pain without repair draft
    draft without next read path
    map without validator
    organ found but similarity not checked
    passport found but required fields not checked
    signal fields listed but not checked

## 2. Planned sections to expand

### 2. Boundaries, protected surfaces, scan policy, denylist

Purpose: make inspection reliable without turning it into an expensive full repo read or unsafe runtime touch.

This cell defines what the circuit may inspect, what it must skip, and what it may read only through compact summaries.

#### 2.1 Boundary class

The first implementation is:

    READ_ONLY_BODY_INSPECTION

It may create only runtime outputs under:

    .runtime/body_self_inspection_v1/

It must not change tracked source files, active memory, accepted-core, body maps, capability maps, runtime state, or live processes.

#### 2.2 Protected surfaces

Protected surfaces are never mutated by this circuit:

    .runtime/active_compact_semantic_memory_v1
    accepted-core surfaces
    D2B/accepted-core pipeline surfaces
    body map / capability map tracked files
    route locks
    registry files
    validators
    organ contracts
    passports
    runtime runners
    launch scripts
    git metadata
    credentials/secrets/env files

Read permission is not write permission.

#### 2.3 Hard denylist

The inventory must skip these surfaces by default:

    .git
    node_modules
    .venv
    env
    .env folders
    __pycache__
    .pytest_cache
    .mypy_cache
    dist
    build
    cache
    tmp
    temp
    large archives
    binary blobs
    generated streaming chunks
    old raw school run bodies
    stale raw runtime chunks
    browser/cache exports

If a skipped surface has a manifest or latest summary, the circuit may read only that manifest/summary through an allowlist rule.

#### 2.4 Runtime read policy

Runtime is not a normal repo subtree.

Allowed runtime reads:

    latest summary json
    latest proof json selected by manifest
    compact run report
    current body_self_inspection_v1 outputs
    active draft board
    active pain register

Forbidden runtime reads by default:

    full raw streaming chunks
    old run body dumps
    bulk logs
    temporary generated candidates
    large file blobs

The circuit must output scan_skipped_surfaces.json so the agent knows what was intentionally skipped.

#### 2.5 File size and content policy

Inventory stage reads metadata first:

    path
    extension
    size_bytes
    mtime
    directory_role_guess
    file_role_guess
    scan_status

Content read is allowed only for selected file roles:

    body map
    capability map
    organ registry
    passport
    organ contract
    authority passport
    validator header / validator metadata
    proof json summary
    runtime latest summary
    repair draft board
    pain register
    plan / handoff pointer

Large file threshold must be configurable. Initial default:

    max_content_read_bytes = 262144

Files above threshold are metadata-only unless allowlisted.

#### 2.6 Allowlist roles

Allowed content roles:

    MAP_FILE
    CAPABILITY_MAP_FILE
    ORGAN_REGISTRY_FILE
    ORGAN_PASSPORT_FILE
    ORGAN_CONTRACT_FILE
    AUTHORITY_PASSPORT_FILE
    VALIDATOR_FILE_HEADER
    PROOF_JSON_SUMMARY
    RUNTIME_SUMMARY
    REPAIR_DRAFT_BOARD
    BODY_PAIN_REGISTER
    GPT_HANDOFF_POINTER
    PLAN_FILE

No raw full scan is allowed just because a file is text.

#### 2.7 Git snapshot policy

The circuit may record:

    branch
    HEAD short hash
    git status --short
    origin delta
    latest commits metadata

It must not run:

    git add
    git commit
    git push
    git clean
    git checkout
    git reset

#### 2.8 Scan freshness and staleness

Every output must include:

    scan_started_at
    scan_finished_at
    repo_head
    branch
    scan_policy_version
    stale_after

Default stale_after:

    24h for body reality
    1h for active runtime references
    immediate stale if git HEAD changes

#### 2.9 Failure behavior

If scan policy cannot be loaded or protected surface is ambiguous:

    BLOCKED_SCAN_POLICY_UNSAFE

If repo is dirty before inspection:

    DIRTY_REPO_OBSERVED

Dirty repo does not automatically block read-only inspection, but it must be recorded in proof and next logic queue.

If active runtime is detected:

    ACTIVE_RUNTIME_OBSERVED

The circuit may continue read-only summary inspection, but must not touch runtime surfaces beyond allowlisted summaries.

#### 2.10 Required output from this section

    .runtime/body_self_inspection_v1/scan_policy_effective.json
    .runtime/body_self_inspection_v1/scan_skipped_surfaces.json

scan_policy_effective.json must include:

    denied_dirs
    denied_file_patterns
    allowed_content_roles
    max_content_read_bytes
    runtime_read_policy
    protected_surfaces
    git_command_allowlist
    git_command_denylist

scan_skipped_surfaces.json must include:

    path
    reason
    policy_rule
    metadata_seen
    summary_ref_if_any

### 3. Repo Inventory Cell

Purpose: produce a bounded, role-aware inventory of repo reality without promoting files to organs and without reading everything.

Output:

    .runtime/body_self_inspection_v1/repo_inventory.json

#### 3.1 Input

Inputs:

    repo root
    effective scan policy
    git snapshot
    optional route_request_packet context

The cell must not depend on internet, Codex, live runtime, or Owner intervention.

#### 3.2 Inventory record schema

Each file/directory record should include:

    path
    normalized_path
    kind = file | directory
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

role_guess values:

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

#### 3.3 Organ candidate signals

A file may be an organ candidate if it matches one or more:

    operations/<name>/...runner or orchestrator script
    operations/<name>/organ_contract.json
    operations/<name>/execution_authority_passport*.json
    modules/invoke_*.ps1
    orchestrator/*.ps1
    validators/validate_*_organ*.ps1
    contracts/**/ORGAN_PASSPORT.json
    scripts that produce proof json
    scripts that manage memory, maps, body, runtime, proof, school, or route

Candidate detection is weak evidence only:

    ORGAN_CANDIDATE != ORGAN

#### 3.4 Content summary for selected files

For selected allowed roles, the inventory may write a compact content summary, not a full copy.

Summary fields:

    schema_if_json
    status_if_present
    role_if_present
    declared_organ_id
    declared_capability_ids
    declared_validator_refs
    declared_signal_refs
    declared_proof_refs
    top_level_keys
    parse_status
    parse_errors

#### 3.5 Inventory aggregates

repo_inventory.json must include aggregates:

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

#### 3.6 Required safety proof

repo_inventory.json must include boundary proof:

    repo_mutated = false
    active_memory_mutated = false
    accepted_core_mutated = false
    live_process_touched = false
    codex_launched = false
    web_launched = false
    cleanup_performed = false

#### 3.7 Failure behavior

If a file cannot be read:

    record scan_status = READ_FAILED
    record error class
    continue unless it is a required root marker

If root markers are missing:

    record ROOT_MARKER_MISSING pain candidate
    do not invent marker

Required root markers to check:

    CAPABILITY_ROADMAP.json
    GENESIS_STATE.json
    TASK_QUEUE.json
    packs/registry.json
    orchestrator/run.ps1

#### 3.8 Non-success patterns

Not acceptable:

    raw full repo file dump
    recursive runtime dump
    treating file name match as organ proof
    ignoring skipped surfaces
    no role counts
    no boundary proof
    no stale_after
    inventory without scan policy ref
### 4. Body / Capability Map Reader Cell

Read existing maps, registries, capability surfaces, known invocation paths and proof refs.

### 5. Organ Candidate Detector Cell

Detect organ candidates from repo surfaces without promoting them to organs.

### 6. Organ Similarity / Duplicate Detector Cell

Compare organ candidates and known organs.

Must detect:

    UNIQUE_ORGAN_CANDIDATE
    POSSIBLE_DUPLICATE
    FUNCTIONAL_OVERLAP
    OLDER_VERSION_CANDIDATE
    SHADOW_ORGAN
    WRAPPER_AROUND_EXISTING_ORGAN
    MERGE_CANDIDATE
    CONFLICTING_ORGAN
    UNKNOWN_SIMILARITY

Comparison dimensions:

    same capability_id
    same purpose
    same input/output shape
    same touched state
    same validator target
    same proof type
    same invocation path
    same file family
    same naming pattern
    same parent task

### 7. Passport / Contract Audit Cell

Use existing passport/contract surfaces, not invented replacements:

    contracts/accepted_atom_retention_organ/passports/ORGAN_PASSPORT.json
    contracts/accepted_atom_retention_organ/passports/PASSPORT_INDEX.json
    contracts/accepted_atom_retention_organ/passports/CAPABILITY_PASSPORT.json
    operations/autonomous_inner_motor/organ_contract.json
    operations/autonomous_inner_motor/execution_authority_passport_v1.json
    validators/validate_accepted_atom_retention_passports_v1.ps1
    validators/validate_autonomous_inner_motor_organ_contract.ps1

Must detect:

    organ_missing_passport
    passport_missing_required_field
    organ_contract_missing
    authority_passport_missing
    validator_contract_missing

### 8. Signal Readiness Audit Cell

Prepare future nervous-system compatibility now.

For every organ/cell candidate include:

    signal_contract_status
    expected_signals_emitted
    expected_signals_consumed
    signal_schema_ref
    signal_validator_ref
    signal_emission_proof_ref

Statuses:

    NATIVE_SIGNAL_EMITTER
    LEGACY_SIGNAL_ADAPTED
    SIGNAL_MISSING
    SIGNAL_UNKNOWN
    SIGNAL_CONTRACT_WITHOUT_VALIDATOR

Signals may be emitted into a placeholder/void now, but contract visibility is required for future nervous-system consumption.

### 9. Reconciliation Cell

Compare repo inventory, maps, capability map, passport index, contracts, validators, proof refs, draft board, runtime summaries.

Detect mismatches and body pains.

### 10. Body Pain Register

Output:

    .runtime/body_self_inspection_v1/body_pain_register.jsonl

Pain records must include:

    pain_id
    pain_type
    symptom
    affected_surface
    evidence_refs
    why_it_matters
    severity
    repairability
    blocked_by
    status
    first_seen
    last_seen

If pain repeats, update existing pain instead of duplicating.

### 11. Repair Draft Board

Output:

    .runtime/body_self_inspection_v1/repair_draft_board.jsonl

Draft records must include:

    draft_id
    from_pain_id
    hypothesis
    proposed_logic_repair
    required_proof
    required_validator
    allowed_now
    forbidden_now
    status
    next_read_required

Statuses:

    ACTIVE_DRAFT
    EVIDENCE_LINKED
    READY_FOR_PROBE
    BLOCKED
    STALE
    SUPERSEDED
    CLOSED

### 12. Next Logic Queue

Output:

    .runtime/body_self_inspection_v1/next_logic_queue.json

Select what the agent should reason about next, not what Owner should manually inspect.

### 13. Self-Inspection Signal

Output:

    .runtime/body_self_inspection_v1/self_inspection_signal.json

Compact signal for future nervous system:

    signal_type = BODY_SELF_INSPECTION_COMPLETED
    pain_count
    critical_pain_count
    new_drafts_count
    next_logic_action
    proof_ref
    stale_after

### 14. Validator Layer

Validator must check quality, not only file existence:

    heavy folders skipped
    maps read
    passport refs checked
    signal fields checked
    similarity checked
    repo/map mismatches detected
    pain register updated
    repair draft board updated
    next logic queue produced
    self-inspection signal produced
    next cycle can read drafts
    no repo mutation
    no active memory mutation
    no accepted-core mutation
    no Codex/web

### 15. Integration with Mind Logic

After route_request_packet:

    body_self_inspection
    -> check maps/drafts/pains
    -> if internal answer exists, use it
    -> if body gap exists, create logic draft
    -> only then fallback to repo proof lookup

### 16. Codex Implementation Pack

Codex gets implementation only after GPT/operator writes strict pack:

    files in/out
    schemas
    denylist
    existing passport refs
    signal fields
    validators
    proof expectations
    cut list
    PREFLIGHT_PASS before writes

Codex does not decide architecture.
