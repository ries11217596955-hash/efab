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

Purpose: read the organism's declared self-map and capability surfaces before falling back to repo-level proof search.

This cell does not decide truth alone. It reads what the body claims about itself and passes those claims into reconciliation.

Output:

    .runtime/body_self_inspection_v1/body_map_read.json
    .runtime/body_self_inspection_v1/capability_map_read.json

#### 4.1 Required map surfaces to look for

The reader must search for known root markers and map-like surfaces:

    CAPABILITY_ROADMAP.json
    GENESIS_STATE.json
    TASK_QUEUE.json
    packs/registry.json
    orchestrator/run.ps1
    operations/gpt_handoff/NEXT_CHAT_HANDOFF_20260716_MIND_LOGIC_STATUS.json
    operations/gpt_handoff/NEXT_CHAT_HANDOFF_20260716_MIND_LOGIC.md

It must also look for files whose path/name suggests:

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

#### 4.2 Map record schema

Each map-like surface should become a record:

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

map_type values:

    BODY_MAP
    CAPABILITY_MAP
    ORGAN_REGISTRY
    INVOCATION_MAP
    LAUNCH_MAP
    PASSPORT_INDEX
    VALIDATOR_INDEX
    PROOF_INDEX
    SIGNAL_INDEX
    HANDOFF_STATUS_POINTER
    UNKNOWN_MAP_LIKE

#### 4.3 Declared organ schema

When a map declares an organ, capture:

    declared_organ_id
    name
    source_map_ref
    implementation_refs
    contract_refs
    passport_refs
    validator_refs
    proof_refs
    capabilities
    invocation_paths
    state_touched
    authority_refs
    signal_refs
    lifecycle_status
    evidence_status

Important boundary:

    DECLARED_ORGAN != PRESENT_ORGAN
    DECLARED_ORGAN != VALID_ORGAN
    DECLARED_ORGAN != MATURE_ORGAN

The reconciliation cell must verify declarations against repo inventory and proof refs.

#### 4.4 Declared capability schema

When a map declares a capability, capture:

    capability_id
    name
    source_map_ref
    owning_organ_refs
    invocation_refs
    validator_refs
    proof_refs
    input_contract
    output_contract
    state_touched
    maturity_status
    evidence_status

Important boundary:

    DECLARED_CAPABILITY != USABLE_CAPABILITY
    CAPABILITY_WITHOUT_INVOCATION is a pain candidate.
    CAPABILITY_WITHOUT_VALIDATOR is a pain candidate.
    CAPABILITY_WITHOUT_PROOF is a pain candidate.

#### 4.5 Map freshness and conflict handling

Every map read must be labeled:

    FRESH_ENOUGH
    STALE_BY_TIME
    STALE_BY_HEAD_CHANGE
    PARSE_FAILED
    MISSING
    CONFLICTING_WITH_OTHER_MAP
    UNKNOWN_FRESHNESS

If two maps disagree, do not choose silently.

Record conflict candidate:

    map_conflict

with:

    map_a
    map_b
    conflicting_field
    value_a
    value_b
    required_resolution

#### 4.6 Output aggregates

body_map_read.json and capability_map_read.json must include:

    maps_seen
    maps_parsed
    maps_failed
    declared_organs_count
    declared_capabilities_count
    declared_validators_count
    declared_invocation_paths_count
    declared_proof_refs_count
    stale_maps_count
    conflict_count
    missing_root_markers

#### 4.7 Non-success patterns

Not acceptable:

    treating map declaration as proof
    ignoring stale maps
    ignoring conflicting declarations
    losing proof refs
    losing invocation refs
    no evidence_status labels
    no parse errors
    no missing root marker records

### 5. Organ Candidate Detector Cell

Purpose: detect possible organs and organ-adjacent surfaces in repo inventory without promoting them.

Output:

    .runtime/body_self_inspection_v1/organ_candidates.json

#### 5.1 Candidate definition

An organ candidate is a repo surface that may represent a reusable capability, controller, runner, validator set, memory tool, map tool, proof tool, or governed subsystem.

Boundary:

    ORGAN_CANDIDATE != ORGAN
    SCRIPT != ORGAN
    VALIDATOR != ORGAN
    PASSPORT != ORGAN
    PROOF PRODUCER != ORGAN

Promotion is impossible here. This cell only detects candidates.

#### 5.2 Candidate sources

Candidate patterns:

    operations/<name>/**
    modules/invoke_*.ps1
    orchestrator/*.ps1
    validators/validate_*_organ*.ps1
    validators/validate_*_wiring*.ps1
    contracts/**/ORGAN_PASSPORT.json
    contracts/**/CAPABILITY_PASSPORT.json
    **/organ_contract.json
    **/execution_authority_passport*.json
    scripts that produce *_PROOF.json
    scripts that read/write maps
    scripts that manage active memory
    scripts that manage runtime/school/inner motor
    scripts that emit or validate signals

#### 5.3 Candidate record schema

Each candidate must include:

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

candidate_type values:

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

