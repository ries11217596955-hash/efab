# AGENT_BUILDER_SELF_NOTEBOOK

Status: ROOT_OPERATOR_NOTEBOOK / MIGRATION_FIRST_READ
Language: English ASCII only
Encoding rule: UTF-8 without BOM, no Cyrillic, no smart quotes, no long dashes
Updated: 2026-07-17
Repo root: H:/efab

## 0. Purpose

This is the single root notebook for the GPT/operator.
Read this file first after chat migration or drift.

This file is:
- active operator notebook
- compact migration pointer
- current route reminder
- file map
- cleanup guard

This file is not:
- runtime proof
- live proof
- validator output
- active memory
- permission to mutate protected state

Fresh claims still require terminal/repo/runtime proof.

## 1. Restore reality before action

Before any serious repo/runtime claim or mutation run:

    git fetch origin main
    git status --short --untracked-files=all
    git rev-parse --abbrev-ref HEAD
    git rev-parse --short HEAD
    git rev-list --left-right --count HEAD...origin/main
    git log -5 --oneline

Also check no duplicate runtime:

    run_agent_school
    canonical_exact
    codex_warehouse
    codex.cmd
    node.exe
    run_autonomous_inner_motor
    merge_compact_memory_intake
    memory_commit_controller
    absorb_atom_file
    digest

Protected active memory readiness:

    .runtime/active_compact_semantic_memory_v1/manifest.json
    .runtime/active_compact_semantic_memory_v1/index.json
    .runtime/active_compact_semantic_memory_v1/cells.jsonl

Rules:
- No proof -> no strong claim.
- Codex output -> CODEX_DRAFT until validator/proof.
- Lab proof is not live proof.
- If this notebook conflicts with fresh repo/runtime proof, proof wins and this notebook must be corrected.

## 2. Current repo checkpoint when this ASCII rewrite was made

Previous head before this rewrite:

    121704d

Remote delta before this rewrite:

    0 / 0

Previous important commits:

    121704d docs: reinforce GPT notebook discipline
    a2e03bd chore: refresh body maps after notebook consolidation
    92f07ad docs: consolidate GPT self notebook
    33ba04f fix: add AIMO proof pack anti-repeat guard
    027407a docs: add self files and BIOS migration index

## 3. Notebook update discipline

This root notebook is the first-read operator file.

Update this file after:
- important accepted slice
- validator PASS
- runtime trial
- cleanup
- handoff change
- settings or protocol delta
- commit/push
- route-changing decision

For important project work, also append a compact entry to:

    operations/gpt_handoff/GPT_OPERATOR_JOURNAL.md

Do not create scattered handoff/status/index files unless Owner explicitly asks or a validator requires a tracked proof file.

If formal next-chat handoff is needed:
- create it under operations/gpt_handoff/
- link it from this notebook

No notebook update after important work means handoff is incomplete.

## 4. BIOS / settings / strategy reality

Exact tracked repo file named BIOS or bios was not found.

BIOS-like layer currently means:
- GPT Knowledge uploads in /mnt/data
- GPT Instructions / behavior kernel
- repo-tracked gpt_handoff / reasoning / autonomous_inner_motor / proof files

Important uploaded Knowledge files in this chat/session include:

    /mnt/data/EF_AGENT_BUILDER_BEHAVIOR_KERNEL.md
    /mnt/data/EF_UNIFIED_INNER_MOTOR_CYCLE.md
    /mnt/data/EF_EVIDENCE_AND_ACCEPTANCE_LAW.md
    /mnt/data/EF_LIVE_LAB_RUNTIME_BOUNDARY.md
    /mnt/data/EF_CHAT_MIGRATION_RECOVERY_PROTOCOL.md
    /mnt/data/EF_SETTINGS_EVOLUTION_AND_KNOWLEDGE_GOVERNANCE.md
    /mnt/data/AGENT_STRATEGY.md
    /mnt/data/EF_STATUS_POINTER_AND_CURRENT_REALITY.md

Boundary:
- uploaded Knowledge files guide behavior
- uploaded Knowledge files are not repo proof
- root AGENT_STRATEGY.md and EF_STATUS_POINTER_AND_CURRENT_REALITY.md may not exist in repo root

## 5. Current project route

Owner wants Agent Builder as independent action machine:
- brain
- memory
- hands
- legs
- immune system
- self-observation
- self-change
- self-verification
- return-to-parent

Current branch is still:

    MIND > KNOWLEDGE > REASONING > LEARNING

Do not jump to:
- live autonomous action
- child-agent launcher
- web executor
- Codex executor
- hands/legs expansion
- huge orchestration framework
- generic knowledge graph

## 6. BODY_SELF_INSPECTION_CIRCUIT_V1 status

Allowed claim:

    BODY_SELF_INSPECTION_CIRCUIT_V1 has aggregate validator PASS and signal packet readiness.

Forbidden claims:
- mature organ accepted
- live organ wired
- nervous system connected
- mind loop installed

