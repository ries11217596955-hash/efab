# CODEX_TASK_BODY_SELF_INSPECTION_SLICE_F

Status: READY_FOR_CODEX / NOT_RUN
Task type: bounded implementation slice
Target organ/circuit: BODY_SELF_INSPECTION_CIRCUIT_V1
Slice: F - Self-Inspection Signal + Circuit Aggregate Validator

## 0. Mandatory primary spec

Read first:

    operations/body_self_inspection/BODY_SELF_INSPECTION_CIRCUIT_V1_PLAN.md

Primary plan sections for this slice:

    13. Self-Inspection Signal
    14. Validator Layer
    15. Integration with Mind Logic
    16. Codex Implementation Pack

Also read existing Slice A/B/C/D/E implementation and proofs, especially:

    operations/body_self_inspection/invoke_body_self_inspection_slice_e_v1.ps1
    validators/validate_body_self_inspection_slice_e_v1.ps1
    tests/self_development/BODY_SELF_INSPECTION_SLICE_E_V1_PROOF.json

## 1. Role and boundary

Implement only Slice F.

You are not the Builder brain. You are an implementation tool.

Slice F builds:

    self-inspection signal emitter
    final circuit aggregate invoker
    final aggregate validator/proof
    parent-loop integration-ready packet

It must not mutate mind logic, live runtime, active memory, maps, passports, contracts or accepted-core.

Integration with mind logic in this slice means:

    emit an integration-ready signal/packet for future parent-loop consumption

It does not mean editing operations/reasoning/*, autonomous_inner_motor, live runners, route locks or active memory.

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
    Slice A-E files/proofs exist
    target Slice F files already exist or not

If repo is dirty before changes, return BLOCKED_PREFLIGHT unless dirt is explicitly expected and explained.

## 3. Allowed files

Allowed new files:

    operations/body_self_inspection/emit_body_self_inspection_signal_v1.ps1
    operations/body_self_inspection/invoke_body_self_inspection_circuit_v1.ps1
    validators/validate_body_self_inspection_circuit_v1.ps1
    tests/self_development/BODY_SELF_INSPECTION_CIRCUIT_V1_PROOF.json

Allowed runtime outputs:

    .runtime/body_self_inspection_v1/body_self_inspection_signal.json
    .runtime/body_self_inspection_v1/body_self_inspection_parent_packet.json
    .runtime/body_self_inspection_v1/BODY_SELF_INSPECTION_CIRCUIT_PROOF.json

Slice F may call Slice E invoker to refresh prior outputs.

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
    route locks
    git metadata
    credentials/secrets/env files

Do not:

    run live runtime
    delete or cleanup runtime
    launch Codex recursively
    browse web
    execute repair drafts
    patch files based on queue items
    write active memory
    install parent-loop wiring
    claim nervous system connected
    claim full mature organ if only aggregate PASS exists

## 5. Required signal emitter

Implement:

    operations/body_self_inspection/emit_body_self_inspection_signal_v1.ps1

It must read:

    body_pain_register.json
    repair_draft_board.json
    next_logic_queue.json
    body_reconciliation.json
    Slice A-E tracked proofs

It must write:

    .runtime/body_self_inspection_v1/body_self_inspection_signal.json
    .runtime/body_self_inspection_v1/body_self_inspection_parent_packet.json

Signal top-level required fields:

    schema
    status
    version
    generated_at
    repo_root
    source_outputs
    proof_refs
    body_health_summary
    pain_summary
    repair_summary
    queue_summary
    top_priority_items
    parent_loop_signal
    integration_boundary
    boundary

PASS signal status:

    PASS_BODY_SELF_INSPECTION_SIGNAL_V1

Parent packet top-level required fields:

    schema
    status
    version
    generated_at
    packet_type
    produced_by
    source_signal_ref
    recommended_parent_action
    next_safe_operator_action
    execution_allowed
    owner_decision_required
    proof_required_before_execution
    forbidden_now
    boundary

PASS packet status:

    PASS_BODY_SELF_INSPECTION_PARENT_PACKET_V1

Boundary:

    signal != nervous system connection
    parent packet != executed parent action
    queue item != permission
    repair draft != patch
    aggregate PASS != mature organ acceptance

## 6. Required circuit invoker

Implement:

    operations/body_self_inspection/invoke_body_self_inspection_circuit_v1.ps1

It must:

    create .runtime/body_self_inspection_v1 if missing
    call Slice E invoker or verify Slice A-E outputs exist/fresh enough
    call emit_body_self_inspection_signal_v1.ps1
    write BODY_SELF_INSPECTION_CIRCUIT_PROOF.json

Circuit runtime proof status:

    PASS_BODY_SELF_INSPECTION_CIRCUIT_RUNTIME_V1

It must summarize:

    slice_a_status
    slice_b_status
    slice_c_status
    slice_d_status
    slice_e_status
    signal_status
    parent_packet_status
    total_pains
    total_repair_drafts
    total_queue_items
    execution_allowed=false

## 7. Final aggregate validator

Implement:

    validators/validate_body_self_inspection_circuit_v1.ps1

Validator must run the circuit invoker and verify:

    Slice A-E validators/proofs pass or tracked proofs status PASS
    all Slice A-E runtime outputs exist and parse
    body_self_inspection_signal.json exists and parses
    body_self_inspection_parent_packet.json exists and parses
    BODY_SELF_INSPECTION_CIRCUIT_PROOF.json exists and parses
    signal required fields exist
    parent packet required fields exist
    execution_allowed is false in parent packet and circuit proof
    integration boundary explicitly says signal is not nervous system connection
    repair drafts and queue items are not executed
    no tracked map/passport/contract mutation
    no active memory mutation
    no accepted-core mutation
    no live process touched
    no Codex/web launched

Tracked validator proof path:

    tests/self_development/BODY_SELF_INSPECTION_CIRCUIT_V1_PROOF.json

PASS status:

    PASS_BODY_SELF_INSPECTION_CIRCUIT_V1

Failure statuses:

    FAIL_BODY_SELF_INSPECTION_CIRCUIT_V1
    BLOCKED_BODY_SELF_INSPECTION_CIRCUIT_V1

## 8. Required boundary proof

Every output/proof must state:

    repo_mutated = false
    active_memory_mutated = false
    accepted_core_mutated = false
    body_map_mutated = false
    capability_map_mutated = false
    passports_mutated = false
    contracts_mutated = false
    repair_executed = false
    parent_action_executed = false
    mind_logic_mutated = false
    nervous_system_connected = false
    live_process_touched = false
    codex_launched = false
    web_launched = false
    cleanup_performed = false

Runtime outputs under .runtime/body_self_inspection_v1 are allowed.

## 9. Commands before final report

Run at least:

    powershell -NoProfile -ExecutionPolicy Bypass -File validators/validate_body_self_inspection_circuit_v1.ps1
    git diff --check
    git status --short --untracked-files=all

Do not commit/push unless explicitly instructed by GPT/operator.

## 10. Acceptance boundary

This slice is accepted only if:

    aggregate validator PASS
    tracked proof JSON PASS
    outputs parse
    signal exists
    parent packet exists
    execution_allowed false
    parent action not executed
    mind logic not mutated
    nervous system not claimed connected
    mutation boundary false

Claim allowed after PASS:

    BODY_SELF_INSPECTION_CIRCUIT_V1 has aggregate validator PASS and signal packet readiness.

Claim not allowed:

    mature organ accepted
    live organ wired
    nervous system connected
    mind loop installed
