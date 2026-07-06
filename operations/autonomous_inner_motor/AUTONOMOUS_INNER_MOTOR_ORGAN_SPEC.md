# AUTONOMOUS_INNER_MOTOR_ORGAN_SPEC

Status: CONSTRUCTION_STARTED_CONTRACT_SURFACE_ONLY

## Role

AUTONOMOUS_INNER_MOTOR_ORGAN is not the whole brain. It is the executive motor organ: the controlled inner cycle that wakes the Builder, observes reality, asks internal questions, chooses the next allowed path, invokes the right organ by contract, checks proof, checkpoints, and stops or continues by policy.

Brain = system of organs. Motor = organ that keeps the brain moving. School teaches. Library advises. Web informs. Validator protects. Memory remembers. Motor chooses who acts next.

## Non-sprawl law

No new autonomous runner may be created for a new maturity level. New maturity means policy change plus validator extension, not a new organ. New mode is opened inside the same organ only after proof.

Forbidden pattern:
- run_motor_trial.ps1
- run_motor_v1.ps1
- run_motor_v2.ps1
- run_live_motor_daemon.ps1
- one runner per maturity or phase

Required pattern:
- one organ
- one runner contract
- one policy surface
- one proof format
- one validator family
- maturity controlled by policy gates

## Core loop

1. wake
2. observe repo/runtime/memory reality
3. check active long process and school priority
4. ask internal questions
5. classify current state and gaps
6. rank allowed next paths
7. select one path
8. check policy
9. invoke target organ only if allowed
10. collect proof
11. checkpoint
12. stop or continue by policy

## Priority order

1. Owner stop / safety / rollback
2. active school or active long process
3. memory integrity
4. validators and proof
5. motor self-cycle
6. optional sandbox action
7. governed repo action
8. live authority only after explicit live proof

## School priority

If school is active, the motor must not compete with it. Allowed responses are WAIT_FOR_SCHOOL, OBSERVE_SCHOOL_READONLY, SUMMARIZE_AFTER_SCHOOL, or BLOCKED_BY_ACTIVE_SCHOOL. The motor must not start a second school process, mutate active memory, or use the same state surface while school owns it.

## Ports

- SCHOOL_PORT: learning organ invocation through contract only.
- ACTIVE_MEMORY_PORT: read-only by default; mutation only by governed promotion path.
- INTERNAL_LIBRARY_PORT: local instruction/library search, above web in source ladder.
- WEB_RESEARCH_PORT: external facts and citations only; never brain or runtime truth.
- TOOL_ACTION_PORT: terminal/repo/Codex/Bridge actions only through policy and proof gates.
- VALIDATOR_PORT: immune proof gate.
- ROLLBACK_PORT: checkpoint/restore gate for risky actions.

## Source ladder

1. active law/settings
2. current repo/runtime proof
3. active compact memory
4. internal library
5. archived reference
6. web/external sources

Web cannot prove internal runtime state. Repo/runtime proof overrides old reports and external content.

## Maturity levels inside one organ

- DIAGNOSTIC_LOCKED: read reality and validate contracts only.
- READ_ONLY_MOTOR: ask internal questions and choose a safe next path; no active mutation.
- SANDBOX_ACTION: one sandbox-only action with rollback/proof.
- GOVERNED_REPO_ACTION: one governed repo action after preflight, checkpoint, validator.
- CONTINUOUS_CHECKPOINTED: multiple cycles with checkpoint between cycles.
- LIVE_AUTHORITY: disabled until separate live proof and Owner authority.

These are policy levels, not new organs.

## Initial construction boundary

Current pass builds the contract surface only: spec, policy, state schema, proof schema, organ contract, and validator. It does not launch the motor, mutate active memory, run school, invoke Codex, or start daemon processes.

## SandboxExploration compact proof rule

SandboxExploration grants broad internal freedom only inside hard sandbox walls. It must write exactly one compact proof file per run: `SANDBOX_EXPLORATION_PROOF.json`. Raw traces must be summarized into compact events. No extra trace files are allowed. The validator must reject proof overflow, extra files, active memory mutation, school start, Codex launch, web use, or background process creation.
