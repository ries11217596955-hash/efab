# CANONICAL_EXACT_COUNT_CYCLE_WIRING_INSTALLATION_20260715

Status: PASS_CANONICAL_EXACT_COUNT_CYCLE_WIRED_AND_PROVEN_V1

Canonical owner entrypoint now routes through Generic Exact Count Warehouse Cycle.

Owner-facing fields remain:

```text
Count
Mode
Topics
```

Test proof:

```text
run_agent_school.ps1 -Count 101 -Mode Test -Topics AUTO
status = PASS_CANONICAL_EXACT_COUNT_CYCLE_TEST_V1
batch_counts = 100,1
accepted_count = 101
absorb = False
memory_changed = False
```

Live proof:

```text
run_agent_school.ps1 -Count 1 -Mode Live -Topics AUTO
status = PASS_CANONICAL_EXACT_COUNT_CYCLE_LIVE_V1
batch_counts = 1
accepted_count = 1
absorb = True
memory_changed = True
backup_root = .runtime/protected_backups/before_canonical_exact_live_1_20260715_092114
```

Boundary: larger canonical Live counts are not claimed yet.
