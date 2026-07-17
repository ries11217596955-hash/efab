# CODEX_TASK_CONTINUOUS_AGENT_RUNTIME_V1_LAB_SLICE_A

Status: READY_FOR_CODEX

## Mission

Create the smallest operator-supervised continuous RAM runtime lab proving one principle only:

```text
same process + RAM state persistence across multiple cycles + safety boundary
```

This is not a canonical launcher replacement and not a full agent life.

## Required preflight rule

Before any file writes, Codex must inspect the repo and report:

```text
PREFLIGHT_PASS
Files changed before PREFLIGHT_PASS: NO
```

If this cannot be confirmed, stop with:

```text
BLOCKED_PREFLIGHT
Files changed before PREFLIGHT_PASS: NO
```

## Context files to read first

```text
AGENT_BUILDER_RAM_LIFE_TRANSITION_MASTER_PLAN_V1.md
operations/autonomous_inner_motor/reports/RAM_LIFE_AUDIT_F_CONTINUOUS_RUNTIME_LAB_DESIGN_V1.json
tests/self_development/RAM_LIFE_AUDIT_F_CONTINUOUS_RUNTIME_LAB_DESIGN_V1_PROOF.json
operations/autonomous_inner_motor/reports/RAM_LIFE_AUDIT_D_CONTINUOUS_SAFETY_V1.json
```

## Files to create only

```text
operations/autonomous_inner_motor/run_continuous_agent_runtime_v1_lab.ps1
validators/validate_continuous_agent_runtime_v1_lab.ps1
tests/self_development/CONTINUOUS_AGENT_RUNTIME_V1_LAB_PROOF.json
operations/autonomous_inner_motor/reports/CONTINUOUS_AGENT_RUNTIME_V1_LAB_ACCEPTANCE_DRAFT.json
```

Do not edit existing runner/launcher:

```text
operations/autonomous_inner_motor/start_agent_life_v1.ps1
operations/autonomous_inner_motor/run_autonomous_inner_motor.ps1
```

Do not edit active memory or compact memory intake.

## Lab script requirements

Create:

```text
operations/autonomous_inner_motor/run_continuous_agent_runtime_v1_lab.ps1
```

Owner-facing parameters:

```powershell
[int]$DurationMinutes
```

Default constraints:

```text
DurationMinutes must be 1..5
Mode = SandboxExploration
MemoryMode = QueueOnly
NoGit = true
NoCodex = true
NoWeb = true
NoRepair = true
NoCleanup = true
```

Runtime root:

```text
.runtime/continuous_agent_runtime_v1_lab/<runtime_id>/
```

Allowed disk outputs:

```text
runtime.lock.json
heartbeat.json
STOP.json support only if present, do not create by default
checkpoints/latest.json
CONTINUOUS_AGENT_RUNTIME_V1_LAB_PROOF.json
CONTINUOUS_AGENT_RUNTIME_V1_LAB_SUMMARY.json
```

The script must:

```text
1. Preflight repo root.
2. Refuse if another continuous lab/runtime lock is live.
3. Refuse if active memory root is missing.
4. Create one runtime lock with current PID.
5. Create one in-memory AgentState object.
6. Loop until DurationMinutes expires, at least 2 cycles when possible.
7. Keep the same PID for all cycles.
8. Increment AgentState.cycle_count and AgentState.ram_counter in RAM.
9. Create cycle_scratch in RAM and clear it before next cycle.
10. Write heartbeat each cycle.
11. Write bounded checkpoint/latest.json.
12. Respect STOP.json if created externally between cycles.
13. Write final proof and summary.
14. Mark boundary booleans false for repo/active memory/codex/web/school/cleanup mutations.
15. Remove or mark lock inactive at safe shutdown; final proof must record shutdown status.
```

The lab must not call:

```text
run_autonomous_inner_motor.ps1
start_agent_life_v1.ps1
invoke_body_self_inspection_circuit_v1.ps1
codex
web
school
cleanup scripts
```

## Proof requirements

The final proof must include:

```text
schema = continuous_agent_runtime_v1_lab_proof
status = PASS_CONTINUOUS_AGENT_RUNTIME_V1_LAB
runtime_id
pid
same_pid_across_cycles = true
cycle_count >= 2
ram_counter_final >= 2
ram_state_persisted = true
per_cycle_json_bridge_used_for_ram_state = false
lock_created = true
heartbeat_written = true
stop_signal_supported = true
checkpoint_written = true
final_proof_written = true
cycle_scratch_cleared = true
repo_mutated = false
active_memory_direct_mutated = false
codex_launched = false
web_launched = false
school_launched = false
raw_debug_retained = false
canonical_launcher_mutated = false
cycle_runner_mutated = false
```

## Validator requirements

Create:

```text
validators/validate_continuous_agent_runtime_v1_lab.ps1
```

Validator must:

```text
1. Parse the lab script.
2. Execute the lab with DurationMinutes 1.
3. Locate the produced runtime proof.
4. Validate all proof requirements above.
5. Validate same PID across cycle records.
6. Validate cycle_count >= 2 and ram_counter_final >= 2.
7. Validate there are no forbidden per-cycle JSON bridge files.
8. Validate canonical launcher and cycle runner were not changed by the lab.
9. Validate active memory root still exists.
10. Validate no codex/web/school process was launched.
11. Write tests/self_development/CONTINUOUS_AGENT_RUNTIME_V1_LAB_PROOF.json as the canonical validation proof.
```

## Acceptance draft requirements

Create:

```text
operations/autonomous_inner_motor/reports/CONTINUOUS_AGENT_RUNTIME_V1_LAB_ACCEPTANCE_DRAFT.json
```

It must say:

```text
status = CODEX_DRAFT_CONTINUOUS_AGENT_RUNTIME_V1_LAB_SLICE_A
not accepted until operator/GPT validation
```

## Forbidden changes

```text
no canonical launcher mutation
no cycle runner mutation
no active memory mutation
no compact memory intake mutation except lab proof output if validator requires none
no git mutation inside lab
no Codex invocation inside lab
no web invocation inside lab
no school invocation inside lab
no body repair
no cleanup
```

## Final Codex response format

Codex final response must include:

```text
PREFLIGHT_PASS or BLOCKED_PREFLIGHT
Files changed before PREFLIGHT_PASS: YES/NO
Files created
Files modified
Validator command
Validator status
Proof path
Known limitations
```

Expected:

```text
PREFLIGHT_PASS
Files changed before PREFLIGHT_PASS: NO
Validator status: PASS_CONTINUOUS_AGENT_RUNTIME_V1_LAB
```
