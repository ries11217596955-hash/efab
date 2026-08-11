# OWNER_AGENT_LIFE_RUNBOOK_V1

Status: CURRENT_OWNER_GUIDANCE / HISTORICAL_LIVE_PROOF_BOUNDARY

## Purpose
This is the single Owner-facing recovery/runbook surface for Agent Life topology. It prevents a new GPT/chat from guessing which launcher is live, lab-only, legacy, or forbidden.

## Current claim boundary
- Agent currently alive: NOT_PROVEN.
- Current replacement canonical live-life launcher: NOT_PROVEN.
- Do not blindly relaunch Agent Life from this document. Fresh repo/runtime -> applicable AGENTS.md -> Notebook/journal -> retained proofs -> explicit Owner authority are required first.

## Last real proven live-life route
Historical Owner-facing entrypoint:
`operations/autonomous_inner_motor/start_agent_life_v1.ps1`

Exact retained 5-minute command:
`powershell -NoProfile -ExecutionPolicy Bypass -File operations/autonomous_inner_motor/start_agent_life_v1.ps1 -DurationMinutes 5`

Historical internal cycle:
`operations/autonomous_inner_motor/run_autonomous_inner_motor.ps1`

Proven historical contract for that trial:
- Mode=SandboxExploration
- deep thinking=ON
- memory learning=ON
- MemoryIngestionMode=QueueOnly
- direct active-memory write=NO
- action execution=NO
- Codex=NO
- Web=NO
- git mutation=NO
- repair execution=NO

Retained proof:
- `operations/autonomous_inner_motor/reports/LIVE_OBSERVATION_5MIN_THOUGHT_AUDIT_V1.json`
- `operations/autonomous_inner_motor/reports/DAILY_AUDIT_20260717_V1.json`

Lifecycle classification: LAST_REAL_LIVE_PROVEN, later reclassified as TRACKED_LEGACY_ADAPTER. Historical proof does not grant current launch authority and does not prove this is the current canonical live-life launcher.

## Continuous RAM-life LAB route
LAB entrypoint:
`operations/autonomous_inner_motor/run_continuous_agent_runtime_v1_lab.ps1`

Retained acceptance/proof:
- `operations/autonomous_inner_motor/reports/CONTINUOUS_AGENT_RUNTIME_V1_LAB_ACCEPTANCE.json`
- `tests/self_development/CONTINUOUS_AGENT_RUNTIME_V1_LAB_PROOF.json`

Proves: one supervised LAB process can retain RAM state across multiple cycles under safety gates.

Does NOT prove:
- canonical live-life was replaced;
- unattended/live runtime readiness;
- full-organism wiring;
- compact-memory integration solved;
- autonomous agent.

Lifecycle classification: LAB_ONLY / NOT_CURRENT_LIVE_AUTHORITY.

## Forbidden old Owner-facing life routes
Use `operations/autonomous_inner_motor/AGENT_LIFE_LEGACY_LAUNCH_QUARANTINE_V1.json` as the authoritative quarantine list. In particular, do not promote old `live_like`, `live_readiness`, `live_start`, `parallel_life`, or generated `.runtime/live_trials` wrappers into current Owner launch routes.

Legacy/quarantined files are not automatically deletion-safe. Dependency migration and scoped proof are required before removal.

## Recovery decision rule for any new GPT/chat
1. Restore fresh `H:\efab` root/branch/HEAD/dirty/runtime state.
2. Read applicable `AGENTS.md`.
3. Read latest `AGENT_BUILDER_SELF_NOTEBOOK.md` and relevant operator journal.
4. Read this runbook plus the retained proof/quarantine files above.
5. Distinguish LAST_REAL_LIVE_PROVEN from CURRENT_LIVE_AUTHORITY.
6. If no newer accepted live-life replacement exists, report `CURRENT_REPLACEMENT_NOT_PROVEN`; do not guess and do not launch.
7. Any live launch requires explicit current Owner authority, checkpoint/rollback, validator, and post-health proof.

## Related School Owner route
School has its own canonical Owner surfaces and must not be inferred from Agent Life wrappers:
- `operations/school/OWNER_SCHOOL_CONTROL_CONTRACT_V1.md`
- `operations/school/OWNER_SCHOOL_RUNBOOK_V1.md`
- Owner-facing School entrypoint: `operations/school/run_agent_school.ps1`

Do not treat School internal controllers/helpers as alternate Owner launchers.
## 2026-08-11 Legacy launcher decommission

The following old Owner-facing launch surfaces were removed from the active repo after caller/process closure proof. They remain historical names only and MUST NOT be recreated as launch alternatives:

- operations/live_like/run_school_aimo_live_like_observation_gate_v1.ps1
- operations/live_readiness/run_school_aimo_continuous_runtime_proof_v1.ps1
- operations/live_readiness/run_school_aimo_live_readiness_gate_v1.ps1
- operations/live_start/restart_aimo_agent_only_v1.ps1
- operations/live_start/start_school_aimo_controlled_live_v1.ps1
- operations/parallel_life/run_school_aimo_parallel_lab_v1.ps1

Current boundary remains:
- School Owner entrypoint: operations/school/run_agent_school.ps1
- last retained real Agent Life launcher/evidence adapter: operations/autonomous_inner_motor/start_agent_life_v1.ps1
- continuous RAM runtime: LAB_ONLY, not live replacement
- current proven replacement live-life launcher: NONE