#### 5.4 Candidate grouping

The detector should group related files into candidate families.

Family grouping hints:

    same directory root
    same normalized name stem
    same capability words
    same validator target
    same proof file prefix
    same contract organ_id
    same passport organ_id
    same invocation script reference

Example family:

    operations/autonomous_inner_motor/run_autonomous_inner_motor.ps1
    operations/autonomous_inner_motor/organ_contract.json
    operations/autonomous_inner_motor/execution_authority_passport_v1.json
    validators/validate_autonomous_inner_motor_*.ps1
    tests/self_development/AUTONOMOUS_INNER_MOTOR_*_PROOF.json

#### 5.5 Evidence strength

Candidate confidence values:

    HIGH_CONTRACT_BACKED
    MEDIUM_VALIDATOR_BACKED
    MEDIUM_MAP_DECLARED
    LOW_NAME_PATTERN_ONLY
    LOW_DIRECTORY_PATTERN_ONLY
    UNKNOWN

A candidate discovered only by name must not be used as proof.

#### 5.6 Required pain candidates from this cell

The detector may emit pain candidates:

    repo_candidate_unmapped
    candidate_has_validator_but_no_contract
    candidate_has_contract_but_no_map_entry
    candidate_has_proof_but_no_map_entry
    candidate_family_split_across_dirs
    unknown_body_surface_needs_classification

These are not final pains until reconciliation confirms them.

#### 5.7 Non-success patterns

Not acceptable:

    every script becomes organ candidate
    every folder becomes organ candidate
    candidate promoted to organ
    no grouping
    no confidence
    no evidence refs
    no relation to maps/contracts/validators/proofs

### 6. Organ Similarity / Duplicate Detector Cell

Purpose: prevent body bloat by comparing organ candidates to known organs and to each other before any future promotion or wiring.

Output:

    .runtime/body_self_inspection_v1/organ_similarity_index.json

#### 6.1 Comparison targets

Compare:

    repo organ candidates vs map-declared organs
    repo organ candidates vs repo organ candidates
    map-declared organs vs map-declared organs
    candidate families vs validator clusters
    candidate families vs proof producers
    capability declarations vs candidate capabilities

#### 6.2 Similarity dimensions

Similarity features:

    same capability_id
    same normalized name stem
    same purpose words
    same input contract shape
    same output contract shape
    same touched state
    same authority surface
    same validator target
    same proof type
    same invocation path
    same file family
    same parent task or handoff route
    same signal schema ref
    same passport organ_id
    same contract organ_id

#### 6.3 Similarity status values

Each pair or cluster must be assigned one:

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

#### 6.4 Similarity record schema

Each record:

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

recommended_logic_action examples:

    compare_contracts
    compare_validators
    check_if_wrapper
    create_merge_draft
    create_quarantine_draft
    create_map_cleanup_draft
    mark_unique_candidate
    ask_owner_if_intent_unknown

forbidden_now examples:

    promote either candidate
    delete duplicate
    merge files
    rewrite map
    claim replacement

#### 6.5 Duplicate pain candidates

Similarity cell may emit pain candidates:

    possible_duplicate_organ
    functional_overlap_without_decision
    shadow_organ_unmapped
    old_version_not_quarantined
    wrapper_without_contract
    conflicting_organ_claims_same_capability

These must go through reconciliation before entering BODY_PAIN_REGISTER.

#### 6.6 Similarity scoring boundary

Similarity score is a heuristic, not proof.

Allowed labels:

    SIMILARITY_HEURISTIC
    CONTRACT_SUPPORTED_SIMILARITY
    VALIDATOR_SUPPORTED_SIMILARITY
    MAP_SUPPORTED_SIMILARITY

Forbidden:

    duplicate proven solely by filename
    replacement proven without validator/proof
    automatic deletion or merge

#### 6.7 Non-success patterns

Not acceptable:

    no duplicate check
    only exact filename matching
    no feature list
    no conflict list
    no recommended logic action
    duplicate detection that mutates repo
    duplicate detection that rewrites map directly
### 7. Passport / Contract Audit Cell

Purpose: enforce the rule that a candidate is not a real organ unless its passport/contract surfaces exist, parse, and satisfy the required fields.

Output:

    .runtime/body_self_inspection_v1/passport_audit.json

This cell must use existing repo passport/contract surfaces. It must not invent a new passport law unless the reconciliation later creates a draft requirement.

#### 7.1 Existing passport and contract refs

Known required surfaces to read/check when present:

    contracts/accepted_atom_retention_organ/passports/ORGAN_PASSPORT.json
    contracts/accepted_atom_retention_organ/passports/PASSPORT_INDEX.json
    contracts/accepted_atom_retention_organ/passports/CAPABILITY_PASSPORT.json
    operations/autonomous_inner_motor/organ_contract.json
    operations/autonomous_inner_motor/execution_authority_passport_v1.json
    validators/validate_accepted_atom_retention_passports_v1.ps1
    validators/validate_autonomous_inner_motor_organ_contract.ps1

