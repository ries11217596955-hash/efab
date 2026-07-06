# Autonomous School Cycle Controller V1

Status: ACTIVE_MINIMAL_RUNTIME

## Default limits

Default run limits are policy-driven:

```text
default_count = 50000
default_max_cycle_runtime_minutes = 60
default_max_total_runtime_minutes = 0
default_max_cycles = 0
```

The 60-minute limit is a **per-cycle SLA**, not a total session timer. One cycle means one canonical school run for `Count` candidates.

## Cycle loop law

```text
run 50000-candidate cycle
-> finalizer
-> intake
-> merge queue
-> verify memory hash changed
-> measure cycle duration

if cycle_duration_minutes <= 60:
  start next cycle

if cycle_duration_minutes > 60:
  STOPPED_BY_CYCLE_RUNTIME_SLA_EXCEEDED
  do not start next cycle
```

The controller does not hard-kill an active school run. A slow cycle is allowed to finish so checkpoint/finalizer/merge boundaries stay safe. The stop happens before the next cycle.

## Easy override

Launch-time overrides:

```text
-Count <N>
-MaxCycleRuntimeMinutes <N>
-MaxTotalRuntimeMinutes <N>
-MaxCycles <N>
-StopFile <path>
-RequireRepoClean
```

`-MaxRuntimeMinutes` remains accepted as an alias for `-MaxCycleRuntimeMinutes`.

## Flow

```text
preflight repo/process/stop-file
-> resolve defaults from autonomous_school_cycle_policy.json
-> run operations/school/run_agent_school.ps1 -Count N -Mode Test|Live -TopicsPlan plan.json
-> canonical runner creates school proof
-> finalizer submits School packet to intake
-> merge queue admits packet into compact memory
-> controller verifies school PASS, intake PASS, merge PASS, memory hash changed
-> measure cycle duration against per-cycle SLA
-> if within SLA and no stop file, start next cycle
-> write AUTONOMOUS_SCHOOL_CYCLE_RUN_V1.json
```

## Control interface

Use one owner-facing control command:

```text
operations/school/control_autonomous_school_cycle_v1.ps1 -Action Start
operations/school/control_autonomous_school_cycle_v1.ps1 -Action Status
operations/school/control_autonomous_school_cycle_v1.ps1 -Action Stop
```

`Start` launches the bounded cycle controller detached. Defaults come from `autonomous_school_cycle_policy.json`: Live mode, 50000 candidates, 60-minute per-cycle SLA. `Stop` writes the stop-file only; it does not hard-kill an active school run.