# OWNER_SCHOOL_CONTROL_CONTRACT_V1

Status: ACTIVE_OPERATOR_CONTROL_CONTRACT
Created: 2026-07-15T15:22:37+04:00
Layer: Owner / GPT operator control surface

## 1. Human meaning

School is an organ for us, the Owner/operator layer.

It is not being promoted here as an autonomous Builder organ and this file is not an organ passport.

The purpose is simple:

```text
When Owner says run / test / scale / inspect School,
GPT must know the one safe control surface,
the boundaries,
the validators,
and what must not be touched.
```

## 2. Canonical control surface

Owner-facing School entrypoint:

```powershell
operations/school/run_agent_school.ps1 -Count <N> -Mode <Test|Live> -Topics <AUTO|topic1,topic2>
```

Canonical policy validator:

```powershell
operations/school/validate_agent_school_canonical_entrypoint_v1.ps1
```

Current P1 proof says:

```text
VALIDATION_STATUS = PASS_AGENT_SCHOOL_CANONICAL_POLICY_V2
OWNER_FACING_ENTRYPOINT_COUNT = 1
OWNER_ENTRYPOINT = operations/school/run_agent_school.ps1
OWNER_FIELDS = Count, Mode, Topics
MODE_VALUES = Test, Live
SCHOOL_LIVE_MODE_IS_MEMORY_DIGEST_MODE_NOT_AGENT_RUNTIME = true
RUNTIME_READY = false
```

## 3. What this contract gives us

This contract gives the human/operator layer a stable command boundary:

```text
Owner intent -> GPT checks state -> GPT chooses safe School control action -> validator/proof -> report back
```

It prevents these bad patterns:

```text
run random internal school script
create a new launcher because Count changed
treat 84 ps1 files as 84 organs
touch active memory without preflight
call Live readiness from smoke proof
use body map as command interface
```

## 4. Operating rule

Before any School action, GPT must check:

```text
repo root
branch
HEAD
git status
origin delta
active School / producer / digest processes
active memory surface existence
latest small validator proof
requested Count / Mode / Topics
```

If another School/digest/producer process is running:

```text
observe only
no duplicate launch
no cleanup
no mutation of shared surfaces
```

## 5. Allowed operator actions

Allowed after fresh preflight:

```text
inspect School files and reports
run canonical validator
prepare launch command
run bounded Test mode when Owner asks
produce campaign/material pack for existing School
write audit/report artifacts
propose repair patch for School control surface
```

Live mode requires stronger gate:

```text
repo clean/synced
no duplicate process
active memory ready/protected
last bounded proof PASS
disk/log path known
stop/resume plan
Owner route authority
```

## 6. Forbidden actions

```text
Do not launch duplicate School.
Do not broad-kill Codex or School processes.
Do not clean .runtime while School/digest is active.
Do not mutate .runtime/active_compact_semantic_memory_v1 without backup/hash/proof/authority.
Do not create one passport per script.
Do not patch body map just to make the audit look green.
Do not claim PROVEN_LIVE from lab/report material.
Do not call School an autonomous Builder organ from this contract.
```

## 7. Relationship to maps and passports

For us:

```text
School = operator-controlled organ / control surface
```

For Builder body maps/passports:

```text
School may be represented later as controlled capability / organ candidate / operator organ boundary,
only after a separate map/passport reconciliation with validators.
```

This file does not repair body-map or passport-index gaps by itself.

## 8. Current known gap from P1 audit

```text
School canonical launcher and validator exist.
Canonical School validator passes.
But body map and passport coverage do not cleanly express School as a governed control surface.
Passport index/count validators still need reconciliation.
```

Meaning:

```text
We can control School safely from the Owner layer.
We cannot yet claim mature internal Builder organ coverage for School.
```

## 9. Next repair slice

Next safe repair is not “make 59 passports”.

Next safe repair is:

```text
create a School operator-control index / map reference
reconcile passport index counts
keep canonical launcher as the only Owner-facing entrypoint
run validators
commit only proof-backed changes
```

## 10. Status boundary

```text
OWNER_CONTROL_CONTRACT = ACTIVE
SCHOOL_CANONICAL_ENTRYPOINT = VALIDATOR_PASS
SCHOOL_AS_AGENT_ORGAN = NOT_CLAIMED
SCHOOL_LIVE_RUNTIME = NOT_PROVEN_LIVE
ACTIVE_MEMORY = NOT_TOUCHED
```
## 11. Operator runbook

Human-use runbook / practical pult:

```text
operations/school/OWNER_SCHOOL_RUNBOOK_V1.md
```

Use it when Owner asks to check, test, prepare Live, observe, or recover School.