The audit must record these as law/reference surfaces, not as proof that all organs comply.

#### 7.2 Passport audit target set

Audit targets come from:

    map-declared organs
    repo organ candidates
    candidate families
    organ_contract files
    authority passport files
    capability passport files
    validator clusters claiming organ validation
    known active organs from body/capability maps

Every target must receive one passport_status.

#### 7.3 Passport status values

Allowed passport_status:

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

#### 7.4 Required passport fields to check

The exact required fields should be loaded from the existing passport schema/contract if available.

Minimum fields to check for every organ/passport-like record:

    organ_id
    organ_name
    organ_type
    purpose
    capabilities
    input_contract
    output_contract
    state_touched
    authority
    invocation_contract
    validator_refs
    proof_refs
    maturity_status
    owner_or_parent_ref
    rollback_or_quarantine_rule
    last_validated_at or evidence timestamp

If field names differ in existing repo schema, the audit must map to canonical concepts and record mapping_source.

#### 7.5 Contract audit fields

For organ_contract-like files check:

    organ_id
    contract_schema
    mode
    allowed_inputs
    allowed_outputs
    forbidden_actions
    state_boundaries
    memory_boundaries
    live_boundaries
    validator_contract
    proof_expectations
    failure_modes
    quarantine_rule

#### 7.6 Authority passport audit fields

For authority passport-like files check:

    organ_id
    authority_scope
    allowed_actions
    forbidden_actions
    state_mutation_authority
    live_runtime_authority
    repo_mutation_authority
    memory_mutation_authority
    codex_authority
    web_authority
    validator_required
    proof_required
    rollback_required

If authority is ambiguous, emit pain candidate:

    authority_scope_ambiguous

#### 7.7 Validator relationship check

For every organ/candidate with passport or contract, check whether validator refs exist and whether validators are wired to the same organ/capability.

Statuses:

    VALIDATOR_PRESENT_AND_REFERENCED
    VALIDATOR_PRESENT_NOT_REFERENCED
    VALIDATOR_REFERENCED_MISSING
    VALIDATOR_TARGET_MISMATCH
    VALIDATOR_CLUSTER_FOUND_NO_CONTRACT
    VALIDATOR_MISSING
    VALIDATOR_UNKNOWN

#### 7.8 Proof relationship check

For every passport/contract, check proof refs:

    proof_ref_present
    proof_ref_path_exists
    proof_ref_parse_status
    proof_status_if_present
    proof_head_or_timestamp
    proof_matches_organ_id
    proof_matches_validator

Statuses:

    PROOF_REF_VALID
    PROOF_REF_BROKEN
    PROOF_REF_PARSE_FAILED
    PROOF_REF_TARGET_MISMATCH
    PROOF_REF_MISSING
    PROOF_STALE
    PROOF_UNKNOWN

#### 7.9 Passport pain candidates

This cell may emit pain candidates:

    organ_missing_passport
    passport_missing_required_field
    passport_parse_failed
    passport_schema_unknown
    organ_contract_missing
    organ_contract_parse_failed
    authority_passport_missing
    authority_scope_ambiguous
    capability_passport_missing
    validator_referenced_missing
    validator_target_mismatch
    proof_ref_broken
    proof_ref_target_mismatch
    proof_stale

These become final body pains only after reconciliation confirms them.

#### 7.10 Passport audit record schema

Each audited target:

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

recommended_logic_action examples:

    create_passport_requirement_draft
    create_contract_requirement_draft
    create_validator_requirement_draft
    compare_existing_passport_schema
    quarantine_candidate_until_passport
    mark_not_organ_candidate

forbidden_now examples:

    claim organ mature
    wire organ
    mutate body map
    auto-create passport without proof
    delete candidate

#### 7.11 Non-success patterns

Not acceptable:

    only checking file existence
    treating passport presence as maturity
    ignoring authority passport
    ignoring validator refs
    ignoring proof refs
    ignoring parse failures
    not using existing passport surfaces
    creating new passport law silently
    no pain candidates for missing passport

### 8. Signal Readiness Audit Cell

Purpose: make organs/candidates future-compatible with the nervous system before the nervous system exists.

Output:

    .runtime/body_self_inspection_v1/signal_readiness_audit.json

This cell does not require a complete nervous system. It checks whether an organ/candidate has a visible contract for emitting/consuming signals and whether that contract has proof or validator support.

#### 8.1 Signal readiness fields

Every organ/cell candidate and every map-declared organ should receive:

    signal_contract_status
    expected_signals_emitted
    expected_signals_consumed
    signal_schema_ref
    signal_validator_ref
    signal_emission_proof_ref
    signal_sink_status
    signal_adapter_status
    nervous_system_dependency_status

#### 8.2 Signal contract status values

Allowed signal_contract_status:

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
    EMITS_TO_PLACEHOLDER is allowed for now, but must be explicit.

#### 8.3 Expected signal envelope concepts

