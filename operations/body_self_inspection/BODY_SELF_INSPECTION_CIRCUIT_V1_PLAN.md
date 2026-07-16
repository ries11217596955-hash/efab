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

Define exact skip/read policy for heavy and protected surfaces.

Must include:

    .git
    node_modules
    .venv
    __pycache__
    dist/build/cache
    large archives
    .runtime raw chunks / old run bodies / transient logs

Runtime may be read only via manifests, latest summaries, and selected proof refs.

### 3. Repo Inventory Cell

Build bounded metadata inventory. No full content read by default.

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