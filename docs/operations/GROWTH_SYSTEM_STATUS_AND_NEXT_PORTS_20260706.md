# Growth System Status and Next Ports - 2026-07-06

Status: ACTIVE_POINTER

## What is proven now

School has a governed path into compact memory:

```text
School
-> canonical school runner
-> finalizer
-> compact memory knowledge packet
-> intake validation
-> merge queue lock/checkpoint
-> active compact memory
-> recall/use surface
```

Proven components:

- 300k Live school result recorded: `351a071509306044bb719e2ed593bfe3642340e7`, `97987377e1ec2d1526ba18619ed1534c2b699577`.
- Multi-source compact memory intake signal: `ca61e01a7f023a4025f1bf73092cf0f9197354d2`.
- Growth signal corrected to support selected path, not choose path: `b3f02c7d3b52468a200d6cd8eecf22597f2496f0`.
- Multi-source compact memory merge queue: `b416f4c6459b3c77e91884583ffd259e2008cc9e`.
- Packet submit-to-merge wiring: `10ef30cc96d9b4aedfe97a871b55e6431bc9137e`.
- Finalizer auto-merge proof: `22f63ce18dd22fbeb51254384607f587d671c005`.
- Autonomous school cycle controller: `2905a5f344db42c0f6adfc3da0875f9ba75e5439`.
- Autonomous school control interface: `8606451a58efed6b5cc9fba0890e1d9075791541`.
- Per-cycle SLA law: `4ea7e22a369fcd7fb1218ff1cf5e82054983b7db`.
- Per-cycle SLA proof: `a07f3461da7c2a5a8fbd33e5c2855d88b498190e`.

## Current school law

```text
default_count = 50000
default_max_cycle_runtime_minutes = 60
default_max_total_runtime_minutes = 0
default_max_cycles = 0
```

Meaning:

```text
50k cycle <= 60 minutes -> continue to next cycle
50k cycle > 60 minutes -> finish finalizer/intake/merge safely, then stop before next cycle
```

This is a per-cycle SLA, not a total session timer.

## What is not yet enabled

Parallel School + AgentLife is not yet enabled as final behavior.

Current status:

```text
School autonomous cycle: built/proven
Multi-source memory intake/merge: built/proven
AgentLife packet path: built/proven
AIMO parallel life during active school: NOT_PROVEN / NOT_ENABLED
```

AIMO still needs compatibility repair so active school no longer means agent life must fully stop. The new law should be: AIMO may live in parallel, but all memory writes go through intake/merge queue and must respect merge locks/backoff.

## Next organ

`AIMO_MULTI_SOURCE_MEMORY_COMPATIBILITY_V1`

Target:

```text
School process -> intake -> merge queue -> compact memory
Agent life     -> intake -> merge queue -> compact memory
```

Rules:

- sources do not write active compact memory directly
- memory merge queue serializes writes
- AIMO can submit AgentLife packets
- AIMO uses memory_support_hint after path selection, not as route authority
- AIMO must back off if merge lock is active
- school-active state should become a coordination signal, not a hard stop by default

## Future ports to design later

### School + Codex / External World

Future source router must define:

```text
InternalFactory -> first/default scaling source
CodexSourcePort -> semantic expansion / repair patterns / edge cases
ExternalWorldSourcePort -> real-world material / current facts / environmental signals
SchoolValidator -> only accepted material becomes packet
Intake/MergeQueue -> only path into compact memory
```

Boundary: Codex and External World are material suppliers, not school brain and not route authority.

### Agent + Codex / External World / Reflex

Future agent source/reflex layer must define:

```text
AgentLife chosen task/path
-> memory support lookup
-> if knowledge gap remains, request Codex/ExternalWorld material under contract
-> convert result to packet candidate
-> validate
-> intake/merge
-> reflex candidate only after repeated/proven behavior need
```

Boundary: Codex/ExternalWorld cannot decide agent path. Reflex promotion must be validator/proof based, not convenience based.

## Stop condition for this phase

This phase is not complete until AIMO is proven to live safely while school cycle is active, with no direct active memory mutation and with correct backoff around merge queue locks.