Main files:

    operations/body_self_inspection/*
    validators/validate_body_self_inspection_*.ps1
    tests/self_development/BODY_SELF_INSPECTION_*_PROOF.json
    tests/self_development/BODY_SELF_INSPECTION_CIRCUIT_V1_PROOF.json

Slices:

    Slice A = PASS / REMOTE_SYNCED
    Slice B = PASS / REMOTE_SYNCED
    Slice C = PASS / REMOTE_SYNCED
    Slice D = PASS / REMOTE_SYNCED
    Slice E = PASS / REMOTE_SYNCED
    Slice F = PASS / REMOTE_SYNCED

## 7. AIMO / Autonomous Inner Motor status

Main files:

    operations/autonomous_inner_motor/run_autonomous_inner_motor.ps1
    operations/autonomous_inner_motor/AUTONOMOUS_INNER_MOTOR_ORGAN_SPEC.md
    operations/autonomous_inner_motor/organ_contract.json
    operations/autonomous_inner_motor/validation/AUTONOMOUS_INNER_MOTOR_ORGAN_CONTRACT_VALIDATION.json

Validators:

    validators/validate_autonomous_inner_motor_organ_contract.ps1
    validators/validate_autonomous_inner_motor_mind_logic_wiring_v1.ps1
    validators/validate_autonomous_inner_motor_action_decision_wiring_v1.ps1

Proofs:

    tests/self_development/AUTONOMOUS_INNER_MOTOR_MIND_LOGIC_WIRING_V1_PROOF.json
    tests/self_development/AUTONOMOUS_INNER_MOTOR_ACTION_DECISION_WIRING_V1_PROOF.json

AIMO repair status:
- proof-pack v2 added
- anti-repeat guard added
- organ validator updated for proof-pack v2

New runtime outputs per AIMO run:

    sandbox_proof_pack_manifest.json
    anti_repeat_guard.json

Anti-repeat rule:
- repeated_candidate_is_progress = false
- same selected_action_id repeated 3+ times => REPEAT_PRESSURE_DETECTED
- repeat pressure requires QueueOnly learning, operator review, or a new allowed action path

Fresh control proof after repair:

    .runtime/autonomous_inner_motor/aimo_20260717_084748/SANDBOX_EXPLORATION_PROOF.json

Fresh control facts:
- proof-pack manifest = PASS_AIMO_SANDBOX_PROOF_PACK_V2
- organ validator = PASS_AUTONOMOUS_INNER_MOTOR_SANDBOX_EXPLORATION_PROOF
- mind validator = PASS_AUTONOMOUS_INNER_MOTOR_MIND_LOGIC_WIRING_V1
- action validator = PASS_AUTONOMOUS_INNER_MOTOR_ACTION_DECISION_WIRING_V1
- anti_repeat_status = REPEAT_PRESSURE_DETECTED
- selected_action = ACTION_CONTRACT_V1
- consecutive_repeat_count = 8
- action_execution_allowed = false

## 8. Latest QueueOnly experiment

Trial root:

    .runtime/live_trials/aimo_10min_queueonly_20260717_0909

Summary path:

    .runtime/live_trials/aimo_10min_queueonly_20260717_0909/LIVE_TRIAL_SUMMARY.json

Observed after completion:
- status = PASS_AIMO_10MIN_QUEUEONLY_TRIAL
- cycles = 15
- duration_seconds = 629
- repeat_pressure_cycles = 15
- git_mutated = false
- codex_launched = false
- web_research_performed = false
- last_anti_repeat = REPEAT_PRESSURE_DETECTED
- last_repeat_count = 8
- last_memory_mode = QueueOnly
- last_active_memory_mutated = true

Interpretation boundary:
- active_memory_mutated=true is expected for EnableMemoryLearning + QueueOnly
- direct active memory write remains forbidden unless explicitly proven otherwise
- action_execution_allowed remains false

Next analysis needed:
- inspect whether QueueOnly created useful queued learning/operator signal
- verify no direct active-memory corruption
- decide whether ACTION_CONTRACT_V1 should become formal next task or be cut/replaced

## 9. Mind / reasoning current route

Correct cognitive route after current repair:

    Answer Assimilator / Knowledge Maturity Evaluator V1
    Knowledge Evolution Engine V1
    Mind Delta V1
    Next Intelligence Gain Question Selector V1

Do not implement huge AGI engine.
Do not create 10 organs from one idea.
Use: smallest cognitive atom -> validator -> negative tests -> AIMO wiring -> proof -> map refresh -> commit/push -> update this notebook.

Expected Answer Assimilator files if implemented:

    operations/reasoning/assimilate_deep_answer_v1.ps1
    validators/validate_deep_answer_assimilator_v1.ps1
    tests/self_development/DEEP_ANSWER_ASSIMILATOR_V1_PROOF.json

Boundary for Answer Assimilator:
- reasoning operator, not memory writer
- no active memory mutation
- no Codex launch
- no web launch
- no School launch
- no action execution

## 10. Cleanup rule

Do not delete:
- validators
- proof JSON files
- body self-inspection implementation
- AIMO implementation
- active memory runtime
- current trial runtime while analysis is needed

Do not create more scattered notebook/handoff/index files.
Prefer updating:

    AGENT_BUILDER_SELF_NOTEBOOK.md
    operations/gpt_handoff/GPT_OPERATOR_JOURNAL.md

## 11. Owner reminder map

If Owner says the operator is drifting:

    read AGENT_BUILDER_SELF_NOTEBOOK.md first

If Owner asks which files matter for the operator, answer:

    AGENT_BUILDER_SELF_NOTEBOOK.md = root notebook / first-read
    operations/gpt_handoff/GPT_OPERATOR_JOURNAL.md = formal operator journal
    operations/gpt_handoff/NEXT_CHAT_HANDOFF_*.md = formal next-chat handoff area
    operations/autonomous_inner_motor/* = AIMO organ
    operations/reasoning/* = mind/reasoning operators
    operations/body_self_inspection/* = body inspection circuit
    tests/self_development/*_PROOF.json = tracked validator proofs

If Owner asks what is next from current state:

    analyze QueueOnly trial
    verify memory QueueOnly effect
    then choose Answer Assimilator V1 or action contract formalization based on proof