The future common language should be compatible with this minimum envelope:

    signal_id
    signal_schema_version
    emitted_at
    emitter_organ_id
    emitter_cell_id
    capability_id
    event_type
    status
    evidence_status
    proof_ref
    state_touched
    authority_used
    risk_flags
    next_route
    parent_task_ref
    stale_after

This cell should not enforce final nervous-system schema yet, but it must record whether the candidate can map to these concepts.

#### 8.4 Signal source discovery

Look for signal readiness in:

    organ passports
    organ contracts
    authority passports
    validators with signal contract names
    operations/*signal* files
    proof JSON containing signal fields
    body/capability maps with signal refs
    runtime summaries with signal-like outputs
    existing live-like or promotion lane signal validators

Known signal-adjacent validators/scripts should be recorded when found.

#### 8.5 Placeholder/void emission policy

Until a nervous system exists, an organ may emit to a placeholder/void if:

    signal schema ref exists or is declared as provisional
    emission output path is bounded
    validator checks emission shape
    no active memory mutation occurs
    no body map mutation occurs
    no live action is triggered by signal

Status:

    SIGNAL_EMITS_TO_PLACEHOLDER

This is better than no signal contract, but not equal to nervous-system integration.

#### 8.6 Native vs adapter status

A candidate can be:

    NATIVE_SIGNAL_EMITTER
    LEGACY_SIGNAL_ADAPTED
    SIGNAL_MISSING
    SIGNAL_UNKNOWN

NATIVE_SIGNAL_EMITTER:

    organ itself emits standard/provisional signal
    validator checks signal output
    proof ref exists

LEGACY_SIGNAL_ADAPTED:

    old proof/validator output can be converted into signal by adapter
    adapter ref exists or is required as draft
    native emission missing

SIGNAL_MISSING:

    no contract, no adapter, no proof

SIGNAL_UNKNOWN:

    insufficient evidence due to skipped/failed parse or ambiguous surface

#### 8.7 Signal pain candidates

This cell may emit pain candidates:

    organ_missing_signal_contract
    signal_contract_without_validator
    signal_validator_without_contract
    signal_schema_ref_broken
    signal_emission_proof_missing
    signal_emission_proof_broken
    signal_adapter_needed_for_legacy_organ
    signal_sink_missing_future_dependency
    signal_fields_ambiguous

These become final pains only after reconciliation.

#### 8.8 Signal audit record schema

Each target:

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

recommended_logic_action examples:

    create_signal_contract_requirement_draft
    create_signal_validator_requirement_draft
    create_legacy_signal_adapter_draft
    mark_signal_not_required_for_non_organ
    wait_for_nervous_system_layer

forbidden_now examples:

    claim nervous system connected
    mutate organ to emit signal
    mutate active memory
    wire signal consumer
    launch live action from signal

#### 8.9 Non-success patterns

Not acceptable:

    no signal fields on candidates
    treating placeholder emission as nervous system
    requiring full nervous system before recording readiness
    claiming signal readiness without validator/proof
    ignoring legacy adapter path
    ignoring signal refs in existing validators
    losing signal pain candidates
### 9. Reconciliation Cell

Purpose: convert many partial truths into one bounded body reality diagnosis for the agent.

This is the central cell. It decides which differences are real body pains, which are only weak candidates, which are stale, and which require more proof.

Output:

    .runtime/body_self_inspection_v1/map_reconciliation.json
    .runtime/body_self_inspection_v1/current_body_reality.json

#### 9.1 Reconciliation inputs

The cell must read outputs from previous cells:

    scan_policy_effective.json
    scan_skipped_surfaces.json
    repo_inventory.json
    body_map_read.json
    capability_map_read.json
    organ_candidates.json
    organ_similarity_index.json
    passport_audit.json
    signal_readiness_audit.json

It must also read existing circuit memory if present:

    body_pain_register.jsonl
    repair_draft_board.jsonl
    next_logic_queue.json
    self_inspection_signal.json

This lets the agent distinguish new pain from old pain.

#### 9.2 Truth model

No single input is final truth.

Labels:

    REPO_OBSERVED
    MAP_DECLARED
    CAPABILITY_DECLARED
    PASSPORT_DECLARED
    CONTRACT_DECLARED
    VALIDATOR_DECLARED
    PROOF_DECLARED
    PROOF_VALIDATED
    RUNTIME_OBSERVED
    DRAFT_OBSERVED
    SIGNAL_DECLARED
    SIGNAL_VALIDATED
    HEURISTIC_ONLY
    CONFLICTING_EVIDENCE
    UNKNOWN

Reconciliation must produce:

    evidence_status
    confidence
    proof_boundary
    remaining_unknowns

#### 9.3 Body reality object

current_body_reality.json must include:

    schema
    status
    scan_started_at
    scan_finished_at
    repo_head
    branch
    source_refs
    organs
    organ_candidates
    capabilities
    maps
    validators
    passports
    signal_readiness
    proofs
    drafts
    pains_summary
    contradictions
    skipped_surfaces
    next_logic_ref
    stale_after
    boundary

#### 9.4 Organ reality classification

Every declared organ/candidate should be classified as one:

    ACTIVE_MATURE_ORGAN
    ACTIVE_LIMITED_ORGAN
    MAP_DECLARED_ORGAN_UNVERIFIED
    REPO_CANDIDATE_UNMAPPED
    PASSPORTED_BUT_UNWIRED
    CONTRACTED_BUT_UNMAPPED
    VALIDATOR_CLUSTER_WITHOUT_ORGAN
    PROOF_PRODUCER_WITHOUT_MAP_ENTRY
    SHADOW_ORGAN
    POSSIBLE_DUPLICATE_ORGAN
    LEGACY_ORGAN_ADAPTED
    NON_ORGAN_SUPPORT_TOOL
    QUARANTINE_CANDIDATE
    UNKNOWN_BODY_SURFACE

Boundary:

    ACTIVE_MATURE_ORGAN requires map/contract/passport/validator/proof evidence.
    REPO_CANDIDATE_UNMAPPED is not a failure by itself, but can create pain if it looks reusable or has proofs/contracts.

#### 9.5 Capability reality classification

Every capability-like item should be classified as one:

    USABLE_CAPABILITY
    DECLARED_CAPABILITY_UNVERIFIED
    CAPABILITY_WITHOUT_INVOCATION
    CAPABILITY_WITHOUT_VALIDATOR
    CAPABILITY_WITHOUT_PROOF
    CAPABILITY_WITH_DUPLICATE_ORGANS
    CAPABILITY_ORPHANED
    CAPABILITY_CONFLICTING_CLAIMS
    CAPABILITY_UNKNOWN

#### 9.6 Contradiction types

The cell must detect contradictions:

    map_declares_file_missing
    repo_candidate_unmapped
    map_declares_organ_but_passport_missing
    passport_exists_but_map_missing
    contract_exists_but_passport_missing
    validator_exists_but_target_missing
    validator_ref_missing
    validator_target_mismatch
    proof_ref_broken
    proof_target_mismatch
    proof_stale
    capability_declared_without_invocation
    capability_declared_without_validator
    duplicate_candidates_same_capability
    signal_contract_missing_for_organ
    signal_validator_without_contract
    draft_references_missing_pain
    draft_references_missing_surface
    runtime_summary_unindexed
    skipped_surface_may_hide_body_part

#### 9.7 Pain promotion rules

A pain candidate becomes an open pain only if:

    evidence_refs are present
    pain_type is allowed
    affected_surface is known or UNKNOWN_SURFACE explicitly labeled
    why_it_matters is non-empty
    repairability is classified
    forbidden_now is listed

Pain candidate must stay CANDIDATE_ONLY if:

    source is filename heuristic only
    required surface was skipped
    map parse failed before comparison
    evidence contradicts itself
    affected target is non-organ support tool and impact is unknown

#### 9.8 Repairability classification

Every promoted pain must be classified:

    LOGIC_LEVEL_REPAIR_CANDIDATE
    REQUIREMENT_DRAFT_ONLY
    VALIDATOR_REQUIREMENT_NEEDED
    MAP_ENTRY_DRAFT_NEEDED
    PASSPORT_REQUIREMENT_NEEDED
    SIGNAL_CONTRACT_DRAFT_NEEDED
    OWNER_DECISION_REQUIRED
    CODEX_IMPLEMENTATION_REQUIRED_LATER
    BLOCKED_BY_MISSING_PROOF
    BLOCKED_BY_UNSAFE_SURFACE
    NOT_REPAIRABLE_BY_AGENT_NOW

This controls what the agent may do next.

#### 9.9 Recommended next logic action

For every promoted pain, propose one next_logic_action:

    create_passport_requirement_draft
    create_contract_requirement_draft
    create_validator_requirement_draft
    create_signal_contract_requirement_draft
    create_map_entry_candidate_draft
    create_duplicate_resolution_draft
    create_quarantine_candidate_draft
    request_more_proof
    read_specific_map
    read_specific_passport
    read_specific_validator
    compare_contracts
    compare_proofs
    mark_support_tool_non_organ
    ask_owner_decision
    no_action_monitor_only

The next logic selector will later pick priority from these.

#### 9.10 Draft interaction

Reconciliation must compare new pains with existing drafts.

Draft relation values:

    NO_DRAFT
    ACTIVE_DRAFT_EXISTS
    DRAFT_STALE
    DRAFT_SUPERSEDED
    DRAFT_TARGET_MISSING
    DRAFT_READY_FOR_PROBE
    DRAFT_BLOCKED
    DRAFT_CLOSED_BUT_PAIN_REOPENED

If pain already has an active draft, do not create duplicate draft. Update relation and last_seen.

#### 9.11 Severity rules

Severity values:

    CRITICAL
    HIGH
    MEDIUM
    LOW
    INFO

Initial severity guidance:

    CRITICAL = accepted/live/protected surface mismatch or active map points to missing unsafe target
    HIGH = organ declared active but missing passport/validator/proof
    MEDIUM = strong repo candidate unmapped or duplicate with same capability
    LOW = weak candidate, stale proof, missing optional signal readiness
    INFO = non-organ support tool or monitor-only observation

#### 9.12 Current body reality summaries

current_body_reality.json must include summaries for agent use:

    total_declared_organs
    total_repo_candidates
    total_active_mature_organs
    total_active_limited_organs
    total_unmapped_candidates
    total_missing_passports
    total_missing_validators
    total_missing_signal_contracts
    total_possible_duplicates
    total_open_pains
    total_active_drafts
    highest_severity
    next_logic_available

#### 9.13 Boundary proof

map_reconciliation.json and current_body_reality.json must include:

    repo_mutated = false
    active_memory_mutated = false
    accepted_core_mutated = false
    body_map_mutated = false
    capability_map_mutated = false
    live_process_touched = false
    codex_launched = false
    web_launched = false
    cleanup_performed = false

#### 9.14 Failure behavior

If required previous cell output is missing:

    BLOCKED_RECONCILIATION_INPUT_MISSING

If previous cell output is parse-failed:

    PARTIAL_RECONCILIATION_WITH_PARSE_ERRORS

If contradictions cannot be resolved:

    RECONCILIATION_CONFLICT_UNRESOLVED

If only weak heuristics exist:

    RECONCILIATION_HEURISTIC_ONLY_NO_PAIN_PROMOTION

#### 9.15 Non-success patterns

Not acceptable:

    treating repo as truth
    treating map as truth
    treating passport as truth
    turning weak filename matches into pains
    creating duplicate pains every run
    creating duplicate drafts every run
    no repairability classification
    no next_logic_action
    no boundary proof
    no stale_after
    no contradiction records
    no skipped-surface awareness
### 10. Body Pain Register

Purpose: preserve body pains as agent-readable working state across cycles, without duplicating the same pain every run.

Output:

    .runtime/body_self_inspection_v1/body_pain_register.jsonl

This is not a human report. It is the agent's open-pain memory for body self-repair logic.

#### 10.1 Pain lifecycle

Allowed pain statuses:

    OPEN
    ACTIVE_DRAFT_LINKED
    EVIDENCE_LINKED
    READY_FOR_LOGIC_REPAIR
    BLOCKED_BY_MISSING_PROOF
    BLOCKED_BY_OWNER_DECISION
    BLOCKED_BY_UNSAFE_SURFACE
    MONITOR_ONLY
    STALE
    SUPERSEDED
    CLOSED
    REOPENED
    QUARANTINED

Status transition rules:

    new confirmed pain -> OPEN
    OPEN + active draft -> ACTIVE_DRAFT_LINKED
    OPEN + required proof found -> EVIDENCE_LINKED
    EVIDENCE_LINKED + safe repair route -> READY_FOR_LOGIC_REPAIR
    insufficient proof -> BLOCKED_BY_MISSING_PROOF
    unsafe/protected target -> BLOCKED_BY_UNSAFE_SURFACE
    owner choice required -> BLOCKED_BY_OWNER_DECISION
    same pain absent for N scans -> STALE candidate
    stale and replaced by newer pain -> SUPERSEDED
    confirmed resolved by proof -> CLOSED
    closed pain appears again -> REOPENED

The circuit must not close pain without evidence/proof.

#### 10.2 Pain identity and deduplication

Pain identity must be stable across runs.

pain_id should be derived from:

    pain_type
    normalized affected_surface
    related organ_id or candidate_id
    source map/ref when relevant
    contradiction type when relevant

A repeat observation must update:

    last_seen
    seen_count
    evidence_refs
    current_status
    latest_scan_ref

It must not create a second active pain unless affected_surface or root cause differs.

#### 10.3 Pain record schema

Each jsonl record:

    pain_id
    schema
    status
    pain_type
    symptom
    affected_surface
    affected_ids
    root_cause_guess
    evidence_refs
    evidence_status
    confidence
    severity
    why_it_matters
    repairability
    recommended_next_logic_action
    allowed_now
    forbidden_now
    blocked_by
    linked_draft_ids
    linked_proof_refs
    linked_validator_refs
    source_cell_refs
    first_seen
    last_seen
    seen_count
    stale_after
    supersedes
    superseded_by
    closure_proof_ref

#### 10.4 Required pain types

The register must support at least:

    repo_candidate_unmapped
    map_entry_missing_file
    organ_missing_passport
    passport_missing_required_field
    passport_parse_failed
    organ_contract_missing
    authority_passport_missing
    authority_scope_ambiguous
    organ_missing_validator
    validator_unwired
    validator_target_mismatch
    organ_missing_signal_contract
    signal_contract_without_validator
    signal_schema_ref_broken
    signal_emission_proof_missing
    capability_without_invocation
    capability_without_validator
    capability_without_proof
    proof_ref_broken
    proof_ref_target_mismatch
    proof_stale
    possible_duplicate_organ
    functional_overlap_without_decision
    shadow_organ_unmapped
    old_version_not_quarantined
    wrapper_without_contract
    conflicting_organ_claims_same_capability
    draft_stale_or_unread
    draft_references_missing_pain
    draft_references_missing_surface
    runtime_surface_unindexed
    skipped_surface_may_hide_body_part
    map_conflict
    root_marker_missing

#### 10.5 Severity and priority fields

Severity is risk to organism integrity.

Priority is what the agent should reason about first.

priority_score should consider:

    severity
    evidence strength
    whether it blocks current route_request_packet
    whether it affects active/limited organ
    whether it affects accepted memory or live boundary
    whether an active draft already exists
    whether repair is logic-level safe now

#### 10.6 Agent consumption rules

The next cycle must be able to ask:

    What open pains exist?
    Which pain is blocking my current route?
    Which pain has an active draft?
    Which pain is ready for logic repair?
    Which pain requires proof first?
    Which pain requires Owner decision?
    Which pain should only be monitored?

Therefore the register must include an index summary at end or in companion summary:

    open_count
    critical_count
    ready_for_logic_repair_count
    blocked_count
    active_draft_linked_count
    top_priority_pain_ids

#### 10.7 Forbidden behavior

The pain register must not:

    auto-fix files
    mutate maps
    mutate passports
    mutate active memory
    claim resolution without proof
    duplicate same pain every run
    promote weak heuristic candidates to pain
    hide skipped-surface uncertainty

#### 10.8 Non-success patterns

Not acceptable:

    pain as one-off report only
    no stable pain_id
    no lifecycle
    no deduplication
    no severity/priority
    no linked draft ids
    no next logic action
    no blocked_by
    no stale handling

### 11. Repair Draft Board

Purpose: store candidate logic repairs that the agent can revisit, strengthen, reject, or route into implementation later.

Output:

    .runtime/body_self_inspection_v1/repair_draft_board.jsonl

A draft is not an implemented fix. It is a structured hypothesis and safe next-thinking route.

#### 11.1 Draft lifecycle

Allowed draft statuses:

    ACTIVE_DRAFT
    EVIDENCE_LINKED
    READY_FOR_PROBE
    BLOCKED_BY_MISSING_PROOF
    BLOCKED_BY_OWNER_DECISION
    BLOCKED_BY_UNSAFE_SURFACE
    CODEX_TASK_CANDIDATE
    SUPERSEDED
    STALE
    REJECTED
    CLOSED
    QUARANTINED

Transition rules:

    pain with safe logic repair -> ACTIVE_DRAFT
    draft + proof refs -> EVIDENCE_LINKED
    draft + validator requirement + proof path -> READY_FOR_PROBE
    needs implementation beyond logic -> CODEX_TASK_CANDIDATE
    unsafe target -> BLOCKED_BY_UNSAFE_SURFACE
    missing evidence -> BLOCKED_BY_MISSING_PROOF
    owner choice needed -> BLOCKED_BY_OWNER_DECISION
    newer better draft replaces it -> SUPERSEDED
    target disappears or map changes -> STALE
    proof contradicts hypothesis -> REJECTED
    repair proven accepted elsewhere -> CLOSED

#### 11.2 Draft identity and deduplication

Draft id should be stable from:

    from_pain_id
    proposed_repair_type
    target_id
    affected_surface

If same pain already has active draft, update draft instead of creating a duplicate.

#### 11.3 Draft record schema

Each jsonl record:

    draft_id
    schema
    status
    from_pain_id
    target_id
    target_kind
    hypothesis
    proposed_logic_repair
    proposed_repair_type
    required_proof
    required_validator
    required_inputs
    allowed_now
    forbidden_now
    risk_flags
    expected_outputs
    acceptance_boundary
    rollback_or_quarantine_note
    linked_evidence_refs
    linked_validator_refs
    linked_proof_refs
    next_read_required
    next_probe_candidate
    codex_task_candidate
    owner_decision_required
    created_at
    updated_at
    stale_after
    supersedes
    superseded_by
    closure_proof_ref

#### 11.4 Proposed repair types

Allowed proposed_repair_type values:

    CREATE_PASSPORT_REQUIREMENT
    CREATE_CONTRACT_REQUIREMENT
    CREATE_AUTHORITY_REQUIREMENT
    CREATE_VALIDATOR_REQUIREMENT
    CREATE_SIGNAL_CONTRACT_REQUIREMENT
    CREATE_SIGNAL_ADAPTER_REQUIREMENT
    CREATE_MAP_ENTRY_CANDIDATE
    CREATE_INVOCATION_REQUIREMENT
    CREATE_PROOF_REF_REPAIR_REQUIREMENT
    CREATE_DUPLICATE_RESOLUTION_REQUIREMENT
    CREATE_QUARANTINE_REQUIREMENT
    MARK_SUPPORT_TOOL_NON_ORGAN
    REQUEST_MORE_PROOF
    ASK_OWNER_DECISION
    MONITOR_ONLY

#### 11.5 Draft-to-Codex boundary

A draft may become CODEX_TASK_CANDIDATE only if it has:

    clear target files or target surfaces
    explicit allowed writes
    explicit forbidden writes
    expected outputs
    validator requirements
    proof expectations
    rollback/quarantine rule
    preflight requirements

Draft board does not launch Codex.

Codex task pack is created later by GPT/operator after reviewing draft candidates.

#### 11.6 Draft board read path

Next agent cycle must read draft board before creating new drafts.

Read questions:

    Do I already have a draft for this pain?
    Did new evidence strengthen it?
    Did new evidence contradict it?
    Is it ready for probe?
    Is it blocked?
    Is it stale?
    Should it become Codex task candidate?

#### 11.7 Forbidden behavior

The draft board must not:

    directly mutate repo
    directly mutate maps
    directly mutate passports
    directly wire organs
    directly launch Codex
    directly claim acceptance
    create implementation task without proof/validator boundary
    create duplicate drafts for same pain

#### 11.8 Non-success patterns

Not acceptable:

    draft without from_pain_id
    draft without allowed/forbidden actions
    draft without required proof
    draft without required validator when repair affects organism structure
    draft that cannot be read next cycle
    Codex candidate without preflight boundary
    stale drafts never detected

### 12. Next Logic Queue

Purpose: choose the next reasoning action for the agent from current body reality, open pains, and active drafts.

Output:

    .runtime/body_self_inspection_v1/next_logic_queue.json

This is the bridge from inspection to the agent's mind. It is not a human todo list.

#### 12.1 Queue structure

next_logic_queue.json must include:

    schema
    status
    generated_at
    source_reality_ref
    source_pain_register_ref
    source_draft_board_ref
    queue_items
    selected_next_item
    selection_reason
    blocked_items
    monitor_items
    stale_after
    boundary

#### 12.2 Queue item schema

Each queue item:

    queue_item_id
    from_pain_id
    from_draft_id
    target_id
    target_kind
    next_logic_action
    reason
    priority_score
    severity
    repairability
    required_read_refs
    required_proof_refs
    required_validator_refs
    allowed_now
    forbidden_now
    expected_logic_output
    stop_condition
    escalation_candidate
    owner_decision_required
    codex_candidate

#### 12.3 Selection rules

Prioritize:

    current route_request_packet blockers
    critical/high severity pains with strong evidence
    pains ready for logic-level repair
    drafts ready for probe
    missing passport/validator on active or map-declared organ
    duplicate/conflict affecting capability routing
    broken proof refs used by current map

Deprioritize:

    weak heuristic-only observations
    low severity signal readiness for non-active candidates
    monitor-only support tools
    skipped-surface uncertainty without evidence
    pains already blocked by owner decision

#### 12.4 Allowed next_logic_action values

    READ_SPECIFIC_MAP
    READ_SPECIFIC_PASSPORT
    READ_SPECIFIC_CONTRACT
    READ_SPECIFIC_VALIDATOR
    READ_SPECIFIC_PROOF
    COMPARE_CONTRACTS
    COMPARE_VALIDATORS
    COMPARE_PROOFS
    CREATE_PASSPORT_REQUIREMENT_DRAFT
    CREATE_CONTRACT_REQUIREMENT_DRAFT
    CREATE_VALIDATOR_REQUIREMENT_DRAFT
    CREATE_SIGNAL_CONTRACT_REQUIREMENT_DRAFT
    CREATE_MAP_ENTRY_CANDIDATE_DRAFT
    CREATE_DUPLICATE_RESOLUTION_DRAFT
    CREATE_QUARANTINE_DRAFT
    UPDATE_EXISTING_DRAFT
    MARK_SUPPORT_TOOL_NON_ORGAN_DRAFT
    REQUEST_MORE_PROOF
    ASK_OWNER_DECISION
    MONITOR_ONLY
    BLOCKED_NO_SAFE_LOGIC_ACTION

#### 12.5 Boundary of queue execution

The queue selects reasoning, not mutation.

Allowed immediate execution after queue selection:

    read selected refs
    create/update runtime draft
    create/update runtime pain status
    produce reasoning proof
    produce Codex task candidate draft, not launch Codex

Forbidden immediate execution:

    edit tracked repo files
    edit maps
    edit passports
    edit validators
    wire organs
    launch live runtime
    launch Codex
    browse web
    mutate active memory

#### 12.6 Stop conditions

Each selected item must include a stop condition:

    proof_found
    proof_missing
    contradiction_found
    draft_updated
    owner_decision_required
    unsafe_surface_detected
    no_safe_logic_action
    codex_task_candidate_ready

#### 12.7 Queue proof

next_logic_queue.json must prove:

    source refs exist
    selected item is from open pain or active draft
    selected action is allowed
    forbidden actions are listed
    no mutation was performed
    stale_after exists

#### 12.8 Non-success patterns

Not acceptable:

    queue as human todo list only
    selected action without source pain/draft
    no priority reason
    no stop condition
    action that mutates repo immediately
    Codex launched from queue
    no stale_after
    no boundary proof
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
